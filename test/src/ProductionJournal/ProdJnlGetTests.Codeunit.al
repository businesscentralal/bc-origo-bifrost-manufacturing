namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Inventory.Item;
using Microsoft.Manufacturing.Document;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Story #7 AC01, AC02, AC04, AC16 and AC18: Manufacturing.ProductionJournal.Get.</summary>
codeunit 97640 "Prod Jnl Get Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Data: Codeunit "Mfg Test Data ori";
        Lib: Codeunit "Prod Jnl Test Lib ori";
        StatusLib: Codeunit "Mfg Status Test Lib ori";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Scenario_AC01_AC02_ProposalFollowsBasisAndFilters()
    var
        Item: Record Item;
        Order: Record "Production Order";
        Extra: JsonObject;
        Response: JsonObject;
        ResponseText: Text;
    begin
        Lib.PrepareReleased(Item, Order);
        Response := Lib.Call("Message Type ori"::"Manufacturing.ProductionJournal.Get", Order, Extra, 1033);
        Response.WriteTo(ResponseText);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Get succeeds: ' + ResponseText);
        Assert.AreEqual(1, StatusLib.ArrayValue(Response, 'outputLines').Count(), 'One output line (one operation).');
        Assert.AreEqual(1, StatusLib.ArrayValue(Response, 'consumptionLines').Count(), 'One consumption line (one component).');
        Assert.AreEqual(2, StatusLib.ArrayValue(Response, 'proposedLines').Count(), 'Proposed lines carry both.');
        Assert.AreEqual(Format(WorkDate(), 0, 9), Data.TextValue(Response, 'postingDate'), 'Default posting date is the work date.');
        Assert.AreEqual(0, Lib.JournalLines(Order."No."), 'Get leaves no journal line behind.');

        Clear(Extra);
        Extra.Add('consumptionBasis', 'ExpectedOutput');
        Response := Lib.Call("Message Type ori"::"Manufacturing.ProductionJournal.Get", Order, Extra, 1033);
        Response.WriteTo(ResponseText);
        Assert.AreEqual('ExpectedOutput', Data.TextValue(Response, 'consumptionBasis'), 'Basis echoed.');
        Assert.IsTrue(ResponseText.Contains('"quantity":10'), 'Expected-output basis proposes 5 x 2 = 10 of the component: ' + ResponseText);

        Clear(Extra);
        Extra.Add('consumptionBasis', 'ActualOutput');
        Response := Lib.Call("Message Type ori"::"Manufacturing.ProductionJournal.Get", Order, Extra, 1033);
        Response.WriteTo(ResponseText);
        Assert.IsTrue(ResponseText.Contains('"quantity":0'), 'Actual-output basis proposes 0 before any output is posted: ' + ResponseText);

        Clear(Extra);
        Extra.Add('postingDate', Format(CalcDate('<+1D>', WorkDate()), 0, 9));
        Response := Lib.Call("Message Type ori"::"Manufacturing.ProductionJournal.Get", Order, Extra, 1033);
        Assert.AreEqual(Format(CalcDate('<+1D>', WorkDate()), 0, 9), Data.TextValue(Response, 'postingDate'), 'postingDate honoured.');

        Clear(Extra);
        Extra.Add('include', '["output"]');
        Response := Lib.Call("Message Type ori"::"Manufacturing.ProductionJournal.Get", Order, Extra, 1033);
        Assert.AreEqual(0, StatusLib.ArrayValue(Response, 'consumptionLines').Count(), 'include output omits consumption.');
        Lib.Cleanup(Item."No.");
    end;

    [Test]
    procedure Scenario_AC04_NotReleased_Unknown_And_Ambiguity()
    var
        Item: Record Item;
        Order: Record "Production Order";
        Extra: JsonObject;
        Request: JsonObject;
        Response: JsonObject;
    begin
        StatusLib.PrepareOrder(Item, Order, Order.Status::"Firm Planned");
        Response := Lib.Call("Message Type ori"::"Manufacturing.ProductionJournal.Get", Order, Extra, 1033);
        Data.AssertRefusal(Response, 'PreconditionFailed');
        Assert.IsTrue(StatusLib.ResponseContains(Response, 'Manufacturing.ProductionOrder.ChangeStatus'), 'The next step names ChangeStatus.');
        Request.Add('no', 'NOSUCH-ORDER');
        Response := Data.Invoke("Message Type ori"::"Manufacturing.ProductionJournal.Get", Request, 1033, false);
        Data.AssertRefusal(Response, 'RecordNotFound');
        Lib.Cleanup(Item."No.");
    end;

    [Test]
    procedure Scenario_AC18_Refusal_AnswersInIcelandic()
    var
        Item: Record Item;
        Order: Record "Production Order";
        Extra: JsonObject;
        Response: JsonObject;
    begin
        StatusLib.PrepareOrder(Item, Order, Order.Status::"Firm Planned");
        Response := Lib.Call("Message Type ori"::"Manufacturing.ProductionJournal.Get", Order, Extra, 1039);
        Data.AssertRefusal(Response, 'PreconditionFailed');
        Assert.IsTrue(StatusLib.ResponseContains(Response, 'Framleiðslubók er aðeins til fyrir útgefna pöntun.'), 'Icelandic refusal text.');
        Lib.Cleanup(Item."No.");
    end;
}
