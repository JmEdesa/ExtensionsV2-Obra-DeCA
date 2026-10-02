codeunit 78351 "AST OE Expeditions Mgt."
{
    var
        OE_ProcessEvents: Codeunit "AST OE Process Events";

    // Valida que las líneas seleccionadas del diario puedan agruparse en una única expedición:
    // todas deben tener informados los campos obligatorios y compartir los mismos valores que la primera línea.
    procedure TestServItemJournalLine(var ServItemEntryJournal: Record "AST Serv. Item Entry Journal")
    var
        FirstServItemEntryJournal: Record "AST Serv. Item Entry Journal";
        ServItemEntryJournalAux: Record "AST Serv. Item Entry Journal";
        ShiptoAddress: Record "Ship-to Address";
        FirstLocationCode: Code[10];
    begin
        // Se trabaja sobre una copia para no alterar la posición ni los filtros del registro recibido.
        ServItemEntryJournalAux.Copy(ServItemEntryJournal);
        // "Driver Name" es un FlowField: se calcula automáticamente en cada lectura para poder validarlo.
        ServItemEntryJournalAux.SetAutoCalcFields("Driver Name");
        ServItemEntryJournalAux.FindSet();
        // La primera línea actúa como referencia con la que se comparan el resto.
        FirstServItemEntryJournal := ServItemEntryJournalAux;
        CheckValidEntryType(FirstServItemEntryJournal);
        // El almacén de la primera línea será el de la cabecera de la expedición.
        FirstLocationCode := GetShipToLocationCode(FirstServItemEntryJournal);

        // Para cada línea: tipo válido, campos obligatorios informados y mismos valores (incluido el almacén) que la primera línea.
        repeat
            CheckValidEntryType(ServItemEntryJournalAux);
            CheckMandatoryFields(ServItemEntryJournalAux);
            CheckSameValuesAsFirstLine(FirstServItemEntryJournal, ServItemEntryJournalAux);
            CheckSameValue(ShiptoAddress.FieldCaption("Location Code"), FirstLocationCode, GetShipToLocationCode(ServItemEntryJournalAux));
        until ServItemEntryJournalAux.Next() = 0;
    end;

    // Devuelve el almacén de la dirección de envío de la línea (origen en entregas, asignación en recogidas).
    local procedure GetShipToLocationCode(ServItemEntryJournal: Record "AST Serv. Item Entry Journal"): Code[10]
    var
        ShiptoAddress: Record "Ship-to Address";
        EntryType: Option Delivery,Return,Error;
    begin
        EntryType := GetEntryType(ServItemEntryJournal."Entry Type");
        if EntryType = EntryType::Return then
            ShiptoAddress.Get(ServItemEntryJournal."Assignment Customer", ServItemEntryJournal."Assignment Cust Ship Address")
        else
            ShiptoAddress.Get(ServItemEntryJournal."Originally Customer", ServItemEntryJournal."Originally Cust Ship Address");
        ShiptoAddress.TestField("Location Code");
        exit(ShiptoAddress."Location Code");
    end;

    // Lanza error si el tipo de movimiento no corresponde a una entrega ni a una recogida.
    local procedure CheckValidEntryType(ServItemEntryJournal: Record "AST Serv. Item Entry Journal")
    var
        EntryType: Option Delivery,Return,Error;
        InvalidEntryTypeErr: Label 'Type Error', Comment = 'ESP="Error de Tipo"';
    begin
        EntryType := GetEntryType(ServItemEntryJournal."Entry Type");
        if EntryType = EntryType::Error then
            Error(InvalidEntryTypeErr);
    end;

    // Comprueba que la línea tenga informados los datos de transporte necesarios para la expedición.
    local procedure CheckMandatoryFields(ServItemEntryJournal: Record "AST Serv. Item Entry Journal")
    begin
        ServItemEntryJournal.TestField("Transport Method");
        ServItemEntryJournal.TestField("Shipping Agent Code");
        ServItemEntryJournal.TestField(Vehicle);
        ServItemEntryJournal.TestField("Driver Code");
        ServItemEntryJournal.TestField("Driver Name");
        ServItemEntryJournal.TestField("Expedition Route");
    end;

    // Compara los campos que definen la expedición entre la línea de referencia y la línea actual.
    local procedure CheckSameValuesAsFirstLine(FirstServItemEntryJournal: Record "AST Serv. Item Entry Journal"; ServItemEntryJournal: Record "AST Serv. Item Entry Journal")
    var
        FirstEntryType: Option Delivery,Return,Error;
        LineEntryType: Option Delivery,Return,Error;
    begin
        // Se compara el tipo agrupado (Entrega/Recogida), no el valor exacto del enum.
        FirstEntryType := GetEntryType(FirstServItemEntryJournal."Entry Type");
        LineEntryType := GetEntryType(ServItemEntryJournal."Entry Type");

        CheckSameValue(ServItemEntryJournal.FieldCaption("Entry Type"), Format(FirstEntryType), Format(LineEntryType));
        CheckSameValue(ServItemEntryJournal.FieldCaption("Posting Date"), Format(FirstServItemEntryJournal."Posting Date"), Format(ServItemEntryJournal."Posting Date"));
        CheckSameValue(ServItemEntryJournal.FieldCaption("Transport Method"), FirstServItemEntryJournal."Transport Method", ServItemEntryJournal."Transport Method");
        CheckSameValue(ServItemEntryJournal.FieldCaption("Shipping Agent Code"), FirstServItemEntryJournal."Shipping Agent Code", ServItemEntryJournal."Shipping Agent Code");
        CheckSameValue(ServItemEntryJournal.FieldCaption(Vehicle), FirstServItemEntryJournal.Vehicle, ServItemEntryJournal.Vehicle);
        // "Driver Name" no se compara: es un FlowField que depende de "Driver Code".
        CheckSameValue(ServItemEntryJournal.FieldCaption("Driver Code"), FirstServItemEntryJournal."Driver Code", ServItemEntryJournal."Driver Code");

        // El cliente asociado a cada expedición depende de si la línea es entrega o recogida.
        case FirstEntryType of
            FirstEntryType::Delivery:
                CheckSameValue(ServItemEntryJournal.FieldCaption("Originally Customer"), FirstServItemEntryJournal."Originally Customer", ServItemEntryJournal."Originally Customer");
            FirstEntryType::Return:
                CheckSameValue(ServItemEntryJournal.FieldCaption("Assignment Customer"), FirstServItemEntryJournal."Assignment Customer", ServItemEntryJournal."Assignment Customer");
        end;
    end;

    // Lanza un error descriptivo indicando el campo, el valor esperado y el valor encontrado si no coinciden.
    local procedure CheckSameValue(FieldCaptionTxt: Text; ExpectedValue: Text; LineValue: Text)
    var
        DifferentValueErr: Label 'All selected lines must have the same %1. Expected value: %2. Line value: %3.', Comment = 'ESP="Todas las líneas seleccionadas deben tener el mismo %1. Valor esperado: %2. Valor de la línea: %3."';
    begin
        if ExpectedValue <> LineValue then
            Error(DifferentValueErr, FieldCaptionTxt, ExpectedValue, LineValue);
    end;


    procedure CreateExpeditionFromServItemBinEntry(Var ServItemEntryJournal: Record "AST Serv. Item Entry Journal")
    var
        ExpeditionHeader: Record "ASTEX Expedition";
        ExpeditionheaderAux: Record "ASTEX Expedition";
        RouteExpLines: Record "ASTEX Route Expedition Lines";
        ReleaseSalesDoc: Codeunit "Release Sales Document";
        SuccesLbl: Label 'The %1 Expedition has been created.', Comment = 'ESP="Se ha creado la Expedición %1."';
        IsHandled: Boolean;
        EntryType: Option Delivery,Return;
        ExpeditionSetup: Record "ASTEX Expedition Setup";
        eCMRSigningMode: Enum "ASTEX eCMR Signing Mode";
        ASTEXProcessEvents: Codeunit "ASTEX Process Events";
    begin
        ExpeditionSetup.Get();
        // Las líneas ya se han validado previamente en TestServItemJournalLine.
        ServItemEntryJournal.SetCurrentKey("Expedition Route");
        ServItemEntryJournal.SetAscending("Expedition Route", true);
        if ServItemEntryJournal.FindSet() then begin
            EntryType := GetEntryType(ServItemEntryJournal."Entry Type");

            ExpeditionHeader.Init();
            case EntryType of
                EntryType::Delivery:
                    ExpeditionHeader.Validate("Source Doc. Type", ExpeditionHeader."Source Doc. Type"::"Service Delivery");
                EntryType::Return:
                    ExpeditionHeader.Validate("Source Doc. Type", ExpeditionHeader."Source Doc. Type"::"Service Pickup");
            end;

            ExpeditionHeader.Validate(Status, ExpeditionHeader.Status::Released);
            ExpeditionHeader.Validate("Location Code", GetShipToLocationCode(ServItemEntryJournal));
            ExpeditionHeader.Validate("Shipment Date", ServItemEntryJournal."Posting Date");
            ExpeditionHeader.Validate("Delivery Date", ServItemEntryJournal."Posting Date");

            IF ServItemEntryJournal."Transport Method" = '' then begin
                ExpeditionSetup.TestField("Default Transport Method");
                ExpeditionHeader.Validate("Transport Method", ExpeditionSetup."Default Transport Method");
            end else
                ExpeditionHeader.Validate("Transport Method", ServItemEntryJournal."Transport Method");

            // ExpeditionHeader.Validate("Transport Conservation Method", SalesHeader."ASTEX Method of Conservation"); No es necesario
            ExpeditionHeader.Validate("Transport Type", ExpeditionHeader."Transport Type"::"Transport Complete");
            ExpeditionHeader."Shipping Agent" := ServItemEntryJournal."Shipping Agent Code";

            ExpeditionHeader.Validate("Vehicle", ServItemEntryJournal."Vehicle");
            // La cabecera distingue la matrícula del camión de la del remolque.
            // El diario las conserva separadas y deben mantenerse en el mismo campo.
            ExpeditionHeader.Plate := ServItemEntryJournal."Truck Plate";
            ExpeditionHeader."Trailer Plate" := ServItemEntryJournal."Trailer Plate";
            ExpeditionHeader.Validate("Driver Code", ServItemEntryJournal."Driver Code");
            ServItemEntryJournal.CalcFields("Driver Name");
            ExpeditionHeader.Validate("Driver Name", ServItemEntryJournal."Driver Name");

            // ExpeditionHeader.Validate("Total Transport Cost", SalesHeader."ASTEX Total Transport Cost"); No es necesario
            ExpeditionHeader."ASTEX eCMR Signing Mode" := eCMRSigningMode::"Simple Signature";
            ExpeditionHeader.Observations := '';
            ExpeditionHeader.Insert(true);

            repeat
                CreateExpeditionLinesFromServItemJournal(ServItemEntryJournal, ExpeditionHeader."Expedition No.", false, ExpeditionHeader."Source Doc. Type");
                ServItemEntryJournal."Expedition No." := ExpeditionHeader."Expedition No.";
                ServItemEntryJournal.Modify(true);
            until ServItemEntryJournal.Next() = 0;

            if ExpeditionSetup."ServItem Journ. AutoPost Exp." then
                ASTEXProcessEvents.PostExpeditionFromCode(ExpeditionHeader, '', false);
            Message(SuccesLbl, ExpeditionHeader."Expedition No.");
        end;
    end;

    procedure CreateExpeditionLinesFromServItemJournal(var
                                                           ServItemEntryJournal: Record "AST Serv. Item Entry Journal";
                                                           ExpeditionNo: Code[20];
                                                           SkipCheckRemQty: Boolean; ExpSourceDocType: Enum "ASTEX Source Doc Type")
    var
        ExpeditionsLines: Record "ASTEX Expeditions Lines";
        RouteExpLines: Record "ASTEX Route Expedition Lines";
        ServiceItem: Record "AST Service Item";
        Item: Record Item;
        ShiptoAddress: Record "Ship-to Address";
        TransportQuantity: Decimal;
        IsHandled: Boolean;

    begin
        Clear(ExpeditionsLines);
        ExpeditionsLines.Init();
        ExpeditionsLines.Validate("Expedition No.", ExpeditionNo);
        ExpeditionsLines.Validate("Line No.", GetLastExpeditionLineNo(ExpeditionNo));
        ExpeditionsLines.Validate("Source Doc. Type", ExpSourceDocType);
        ExpeditionsLines.Validate(RecordId, ServItemEntryJournal.RecordId);

        ServItemEntryJournal.TestField("No.");

        ExpeditionsLines.Validate(Type, ServItemEntryJournal.Type);
        ExpeditionsLines.Validate("No.", ServItemEntryJournal."No.");
        ExpeditionsLines.Validate("Expedition Route", ServItemEntryJournal."Expedition Route");
        ExpeditionsLines.Validate("Location Code", GetShipToLocationCode(ServItemEntryJournal));


        if ExpSourceDocType = ExpSourceDocType::"Service Delivery" then begin
            ShiptoAddress.Get(ServItemEntryJournal."Assignment Customer", ServItemEntryJournal."Assignment Cust Ship Address");
            ExpeditionsLines.Validate("Customer No.", ServItemEntryJournal."Assignment Customer")
        end else begin
            ShiptoAddress.Get(ServItemEntryJournal."Originally Customer", ServItemEntryJournal."Originally Cust Ship Address");
            ExpeditionsLines.Validate("Customer No.", ServItemEntryJournal."Originally Customer");
        end;

        //NO LOS VAMOS A USAR
        // ExpeditionsLines.Validate("Gross Weight", RemQty * SalesLine."Gross Weight");
        // ExpeditionsLines.Validate("Net Weight", RemQty * SalesLine."Net Weight");
        // ExpeditionsLines.Validate("Estimated Pallets", CalcEstimatedPallets(SalesLine));

        TransportQuantity := GetTransportQuantity(ServItemEntryJournal);
        ExpeditionsLines.Validate("Qty to Ship", TransportQuantity);
        case ServItemEntryJournal.Type of
            ServItemEntryJournal.Type::"Service Item":
                begin
                    ServiceItem.Get(ServItemEntryJournal."No.");
                    ExpeditionsLines.Validate("Net Weight", TransportQuantity * ServiceItem.Weight);
                    ExpeditionsLines.Validate(Volume, TransportQuantity * ServiceItem.Volume);
                end;
            ServItemEntryJournal.Type::Item:
                begin
                    Item.Get(ServItemEntryJournal."No.");
                    ExpeditionsLines.Validate("Gross Weight", TransportQuantity * Item."Gross Weight");
                    ExpeditionsLines.Validate("Net Weight", TransportQuantity * Item."Net Weight");
                    ExpeditionsLines.Validate(Volume, TransportQuantity * Item."Unit Volume");
                end;
        end;
        ExpeditionsLines.Validate("Destination Location Name", ShiptoAddress.Name);
        ExpeditionsLines.Validate("Destination Location Address", ShiptoAddress.Address);
        ExpeditionsLines.Validate("Destination Location City", ShiptoAddress.City);
        ExpeditionsLines.Validate("Destination Location Post Code", ShiptoAddress."Post Code");
        ExpeditionsLines.Validate("Expedition County", ShiptoAddress.County);
        ExpeditionsLines.Validate("Dest. Country/Region Code", ShiptoAddress."Country/Region Code");

        ExpeditionsLines.Validate("Requested Delivery Date", ServItemEntryJournal."Posting Date");

        IsHandled := false;
        OE_ProcessEvents.OnBeforeInsertExpeditionLineFromServItemJournal(ExpeditionsLines, IsHandled);
        if not IsHandled then
            ExpeditionsLines.Insert(true);
        // end;

        RouteExpLines.Reset();
        RouteExpLines.SetRange("Expedition No.", ExpeditionNo);
        RouteExpLines.SetRange("Location Code", ExpeditionsLines."Location Code");
        RouteExpLines.SetRange("Destination Location Name", ExpeditionsLines."Destination Location Name");
        if RouteExpLines.FindFirst() then begin
            CheckSameValue(RouteExpLines.FieldCaption("Stop Order"), Format(RouteExpLines."Stop Order"), Format(ServItemEntryJournal."Expedition Route"));
            CheckSameValue(RouteExpLines.FieldCaption("Location Code"), RouteExpLines."Location Code", ExpeditionsLines."Location Code");
            CheckSameValue(RouteExpLines.FieldCaption("Destination Location Name"), RouteExpLines."Destination Location Name", ExpeditionsLines."Destination Location Name");
            CheckSameValue(RouteExpLines.FieldCaption("Destination Location Address"), RouteExpLines."Destination Location Address", ExpeditionsLines."Destination Location Address");
            CheckSameValue(RouteExpLines.FieldCaption("Destination Location City"), RouteExpLines."Destination Location City", ExpeditionsLines."Destination Location City");
            CheckSameValue(RouteExpLines.FieldCaption("Destination Location Post Code"), RouteExpLines."Destination Location Post Code", ExpeditionsLines."Destination Location Post Code");
            CheckSameValue(RouteExpLines.FieldCaption("Dest. Country/Region Code"), RouteExpLines."Dest. Country/Region Code", ExpeditionsLines."Dest. Country/Region Code");
            CheckSameValue(RouteExpLines.FieldCaption("Expedition County"), RouteExpLines."Expedition County", ExpeditionsLines."Expedition County");
        end else begin
            RouteExpLines.Init();
            RouteExpLines.Validate("Expedition No.", ExpeditionNo);
            RouteExpLines.Validate("Line No.", RouteExpLines.GetNextLineNo());
            RouteExpLines.Validate("Source Doc. Type", ExpSourceDocType);
            RouteExpLines.Validate("Location Code", ExpeditionsLines."Location Code");
            RouteExpLines.Validate("Destination Location Name", ExpeditionsLines."Destination Location Name");
            RouteExpLines.Validate("Destination Location Address", ExpeditionsLines."Destination Location Address");
            RouteExpLines.Validate("Destination Location City", ExpeditionsLines."Destination Location City");
            RouteExpLines.Validate("Destination Location Post Code", ExpeditionsLines."Destination Location Post Code");
            RouteExpLines.Validate("Dest. Country/Region Code", ExpeditionsLines."Dest. Country/Region Code");
            RouteExpLines.Validate("Expedition County", ExpeditionsLines."Expedition County");
            RouteExpLines.Validate("Unload Time", ExpeditionsLines."Unload Time");
            RouteExpLines.Validate("Stop Order", ServItemEntryJournal."Expedition Route");
            RouteExpLines."Journal Template Name" := ServItemEntryJournal."Journal Template Name";
            RouteExpLines."Journal Batch Name" := ServItemEntryJournal."Journal Batch Name";
            RouteExpLines."Journal Line No." := ServItemEntryJournal."Line No.";
            IsHandled := false;
            OE_ProcessEvents.OnBeforeInsertRouteExpeditionLineFromServItemJournal(RouteExpLines, IsHandled);
            if not IsHandled then
                RouteExpLines.Insert();
        end;
    end;


    procedure GetTransportQuantity(ServItemEntryJournal: Record "AST Serv. Item Entry Journal"): Decimal
    var
        ServiceItem: Record "AST Service Item";
        InvalidQuantityErr: Label 'The transport quantity for journal line %1 must be greater than zero.', Comment = 'ESP="La cantidad a transportar de la línea de diario %1 debe ser mayor que cero."';
    begin
        case ServItemEntryJournal.Type of
            ServItemEntryJournal.Type::"Service Item":
                begin
                    ServiceItem.Get(ServItemEntryJournal."No.");
                    if not ServiceItem.IsAux() then
                        exit(1);
                end;
            ServItemEntryJournal.Type::Item:
                ;
            else
                ServItemEntryJournal.FieldError(Type);
        end;
        if ServItemEntryJournal.Quantity <= 0 then
            Error(InvalidQuantityErr, ServItemEntryJournal."Line No.");
        exit(ServItemEntryJournal.Quantity);
    end;

    local procedure GetLastExpeditionLineNo(ExpeditionNo: Code[20]): Integer;
    var
        LastExpLines: Record "ASTEX Expeditions Lines";
    begin
        LastExpLines.SetRange("Expedition No.", ExpeditionNo);
        if LastExpLines.FindLast() then
            exit(LastExpLines."Line No." + 10000)
        else
            exit(10000);
    end;

    local procedure GetEntryType(InitialServItemBinEntryType: Enum "AST ServItemBinEntry Type"): Option
    var
        EntryType: Option Delivery,Return,Error;
    begin
        if (InitialServItemBinEntryType = InitialServItemBinEntryType::"Delivery for Sale") Or (InitialServItemBinEntryType = InitialServItemBinEntryType::"Delivery Rent Contract Start")
        OR ((InitialServItemBinEntryType = InitialServItemBinEntryType::"Delivery repair finish") Or (InitialServItemBinEntryType = InitialServItemBinEntryType::"Bin Movements")
        OR (InitialServItemBinEntryType = InitialServItemBinEntryType::"Serv. Item Change Delivery") OR (InitialServItemBinEntryType = InitialServItemBinEntryType::"Repair Change Delivery")) then
            exit(EntryType::Delivery) else
            if (InitialServItemBinEntryType = InitialServItemBinEntryType::"Return Rent Contract Finish") Or (InitialServItemBinEntryType = InitialServItemBinEntryType::"Collection return")
             OR ((InitialServItemBinEntryType = InitialServItemBinEntryType::"Repair start collection")) or (InitialServItemBinEntryType = InitialServItemBinEntryType::"Repair Change Collection") OR
             (InitialServItemBinEntryType = InitialServItemBinEntryType::"Serv. Item Change Collection") then
                exit(EntryType::Return);
        exit(EntryType::Error);
    end;

}