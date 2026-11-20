namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Finance.GeneralLedger.Account;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Foundation.UOM;
using Microsoft.Inventory.Costing;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Ledger;
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
        Component."Flushing Method" := Component."Flushing Method"::Manual;
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
}
