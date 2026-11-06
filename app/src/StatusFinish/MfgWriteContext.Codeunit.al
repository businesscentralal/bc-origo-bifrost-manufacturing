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
    end;
}
