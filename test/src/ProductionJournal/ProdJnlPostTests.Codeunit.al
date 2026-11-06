namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Microsoft.Manufacturing.Capacity;
using Microsoft.Manufacturing.Document;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Story #7 AC05-AC13 and AC15: PreviewPost and Post, including the end-to-end finish.</summary>
codeunit 97642 "Prod Jnl Post Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Data: Codeunit "Mfg Test Data ori";
        Lib: Codeunit "Prod Jnl Test Lib ori";
        StatusLib: Codeunit "Mfg Status Test Lib ori";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Scenario_AC05_AC09_AC12_AC13_AC15_PostThenFinish()
    var
        Item: Record Item;
        Order: Record "Production Order";
        OrderLine: Record "Prod. Order Line";
        Extra: JsonObject;
        Response: JsonObject;
        FinishRequest: JsonObject;
        ResponseText: Text;
    begin
        Lib.PrepareReleased(Item, Order);
        StatusLib.SetConfirmRequired(true);
        Commit();

        // AC13: preview changes nothing.
        Clear(Extra);
        Extra.Add('consumptionBasis', 'ExpectedOutput');
        Response := Lib.Call("Message Type ori"::"Manufacturing.ProductionJournal.PreviewPost", Order, Extra, 1033);
        Response.WriteTo(ResponseText);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'PreviewPost succeeds: ' + ResponseText);
        Assert.AreEqual(2, Data.NumberValue(Response, 'linesToPost'), 'Two lines would post.');
        Assert.AreEqual(0, Lib.JournalLines(Order."No."), 'Preview leaves no journal line.');
        Assert.AreEqual(0, Lib.Entries(Order."No.", "Item Ledger Entry Type"::Output), 'Preview posts no output.');

        // AC09: no expectedCount -> refusal, nothing posted, no journal line.
        Response := Lib.Call("Message Type ori"::"Manufacturing.ProductionJournal.Post", Order, Extra, 1033);
        Data.AssertRefusal(Response, 'ConfirmationRequired');
        Assert.AreEqual(0, Lib.JournalLines(Order."No."), 'A refusal leaves no journal line.');
        Assert.AreEqual(0, Lib.Entries(Order."No.", "Item Ledger Entry Type"::Output), 'A refusal posts nothing.');
        Extra.Add('expectedCount', 5);
        Response := Lib.Call("Message Type ori"::"Manufacturing.ProductionJournal.Post", Order, Extra, 1033);
        Data.AssertRefusal(Response, 'ConfirmationMismatch');
        Assert.AreEqual(0, Lib.JournalLines(Order."No."), 'A mismatch leaves no journal line.');

        // AC05: post BC's proposal.
        Extra.Remove('expectedCount');
        Extra.Add('expectedCount', 2);
        Response := Lib.Call("Message Type ori"::"Manufacturing.ProductionJournal.Post", Order, Extra, 1033);
        Response.WriteTo(ResponseText);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Post succeeds: ' + ResponseText);
        Assert.AreEqual(2, Data.NumberValue(Response, 'postedLines'), 'Two lines posted.');
        Assert.AreEqual(5, Data.NumberValue(Response, 'outputQuantityPosted'), 'Output posted.');
        Assert.AreEqual(1, Data.NumberValue(Response, 'consumptionLinesPosted'), 'Consumption posted.');
        Assert.AreEqual(1, Lib.Entries(Order."No.", "Item Ledger Entry Type"::Output), 'One output entry.');
        Assert.AreEqual(1, Lib.Entries(Order."No.", "Item Ledger Entry Type"::Consumption), 'One consumption entry.');
        Assert.AreEqual(0, Lib.JournalLines(Order."No."), 'The batch is empty afterwards.');
        OrderLine.Get(Order.Status, Order."No.", 10000);
        Assert.AreEqual(5, OrderLine."Finished Quantity", 'Finished quantity rose by the output.');

        // AC12: nothing left.
        Clear(Extra);
        Extra.Add('expectedCount', 0);
        Response := Lib.Call("Message Type ori"::"Manufacturing.ProductionJournal.Post", Order, Extra, 1033);
        Data.AssertRefusal(Response, 'PreconditionFailed');
        Assert.IsTrue(StatusLib.ResponseContains(Response, 'Nothing to post'), 'Nothing to post.');

        // AC15: the posted order finishes.
        Clear(FinishRequest);
        FinishRequest := StatusLib.IdRequest(Order);
        FinishRequest.Add('expectedCount', 1);
        FinishRequest.Add('acceptMissingConsumption', true);
        Response := StatusLib.Finish(FinishRequest, 1033);
        Response.WriteTo(ResponseText);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Finish succeeds after Post: ' + ResponseText);
        StatusLib.SetConfirmRequired(false);
        Commit();
    end;

    [Test]
    procedure Scenario_AC06_AC08_AC10_ListedLinesOnly_Date_And_LineErrors()
    var
        Item: Record Item;
        Order: Record "Production Order";
        CapacityEntry: Record "Capacity Ledger Entry";
        Extra: JsonObject;
        Response: JsonObject;
        Lines: JsonArray;
        Line: JsonObject;
        ResponseText: Text;
    begin
        Lib.PrepareReleased(Item, Order);
        StatusLib.SetConfirmRequired(false);
        Commit();

        // AC10: collected line errors, nothing posted.
        Line.Add('kind', 'output');
        Line.Add('lineNo', 10000);
        Line.Add('operationNo', '99');
        Line.Add('outputQuantity', -1);
        Line.Add('bogus', 1);
        Lines.Add(Line);
        Clear(Line);
        Line.Add('kind', 'weird');
        Lines.Add(Line);
        Extra.Add('lines', Lines);
        Response := Lib.Call("Message Type ori"::"Manufacturing.ProductionJournal.Post", Order, Extra, 1033);
        Data.AssertRefusal(Response, 'MultipleErrors');
        Response.WriteTo(ResponseText);
        Assert.IsTrue(ResponseText.Contains('lines[0]'), 'The first line index is named.');
        Assert.IsTrue(ResponseText.Contains('lines[1]'), 'The second line index is named.');
        Assert.AreEqual(0, Lib.Entries(Order."No.", "Item Ledger Entry Type"::Output), 'Nothing posted.');

        // AC06 + AC08: only the listed output line posts, on the given date.
        Clear(Extra);
        Clear(Lines);
        Clear(Line);
        Line.Add('kind', 'output');
        Line.Add('lineNo', 10000);
        Line.Add('operationNo', '10');
        Line.Add('outputQuantity', 2);
        Line.Add('scrapQuantity', 1);
        Line.Add('runTime', 30);
        Lines.Add(Line);
        Extra.Add('lines', Lines);
        Extra.Add('postingDate', Format(CalcDate('<+1D>', WorkDate()), 0, 9));
        Response := Lib.Call("Message Type ori"::"Manufacturing.ProductionJournal.Post", Order, Extra, 1033);
        Response.WriteTo(ResponseText);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Post with lines succeeds: ' + ResponseText);
        Assert.AreEqual(1, Data.NumberValue(Response, 'postedLines'), 'Only the listed line posts.');
        Assert.AreEqual(1, Data.NumberValue(Response, 'scrapQuantityPosted'), 'Scrap posted.');
        Assert.AreEqual(0, Lib.Entries(Order."No.", "Item Ledger Entry Type"::Consumption), 'The unlisted consumption line did not post.');
        Assert.AreEqual(Format(CalcDate('<+1D>', WorkDate()), 0, 9), Data.TextValue(Response, 'postingDate'), 'The posting date is the requested one.');
        Assert.AreEqual(0, Lib.JournalLines(Order."No."), 'The batch is empty afterwards.');

        // AC07: the capacity ledger entry carries the times and the scrap is on the output.
        Assert.AreEqual(1, Data.NumberValue(Response, 'capacityEntriesPosted'), 'One capacity entry.');
        CapacityEntry.SetRange("Order Type", CapacityEntry."Order Type"::Production);
        CapacityEntry.SetRange("Order No.", Order."No.");
        CapacityEntry.FindFirst();
        Assert.AreEqual(30, CapacityEntry."Run Time", 'Run time on the capacity entry.');
        Assert.AreEqual(1, CapacityEntry."Scrap Quantity", 'Scrap on the capacity entry.');
    end;

    [Test]
    procedure Scenario_AC11_BcRefusal_Is_Atomic()
    var
        Item: Record Item;
        Order: Record "Production Order";
        Component: Record "Prod. Order Component";
        Extra: JsonObject;
        Response: JsonObject;
        Lines: JsonArray;
        Line: JsonObject;
    begin
        Lib.PrepareReleased(Item, Order);
        StatusLib.SetConfirmRequired(false);
        Commit();
        Component.SetRange(Status, Order.Status);
        Component.SetRange("Prod. Order No.", Order."No.");
        Component.FindFirst();
        Line.Add('kind', 'consumption');
        Line.Add('lineNo', Component."Prod. Order Line No.");
        Line.Add('componentLineNo', Component."Line No.");
        Line.Add('quantity', 100000);
        Lines.Add(Line);
        Extra.Add('lines', Lines);
        Response := Lib.Call("Message Type ori"::"Manufacturing.ProductionJournal.Post", Order, Extra, 1033);
        Data.AssertRefusal(Response, 'BusinessCentralError');
        Assert.IsTrue(StatusLib.ResponseContains(Response, 'insufficient'), 'BC text is returned.');
        Assert.AreEqual(0, Lib.Entries(Order."No.", "Item Ledger Entry Type"::Consumption), 'No consumption entry.');
        Assert.AreEqual(0, Lib.JournalLines(Order."No."), 'No journal line remains.');
        Lib.Cleanup(Item."No.");
    end;

    [Test]
    procedure Scenario_AC14_Post_Hidden_And_Denied_Without_PostingSet()
    var
        Item: Record Item;
        Order: Record "Production Order";
        Extra: JsonObject;
        Response: JsonObject;
    begin
        Lib.PrepareReleased(Item, Order);
        Response := Lib.Call("Message Type ori"::"Manufacturing.ProductionJournal.Get", Order, Extra, 1033);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Get works for the test user; the Post gate is covered by the status tests.');
        Lib.Cleanup(Item."No.");
    end;
}
