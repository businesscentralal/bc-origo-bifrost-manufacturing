namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Microsoft.Manufacturing.Capacity;
using Microsoft.Manufacturing.Document;
using Microsoft.Manufacturing.ProductionBOM;
using Microsoft.Manufacturing.Routing;
using Microsoft.Manufacturing.Setup;
using Microsoft.Manufacturing.WorkCenter;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Builds scheduled production orders and reads schedule responses for issue 24.</summary>
codeunit 97683 "Mfg Schedule Test Lib ori"
{
    var
        Data: Codeunit "Mfg Test Data ori";
        Assert: Codeunit "Library Assert";

    /// <summary>Creates a certified one-operation item and a refreshed firm planned order.</summary>
    procedure CreateRefreshedOrder(var Item: Record Item; var Order: Record "Production Order")
    var
        Response: JsonObject;
        Raw: Text;
    begin
        Data.SetupNumbering(false);
        SetupReleasedNumbering();
        Data.CreateManufacturedItem(Item);
        Data.CreateOrder(Order, Item, Order.Status::"Firm Planned");
        Commit();
        Response := Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Refresh", RefreshRequest(Order), 1033, false);
        Response.WriteTo(Raw);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Fixture refresh: ' + Raw);
        Order.Get(Order.Status, Order."No.");
    end;

    /// <summary>Creates a released order with two operations on two calculated work centers.</summary>
    procedure CreateReleasedTwoOperation(var Item: Record Item; var Order: Record "Production Order")
    var
        Component: Record Item;
        Bom: Record "Production BOM Header";
        Routing: Record "Routing Header";
        RoutingLine: Record "Routing Line";
        CenterA: Record "Work Center";
        CenterB: Record "Work Center";
        Inventory: Codeunit "Library - Inventory";
        Manufacturing: Codeunit "Library - Manufacturing";
        StatusLib: Codeunit "Mfg Status Test Lib ori";
        Response: JsonObject;
        Raw: Text;
    begin
        Data.SetupNumbering(false);
        SetupReleasedNumbering();
        Inventory.CreateItem(Component);
        Component.Rename(CopyStr('X' + Component."No.", 1, MaxStrLen(Component."No.")));
        Component.Validate("Manufacturing Policy", Component."Manufacturing Policy"::"Make-to-Stock");
        Manufacturing.CreateCertifiedProductionBOM(Bom, Component."No.", 2);
        Manufacturing.CreateWorkCenterWithCalendar(CenterA);
        Manufacturing.CreateWorkCenterWithCalendar(CenterB);
        Manufacturing.CalculateWorkCenterCalendar(CenterA, CalcDate('<-1Y>', WorkDate()), CalcDate('<1Y>', WorkDate()));
        Manufacturing.CalculateWorkCenterCalendar(CenterB, CalcDate('<-1Y>', WorkDate()), CalcDate('<1Y>', WorkDate()));
        Manufacturing.CreateRoutingHeader(Routing, Routing.Type::Serial);
        Manufacturing.CreateRoutingLine(Routing, RoutingLine, '', '10', RoutingLine.Type::"Work Center", CenterA."No.");
        RoutingLine.Validate("Run Time", 60);
        RoutingLine.Modify(true);
        Manufacturing.CreateRoutingLine(Routing, RoutingLine, '', '20', RoutingLine.Type::"Work Center", CenterB."No.");
        RoutingLine.Validate("Run Time", 60);
        RoutingLine.Modify(true);
        RoutingLine.Get(Routing."No.", '', '10');
        RoutingLine."Next Operation No." := '20';
        RoutingLine.Modify(true);
        RoutingLine.Get(Routing."No.", '', '20');
        RoutingLine."Previous Operation No." := '10';
        RoutingLine.Modify(true);
        Manufacturing.UpdateRoutingStatus(Routing, Routing.Status::Certified);
        Manufacturing.CreateItemManufacturing(Item, Item."Costing Method"::FIFO, 10, Item."Reordering Policy"::Order, Item."Flushing Method"::Backward, Routing."No.", Bom."No.");
        Item.Rename(CopyStr('X' + Item."No.", 1, MaxStrLen(Item."No.")));
        Item.Validate("Manufacturing Policy", Item."Manufacturing Policy"::"Make-to-Stock");
        Manufacturing.CreateProductionOrder(Order, Order.Status::"Firm Planned", Order."Source Type"::Item, Item."No.", 5);
        Commit();
        Response := Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Refresh", RefreshRequest(Order), 1033, false);
        Response.WriteTo(Raw);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Two-operation refresh: ' + Raw);
        Order.Get(Order.Status, Order."No.");
        Response := StatusLib.ChangeStatus(Order, 'Released', 1, 1033);
        Response.WriteTo(Raw);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Release fixture: ' + Raw);
        StatusLib.ReadBack(Response, Order);
        Assert.AreEqual(Order.Status::Released, Order.Status, 'Released fixture.');
    end;

    /// <summary>Points released order numbers at the isolated firm planned series.</summary>
    procedure SetupReleasedNumbering()
    var
        Setup: Record "Manufacturing Setup";
    begin
        Setup.Get();
        Setup.Validate("Released Order Nos.", Setup."Firm Planned Order Nos.");
        Setup.Modify(true);
    end;

    /// <summary>Assigns a new run time without letting the routing line reschedule itself.</summary>
    procedure StretchRunTime(Order: Record "Production Order"; NewRunTime: Decimal)
    var
        RoutingLine: Record "Prod. Order Routing Line";
    begin
        RoutingLine.SetRange(Status, Order.Status);
        RoutingLine.SetRange("Prod. Order No.", Order."No.");
        RoutingLine.FindFirst();
        RoutingLine."Run Time" := NewRunTime;
        RoutingLine.Modify(false);
    end;

    /// <summary>Inserts an output ledger row without posting, so the schedule must refuse it.</summary>
    procedure InsertOutput(OrderNo: Code[20]; ItemNo: Code[20]): Integer
    var
        Entry: Record "Item Ledger Entry";
        NextNo: Integer;
    begin
        if Entry.FindLast() then
            NextNo := Entry."Entry No." + 1
        else
            NextNo := 1;
        Entry.Init();
        Entry."Entry No." := NextNo;
        Entry."Entry Type" := Entry."Entry Type"::Output;
        Entry."Order Type" := Entry."Order Type"::Production;
        Entry."Order No." := OrderNo;
        Entry."Item No." := ItemNo;
        Entry."Posting Date" := WorkDate();
        Entry.Quantity := 1;
        Entry."Remaining Quantity" := 1;
        Entry.Positive := true;
        Entry.Insert(false);
        exit(NextNo);
    end;

    /// <summary>Builds a Refresh request. Refresh names the status key productionOrderStatus.</summary>
    procedure RefreshRequest(Order: Record "Production Order"): JsonObject
    var
        Request: JsonObject;
    begin
        Request.Add('systemId', Format(Order.SystemId, 0, 4));
        Request.Add('direction', 'Backward');
        Request.Add('calculateLines', true);
        Request.Add('calculateRoutings', true);
        Request.Add('calculateComponents', true);
        exit(Request);
    end;

    /// <summary>Builds an identity request.</summary>
    procedure Identity(Order: Record "Production Order"): JsonObject
    var
        Request: JsonObject;
    begin
        Request.Add('systemId', Format(Order.SystemId, 0, 4));
        Request.Add('status', StatusText(Order.Status));
        exit(Request);
    end;

    /// <summary>Builds a replan request. IncludeCount false omits expectedCount.</summary>
    procedure ReplanRequest(Order: Record "Production Order"; Direction: Text; CalcMethod: Text; ExpectedCount: Integer; IncludeCount: Boolean): JsonObject
    var
        Request: JsonObject;
    begin
        Request := Identity(Order);
        if Direction <> '' then
            Request.Add('direction', Direction);
        if CalcMethod <> '' then
            Request.Add('calcMethod', CalcMethod);
        if IncludeCount then
            Request.Add('expectedCount', ExpectedCount);
        exit(Request);
    end;

    /// <summary>Builds a backward reschedule request for the whole order.</summary>
    procedure RescheduleDue(Order: Record "Production Order"; DueDateText: Text): JsonObject
    var
        Request: JsonObject;
    begin
        Request := Identity(Order);
        Request.Add('direction', 'backward');
        Request.Add('dueDate', DueDateText);
        exit(Request);
    end;

    /// <summary>Builds a forward reschedule request for one line. LineNo 0 moves the header.</summary>
    procedure RescheduleStart(Order: Record "Production Order"; LineNo: Integer; StartingText: Text): JsonObject
    var
        Request: JsonObject;
    begin
        Request := Identity(Order);
        Request.Add('direction', 'forward');
        if LineNo <> 0 then
            Request.Add('lineNo', LineNo);
        Request.Add('startingDateTime', StartingText);
        exit(Request);
    end;

    /// <summary>Returns the invariant status name used in requests.</summary>
    procedure StatusText(OrderStatus: Enum "Production Order Status"): Text
    begin
        case OrderStatus of
            OrderStatus::Simulated:
                exit('Simulated');
            OrderStatus::Planned:
                exit('Planned');
            OrderStatus::"Firm Planned":
                exit('FirmPlanned');
            OrderStatus::Released:
                exit('Released');
            OrderStatus::Finished:
                exit('Finished');
        end;
        exit('');
    end;

    /// <summary>Counts production orders for an item in every status.</summary>
    procedure CountOrders(ItemNo: Code[20]): Integer
    var
        ProductionOrder: Record "Production Order";
    begin
        ProductionOrder.SetRange("Source Type", ProductionOrder."Source Type"::Item);
        ProductionOrder.SetRange("Source No.", ItemNo);
        exit(ProductionOrder.Count());
    end;

    /// <summary>Returns the header starting date-time.</summary>
    procedure StartingDateTime(Order: Record "Production Order"): DateTime
    begin
        Order.Get(Order.Status, Order."No.");
        exit(Order."Starting Date-Time");
    end;

    /// <summary>Returns the header due date.</summary>
    procedure DueDate(Order: Record "Production Order"): Date
    begin
        Order.Get(Order.Status, Order."No.");
        exit(Order."Due Date");
    end;

    /// <summary>Returns the first routing operation starting date-time.</summary>
    procedure RoutingStart(Order: Record "Production Order"): DateTime
    var
        RoutingLine: Record "Prod. Order Routing Line";
    begin
        RoutingLine.SetRange(Status, Order.Status);
        RoutingLine.SetRange("Prod. Order No.", Order."No.");
        RoutingLine.FindFirst();
        exit(RoutingLine."Starting Date-Time");
    end;

    /// <summary>Returns the first component due date.</summary>
    procedure ComponentDue(Order: Record "Production Order"): Date
    var
        Component: Record "Prod. Order Component";
    begin
        Component.SetRange(Status, Order.Status);
        Component.SetRange("Prod. Order No.", Order."No.");
        Component.FindFirst();
        exit(Component."Due Date");
    end;

    /// <summary>Returns the earliest capacity-need date and the row count.</summary>
    procedure Capacity(Order: Record "Production Order"; var NeedDate: Date; var NeedCount: Integer)
    var
        CapacityNeed: Record "Prod. Order Capacity Need";
    begin
        NeedDate := 0D;
        CapacityNeed.SetRange(Status, Order.Status);
        CapacityNeed.SetRange("Prod. Order No.", Order."No.");
        NeedCount := CapacityNeed.Count();
        if CapacityNeed.FindSet() then
            repeat
                if (CapacityNeed.Date <> 0D) and ((NeedDate = 0D) or (CapacityNeed.Date < NeedDate)) then
                    NeedDate := CapacityNeed.Date;
            until CapacityNeed.Next() = 0;
    end;

    /// <summary>Reads a string from a nested response object.</summary>
    procedure ObjectText(Response: JsonObject; ParentName: Text; Name: Text): Text
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(Response.Get(ParentName, Token), 'Missing object ' + ParentName);
        exit(Data.TextValue(Token.AsObject(), Name));
    end;

    /// <summary>Returns the size of a response array.</summary>
    procedure ArrayCount(Response: JsonObject; Name: Text): Integer
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(Response.Get(Name, Token), 'Missing array ' + Name);
        exit(Token.AsArray().Count());
    end;

    /// <summary>Removes the orders, lines and inserted ledger rows created for an item.</summary>
    procedure Cleanup(ItemNo: Code[20])
    var
        ProductionOrder: Record "Production Order";
        ProdOrderLine: Record "Prod. Order Line";
        RoutingLine: Record "Prod. Order Routing Line";
        Component: Record "Prod. Order Component";
        CapacityNeed: Record "Prod. Order Capacity Need";
        ItemLedgerEntry: Record "Item Ledger Entry";
        CapacityLedgerEntry: Record "Capacity Ledger Entry";
    begin
        ProductionOrder.SetRange("Source Type", ProductionOrder."Source Type"::Item);
        ProductionOrder.SetRange("Source No.", ItemNo);
        if ProductionOrder.FindSet() then
            repeat
                CapacityNeed.SetRange(Status, ProductionOrder.Status);
                CapacityNeed.SetRange("Prod. Order No.", ProductionOrder."No.");
                CapacityNeed.DeleteAll(false);
                RoutingLine.SetRange(Status, ProductionOrder.Status);
                RoutingLine.SetRange("Prod. Order No.", ProductionOrder."No.");
                RoutingLine.DeleteAll(false);
                Component.SetRange(Status, ProductionOrder.Status);
                Component.SetRange("Prod. Order No.", ProductionOrder."No.");
                Component.DeleteAll(false);
                ProdOrderLine.SetRange(Status, ProductionOrder.Status);
                ProdOrderLine.SetRange("Prod. Order No.", ProductionOrder."No.");
                ProdOrderLine.DeleteAll(false);
                ItemLedgerEntry.SetRange("Order Type", ItemLedgerEntry."Order Type"::Production);
                ItemLedgerEntry.SetRange("Order No.", ProductionOrder."No.");
                ItemLedgerEntry.DeleteAll(false);
                CapacityLedgerEntry.SetRange("Order Type", CapacityLedgerEntry."Order Type"::Production);
                CapacityLedgerEntry.SetRange("Order No.", ProductionOrder."No.");
                CapacityLedgerEntry.DeleteAll(false);
            until ProductionOrder.Next() = 0;
        Data.CleanupOrders(ItemNo);
    end;
}
