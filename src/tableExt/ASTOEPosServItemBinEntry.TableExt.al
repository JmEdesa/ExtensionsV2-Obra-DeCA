tableextension 78350 "AST OE Pos. ServItem Bin Entry" extends "AST Posted ServItem Bin Entry"
{
    fields
    {
        field(78350; "Expedition No."; Code[20])
        {
            Caption = 'Expedition No.', comment = 'ESP="Nº Expedición"';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(78351; "Transport Method"; Code[10])
        {
            Caption = 'Transport Method', comment = 'ESP="Método Transporte"';
            DataClassification = CustomerContent;
            TableRelation = "Transport Method".Code where("ASTEX Expedition Required" = const(true));
            Editable = false;
        }
        field(78352; "Driver Code"; Code[20])
        {
            DataClassification = CustomerContent;
            Caption = 'Driver Code', comment = 'ESP="Código Conductor"';
            TableRelation = "ASTEX Driver"."No.";
            Editable = false;
        }
        field(78353; "Driver Name"; Text[100])
        {
            FieldClass = FlowField;
            CalcFormula = lookup("ASTEX Driver".Name where("No." = field("Driver Code")));
            Caption = 'Driver Name', comment = 'ESP="Nombre Conductor"';
            Editable = False;
        }
        field(78354; "Vehicle"; Code[20])
        {
            DataClassification = CustomerContent;
            Caption = 'Vehicle', comment = 'ESP="Vehículo"';
            TableRelation = "ASTEX Vehicle"."No.";
            Editable = false;
        }
        field(78355; "Truck Plate"; Code[15])
        {
            DataClassification = CustomerContent;
            Caption = 'Truck Plate', comment = 'ESP="Matrícula Camión"';
            Editable = false;
        }
        field(78356; "Trailer Plate"; Code[15])
        {
            DataClassification = CustomerContent;
            Caption = 'Trailer Plate', comment = 'ESP="Matrícula Remolque"';
            Editable = false;
        }
        field(78357; "Expedition Route"; Integer)
        {
            DataClassification = CustomerContent;
            Caption = 'Expedition Route', comment = 'ESP="Ruta de Expedición"';
            Editable = false;
        }
    }

}