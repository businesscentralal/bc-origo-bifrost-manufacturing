namespace Origo.Bifrost.Manufacturing;

using Microsoft.Manufacturing.Document;
using Origo.Bifrost;

/// <summary>Counts the one production order an irreversible status change or finish affects.</summary>
codeunit 10077061 "Prod Order Confirm ori" implements "Msg Confirm ori"
{
    Access = Internal;

    /// <summary>
    /// Returns count 1 and a localized summary. Foundation calls this before ExecuteBifrostTask; it reads
    /// without LockTable so that no write transaction is open when the Impl enters its Codeunit.Run
    /// boundary. The count of one order cannot change; the Proc locks the order and checks again.
    /// </summary>
    procedure GetConfirmCount(var Argument: Record "Message Argument ori"; var Count: Integer; var Summary: Text): Boolean
    var
        ProductionOrder: Record "Production Order";
        ProdOrderLine: Record "Prod. Order Line";
        Lookup: Codeunit "Mfg Prod Order Lookup ori";
        FinishCheck: Codeunit "Prod Order Finish Check ori";
        Request: JsonObject;
        Token: JsonToken;
        NewStatus: Enum "Production Order Status";
        StatusSummaryLbl: Label 'production order %1 (%2 to %3)', Comment = '%1 = order number, %2 = current status, %3 = new status, is-IS=framleiðslupöntun %1 (%2 í %3)';
        FinishSummaryLbl: Label 'production order %1 (finish, %2 lines)', Comment = '%1 = order number, %2 = line count, is-IS=framleiðslupöntun %1 (lúka, %2 línur)';
    begin
        if not FinishCheck.FindOrder(Argument, ProductionOrder) then
            exit(false);
        Count := 1;
        if Argument.Type = "Message Type ori"::"Manufacturing.ProductionOrder.Finish" then begin
            ProdOrderLine.SetRange(Status, ProductionOrder.Status);
            ProdOrderLine.SetRange("Prod. Order No.", ProductionOrder."No.");
            Summary := StrSubstNo(FinishSummaryLbl, ProductionOrder."No.", ProdOrderLine.Count());
            exit(true);
        end;
        Request := Argument.GetRequestJson();
        NewStatus := ProductionOrder.Status;
        if Request.Get('newStatus', Token) then
            if Token.IsValue() then
                if not FinishCheck.TryStatus(Token.AsValue().AsText(), NewStatus) then
                    NewStatus := ProductionOrder.Status;
        Summary := StrSubstNo(StatusSummaryLbl, ProductionOrder."No.", Lookup.StatusName(ProductionOrder.Status), Lookup.StatusName(NewStatus));
        exit(true);
    end;
}
