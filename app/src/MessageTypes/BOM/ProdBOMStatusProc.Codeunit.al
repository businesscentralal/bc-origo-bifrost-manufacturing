namespace Origo.Bifrost.Manufacturing;

using Microsoft.Manufacturing.ProductionBOM;

/// <summary>
/// Executes the validation of a Production BOM status change.
/// Must be run via Codeunit.Run to capture Business Central check errors.
/// </summary>
codeunit 10077088 "Prod BOM Status Proc ori"
{
    Access = Internal;
    TableNo = "Production BOM Header";

    var
        StatusToSet: Enum "BOM Status";
        VersionCodeToSet: Code[20];
        IsVersion: Boolean;

    trigger OnRun()
    var
        ProductionBOMVersion: Record "Production BOM Version";
    begin
        if IsVersion then begin
            ProductionBOMVersion.Get(Rec."No.", VersionCodeToSet);
            ProductionBOMVersion.Validate(Status, StatusToSet);
            ProductionBOMVersion.Modify(true);
        end else begin
            Rec.Validate(Status, StatusToSet);
            Rec.Modify(true);
        end;
    end;

    /// <summary>
    /// Sets the parameters for the status change.
    /// </summary>
    /// <param name="NewStatusToSet">The status to set.</param>
    /// <param name="NewVersionCodeToSet">The version code (if setting a version).</param>
    /// <param name="NewIsVersion">True if changing a version status.</param>
    internal procedure SetParameters(NewStatusToSet: Enum "BOM Status"; NewVersionCodeToSet: Code[20]; NewIsVersion: Boolean)
    begin
        StatusToSet := NewStatusToSet;
        VersionCodeToSet := NewVersionCodeToSet;
        IsVersion := NewIsVersion;
    end;
}
