namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Inventory.Item;
using Microsoft.Manufacturing.Document;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Proves Omit Commit does not commit a successful Create or Refresh before the caller aborts.</summary>
codeunit 97610 "Mfg ProdOrder Rollback Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Data: Codeunit "Mfg Test Data ori";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Scenario_AC13_Create_CallerRollbackRemovesHeader()
    var
        Item: Record Item;
        Order: Record "Production Order";
        Request: JsonObject;
    begin
        // Story #5 AC13: committed fixture precedes the deliberately rolled-back call.
        Data.SetupNumbering(true);
        Data.CreateItem(Item);
        Request := Data.CreateRequest(Item."No.");
        Request.Add('no', 'X-ROLLBACK-CREATE');
        Commit();
        asserterror CreateAndAbort(Request);
        Assert.ExpectedError('X caller rollback after successful create');
        Assert.IsFalse(Order.Get(Order.Status::Planned, 'X-ROLLBACK-CREATE'), 'Create must remain inside caller transaction.');
    end;

    [Test]
    procedure Scenario_AC13_Refresh_CallerRollbackRemovesLines()
    var
        Item: Record Item;
        Order: Record "Production Order";
        Line: Record "Prod. Order Line";
        Request: JsonObject;
    begin
        // Story #5 AC13: committed planning header survives; uncommitted refresh rows must not.
        Data.SetupNumbering(false);
        Data.CreateManufacturedItem(Item);
        Data.CreateOrder(Order, Item, Order.Status::Planned);
        Request.Add('systemId', Format(Order.SystemId, 0, 4));
        Commit();
        asserterror RefreshAndAbort(Request);
        Assert.ExpectedError('X caller rollback after successful refresh');
        Line.SetRange(Status, Order.Status);
        Line.SetRange("Prod. Order No.", Order."No.");
        Assert.IsTrue(Line.IsEmpty(), 'Refresh lines must remain inside caller transaction.');
    end;

    local procedure CreateAndAbort(Request: JsonObject)
    var
        Response: JsonObject;
    begin
        Response := Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Create", Request, 1033, true);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Create succeeded before caller rollback.');
        Error('X caller rollback after successful create');
    end;

    local procedure RefreshAndAbort(Request: JsonObject)
    var
        Response: JsonObject;
    begin
        Response := Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Refresh", Request, 1033, true);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Refresh succeeded before caller rollback.');
        Assert.IsTrue(Data.NumberValue(Response, 'componentCount') > 0, 'Refresh actually created components before rollback.');
        Error('X caller rollback after successful refresh');
    end;
}
