tableextension 78351 "AST OE Expedition Setup" extends "ASTEX Expedition Setup"
{
    fields
    {
        field(78350; "Default Transport Method"; Code[10])
        {
            Caption = 'Default Transport Method', comment = 'ESP="Método Transporte Defecto"';
            DataClassification = CustomerContent;
            TableRelation = "Transport Method".Code where("ASTEX Expedition Required" = const(true));
        }
        field(78351; "ServItem Journ. AutoPost Exp."; Boolean)
        {
            Caption = 'Auto Post Expedition from Services', comment = 'ESP="Registro automático de expedición desde Servicios"';
            DataClassification = CustomerContent;
        }
    }
}