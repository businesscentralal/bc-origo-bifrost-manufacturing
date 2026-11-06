namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Inventory.Item;
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
        StatusLib.PrepareOrder(Item, Order, Order.Status::"Firm Planned");
        Commit();
        Response := StatusLib.ChangeStatus(Order, 'Released', 1, 1033);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Fixture release succeeds.');
        StatusLib.ReadBack(Response, Order);
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
