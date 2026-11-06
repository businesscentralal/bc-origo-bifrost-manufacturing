namespace Origo.Bifrost.Manufacturing;

using Microsoft.Manufacturing.Document;

/// <summary>Carries validated parameters from an Impl codeunit to its Codeunit.Run boundary.</summary>
codeunit 10077063 "Mfg Write Context ori"
{
    Access = Internal;
    SingleInstance = true;

    var
        TargetOrder: Record "Production Order";
        TargetStatus: Enum "Production Order Status";
        TargetPostingDate: Date;
        TargetUpdateUnitCost: Boolean;
        TargetFinishWithoutOutput: Boolean;
        FinishAcknowledged: Boolean;

    /// <summary>Stores the validated request.</summary>
    internal procedure SetRequest(ProductionOrder: Record "Production Order"; NewStatus: Enum "Production Order Status"; PostingDate: Date; UpdateUnitCost: Boolean; FinishWithoutOutput: Boolean)
    begin
        TargetOrder := ProductionOrder;
        TargetStatus := NewStatus;
        TargetPostingDate := PostingDate;
        TargetUpdateUnitCost := UpdateUnitCost;
        TargetFinishWithoutOutput := FinishWithoutOutput;
    end;

    /// <summary>Returns the validated request.</summary>
    internal procedure GetRequest(var ProductionOrder: Record "Production Order"; var NewStatus: Enum "Production Order Status"; var PostingDate: Date; var UpdateUnitCost: Boolean; var FinishWithoutOutput: Boolean)
    begin
        ProductionOrder := TargetOrder;
        NewStatus := TargetStatus;
        PostingDate := TargetPostingDate;
        UpdateUnitCost := TargetUpdateUnitCost;
        FinishWithoutOutput := TargetFinishWithoutOutput;
    end;

    /// <summary>Clears the carried request after the call.</summary>
    internal procedure ClearRequest()
    begin
        Clear(TargetOrder);
        Clear(TargetStatus);
        TargetPostingDate := 0D;
        TargetUpdateUnitCost := false;
        TargetFinishWithoutOutput := false;
        FinishAcknowledged := false;
    end;

    /// <summary>Marks that Finish already refused or the caller acknowledged every missing output and consumption warning.</summary>
    internal procedure SetFinishAcknowledged(Acknowledged: Boolean)
    begin
        FinishAcknowledged := Acknowledged;
    end;

    /// <summary>
    /// Business Central would ask "Do you still want to finish the order?" about missing output or consumption,
    /// and answer yes without a GUI. Finish has already answered that question by refusing or by the caller's
    /// acknowledgment, so the warning loop is skipped only while an acknowledged Finish runs. BC's other finish
    /// checks (outstanding purchase orders and picks, consumption without output) still run.
    /// </summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Prod. Order Status Management", OnCheckBeforeFinishProdOrderOnBeforeFindSet, '', false, false)]
    local procedure SkipAnsweredFinishQuestion(var ProdOrderLine: Record "Prod. Order Line"; var ProdOrderRtngLine: Record "Prod. Order Routing Line"; var ShowWarning: Boolean; var IsHandled: Boolean)
    begin
        if not FinishAcknowledged then
            exit;
        ShowWarning := false;
        IsHandled := true;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Prod. Order Status Management", OnCheckMissingOutput, '', false, false)]
    local procedure SkipAnsweredOutputQuestion(var ProductionOrder: Record "Production Order"; var ProdOrderLine: Record "Prod. Order Line"; var ProdOrderRoutingLine: Record "Prod. Order Routing Line"; var ShowWarning: Boolean)
    begin
        if FinishAcknowledged then
            ShowWarning := false;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Prod. Order Status Management", OnCheckMissingConsumption, '', false, false)]
    local procedure SkipAnsweredConsumptionQuestion(var ProductionOrder: Record "Production Order"; var ProdOrderLine: Record "Prod. Order Line"; var ProdOrderRoutingLine: Record "Prod. Order Routing Line"; var ShowWarning: Boolean)
    begin
        if FinishAcknowledged then
            ShowWarning := false;
    end;
}
