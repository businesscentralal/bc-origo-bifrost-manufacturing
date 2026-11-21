namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Finance.GeneralLedger.Account;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Foundation.UOM;
using Microsoft.Inventory.Costing;
using Microsoft.Inventory.Item;
using Microsoft.Finance.GeneralLedger.Ledger;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Tracking;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Posting;
using Microsoft.Inventory.Setup;
using Microsoft.Manufacturing.Capacity;
using Microsoft.Manufacturing.Document;
using Microsoft.Manufacturing.Setup;

/// <summary>Creates all read fixtures from raw records; no CRONUS business data or library lookups.</summary>
codeunit 97630 "Mfg Read Fixture ori"
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
        MfgSetup: Record "Manufacturing Setup";
        Line: Record "Prod. Order Line";
        Component: Record "Prod. Order Component";
    begin
        Uom.Code := Prefix;
        Uom.Description := Prefix;
        Uom.Insert();
        CapUom.Code := Prefix;
        CapUom.Type := CapUom.Type::Hours;
        CapUom.Insert();
        MfgSetup.Get();
        MfgSetup."Show Capacity In" := Prefix;
        MfgSetup.Modify();
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
        Component."Flushing Method" := Component."Flushing Method"::"Pick + Manual";
        Component."Unit Cost" := 2;
        Component."Cost Amount" := 10;
        Component.Insert();
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
        Item."Flushing Method" := Item."Flushing Method"::"Pick + Manual";
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
        OwnedItems: Text;
    begin
        if not (Prefix in ['X26MCPW', 'X26MCPI', 'X26MCPT']) then
            Error('Only issue 26 MCP fixture prefixes can be cleaned.');
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
