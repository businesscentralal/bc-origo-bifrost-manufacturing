namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Inventory.Item;
using Microsoft.Manufacturing.Document;
using Microsoft.Manufacturing.ProductionBOM;
using Microsoft.Manufacturing.Routing;
using Microsoft.Manufacturing.Capacity;
using Microsoft.Manufacturing.WorkCenter;
using Microsoft.Sales.Customer;
using Microsoft.Sales.Document;

/// <summary>Own-tenant raw MCP fixture for CreateFromDemand: inserting seeds an owned released sales order, deleting removes every record it and the call created; no product operation is added.</summary>
table 97646 "Mfg Demand MCP Fixture ori"
{
    DataClassification = CustomerContent;
    Caption = 'Demand MCP fixture', Locked = true;

    fields
    {
        field(1; Code; Code[10])
        {
            Caption = 'Code', Locked = true;
        }
        field(2; "Sales Order No."; Code[20])
        {
            Caption = 'Sales order no.', Locked = true;
            Editable = false;
        }
        field(3; "Item No."; Code[20])
        {
            Caption = 'Item no.', Locked = true;
            Editable = false;
        }
        field(4; "Component No."; Code[20])
        {
            Caption = 'Component no.', Locked = true;
            Editable = false;
        }
        field(5; "Customer No."; Code[20])
        {
            Caption = 'Customer no.', Locked = true;
            Editable = false;
        }
        field(6; "Production BOM No."; Code[20])
        {
            Caption = 'Production BOM no.', Locked = true;
            Editable = false;
        }
        field(7; "Routing No."; Code[20])
        {
            Caption = 'Routing no.', Locked = true;
            Editable = false;
        }
        field(8; "Work Center No."; Code[20])
        {
            Caption = 'Work center no.', Locked = true;
            Editable = false;
        }
    }
    keys
    {
        key(PK; Code)
        {
            Clustered = true;
        }
    }

    trigger OnInsert()
    var
        Item: Record Item;
        Bom: Record "Production BOM Line";
        RoutingLine: Record "Routing Line";
        SalesHeader: Record "Sales Header";
        Lib: Codeunit "Mfg Demand Test Lib ori";
        ItemNos: List of [Code[20]];
    begin
        if not (Code in ['X23MCPEN', 'X23MCPIS']) then
            Error('Only issue 23 MCP fixtures are allowed.');
        Lib.CreateManufacturedItem(Item);
        "Item No." := Item."No.";
        "Production BOM No." := Item."Production BOM No.";
        "Routing No." := Item."Routing No.";
        Bom.SetRange("Production BOM No.", Item."Production BOM No.");
        Bom.SetRange(Type, Bom.Type::Item);
        if Bom.FindFirst() then
            "Component No." := Bom."No.";
        RoutingLine.SetRange("Routing No.", Item."Routing No.");
        RoutingLine.SetRange(Type, RoutingLine.Type::"Work Center");
        if RoutingLine.FindFirst() then
            "Work Center No." := RoutingLine."No.";
        ItemNos.Add(Item."No.");
        Lib.CreateSalesOrder(SalesHeader, ItemNos, true);
        "Sales Order No." := SalesHeader."No.";
        "Customer No." := SalesHeader."Sell-to Customer No.";
    end;

    trigger OnDelete()
    var
        SalesHeader: Record "Sales Header";
        Item: Record Item;
        BomHeader: Record "Production BOM Header";
        BomLine: Record "Production BOM Line";
        RoutingHeader: Record "Routing Header";
        RoutingLine: Record "Routing Line";
        WorkCenter: Record "Work Center";
        CalendarEntry: Record "Calendar Entry";
        Customer: Record Customer;
        Lib: Codeunit "Mfg Demand Test Lib ori";
        ItemNos: List of [Code[20]];
    begin
        SalesHeader."Document Type" := SalesHeader."Document Type"::Order;
        SalesHeader."No." := "Sales Order No.";
        ItemNos.Add("Item No.");
        Lib.Cleanup(SalesHeader, ItemNos);
        if Item.Get("Item No.") then
            Item.Delete(true);
        BomLine.SetRange("Production BOM No.", "Production BOM No.");
        BomLine.DeleteAll(false);
        if BomHeader.Get("Production BOM No.") then
            BomHeader.Delete(false);
        if Item.Get("Component No.") then
            Item.Delete(true);
        RoutingLine.SetRange("Routing No.", "Routing No.");
        RoutingLine.DeleteAll(false);
        if RoutingHeader.Get("Routing No.") then
            RoutingHeader.Delete(false);
        CalendarEntry.SetRange("Capacity Type", CalendarEntry."Capacity Type"::"Work Center");
        CalendarEntry.SetRange("No.", "Work Center No.");
        CalendarEntry.DeleteAll(false);
        if WorkCenter.Get("Work Center No.") then
            WorkCenter.Delete(false);
        if Customer.Get("Customer No.") then
            Customer.Delete(true);
    end;
}
