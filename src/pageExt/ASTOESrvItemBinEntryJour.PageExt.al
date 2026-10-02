pageextension 78350 "AST OE SrvItem Bin Entry Jour." extends "ASTO Serv. Mgt. Assist Journal"
{
    layout
    {
        addlast(Control1000000002)
        {
            field("Transport Method"; Rec."Transport Method")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Transport Method field.', Comment = '%ESP="Método Transporte"';
            }
        }
        moveafter("Transport Method"; "Shipping Agent Code")
        addafter("Shipping Agent Code")
        {
            field("Vehicle"; Rec."Vehicle")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Vehicle Code field.', Comment = '%ESP="Código Vehículo"';
            }
            field("Truck Plate"; Rec."Truck Plate")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Truck Plate field.', Comment = '%ESP="Matrícula Camión"';
            }
            field("Trailer Plate"; Rec."Trailer Plate")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Trailer Plate field.', Comment = '%ESP="Matrícula Remolque"';
            }
            field("Driver Code"; Rec."Driver Code")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Driver Code field.', Comment = '%ESP="Código Conductor"';
            }
            field("Driver Name"; Rec."Driver Name")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Driver Name field.', Comment = '%ESP="Nombre Conductor"';
            }
            field("eCMR Shipment Status"; Rec."eCMR Shipment Status")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the eCMR shipment status for this expedition.', Comment = 'ESP="Estado del envío eCMR de esta expedición."';
            }
            field("Expedition No."; Rec."Expedition No.")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Expedition No. field.', Comment = 'ESP="Nº Expedición"';
                Editable = False;
                StyleExpr = ExpeditionStyleExpr;
            }
            field("Expedition Route"; Rec."Expedition Route")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Expedition Route field.', Comment = '%ESP="Ruta de Expedición"';
            }
        }
        addfirst(FactBoxes)
        {
            part(RouteMap; "ASTEX Route Map FactBox")
            {
                ApplicationArea = All;
                Caption = 'Map', Comment = 'ESP="Mapa"';
                SubPageLink = "Expedition No." = field("Posted Route Exp. No."), "Line No." = field("Posted Route Line No.");
            }
            part(ECMRDocuments; "ASTEX eCMR Documents FactBox")
            {
                ApplicationArea = All;
                Caption = 'eCMR Documents', Comment = 'ESP="Documentos eCMR"';
                SubPageLink = "Shipment Id" = field("eCMR Shipment Id");
            }
        }
    }
    actions
    {
        addafter("Post")
        {
            action(ALQEXCreateExpedition)
            {
                Caption = 'Create Expedition', comment = 'ESP="Crear Expedición"';
                ApplicationArea = All;
                Image = TransferReceipt;
                ToolTip = 'Executes the Create Expedition action.';
                Promoted = true;
                trigger OnAction()
                var
                    ServItemEntryJournal: Record "AST Serv. Item Entry Journal";
                begin
                    CurrPage.SetSelectionFilter(ServItemEntryJournal);
                    if ServItemEntryJournal.Count > 1 then begin
                        ALQExpeditionsMgt.TestServItemJournalLine(ServItemEntryJournal);
                        ALQExpeditionsMgt.CreateExpeditionFromServItemBinEntry(ServItemEntryJournal);
                    end else begin
                        ALQExpeditionsMgt.TestServItemJournalLine(Rec);
                        ALQExpeditionsMgt.CreateExpeditionFromServItemBinEntry(Rec);
                    end;
                end;
            }
            action(ASTEXShowExpeditions)
            {
                ToolTip = 'Show Expeditions', comment = 'ESP="Ver Expedicion"';
                Caption = 'Show Expeditions', comment = 'ESP="Mostrar Expedicion"';
                ApplicationArea = All;
                Image = List;
                Promoted = true;
                trigger OnAction()
                var
                    Expeditions: Record "ASTEX Expedition";
                    PostedExpedition: Record "ASTEX Posted Expedition";
                    ExpeditionNotFoundErr: Label 'No expedition was found for journal entry %1.', Comment = 'ESP="No se encontró ninguna expedición para la línea de diario %1."';
                begin
                    if Expeditions.Get(Rec."Expedition No.") then begin
                        Page.Run(Page::"ASTEX Expedition Card", Expeditions);
                        exit;
                    end;

                    // El número registrado puede ser distinto del número de
                    // origen; por eso se prueba primero por el número directo
                    // y después por "Source Expedition No.".
                    if PostedExpedition.Get(Rec."Expedition No.") then begin
                        Page.Run(Page::"ASTEX Posted Expedition", PostedExpedition);
                        exit;
                    end;

                    PostedExpedition.Reset();
                    PostedExpedition.SetRange("Source Expedition No.", Rec."Expedition No.");
                    if PostedExpedition.FindFirst() then begin
                        Page.Run(Page::"ASTEX Posted Expedition", PostedExpedition);
                        exit;
                    end;

                    Error(ExpeditionNotFoundErr, Rec."Expedition No.");
                end;
            }
        }
    }


    trigger OnAfterGetRecord()
    var
        Expedition: Record "ASTEX Expedition";
        PostedExpedition: Record "ASTEX Posted Expedition";
    begin
        ExpeditionStyleExpr := 'None';
        if Rec."Expedition No." = '' then
            exit;

        if Expedition.Get(Rec."Expedition No.") then begin
            ExpeditionStyleExpr := 'Attention';
            exit;
        end;

        PostedExpedition.SetRange("Source Expedition No.", Rec."Expedition No.");
        if not PostedExpedition.IsEmpty() then
            ExpeditionStyleExpr := 'Favorable';
    end;

    trigger OnAfterGetCurrRecord()
    begin
        Rec.CalcFields("Posted Route Exp. No.", "Posted Route Line No.", "eCMR Shipment Id");
        // La FactBox usa tabla temporal: SubPageLink no la rellena.
        CurrPage.ECMRDocuments.Page.LoadDocuments(Rec."eCMR Shipment Id");
    end;

    var
        ALQExpeditionsMgt: Codeunit "AST OE Expeditions Mgt.";
        ExpeditionStyleExpr: Text[10];
}