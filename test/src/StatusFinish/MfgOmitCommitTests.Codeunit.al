namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Inventory.Item;
using Microsoft.Manufacturing.Document;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Story #6 AC17/AC18: Omit Commit does not suppress BC's commit; a failing call leaves no partial status change.</summary>
codeunit 97623 "Mfg Omit Commit Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Data: Codeunit "Mfg Test Data ori";
        Lib: Codeunit "Mfg Status Test Lib ori";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Scenario_AC17_OmitCommit_StatusChangeStillRuns()
    var
        Item: Record Item;
        Order: Record "Production Order";
        Moved: Record "Production Order";
        Request: JsonObject;
        Response: JsonObject;
    begin
        Lib.PrepareOrder(Item, Order, Order.Status::Planned);
        Commit();
        Request := Lib.IdRequest(Order);
        Request.Add('newStatus', 'FirmPlanned');
        Request.Add('expectedCount', 1);

        Response := Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.ChangeStatus", Request, 1033, true);

        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'ChangeStatus runs under Omit Commit (documented as committing).');
        Lib.ReadBack(Response, Moved);
        Assert.AreEqual(Moved.Status::"Firm Planned", Moved.Status, 'The order moved.');
        Lib.Cleanup(Item."No.");
    end;

    [Test]
    procedure Scenario_AC17_AC18_OmitCommit_FailureLeavesNoPartialChange()
    var
        Item: Record Item;
        Order: Record "Production Order";
        Request: JsonObject;
        Lines: Integer;
        Routings: Integer;
        Components: Integer;
        LinesAfter: Integer;
        RoutingsAfter: Integer;
        ComponentsAfter: Integer;
    begin
        Lib.PrepareOrder(Item, Order, Order.Status::"Firm Planned");
        Lib.CountChildren(Order, Lines, Routings, Components);
        Item.Get(Item."No.");
        Item.Validate("Production Blocked", Item."Production Blocked"::Output);
        Item.Modify(true);
        Commit();
        Request := Lib.IdRequest(Order);
        Request.Add('newStatus', 'Released');
        Request.Add('expectedCount', 1);

        // Under Omit Commit the caller owns the transaction: BC's error is raised to the caller, who rolls back.
        asserterror Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.ChangeStatus", Request, 1033, true);

        Assert.ExpectedError('Production Blocked');
        Assert.IsTrue(Order.Get(Order.Status, Order."No."), 'The order keeps its old status.');
        Lib.CountChildren(Order, LinesAfter, RoutingsAfter, ComponentsAfter);
        Assert.AreEqual(Lines, LinesAfter, 'Lines intact.');
        Assert.AreEqual(Routings, RoutingsAfter, 'Routing intact.');
        Assert.AreEqual(Components, ComponentsAfter, 'Components intact.');
        Lib.Cleanup(Item."No.");
    end;
}
