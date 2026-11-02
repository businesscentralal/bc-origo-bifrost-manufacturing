namespace Origo.Bifrost.Manufacturing;

using Microsoft.Manufacturing.ProductionBOM;
using Origo.Bifrost;

/// <summary>
/// Applies Manufacturing.ProductionBOM.SetStatus inside one transaction.
/// A failed check rolls back with the transaction. The version commit is suppressed
/// by a local manual subscription that is released on success and when the call unwinds.
/// No write is performed inside a TryFunction.
/// </summary>
codeunit 10077088 "Prod BOM Status Proc ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    var
        Contract: Codeunit "Mfg BOMRtg Contract ori";

    trigger OnRun()
    begin
        Apply(Rec);
    end;

    /// <summary>Reads the request and certifies the production BOM header or one version.</summary>
    /// <param name="Argument">The message argument.</param>
    internal procedure Apply(var Argument: Record "Message Argument ori")
    var
        Events: Codeunit "BOM Routing Events ori";
        DocumentNo: Code[20];
        VersionCode: Code[20];
        StatusToken: Text;
    begin
        if not Contract.ReadSetStatusRequest(Argument, DocumentNo, VersionCode, StatusToken) then begin
            Contract.RaiseCollected(Argument);
            exit;
        end;
        BindSubscription(Events);
        if VersionCode = '' then
            ApplyHeader(Argument, DocumentNo, StatusToken)
        else
            ApplyVersion(Argument, DocumentNo, VersionCode, StatusToken);
    end;

    local procedure ApplyHeader(var Argument: Record "Message Argument ori"; DocumentNo: Code[20]; StatusToken: Text)
    var
        Header: Record "Production BOM Header";
        NewStatus: Enum "BOM Status";
        PreviousToken: Text;
    begin
        if not Contract.HasTablePermission(Argument, Contract.ProductionBomKind(), Header.ReadPermission(), Header.WritePermission()) then
            exit;
        if not Header.Get(DocumentNo) then begin
            Contract.FailRecordNotFound(Argument, Contract.ProductionBomKind(), DocumentNo);
            exit;
        end;

        PreviousToken := Contract.BomStatusToken(Header.Status);
        if PreviousToken = StatusToken then begin
            Contract.WriteSuccess(Argument, Contract.ProductionBomKind(), DocumentNo, '', PreviousToken, PreviousToken, false, Header."Low-Level Code", Contract.CountBomItems(DocumentNo), true, true);
            exit;
        end;

        NewStatus := Contract.BomStatusFromToken(StatusToken);
        SetHeaderStatus(Header, NewStatus);

        Header.Get(DocumentNo);
        Contract.WriteSuccess(Argument, Contract.ProductionBomKind(), DocumentNo, '', PreviousToken, Contract.BomStatusToken(Header.Status), true, Header."Low-Level Code", Contract.CountBomItems(DocumentNo), true, true);
    end;

    local procedure ApplyVersion(var Argument: Record "Message Argument ori"; DocumentNo: Code[20]; VersionCode: Code[20]; StatusToken: Text)
    var
        Header: Record "Production BOM Header";
        Version: Record "Production BOM Version";
        NewStatus: Enum "BOM Status";
        PreviousToken: Text;
    begin
        if not Contract.HasTablePermission(Argument, Contract.ProductionBomKind(), Version.ReadPermission(), Version.WritePermission()) then
            exit;
        if not Header.Get(DocumentNo) then begin
            Contract.FailRecordNotFound(Argument, Contract.ProductionBomKind(), DocumentNo);
            exit;
        end;
        if not Version.Get(DocumentNo, VersionCode) then begin
            Contract.FailVersionNotFound(Argument, Contract.ProductionBomKind(), DocumentNo, VersionCode);
            exit;
        end;

        PreviousToken := Contract.BomStatusToken(Version.Status);
        if PreviousToken = StatusToken then begin
            Contract.WriteSuccess(Argument, Contract.ProductionBomKind(), DocumentNo, VersionCode, PreviousToken, PreviousToken, false, 0, 0, false, false);
            exit;
        end;

        NewStatus := Contract.BomStatusFromToken(StatusToken);
        SetVersionStatus(Version, NewStatus);

        Version.Get(DocumentNo, VersionCode);
        Contract.WriteSuccess(Argument, Contract.ProductionBomKind(), DocumentNo, VersionCode, PreviousToken, Contract.BomStatusToken(Version.Status), true, 0, 0, false, false);
    end;

    local procedure SetHeaderStatus(var ProductionBOMHeader: Record "Production BOM Header"; NewStatus: Enum "BOM Status")
    begin
        // Status validation reads fields beyond Status, so this record is not load-field limited.
        ProductionBOMHeader.Validate(Status, NewStatus);
        ProductionBOMHeader.Modify(true);
    end;

    local procedure SetVersionStatus(var ProductionBOMVersion: Record "Production BOM Version"; NewStatus: Enum "BOM Status")
    begin
        // The version modifies and would commit inside validation. SkipCommit is set while the context is active.
        ProductionBOMVersion.Validate(Status, NewStatus);
    end;
}
