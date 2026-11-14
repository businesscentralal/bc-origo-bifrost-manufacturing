namespace Origo.Bifrost.Manufacturing;

using Microsoft.Inventory.Ledger;
using Microsoft.Manufacturing.Document;
using Origo.Bifrost;

/// <summary>
/// Runs the standard Business Central status change inside a Codeunit.Run boundary and builds the
/// response. Business Central commits at the end of ChangeProdOrderStatus; an error before that
/// rolls back the whole change.
/// </summary>
codeunit 10077056 "Prod Order Status Proc ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        ProductionOrder: Record "Production Order";
        NewProductionOrder: Record "Production Order";
        ProdOrderLine: Record "Prod. Order Line";
        WriteContext: Codeunit "Mfg Write Context ori";
        StatusMgt: Codeunit "Prod. Order Status Management";
        Lookup: Codeunit "Mfg Prod Order Lookup ori";
        ConfirmGate: Codeunit "Confirm Gate ori";
        Response: JsonObject;
        NewStatus: Enum "Production Order Status";
        FromStatus: Enum "Production Order Status";
        PostingDate: Date;
        UpdateUnitCost: Boolean;
        FinishWithoutOutput: Boolean;
        EntriesBefore: Integer;
        OldNo: Code[20];
    begin
        WriteContext.GetRequest(ProductionOrder, NewStatus, PostingDate, UpdateUnitCost, FinishWithoutOutput);
        ProductionOrder.LockTable();
        ProductionOrder.Get(ProductionOrder.Status, ProductionOrder."No.");
        if not ConfirmGate.Check(Rec, Rec.Type) then
            exit;
        FromStatus := ProductionOrder.Status;
        OldNo := ProductionOrder."No.";
        EntriesBefore := CountItemEntries(OldNo);
        StatusMgt.ChangeProdOrderStatus(ProductionOrder, NewProductionOrder, NewStatus, PostingDate, UpdateUnitCost);
        ProdOrderLine.SetRange(Status, NewProductionOrder.Status);
        ProdOrderLine.SetRange("Prod. Order No.", NewProductionOrder."No.");
        Response.Add('status', 'Success');
        Response.Add('fromStatus', Lookup.StatusName(FromStatus));
        Response.Add('toStatus', Lookup.StatusName(NewProductionOrder.Status));
        Response.Add('oldNo', OldNo);
        Response.Add('no', NewProductionOrder."No.");
        Response.Add('systemId', Format(NewProductionOrder.SystemId, 0, 4));
        Response.Add('numberChanged', NewProductionOrder."No." <> OldNo);
        Response.Add('postingDate', Format(PostingDate, 0, 9));
        Response.Add('postedItemEntries', CountItemEntries(OldNo, NewProductionOrder."No.") - EntriesBefore);
        Response.Add('lines', ProdOrderLine.Count());
        Rec.SetResponseJson(Response);
        Rec."Content Type" := Rec.GetContentTypeJson();
    end;

    /// <summary>Counts Item Ledger Entries posted for a production order number.</summary>
    internal procedure CountItemEntries(OrderNo: Code[20]): Integer
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
    begin
        ItemLedgerEntry.SetRange("Order Type", ItemLedgerEntry."Order Type"::Production);
        ItemLedgerEntry.SetRange("Order No.", OrderNo);
        exit(ItemLedgerEntry.Count());
    end;

    local procedure CountItemEntries(OldNo: Code[20]; NewNo: Code[20]): Integer
    begin
        if OldNo = NewNo then
            exit(CountItemEntries(OldNo));
        exit(CountItemEntries(OldNo) + CountItemEntries(NewNo));
    end;
}
