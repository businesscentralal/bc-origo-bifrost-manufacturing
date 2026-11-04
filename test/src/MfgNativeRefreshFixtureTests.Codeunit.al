namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Inventory.Item;
using Microsoft.Manufacturing.Document;
using System.TestLibraries.Utilities;

/// <summary>Separately proves fixture validity through the native report outside the caller rollback contract.</summary>
codeunit 97615 "Mfg Native Refresh Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    [Test]
    procedure NativeRefresh_CommittedFixtureCreatesLine()
    var
        Item: Record Item;
        Order: Record "Production Order";
        Line: Record "Prod. Order Line";
        Data: Codeunit "Mfg Test Data ori";
        Manufacturing: Codeunit "Library - Manufacturing";
        Assert: Codeunit "Library Assert";
    begin
        // Microsoft's helper commits the fixture and restores the transaction type after the report.
        // The original dispatcher and caller-rollback tests remain separate and unchanged.
        Data.SetupNumbering(false);
        Data.CreateManufacturedItem(Item);
        Data.CreateOrder(Order, Item, Order.Status::Planned);
        Manufacturing.RefreshProdOrder(Order, false, true, true, true, false);
        Line.SetRange(Status, Order.Status);
        Line.SetRange("Prod. Order No.", Order."No.");
        Assert.AreEqual(1, Line.Count(), 'Native refresh creates the manufactured-item line.');
        Data.CleanupOrders(Item."No.");
    end;
}
