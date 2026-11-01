namespace Origo.Bifrost.Manufacturing;

using Microsoft.Manufacturing.ProductionBOM;
using Microsoft.Manufacturing.Routing;

/// <summary>
/// Suppresses standard Business Central commits when setting Production BOM and Routing status.
/// </summary>
codeunit 10077092 "BOM Routing Events ori"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Table, Database::"Production BOM Version", 'OnValidateStatusBeforeCommit', '', false, false)]
    local procedure SuppressProductionBOMVersionCommit(var ProductionBOMVersion: Record "Production BOM Version"; var SkipCommit: Boolean)
    var
        BOMRoutingContext: Codeunit "BOM Routing Context ori";
    begin
        if BOMRoutingContext.IsInsideBifrostCall() then
            SkipCommit := true;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Routing Version", 'OnValidateStatusBeforeCommit', '', false, false)]
    local procedure SuppressRoutingVersionCommit(var RoutingVersion: Record "Routing Version"; var SkipCommit: Boolean)
    var
        BOMRoutingContext: Codeunit "BOM Routing Context ori";
    begin
        if BOMRoutingContext.IsInsideBifrostCall() then
            SkipCommit := true;
    end;
}
