pageextension 78352 "AST OE Expedition Lines" extends "ASTEX Expedition Lines"
{
    layout
    {
        addafter("Sales Order Line No.")
        {
            field(Type; Rec.Type)
            {
                Editable = false;
                ApplicationArea = All;
                ToolTip = 'Specifies whether the line transports an item or a service item.', Comment = 'ESP="Especifica si la línea transporta un producto o un producto de servicio."';
            }
            field("No."; Rec."No.")
            {
                Editable = false;
                ApplicationArea = All;
                ToolTip = 'Specifies the item or service item number.', Comment = 'ESP="Especifica el número de producto o producto de servicio."';
            }
        }
        addafter("Gross Weight")
        {
            field(Volume; Rec.Volume)
            {
                Editable = false;
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Volume field.', Comment = 'ESP="Volumen"';
            }
        }
    }
}