tableextension 78353 "AST OE Expeditions Lines" extends "ASTEX Expeditions Lines"
{
    fields
    {
        field(78350; RecordId; RecordId)
        {
            DataClassification = CustomerContent;
            Caption = 'RecordId', comment = 'ESP="RecordId"';
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
            Caption = 'Volume', Comment = 'ITA="Volume",ESP="Volumen"';
            DataClassification = CustomerContent;
        }
        field(78354; "Expedition Route"; Integer)
        {
            DataClassification = CustomerContent;
            Caption = 'Expedition Route', Comment = 'ESP="Ruta de Expedición"';
        }
    }
}