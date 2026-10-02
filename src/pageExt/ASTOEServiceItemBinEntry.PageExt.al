pageextension 78353 "AST OE Service Item Bin Entry" extends "ASTO PostServMgtAssistJournal"
{
    layout
    {
        addlast(Control1000000000)
        {
            field("Expedition No."; Rec."Expedition No.")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Expedition No. field.', Comment = 'ESP="Nº Expedición"';
                Editable = False;
            }
            field("Expedition Route"; Rec."Expedition Route")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Expedition Route field.', Comment = 'ESP="Ruta de Expedición"';
            }
            field("Transport Method"; Rec."Transport Method")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Transport Method field.', Comment = 'ESP="Método Transporte"';
            }
            field("Driver Code"; Rec."Driver Code")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Driver Code field.', Comment = 'ESP="Código Conductor"';
            }
            field("Driver Name"; Rec."Driver Name")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Driver Name field.', Comment = 'ESP="Nombre Conductor"';
            }
            field("Vehicle"; Rec."Vehicle")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Vehicle Code field.', Comment = 'ESP="Código Vehículo"';
            }
            field("Truck Plate"; Rec."Truck Plate")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Truck Plate field.', Comment = 'ESP="Matrícula Camión"';
            }
            field("Trailer Plate"; Rec."Trailer Plate")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Trailer Plate field.', Comment = 'ESP="Matrícula Remolque"';
            }
        }
    }
    actions
    {
        addlast("&Entry")
        {
            action(ASTEXShowExpeditions)
            {
                ToolTip = 'Show Expeditions', comment = 'ESP="Ver Expedicion"';
                Caption = 'Show Expeditions', comment = 'ESP="Mostrar Expedicion"';
                ApplicationArea = All;
                Image = List;
                PromotedOnly = true;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
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
}