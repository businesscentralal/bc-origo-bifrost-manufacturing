namespace Origo.Bifrost.Manufacturing;

using Microsoft.Manufacturing.ProductionBOM;
using Origo.Bifrost;

/// <summary>
/// Applies Manufacturing.ProductionBOM.CopyVersion inside one transaction.
/// A new empty version is created first. Business Central deletes the target lines before it copies,
/// and an empty version has nothing to delete. An existing target is refused before that delete.
/// </summary>
codeunit 10077095 "Prod BOM Copy Proc ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    var
        Contract: Codeunit "Mfg Copy Contract ori";

    trigger OnRun()
    begin
        Apply(Rec);
    end;

    /// <summary>Reads the request and copies the production BOM into a new version.</summary>
    /// <param name="Argument">The message argument.</param>
    internal procedure Apply(var Argument: Record "Message Argument ori")
    var
        Header: Record "Production BOM Header";
        Version: Record "Production BOM Version";
        BomCopy: Codeunit "Production BOM-Copy";
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
                Contract.FailTargetExists(Argument, Contract.ProductionBomKind(), Header."No.", TargetVersionCode);
                exit;
            end;
        end else
            if Header."Version Nos." = '' then begin
                Contract.FailVersionNos(Argument, Contract.ProductionBomKind(), Header."No.");
                exit;
            end;

        InsertVersion(Header, TargetVersionCode, HasTarget, StartingDate, Description, HasDescription, SourceDescription, Version);
        if Version."Version Code" = SourceVersionCode then
            Contract.ErrorSameVersion();

        // CopyBOM deletes the target lines first. The version was just inserted empty, so that delete removes nothing.
        BomCopy.CopyBOM(Header."No.", SourceVersionCode, Header, Version."Version Code");
        Contract.WriteCopySuccess(Argument, false, Header."No.", Version."Version Code", Version."Starting Date", CountLines(Header."No.", Version."Version Code"), 0, 0, 0, 0);
    end;

    local procedure CanChange(var Argument: Record "Message Argument ori"): Boolean
    var
        Header: Record "Production BOM Header";
        Version: Record "Production BOM Version";
        Line: Record "Production BOM Line";
        CommentLine: Record "Production BOM Comment Line";
    begin
        exit(Contract.HasTablePermission(
            Argument,
            Contract.ProductionBomKind(),
            Header.ReadPermission() and Version.ReadPermission() and Line.ReadPermission() and CommentLine.ReadPermission(),
            Header.WritePermission() and Version.WritePermission() and Line.WritePermission() and CommentLine.WritePermission()));
    end;

    local procedure FindHeader(var Argument: Record "Message Argument ori"; DocumentNo: Code[20]; SystemId: Guid; HasSystemId: Boolean; var Header: Record "Production BOM Header"): Boolean
    begin
        Header.SetLoadFields("No.", SystemId, Description, "Version Nos.", "Unit of Measure Code", Status);
        if HasSystemId and (DocumentNo = '') then begin
            if not Header.GetBySystemId(SystemId) then begin
                Contract.FailSystemIdNotFound(Argument, Contract.ProductionBomKind(), SystemId);
                exit(false);
            end;
            exit(true);
        end;

        if not Header.Get(DocumentNo) then begin
            Contract.FailRecordNotFound(Argument, Contract.ProductionBomKind(), DocumentNo);
            exit(false);
        end;
        if HasSystemId and (Header.SystemId <> SystemId) then begin
            Contract.FailIdentifierConflict(Argument);
            exit(false);
        end;
        exit(true);
    end;

    local procedure TrySourceDescription(var Argument: Record "Message Argument ori"; Header: Record "Production BOM Header"; SourceVersionCode: Code[20]; var SourceDescription: Text[100]): Boolean
    var
        Version: Record "Production BOM Version";
    begin
        if SourceVersionCode = '' then begin
            SourceDescription := Header.Description;
            exit(true);
        end;
        Version.SetLoadFields(Description);
        if not Version.Get(Header."No.", SourceVersionCode) then begin
            Contract.FailSourceVersionNotFound(Argument, Contract.ProductionBomKind(), Header."No.", SourceVersionCode);
            exit(false);
        end;
        SourceDescription := Version.Description;
        exit(true);
    end;

    local procedure TargetExists(DocumentNo: Code[20]; VersionCode: Code[20]): Boolean
    var
        Version: Record "Production BOM Version";
    begin
        Version.SetLoadFields("Version Code");
        exit(Version.Get(DocumentNo, VersionCode));
    end;

    local procedure InsertVersion(Header: Record "Production BOM Header"; TargetVersionCode: Code[20]; HasTarget: Boolean; StartingDate: Date; Description: Text; HasDescription: Boolean; SourceDescription: Text[100]; var Version: Record "Production BOM Version")
    begin
        Version.Init();
        Version."Production BOM No." := Header."No.";
        if HasTarget then
            Version."Version Code" := TargetVersionCode;
        if HasDescription then
            Version.Description := CopyStr(Description, 1, MaxStrLen(Version.Description))
        else
            Version.Description := SourceDescription;
        Version."Starting Date" := StartingDate;
        Version."Unit of Measure Code" := Header."Unit of Measure Code";
        Version.Status := Version.Status::"Under Development";
        Version.Insert(true);
    end;

    local procedure CountLines(DocumentNo: Code[20]; VersionCode: Code[20]): Integer
    var
        Line: Record "Production BOM Line";
    begin
        Line.SetRange("Production BOM No.", DocumentNo);
        Line.SetRange("Version Code", VersionCode);
        exit(Line.Count());
    end;
}
