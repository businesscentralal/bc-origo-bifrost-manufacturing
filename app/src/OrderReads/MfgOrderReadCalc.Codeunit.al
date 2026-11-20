namespace Origo.Bifrost.Manufacturing;

using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Setup;
using Microsoft.Inventory.Tracking;
using Microsoft.Purchases.Document;
using Microsoft.Sales.Document;

using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Inventory.Costing;
using Microsoft.Inventory.Item;
using Microsoft.Manufacturing.Capacity;
using Microsoft.Manufacturing.Document;
using Microsoft.Manufacturing.MachineCenter;
using Microsoft.Manufacturing.Setup;
using Microsoft.Manufacturing.WorkCenter;

/// <summary>Reads shortage-list quantities and the native production order statistics calculations.</summary>
codeunit 10077066 "Mfg Order Read Calc ori"
{
    Access = Internal;
    Permissions =
        tabledata "Item" = R,
        tabledata "Item Ledger Entry" = R,
        tabledata "Value Entry" = R,
        tabledata "Inventory Adjmt. Entry (Order)" = R,
        tabledata "Stockkeeping Unit" = R,
        tabledata "Prod. Order Line" = R,
        tabledata "Production Order" = R,
        tabledata "Prod. Order Component" = R,
        tabledata "Prod. Order Routing Line" = R,
        tabledata "Prod. Order Capacity Need" = R,
        tabledata "Capacity Ledger Entry" = R,
        tabledata "Work Center" = R,
        tabledata "Machine Center" = R,
        tabledata "Manufacturing Setup" = R,
        tabledata "General Ledger Setup" = R,
        tabledata "Capacity Unit of Measure" = R,
        tabledata "Reservation Entry" = R,
        tabledata "Sales Line" = R,
        tabledata "Purchase Line" = R,
        tabledata "Item Application Entry" = R,
        tabledata "Inventory Setup" = R,
        tabledata "Location" = R,
        tabledata "Item Unit of Measure" = R;

    /// <summary>Returns each selected inventory component, with shortage-list priority and reservation arithmetic in base units.</summary>
    internal procedure Availability(Order: Record "Production Order"; LineNo: Integer; LocationCode: Code[10]; FilterLocation: Boolean; var Result: JsonObject)
    var
        Component: Record "Prod. Order Component";
        Item: Record Item;
        Components: JsonArray;
        Row: JsonObject;
    begin
        Component.SetRange(Status, Order.Status);
        Component.SetRange("Prod. Order No.", Order."No.");
        if LineNo <> 0 then
            Component.SetRange("Prod. Order Line No.", LineNo);
        if FilterLocation then
            Component.SetRange("Location Code", LocationCode);
        Component.SetLoadFields("Prod. Order Line No.", "Line No.", "Item No.", "Variant Code", "Location Code", "Expected Qty. (Base)", "Remaining Qty. (Base)", "Due Date", "Flushing Method");
        if Component.FindSet() then
            repeat
                Item.Get(Component."Item No.");
                if not Item.IsNonInventoriableType() then begin
                    Clear(Row);
                    Row.Add('lineNo', Component."Prod. Order Line No.");
                    Row.Add('componentLineNo', Component."Line No.");
                    Row.Add('itemNo', Component."Item No.");
                    Row.Add('variantCode', Component."Variant Code");
                    Row.Add('locationCode', Component."Location Code");
                    Row.Add('expectedQuantity', Component."Expected Qty. (Base)");
                    Row.Add('remainingQuantity', Component."Remaining Qty. (Base)");
                    Row.Add('dueDate', Component."Due Date");
                    Row.Add('flushingMethod', Component."Flushing Method".Names().Get(Component."Flushing Method".Ordinals().IndexOf(Component."Flushing Method".AsInteger())));
                    Shortage(Component, Item, Row);
                    Components.Add(Row);
                end;
            until Component.Next() = 0;
        Result.Add('components', Components);
    end;

    local procedure Shortage(Component: Record "Prod. Order Component"; Item: Record Item; var Row: JsonObject)
    var
        Supply: Record "Prod. Order Line";
        Demand: Record "Prod. Order Component";
        Inventory: Decimal;
        ScheduledReceipts: Decimal;
        GrossRequirement: Decimal;
        ProjectedAvailable: Decimal;
        ShortageQty: Decimal;
    begin
        // Mirrors report 99000788: dates before the component date, then same-day priority.
        Item.SetRange("Variant Filter", Component."Variant Code");
        Item.SetRange("Location Filter", Component."Location Code");
        Item.SetRange("Date Filter", 0D, Component."Due Date" - 1);
        Item.CalcFields(Inventory, "Reserved Qty. on Inventory", "Scheduled Receipt (Qty.)", "Reserved Qty. on Prod. Order", "Qty. on Component Lines", "Res. Qty. on Prod. Order Comp.");
        Inventory := Item.Inventory - Item."Reserved Qty. on Inventory";
        ScheduledReceipts := Item."Scheduled Receipt (Qty.)" - Item."Reserved Qty. on Prod. Order";
        GrossRequirement := Item."Qty. on Component Lines" - Item."Res. Qty. on Prod. Order Comp.";
        Item.SetRange("Date Filter", 0D, Component."Due Date");
        Item.CalcFields("Qty. on Sales Order", "Reserved Qty. on Sales Orders", "Qty. on Purch. Order", "Reserved Qty. on Purch. Orders");
        ScheduledReceipts += Item."Qty. on Purch. Order" - Item."Reserved Qty. on Purch. Orders";
        GrossRequirement += Item."Qty. on Sales Order" - Item."Reserved Qty. on Sales Orders";
        Supply.SetRange("Item No.", Component."Item No.");
        Supply.SetRange("Variant Code", Component."Variant Code");
        Supply.SetRange("Location Code", Component."Location Code");
        Supply.SetRange("Due Date", Component."Due Date");
        Supply.SetRange(Status, Supply.Status::Planned, Enum::"Production Order Status".FromInteger(Component.Status.AsInteger() - 1));
        ScheduledReceipts += NetSupply(Supply);
        Supply.SetRange(Status, Component.Status);
        Supply.SetRange("Prod. Order No.", Component."Prod. Order No.");
        ScheduledReceipts += NetSupply(Supply);
        Demand.SetRange("Item No.", Component."Item No.");
        Demand.SetRange("Variant Code", Component."Variant Code");
        Demand.SetRange("Location Code", Component."Location Code");
        Demand.SetRange("Due Date", Component."Due Date");
        Demand.SetRange(Status, Demand.Status::Planned, Enum::"Production Order Status".FromInteger(Component.Status.AsInteger() - 1));
        GrossRequirement += NetDemand(Demand);
        Demand.SetRange(Status, Component.Status);
        Demand.SetFilter("Prod. Order No.", '<%1', Component."Prod. Order No.");
        GrossRequirement += NetDemand(Demand);
        Demand.SetRange("Prod. Order No.", Component."Prod. Order No.");
        Demand.SetRange("Prod. Order Line No.", 0, Component."Prod. Order Line No.");
        GrossRequirement += NetDemand(Demand);
        ProjectedAvailable := Inventory + ScheduledReceipts - GrossRequirement;
        if ProjectedAvailable < 0 then
            ShortageQty := -ProjectedAvailable;
        Row.Add('inventory', Inventory);
        Row.Add('scheduledReceipts', ScheduledReceipts);
        Row.Add('grossRequirement', GrossRequirement);
        Row.Add('projectedAvailable', ProjectedAvailable);
        Row.Add('shortage', ShortageQty);
    end;

    local procedure NetSupply(var Line: Record "Prod. Order Line") Total: Decimal
    begin
        Line.SetLoadFields("Remaining Qty. (Base)");
        if Line.FindSet() then
            repeat
                Line.CalcFields("Reserved Qty. (Base)");
                Total += Line."Remaining Qty. (Base)" - Line."Reserved Qty. (Base)";
            until Line.Next() = 0;
    end;

    local procedure NetDemand(var Component: Record "Prod. Order Component") Total: Decimal
    begin
        Component.SetLoadFields("Remaining Qty. (Base)");
        if Component.FindSet() then
            repeat
                Component.CalcFields("Reserved Qty. (Base)");
                Total += Component."Remaining Qty. (Base)" - Component."Reserved Qty. (Base)";
            until Component.Next() = 0;
    end;

    /// <summary>Uses the Statistics page costing routines, LCY rounding and top-level line selection.</summary>
    internal procedure Statistics(Order: Record "Production Order"; LineNo: Integer; var Result: JsonObject)
    var
        Line: Record "Prod. Order Line";
        ShareLine: Record "Prod. Order Line";
        GLSetup: Record "General Ledger Setup";
        MfgSetup: Record "Manufacturing Setup";
        Cost: Codeunit "Mfg. Cost Calculation Mgt.";
        Calendar: Codeunit "Shop Calendar Management";
        Standard: array[6] of Decimal;
        Expected: array[6] of Decimal;
        Actual: array[6] of Decimal;
        Variance: array[6] of Decimal;
        Percent: array[6] of Decimal;
        Dummy: array[5] of Decimal;
        Share: Decimal;
        Output: Decimal;
        Scrap: Decimal;
        CapacityNeed: Decimal;
        CapacityUsed: Decimal;
        Index: Integer;
        VarianceJson: JsonObject;
    begin
        GLSetup.Get();
        MfgSetup.Get();
        MfgSetup.TestField("Show Capacity In");
        Line.SetRange(Status, Order.Status);
        Line.SetRange("Prod. Order No.", Order."No.");
        Line.SetRange("Planning Level Code", 0);
        Line.SetFilter("Item No.", '<>%1', '');
        if LineNo <> 0 then
            Line.SetRange("Line No.", LineNo);
        // Native routines read the complete line; preserve all fields for their subscribers.
        if Line.FindSet() then
            repeat
                ShareLine.Copy(Line);
                ShareLine.SetRange("Line No.");
                Cost.CalcShareOfTotalCapCost(ShareLine, Share);
                Cost.CalcProdOrderLineStdCost(Line, 1, GLSetup."Amount Rounding Precision", Standard[1], Standard[2], Standard[3], Standard[4], Standard[5]);
                Cost.CalcProdOrderLineExpCost(Line, Share, Expected[1], Expected[2], Expected[3], Expected[4], Expected[5]);
                Cost.CalcProdOrderLineActCost(Line, Actual[1], Actual[2], Actual[3], Actual[4], Actual[5], Dummy[1], Dummy[2], Dummy[3], Dummy[4], Dummy[5]);
                Output += Line."Finished Qty. (Base)";
            until Line.Next() = 0;
        for Index := 1 to 5 do begin
            Standard[6] += Standard[Index];
            Expected[6] += Expected[Index];
            Actual[6] += Actual[Index];
        end;
        for Index := 1 to 6 do begin
            Variance[Index] := Actual[Index] - Standard[Index];
            if Standard[Index] <> 0 then
                Percent[Index] := Round(Variance[Index] / Standard[Index] * 100, 1);
        end;
        Capacity(Order, LineNo, CapacityNeed, CapacityUsed, Scrap);
        Result.Add('standard', CostBlock(Standard));
        Result.Add('expected', CostBlock(Expected));
        Result.Add('actual', CostBlock(Actual));
        VarianceJson.Add('amount', CostBlock(Variance));
        VarianceJson.Add('percent', CostBlock(Percent));
        Result.Add('variance', VarianceJson);
        Result.Add('capacityNeed', CapacityNeed / Calendar.TimeFactor(MfgSetup."Show Capacity In"));
        Result.Add('capacityUsed', CapacityUsed / Calendar.TimeFactor(MfgSetup."Show Capacity In"));
        Result.Add('capacityUnitOfMeasure', MfgSetup."Show Capacity In");
        Result.Add('output', Output);
        Result.Add('scrap', Scrap);
        Result.Add('currencyCode', '');
    end;

    local procedure CostBlock(Values: array[6] of Decimal) Block: JsonObject
    begin
        Block.Add('material', Values[1]);
        Block.Add('capacity', Values[2]);
        Block.Add('subcontracted', Values[3]);
        Block.Add('capacityOverhead', Values[4]);
        Block.Add('manufacturingOverhead', Values[5]);
        Block.Add('total', Values[6]);
    end;

    local procedure Capacity(Order: Record "Production Order"; LineNo: Integer; var Needed: Decimal; var Used: Decimal; var Scrap: Decimal)
    var
        Need: Record "Prod. Order Capacity Need";
        Routing: Record "Prod. Order Routing Line";
        Entry: Record "Capacity Ledger Entry";
        Center: Record "Work Center";
        Line: Record "Prod. Order Line";
        Calendar: Codeunit "Shop Calendar Management";
        Cost: Codeunit "Mfg. Cost Calculation Mgt.";
        UnitCode: Code[10];
        QtyPerUnit: Decimal;
        Share: Decimal;
        RoutingReferenceNo: Integer;
    begin
        if LineNo <> 0 then begin
            Line.Get(Order.Status, Order."No.", LineNo);
            RoutingReferenceNo := Line."Routing Reference No.";
            Line.SetRange("Planning Level Code", 0);
            Line.SetFilter("Item No.", '<>%1', '');
            Cost.CalcShareOfTotalCapCost(Line, Share);
        end;
        if LineNo = 0 then begin
            Needed := Cost.CalcProdOrderExpCapNeed(Order, false);
            Used := Cost.CalcProdOrderActTimeUsed(Order, false);
        end else
            if Order.Status = Order.Status::Finished then begin
                Routing.SetRange(Status, Order.Status);
                Routing.SetRange("Prod. Order No.", Order."No.");
                Routing.SetRange("Routing Reference No.", RoutingReferenceNo);
                Routing.SetLoadFields(Type, "No.", "Expected Capacity Need");
                if Routing.FindSet() then
                    repeat
                        Clear(Center);
                        if Routing.Type = Routing.Type::"Work Center" then
                            if Center.Get(Routing."No.") then;
                        if Center."Subcontractor No." = '' then
                            Needed += Routing."Expected Capacity Need";
                    until Routing.Next() = 0;
            end else begin
                Need.SetRange(Status, Order.Status);
                Need.SetRange("Prod. Order No.", Order."No.");
                Need.SetRange("Routing Reference No.", RoutingReferenceNo);
                Need.SetRange("Requested Only", false);
                Need.SetLoadFields(Type, "No.", "Needed Time (ms)");
                if Need.FindSet() then
                    repeat
                        Clear(Center);
                        if Need.Type = Need.Type::"Work Center" then
                            if Center.Get(Need."No.") then;
                        if Center."Subcontractor No." = '' then
                            Needed += Need."Needed Time (ms)";
                    until Need.Next() = 0;
            end;
        if LineNo <> 0 then
            Needed *= Share;
        if Order.IsStatusLessThanReleased() then
            exit;
        Entry.SetRange("Order Type", Entry."Order Type"::Production);
        Entry.SetRange("Order No.", Order."No.");
        if LineNo <> 0 then
            Entry.SetRange("Order Line No.", LineNo);
        Entry.SetLoadFields(Type, "No.", "Work Center No.", Quantity, "Scrap Quantity", "Cap. Unit of Measure Code", "Qty. per Cap. Unit of Measure");
        if Entry.FindSet() then
            repeat
                Scrap += Entry."Scrap Quantity";
                if LineNo <> 0 then begin
                    Clear(Center);
                    if Entry.Type = Entry.Type::"Work Center" then
                        if Center.Get(Entry."No.") then;
                    if Center."Subcontractor No." = '' then begin
                        UnitCode := Entry."Cap. Unit of Measure Code";
                        QtyPerUnit := Entry."Qty. per Cap. Unit of Measure";
                        if QtyPerUnit = 0 then begin
                            if Center.Get(Entry."Work Center No.") then
                                UnitCode := Center."Unit of Measure Code";
                            QtyPerUnit := 1;
                        end;
                        Used += Entry.Quantity / QtyPerUnit * Calendar.TimeFactor(UnitCode);
                    end;
                end;
            until Entry.Next() = 0;
    end;
}
