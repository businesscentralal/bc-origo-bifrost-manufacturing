namespace Origo.Bifrost.Manufacturing;

using Microsoft.Manufacturing.Routing;

/// <summary>
/// Executes the validation of a Routing status change.
/// Must be run via Codeunit.Run to capture Business Central check errors.
/// </summary>
codeunit 10077090 "Routing Status Proc ori"
{
    Access = Internal;
    TableNo = "Routing Header";

    var
        StatusToSet: Enum "Routing Status";
        VersionCodeToSet: Code[20];
        IsVersion: Boolean;

    trigger OnRun()
    var
        RoutingVersion: Record "Routing Version";
    begin
        if IsVersion then begin
            RoutingVersion.Get(Rec."No.", VersionCodeToSet);
            RoutingVersion.Validate(Status, StatusToSet);
            RoutingVersion.Modify(true);
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
    internal procedure SetParameters(NewStatusToSet: Enum "Routing Status"; NewVersionCodeToSet: Code[20]; NewIsVersion: Boolean)
    begin
        StatusToSet := NewStatusToSet;
        VersionCodeToSet := NewVersionCodeToSet;
        IsVersion := NewIsVersion;
    end;
}
