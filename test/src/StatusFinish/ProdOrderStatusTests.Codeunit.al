namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Inventory.Item;
using Microsoft.Manufacturing.Document;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Story #6 AC01-AC06: Manufacturing.ProductionOrder.ChangeStatus through the public dispatcher.</summary>
codeunit 97620 "Prod Order Status Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Data: Codeunit "Mfg Test Data ori";
        Lib: Codeunit "Mfg Status Test Lib ori";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Scenario_AC01_PlannedToFirmPlanned_MovesOrderAndChildren()
    var
        Item: Record Item;
        Order: Record "Production Order";
        Moved: Record "Production Order";
        Old: Record "Production Order";
        Response: JsonObject;
        LinesBefore: Integer;
        RoutingsBefore: Integer;
        ComponentsBefore: Integer;
        LinesAfter: Integer;
        RoutingsAfter: Integer;
        ComponentsAfter: Integer;
    begin
        Lib.PrepareOrder(Item, Order, Order.Status::Planned);
        Lib.CountChildren(Order, LinesBefore, RoutingsBefore, ComponentsBefore);
        Commit();

        Response := Lib.ChangeStatus(Order, 'FirmPlanned', 1, 1033);

        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'ChangeStatus succeeds.');
        Assert.AreEqual('Planned', Data.TextValue(Response, 'fromStatus'), 'fromStatus');
        Assert.AreEqual('FirmPlanned', Data.TextValue(Response, 'toStatus'), 'toStatus');
        Assert.AreEqual(Order."No.", Data.TextValue(Response, 'oldNo'), 'oldNo');
        Lib.ReadBack(Response, Moved);
        Assert.AreEqual(Moved.Status::"Firm Planned", Moved.Status, 'The order is Firm Planned.');
        Assert.AreEqual(Moved."No.", Data.TextValue(Response, 'no'), 'no');
        Assert.AreNotEqual(Format(Order.SystemId, 0, 4), Data.TextValue(Response, 'systemId'), 'A new SystemId is returned.');
        Assert.IsFalse(Old.Get(Order.Status, Order."No."), 'The old Planned record is gone.');
        Lib.CountChildren(Moved, LinesAfter, RoutingsAfter, ComponentsAfter);
        Assert.AreEqual(LinesBefore, LinesAfter, 'Lines moved.');
        Assert.AreEqual(RoutingsBefore, RoutingsAfter, 'Routing moved.');
        Assert.AreEqual(ComponentsBefore, ComponentsAfter, 'Components moved.');
        Assert.IsTrue(LinesAfter > 0, 'The fixture has lines.');
        Lib.Cleanup(Item."No.");
    end;

    [Test]
    procedure Scenario_AC02_AC03_FirmPlannedToReleased_SameSeriesNoForwardFlushing()
    var
        Item: Record Item;
        Order: Record "Production Order";
        Moved: Record "Production Order";
        Response: JsonObject;
    begin
        // The fixture flushes Backward, so release posts no Item Ledger Entry; Data.SetupNumbering
        // configures no Released series, so BC keeps the number (same series case of AC03).
        Lib.PrepareOrder(Item, Order, Order.Status::"Firm Planned");
        Commit();

        Response := Lib.ChangeStatus(Order, 'Released', 1, 1033);

        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Release succeeds.');
        Lib.ReadBack(Response, Moved);
        Assert.AreEqual(Moved.Status::Released, Moved.Status, 'The order is Released.');
        Assert.AreEqual(0, Data.NumberValue(Response, 'postedItemEntries'), 'No forward flushing posts nothing.');
        Assert.AreEqual(Data.TextValue(Response, 'oldNo') <> Data.TextValue(Response, 'no'), Lib.ResponseContains(Response, '"numberChanged":true'), 'numberChanged agrees with no and oldNo.');
        Assert.AreNotEqual(Format(Order.SystemId, 0, 4), Data.TextValue(Response, 'systemId'), 'SystemId is new even when the number is unchanged.');
        Lib.Cleanup(Item."No.");
    end;

    [Test]
    procedure Scenario_AC04_RefusedTargets_ChangeNothing()
    var
        Item: Record Item;
        Order: Record "Production Order";
        Response: JsonObject;
        Target: Text;
        Names: List of [Text];
    begin
        Lib.PrepareOrder(Item, Order, Order.Status::"Firm Planned");
        Commit();

        Response := Lib.ChangeStatus(Order, 'Finished', 1, 1033);
        Data.AssertRefusal(Response, 'InvalidParameter');
        Assert.AreEqual('newStatus', Data.TextValue(Response, 'parameter'), 'Refusal names newStatus.');
        Assert.IsTrue(Data.TextValue(Response, 'error').Contains('Manufacturing.ProductionOrder.Finish'), 'Finished points at Finish.');
        Names.Add('Planned');
        Names.Add('Simulated');
        Names.Add('FirmPlanned');
        Names.Add('Closed');
        foreach Target in Names do begin
            Response := Lib.ChangeStatus(Order, Target, 1, 1033);
            Data.AssertRefusal(Response, 'InvalidParameter');
            Assert.AreEqual('newStatus', Data.TextValue(Response, 'parameter'), 'Refusal names newStatus for ' + Target);
        end;
        Assert.IsTrue(Order.Get(Order.Status, Order."No."), 'The order is unchanged.');
        Lib.Cleanup(Item."No.");
    end;

    [Test]
    procedure Scenario_AC05_Confirmation_RequiredMismatchAndSettingOff()
    var
        Item: Record Item;
        Order: Record "Production Order";
        Moved: Record "Production Order";
        Response: JsonObject;
    begin
        Lib.PrepareOrder(Item, Order, Order.Status::Planned);
        Lib.SetConfirmRequired(true);
        Commit();

        Response := Lib.ChangeStatus(Order, 'FirmPlanned', -1, 1033);
        Data.AssertRefusal(Response, 'ConfirmationRequired');
        Assert.IsTrue(Data.TextValue(Response, 'error').Contains(Order."No."), 'The summary names the order.');
        Assert.IsTrue(Data.TextValue(Response, 'error').Contains('Planned to FirmPlanned'), 'The summary names the move.');
        Assert.IsTrue(Order.Get(Order.Status, Order."No."), 'Nothing changed after ConfirmationRequired.');

        Response := Lib.ChangeStatus(Order, 'FirmPlanned', 2, 1033);
        Data.AssertRefusal(Response, 'ConfirmationMismatch');
        Assert.IsTrue(Order.Get(Order.Status, Order."No."), 'Nothing changed after ConfirmationMismatch.');

        Lib.SetConfirmRequired(false);
        Commit();
        Response := Lib.ChangeStatus(Order, 'FirmPlanned', 3, 1033);
        Data.AssertRefusal(Response, 'ConfirmationMismatch');
        Response := Lib.ChangeStatus(Order, 'FirmPlanned', -1, 1033);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'With the setting off, omission runs the type.');
        Lib.ReadBack(Response, Moved);
        Assert.AreEqual(Moved.Status::"Firm Planned", Moved.Status, 'The order moved.');
        Lib.SetConfirmRequired(true);
        Lib.Cleanup(Item."No.");
    end;

    [Test]
    procedure Scenario_AC06_ProductionBlockedOutput_BusinessCentralErrorRollsBack()
    var
        Item: Record Item;
        Order: Record "Production Order";
        Response: JsonObject;
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

        Response := Lib.ChangeStatus(Order, 'Released', 1, 1033);

        Data.AssertRefusal(Response, 'BusinessCentralError');
        Assert.IsTrue(Order.Get(Order.Status, Order."No."), 'The order keeps its status.');
        Lib.CountChildren(Order, LinesAfter, RoutingsAfter, ComponentsAfter);
        Assert.AreEqual(Lines, LinesAfter, 'Lines intact.');
        Assert.AreEqual(Routings, RoutingsAfter, 'Routing intact.');
        Assert.AreEqual(Components, ComponentsAfter, 'Components intact.');
        Lib.Cleanup(Item."No.");
    end;

    [Test]
    procedure Scenario_AC15_InvalidMove_AnswersInIcelandic()
    var
        Item: Record Item;
        Order: Record "Production Order";
        Response: JsonObject;
    begin
        Lib.PrepareOrder(Item, Order, Order.Status::"Firm Planned");
        Commit();
        Response := Lib.ChangeStatus(Order, 'Finished', 1, 1039);
        Data.AssertRefusal(Response, 'InvalidParameter');
        Assert.AreEqual('Notaðu Manufacturing.ProductionOrder.Finish til að ljúka pöntun.', Data.TextValue(Response, 'error'), 'Icelandic refusal text.');
        Response := Lib.ChangeStatus(Order, 'Planned', 1, 1039);
        Assert.AreEqual('Sendu FirmPlanned eða Released sem newStatus.', Data.TextValue(Response, 'nextStep'), 'Icelandic nextStep.');
        Lib.Cleanup(Item."No.");
    end;
}
