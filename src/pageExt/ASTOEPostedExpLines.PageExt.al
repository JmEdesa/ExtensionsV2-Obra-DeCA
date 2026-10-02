pageextension 78355 "AST OE Posted Exp. Lines" extends "ASTEX Posted Exp. Lines"
{
    layout
    {
        addfirst(Control1)
        {
            field(Type; Rec.Type)
            {
                ApplicationArea = All;
                Editable = false;
                ToolTip = 'Specifies whether the line transports an item or a service item.', Comment = 'ESP="Especifica si la línea transporta un producto o un producto de servicio."';
                Visible = ServiceItemContext;
            }
            field("No."; Rec."No.")
            {
                ApplicationArea = All;
                Editable = false;
                ToolTip = 'Specifies the item or service item number.', Comment = 'ESP="Especifica el número de producto o producto de servicio."';
                Visible = ServiceItemContext;
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        ServiceItemContext := Rec."Source Doc. Type" in [Rec."Source Doc. Type"::"Service Delivery", Rec."Source Doc. Type"::"Service Pickup"];
    end;

    var
        ServiceItemContext: Boolean;
}