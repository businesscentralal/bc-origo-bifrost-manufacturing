namespace Origo.Bifrost.Manufacturing;

using Microsoft.Manufacturing.Document;
using Origo.Bifrost;

/// <summary>
/// Finishes a released production order with the standard Business Central status management inside
/// a Codeunit.Run boundary. The caller has already refused unacknowledged warnings and blockers,
/// so the questions Business Central would ask are answered before this runs.
/// </summary>
codeunit 10077058 "Prod Order Finish Proc ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        ProductionOrder: Record "Production Order";
        NewProductionOrder: Record "Production Order";
        WriteContext: Codeunit "Mfg Write Context ori";
        StatusMgt: Codeunit "Prod. Order Status Management";
        StatusProc: Codeunit "Prod Order Status Proc ori";
        FinishCheck: Codeunit "Prod Order Finish Check ori";
        ConfirmGate: Codeunit "Confirm Gate ori";
        Response: JsonObject;
        Acknowledged: JsonArray;
        Blockers: JsonArray;
        Warnings: JsonArray;
        NewStatus: Enum "Production Order Status";
        PostingDate: Date;
        UpdateUnitCost: Boolean;
        FinishWithoutOutput: Boolean;
        EntriesBefore: Integer;
        ChangedLbl: Label 'Production order %1 changed while it was being finished. Nothing was changed.', Comment = '%1 = order number, is-IS=Framleiðslupöntun %1 breyttist á meðan henni var lokið. Engu var breytt.';
    begin
        WriteContext.GetRequest(ProductionOrder, NewStatus, PostingDate, UpdateUnitCost, FinishWithoutOutput);
        ProductionOrder.LockTable();
        ProductionOrder.Get(ProductionOrder.Status, ProductionOrder."No.");
        if not ConfirmGate.Check(Rec, Rec.Type) then
            exit;
        // Recheck under lock: findings must still be the ones the caller acknowledged.
        FinishCheck.CollectFindings(ProductionOrder, FinishWithoutOutput, Blockers, Warnings);
        if Blockers.Count() > 0 then
            Error(ChangedLbl, ProductionOrder."No.");
        if FinishCheck.HasWarning(Warnings, 'missingOutput') then
            Acknowledged.Add('missingOutput');
        if FinishCheck.HasWarning(Warnings, 'missingConsumption') then
            Acknowledged.Add('missingConsumption');
        EntriesBefore := StatusProc.CountItemEntries(ProductionOrder."No.");
        StatusMgt.SetFinishOrderWithoutOutput(FinishWithoutOutput);
        StatusMgt.ChangeProdOrderStatus(ProductionOrder, NewProductionOrder, NewStatus::Finished, PostingDate, UpdateUnitCost);
        NewProductionOrder.Get(NewProductionOrder.Status, NewProductionOrder."No.");
        Response.Add('status', 'Success');
        Response.Add('no', NewProductionOrder."No.");
        Response.Add('systemId', Format(NewProductionOrder.SystemId, 0, 4));
        Response.Add('finishedDate', Format(NewProductionOrder."Finished Date", 0, 9));
        Response.Add('postingDate', Format(PostingDate, 0, 9));
        Response.Add('updateUnitCost', UpdateUnitCost);
        Response.Add('postedItemEntries', StatusProc.CountItemEntries(NewProductionOrder."No.") - EntriesBefore);
        Response.Add('acknowledgedWarnings', Acknowledged);
        Response.Add('lines', FinishCheck.GetLines(NewProductionOrder, false));
        Rec.SetResponseJson(Response);
        Rec."Content Type" := Rec.GetContentTypeJson();
    end;
}
