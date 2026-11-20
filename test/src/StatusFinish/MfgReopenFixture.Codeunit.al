namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Finance.GeneralLedger.Account;
using Microsoft.Finance.GeneralLedger.Ledger;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Foundation.UOM;
using Microsoft.Inventory.Costing;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Posting;
using Microsoft.Inventory.Setup;
using Microsoft.Inventory.Tracking;
using Microsoft.Manufacturing.Capacity;
using Microsoft.Manufacturing.Document;
using Microsoft.Manufacturing.ProductionBOM;
using Microsoft.Manufacturing.Routing;
using Microsoft.Manufacturing.Setup;
using Microsoft.Manufacturing.WorkCenter;
using Origo.Bifrost;
using System.TestLibraries.Utilities;
using System.Utilities;

/// <summary>Creates Reopen lifecycle fixtures from raw records; no CRONUS business data or library lookups.</summary>
codeunit 97637 "Mfg Reopen Fixture ori"
{
    /// <summary>Creates an owned location, posting groups, accounts, items and released order with five components needed.</summary>
    procedure Seed(Prefix: Code[10]; var Order: Record "Production Order")
    var
        Uom: Record "Unit of Measure";
        CapUom: Record "Capacity Unit of Measure";
        Location: Record Location;
        Account: Record "G/L Account";
        GenProd: Record "Gen. Product Posting Group";
        GenBus: Record "Gen. Business Posting Group";
        GenPosting: Record "General Posting Setup";
        InvGroup: Record "Inventory Posting Group";
        InvPosting: Record "Inventory Posting Setup";
        Line: Record "Prod. Order Line";
        Component: Record "Prod. Order Component";
    begin
        Cleanup(Prefix);
        Uom.Code := Prefix;
        Uom.Description := Prefix;
        Uom.Insert();
        CapUom.Code := Prefix;
        CapUom.Type := CapUom.Type::Hours;
        CapUom.Insert();
        Location.Code := Prefix;
        Location.Name := Prefix;
        Location.Insert();
        Account."No." := Prefix;
        Account.Name := Prefix;
        Account."Direct Posting" := true;
        Account.Insert();
        GenProd.Code := Prefix;
        GenProd.Insert();
        GenBus.Code := Prefix;
        GenBus.Insert();
        GenPosting."Gen. Bus. Posting Group" := Prefix;
        GenPosting."Gen. Prod. Posting Group" := Prefix;
        GenPosting."Purch. Account" := Prefix;
        GenPosting."COGS Account" := Prefix;
        GenPosting."COGS Account (Interim)" := Prefix;
        GenPosting."Inventory Adjmt. Account" := Prefix;
        GenPosting."Direct Cost Applied Account" := Prefix;
        GenPosting."Overhead Applied Account" := Prefix;
        GenPosting."Purchase Variance Account" := Prefix;
        GenPosting.Insert();
        GenPosting."Gen. Bus. Posting Group" := '';
        GenPosting.Insert();
        InvGroup.Code := Prefix;
        InvGroup.Insert();
        InvPosting."Location Code" := Prefix;
        InvPosting."Invt. Posting Group Code" := Prefix;
        InvPosting."Inventory Account" := Prefix;
        InvPosting."Inventory Account (Interim)" := Prefix;
        InvPosting."WIP Account" := Prefix;
        InvPosting."Material Variance Account" := Prefix;
        InvPosting."Capacity Variance Account" := Prefix;
        InvPosting."Subcontracted Variance Account" := Prefix;
        InvPosting."Cap. Overhead Variance Account" := Prefix;
        InvPosting."Mfg. Overhead Variance Account" := Prefix;
        InvPosting.Insert();
        CreateItem(Prefix + '-C', Prefix, 2, false);
        CreateItem(Prefix + '-P', Prefix, 10, true);
        Order.Status := Order.Status::Released;
        Order."No." := Prefix;
        Order."Source Type" := Order."Source Type"::Item;
        Order."Source No." := Prefix + '-P';
        Order.Quantity := 1;
        Order."Location Code" := Prefix;
        Order."Due Date" := WorkDate() + 1;
        Order.Insert();
        Line.Status := Order.Status;
        Line."Prod. Order No." := Order."No.";
        Line."Line No." := 10000;
        Line."Item No." := Prefix + '-P';
        Line."Location Code" := Prefix;
        Line.Quantity := 1;
        Line."Quantity (Base)" := 1;
        Line."Remaining Quantity" := 1;
        Line."Remaining Qty. (Base)" := 1;
        Line."Qty. per Unit of Measure" := 1;
        Line."Unit of Measure Code" := Prefix;
        Line."Due Date" := Order."Due Date";
        Line."Unit Cost" := 10;
        Line."Cost Amount" := 10;
        Line.Insert();
        Component.Status := Order.Status;
        Component."Prod. Order No." := Order."No.";
        Component."Prod. Order Line No." := 10000;
        Component."Line No." := 10000;
        Component."Item No." := Prefix + '-C';
        Component."Location Code" := Prefix;
        Component."Quantity per" := 5;
        Component."Expected Quantity" := 5;
        Component."Expected Qty. (Base)" := 5;
        Component."Remaining Quantity" := 5;
        Component."Remaining Qty. (Base)" := 5;
        Component."Qty. per Unit of Measure" := 1;
        Component."Unit of Measure Code" := Prefix;
        Component."Due Date" := Order."Due Date";
        Component."Flushing Method" := Component."Flushing Method"::Manual;
        Component."Unit Cost" := 2;
        Component."Cost Amount" := 10;
        Component.Insert();
        AddBomAndRouting(Prefix, Order);
    end;

    local procedure AddBomAndRouting(Prefix: Code[10]; var Order: Record "Production Order")
    var
        Bom: Record "Production BOM Header";
        BomLine: Record "Production BOM Line";
        Routing: Record "Routing Header";
        RoutingLine: Record "Routing Line";
        Center: Record "Work Center";
        CenterGroup: Record "Work Center Group";
        Calendar: Record "Shop Calendar";
        WorkingDay: Record "Shop Calendar Working Days";
        Shift: Record "Work Shift";
        Item: Record Item;
        Line: Record "Prod. Order Line";
        OrderRouting: Record "Prod. Order Routing Line";
        Manufacturing: Codeunit "Library - Manufacturing";
        DayNo: Integer;
    begin
        Shift.Code := Prefix;
        Shift.Description := Prefix;
        Shift.Insert();
        Calendar.Code := Prefix;
        Calendar.Description := Prefix;
        Calendar.Insert();
        for DayNo := 1 to 7 do begin
            WorkingDay.Init();
            WorkingDay."Shop Calendar Code" := Prefix;
            WorkingDay.Day := DayNo - 1;
            WorkingDay."Work Shift Code" := Prefix;
            WorkingDay."Starting Time" := 080000T;
            WorkingDay."Ending Time" := 170000T;
            WorkingDay.Insert();
        end;
        CenterGroup.Code := Prefix;
        CenterGroup.Name := Prefix;
        CenterGroup.Insert();
        Center."Work Center Group Code" := Prefix;
        Center."No." := Prefix;
        Center.Name := Prefix;
        Center."Unit of Measure Code" := Prefix;
        Center."Shop Calendar Code" := Prefix;
        Center.Capacity := 1;
        Center.Efficiency := 100;
        Center."Gen. Prod. Posting Group" := Prefix;
        Center."Flushing Method" := Center."Flushing Method"::Manual;
        Center.Insert();
        Manufacturing.CalculateWorkCenterCalendar(Center, WorkDate() - 30, WorkDate() + 30);
        Bom."No." := Prefix;
        Bom."Unit of Measure Code" := Prefix;
        Bom.Insert();
        BomLine."Production BOM No." := Prefix;
        BomLine."Line No." := 10000;
        BomLine.Type := BomLine.Type::Item;
        BomLine.Validate("No.", Prefix + '-C');
        BomLine.Validate("Quantity per", 5);
        BomLine.Insert(true);
        Manufacturing.UpdateProductionBOMStatus(Bom, Bom.Status::Certified);
        Routing."No." := Prefix;
        Routing.Insert();
        RoutingLine."Routing No." := Prefix;
        RoutingLine."Operation No." := '10';
        RoutingLine.Type := RoutingLine.Type::"Work Center";
        RoutingLine.Validate("No.", Prefix);
        RoutingLine.Validate("Run Time", 1);
        RoutingLine.Insert(true);
        Manufacturing.UpdateRoutingStatus(Routing, Routing.Status::Certified);
        Item.Get(Prefix + '-P');
        Item.Validate("Production BOM No.", Prefix);
        Item.Validate("Routing No.", Prefix);
        Item.Modify(true);
        Order."Routing No." := Prefix;
        Order.Modify();
        Line.Get(Order.Status, Order."No.", 10000);
        Line."Production BOM No." := Prefix;
        Line."Routing No." := Prefix;
        Line."Routing Reference No." := Line."Line No.";
        Line.Modify();
        OrderRouting.Status := Order.Status;
        OrderRouting."Prod. Order No." := Order."No.";
        OrderRouting."Routing Reference No." := Line."Line No.";
        OrderRouting."Routing No." := Prefix;
        OrderRouting."Operation No." := '10';
        OrderRouting.Type := OrderRouting.Type::"Work Center";
        OrderRouting."No." := Prefix;
        OrderRouting."Work Center No." := Prefix;
        OrderRouting."Run Time" := 1;
        OrderRouting."Run Time Unit of Meas. Code" := Prefix;
        OrderRouting."Flushing Method" := OrderRouting."Flushing Method"::Manual;
        OrderRouting.Insert();
    end;

    /// <summary>Creates an owned fully posted and finished order through the public journal and Finish operations.</summary>
    procedure PrepareFinished(Prefix: Code[10]; var Order: Record "Production Order")
    var
        Data: Codeunit "Mfg Test Data ori";
        Lib: Codeunit "Mfg Status Test Lib ori";
        Assert: Codeunit "Library Assert";
        Request: JsonObject;
        Response: JsonObject;
        ResponseText: Text;
    begin
        Seed(Prefix, Order);
        Post(Prefix, "Item Ledger Entry Type"::"Positive Adjmt.", 20);
        Commit();
        Request := Lib.IdRequest(Order);
        Request.Add('consumptionBasis', 'ExpectedOutput');
        Request.Add('expectedCount', 2);
        Response := Data.Invoke("Message Type ori"::"Manufacturing.ProductionJournal.Post", Request, 1033, false);
        Response.WriteTo(ResponseText);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Post self-made fixture: ' + ResponseText);
        Request := Lib.IdRequest(Order);
        Request.Add('expectedCount', 1);
        Response := Lib.Finish(Request, 1033);
        Response.WriteTo(ResponseText);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Finish self-made fixture: ' + ResponseText);
        Lib.ReadBack(Response, Order);
    end;

    /// <summary>Reads the exact persisted Foundation message response and verifies the refusal code.</summary>
    procedure AssertLoggedError(MessageId: Guid; ExpectedCode: Text)
    var
        Assert: Codeunit "Library Assert";
        Blob: Codeunit "Temp Blob";
        Log: RecordRef;
        IdField: FieldRef;
        ResponseField: FieldRef;
        Stream: InStream;
        Raw: Text;
        Response: JsonObject;
        Token: JsonToken;
    begin
        // Foundation's dispatcher returns the ID of its persisted message (table 10077897).
        Log.Open(10077897);
        IdField := Log.Field(1);
        IdField.SetRange(MessageId);
        Assert.IsTrue(Log.FindFirst(), 'Foundation persisted the exact message.');
        ResponseField := Log.Field(9);
        ResponseField.CalcField();
        Blob.FromFieldRef(ResponseField);
        Blob.CreateInStream(Stream, TextEncoding::UTF8);
        Stream.ReadText(Raw);
        Assert.IsTrue(Response.ReadFrom(Raw), 'Foundation log contains JSON response.');
        Response.Get('status', Token);
        Assert.AreEqual('Error', Token.AsValue().AsText(), 'Foundation log records an error.');
        Response.Get('code', Token);
        Assert.AreEqual(ExpectedCode, Token.AsValue().AsText(), 'Foundation log preserves the refusal code.');
        Response.Get('nextStep', Token);
        Assert.AreNotEqual('', Token.AsValue().AsText(), 'Foundation log preserves nextStep.');
        Log.Close();
    end;

    local procedure CreateItem(Number: Code[20]; Prefix: Code[10]; Cost: Decimal; Manufactured: Boolean)
    var
        Item: Record Item;
        ItemUom: Record "Item Unit of Measure";
    begin
        Item."No." := Number;
        Item.Description := Number;
        Item."Base Unit of Measure" := Prefix;
        Item."Gen. Prod. Posting Group" := Prefix;
        Item."Inventory Posting Group" := Prefix;
        Item."Costing Method" := Item."Costing Method"::Standard;
        Item."Unit Cost" := Cost;
        Item."Standard Cost" := Cost;
        Item."Single-Level Material Cost" := Cost;
        Item."Flushing Method" := Item."Flushing Method"::Manual;
        if Manufactured then
            Item."Replenishment System" := Item."Replenishment System"::"Prod. Order";
        Item.Insert();
        ItemUom."Item No." := Number;
        ItemUom.Code := Prefix;
        ItemUom."Qty. per Unit of Measure" := 1;
        ItemUom.Insert();
    end;

    /// <summary>Posts stock or production usage using a self-built journal template, batch and line.</summary>
    procedure Post(Prefix: Code[10]; EntryType: Enum "Item Ledger Entry Type"; Quantity: Decimal)
    var
        JournalTemplate: Record "Item Journal Template";
        Batch: Record "Item Journal Batch";
        Journal: Record "Item Journal Line";
        PostLine: Codeunit "Item Jnl.-Post Line";
    begin
        if not JournalTemplate.Get(Prefix) then begin
            JournalTemplate.Name := Prefix;
            JournalTemplate.Type := JournalTemplate.Type::Item;
            JournalTemplate.Insert();
            Batch."Journal Template Name" := Prefix;
            Batch.Name := Prefix;
            Batch.Insert();
        end;
        Journal."Journal Template Name" := Prefix;
        Journal."Journal Batch Name" := Prefix;
        Journal."Line No." := 10000;
        Journal.Validate("Posting Date", WorkDate());
        Journal."Document No." := Prefix;
        Journal.Validate("Entry Type", EntryType);
        if EntryType = EntryType::Output then
            Journal.Validate("Item No.", Prefix + '-P')
        else
            Journal.Validate("Item No.", Prefix + '-C');
        Journal.Validate("Location Code", Prefix);
        if EntryType in [EntryType::Consumption, EntryType::Output] then begin
            Journal."Source Type" := Journal."Source Type"::Item;
            Journal."Source No." := Prefix + '-P';
            Journal."Order Type" := Journal."Order Type"::Production;
            Journal."Order No." := Prefix;
            Journal."Order Line No." := 10000;
        end;
        if EntryType = EntryType::Consumption then
            Journal."Prod. Order Comp. Line No." := 10000;
        if EntryType = EntryType::Output then begin
            Journal.Validate("Output Quantity", Quantity);
            Journal.Finished := true;
        end else
            Journal.Validate(Quantity, Quantity);
        Journal.Insert();
        PostLine.RunWithCheck(Journal);
        Journal.Delete();
    end;

    /// <summary>Finishes a fully posted fixture using native status management and runs native cost adjustment for owned items only.</summary>
    procedure FinishAndAdjust(var Order: Record "Production Order")
    var
        Finished: Record "Production Order";
        Item: Record Item;
        StatusMgt: Codeunit "Prod. Order Status Management";
        Adjustment: Codeunit "Inventory Adjustment";
    begin
        StatusMgt.ChangeProdOrderStatus(Order, Finished, Order.Status::Finished, WorkDate(), false);
        Order := Finished;
        Item.SetFilter("No.", '%1|%2', Order."No." + '-C', Order."No." + '-P');
        Adjustment.SetFilterItem(Item);
        Adjustment.SetProperties(false, false);
        Adjustment.MakeMultiLevelAdjmt();
    end;

    /// <summary>Removes only the fixed-prefix MCP fixture and the entries posted for its two new items.</summary>
    procedure Cleanup(Prefix: Code[10])
    var
        ItemEntry: Record "Item Ledger Entry";
        ValueEntry: Record "Value Entry";
        Application: Record "Item Application Entry";
        Relation: Record "G/L - Item Ledger Relation";
        EntryRelation: Record "Item Entry Relation";
        GL: Record "G/L Entry";
        Order: Record "Production Order";
        Line: Record "Prod. Order Line";
        Component: Record "Prod. Order Component";
        ItemUom: Record "Item Unit of Measure";
        Item: Record Item;
        AdjustmentOrder: Record "Inventory Adjmt. Entry (Order)";
        AvgCost: Record "Avg. Cost Adjmt. Entry Point";
        PostingQueue: Record "Post Value Entry to G/L";
        Journal: Record "Item Journal Line";
        Batch: Record "Item Journal Batch";
        JournalTemplate: Record "Item Journal Template";
        GenPosting: Record "General Posting Setup";
        InvPosting: Record "Inventory Posting Setup";
        GenProd: Record "Gen. Product Posting Group";
        GenBus: Record "Gen. Business Posting Group";
        InvGroup: Record "Inventory Posting Group";
        Location: Record Location;
        Uom: Record "Unit of Measure";
        CapUom: Record "Capacity Unit of Measure";
        Account: Record "G/L Account";
        OrderRouting: Record "Prod. Order Routing Line";
        CapacityEntry: Record "Capacity Ledger Entry";
        Bom: Record "Production BOM Header";
        BomLine: Record "Production BOM Line";
        Routing: Record "Routing Header";
        RoutingLine: Record "Routing Line";
        Center: Record "Work Center";
        CenterGroup: Record "Work Center Group";
        CalendarEntry: Record "Calendar Entry";
        Calendar: Record "Shop Calendar";
        WorkingDay: Record "Shop Calendar Working Days";
        Shift: Record "Work Shift";
        Absence: Record "Calendar Absence Entry";
        OwnedItems: Text;
    begin
        if not (Prefix in ['X22REOPEN', 'X22MCPEN', 'X22MCPIS']) then
            Error('Only issue 22 fixture prefixes can be cleaned.');
        OwnedItems := Prefix + '-C|' + Prefix + '-P';
        CleanupRegisters(Prefix, OwnedItems);
        ItemEntry.SetFilter("Item No.", OwnedItems);
        if ItemEntry.FindSet() then
            repeat
                Application.SetRange("Item Ledger Entry No.", ItemEntry."Entry No.");
                Application.DeleteAll();
                Application.SetRange("Item Ledger Entry No.");
                Application.SetRange("Inbound Item Entry No.", ItemEntry."Entry No.");
                Application.DeleteAll();
                Application.SetRange("Inbound Item Entry No.");
                Application.SetRange("Outbound Item Entry No.", ItemEntry."Entry No.");
                Application.DeleteAll();
                Application.SetRange("Outbound Item Entry No.");
                EntryRelation.SetRange("Item Entry No.", ItemEntry."Entry No.");
                EntryRelation.DeleteAll();
            until ItemEntry.Next() = 0;
        ValueEntry.SetFilter("Item No.", OwnedItems);
        if ValueEntry.FindSet() then
            repeat
                Relation.SetRange("Value Entry No.", ValueEntry."Entry No.");
                Relation.DeleteAll();
            until ValueEntry.Next() = 0;
        PostingQueue.SetFilter("Item No.", OwnedItems);
        PostingQueue.DeleteAll();
        ValueEntry.DeleteAll();
        ItemEntry.DeleteAll();
        GL.SetRange("Document No.", Prefix);
        GL.SetRange("G/L Account No.", Prefix);
        GL.DeleteAll();
        AdjustmentOrder.SetRange("Order Type", AdjustmentOrder."Order Type"::Production);
        AdjustmentOrder.SetRange("Order No.", Prefix);
        AdjustmentOrder.DeleteAll();
        AvgCost.SetFilter("Item No.", OwnedItems);
        AvgCost.DeleteAll();
        CapacityEntry.SetRange("Order Type", CapacityEntry."Order Type"::Production);
        CapacityEntry.SetRange("Order No.", Prefix);
        CapacityEntry.DeleteAll();
        OrderRouting.SetRange("Prod. Order No.", Prefix);
        OrderRouting.DeleteAll();
        Component.SetRange("Prod. Order No.", Prefix);
        Component.DeleteAll();
        Line.SetRange("Prod. Order No.", Prefix);
        Line.DeleteAll();
        Order.SetRange("No.", Prefix);
        Order.DeleteAll();
        ItemUom.SetFilter("Item No.", OwnedItems);
        ItemUom.DeleteAll();
        Item.SetFilter("No.", OwnedItems);
        Item.DeleteAll();
        Journal.SetRange("Journal Template Name", Prefix);
        Journal.DeleteAll();
        Batch.SetRange("Journal Template Name", Prefix);
        Batch.DeleteAll();
        if JournalTemplate.Get(Prefix) then
            JournalTemplate.Delete();
        GenPosting.SetRange("Gen. Prod. Posting Group", Prefix);
        GenPosting.DeleteAll();
        InvPosting.SetRange("Invt. Posting Group Code", Prefix);
        InvPosting.DeleteAll();
        if GenProd.Get(Prefix) then
            GenProd.Delete();
        if GenBus.Get(Prefix) then
            GenBus.Delete();
        if InvGroup.Get(Prefix) then
            InvGroup.Delete();
        if Location.Get(Prefix) then
            Location.Delete();
        if Uom.Get(Prefix) then
            Uom.Delete();
        BomLine.SetRange("Production BOM No.", Prefix);
        BomLine.DeleteAll();
        if Bom.Get(Prefix) then
            Bom.Delete();
        RoutingLine.SetRange("Routing No.", Prefix);
        RoutingLine.DeleteAll();
        if Routing.Get(Prefix) then
            Routing.Delete();
        CalendarEntry.SetRange("No.", Prefix);
        CalendarEntry.DeleteAll();
        Absence.SetRange("No.", Prefix);
        Absence.DeleteAll();
        if Center.Get(Prefix) then
            Center.Delete();
        if CenterGroup.Get(Prefix) then
            CenterGroup.Delete();
        WorkingDay.SetRange("Shop Calendar Code", Prefix);
        WorkingDay.DeleteAll();
        if Calendar.Get(Prefix) then
            Calendar.Delete();
        if Shift.Get(Prefix) then
            Shift.Delete();
        if CapUom.Get(Prefix) then
            CapUom.Delete();
        if Account.Get(Prefix) then
            Account.Delete();
    end;

    local procedure CleanupRegisters(Prefix: Code[10]; OwnedItems: Text)
    var
        ItemEntry: Record "Item Ledger Entry";
        OtherItemEntry: Record "Item Ledger Entry";
        ItemRegister: Record "Item Register";
        GL: Record "G/L Entry";
        OtherGL: Record "G/L Entry";
        GLRegister: Record "G/L Register";
    begin
        ItemEntry.SetFilter("Item No.", OwnedItems);
        if ItemEntry.FindFirst() then begin
            ItemRegister.SetFilter("From Entry No.", '>=%1', ItemEntry."Entry No.");
            ItemEntry.FindLast();
            ItemRegister.SetFilter("To Entry No.", '<=%1', ItemEntry."Entry No.");
            if ItemRegister.FindSet() then
                repeat
                    OtherItemEntry.SetRange("Entry No.", ItemRegister."From Entry No.", ItemRegister."To Entry No.");
                    OtherItemEntry.SetFilter("Item No.", '<>%1&<>%2', Prefix + '-C', Prefix + '-P');
                    if OtherItemEntry.IsEmpty() then
                        ItemRegister.Delete();
                until ItemRegister.Next() = 0;
        end;
        GL.SetRange("Document No.", Prefix);
        GL.SetRange("G/L Account No.", Prefix);
        if GL.FindFirst() then begin
            GLRegister.SetFilter("From Entry No.", '>=%1', GL."Entry No.");
            GL.FindLast();
            GLRegister.SetFilter("To Entry No.", '<=%1', GL."Entry No.");
            if GLRegister.FindSet() then
                repeat
                    OtherGL.SetRange("Entry No.", GLRegister."From Entry No.", GLRegister."To Entry No.");
                    OtherGL.SetFilter("Document No.", '<>%1', Prefix);
                    if OtherGL.IsEmpty() then
                        GLRegister.Delete();
                until GLRegister.Next() = 0;
        end;
    end;
}
