namespace Origo.Bifrost.Manufacturing;

using Microsoft.Manufacturing.Routing;
using Origo.Bifrost;

/// <summary>
/// Applies Manufacturing.Routing.CopyVersion inside one transaction.
/// A new empty version is created first. Business Central deletes the target lines before it copies,
/// and an empty version has nothing to delete. An existing target is refused before that delete.
/// </summary>
codeunit 10077097 "Routing Copy Proc ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    var
        Contract: Codeunit "Mfg Copy Contract ori";

    trigger OnRun()
    begin
        Apply(Rec);
    end;

    /// <summary>Reads the request and copies the routing into a new version.</summary>
    /// <param name="Argument">The message argument.</param>
    internal procedure Apply(var Argument: Record "Message Argument ori")
    var
        Header: Record "Routing Header";
        Version: Record "Routing Version";
        RoutingCopy: Codeunit "Routing Line-Copy Lines";
        DocumentNo: Code[20];
        SourceVersionCode: Code[20];
        TargetVersionCode: Code[20];
        SystemId: Guid;
        StartingDate: Date;
        Description: Text;
        SourceDescription: Text[100];
        HasSystemId: Boolean;
        HasTarget: Boolean;
        HasDescription: Boolean;
    begin
        if not Contract.ReadCopyRequest(Argument, DocumentNo, SystemId, HasSystemId, SourceVersionCode, TargetVersionCode, HasTarget, StartingDate, Description, HasDescription) then begin
            Contract.RaiseCollected(Argument);
            exit;
        end;
        if not CanChange(Argument) then
            exit;
        if not FindHeader(Argument, DocumentNo, SystemId, HasSystemId, Header) then
            exit;
        if HasTarget and (TargetVersionCode = SourceVersionCode) then begin
            Contract.FailSameVersion(Argument, TargetVersionCode);
            exit;
        end;
        if not TrySourceDescription(Argument, Header, SourceVersionCode, SourceDescription) then
            exit;
        if HasTarget then begin
            if TargetExists(Header."No.", TargetVersionCode) then begin
                Contract.FailTargetExists(Argument, Contract.RoutingKind(), Header."No.", TargetVersionCode);
                exit;
            end;
        end else
            if Header."Version Nos." = '' then begin
                Contract.FailVersionNos(Argument, Contract.RoutingKind(), Header."No.");
                exit;
            end;

        InsertVersion(Header, TargetVersionCode, HasTarget, StartingDate, Description, HasDescription, SourceDescription, Version);
        if Version."Version Code" = SourceVersionCode then
            Contract.ErrorSameVersion();

        // CopyRouting deletes the target lines first. The version was just inserted empty, so that delete removes nothing.
        RoutingCopy.CopyRouting(Header."No.", SourceVersionCode, Header, Version."Version Code");
        Contract.WriteCopySuccess(
            Argument, true, Header."No.", Version."Version Code", Version."Starting Date",
            CountLines(Header."No.", Version."Version Code"),
            CountTools(Header."No.", Version."Version Code"),
            CountPersonnel(Header."No.", Version."Version Code"),
            CountMeasures(Header."No.", Version."Version Code"),
            CountComments(Header."No.", Version."Version Code"));
    end;

    local procedure CanChange(var Argument: Record "Message Argument ori"): Boolean
    var
        Header: Record "Routing Header";
        Version: Record "Routing Version";
        Line: Record "Routing Line";
        Tool: Record "Routing Tool";
        Personnel: Record "Routing Personnel";
        Measure: Record "Routing Quality Measure";
        CommentLine: Record "Routing Comment Line";
    begin
        exit(Contract.HasTablePermission(
            Argument,
            Contract.RoutingKind(),
            Header.ReadPermission() and Version.ReadPermission() and Line.ReadPermission() and Tool.ReadPermission() and Personnel.ReadPermission() and Measure.ReadPermission() and CommentLine.ReadPermission(),
            Header.WritePermission() and Version.WritePermission() and Line.WritePermission() and Tool.WritePermission() and Personnel.WritePermission() and Measure.WritePermission() and CommentLine.WritePermission()));
    end;

    local procedure FindHeader(var Argument: Record "Message Argument ori"; DocumentNo: Code[20]; SystemId: Guid; HasSystemId: Boolean; var Header: Record "Routing Header"): Boolean
    begin
        Header.SetLoadFields("No.", SystemId, Description, "Version Nos.", Type, Status);
        if HasSystemId and (DocumentNo = '') then begin
            if not Header.GetBySystemId(SystemId) then begin
                Contract.FailSystemIdNotFound(Argument, Contract.RoutingKind(), SystemId);
                exit(false);
            end;
            exit(true);
        end;

        if not Header.Get(DocumentNo) then begin
            Contract.FailRecordNotFound(Argument, Contract.RoutingKind(), DocumentNo);
            exit(false);
        end;
        if HasSystemId and (Header.SystemId <> SystemId) then begin
            Contract.FailIdentifierConflict(Argument);
            exit(false);
        end;
        exit(true);
    end;

    local procedure TrySourceDescription(var Argument: Record "Message Argument ori"; Header: Record "Routing Header"; SourceVersionCode: Code[20]; var SourceDescription: Text[100]): Boolean
    var
        Version: Record "Routing Version";
    begin
        if SourceVersionCode = '' then begin
            SourceDescription := Header.Description;
            exit(true);
        end;
        Version.SetLoadFields(Description);
        if not Version.Get(Header."No.", SourceVersionCode) then begin
            Contract.FailSourceVersionNotFound(Argument, Contract.RoutingKind(), Header."No.", SourceVersionCode);
            exit(false);
        end;
        SourceDescription := Version.Description;
        exit(true);
    end;

    local procedure TargetExists(DocumentNo: Code[20]; VersionCode: Code[20]): Boolean
    var
        Version: Record "Routing Version";
    begin
        Version.SetLoadFields("Version Code");
        exit(Version.Get(DocumentNo, VersionCode));
    end;

    local procedure InsertVersion(Header: Record "Routing Header"; TargetVersionCode: Code[20]; HasTarget: Boolean; StartingDate: Date; Description: Text; HasDescription: Boolean; SourceDescription: Text[100]; var Version: Record "Routing Version")
    begin
        Version.Init();
        Version."Routing No." := Header."No.";
        if HasTarget then
            Version."Version Code" := TargetVersionCode;
        if HasDescription then
            Version.Description := CopyStr(Description, 1, MaxStrLen(Version.Description))
        else
            Version.Description := SourceDescription;
        Version."Starting Date" := StartingDate;
        if Header.Type = Header.Type::Parallel then
            Version.Type := Version.Type::Parallel
        else
            Version.Type := Version.Type::Serial;
        Version.Status := Version.Status::"Under Development";
        Version.Insert(true);
    end;

    local procedure CountLines(DocumentNo: Code[20]; VersionCode: Code[20]): Integer
    var
        Line: Record "Routing Line";
    begin
        Line.SetRange("Routing No.", DocumentNo);
        Line.SetRange("Version Code", VersionCode);
        exit(Line.Count());
    end;

    local procedure CountTools(DocumentNo: Code[20]; VersionCode: Code[20]): Integer
    var
        Tool: Record "Routing Tool";
    begin
        Tool.SetRange("Routing No.", DocumentNo);
        Tool.SetRange("Version Code", VersionCode);
        exit(Tool.Count());
    end;

    local procedure CountPersonnel(DocumentNo: Code[20]; VersionCode: Code[20]): Integer
    var
        Personnel: Record "Routing Personnel";
    begin
        Personnel.SetRange("Routing No.", DocumentNo);
        Personnel.SetRange("Version Code", VersionCode);
        exit(Personnel.Count());
    end;

    local procedure CountMeasures(DocumentNo: Code[20]; VersionCode: Code[20]): Integer
    var
        Measure: Record "Routing Quality Measure";
    begin
        Measure.SetRange("Routing No.", DocumentNo);
        Measure.SetRange("Version Code", VersionCode);
        exit(Measure.Count());
    end;

    local procedure CountComments(DocumentNo: Code[20]; VersionCode: Code[20]): Integer
    var
        CommentLine: Record "Routing Comment Line";
    begin
        CommentLine.SetRange("Routing No.", DocumentNo);
        CommentLine.SetRange("Version Code", VersionCode);
        exit(CommentLine.Count());
    end;
}
