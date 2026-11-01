namespace Origo.Bifrost.Manufacturing;

using Microsoft.Manufacturing.ProductionBOM;
using Microsoft.Manufacturing.Routing;

/// <summary>
/// Suppresses the commit Business Central performs when a production BOM version or a
/// routing version changes status, and only while <c>BOM Routing Context ori</c> is active.
/// Header status validation does not commit. Outside a Bifrost call the flag is clear, so a
/// page-style validate commits exactly as standard Business Central does.
/// </summary>
codeunit 10077092 "BOM Routing Events ori"
{
    Access = Internal;
    InherentPermissions = X;
    InherentEntitlements = X;

    [EventSubscriber(ObjectType::Table, Database::"Production BOM Version", OnValidateStatusBeforeCommit, '', false, false)]
    local procedure SkipProdBomVersionCommit(var ProductionBOMVersion: Record "Production BOM Version"; var SkipCommit: Boolean)
    var
        Context: Codeunit "BOM Routing Context ori";
    begin
        if Context.IsActive() then
            SkipCommit := true;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Routing Version", OnValidateStatusBeforeCommit, '', false, false)]
    local procedure SkipRoutingVersionCommit(var RoutingVersion: Record "Routing Version"; var SkipCommit: Boolean)
    var
        Context: Codeunit "BOM Routing Context ori";
    begin
        if Context.IsActive() then
            SkipCommit := true;
    end;
}
