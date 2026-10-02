tableextension 78352 "AST OE Serv.Item Entry Journal" extends "AST Serv. Item Entry Journal"
{
    fields
    {
        modify("Shipping Agent Code")
        {
            trigger OnAfterValidate()
            begin
                if Rec."Shipping Agent Code" <> xRec."Shipping Agent Code" then
                    Rec.Validate(Vehicle, '');
            end;
        }
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
            trigger OnValidate()
            begin
                if Rec."Transport Method" = xRec."Transport Method" then
                    exit;

                Rec.Validate("Shipping Agent Code", '');
                Rec.Validate(Vehicle, '');
            end;
        }
        field(78352; "Driver Code"; Code[20])
        {
            DataClassification = CustomerContent;
            Caption = 'Driver Code', comment = 'ESP="Código Conductor"';
            TableRelation = "ASTEX Driver"."No.";
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
            TableRelation = "ASTEX Vehicle"."No." where("Transport Method" = field("Transport Method"), "Shipping Agent Code" = field("Shipping Agent Code"));
            trigger OnValidate()
            var
                Vehicle: Record "ASTEX Vehicle";
            begin
                Rec."Truck Plate" := '';
                Rec."Trailer Plate" := '';
                Rec.Validate("Driver Code", '');
                if Rec.Vehicle = '' then
                    exit;

                if Vehicle.Get(Rec.Vehicle) then begin
                    Rec."Truck Plate" := Vehicle.Plate;
                    Rec."Trailer Plate" := Vehicle."Trailer Plate";
                    Rec.Validate("Driver Code", Vehicle."Driver Code");
                end;
            end;
        }
        field(78355; "Truck Plate"; Code[15])
        {
            DataClassification = CustomerContent;
            Caption = 'Truck Plate', comment = 'ESP="Matrícula Camión"';
        }
        field(78356; "Trailer Plate"; Code[15])
        {
            DataClassification = CustomerContent;
            Caption = 'Trailer Plate', comment = 'ESP="Matrícula Remolque"';
        }
        field(78357; "Expedition Route"; Integer)
        {
            DataClassification = CustomerContent;
            Caption = 'Expedition Route', comment = 'ESP="Ruta de Expedición"';
            MinValue = 1;
            InitValue = 1;
        }
        field(78358; "eCMR Shipment Status"; Enum "ASTEX eCMR Shipment Status")
        {
            FieldClass = FlowField;
            Caption = 'eCMR Shipment Status', comment = 'ESP="Estado envío eCMR"';
            CalcFormula = lookup("ASTEX Posted Route Ex. Lines"."eCMR Shipment Status" where("Journal Template Name" = field("Journal Template Name"), "Journal Batch Name" = field("Journal Batch Name"), "Source Expedition No." = field("Expedition No."), "Stop Order" = field("Expedition Route")));
            Editable = false;
        }
        field(78359; "Posted Route Exp. No."; Code[20])
        {
            FieldClass = FlowField;
            Caption = 'Posted Route Expedition No.', Comment = 'ESP="Nº Expedición Ruta Registrada"';
            CalcFormula = lookup("ASTEX Posted Route Ex. Lines"."Expedition No." where("Journal Template Name" = field("Journal Template Name"), "Journal Batch Name" = field("Journal Batch Name"), "Source Expedition No." = field("Expedition No."), "Stop Order" = field("Expedition Route")));
            Editable = false;
        }
        field(78360; "Posted Route Line No."; Integer)
        {
            FieldClass = FlowField;
            Caption = 'Posted Route Line No.', Comment = 'ESP="Nº Línea Ruta Registrada"';
            CalcFormula = lookup("ASTEX Posted Route Ex. Lines"."Line No." where("Journal Template Name" = field("Journal Template Name"), "Journal Batch Name" = field("Journal Batch Name"), "Source Expedition No." = field("Expedition No."), "Stop Order" = field("Expedition Route")));
            Editable = false;
        }
        field(78361; "eCMR Shipment Id"; Text[100])
        {
            FieldClass = FlowField;
            Caption = 'eCMR Shipment Id', Comment = 'ESP="Id. envío eCMR"';
            CalcFormula = lookup("ASTEX Posted Route Ex. Lines"."eCMR Shipment Id" where("Journal Template Name" = field("Journal Template Name"), "Journal Batch Name" = field("Journal Batch Name"), "Source Expedition No." = field("Expedition No."), "Stop Order" = field("Expedition Route")));
            Editable = false;
        }
    }
    keys
    {
        key(AST_OE_Key1; "Expedition Route")
        {
        }
    }
}