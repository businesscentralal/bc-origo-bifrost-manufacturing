namespace Origo.Bifrost.Manufacturing;

using Microsoft.Inventory;
using Microsoft.Inventory.Requisition;
using Microsoft.Manufacturing.Capacity;
using Microsoft.Manufacturing.Document;
using Microsoft.Manufacturing.Routing;
using Origo.Bifrost;

/// <summary>Schedules one production order without the replan report dialog, and never deletes another order.</summary>
codeunit 10077114 "Prod Order Replan Proc ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    begin
        CurrentTransactionType(TransactionType::Update);
        RunReplan(Rec);
    end;

    /// <summary>Replans the already validated order at no levels and writes the response.</summary>
    /// <param name="Argument">The dispatcher argument.</param>
    internal procedure RunReplan(var Argument: Record "Message Argument ori")
    var
        ProductionOrder: Record "Production Order";
        Lookup: Codeunit "Mfg Prod Order Lookup ori";
        Reader: Codeunit "Mfg Prod Order Request ori";
        CreateProdOrderLines: Codeunit "Create Prod. Order Lines";
        Request: JsonObject;
        Direction: Option Forward,Backward;
        DirectionText: Text;
        BeforeDates: JsonObject;
        NotReadyLbl: Label 'The production order could not be locked for replanning. Nothing was changed.', Comment = 'is-IS=Ekki tókst að læsa framleiðslupöntuninni fyrir endurskipulagningu. Engu var breytt.';
    begin
        // Report 99001026 opens a dialog and has no hide flag, so an API session cannot run it.
        // Only this order is processed. oneLevel and allLevels, which delete other orders, never run.
        Request := Argument.GetRequestJson();
        DirectionText := LowerCase(Reader.ReadText(Request, 'direction', false, 8, Argument));
        if DirectionText = 'forward' then
            Direction := Direction::Forward
        else begin
            Direction := Direction::Backward;
            DirectionText := 'backward';
        end;
        if not Lookup.FindSchedulingOrder(Argument, ProductionOrder) then
            exit;
        ProductionOrder.ReadIsolation := IsolationLevel::UpdLock;
        if not ProductionOrder.Get(ProductionOrder.Status, ProductionOrder."No.") then
            Error(NotReadyLbl);
        if not (ProductionOrder.Status in [ProductionOrder.Status::"Firm Planned", ProductionOrder.Status::Released]) then
            Error(NotReadyLbl);
        AddDates(BeforeDates, ProductionOrder);
        if ProductionOrder."Replan Ref. No." = '' then begin
            ProductionOrder."Replan Ref. No." := ProductionOrder."No.";
            ProductionOrder."Replan Ref. Status" := ProductionOrder.Status;
            ProductionOrder.Modify(true);
        end;
        DeleteUnreservedLowLevelLines(ProductionOrder);
        CreateProdOrderLines.CheckStructure(ProductionOrder.Status.AsInteger(), ProductionOrder."No.", Direction, true, true);
        ScheduleLines(ProductionOrder, Direction);
        ProductionOrder.Get(ProductionOrder.Status, ProductionOrder."No.");
        ProductionOrder.AdjustStartEndingDate();
        ProductionOrder.Modify(true);
        WriteResponse(Argument, BeforeDates, ProductionOrder, DirectionText, true, 0);
    end;

    /// <summary>Moves the due date or starting date-time of the already validated order or line.</summary>
    /// <param name="Argument">The dispatcher argument.</param>
    internal procedure RunReschedule(var Argument: Record "Message Argument ori")
    var
        ProductionOrder: Record "Production Order";
        ProdOrderLine: Record "Prod. Order Line";
        Lookup: Codeunit "Mfg Prod Order Lookup ori";
        Reader: Codeunit "Mfg Prod Order Request ori";
        Request: JsonObject;
        DirectionText: Text;
        Forward: Boolean;
        LineNo: Integer;
        NewDueDate: Date;
        NewStart: DateTime;
        NotReadyLbl: Label 'The production order could not be locked for rescheduling. Nothing was changed.', Comment = 'is-IS=Ekki tókst að læsa framleiðslupöntuninni fyrir endurtímasetningu. Engu var breytt.';
        LineMissingLbl: Label 'Production order line %1 was not found. Nothing was changed.', Comment = '%1 = line number, is-IS=Framleiðslupöntunarlínan %1 fannst ekki. Engu var breytt.';
        BeforeDates: JsonObject;
    begin
        Request := Argument.GetRequestJson();
        DirectionText := LowerCase(Reader.ReadText(Request, 'direction', false, 8, Argument));
        Forward := DirectionText = 'forward';
        if not Forward then
            DirectionText := 'backward';
        if Request.Contains('lineNo') then
            LineNo := Reader.ReadInteger(Request, 'lineNo', true, Argument);
        if not Lookup.FindSchedulingOrder(Argument, ProductionOrder) then
            exit;
        ProductionOrder.ReadIsolation := IsolationLevel::UpdLock;
        if not ProductionOrder.Get(ProductionOrder.Status, ProductionOrder."No.") then
            Error(NotReadyLbl);
        if not (ProductionOrder.Status in [ProductionOrder.Status::"Firm Planned", ProductionOrder.Status::Released]) then
            Error(NotReadyLbl);
        AddDates(BeforeDates, ProductionOrder);
        if Forward then
            NewStart := Reader.ReadDateTime(Request, 'startingDateTime', true, Argument)
        else
            NewDueDate := Reader.ReadCalendarDate(Request, 'dueDate', Argument);
        if LineNo = 0 then begin
            if Forward then
                MoveHeaderForward(ProductionOrder, NewStart)
            else
                MoveHeaderBackward(ProductionOrder, NewDueDate);
        end else begin
            if not ProdOrderLine.Get(ProductionOrder.Status, ProductionOrder."No.", LineNo) then
                Error(LineMissingLbl, LineNo);
            if Forward then
                MoveLineForward(ProductionOrder, ProdOrderLine, NewStart)
            else begin
                MoveLineBackward(ProductionOrder, ProdOrderLine, NewDueDate);
                ProductionOrder.Get(ProductionOrder.Status, ProductionOrder."No.");
                ProductionOrder.AdjustStartEndingDate();
                ProductionOrder.Modify(true);
            end;
        end;
        RefreshOrderComponents(ProductionOrder);
        ProductionOrder.Get(ProductionOrder.Status, ProductionOrder."No.");
        WriteResponse(Argument, BeforeDates, ProductionOrder, DirectionText, false, LineNo);
    end;

    local procedure ScheduleLines(ProductionOrder: Record "Production Order"; Direction: Option Forward,Backward)
    var
        ProdOrderLine: Record "Prod. Order Line";
        LineNos: List of [Integer];
        LineNo: Integer;
    begin
        ProdOrderLine.SetCurrentKey(Status, "Prod. Order No.", "Planning Level Code");
        ProdOrderLine.SetRange(Status, ProductionOrder.Status);
        ProdOrderLine.SetRange("Prod. Order No.", ProductionOrder."No.");
        if ProdOrderLine.FindSet() then
            repeat
                LineNos.Add(ProdOrderLine."Line No.");
            until ProdOrderLine.Next() = 0;
        foreach LineNo in LineNos do begin
            ProdOrderLine.Get(ProductionOrder.Status, ProductionOrder."No.", LineNo);
            ScheduleLine(ProdOrderLine, Direction);
        end;
    end;

    local procedure ScheduleLine(var ProdOrderLine: Record "Prod. Order Line"; Direction: Option Forward,Backward)
    var
        CalcProdOrder: Codeunit "Calculate Prod. Order";
        ProdOrderRouteMgt: Codeunit "Prod. Order Route Management";
    begin
        ProdOrderLine.BlockDynamicTracking(true);
        if ProdOrderLine."Routing No." = '' then begin
            CalcProdOrder.BlockDynamicTracking(true);
            CalcProdOrder.Recalculate(ProdOrderLine, Direction, true);
            ProdOrderLine.Modify(true);
        end else begin
            // Keep a changed production-order routing time. Calculate rebuilds the lines from the routing master.
            if not RoutingLinesExist(ProdOrderLine) then
                ProdOrderRouteMgt.Calculate(ProdOrderLine);
            ScheduleRouting(ProdOrderLine, Direction);
            Clear(CalcProdOrder);
            CalcProdOrder.CalculateProdOrderDates(ProdOrderLine, true);
        end;
        RefreshLineComponents(ProdOrderLine);
    end;

    local procedure ScheduleRouting(ProdOrderLine: Record "Prod. Order Line"; Direction: Option Forward,Backward)
    var
        RoutingLine: Record "Prod. Order Routing Line";
        CalcRouting: Codeunit "Calculate Routing Line";
        Operations: List of [Code[10]];
        OperationNo: Code[10];
        PlanLevel: Integer;
    begin
        PlanLevel := HighestPlanLevel(ProdOrderLine);
        if Direction = Direction::Forward then
            RoutingLine.SetCurrentKey(Status, "Prod. Order No.", "Routing Reference No.", "Routing No.", "Sequence No. (Forward)")
        else
            RoutingLine.SetCurrentKey(Status, "Prod. Order No.", "Routing Reference No.", "Routing No.", "Sequence No. (Backward)");
        RoutingLine.SetRange(Status, ProdOrderLine.Status);
        RoutingLine.SetRange("Prod. Order No.", ProdOrderLine."Prod. Order No.");
        RoutingLine.SetRange("Routing Reference No.", ProdOrderLine."Routing Reference No.");
        RoutingLine.SetRange("Routing No.", ProdOrderLine."Routing No.");
        if RoutingLine.FindSet() then
            repeat
                Operations.Add(RoutingLine."Operation No.");
            until RoutingLine.Next() = 0;
        if PlanLevel <> ProdOrderLine."Planning Level Code" then
            exit;
        foreach OperationNo in Operations do begin
            RoutingLine.Get(ProdOrderLine.Status, ProdOrderLine."Prod. Order No.", ProdOrderLine."Routing Reference No.", ProdOrderLine."Routing No.", OperationNo);
            if RoutingLine."Routing Status" <> RoutingLine."Routing Status"::Finished then begin
                if Direction = Direction::Forward then begin
                    RoutingLine."Starting Date" := ProdOrderLine."Starting Date";
                    RoutingLine."Starting Time" := ProdOrderLine."Starting Time";
                end else begin
                    RoutingLine."Ending Date" := ProdOrderLine."Ending Date";
                    RoutingLine."Ending Time" := ProdOrderLine."Ending Time";
                end;
                RoutingLine.Modify(false);
                CalcRouting.ReplanRoutingLine(RoutingLine, Direction, true);
                RoutingLine.Modify(false);
            end;
        end;
    end;

    local procedure RoutingLinesExist(ProdOrderLine: Record "Prod. Order Line"): Boolean
    var
        RoutingLine: Record "Prod. Order Routing Line";
    begin
        RoutingLine.SetRange(Status, ProdOrderLine.Status);
        RoutingLine.SetRange("Prod. Order No.", ProdOrderLine."Prod. Order No.");
        RoutingLine.SetRange("Routing Reference No.", ProdOrderLine."Routing Reference No.");
        RoutingLine.SetRange("Routing No.", ProdOrderLine."Routing No.");
        exit(not RoutingLine.IsEmpty());
    end;

    local procedure HighestPlanLevel(ProdOrderLine: Record "Prod. Order Line"): Integer
    var
        OtherLine: Record "Prod. Order Line";
        PlanLevel: Integer;
    begin
        PlanLevel := ProdOrderLine."Planning Level Code";
        OtherLine.SetLoadFields("Planning Level Code");
        OtherLine.SetCurrentKey(Status, "Prod. Order No.", "Routing No.");
        OtherLine.SetRange(Status, ProdOrderLine.Status);
        OtherLine.SetRange("Prod. Order No.", ProdOrderLine."Prod. Order No.");
        OtherLine.SetRange("Routing No.", ProdOrderLine."Routing No.");
        if OtherLine.FindSet() then
            repeat
                if PlanLevel < OtherLine."Planning Level Code" then
                    PlanLevel := OtherLine."Planning Level Code";
            until OtherLine.Next() = 0;
        exit(PlanLevel);
    end;

    local procedure DeleteUnreservedLowLevelLines(ProductionOrder: Record "Production Order")
    var
        ProdOrderLine: Record "Prod. Order Line";
        LineNos: List of [Integer];
        LineNo: Integer;
    begin
        // Removes only this order's own unreserved lower planning lines. The order header is kept.
        ProdOrderLine.SetRange(Status, ProductionOrder.Status);
        ProdOrderLine.SetRange("Prod. Order No.", ProductionOrder."No.");
        ProdOrderLine.SetFilter("Planning Level Code", '>%1', 0);
        if ProdOrderLine.FindSet() then
            repeat
                LineNos.Add(ProdOrderLine."Line No.");
            until ProdOrderLine.Next() = 0;
        foreach LineNo in LineNos do
            if ProdOrderLine.Get(ProductionOrder.Status, ProductionOrder."No.", LineNo) then begin
                ProdOrderLine.SetCalledFromComponent(true);
                ProdOrderLine.CalcFields("Reserved Qty. (Base)");
                if ProdOrderLine."Reserved Qty. (Base)" = 0 then
                    ProdOrderLine.Delete(true);
            end;
    end;

    local procedure MoveHeaderForward(var ProductionOrder: Record "Production Order"; NewStart: DateTime)
    begin
        ProductionOrder.Validate("Starting Date-Time", NewStart);
        ProductionOrder.Get(ProductionOrder.Status, ProductionOrder."No.");
    end;

    local procedure MoveHeaderBackward(var ProductionOrder: Record "Production Order"; NewDueDate: Date)
    var
        ProdOrderLine: Record "Prod. Order Line";
        LineNos: List of [Integer];
        LineNo: Integer;
    begin
        ProdOrderLine.SetRange(Status, ProductionOrder.Status);
        ProdOrderLine.SetRange("Prod. Order No.", ProductionOrder."No.");
        ProdOrderLine.SetFilter("Item No.", '<>%1', '');
        if ProdOrderLine.FindSet() then
            repeat
                LineNos.Add(ProdOrderLine."Line No.");
            until ProdOrderLine.Next() = 0;
        foreach LineNo in LineNos do begin
            ProdOrderLine.Get(ProductionOrder.Status, ProductionOrder."No.", LineNo);
            MoveLineBackward(ProductionOrder, ProdOrderLine, NewDueDate);
        end;
        ProductionOrder.Get(ProductionOrder.Status, ProductionOrder."No.");
        ProductionOrder.AdjustStartEndingDate();
        ProductionOrder."Due Date" := NewDueDate;
        ProductionOrder.Modify(true);
    end;

    local procedure MoveLineForward(var ProductionOrder: Record "Production Order"; var ProdOrderLine: Record "Prod. Order Line"; NewStart: DateTime)
    begin
        ProdOrderLine.Validate("Starting Date-Time", NewStart);
        ProductionOrder.Get(ProductionOrder.Status, ProductionOrder."No.");
        ProductionOrder.AdjustStartEndingDate();
        ProductionOrder.Modify(true);
    end;

    local procedure MoveLineBackward(var ProductionOrder: Record "Production Order"; var ProdOrderLine: Record "Prod. Order Line"; NewDueDate: Date)
    var
        LeadTimeMgt: Codeunit "Lead-Time Management";
        CalcProdOrder: Codeunit "Calculate Prod. Order";
        Backward: Option Forward,Backward;
        NewEndingDate: Date;
    begin
        ProdOrderLine."Manual Scheduling" := ProductionOrder."Manual Scheduling";
        ProdOrderLine."Due Date" := NewDueDate;
        LeadTimeMgt.SetManualScheduling(ProdOrderLine."Manual Scheduling");
        NewEndingDate := LeadTimeMgt.GetPlannedEndingDate(ProdOrderLine."Item No.", ProdOrderLine."Location Code", ProdOrderLine."Variant Code", ProdOrderLine."Due Date", '', "Requisition Ref. Order Type"::"Prod. Order");
        if not ProdOrderLine."Manual Scheduling" then
            ProdOrderLine."Ending Date" := NewEndingDate;
        ProdOrderLine.Modify(false);
        Backward := Backward::Backward;
        CalcProdOrder.SetParameter(true);
        if ProdOrderLine."Manual Scheduling" then
            CalcProdOrder.Recalculate(ProdOrderLine, Backward, false)
        else
            CalcProdOrder.Recalculate(ProdOrderLine, Backward, true);
        ProdOrderLine.Modify(true);
        ProdOrderLine.CheckEndingDate(false);
        if ProductionOrder."Due Date" = 0D then
            ProductionOrder."Due Date" := NewDueDate;
    end;

    local procedure RefreshOrderComponents(ProductionOrder: Record "Production Order")
    var
        ProdOrderLine: Record "Prod. Order Line";
    begin
        ProdOrderLine.SetRange(Status, ProductionOrder.Status);
        ProdOrderLine.SetRange("Prod. Order No.", ProductionOrder."No.");
        if ProdOrderLine.FindSet() then
            repeat
                RefreshLineComponents(ProdOrderLine);
            until ProdOrderLine.Next() = 0;
    end;

    local procedure RefreshLineComponents(ProdOrderLine: Record "Prod. Order Line")
    var
        Component: Record "Prod. Order Component";
        LineNos: List of [Integer];
        LineNo: Integer;
    begin
        Component.SetRange(Status, ProdOrderLine.Status);
        Component.SetRange("Prod. Order No.", ProdOrderLine."Prod. Order No.");
        Component.SetRange("Prod. Order Line No.", ProdOrderLine."Line No.");
        if Component.FindSet() then
            repeat
                LineNos.Add(Component."Line No.");
            until Component.Next() = 0;
        foreach LineNo in LineNos do begin
            Component.Get(ProdOrderLine.Status, ProdOrderLine."Prod. Order No.", ProdOrderLine."Line No.", LineNo);
            Component.BlockDynamicTracking(true);
            Component.Validate("Routing Link Code");
            Component.Modify(true);
        end;
    end;

    local procedure WriteResponse(var Argument: Record "Message Argument ori"; BeforeDates: JsonObject; ProductionOrder: Record "Production Order"; DirectionText: Text; IsReplan: Boolean; LineNo: Integer)
    var
        ProdOrderLine: Record "Prod. Order Line";
        RoutingLine: Record "Prod. Order Routing Line";
        CapacityNeed: Record "Prod. Order Capacity Need";
        Lookup: Codeunit "Mfg Prod Order Lookup ori";
        Response: JsonObject;
        AfterDates: JsonObject;
        Line: JsonObject;
        Routing: JsonObject;
        Warning: JsonObject;
        Lines: JsonArray;
        RoutingLines: JsonArray;
        Warnings: JsonArray;
        CapacityMissing: Boolean;
        DueWarnLbl: Label 'The due date is before the work date.', Comment = 'is-IS=Gjalddagi er fyrir vinnudagsetningu.';
        CapWarnLbl: Label 'Capacity could not be scheduled on the work center calendar.', Comment = 'is-IS=Ekki tókst að áætla afköst á dagatali vinnustöðvarinnar.';
    begin
        AddDates(AfterDates, ProductionOrder);
        ProdOrderLine.SetLoadFields("Line No.", "Starting Date-Time", "Ending Date-Time", "Due Date");
        ProdOrderLine.SetRange(Status, ProductionOrder.Status);
        ProdOrderLine.SetRange("Prod. Order No.", ProductionOrder."No.");
        if ProdOrderLine.FindSet() then
            repeat
                Clear(Line);
                Line.Add('lineNo', ProdOrderLine."Line No.");
                Line.Add('startingDateTime', Format(ProdOrderLine."Starting Date-Time", 0, 9));
                Line.Add('endingDateTime', Format(ProdOrderLine."Ending Date-Time", 0, 9));
                Line.Add('dueDate', Format(ProdOrderLine."Due Date", 0, 9));
                Lines.Add(Line);
            until ProdOrderLine.Next() = 0;
        RoutingLine.SetLoadFields("Operation No.", Type, "No.", "Work Center No.", "Starting Date-Time", "Ending Date-Time", "Starting Date");
        RoutingLine.SetRange(Status, ProductionOrder.Status);
        RoutingLine.SetRange("Prod. Order No.", ProductionOrder."No.");
        if RoutingLine.FindSet() then
            repeat
                Clear(Routing);
                Routing.Add('operationNo', RoutingLine."Operation No.");
                Routing.Add('type', CapacityTypeName(RoutingLine.Type));
                Routing.Add('no', RoutingLine."No.");
                Routing.Add('workCenterNo', RoutingLine."Work Center No.");
                Routing.Add('startingDateTime', Format(RoutingLine."Starting Date-Time", 0, 9));
                Routing.Add('endingDateTime', Format(RoutingLine."Ending Date-Time", 0, 9));
                RoutingLines.Add(Routing);
                if RoutingLine."Starting Date" = 0D then
                    CapacityMissing := true;
            until RoutingLine.Next() = 0;
        CapacityNeed.SetLoadFields("Line No.");
        CapacityNeed.SetRange(Status, ProductionOrder.Status);
        CapacityNeed.SetRange("Prod. Order No.", ProductionOrder."No.");
        if (RoutingLines.Count() > 0) and CapacityNeed.IsEmpty() then
            CapacityMissing := true;
        if (ProductionOrder."Due Date" <> 0D) and (ProductionOrder."Due Date" < WorkDate()) then begin
            Warning.Add('code', 'dueDateBeforeToday');
            Warning.Add('message', DueWarnLbl);
            Warnings.Add(Warning);
            Clear(Warning);
        end;
        if CapacityMissing then begin
            Warning.Add('code', 'capacityExceeded');
            Warning.Add('message', CapWarnLbl);
            Warnings.Add(Warning);
        end;
        Response.Add('status', 'Success');
        Response.Add('productionOrderStatus', Lookup.StatusName(ProductionOrder.Status));
        Response.Add('no', ProductionOrder."No.");
        Response.Add('systemId', Format(ProductionOrder.SystemId, 0, 4));
        Response.Add('direction', DirectionText);
        if IsReplan then
            Response.Add('calcMethod', 'noLevels');
        if not IsReplan then
            Response.Add('lineNo', LineNo);
        Response.Add('before', BeforeDates);
        Response.Add('after', AfterDates);
        Response.Add('lines', Lines);
        Response.Add('routingLines', RoutingLines);
        Response.Add('warnings', Warnings);
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure AddDates(var Dates: JsonObject; ProductionOrder: Record "Production Order")
    begin
        Dates.Add('startingDate', Format(ProductionOrder."Starting Date", 0, 9));
        Dates.Add('endingDate', Format(ProductionOrder."Ending Date", 0, 9));
        Dates.Add('dueDate', Format(ProductionOrder."Due Date", 0, 9));
        Dates.Add('startingDateTime', Format(ProductionOrder."Starting Date-Time", 0, 9));
        Dates.Add('endingDateTime', Format(ProductionOrder."Ending Date-Time", 0, 9));
    end;

    local procedure CapacityTypeName(CapacityType: Enum "Capacity Type"): Text
    begin
        case CapacityType of
            CapacityType::"Work Center":
                exit('workCenter');
            CapacityType::"Machine Center":
                exit('machineCenter');
        end;
        exit('');
    end;
}
