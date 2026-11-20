namespace Origo.Bifrost.Manufacturing;

using Microsoft.Manufacturing.Document;
using Origo.Bifrost;

/// <summary>Moves a finished order through the standard no-UI routine inside a rollback boundary.</summary>
codeunit 10077069 "Prod Order Reopen Proc ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        ProductionOrder: Record "Production Order";
        ReleasedOrder: Record "Production Order";
        Line: Record "Prod. Order Line";
        WriteContext: Codeunit "Mfg Write Context ori";
        ReopenImpl: Codeunit "Prod Order Reopen Impl ori";
        StatusMgt: Codeunit "Prod. Order Status Management";
        ConfirmGate: Codeunit "Confirm Gate ori";
        NewStatus: Enum "Production Order Status";
        PostingDate: Date;
        UpdateUnitCost: Boolean;
        FinishWithoutOutput: Boolean;
        Response: JsonObject;
        NextSteps: JsonArray;
    begin
        WriteContext.GetRequest(ProductionOrder, NewStatus, PostingDate, UpdateUnitCost, FinishWithoutOutput);
        ProductionOrder.LockTable();
        ProductionOrder.Get(ProductionOrder.Status, ProductionOrder."No.");
        Line.LockTable();
        if not ReopenImpl.CheckPreconditions(Rec, ProductionOrder) then
            exit;
        if not ConfirmGate.Check(Rec, Rec.Type) then
            exit;
        StatusMgt.ProcessProdOrderForReopen(ProductionOrder);
        ReleasedOrder.Get(ReleasedOrder.Status::Released, ProductionOrder."No.");
        Line.SetRange(Status, ReleasedOrder.Status);
        Line.SetRange("Prod. Order No.", ReleasedOrder."No.");
        Response.Add('status', 'Success');
        Response.Add('productionOrderStatus', 'Released');
        Response.Add('no', ReleasedOrder."No.");
        Response.Add('systemId', Format(ReleasedOrder.SystemId, 0, 4));
        Response.Add('reopened', ReleasedOrder.Reopened);
        Response.Add('lineCount', Line.Count());
        NextSteps.Add('Manufacturing.ProductionJournal.Get');
        NextSteps.Add('Manufacturing.ProductionJournal.Post');
        NextSteps.Add('Manufacturing.ProductionOrder.CheckFinish');
        NextSteps.Add('Manufacturing.ProductionOrder.Finish');
        Response.Add('nextSteps', NextSteps);
        Rec.SetResponseJson(Response);
        Rec."Content Type" := Rec.GetContentTypeJson();
        // The no-UI reopen routine has no COMMIT of its own. Match the lifecycle commit contract explicitly.
        Commit();
    end;
}
