namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Inventory.Item;
using Microsoft.Manufacturing.Document;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Story #6 AC07-AC12: Finish and CheckFinish through the public dispatcher.</summary>
codeunit 97621 "Prod Order Finish Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Data: Codeunit "Mfg Test Data ori";
        Lib: Codeunit "Mfg Status Test Lib ori";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Scenario_AC08_AC12_MissingOutput_RefusedThenAcknowledged()
    var
        Item: Record Item;
        Order: Record "Production Order";
        Finished: Record "Production Order";
        Check: JsonObject;
        Response: JsonObject;
        Request: JsonObject;
    begin
        PrepareReleased(Item, Order);

        Check := Lib.CheckFinish(Order, 1033);
        Assert.AreEqual('Success', Data.TextValue(Check, 'status'), 'CheckFinish runs.');
        Assert.IsTrue(Lib.ResponseContains(Check, '"kind":"missingOutput"'), 'CheckFinish warns about missing output.');
        Assert.IsTrue(Lib.ResponseContains(Check, '"canFinish":true'), 'Warnings do not block.');
        Assert.AreEqual(1, Lib.ArrayValue(Check, 'lines').Count(), 'CheckFinish lists the line.');
        Assert.IsTrue(Lib.ArrayValue(Check, 'components').Count() > 0, 'CheckFinish lists components.');

        Request := Lib.IdRequest(Order);
        Request.Add('expectedCount', 1);
        Response := Lib.Finish(Request, 1033);
        Assert.AreEqual('Error', Data.TextValue(Response, 'status'), 'Unacknowledged missing output is refused.');
        Assert.IsTrue(Lib.ResponseContains(Response, 'PreconditionFailed'), 'PreconditionFailed');
        Assert.IsTrue(Lib.ResponseContains(Response, 'missingOutput'), 'The refusal lists missingOutput (parity with CheckFinish).');
        Assert.IsTrue(Order.Get(Order.Status, Order."No."), 'Nothing changed.');

        Request.Add('acceptMissingOutput', true);
        Request.Add('acceptMissingConsumption', true);
        Request.Add('postingDate', Format(WorkDate(), 0, 9));
        Response := Lib.Finish(Request, 1033);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Acknowledged Finish succeeds.');
        Lib.ReadBack(Response, Finished);
        Assert.AreEqual(Finished.Status::Finished, Finished.Status, 'The order is Finished.');
        Assert.AreEqual(Format(WorkDate(), 0, 9), Data.TextValue(Response, 'finishedDate'), 'Finished Date = posting date.');
        Assert.IsTrue(Lib.ResponseContains(Response, '"acknowledgedWarnings":["missingOutput"'), 'Acknowledged warnings are listed.');
        Assert.AreEqual(1, Lib.ArrayValue(Response, 'lines').Count(), 'Finish lists the lines.');
        Lib.Cleanup(Item."No.");
    end;

    [Test]
    procedure Scenario_AC11_NotReleased_And_NoExpectedCount()
    var
        Item: Record Item;
        Order: Record "Production Order";
        Check: JsonObject;
        Response: JsonObject;
        Request: JsonObject;
    begin
        Lib.PrepareOrder(Item, Order, Order.Status::"Firm Planned");
        Lib.SetConfirmRequired(true);
        Commit();
        Request := Lib.IdRequest(Order);
        Request.Add('expectedCount', 1);
        Response := Lib.Finish(Request, 1033);
        Assert.AreEqual('Error', Data.TextValue(Response, 'status'), 'A Firm Planned order cannot be finished.');
        Assert.IsTrue(Lib.ResponseContains(Response, 'Only a Released order can be finished.'), 'Not released text.');
        Check := Lib.CheckFinish(Order, 1033);
        Assert.IsTrue(Lib.ResponseContains(Check, '"code":"NotReleased"'), 'CheckFinish reports NotReleased (parity).');
        Assert.IsTrue(Lib.ResponseContains(Check, '"canFinish":false'), 'canFinish is false.');
        Lib.Cleanup(Item."No.");

        PrepareReleased(Item, Order);
        Request := Lib.IdRequest(Order);
        Request.Add('acceptMissingOutput', true);
        Request.Add('acceptMissingConsumption', true);
        Response := Lib.Finish(Request, 1033);
        Data.AssertRefusal(Response, 'ConfirmationRequired');
        Assert.IsTrue(Order.Get(Order.Status, Order."No."), 'Nothing changed without expectedCount.');
        Lib.Cleanup(Item."No.");
    end;

    [Test]
    procedure Scenario_AC12_CheckFinish_ChangesNothing()
    var
        Item: Record Item;
        Order: Record "Production Order";
        After: Record "Production Order";
        Check: JsonObject;
    begin
        PrepareReleased(Item, Order);
        Check := Lib.CheckFinish(Order, 1033);
        Assert.AreEqual('Success', Data.TextValue(Check, 'status'), 'CheckFinish runs.');
        After.Get(Order.Status, Order."No.");
        Assert.AreEqual(Order.SystemId, After.SystemId, 'CheckFinish keeps the record.');
        Assert.AreEqual(Order.Status, After.Status, 'CheckFinish keeps the status.');
        Lib.Cleanup(Item."No.");
    end;

    [Test]
    procedure Scenario_AC15_MissingOutput_AnswersInIcelandic()
    var
        Item: Record Item;
        Order: Record "Production Order";
        Check: JsonObject;
    begin
        PrepareReleased(Item, Order);
        Check := Lib.CheckFinish(Order, 1039);
        Assert.IsTrue(Lib.ResponseContains(Check, StrSubstNo('Framleiðslupöntun %1 vantar enn afköst. Engu var breytt.', Order."No.")), 'Icelandic missing-output text.');
        Lib.Cleanup(Item."No.");
    end;

    local procedure PrepareReleased(var Item: Record Item; var Order: Record "Production Order")
    var
        Response: JsonObject;
    begin
        Lib.PrepareOrder(Item, Order, Order.Status::"Firm Planned");
        Commit();
        Response := Lib.ChangeStatus(Order, 'Released', 1, 1033);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Fixture release succeeds.');
        Lib.ReadBack(Response, Order);
    end;
}
