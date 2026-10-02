codeunit 78350 "AST OE Events Mgt."
{
    // Este codeunit adapta el proceso estándar de Transportes a las expediciones
    // creadas desde el diario de productos de servicio. Conserva los datos de
    // transporte al contabilizar y construye los portes eCMR de cada ruta.
    // La petición HTTP y el envío a eCMR permanecen en el codeunit estándar;
    // aquí se preparan y completan los datos específicos de los servicios.
    Permissions = tabledata Customer = R,
                  tabledata "Ship-to Address" = R,
                  tabledata Item = R,
                  tabledata "AST Serv. Item Entry Journal" = RIMD,
                  tabledata "AST Service Item" = R,
                  tabledata "ASTEX Expedition Setup" = R,
                  tabledata "ASTEX Goods Nature" = R,
                  tabledata "ASTEX Posted Exp. Lines" = R,
                  tabledata "ASTEX Posted Route Ex. Lines" = RIMD;

    // Mantiene sincronizada la prioridad de las líneas del diario con la ruta
    // abierta. Solo se actualizan las líneas de servicio de la expedición y
    // de la prioridad anterior, evitando modificar diarios no relacionados.
    [EventSubscriber(ObjectType::Table, Database::"ASTEX Route Expedition Lines", 'OnAfterValidateEvent', 'Stop Order', false, false)]
    local procedure OnAfterValidateRouteStopOrder(var Rec: Record "ASTEX Route Expedition Lines"; var xRec: Record "ASTEX Route Expedition Lines"; CurrFieldNo: Integer)
    var
        ServItemEntryJournal: Record "AST Serv. Item Entry Journal";
    begin
        if not IsServiceSourceDocType(Rec."Source Doc. Type") then
            exit;
        if Rec."Stop Order" = xRec."Stop Order" then
            exit;
        if Rec."Expedition No." = '' then
            exit;

        // Sin filtrar por "Line No.": la parada agrupa todas las líneas del diario con el mismo destino.
        ServItemEntryJournal.SetRange("Journal Template Name", Rec."Journal Template Name");
        ServItemEntryJournal.SetRange("Journal Batch Name", Rec."Journal Batch Name");
        ServItemEntryJournal.SetRange("Expedition No.", Rec."Expedition No.");
        ServItemEntryJournal.SetRange("Expedition Route", xRec."Stop Order");
        if ServItemEntryJournal.FindSet(true) then
            repeat
                ServItemEntryJournal."Expedition Route" := Rec."Stop Order";
                ServItemEntryJournal.Modify(true);
            until ServItemEntryJournal.Next() = 0;
    end;

    // Después de eliminar una expedición abierta se elimina también su vínculo
    // en el diario. Se limpian ambos campos para que la línea pueda volver a
    // formar parte de otra expedición sin conservar una prioridad obsoleta.
    // Al ejecutarse después del borrado no se desvincula el diario si la
    // eliminación fue rechazada por una validación de la expedición.
    [EventSubscriber(ObjectType::Table, Database::"ASTEX Expedition", 'OnAfterDeleteEvent', '', false, false)]
    local procedure OnAfterDeleteServiceExpedition(var Rec: Record "ASTEX Expedition"; RunTrigger: Boolean)
    var
        ServItemEntryJournal: Record "AST Serv. Item Entry Journal";
        PostedExpedition: Record "ASTEX Posted Expedition";
    begin
        if not IsServiceSourceDocType(Rec."Source Doc. Type") then
            exit;
        if Rec."Expedition No." = '' then
            exit;

        // El registro también borra la expedición abierta; en ese caso el diario debe seguir vinculado.
        PostedExpedition.SetRange("Source Expedition No.", Rec."Expedition No.");
        if not PostedExpedition.IsEmpty() then
            exit;

        ServItemEntryJournal.SetRange("Expedition No.", Rec."Expedition No.");
        ServItemEntryJournal.ModifyAll(ServItemEntryJournal."Expedition No.", '');
        ServItemEntryJournal.ModifyAll("Expedition Route", 1);
    end;

    // Copia en el movimiento contabilizado los datos de transporte del diario
    // antes de insertar la línea de producto de servicio registrada.
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"AST Serv. Item Entry-Post Line", OnBeforePostedServiceItemBinEntryInsert, '', false, false)]
    local procedure OnBeforePostedServiceItemBinEntryInsert(var PostedServiceItemBinEntry: Record "AST Posted ServItem Bin Entry"; var ServiceItemEntryLine: Record "AST Serv. Item Entry Journal")
    begin
        CopyJournalTransportToPostedEntry(PostedServiceItemBinEntry, ServiceItemEntryLine);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"ASTO ServItemEntryPostLine", 'OnBeforePostedServiceItemBinEntryInsert', '', false, false)]
    local procedure OnBeforeObraPostedServiceItemBinEntryInsert(var PostedServiceItemBinEntry: Record "AST Posted ServItem Bin Entry"; ServiceItemEntryLine: Record "AST Serv. Item Entry Journal")
    begin
        CopyJournalTransportToPostedEntry(PostedServiceItemBinEntry, ServiceItemEntryLine);
    end;

    local procedure CopyJournalTransportToPostedEntry(var PostedServiceItemBinEntry: Record "AST Posted ServItem Bin Entry"; ServiceItemEntryLine: Record "AST Serv. Item Entry Journal")
    begin
        PostedServiceItemBinEntry."Expedition No." := ServiceItemEntryLine."Expedition No.";
        PostedServiceItemBinEntry."Transport Method" := ServiceItemEntryLine."Transport Method";
        PostedServiceItemBinEntry."Driver Code" := ServiceItemEntryLine."Driver Code";
        PostedServiceItemBinEntry."Vehicle" := ServiceItemEntryLine.Vehicle;
        PostedServiceItemBinEntry."Truck Plate" := ServiceItemEntryLine."Truck Plate";
        PostedServiceItemBinEntry."Trailer Plate" := ServiceItemEntryLine."Trailer Plate";
        PostedServiceItemBinEntry."Expedition Route" := ServiceItemEntryLine."Expedition Route";
    end;

    // Para Service Delivery y Service Pickup mantiene la referencia al diario
    // cuando se contabiliza la expedición. No contabiliza ni elimina la línea
    // del diario: esa operación se realiza posteriormente por su proceso propio.
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"ASTEX Process Events", 'OnPostExpeditionFromCodeOnUnhandledSourceDocType', '', false, false)]
    local procedure OnPostExpeditionFromCodeOnUnhandledSourceDocType(var ExpeditionHeader: Record "ASTEX Expedition"; var ExpeditionLine: Record "ASTEX Expeditions Lines"; AlreadyShippedOrderNo: Code[20]; FromExpedition: Boolean)
    var
        ServItemEntryJournal: Record "AST Serv. Item Entry Journal";
        SourceRecordRef: RecordRef;
        InvalidRecordTableErr: Label 'Expedition line %1 does not reference the service item journal.', Comment = 'ESP="La línea de expedición %1 no referencia el diario de productos de servicio."';
    begin
        if not (ExpeditionLine."Source Doc. Type" in [ExpeditionLine."Source Doc. Type"::"Service Delivery", ExpeditionLine."Source Doc. Type"::"Service Pickup"]) then
            exit;

        // Si el diario ya se contabilizó, el RecordId original ya no existe y su vínculo quedó copiado al movimiento contabilizado.
        if not SourceRecordRef.Get(ExpeditionLine.RecordId) then
            exit;
        if SourceRecordRef.Number() <> Database::"AST Serv. Item Entry Journal" then
            Error(InvalidRecordTableErr, ExpeditionLine."Line No.");

        SourceRecordRef.SetTable(ServItemEntryJournal);
        if ServItemEntryJournal."Expedition No." <> ExpeditionHeader."Expedition No." then begin
            ServItemEntryJournal."Expedition No." := ExpeditionHeader."Expedition No.";
            ServItemEntryJournal.Modify(true);
        end;
    end;

    // Comprueba el correo del destinatario antes de que el proceso estándar intente
    // enviar los portes de servicio a eCMR mediante firma simple.
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"ASTEX Process Events", 'OnCheckSourceDocumentsEmailOnUnhandledSourceDocType', '', false, false)]
    local procedure CheckServiceExpeditionCustomerEmail(Expedition: Record "ASTEX Expedition"; ExpeditionLine: Record "ASTEX Expeditions Lines")
    var
        MissingCustomerEmailErr: Label 'Neither the ship-to address nor customer %1 has an e-mail address, required for service expedition %2.', Comment = 'ESP="Ni la dirección de envío ni el cliente %1 tienen correo electrónico, necesario para la expedición de servicio %2."';
    begin
        if not IsServiceSourceDocType(Expedition."Source Doc. Type") then
            exit;


        if GetServiceConsigneeEmail(ExpeditionLine."Customer No.", ExpeditionLine.RecordId, ExpeditionLine."Source Doc. Type") = '' then
            Error(MissingCustomerEmailErr, ExpeditionLine."Customer No.", Expedition."Expedition No.");
    end;

    local procedure GetServiceConsigneeEmail(CustomerNo: Code[20]; SourceRecordId: RecordId; SourceDocType: Enum "ASTEX Source Doc Type"): Text
    var
        Customer: Record Customer;
        ShiptoAddress: Record "Ship-to Address";
        ServItemEntryJournal: Record "AST Serv. Item Entry Journal";
        SourceRecordRef: RecordRef;
        ShipToCode: Code[10];
    begin
        if SourceRecordRef.Get(SourceRecordId) then
            if SourceRecordRef.Number() = Database::"AST Serv. Item Entry Journal" then begin
                SourceRecordRef.SetTable(ServItemEntryJournal);
                case SourceDocType of
                    SourceDocType::"Service Delivery":
                        ShipToCode := ServItemEntryJournal."Assignment Cust Ship Address";
                    SourceDocType::"Service Pickup":
                        ShipToCode := ServItemEntryJournal."Originally Cust Ship Address";
                end;
                if ShiptoAddress.Get(CustomerNo, ShipToCode) then
                    if ShiptoAddress."E-Mail" <> '' then
                        exit(ShiptoAddress."E-Mail");
            end;

        Customer.Get(CustomerNo);
        exit(Customer."E-Mail");
    end;
    // Construye el lote eCMR para una expedición de servicio. Se genera un
    // porte por cada ruta registrada y se buscan sus mercancías mediante la
    // prioridad persistida en "Stop Order" / "Expedition Route".
    // El codeunit estándar enviará después el lote resultante a eCMR.
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"ASTEX Process Events", 'OnBuildLotRequestOnUnhandledSourceDocType', '', false, false)]
    local procedure BuildServiceExpeditionLot(Expedition: Record "ASTEX Posted Expedition"; var ShipmentsArray: JsonArray)
    var
        PostedRouteLine: Record "ASTEX Posted Route Ex. Lines";
        PostedExpeditionLine: Record "ASTEX Posted Exp. Lines";
        ProcessEvents: Codeunit "ASTEX Process Events";
        SourceDocument: Variant;
        ShipmentObj: JsonObject;
        GoodsArray: JsonArray;
        TotalNetWeight: Decimal;
        GoodsNatureDescription: Text;
        NoServiceRoutesErr: Label 'No posted service route lines were found for expedition %1.', Comment = 'ESP="No se encontraron líneas de ruta registradas para la expedición de servicio %1."';
        NoServiceLinesErr: Label 'No posted service expedition lines were found for route %1 of expedition %2.', Comment = 'ESP="No se encontraron líneas registradas de expedición de servicio para la ruta %1 de la expedición %2."';
    begin
        if not IsServiceSourceDocType(Expedition."Source Doc. Type") then
            exit;

        // Solo se incluyen las rutas registradas de la expedición actual y del
        // mismo tipo de origen, evitando mezclar entregas y recogidas.
        PostedRouteLine.SetRange("Expedition No.", Expedition."Expedition No.");
        PostedRouteLine.SetRange("Source Doc. Type", Expedition."Source Doc. Type");
        if not PostedRouteLine.FindSet() then
            Error(NoServiceRoutesErr, Expedition."Expedition No.");

        repeat
            SetServiceExpeditionLineFilters(PostedRouteLine, PostedExpeditionLine);
            if not PostedExpeditionLine.FindFirst() then
                Error(NoServiceLinesErr, PostedRouteLine."Stop Order", Expedition."Expedition No.");

            // Se usa la línea registrada como documento origen para que el
            // builder estándar pueda completar los campos comunes del porte.
            SourceDocument := PostedExpeditionLine;
            ShipmentObj := ProcessEvents.BuildShipmentRequest(Expedition, PostedRouteLine, SourceDocument);
            BuildServiceGoods(PostedRouteLine, GoodsArray, TotalNetWeight, GoodsNatureDescription);
            if not ShipmentObj.Replace('goods', GoodsArray) then
                Error(NoServiceLinesErr, PostedRouteLine."Stop Order", Expedition."Expedition No.");

            AddServiceConsignee(Expedition, PostedRouteLine, ShipmentObj);
            UpdateServiceTemplateValues(ShipmentObj, TotalNetWeight, GoodsNatureDescription);
            ShipmentsArray.Add(ShipmentObj);
        until PostedRouteLine.Next() = 0;
    end;

    // Añade una referencia estable y un nombre legible a cada porte de ruta,
    // identificándolo por número de expedición y número de parada.
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"ASTEX Process Events", 'OnBuildShipmentRequestOnUnhandledSourceDocTypeVariant', '', false, false)]
    local procedure BuildServiceShipmentReference(Expedition: Record "ASTEX Posted Expedition"; RouteLine: Record "ASTEX Posted Route Ex. Lines"; SourceDocument: Variant; var ShipmentObj: JsonObject)
    var
        ServiceShipmentNameLbl: Label 'Expedition %1 - Service route %2', Comment = 'ESP="Expedición %1 - Ruta de servicio %2"';
        ShipmentReference: Text;
    begin
        if not IsServiceSourceDocType(Expedition."Source Doc. Type") then
            exit;

        ShipmentReference := Expedition."Expedition No." + '-' + Format(RouteLine."Line No.", 0, 9);
        ShipmentObj.Add('shipment_reference', ShipmentReference);
        ShipmentObj.Add('shipment_name', StrSubstNo(ServiceShipmentNameLbl, Expedition."Expedition No.", RouteLine."Stop Order"));
    end;

    // Recibe la respuesta eCMR de expediciones de servicio, localiza la ruta
    // mediante la referencia que generamos (Nº expedición-Nº línea) y aplica
    // el mismo tratamiento que el estándar hace para Transfer/Sales/etc.
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"ASTEX Process Events", 'OnUpdateRouteShipmentTraceOnUnhandledSourceDocType', '', false, false)]
    local procedure UpdateServiceRouteShipmentTrace(Expedition: Record "ASTEX Posted Expedition"; ShipmentReference: Text; ShipmentId: Text; ShipmentStatusText: Text; var RouteLine: Record "ASTEX Posted Route Ex. Lines"; ErrorCode: Text; ErrorMessage: Text)
    var
        ProcessEvents: Codeunit "ASTEX Process Events";
    begin
        if not IsServiceSourceDocType(Expedition."Source Doc. Type") then
            exit;

        if not FindServiceRouteLineForShipmentReference(Expedition, ShipmentReference, RouteLine) then
            exit;

        RouteLine."eCMR Shipment Id" := CopyStr(ShipmentId, 1, MaxStrLen(RouteLine."eCMR Shipment Id"));
        ProcessEvents.ApplyShipmentStatusToRouteLine(RouteLine, ShipmentStatusText, ErrorCode, ErrorMessage);
        if ProcessEvents.GetECMRShipmentStatus(ShipmentStatusText) = Enum::"ASTEX eCMR Shipment Status"::Error then
            exit;
    end;

    // Localiza la ruta de servicio cuya referencia de porte (Nº expedición-Nº
    // línea) coincide con la devuelta por eCMR.
    local procedure FindServiceRouteLineForShipmentReference(Expedition: Record "ASTEX Posted Expedition"; ShipmentReference: Text; var RouteLine: Record "ASTEX Posted Route Ex. Lines"): Boolean
    begin
        RouteLine.SetRange("Expedition No.", Expedition."Expedition No.");
        RouteLine.SetRange("Source Doc. Type", Expedition."Source Doc. Type");
        if not RouteLine.FindSet(true) then
            exit(false);

        repeat
            if Expedition."Expedition No." + '-' + Format(RouteLine."Line No.", 0, 9) = ShipmentReference then
                exit(true);
        until RouteLine.Next() = 0;

        exit(false);
    end;

    // Sustituye las mercancías genéricas del builder por los productos de
    // Añade una mercancía por cada línea del porte y reúne las naturalezas
    // únicas para la plantilla, sin un límite fijo de productos.
    local procedure BuildServiceGoods(RouteLine: Record "ASTEX Posted Route Ex. Lines"; var GoodsArray: JsonArray; var TotalNetWeight: Decimal; var GoodsNatureDescription: Text)
    var
        PostedExpeditionLine: Record "ASTEX Posted Exp. Lines";
        ServiceItem: Record "AST Service Item";
        Item: Record Item;
        ExpeditionSetup: Record "ASTEX Expedition Setup";
        GoodsNature: Record "ASTEX Goods Nature";
        GoodObj: JsonObject;
        ServiceItemDescription: Text[100];
        GoodsNatureDescriptions: List of [Text[100]];
        GoodsNatureDefaultCode: Code[20];
        GoodsNatureCode: Code[20];
        GoodsNatureText: Text[100];
        CarriageReturn: Char;
        LineFeed: Char;
        LineBreak: Text[2];
        NoServiceGoodsErr: Label 'No service item lines were found for route %1 of expedition %2.', Comment = 'ESP="No se encontraron líneas de producto de servicio para la ruta %1 de la expedición %2."';
    begin
        Clear(GoodsArray);
        Clear(TotalNetWeight);
        Clear(GoodsNatureDescription);
        Clear(GoodsNatureDescriptions);
        if ExpeditionSetup.Get() then
            GoodsNatureDefaultCode := ExpeditionSetup."ASTEX Goods Nature Code";

        SetServiceExpeditionLineFilters(RouteLine, PostedExpeditionLine);
        if not PostedExpeditionLine.FindSet() then
            Error(NoServiceGoodsErr, RouteLine."Stop Order", RouteLine."Expedition No.");

        repeat
            PostedExpeditionLine.TestField("No.");
            PostedExpeditionLine.TestField("Net Weight");
            Clear(ServiceItem);
            Clear(Item);
            Clear(ServiceItemDescription);
            case PostedExpeditionLine.Type of
                PostedExpeditionLine.Type::"Service Item":
                    begin
                        if ServiceItem.Get(PostedExpeditionLine."No.") then begin
                            ServiceItemDescription := ServiceItem.Description;
                            if Item.Get(ServiceItem."Item No.") then;
                        end;
                    end;
                PostedExpeditionLine.Type::Item:
                    if Item.Get(PostedExpeditionLine."No.") then
                        ServiceItemDescription := Item.Description;
                else
                    PostedExpeditionLine.FieldError(Type);
            end;
            if ServiceItemDescription = '' then
                ServiceItemDescription := PostedExpeditionLine."No.";

            Clear(GoodObj);
            // eCMR recibe una mercancía por línea de servicio. El peso que
            // aporta el diario es el peso disponible para esta integración.
            GoodObj.Add('good_description', ServiceItemDescription);
            GoodObj.Add('cargo_type', 'general');
            GoodObj.Add('good_gross_mass', Format(PostedExpeditionLine."Net Weight"));
            GoodObj.Add('good_size', Format(PostedExpeditionLine."Qty to Shipp"));
            GoodObj.Add('temperature', '');
            GoodObj.Add('dangerous_goods', false);
            GoodObj.Add('dangerous_goods_description', '');
            GoodsArray.Add(GoodObj);

            TotalNetWeight += PostedExpeditionLine."Net Weight";

            // La naturaleza del artículo prevalece; si no está informada,
            // Usa la naturaleza del artículo asociado o, si falta, la
            // naturaleza predeterminada de Expediciones.
            GoodsNatureCode := GoodsNatureDefaultCode;
            if Item."ASTEX Goods Nature Code" <> '' then
                GoodsNatureCode := Item."ASTEX Goods Nature Code";

            if GoodsNatureCode <> '' then begin
                GoodsNatureText := GoodsNatureCode;
                if GoodsNature.Get(GoodsNatureCode) then
                    GoodsNatureText := GoodsNature.Description;
                if (GoodsNatureText <> '') and not GoodsNatureDescriptions.Contains(GoodsNatureText) then
                    GoodsNatureDescriptions.Add(GoodsNatureText);
            end;
        until PostedExpeditionLine.Next() = 0;

        CarriageReturn := 13;
        LineFeed := 10;
        LineBreak := Format(CarriageReturn) + Format(LineFeed);
        foreach GoodsNatureText in GoodsNatureDescriptions do begin
            if GoodsNatureDescription <> '' then
                GoodsNatureDescription += LineBreak;
            GoodsNatureDescription += GoodsNatureText;
        end;
    end;

    // Añade el cliente de destino como consignatario y conserva las partes
    // creadas por el builder estándar, incluido el idioma del porte.
    local procedure AddServiceConsignee(Expedition: Record "ASTEX Posted Expedition"; RouteLine: Record "ASTEX Posted Route Ex. Lines"; var ShipmentObj: JsonObject)
    var
        PostedExpeditionLine: Record "ASTEX Posted Exp. Lines";
        Customer: Record Customer;
        ShipmentToken: JsonToken;
        PartiesToken: JsonToken;
        ConsigneesToken: JsonToken;
        ConsigneesArray: JsonArray;
        PartiesObj: JsonObject;
        ConsigneeObj: JsonObject;
        ConsigneeName: Text;
    begin
        SetServiceExpeditionLineFilters(RouteLine, PostedExpeditionLine);
        if not PostedExpeditionLine.FindFirst() then
            exit;
        Customer.Get(PostedExpeditionLine."Customer No.");

        if not ShipmentObj.Get('language', ShipmentToken) then
            exit;
        if not ShipmentObj.Get('parties', PartiesToken) then
            exit;
        PartiesObj := PartiesToken.AsObject();
        if not PartiesObj.Get('consignees', ConsigneesToken) then
            exit;
        ConsigneesArray := ConsigneesToken.AsArray();

        ConsigneeName := RouteLine."Destination Location Name";
        if ConsigneeName = '' then
            ConsigneeName := Customer.Name;
        ConsigneeObj.Add('name', ConsigneeName);
        if Customer."VAT Registration No." <> '' then
            ConsigneeObj.Add('tax_id', Customer."VAT Registration No.");
        ConsigneeObj.Add('address', RouteLine."Destination Location Address");
        ConsigneeObj.Add('post_code', RouteLine."Destination Location Post Code");
        ConsigneeObj.Add('city', RouteLine."Destination Location City");
        ConsigneeObj.Add('country_code', RouteLine."Dest. Country/Region Code");
        ConsigneeObj.Add('order', 4);
        ConsigneeObj.Add('signing_role', 'cc');
        if Customer."E-Mail" <> '' then begin
            ConsigneeObj.Add('channel', 'email');
            ConsigneeObj.Add('email', Customer."E-Mail");
        end;
        ConsigneeObj.Add('language', ShipmentToken.AsValue().AsText());

        ConsigneesArray.Add(ConsigneeObj);
        PartiesObj.Replace('consignees', ConsigneesArray);
        ShipmentObj.Replace('parties', PartiesObj);
    end;

    // Actualiza los valores de la plantilla DeCA con el peso total y la
    // Actualiza el peso y la naturaleza de mercancía de la plantilla DeCA.
    local procedure UpdateServiceTemplateValues(var ShipmentObj: JsonObject; TotalNetWeight: Decimal; GoodsNatureDescription: Text)
    var
        DocumentsToken: JsonToken;
        DocumentToken: JsonToken;
        TemplateToken: JsonToken;
        ValuesToken: JsonToken;
        NatureToken: JsonToken;
        DocumentsArray: JsonArray;
        DocumentObj: JsonObject;
        TemplateObj: JsonObject;
        ValuesObj: JsonObject;
        WeightValue: JsonValue;
        NatureValue: JsonValue;
    begin
        if not ShipmentObj.Get('documents', DocumentsToken) then
            exit;
        DocumentsArray := DocumentsToken.AsArray();
        if not DocumentsArray.Get(0, DocumentToken) then
            exit;
        DocumentObj := DocumentToken.AsObject();
        if not DocumentObj.Get('template', TemplateToken) then
            exit;
        TemplateObj := TemplateToken.AsObject();
        if not TemplateObj.Get('values', ValuesToken) then
            exit;
        ValuesObj := ValuesToken.AsObject();

        // Se reemplazan únicamente los valores propios del servicio y se
        // mantienen intactos el resto de campos de la plantilla.
        WeightValue.SetValue(Format(TotalNetWeight) + 'KG');
        ValuesObj.Replace('PesoMercancía', WeightValue);

        if GoodsNatureDescription <> '' then begin
            NatureValue.SetValue(GoodsNatureDescription);
            ValuesObj.Replace('NaturalezaMercancia', NatureValue);
        end;

        TemplateObj.Replace('values', ValuesObj);
        DocumentObj.Replace('template', TemplateObj);
        DocumentsArray.Set(0, DocumentObj);
        ShipmentObj.Replace('documents', DocumentsArray);
    end;

    // Aplica la relación funcional que vincula una línea registrada con su
    // ruta: expedición, origen, parada y almacén. El destino no se utiliza
    // como filtro porque puede normalizarse de forma diferente al registrar;
    // la línea de ruta ya contiene el destino definitivo del porte.
    local procedure SetServiceExpeditionLineFilters(RouteLine: Record "ASTEX Posted Route Ex. Lines"; var PostedExpeditionLine: Record "ASTEX Posted Exp. Lines")
    begin
        PostedExpeditionLine.Reset();
        PostedExpeditionLine.SetRange("Expedition No.", RouteLine."Expedition No.");
        PostedExpeditionLine.SetRange("Source Doc. Type", RouteLine."Source Doc. Type");
        PostedExpeditionLine.SetRange("Expedition Route", RouteLine."Stop Order");
        PostedExpeditionLine.SetRange("Location Code", RouteLine."Location Code");
    end;

    // Centraliza la identificación de los dos tipos de expedición gestionados
    // por este codeunit para que todos los subscribers apliquen el mismo filtro.
    local procedure IsServiceSourceDocType(SourceDocType: Enum "ASTEX Source Doc Type"): Boolean
    begin
        exit(SourceDocType in [SourceDocType::"Service Delivery", SourceDocType::"Service Pickup"]);
    end;

    // [EventSubscriber(ObjectType::Table, Database::"ASTEX Expedition", 'OnAfterValidateEvent', 'Source Doc. Type', false, false)]
    // local procedure OnAfterValidateExpeditionSourceDocType(var Rec: Record "ASTEX Expedition"; var xRec: Record "ASTEX Expedition"; CurrFieldNo: Integer)
    // var
    //     ExistingExpedition: Record "ASTEX Expedition";
    // begin
    //     if CurrFieldNo <> Rec.FieldNo("Source Doc. Type") then
    //         exit;
    //     if not (Rec."Source Doc. Type" in [Rec."Source Doc. Type"::"Service Delivery", Rec."Source Doc. Type"::"Service Pickup"]) then
    //         exit;
    //     // La ficha base hace CurrPage.Update(false) y las subpáginas propagan el refresco: sin guardar aquí, se relee el valor anterior.
    //     if ExistingExpedition.Get(Rec."Expedition No.") then
    //         Rec.Modify(true);
    // end;


}