namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Setup;
using Microsoft.Manufacturing.Document;
using Microsoft.Purchases.Document;
using Microsoft.Warehouse.Activity;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Story #6 AC07, AC09, AC10 and AC12 parity: Finish after real output and consumption postings, and its blockers.</summary>
codeunit 97622 "Prod Ord Finish Post Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Data: Codeunit "Mfg Test Data ori";
        Lib: Codeunit "Mfg Status Test Lib ori";
        Assert: Codeunit "Library Assert";
        Manufacturing: Codeunit "Library - Manufacturing";
        Inventory: Codeunit "Library - Inventory";
        Purchase: Codeunit "Library - Purchase";

    [Test]
    procedure Scenario_AC07_OutputAndConsumptionPosted_Finishes()
    var
        Item: Record Item;
        Order: Record "Production Order";
        Finished: Record "Production Order";
        Line: Record "Prod. Order Line";
        Component: Record "Prod. Order Component";
        Check: JsonObject;
        Request: JsonObject;
        Response: JsonObject;
        LineJson: JsonToken;
        Value: JsonToken;
        ResponseText: Text;
    begin
        PrepareReleased(Item, Order);
        FirstLine(Order, Line);
        FirstComponent(Order, Component);
        PostConsumption(Line, Component, Component."Expected Quantity");
        Manufacturing.PostOutput(Line, Line.Quantity, WorkDate(), 0);
        Commit();

        Check := Lib.CheckFinish(Order, 1033);
        Assert.IsTrue(Lib.ResponseContains(Check, '"canFinish":true'), 'Posted output and consumption leave nothing blocking.');
        Assert.IsFalse(Lib.ResponseContains(Check, 'missingOutput'), 'No missing output after posting the output.');
        Assert.IsFalse(Lib.ResponseContains(Check, 'missingConsumption'), 'No missing consumption after posting the consumption.');

        Request := Lib.IdRequest(Order);
        Request.Add('expectedCount', 1);
        Request.Add('postingDate', Format(WorkDate(), 0, 9));
        Response := Lib.Finish(Request, 1033);
        Response.WriteTo(ResponseText);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Finish of a fully posted order succeeds without acknowledgments: ' + ResponseText);
        Lib.ReadBack(Response, Finished);
        Assert.AreEqual(Finished.Status::Finished, Finished.Status, 'The order is Finished.');
        Assert.AreEqual(WorkDate(), Finished."Finished Date", 'Finished Date = posting date.');
        Assert.AreEqual(Format(WorkDate(), 0, 9), Data.TextValue(Response, 'finishedDate'), 'The response names the finished date.');
        Assert.IsTrue(Lib.ResponseContains(Response, '"acknowledgedWarnings":[]'), 'Nothing needed an acknowledgment.');
        Assert.AreEqual(1, Lib.ArrayValue(Response, 'lines').Count(), 'Finish lists the line.');
        Lib.ArrayValue(Response, 'lines').Get(0, LineJson);
        LineJson.AsObject().Get('finishedQuantity', Value);
        Assert.AreEqual(Line.Quantity, Value.AsValue().AsDecimal(), 'finishedQuantity equals the posted output.');
        Lib.Cleanup(Item."No.");
    end;

    [Test]
    procedure Scenario_AC07_BackwardFlushedComponent_ConsumedOnFinish()
    var
        Item: Record Item;
        Order: Record "Production Order";
        Finished: Record "Production Order";
        Line: Record "Prod. Order Line";
        Component: Record "Prod. Order Component";
        ComponentItem: Record Item;
        Entry: Record "Item Ledger Entry";
        Check: JsonObject;
        Request: JsonObject;
        Response: JsonObject;
        ResponseText: Text;
    begin
        PrepareReleased(Item, Order);
        FirstLine(Order, Line);
        FirstComponent(Order, Component);
        Component.Validate("Flushing Method", Component."Flushing Method"::Backward);
        Component.Modify(true);
        ComponentItem.Get(Component."Item No.");
        Inventory.PostPositiveAdjustment(ComponentItem, Component."Location Code", '', '', Component."Expected Quantity", WorkDate(), 0);
        Manufacturing.PostOutput(Line, Line.Quantity, WorkDate(), 0);
        Commit();

        Check := Lib.CheckFinish(Order, 1033);
        Assert.IsTrue(Lib.ResponseContains(Check, '"canFinish":true'), 'Nothing blocks.');
        Assert.IsFalse(Lib.ResponseContains(Check, 'missingConsumption'), 'A backward-flushed component is not missing consumption.');
        Assert.IsTrue(Lib.ResponseContains(Check, '"flushingMethod":"Backward"'), 'CheckFinish lists the backward-flushed component.');

        Request := Lib.IdRequest(Order);
        Request.Add('expectedCount', 1);
        Response := Lib.Finish(Request, 1033);
        Response.WriteTo(ResponseText);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Finish succeeds: ' + ResponseText);
        Lib.ReadBack(Response, Finished);
        Assert.AreEqual(Finished.Status::Finished, Finished.Status, 'The order is Finished.');
        Assert.IsTrue(Data.NumberValue(Response, 'postedItemEntries') >= 1, 'Finish posted the backward flushing.');
        Entry.SetRange("Entry Type", Entry."Entry Type"::Consumption);
        Entry.SetRange("Order Type", Entry."Order Type"::Production);
        Entry.SetRange("Order No.", Finished."No.");
        Entry.SetRange("Item No.", Component."Item No.");
        Entry.CalcSums(Quantity);
        Assert.AreEqual(-Component."Expected Quantity", Entry.Quantity, 'The backward-flushed component was consumed by Finish.');
        Lib.Cleanup(Item."No.");
    end;

    [Test]
    procedure Scenario_AC09_ConsumptionWithoutOutput_RefusedThenFinishWithoutOutput()
    var
        Item: Record Item;
        Order: Record "Production Order";
        Finished: Record "Production Order";
        Line: Record "Prod. Order Line";
        Component: Record "Prod. Order Component";
        Check: JsonObject;
        Request: JsonObject;
        Response: JsonObject;
        ResponseText: Text;
    begin
        PrepareReleased(Item, Order);
        FirstLine(Order, Line);
        FirstComponent(Order, Component);
        PostConsumption(Line, Component, Component."Expected Quantity");
        Commit();

        Check := Lib.CheckFinish(Order, 1033);
        Assert.IsTrue(Lib.ResponseContains(Check, '"code":"ConsumptionWithoutOutput"'), 'CheckFinish reports consumption without output.');
        Assert.IsTrue(Lib.ResponseContains(Check, '"canFinish":false'), 'The blocker stops the finish.');

        Request := Lib.IdRequest(Order);
        Request.Add('expectedCount', 1);
        Request.Add('acceptMissingOutput', true);
        Request.Add('acceptMissingConsumption', true);
        Response := Lib.Finish(Request, 1033);
        Assert.AreEqual('Error', Data.TextValue(Response, 'status'), 'Consumption without output is refused even with both acknowledgments.');
        Assert.IsTrue(Lib.ResponseContains(Response, 'PreconditionFailed'), 'PreconditionFailed');
        Assert.IsTrue(Lib.ResponseContains(Response, 'It has consumption or capacity posted with no output.'), 'BC wording (parity with CheckFinish).');
        Assert.IsTrue(Lib.ResponseContains(Response, 'finishWithoutOutput'), 'The refusal names finishWithoutOutput.');
        Assert.IsTrue(Order.Get(Order.Status::Released, Order."No."), 'Nothing changed: the order is still Released.');

        Request.Add('finishWithoutOutput', true);
        Response := Lib.Finish(Request, 1033);
        Response.WriteTo(ResponseText);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'finishWithoutOutput finishes the order: ' + ResponseText);
        Lib.ReadBack(Response, Finished);
        Assert.AreEqual(Finished.Status::Finished, Finished.Status, 'The order is Finished.');
        Lib.Cleanup(Item."No.");
    end;

    [Test]
    procedure Scenario_AC10_OutstandingSubcontractOrder_RefusedNotOverridable()
    var
        Item: Record Item;
        Order: Record "Production Order";
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        Check: JsonObject;
        Response: JsonObject;
    begin
        PrepareReleased(Item, Order);
        Purchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Order, Purchase.CreateVendorNo());
        Purchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, Item."No.", 1);
        // The subcontracting worksheet links the purchase line to the order; the fixture sets the link directly.
        PurchaseLine."Prod. Order No." := Order."No.";
        PurchaseLine.Modify(false);
        Commit();

        Check := Lib.CheckFinish(Order, 1033);
        Assert.IsTrue(Lib.ResponseContains(Check, '"code":"OutstandingSubcontractOrder"'), 'CheckFinish reports the outstanding subcontract order.');
        Assert.IsTrue(Lib.ResponseContains(Check, '"canFinish":false'), 'The blocker stops the finish.');

        Response := Lib.Finish(OverrideAllRequest(Order), 1033);
        Assert.AreEqual('Error', Data.TextValue(Response, 'status'), 'An outstanding subcontract order is refused.');
        Assert.IsTrue(Lib.ResponseContains(Response, 'PreconditionFailed'), 'PreconditionFailed');
        Assert.IsTrue(Lib.ResponseContains(Response, StrSubstNo('Production order %1 cannot be finished as there is an outstanding purchase order for it.', Order."No.")), 'BC wording (parity with CheckFinish).');
        Assert.IsTrue(Order.Get(Order.Status::Released, Order."No."), 'No flag overrides it: the order is still Released.');

        PurchaseLine.Delete(false);
        PurchaseHeader.Delete(false);
        Commit();
        Lib.Cleanup(Item."No.");
    end;

    [Test]
    procedure Scenario_AC10_OutstandingPick_RefusedNotOverridable()
    var
        Item: Record Item;
        Order: Record "Production Order";
        Component: Record "Prod. Order Component";
        ActivityLine: Record "Warehouse Activity Line";
        Check: JsonObject;
        Response: JsonObject;
    begin
        PrepareReleased(Item, Order);
        FirstComponent(Order, Component);
        // An outstanding warehouse pick line for the order's component, as Create Pick would leave it.
        ActivityLine.Init();
        ActivityLine."Activity Type" := ActivityLine."Activity Type"::Pick;
        ActivityLine."No." := CopyStr('X' + Order."No.", 1, MaxStrLen(ActivityLine."No."));
        ActivityLine."Line No." := 10000;
        ActivityLine."Source Type" := Database::"Prod. Order Component";
        ActivityLine."Source Subtype" := Order.Status.AsInteger();
        ActivityLine."Source No." := Order."No.";
        ActivityLine."Source Line No." := Component."Prod. Order Line No.";
        ActivityLine."Source Subline No." := Component."Line No.";
        ActivityLine."Item No." := Component."Item No.";
        ActivityLine.Quantity := Component."Expected Quantity";
        ActivityLine."Qty. Outstanding" := Component."Expected Quantity";
        ActivityLine.Insert(false);
        Commit();

        Check := Lib.CheckFinish(Order, 1033);
        Assert.IsTrue(Lib.ResponseContains(Check, '"code":"OutstandingPick"'), 'CheckFinish reports the outstanding pick.');
        Assert.IsTrue(Lib.ResponseContains(Check, '"canFinish":false'), 'The blocker stops the finish.');

        Response := Lib.Finish(OverrideAllRequest(Order), 1033);
        Assert.AreEqual('Error', Data.TextValue(Response, 'status'), 'An outstanding pick is refused.');
        Assert.IsTrue(Lib.ResponseContains(Response, 'PreconditionFailed'), 'PreconditionFailed');
        Assert.IsTrue(Lib.ResponseContains(Response, StrSubstNo('Production order %1 cannot be finished as there is an outstanding warehouse pick for its components.', Order."No.")), 'Pick wording (parity with CheckFinish).');
        Assert.IsTrue(Order.Get(Order.Status::Released, Order."No."), 'No flag overrides it: the order is still Released.');

        ActivityLine.Delete(false);
        Commit();
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
        UseOwnedPostingGroup(Order);
    end;

    /// <summary>Posts the fixture with its own inventory posting group whose setup has every account, including WIP, so the demo company's setup is not changed.</summary>
    local procedure UseOwnedPostingGroup(Order: Record "Production Order")
    var
        PostingGroup: Record "Inventory Posting Group";
        BlankLocation: Record Location;
        Item: Record Item;
        Line: Record "Prod. Order Line";
        Component: Record "Prod. Order Component";
    begin
        Inventory.CreateInventoryPostingGroup(PostingGroup);
        Inventory.UpdateInventoryPostingSetup(BlankLocation, PostingGroup.Code);
        Item.Get(Order."Source No.");
        Item.Validate("Inventory Posting Group", PostingGroup.Code);
        Item.Modify(true);
        Line.SetRange(Status, Order.Status);
        Line.SetRange("Prod. Order No.", Order."No.");
        Line.ModifyAll("Inventory Posting Group", PostingGroup.Code, false);
        Component.SetRange(Status, Order.Status);
        Component.SetRange("Prod. Order No.", Order."No.");
        if Component.FindSet() then
            repeat
                Item.Get(Component."Item No.");
                Item.Validate("Inventory Posting Group", PostingGroup.Code);
                Item.Modify(true);
            until Component.Next() = 0;
        Commit();
    end;

    local procedure FirstLine(Order: Record "Production Order"; var Line: Record "Prod. Order Line")
    begin
        Line.SetRange(Status, Order.Status);
        Line.SetRange("Prod. Order No.", Order."No.");
        Line.FindFirst();
    end;

    local procedure FirstComponent(Order: Record "Production Order"; var Component: Record "Prod. Order Component")
    begin
        Component.SetRange(Status, Order.Status);
        Component.SetRange("Prod. Order No.", Order."No.");
        Component.FindFirst();
    end;

    local procedure PostConsumption(Line: Record "Prod. Order Line"; Component: Record "Prod. Order Component"; Quantity: Decimal)
    var
        ComponentItem: Record Item;
    begin
        ComponentItem.Get(Component."Item No.");
        Inventory.PostPositiveAdjustment(ComponentItem, Component."Location Code", '', '', Quantity, WorkDate(), 0);
        Manufacturing.PostConsumption(Line, ComponentItem, Component."Location Code", '', Quantity, WorkDate(), 0);
    end;

    local procedure OverrideAllRequest(Order: Record "Production Order") Request: JsonObject
    begin
        Request := Lib.IdRequest(Order);
        Request.Add('expectedCount', 1);
        Request.Add('acceptMissingOutput', true);
        Request.Add('acceptMissingConsumption', true);
        Request.Add('finishWithoutOutput', true);
    end;
}
