namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Inventory.Item;
using Microsoft.Manufacturing.Document;
using Microsoft.Manufacturing.ProductionBOM;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Exercises report refresh, lookup and rollback using the public dispatcher.</summary>
codeunit 97605 "Prod Order Refresh Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Data: Codeunit "Mfg Test Data ori";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Scenario_AC07_Refresh_CreatesMatchingLinesAndCounts()
    var
        Item: Record Item;
        Order: Record "Production Order";
        Line: Record "Prod. Order Line";
        Routing: Record "Prod. Order Routing Line";
        Component: Record "Prod. Order Component";
        Response: JsonObject;
        Token: JsonToken;
    begin
        // Story #5 AC07: self-created certified BOM/routing; WorkDate drives planning.
        Prepare(Item, Order);
        Response := Refresh(Order, 'Backward', true, true, true, true);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Refresh succeeds.');
        Line.SetRange(Status, Order.Status);
        Line.SetRange("Prod. Order No.", Order."No.");
        Assert.AreEqual(1, Line.Count(), 'One manufactured-item line.');
        Response.Get('lines', Token);
        Assert.AreEqual(Line.Count(), Token.AsArray().Count(), 'Response lines match records.');
        Routing.SetRange(Status, Order.Status);
        Routing.SetRange("Prod. Order No.", Order."No.");
        Component.SetRange(Status, Order.Status);
        Component.SetRange("Prod. Order No.", Order."No.");
        Assert.IsTrue(Routing.Count() > 0, 'Routing was calculated.');
        Assert.IsTrue(Component.Count() > 0, 'BOM components were calculated.');
        Assert.AreEqual(Routing.Count(), Data.NumberValue(Response, 'routingLineCount'), 'Routing count.');
        Assert.AreEqual(Component.Count(), Data.NumberValue(Response, 'componentCount'), 'Component count.');
    end;

    [Test]
    procedure Scenario_AC08_Directions_MatchNativeReport()
    var
        Item: Record Item;
        Order: Record "Production Order";
        NativeRefresh: Report "Refresh Production Order";
        Backward: JsonObject;
        Forward: JsonObject;
        NativeStart: Date;
        NativeEnd: Date;
    begin
        // Story #5 AC08: explicit starting date makes forward and backward planning distinguishable.
        Prepare(Item, Order);
        Order.Validate("Starting Date", CalcDate('<-10D>', WorkDate()));
        Order.Modify(true);
        Backward := Refresh(Order, 'Backward', true, true, true, true);
        Order.Get(Order.Status, Order."No.");
        Order.Validate("Starting Date", CalcDate('<-10D>', WorkDate()));
        Order.Modify(true);
        Order.SetRecFilter();
        NativeRefresh.InitializeRequest(0, true, true, true, false);
        NativeRefresh.SetHideValidationDialog(true);
        NativeRefresh.SetTableView(Order);
        NativeRefresh.UseRequestPage(false);
        NativeRefresh.RunModal();
        Order.Get(Order.Status, Order."No.");
        NativeStart := Order."Starting Date";
        NativeEnd := Order."Ending Date";
        Order.Validate("Starting Date", CalcDate('<-10D>', WorkDate()));
        Order.Modify(true);
        Forward := Refresh(Order, 'Forward', true, true, true, true);
        Assert.AreEqual(Format(NativeStart, 0, 9), Data.TextValue(Forward, 'startingDate'), 'Same start as BC report.');
        Assert.AreEqual(Format(NativeEnd, 0, 9), Data.TextValue(Forward, 'endingDate'), 'Same end as BC report.');
        Assert.AreNotEqual(Data.TextValue(Backward, 'endingDate'), Data.TextValue(Forward, 'endingDate'), 'Direction changes the dates.');
    end;

    [Test]
    procedure Scenario_AC09_InvalidFlags_LeaveExistingLines()
    var
        Item: Record Item;
        Order: Record "Production Order";
        Line: Record "Prod. Order Line";
        BeforeId: Guid;
        Response: JsonObject;
    begin
        // Story #5 AC09: invalid replacement options never delete existing lines.
        Prepare(Item, Order);
        Refresh(Order, 'Backward', true, true, true, true);
        Line.SetRange(Status, Order.Status);
        Line.SetRange("Prod. Order No.", Order."No.");
        Line.FindFirst();
        BeforeId := Line.SystemId;
        Commit();
        Data.AssertRefusal(Refresh(Order, 'Backward', true, false, true, false), 'InvalidParameter');
        Assert.IsTrue(Line.GetBySystemId(BeforeId), 'Existing line survived refusal.');
        Response := Refresh(Order, 'Backward', false, true, true, false);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Partial calculation succeeds.');
        Assert.IsTrue(Line.GetBySystemId(BeforeId), 'calculateLines=false preserves original line.');
    end;

    [Test]
    procedure Scenario_AC10_UncertifiedBom_RollsBackRefresh()
    var
        Item: Record Item;
        Order: Record "Production Order";
        Bom: Record "Production BOM Header";
        Line: Record "Prod. Order Line";
        Component: Record "Prod. Order Component";
        Routing: Record "Prod. Order Routing Line";
        BeforeId: Guid;
        BeforeComponents: Integer;
        BeforeRouting: Integer;
    begin
        // Story #5 AC10: report refusal preserves previously calculated records.
        Prepare(Item, Order);
        Refresh(Order, 'Backward', true, true, true, true);
        Line.SetRange(Status, Order.Status);
        Line.SetRange("Prod. Order No.", Order."No.");
        Line.FindFirst();
        BeforeId := Line.SystemId;
        Component.SetRange(Status, Order.Status);
        Component.SetRange("Prod. Order No.", Order."No.");
        Routing.SetRange(Status, Order.Status);
        Routing.SetRange("Prod. Order No.", Order."No.");
        BeforeComponents := Component.Count();
        BeforeRouting := Routing.Count();
        Bom.Get(Item."Production BOM No.");
        Bom.Validate(Status, Bom.Status::"Under Development");
        Bom.Modify(true);
        Commit();
        Data.AssertRefusal(Refresh(Order, 'Backward', true, true, true, false), 'BusinessCentralError');
        Assert.IsTrue(Line.GetBySystemId(BeforeId), 'Line identity survives failed refresh.');
        Assert.AreEqual(BeforeComponents, Component.Count(), 'Component rows survive.');
        Assert.AreEqual(BeforeRouting, Routing.Count(), 'Routing rows survive.');
    end;

    [Test]
    procedure Scenario_AC11_ReleasedAndFinished_Refused()
    var
        Item: Record Item;
        Order: Record "Production Order";
        Request: JsonObject;
        Status: Enum "Production Order Status";
        Statuses: List of [Enum "Production Order Status"];
    begin
        // Story #5 AC11: minimal status fixtures; no posting or status-management call.
        Data.CreateItem(Item);
        Statuses.Add(Status::Released);
        Statuses.Add(Status::Finished);
        foreach Status in Statuses do begin
            Order.Init();
            Order.Status := Status;
            Order."No." := CopyStr('X' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, 20);
            Order."Source No." := Item."No.";
            Order.Insert(false);
            Clear(Request);
            Request.Add('systemId', Format(Order.SystemId, 0, 4));
            Commit();
            Data.AssertRefusal(Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Refresh", Request, 1033, false), 'PreconditionFailed');
        end;
    end;

    [Test]
    procedure Scenario_AC12_AmbiguousConflictingAndMissing_Refused()
    var
        Item: Record Item;
        Order: Record "Production Order";
        OtherOrder: Record "Production Order";
        Request: JsonObject;
    begin
        // Story #5 AC12: same number under two statuses must not choose the first row.
        Data.SetupNumbering(true);
        Data.CreateItem(Item);
        Data.CreateOrder(Order, Item, Order.Status::Planned);
        OtherOrder.Init();
        OtherOrder.Status := OtherOrder.Status::"Firm Planned";
        OtherOrder."No." := Order."No.";
        OtherOrder.Insert(false);
        Request.Add('no', Order."No.");
        Commit();
        Data.AssertRefusal(Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Refresh", Request, 1033, false), 'AmbiguousRecord');
        Request.Add('systemId', Format(Order.SystemId, 0, 4));
        Request.Replace('no', 'X-DIFFERENT-NUMBER');
        Data.AssertRefusal(Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Refresh", Request, 1033, false), 'ConflictingIdentifiers');
        Clear(Request);
        Request.Add('systemId', Format(CreateGuid(), 0, 4));
        Data.AssertRefusal(Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Refresh", Request, 1033, false), 'RecordNotFound');
    end;

    local procedure Prepare(var Item: Record Item; var Order: Record "Production Order")
    begin
        Data.SetupNumbering(false);
        Data.CreateManufacturedItem(Item);
        Data.CreateOrder(Order, Item, Order.Status::Planned);
    end;

    local procedure Refresh(Order: Record "Production Order"; Direction: Text; CalculateLines: Boolean; CalculateRoutings: Boolean; CalculateComponents: Boolean; OmitCommit: Boolean): JsonObject
    var
        Request: JsonObject;
    begin
        Request.Add('systemId', Format(Order.SystemId, 0, 4));
        Request.Add('direction', Direction);
        Request.Add('calculateLines', CalculateLines);
        Request.Add('calculateRoutings', CalculateRoutings);
        Request.Add('calculateComponents', CalculateComponents);
        exit(Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Refresh", Request, 1033, OmitCommit));
    end;
}
