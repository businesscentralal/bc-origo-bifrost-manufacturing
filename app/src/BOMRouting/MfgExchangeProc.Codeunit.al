namespace Origo.Bifrost.Manufacturing;

using Microsoft.Inventory.Item;
using Microsoft.Manufacturing.ProductionBOM;
using Origo.Bifrost;

/// <summary>Runs the native version-only exchange atomically and returns the new records.</summary>
codeunit 10077101 "Mfg Exchange Proc ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    var
        Contract: Codeunit "Mfg Exchange Contract ori";
        SkippedLbl: Label 'The source version is inactive or the BOM is closed.', Comment = 'is-IS=Upprunaútgáfan er óvirk eða efnislistinn er lokaður.';
        ResultCountLbl: Label 'The exchange created an unexpected number of versions. All changes were rolled back.', Comment = 'is-IS=Íhlutaskiptin bjuggu til óvæntan fjölda útgáfa. Öllum breytingum var afturkallað.';

    trigger OnRun()
    begin
        Apply(Rec);
    end;

    /// <summary>Revalidates under locks, checks the confirmed count and executes the native processing-only report.</summary>
    /// <param name="Argument">The dispatcher argument.</param>
    internal procedure Apply(var Argument: Record "Message Argument ori")
    var
        Header: Record "Production BOM Header";
        Version: Record "Production BOM Version";
        Line: Record "Production BOM Line";
        TempSelected: Record "Production BOM Header" temporary;
        TempChanged: Record "Production BOM Line" temporary;
        Events: Codeunit "BOM Routing Events ori";
        Request: JsonObject;
        Token: JsonToken;
        Skipped: JsonArray;
        OriginalVersionIds: List of [Guid];
        ExpectedCount: Integer;
        Parameters: Text;
    begin
        Header.LockTable();
        Version.LockTable();
        Line.LockTable();
        if not Prepare(Argument, Request, TempSelected, Skipped) then
            exit;
        if not Request.Get('expectedCount', Token) then begin
            Contract.Fail(Argument, "Bifrost Error Code ori"::ConfirmationRequired, 'expectedCount', Format(TempSelected.Count(), 0, 9));
            exit;
        end;
        ExpectedCount := Token.AsValue().AsInteger();
        if ExpectedCount <> TempSelected.Count() then begin
            Contract.Fail(Argument, "Bifrost Error Code ori"::ConfirmationMismatch, 'expectedCount', Format(TempSelected.Count(), 0, 9));
            exit;
        end;
        SnapshotVersions(TempSelected, OriginalVersionIds);
        SnapshotChangedLines(Request, TempSelected, TempChanged);
        Parameters := BuildParameters(Request);
        // Native version certification would otherwise commit partway through a batch.
        // The manual subscription ends automatically on return or error, including Omit Commit.
        BindSubscription(Events);
        Report.Execute(Report::"Exchange Production BOM Item", Parameters);
        UnbindSubscription(Events);
        WriteResponse(Argument, Request, TempSelected, TempChanged, OriginalVersionIds, Skipped);
    end;

    /// <summary>Validates the write role, request and native source selection without opening a write transaction.</summary>
    /// <param name="Argument">The dispatcher argument.</param>
    /// <param name="Request">Receives the validated request.</param>
    /// <param name="TempSelected">Receives distinct affected active BOMs.</param>
    /// <param name="Skipped">Receives matching inactive or closed source lines.</param>
    /// <returns>True when at least one active BOM can be exchanged.</returns>
    internal procedure Prepare(var Argument: Record "Message Argument ori"; var Request: JsonObject; var TempSelected: Record "Production BOM Header" temporary; var Skipped: JsonArray): Boolean
    var
        Gate: Record "Mfg Write Gate ori";
        Item: Record Item;
        Header: Record "Production BOM Header";
        Version: Record "Production BOM Version";
        Line: Record "Production BOM Line";
        WriteCheck: Codeunit "Mfg Write Check ori";
        VersionMgt: Codeunit VersionManagement;
        StartingDate: Date;
        SourceClosed: Boolean;
        EntryJson: JsonObject;
    begin
        if not Gate.WritePermission() then begin
            Contract.Fail(Argument, "Bifrost Error Code ori"::PermissionDenied, 'fromNo', '');
            exit(false);
        end;
        WriteCheck.AssertCanWrite('Manufacturing.ProductionBOM.ExchangeItem');
        if not (Item.ReadPermission() and Header.ReadPermission() and Version.ReadPermission() and Line.ReadPermission() and Version.WritePermission() and Line.WritePermission()) then begin
            Contract.Fail(Argument, "Bifrost Error Code ori"::PermissionDenied, 'fromNo', '');
            exit(false);
        end;
        if not Contract.ReadRequest(Argument, Request) then
            exit(false);
        Evaluate(StartingDate, Contract.TextValue(Request, 'startingDate'), 9);
        TempSelected.Reset();
        TempSelected.DeleteAll();
        Clear(Skipped);
        Header.ReadIsolation := IsolationLevel::Default;
        Version.ReadIsolation := IsolationLevel::Default;
        Line.ReadIsolation := IsolationLevel::Default;
        Header.SetLoadFields("No.", Status);
        Version.SetLoadFields(Status);
        Line.SetLoadFields("Production BOM No.", "Version Code", "Line No.");
        Line.SetRange(Type, Contract.LineType(Request, 'fromType'));
        Line.SetRange("No.", Contract.TextValue(Request, 'fromNo'));
        if Line.FindSet() then
            repeat
                Header.Get(Line."Production BOM No.");
                SourceClosed := Header.Status = Header.Status::Closed;
                if Line."Version Code" <> '' then begin
                    Version.Get(Line."Production BOM No.", Line."Version Code");
                    SourceClosed := Version.Status = Version.Status::Closed;
                end;
                if not SourceClosed and (Line."Version Code" = VersionMgt.GetBOMVersion(Line."Production BOM No.", StartingDate, true)) then begin
                    if not TempSelected.Get(Header."No.") then begin
                        TempSelected.Init();
                        TempSelected."No." := Header."No.";
                        TempSelected.Insert();
                    end;
                end else begin
                    Clear(EntryJson);
                    EntryJson.Add('productionBomNo', Line."Production BOM No.");
                    EntryJson.Add('versionCode', Line."Version Code");
                    EntryJson.Add('lineNo', Line."Line No.");
                    EntryJson.Add('reason', SkippedLbl);
                    Skipped.Add(EntryJson);
                end;
            until Line.Next() = 0;
        if TempSelected.IsEmpty() then begin
            Contract.Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'fromNo', '');
            exit(false);
        end;
        exit(true);
    end;

    local procedure SnapshotVersions(var TempSelected: Record "Production BOM Header" temporary; var OriginalIds: List of [Guid])
    var
        Version: Record "Production BOM Version";
    begin
        Version.ReadIsolation := IsolationLevel::Default;
        Version.SetLoadFields(SystemId);
        if TempSelected.FindSet() then
            repeat
                Version.SetRange("Production BOM No.", TempSelected."No.");
                if Version.FindSet() then
                    repeat
                        OriginalIds.Add(Version.SystemId);
                    until Version.Next() = 0;
            until TempSelected.Next() = 0;
    end;

    local procedure SnapshotChangedLines(Request: JsonObject; var TempSelected: Record "Production BOM Header" temporary; var TempChanged: Record "Production BOM Line" temporary)
    var
        Line: Record "Production BOM Line";
        VersionMgt: Codeunit VersionManagement;
        StartingDate: Date;
    begin
        Evaluate(StartingDate, Contract.TextValue(Request, 'startingDate'), 9);
        Line.ReadIsolation := IsolationLevel::Default;
        Line.SetRange(Type, Contract.LineType(Request, 'fromType'));
        Line.SetRange("No.", Contract.TextValue(Request, 'fromNo'));
        if TempSelected.FindSet() then
            repeat
                Line.SetRange("Production BOM No.", TempSelected."No.");
                Line.SetRange("Version Code", VersionMgt.GetBOMVersion(TempSelected."No.", StartingDate, true));
                if Line.FindSet() then
                    repeat
                        TempChanged := Line;
                        TempChanged.Insert();
                    until Line.Next() = 0;
            until TempSelected.Next() = 0;
    end;

    local procedure BuildParameters(Request: JsonObject): Text
    var
        Document: XmlDocument;
        Root: XmlElement;
        Options: XmlElement;
        Parameters: Text;
    begin
        Document := XmlDocument.Create();
        Document.SetDeclaration(XmlDeclaration.Create('1.0', 'utf-8', 'yes'));
        Root := XmlElement.Create('ReportParameters');
        Root.SetAttribute('name', 'Exchange Production BOM Item');
        Root.SetAttribute('id', '99001043');
        Options := XmlElement.Create('Options');
        // Report parameters use source variable names, not request-page control names.
        AddOption(Options, 'FromProductionBOMLineType', Format(Contract.LineType(Request, 'fromType').AsInteger(), 0, 9));
        AddOption(Options, 'FromProductionBOMNo', Contract.TextValue(Request, 'fromNo'));
        AddOption(Options, 'ToProductionBOMLineType', Format(Contract.LineType(Request, 'toType').AsInteger(), 0, 9));
        AddOption(Options, 'ToProductionBOMNo', Contract.TextValue(Request, 'toNo'));
        AddOption(Options, 'CreateNewVersion', 'true');
        AddOption(Options, 'QtyMultiply', Format(Contract.Multiplier(Request), 0, 9));
        AddOption(Options, 'StartingDate', Contract.TextValue(Request, 'startingDate'));
        AddOption(Options, 'Recertify', Format(Contract.BooleanValue(Request, 'recertify', false), 0, 9));
        AddOption(Options, 'CopyRoutingLink', Format(Contract.BooleanValue(Request, 'copyRoutingLink', true), 0, 9));
        AddOption(Options, 'DeleteExcComp', 'false');
        Root.Add(Options);
        Root.Add(XmlElement.Create('DataItems'));
        Document.Add(Root);
        Document.WriteTo(Parameters);
        exit(Parameters);
    end;

    local procedure AddOption(var Options: XmlElement; OptionName: Text; Value: Text)
    var
        OptionElement: XmlElement;
    begin
        OptionElement := XmlElement.Create('Field');
        OptionElement.SetAttribute('name', OptionName);
        OptionElement.Add(XmlText.Create(Value));
        Options.Add(OptionElement);
    end;

    local procedure WriteResponse(var Argument: Record "Message Argument ori"; Request: JsonObject; var TempSelected: Record "Production BOM Header" temporary; var TempChanged: Record "Production BOM Line" temporary; OriginalIds: List of [Guid]; Skipped: JsonArray)
    var
        Version: Record "Production BOM Version";
        Line: Record "Production BOM Line";
        NewVersions: JsonArray;
        ChangedLines: JsonArray;
        EntryJson: JsonObject;
        Response: JsonObject;
    begin
        Version.ReadIsolation := IsolationLevel::Default;
        Line.ReadIsolation := IsolationLevel::Default;
        Version.SetLoadFields(SystemId, "Version Code", Status, "Starting Date");
        Line.SetLoadFields("Line No.", "Quantity per");
        if TempSelected.FindSet() then
            repeat
                Version.SetRange("Production BOM No.", TempSelected."No.");
                if Version.FindSet() then
                    repeat
                        if not OriginalIds.Contains(Version.SystemId) then begin
                            Clear(EntryJson);
                            EntryJson.Add('productionBomNo', Version."Production BOM No.");
                            EntryJson.Add('versionCode', Version."Version Code");
                            if Version.Status = Version.Status::Certified then
                                EntryJson.Add('status', 'Certified')
                            else
                                EntryJson.Add('status', 'New');
                            EntryJson.Add('startingDate', Format(Version."Starting Date", 0, 9));
                            NewVersions.Add(EntryJson);
                            TempChanged.SetRange("Production BOM No.", Version."Production BOM No.");
                            if TempChanged.FindSet() then
                                repeat
                                    Line.Get(Version."Production BOM No.", Version."Version Code", TempChanged."Line No.");
                                    Clear(EntryJson);
                                    EntryJson.Add('productionBomNo', Version."Production BOM No.");
                                    EntryJson.Add('versionCode', Version."Version Code");
                                    EntryJson.Add('lineNo', Line."Line No.");
                                    EntryJson.Add('fromNo', Contract.TextValue(Request, 'fromNo'));
                                    EntryJson.Add('toNo', Contract.TextValue(Request, 'toNo'));
                                    EntryJson.Add('quantityPer', Line."Quantity per");
                                    ChangedLines.Add(EntryJson);
                                until TempChanged.Next() = 0;
                        end;
                    until Version.Next() = 0;
            until TempSelected.Next() = 0;
        if NewVersions.Count() <> TempSelected.Count() then
            Error(ResultCountLbl);
        Response.Add('status', 'Success');
        Response.Add('newVersions', NewVersions);
        Response.Add('changedLines', ChangedLines);
        Response.Add('skipped', Skipped);
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
