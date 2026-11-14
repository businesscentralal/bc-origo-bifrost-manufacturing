namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Inventory.Item;
using Microsoft.Manufacturing.Document;
using Microsoft.Manufacturing.Routing;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Worker review amendments at ddb9349: routing-link-aware missing consumption on Finish (AC08/AC12) and the
/// Get proposal round trip for an order line without routing (Story #7).
/// </summary>
codeunit 97669 "Prod Order Amend Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Data: Codeunit "Mfg Test Data ori";
        Lib: Codeunit "Prod Jnl Test Lib ori";
        StatusLib: Codeunit "Mfg Status Test Lib ori";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Scenario_AC08_AC12_BackwardComponentLinkedToManualOperation_IsMissingConsumption()
    var
        Item: Record Item;
        Order: Record "Production Order";
        Check: JsonObject;
        Request: JsonObject;
        Response: JsonObject;
    begin
        Lib.PrepareReleased(Item, Order);
        LinkComponent(Order, 'Manual');

        Check := StatusLib.CheckFinish(Order, 1033);
        Assert.AreEqual('Success', Data.TextValue(Check, 'status'), 'CheckFinish runs.');
        Assert.IsTrue(StatusLib.ResponseContains(Check, '"kind":"missingConsumption"'), 'A backward component linked to a manual operation is not flushed by Finish and is reported.');

        Request := StatusLib.IdRequest(Order);
        Request.Add('expectedCount', 1);
        Request.Add('acceptMissingOutput', true);
        Response := StatusLib.Finish(Request, 1033);
        Assert.AreEqual('Error', Data.TextValue(Response, 'status'), 'Finish without acceptMissingConsumption is refused.');
        Assert.IsTrue(StatusLib.ResponseContains(Response, 'PreconditionFailed'), 'PreconditionFailed');
        Assert.IsTrue(StatusLib.ResponseContains(Response, 'missingConsumption'), 'The refusal lists missingConsumption.');
        Assert.IsTrue(Order.Get(Order.Status, Order."No."), 'Nothing changed.');
        Lib.Cleanup(Item."No.");
    end;

    [Test]
    procedure Scenario_AC08_AC12_BackwardComponentLinkedToBackwardOperation_IsNotReported()
    var
        Item: Record Item;
        Order: Record "Production Order";
        Check: JsonObject;
    begin
        Lib.PrepareReleased(Item, Order);
        LinkComponent(Order, 'Backward');

        Check := StatusLib.CheckFinish(Order, 1033);
        Assert.AreEqual('Success', Data.TextValue(Check, 'status'), 'CheckFinish runs.');
        Assert.IsFalse(StatusLib.ResponseContains(Check, '"kind":"missingConsumption"'), 'A backward component linked to a backward operation is flushed by Finish.');
        Lib.Cleanup(Item."No.");
    end;

    [Test]
    procedure Scenario_Story7_GetProposal_WithoutRouting_RoundTripsThroughPreviewAndPost()
    var
        Item: Record Item;
        Order: Record "Production Order";
        OrderLine: Record "Prod. Order Line";
        RoutingLine: Record "Prod. Order Routing Line";
        Extra: JsonObject;
        Response: JsonObject;
        Proposed: JsonArray;
        ResponseText: Text;
    begin
        Lib.PrepareReleased(Item, Order);
        RoutingLine.SetRange(Status, Order.Status);
        RoutingLine.SetRange("Prod. Order No.", Order."No.");
        RoutingLine.DeleteAll(false);
        OrderLine.SetRange(Status, Order.Status);
        OrderLine.SetRange("Prod. Order No.", Order."No.");
        OrderLine.ModifyAll("Routing No.", '', false);
        Commit();

        Response := Lib.Call("Message Type ori"::"Manufacturing.ProductionJournal.Get", Order, Extra, 1033);
        Response.WriteTo(ResponseText);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Get succeeds without routing: ' + ResponseText);
        Proposed := StatusLib.ArrayValue(Response, 'proposedLines');
        Assert.IsTrue(Proposed.Count() > 0, 'Get proposes lines without routing: ' + ResponseText);
        Assert.IsTrue(ResponseText.Contains('"operationNo":""'), 'The output proposal has a blank operation: ' + ResponseText);

        Clear(Extra);
        Extra.Add('lines', Proposed);
        Response := Lib.Call("Message Type ori"::"Manufacturing.ProductionJournal.PreviewPost", Order, Extra, 1033);
        Response.WriteTo(ResponseText);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'The proposal is accepted back by PreviewPost: ' + ResponseText);
        Assert.AreEqual(0, Lib.JournalLines(Order."No."), 'Preview leaves no journal line.');

        // Partial output: change the proposed output quantity to 2.
        Clear(Extra);
        Proposed := StatusLib.ArrayValue(Lib.Call("Message Type ori"::"Manufacturing.ProductionJournal.Get", Order, Extra, 1033), 'proposedLines');
        Extra.Add('lines', SetOutput(Proposed, 2));
        Response := Lib.Call("Message Type ori"::"Manufacturing.ProductionJournal.PreviewPost", Order, Extra, 1033);
        Response.WriteTo(ResponseText);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'A partial output proposal is accepted: ' + ResponseText);
        Lib.Cleanup(Item."No.");
    end;

    local procedure SetOutput(Proposed: JsonArray; Quantity: Decimal): JsonArray
    var
        Result: JsonArray;
        Token: JsonToken;
        Line: JsonObject;
        KindToken: JsonToken;
    begin
        foreach Token in Proposed do begin
            Line := Token.AsObject();
            if Line.Get('kind', KindToken) then
                if KindToken.AsValue().AsText() = 'output' then
                    Line.Replace('outputQuantity', Quantity);
            Result.Add(Line);
        end;
        exit(Result);
    end;

    local procedure LinkComponent(Order: Record "Production Order"; OperationFlushing: Text)
    var
        Component: Record "Prod. Order Component";
        RoutingLine: Record "Prod. Order Routing Line";
        RoutingLink: Record "Routing Link";
    begin
        if not RoutingLink.Get('MFG6RL') then begin
            RoutingLink.Code := 'MFG6RL';
            RoutingLink.Insert();
        end;
        RoutingLine.SetRange(Status, Order.Status);
        RoutingLine.SetRange("Prod. Order No.", Order."No.");
        RoutingLine.FindFirst();
        RoutingLine."Routing Link Code" := RoutingLink.Code;
        Evaluate(RoutingLine."Flushing Method", OperationFlushing);
        RoutingLine.Modify(false);
        Component.SetRange(Status, Order.Status);
        Component.SetRange("Prod. Order No.", Order."No.");
        Component.FindFirst();
        Component."Routing Link Code" := RoutingLink.Code;
        Component."Flushing Method" := Component."Flushing Method"::Backward;
        Component.Modify(false);
        Commit();
    end;
}
