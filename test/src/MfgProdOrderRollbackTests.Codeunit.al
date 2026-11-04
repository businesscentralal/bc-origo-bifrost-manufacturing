namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Inventory.Item;
using Microsoft.Manufacturing.Document;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Proves Create caller rollback and the committing Refresh Omit Commit refusal.</summary>
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
    procedure Scenario_AC13_Refresh_OmitCommitRefusedBeforeWrites()
    var
        Item: Record Item;
        Order: Record "Production Order";
        Line: Record "Prod. Order Line";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Gunnar 04 Nov: Refresh always commits; Omit Commit must refuse before writes.
        Data.SetupNumbering(false);
        Data.CreateManufacturedItem(Item);
        Data.CreateOrder(Order, Item, Order.Status::Planned);
        Request.Add('systemId', Format(Order.SystemId, 0, 4));
        Commit();
        Response := Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Refresh", Request, 1033, true);
        Data.AssertRefusal(Response, 'PreconditionFailed');
        Assert.IsTrue(Data.TextValue(Response, 'error').Contains('always commits'), 'English refusal names the committing contract.');
        Response := Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Refresh", Request, 1039, true);
        Data.AssertRefusal(Response, 'PreconditionFailed');
        Assert.IsTrue(Data.TextValue(Response, 'error').Contains('staðfestir alltaf'), 'Icelandic refusal names the committing contract.');
        Line.SetRange(Status, Order.Status);
        Line.SetRange("Prod. Order No.", Order."No.");
        Assert.IsTrue(Line.IsEmpty(), 'Omit Commit refusal must not create any refresh lines.');
    end;

    local procedure CreateAndAbort(Request: JsonObject)
    var
        Response: JsonObject;
    begin
        Response := Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Create", Request, 1033, true);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Create succeeded before caller rollback.');
        Error('X caller rollback after successful create');
    end;

}
