namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Finance.GeneralLedger.Account;
using Microsoft.Finance.GeneralLedger.Ledger;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Foundation.AuditCodes;
using Microsoft.Inventory.Costing;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Planning;
using Microsoft.Manufacturing.Document;
using System.TestLibraries.Utilities;

/// <summary>Creates and removes individually named zero-cost production posting fixtures, including their own posting setup.</summary>
codeunit 97616 "Mfg Posting Fixture ori"
{
    Access = Internal;
    Permissions = tabledata "Item Ledger Entry" = D,
                  tabledata "Value Entry" = D,
                  tabledata "Item Application Entry" = D,
                  tabledata "Item Register" = D,
                  tabledata "G/L Entry" = D,
                  tabledata "Inventory Adjmt. Entry (Order)" = D;

    var
        Assert: Codeunit "Library Assert";
        Lib: Codeunit "BOM Routing Test Lib ori";

    /// <summary>Seeds a fresh Released production order and its own item, accounting groups and journal batch.</summary>
    procedure Seed(FixtureNo: Code[20])
    var
        Item: Record Item;
        Account: Record "G/L Account";
        GenGroup: Record "Gen. Product Posting Group";
        InvtGroup: Record "Inventory Posting Group";
        GenSetup: Record "General Posting Setup";
        InvtSetup: Record "Inventory Posting Setup";
        Order: Record "Production Order";
        JournalTemplate: Record "Item Journal Template";
        Batch: Record "Item Journal Batch";
        SourceCode: Record "Source Code";
        JournalName: Code[10];
    begin
        Assert.IsTrue(CopyStr(FixtureNo, 1, 4) = 'XM11', 'Only owned fixture names are accepted.');
        Assert.IsFalse(Item.Get(FixtureNo), 'Existing fixture keys must not be overwritten.');
        JournalName := CopyStr(FixtureNo, 1, MaxStrLen(JournalName));
        Account."No." := FixtureNo;
        Account.Name := FixtureNo;
        Account."Account Type" := Account."Account Type"::Posting;
        Account."Direct Posting" := true;
        Account.Insert(false);
        GenGroup.Code := FixtureNo;
        GenGroup.Insert(false);
        InvtGroup.Code := FixtureNo;
        InvtGroup.Insert(false);
        GenSetup."Gen. Prod. Posting Group" := FixtureNo;
        GenSetup."Inventory Adjmt. Account" := FixtureNo;
        GenSetup."Direct Cost Applied Account" := FixtureNo;
        GenSetup."Overhead Applied Account" := FixtureNo;
        GenSetup."Purchase Variance Account" := FixtureNo;
        GenSetup.Insert(false);
        InvtSetup."Invt. Posting Group Code" := FixtureNo;
        InvtSetup."Inventory Account" := FixtureNo;
        InvtSetup."Inventory Account (Interim)" := FixtureNo;
        InvtSetup."WIP Account" := FixtureNo;
        InvtSetup."Material Variance Account" := FixtureNo;
        InvtSetup.Insert(false);
        Lib.CreateItem(FixtureNo, '', '');
        Item.Get(FixtureNo);
        Item."Gen. Prod. Posting Group" := FixtureNo;
        Item."Inventory Posting Group" := FixtureNo;
        Item.Modify(false);
        Order.Status := Order.Status::Released;
        Order."No." := FixtureNo;
        Order.Insert(true);
        Order.SetHideValidationDialog(true);
        Order.Validate("Source No.", FixtureNo);
        Order.Validate(Quantity, 2);
        Order.Validate("Due Date", WorkDate());
        Order.Modify(true);
        SourceCode.Code := JournalName;
        SourceCode.Insert(false);
        JournalTemplate.Name := JournalName;
        JournalTemplate.Type := JournalTemplate.Type::Output;
        JournalTemplate."Source Code" := JournalName;
        JournalTemplate.Insert(false);
        Batch."Journal Template Name" := JournalName;
        Batch.Name := JournalName;
        Batch.Insert(false);
        Commit();
    end;

    /// <summary>Creates a positive output journal line after the public refresh message created the production line.</summary>
    procedure CreateOutputLine(FixtureNo: Code[20])
    var
        ProdLine: Record "Prod. Order Line";
        Line: Record "Item Journal Line";
        JournalName: Code[10];
    begin
        JournalName := CopyStr(FixtureNo, 1, MaxStrLen(JournalName));
        ProdLine.SetRange(Status, ProdLine.Status::Released);
        ProdLine.SetRange("Prod. Order No.", FixtureNo);
        ProdLine.FindFirst();
        Line."Journal Template Name" := JournalName;
        Line."Journal Batch Name" := JournalName;
        Line."Line No." := 10000;
        Line.Validate("Posting Date", WorkDate());
        Line."Document No." := FixtureNo;
        Line."Source Code" := JournalName;
        Line.Validate("Entry Type", Line."Entry Type"::Output);
        Line.Validate("Order Type", Line."Order Type"::Production);
        Line.Validate("Order No.", FixtureNo);
        Line.Validate("Order Line No.", ProdLine."Line No.");
        Line.Validate("Item No.", FixtureNo);
        Line.Validate("Output Quantity", 2);
        Line.Insert(true);
        Commit();
    end;

    /// <summary>Removes only records identified by the owned fixture key, including its generated ledger entries.</summary>
    procedure Cleanup(FixtureNo: Code[20])
    var
        Item: Record Item;
        ItemUom: Record "Item Unit of Measure";
        Account: Record "G/L Account";
        GenGroup: Record "Gen. Product Posting Group";
        InvtGroup: Record "Inventory Posting Group";
        GenSetup: Record "General Posting Setup";
        InvtSetup: Record "Inventory Posting Setup";
        Order: Record "Production Order";
        ProdLine: Record "Prod. Order Line";
        Component: Record "Prod. Order Component";
        RoutingLine: Record "Prod. Order Routing Line";
        JournalTemplate: Record "Item Journal Template";
        Batch: Record "Item Journal Batch";
        Line: Record "Item Journal Line";
        Entry: Record "Item Ledger Entry";
        ApplicationEntry: Record "Item Application Entry";
        ValueEntry: Record "Value Entry";
        Register: Record "Item Register";
        GLEntry: Record "G/L Entry";
        Adjustment: Record "Inventory Adjmt. Entry (Order)";
        Planning: Record "Planning Assignment";
        SourceCode: Record "Source Code";
        JournalName: Code[10];
    begin
        Assert.IsTrue(CopyStr(FixtureNo, 1, 4) = 'XM11', 'Only owned fixture names are accepted.');
        JournalName := CopyStr(FixtureNo, 1, MaxStrLen(JournalName));
        Entry.SetRange("Item No.", FixtureNo);
        if Entry.FindSet() then
            repeat
                ApplicationEntry.SetRange("Inbound Item Entry No.", Entry."Entry No.");
                ApplicationEntry.DeleteAll(false);
                ApplicationEntry.SetRange("Inbound Item Entry No.");
                ApplicationEntry.SetRange("Outbound Item Entry No.", Entry."Entry No.");
                ApplicationEntry.DeleteAll(false);
                ApplicationEntry.SetRange("Outbound Item Entry No.");
            until Entry.Next() = 0;
        ValueEntry.SetRange("Item No.", FixtureNo);
        ValueEntry.DeleteAll(false);
        Entry.DeleteAll(false);
        Register.SetRange("Source Code", JournalName);
        Register.DeleteAll(false);
        GLEntry.SetRange("G/L Account No.", FixtureNo);
        GLEntry.DeleteAll(false);
        Adjustment.SetRange("Order Type", Adjustment."Order Type"::Production);
        Adjustment.SetRange("Order No.", FixtureNo);
        Adjustment.DeleteAll(false);
        Line.SetRange("Journal Template Name", JournalName);
        Line.DeleteAll(false);
        Batch.SetRange("Journal Template Name", JournalName);
        Batch.DeleteAll(false);
        if JournalTemplate.Get(JournalName) then
            JournalTemplate.Delete(false);
        Component.SetRange("Prod. Order No.", FixtureNo);
        Component.DeleteAll(false);
        RoutingLine.SetRange("Prod. Order No.", FixtureNo);
        RoutingLine.DeleteAll(false);
        ProdLine.SetRange("Prod. Order No.", FixtureNo);
        ProdLine.DeleteAll(false);
        Order.SetRange("No.", FixtureNo);
        Order.DeleteAll(false);
        ItemUom.SetRange("Item No.", FixtureNo);
        ItemUom.DeleteAll(false);
        Planning.SetRange("Item No.", FixtureNo);
        Planning.DeleteAll(false);
        if Item.Get(FixtureNo) then
            Item.Delete(false);
        if GenSetup.Get('', FixtureNo) then
            GenSetup.Delete(false);
        if InvtSetup.Get('', FixtureNo) then
            InvtSetup.Delete(false);
        if GenGroup.Get(FixtureNo) then
            GenGroup.Delete(false);
        if InvtGroup.Get(FixtureNo) then
            InvtGroup.Delete(false);
        if Account.Get(FixtureNo) then
            Account.Delete(false);
        if SourceCode.Get(JournalName) then
            SourceCode.Delete(false);
        Assert.IsTrue(Entry.IsEmpty() and ValueEntry.IsEmpty() and Line.IsEmpty() and ProdLine.IsEmpty() and Order.IsEmpty() and GLEntry.IsEmpty(), 'Owned production and ledger fixtures removed.');
        Commit();
    end;
}
