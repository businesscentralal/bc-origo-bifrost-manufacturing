namespace Origo.Bifrost.Manufacturing;

using Microsoft.Manufacturing.Routing;
using Origo.Bifrost;

/// <summary>
/// Applies Manufacturing.Routing.SetStatus inside one transaction.
/// A failed check rolls back with the transaction. The version commit is suppressed
/// by a local manual subscription that is released on success and when the call unwinds.
/// No write is performed inside a TryFunction.
/// </summary>
codeunit 10077090 "Routing Status Proc ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    var
        Contract: Codeunit "Mfg BOMRtg Contract ori";

    trigger OnRun()
    begin
        Apply(Rec);
    end;

    /// <summary>Reads the request and certifies the routing header or one version.</summary>
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
        Header: Record "Routing Header";
        NewStatus: Enum "Routing Status";
        PreviousToken: Text;
    begin
        if not Contract.HasTablePermission(Argument, Contract.RoutingKind(), Header.ReadPermission(), Header.WritePermission()) then
            exit;
        if not Header.Get(DocumentNo) then begin
            Contract.FailRecordNotFound(Argument, Contract.RoutingKind(), DocumentNo);
            exit;
        end;

        PreviousToken := Contract.RoutingStatusToken(Header.Status);
        if PreviousToken = StatusToken then begin
            Contract.WriteSuccess(Argument, Contract.RoutingKind(), DocumentNo, '', PreviousToken, PreviousToken, false, 0, Contract.CountRoutingItems(DocumentNo), false, true);
            exit;
        end;

        NewStatus := Contract.RoutingStatusFromToken(StatusToken);
        SetHeaderStatus(Header, NewStatus);

        Header.Get(DocumentNo);
        Contract.WriteSuccess(Argument, Contract.RoutingKind(), DocumentNo, '', PreviousToken, Contract.RoutingStatusToken(Header.Status), true, 0, Contract.CountRoutingItems(DocumentNo), false, true);
    end;

    local procedure ApplyVersion(var Argument: Record "Message Argument ori"; DocumentNo: Code[20]; VersionCode: Code[20]; StatusToken: Text)
    var
        Header: Record "Routing Header";
        Version: Record "Routing Version";
        NewStatus: Enum "Routing Status";
        PreviousToken: Text;
    begin
        if not Contract.HasTablePermission(Argument, Contract.RoutingKind(), Version.ReadPermission(), Version.WritePermission()) then
            exit;
        if not Header.Get(DocumentNo) then begin
            Contract.FailRecordNotFound(Argument, Contract.RoutingKind(), DocumentNo);
            exit;
        end;
        if not Version.Get(DocumentNo, VersionCode) then begin
            Contract.FailVersionNotFound(Argument, Contract.RoutingKind(), DocumentNo, VersionCode);
            exit;
        end;

        PreviousToken := Contract.RoutingStatusToken(Version.Status);
        if PreviousToken = StatusToken then begin
            Contract.WriteSuccess(Argument, Contract.RoutingKind(), DocumentNo, VersionCode, PreviousToken, PreviousToken, false, 0, 0, false, false);
            exit;
        end;

        NewStatus := Contract.RoutingStatusFromToken(StatusToken);
        SetVersionStatus(Version, NewStatus);

        Version.Get(DocumentNo, VersionCode);
        Contract.WriteSuccess(Argument, Contract.RoutingKind(), DocumentNo, VersionCode, PreviousToken, Contract.RoutingStatusToken(Version.Status), true, 0, 0, false, false);
    end;

    local procedure SetHeaderStatus(var RoutingHeader: Record "Routing Header"; NewStatus: Enum "Routing Status")
    begin
        // Status validation reads fields beyond Status, so this record is not load-field limited.
        RoutingHeader.Validate(Status, NewStatus);
        RoutingHeader.Modify(true);
    end;

    local procedure SetVersionStatus(var RoutingVersion: Record "Routing Version"; NewStatus: Enum "Routing Status")
    begin
        // The version modifies and would commit inside validation. SkipCommit is set while the context is active.
        RoutingVersion.Validate(Status, NewStatus);
    end;
}
