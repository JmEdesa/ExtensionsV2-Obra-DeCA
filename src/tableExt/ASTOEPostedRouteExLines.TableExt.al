tableextension 78357 "AST OE Posted Route Ex. Lines" extends "ASTEX Posted Route Ex. Lines"
{
    fields
    {
        field(78350; "Journal Template Name"; Code[10])
        {
            Caption = 'Journal Template Name', Comment = 'ESP="Nombre libro diario"';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(78351; "Journal Batch Name"; Code[10])
        {
            Caption = 'Journal Batch Name', Comment = 'ESP="Nombre sección diario"';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(78352; "Journal Line No."; Integer)
        {
            Caption = 'Journal Line No.', Comment = 'ESP="Nº línea diario"';
            DataClassification = CustomerContent;
            Editable = false;
        }
    }
}
