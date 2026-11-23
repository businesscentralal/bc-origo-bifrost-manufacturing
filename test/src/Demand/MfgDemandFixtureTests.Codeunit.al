namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Inventory.Item;
using Microsoft.Manufacturing.ProductionBOM;
using Microsoft.Manufacturing.Routing;
using Microsoft.Manufacturing.WorkCenter;
using Microsoft.Sales.Customer;
using Microsoft.Sales.Document;
using System.TestLibraries.Utilities;

/// <summary>Proves the CreateFromDemand MCP fixture seeds a released sales order and its cleanup removes all owned data.</summary>
codeunit 97649 "Mfg Demand Fixture Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    [Test]
    procedure C2_McpFixtureSeedsReleasedOrderAndCleans()
    var
        Fixture: Record "Mfg Demand MCP Fixture ori";
        SalesHeader: Record "Sales Header";
        Item: Record Item;
        Customer: Record Customer;
        Bom: Record "Production BOM Header";
        Routing: Record "Routing Header";
        WorkCenter: Record "Work Center";
        Lib: Codeunit "Mfg Demand Test Lib ori";
        Assert: Codeunit "Library Assert";
        MessageId: Guid;
        ItemNos: List of [Code[20]];
        Response: JsonObject;
    begin
        // Story #23, C2 | Time: WorkDate shipment dates | Risk: None
        Fixture.Code := 'X23MCPEN';
        Fixture.Insert(true);
        Assert.IsTrue(SalesHeader.Get(SalesHeader."Document Type"::Order, Fixture."Sales Order No."), 'Fixture sales order exists.');
        Assert.AreEqual(SalesHeader.Status::Released, SalesHeader.Status, 'Fixture sales order is released.');
        Response := Lib.Invoke(Lib.Request(SalesHeader, 'Planned', 'ItemOrder', 1), 1033, MessageId);
        ItemNos.Add(Fixture."Item No.");
        Assert.AreEqual(1, Lib.CountOrders(SalesHeader, ItemNos), 'The fixture order makes one production order.');
        Fixture.Delete(true);
        Assert.IsFalse(SalesHeader.Get(SalesHeader."Document Type"::Order, Fixture."Sales Order No."), 'Sales order removed.');
        Assert.AreEqual(0, Lib.CountOrders(SalesHeader, ItemNos), 'Production orders removed.');
        Assert.IsFalse(Item.Get(Fixture."Item No."), 'Item removed.');
        Assert.IsFalse(Item.Get(Fixture."Component No."), 'Component removed.');
        Assert.IsFalse(Customer.Get(Fixture."Customer No."), 'Customer removed.');
        Assert.IsFalse(Bom.Get(Fixture."Production BOM No."), 'BOM removed.');
        Assert.IsFalse(Routing.Get(Fixture."Routing No."), 'Routing removed.');
        Assert.IsFalse(WorkCenter.Get(Fixture."Work Center No."), 'Work center removed.');
    end;
}
