pageextension 78351 "AST OE Expedition Setup" extends "ASTEX Expedition Setup"
{
    layout
    {
        addlast(General)
        {
            field("Default Transport Method"; Rec."Default Transport Method")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Default Transport Method field.', Comment = 'ESP="Método Transporte Defecto"';
            }
        }
        addafter("ASTEX Return AutoPost Exp.")
        {
            field("ServItem Journ. AutoPost Exp."; Rec."ServItem Journ. AutoPost Exp.")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Auto Post Expedition from Services field.', Comment = 'ESP="Registro automático de expedición desde Servicios"';
            }
        }
    }
}