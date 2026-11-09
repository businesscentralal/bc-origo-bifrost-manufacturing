namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Finance.GeneralLedger.Account;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Setup;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Manufacturing.Document;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Shared helpers for the production journal tests.</summary>
codeunit 97647 "Prod Jnl Test Lib ori"
{
    var
        Data: Codeunit "Mfg Test Data ori";
        StatusLib: Codeunit "Mfg Status Test Lib ori";
        Assert: Codeunit "Library Assert";

    /// <summary>Creates an owned item with BOM and routing and a Released order of quantity 5.</summary>
    procedure PrepareReleased(var Item: Record Item; var Order: Record "Production Order")
    var
        Response: JsonObject;
    begin
        FillPostingAccounts();
        StatusLib.PrepareOrder(Item, Order, Order.Status::"Firm Planned");
        Commit();
        Response := StatusLib.ChangeStatus(Order, 'Released', 1, 1033);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Fixture release succeeds.');
        StatusLib.ReadBack(Response, Order);
        StockComponents(Order);
    end;

    /// <summary>Posts owned positive adjustments so that consumption of the order's components has inventory.</summary>
    procedure StockComponents(Order: Record "Production Order")
    var
        Component: Record "Prod. Order Component";
        ComponentItem: Record Item;
        Inventory: Codeunit "Library - Inventory";
    begin
        Component.SetRange(Status, Order.Status);
        Component.SetRange("Prod. Order No.", Order."No.");
        if Component.FindSet() then
            repeat
                ComponentItem.Get(Component."Item No.");
                Inventory.PostPositiveAdjustment(ComponentItem, '', '', '', 100, WorkDate(), 1);
            until Component.Next() = 0;
        Commit();
    end;

    /// <summary>
    /// Gives every inventory posting setup line the production accounts that posting output needs, using an
    /// existing posting G/L account; only empty accounts are filled.
    /// </summary>
    procedure FillPostingAccounts()
    var
        PostingSetup: Record "Inventory Posting Setup";
        Account: Record "G/L Account";
    begin
        Account.SetRange("Account Type", Account."Account Type"::Posting);
        Account.SetRange("Direct Posting", true);
        Account.SetRange(Blocked, false);
        Account.FindFirst();
        if PostingSetup.FindSet(true) then
            repeat
                if PostingSetup."WIP Account" = '' then
                    PostingSetup."WIP Account" := Account."No.";
                if PostingSetup."Material Variance Account" = '' then
                    PostingSetup."Material Variance Account" := Account."No.";
                if PostingSetup."Capacity Variance Account" = '' then
                    PostingSetup."Capacity Variance Account" := Account."No.";
                if PostingSetup."Mfg. Overhead Variance Account" = '' then
                    PostingSetup."Mfg. Overhead Variance Account" := Account."No.";
                if PostingSetup."Cap. Overhead Variance Account" = '' then
                    PostingSetup."Cap. Overhead Variance Account" := Account."No.";
                if PostingSetup."Subcontracted Variance Account" = '' then
                    PostingSetup."Subcontracted Variance Account" := Account."No.";
                if PostingSetup."Inventory Account" = '' then
                    PostingSetup."Inventory Account" := Account."No.";
                PostingSetup.Modify();
            until PostingSetup.Next() = 0;
        Commit();
    end;

    /// <summary>Calls one of the journal types with an identity request plus optional extra keys.</summary>
    procedure Call(MessageType: Enum "Message Type ori"; Order: Record "Production Order"; Extra: JsonObject; LanguageId: Integer): JsonObject
    var
        Request: JsonObject;
        KeyName: Text;
        Token: JsonToken;
    begin
        Request := StatusLib.IdRequest(Order);
        foreach KeyName in Extra.Keys() do begin
            Extra.Get(KeyName, Token);
            Request.Add(KeyName, Token);
        end;
        exit(Data.Invoke(MessageType, Request, LanguageId, false));
    end;

    /// <summary>Counts the journal lines that exist for the order in any batch.</summary>
    procedure JournalLines(OrderNo: Code[20]): Integer
    var
        ItemJnlLine: Record "Item Journal Line";
    begin
        ItemJnlLine.SetRange("Order Type", ItemJnlLine."Order Type"::Production);
        ItemJnlLine.SetRange("Order No.", OrderNo);
        exit(ItemJnlLine.Count());
    end;

    /// <summary>Counts item ledger entries of the order by entry type.</summary>
    procedure Entries(OrderNo: Code[20]; EntryType: Enum "Item Ledger Entry Type"): Integer
    var
        LedgerEntry: Record "Item Ledger Entry";
    begin
        LedgerEntry.SetRange("Order Type", LedgerEntry."Order Type"::Production);
        LedgerEntry.SetRange("Order No.", OrderNo);
        LedgerEntry.SetRange("Entry Type", EntryType);
        exit(LedgerEntry.Count());
    end;

    /// <summary>Deletes the posted and open fixture data of the item's orders and the item ledger entries are left to the container cleanup.</summary>
    procedure Cleanup(ItemNo: Code[20])
    begin
        StatusLib.Cleanup(ItemNo);
    end;
}
