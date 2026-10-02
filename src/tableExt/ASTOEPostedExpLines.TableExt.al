tableextension 78354 "AST OE Posted Exp. Lines" extends "ASTEX Posted Exp. Lines"
{
    fields
    {
        field(78350; RecordId; RecordId)
        {
            DataClassification = CustomerContent;
            Caption = 'RecordId', Comment = 'ESP="RecordId"';
        }
        field(78351; Type; Enum "ASTO ServItemEntryJournal Type")
        {
            DataClassification = CustomerContent;
            Caption = 'Type', Comment = 'ESP="Tipo"';
        }
        field(78352; "No."; Code[20])
        {
            DataClassification = CustomerContent;
            Caption = 'No.', Comment = 'ESP="Nº"';
            TableRelation = if (Type = const("Service Item")) "AST Service Item"
            else if (Type = const(Item)) Item;
        }
        field(78353; Volume; Decimal)
        {
            DataClassification = CustomerContent;
            Caption = 'Volume', Comment = 'ESP="Volumen"';
        }
        field(78354; "Expedition Route"; Integer)
        {
            DataClassification = CustomerContent;
            Caption = 'Expedition Route', Comment = 'ESP="Ruta de Expedición"';
        }
    }
}