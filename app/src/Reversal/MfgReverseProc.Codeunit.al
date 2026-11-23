namespace Origo.Bifrost.Manufacturing;

using Microsoft.Inventory.Ledger;
using Microsoft.Manufacturing.Capacity;
using Microsoft.Manufacturing.Document;
using Microsoft.Manufacturing.Journal;
using Origo.Bifrost;

/// <summary>Posts correcting entries in one transaction; native failures roll the whole selection back.</summary>
codeunit 10077111 "Mfg Reverse Proc ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        Order: Record "Production Order";
        Entry: Record "Item Ledger Entry";
        CapacityEntry: Record "Capacity Ledger Entry";
        Plan: Codeunit "Mfg Reverse Plan ori";
        Context: Codeunit "Mfg Write Context ori";
        Items: List of [Integer];
        Capacity: List of [Integer];
        Response: JsonObject;
    begin
        Context.GetReverseRequest(Order, Items, Capacity);
        Order.LockTable();
        Order.Get(Order.Status, Order."No.");
        Entry.LockTable();
        CapacityEntry.LockTable();
        if not Plan.Prepare(Rec, Order, Items, Capacity) then
            exit;
        if not Plan.Confirm(Rec, Items.Count() + Capacity.Count()) then
            exit;
        ReverseSelected(Order, Items, Capacity, Response);
        Context.ClearRequest();
        Rec.SetResponseJson(Response);
        Rec."Content Type" := Rec.GetContentTypeJson();
    end;

    [CommitBehavior(CommitBehavior::Error)]
    local procedure ReverseSelected(Order: Record "Production Order"; Items: List of [Integer]; Capacity: List of [Integer]; var Response: JsonObject)
    var
        Entry: Record "Item Ledger Entry";
        NewEntry: Record "Item Ledger Entry";
        CapacityEntry: Record "Capacity Ledger Entry";
        NewCapacity: Record "Capacity Ledger Entry";
        Line: Record "Prod. Order Line";
        Component: Record "Prod. Order Component";
        UndoPosting: Codeunit "Undo Prod. Posting Mgmt.";
        Reversed: JsonArray;
        CapacityReversed: JsonArray;
        OutputRemaining: JsonArray;
        ConsumptionRemaining: JsonArray;
        Detail: JsonObject;
        Number: Integer;
        BeforeEntry: Integer;
        BeforeCapacity: Integer;
    begin
        NewCapacity.Reset();
        if NewCapacity.FindLast() then
            BeforeCapacity := NewCapacity."Entry No.";
        foreach Number in Items do begin
            NewEntry.Reset();
            BeforeEntry := 0;
            if NewEntry.FindLast() then
                BeforeEntry := NewEntry."Entry No.";
            Entry.Reset();
            Entry.SetRange("Entry No.", Number);
            // BC 28.5 has no SetHideDialog. API sessions use its non-GUI confirmation path,
            // and the platform handles its success Message without a client dialog. Keep the 28.5 floor.
            UndoPosting.ReverseProdItemLedgerEntry(Entry);
            NewEntry.SetRange("Order Type", NewEntry."Order Type"::Production);
            NewEntry.SetRange("Order No.", Order."No.");
            NewEntry.SetFilter("Entry No.", '>%1', BeforeEntry);
            if NewEntry.FindSet() then
                repeat
                    Clear(Detail);
                    Detail.Add('originalEntryNo', Number);
                    Detail.Add('newEntryNo', NewEntry."Entry No.");
                    Detail.Add('quantity', NewEntry.Quantity);
                    Detail.Add('itemNo', NewEntry."Item No.");
                    Detail.Add('lotNo', NewEntry."Lot No.");
                    Detail.Add('serialNo', NewEntry."Serial No.");
                    Reversed.Add(Detail);
                until NewEntry.Next() = 0;
        end;
        foreach Number in Capacity do begin
            CapacityEntry.Reset();
            CapacityEntry.SetRange("Entry No.", Number);
            UndoPosting.ReverseCapacityLedgerEntry(CapacityEntry);
        end;
        NewCapacity.Reset();
        NewCapacity.SetRange("Order Type", NewCapacity."Order Type"::Production);
        NewCapacity.SetRange("Order No.", Order."No.");
        NewCapacity.SetFilter("Entry No.", '>%1', BeforeCapacity);
        if NewCapacity.FindSet() then
            repeat
                Clear(Detail);
                Detail.Add('originalEntryNo', NewCapacity."Reversed Entry No.");
                Detail.Add('newEntryNo', NewCapacity."Entry No.");
                Detail.Add('quantity', NewCapacity.Quantity);
                Detail.Add('operationNo', NewCapacity."Operation No.");
                CapacityReversed.Add(Detail);
            until NewCapacity.Next() = 0;
        Line.SetRange(Status, Order.Status);
        Line.SetRange("Prod. Order No.", Order."No.");
        if Line.FindSet() then
            repeat
                Clear(Detail);
                Detail.Add('lineNo', Line."Line No.");
                Detail.Add('remainingQuantity', Line."Remaining Quantity");
                OutputRemaining.Add(Detail);
            until Line.Next() = 0;
        Component.SetRange(Status, Order.Status);
        Component.SetRange("Prod. Order No.", Order."No.");
        if Component.FindSet() then
            repeat
                Clear(Detail);
                Detail.Add('orderLineNo', Component."Prod. Order Line No.");
                Detail.Add('componentLineNo', Component."Line No.");
                Detail.Add('itemNo', Component."Item No.");
                Detail.Add('remainingQuantity', Component."Remaining Quantity");
                ConsumptionRemaining.Add(Detail);
            until Component.Next() = 0;
        Response.Add('status', 'Success');
        Response.Add('prodOrderNo', Order."No.");
        Response.Add('reversed', Reversed);
        Response.Add('capacityEntriesReversed', CapacityReversed);
        Response.Add('remainingOutput', OutputRemaining);
        Response.Add('remainingConsumption', ConsumptionRemaining);
    end;
}
