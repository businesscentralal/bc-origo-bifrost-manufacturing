namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Finance.GeneralLedger.Ledger;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Posting;
using Microsoft.Inventory.Setup;
using Microsoft.Inventory.Tracking;
using Microsoft.Manufacturing.Capacity;
using Microsoft.Manufacturing.Document;
using Microsoft.Manufacturing.Routing;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Raw, prefix-owned posting fixtures for issue 25; no CRONUS records are selected.</summary>
codeunit 97656 "Mfg Reverse Test Lib ori"
{
    var
        Fixture: Codeunit "Mfg Reopen Fixture ori";
        Data: Codeunit "Mfg Test Data ori";
        Assert: Codeunit "Library Assert";
        OriginalWorkDate: Date;

    /// <summary>Creates quantity ten with routing, fifty components and owned posting setup.</summary>
    procedure Seed(Prefix: Code[10]; Tracked: Boolean; var Order: Record "Production Order")
    var
        Line: Record "Prod. Order Line";
        Component: Record "Prod. Order Component";
        Item: Record Item;
        Tracking: Record "Item Tracking Code";
        Period: Record "Inventory Period";
    begin
        Cleanup(Prefix);
        OriginalWorkDate := WorkDate();
        Period.SetRange(Closed, true);
        if Period.FindLast() then
            if Period."Ending Date" >= WorkDate() then
                WorkDate(Period."Ending Date" + 1);
        Fixture.Seed(Prefix, Order);
        Order.Quantity := 10;
        Order.Modify();
        Line.Get(Order.Status, Order."No.", 10000);
        Line.Quantity := 10;
        Line."Quantity (Base)" := 10;
        Line."Remaining Quantity" := 10;
        Line."Remaining Qty. (Base)" := 10;
        Line.Modify();
        Component.Get(Order.Status, Order."No.", 10000, 10000);
        Component."Expected Quantity" := 50;
        Component."Expected Qty. (Base)" := 50;
        Component."Remaining Quantity" := 50;
        Component."Remaining Qty. (Base)" := 50;
        Component.Modify();
        if Tracked then begin
            Tracking.Code := Prefix;
            Tracking."Lot Specific Tracking" := true;
            Tracking.Insert();
            Item.Get(Prefix + '-C');
            Item.Validate("Item Tracking Code", Prefix);
            Item.Modify(true);
            PostTracked(Prefix, "Item Ledger Entry Type"::"Positive Adjmt.", 100);
            PostTracked(Prefix, "Item Ledger Entry Type"::Consumption, 50);
        end else
            Fixture.Post(Prefix, "Item Ledger Entry Type"::"Positive Adjmt.", 100);
        Commit();
    end;

    /// <summary>Adds a second native routing operation before posting to test intermediate capacity.</summary>
    procedure AddOperation(Order: Record "Production Order")
    var
        Routing: Record "Prod. Order Routing Line";
        NewRouting: Record "Prod. Order Routing Line";
    begin
        Routing.SetRange(Status, Order.Status);
        Routing.SetRange("Prod. Order No.", Order."No.");
        Routing.FindFirst();
        NewRouting := Routing;
        Routing."Next Operation No." := '20';
        Routing.Modify();
        NewRouting."Operation No." := '20';
        NewRouting."Previous Operation No." := '10';
        NewRouting."Next Operation No." := '';
        NewRouting.Insert();
        Commit();
    end;

    /// <summary>Posts ten output and fifty consumption through the public production journal.</summary>
    procedure PostOrder(Order: Record "Production Order")
    begin
        PostOrder(Order, 2);
    end;

    /// <summary>Posts the fixture with an explicit number of journal lines.</summary>
    procedure PostOrder(Order: Record "Production Order"; Count: Integer)
    var
        Payload: JsonObject;
        Response: JsonObject;
        Raw: Text;
    begin
        Payload.Add('systemId', Format(Order.SystemId, 0, 4));
        Payload.Add('consumptionBasis', 'ExpectedOutput');
        Payload.Add('expectedCount', Count);
        Response := Data.Invoke("Message Type ori"::"Manufacturing.ProductionJournal.Post", Payload, 1033, false);
        Response.WriteTo(Raw);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Self-made order posts: ' + Raw);
    end;

    local procedure PostTracked(Prefix: Code[10]; EntryType: Enum "Item Ledger Entry Type"; Quantity: Decimal)
    var
        JournalTemplate: Record "Item Journal Template";
        Batch: Record "Item Journal Batch";
        Journal: Record "Item Journal Line";
        Reserv: Record "Reservation Entry";
        CreateReserv: Codeunit "Create Reserv. Entry";
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
        Journal.Validate("Entry Type", EntryType);
        Journal."Document No." := Prefix;
        Journal.Validate("Item No.", Prefix + '-C');
        Journal.Validate("Location Code", Prefix);
        if EntryType = EntryType::Consumption then begin
            Journal.Validate("Order Type", Journal."Order Type"::Production);
            Journal.Validate("Order No.", Prefix);
            Journal.Validate("Order Line No.", 10000);
            Journal.Validate("Prod. Order Comp. Line No.", 10000);
        end;
        Journal.Validate(Quantity, Quantity);
        Journal.Insert();
        Reserv."Lot No." := Prefix + '-LOT';
        CreateReserv.CreateReservEntryFor(Database::"Item Journal Line", EntryType.AsInteger(), Prefix, Prefix, 0, 10000, 1, Quantity, Quantity, Reserv);
        CreateReserv.CreateEntry(Journal."Item No.", '', Prefix, '', WorkDate(), WorkDate(), 0, Reserv."Reservation Status"::Prospect);
        PostLine.RunWithCheck(Journal);
        Journal.Delete();
    end;

    /// <summary>Builds the selected-entry request.</summary>
    procedure Request(Order: Record "Production Order"; EntryNo: Integer): JsonObject
    var
        Result: JsonObject;
        Entries: JsonArray;
    begin
        Result.Add('prodOrderNo', Order."No.");
        Entries.Add(EntryNo);
        Result.Add('itemLedgerEntryNos', Entries);
        Result.Add('expectedCount', 1);
        exit(Result);
    end;

    /// <summary>Returns an original ledger entry of the requested kind.</summary>
    procedure Original(Order: Record "Production Order"; EntryType: Enum "Item Ledger Entry Type"): Integer
    var
        Entry: Record "Item Ledger Entry";
    begin
        Entry.SetRange("Order Type", Entry."Order Type"::Production);
        Entry.SetRange("Order No.", Order."No.");
        Entry.SetRange("Entry Type", EntryType);
        Entry.FindFirst();
        exit(Entry."Entry No.");
    end;

    /// <summary>Captures counts for every principal posting or production table, excluding Foundation audit logs.</summary>
    procedure Snapshot(): Text
    var
        DataRecord: RecordRef;
        TableNumbers: List of [Integer];
        TableNumber: Integer;
        Result: Text;
    begin
        TableNumbers.Add(Database::"Item Ledger Entry");
        TableNumbers.Add(Database::"Value Entry");
        TableNumbers.Add(Database::"Capacity Ledger Entry");
        TableNumbers.Add(Database::"Item Application Entry");
        TableNumbers.Add(Database::"G/L Entry");
        TableNumbers.Add(Database::"Item Journal Line");
        TableNumbers.Add(Database::"Reservation Entry");
        TableNumbers.Add(Database::"Production Order");
        TableNumbers.Add(Database::"Prod. Order Line");
        TableNumbers.Add(Database::"Prod. Order Component");
        foreach TableNumber in TableNumbers do begin
            DataRecord.Open(TableNumber);
            Result += Format(TableNumber, 0, 9) + ':' + Format(DataRecord.Count(), 0, 9) + '|';
            DataRecord.Close();
        end;
        exit(Result);
    end;

    /// <summary>Restores the session date after a raw fixture used a later open inventory period.</summary>
    procedure RestoreWorkDate()
    begin
        if OriginalWorkDate <> 0D then
            WorkDate(OriginalWorkDate);
        OriginalWorkDate := 0D;
    end;

    /// <summary>Removes owned tracking setup and delegates complete raw fixture cleanup.</summary>
    procedure Cleanup(Prefix: Code[10])
    var
        Tracking: Record "Item Tracking Code";
        LotInfo: Record "Lot No. Information";
    begin
        RestoreWorkDate();
        Fixture.Cleanup(Prefix);
        LotInfo.SetRange("Item No.", Prefix + '-C');
        LotInfo.DeleteAll();
        if Tracking.Get(Prefix) then
            Tracking.Delete();
    end;
}
