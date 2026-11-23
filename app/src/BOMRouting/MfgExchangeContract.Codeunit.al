namespace Origo.Bifrost.Manufacturing;

using Microsoft.Inventory.Item;
using Microsoft.Manufacturing.ProductionBOM;
using Origo.Bifrost;

/// <summary>Validates exchange requests and describes the version-only operation.</summary>
codeunit 10077100 "Mfg Exchange Contract ori"
{
    Access = Internal;

    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        InvalidLbl: Label 'Cannot exchange components: parameter %1 is not valid for this request.', Comment = '%1 = parameter, is-IS=Ekki er hægt að skipta um íhluti: færibreytan %1 er ekki gild fyrir þessa beiðni.';
        NextLbl: Label 'Send existing, different fromType/fromNo and toType/toNo, a yyyy-mm-dd startingDate and the documented JSON formats. Inspect usage with Manufacturing.WhereUsed.Get.', Comment = 'is-IS=Sendu fromType/fromNo og toType/toNo sem eru til og mismunandi, startingDate á forminu yyyy-mm-dd og skjalfest JSON-snið. Skoðaðu notkun með Manufacturing.WhereUsed.Get.';
        UnknownNextLbl: Label 'Remove the undeclared parameter; deletion and in-place exchange are not supported.', Comment = 'is-IS=Fjarlægðu óskilgreindu færibreytuna; eyðing og skipti í eldri útgáfum eru ekki studd.';
        PermissionNextLbl: Label 'Ask for BIFROST Full ori and native Manufacturing write permissions.', Comment = 'is-IS=Biddu um BIFROST Full ori og skrifheimildir í framleiðslu.';
        ConfirmationNextLbl: Label 'Inspect the number of new versions and resend expectedCount with exactly that number.', Comment = 'is-IS=Skoðaðu fjölda nýrra útgáfa og sendu expectedCount aftur með nákvæmlega þeim fjölda.';
        NativeLbl: Label 'Business Central refused the exchange: %1', Comment = '%1 = native validation error, is-IS=Business Central hafnaði íhlutaskiptum: %1';
        OmitCommitLbl: Label 'Component exchange requires its own committing transaction.', Comment = 'is-IS=Íhlutaskipti krefjast eigin færslu sem er staðfest í gagnagrunni.';
        OmitCommitNextLbl: Label 'Run the exchange as a separate committing operation without Omit Commit.', Comment = 'is-IS=Keyrðu íhlutaskiptin sem sérstaka aðgerð sem staðfestir færslur án Omit Commit.';
        ExpectedLbl: Label 'a valid documented value', Comment = 'is-IS=gilt skjalfest gildi';

    /// <summary>Validates every supplied parameter before records are changed.</summary>
    /// <param name="Argument">The dispatcher argument.</param>
    /// <param name="Request">Receives the validated request.</param>
    /// <returns>True when the request is valid.</returns>
    internal procedure ReadRequest(var Argument: Record "Message Argument ori"; var Request: JsonObject): Boolean
    var
        Item: Record Item;
        Bom: Record "Production BOM Header";
        ParameterName: Text;
        Value: Text;
        Token: JsonToken;
        StartingDate: Date;
        ParsedMultiplier: Decimal;
        Count: Integer;
    begin
        Request := Argument.GetRequestJson();
        foreach ParameterName in Request.Keys() do
            if not (ParameterName in ['fromType', 'fromNo', 'toType', 'toNo', 'multiplyQtyWith', 'startingDate', 'copyRoutingLink', 'recertify', 'expectedCount']) then begin
                Fail(Argument, "Bifrost Error Code ori"::UnknownParameter, ParameterName, '');
                exit(false);
            end;
        foreach ParameterName in 'fromType|fromNo|toType|toNo|startingDate'.Split('|') do begin
            if not Request.Get(ParameterName, Token) then begin
                Fail(Argument, "Bifrost Error Code ori"::MissingParameter, ParameterName, '');
                exit(false);
            end;
            Token.WriteTo(Value);
            if not Value.StartsWith('"') then begin
                Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, ParameterName, '');
                exit(false);
            end;
            Value := Token.AsValue().AsText().Trim();
            if Value = '' then begin
                Fail(Argument, "Bifrost Error Code ori"::MissingParameter, ParameterName, '');
                exit(false);
            end;
            if (ParameterName in ['fromNo', 'toNo']) and (StrLen(Value) > 20) then begin
                Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, ParameterName, '');
                exit(false);
            end;
            if (ParameterName in ['fromType', 'toType']) and not (Value in ['item', 'productionBOM']) then begin
                Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, ParameterName, '');
                exit(false);
            end;
            Request.Replace(ParameterName, Value);
        end;
        Value := TextValue(Request, 'startingDate');
        if not Evaluate(StartingDate, Value, 9) then begin
            Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'startingDate', '');
            exit(false);
        end;
        if (StartingDate = 0D) or (Format(StartingDate, 0, 9) <> Value) then begin
            Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'startingDate', '');
            exit(false);
        end;
        foreach ParameterName in 'copyRoutingLink|recertify'.Split('|') do
            if Request.Get(ParameterName, Token) then begin
                Token.WriteTo(Value);
                if not (Value in ['true', 'false']) then begin
                    Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, ParameterName, '');
                    exit(false);
                end;
            end;
        if Request.Get('multiplyQtyWith', Token) then begin
            Token.WriteTo(Value);
            if not Evaluate(ParsedMultiplier, Value, 9) then begin
                Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'multiplyQtyWith', '');
                exit(false);
            end;
        end;
        if Request.Get('expectedCount', Token) then begin
            Token.WriteTo(Value);
            if not Evaluate(Count, Value, 9) then begin
                Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'expectedCount', '');
                exit(false);
            end;
            if Count < 0 then begin
                Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'expectedCount', '');
                exit(false);
            end;
        end;
        if (TextValue(Request, 'fromType') = TextValue(Request, 'toType')) and (UpperCase(TextValue(Request, 'fromNo')) = UpperCase(TextValue(Request, 'toNo'))) then begin
            Fail(Argument, "Bifrost Error Code ori"::ConflictingIdentifiers, 'toNo', '');
            exit(false);
        end;
        Item.SetLoadFields("No.");
        Bom.SetLoadFields("No.");
        foreach ParameterName in 'from|to'.Split('|') do
            if TextValue(Request, ParameterName + 'Type') = 'item' then begin
                if not Item.Get(TextValue(Request, ParameterName + 'No')) then begin
                    Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, ParameterName + 'No', '');
                    exit(false);
                end;
            end else
                if not Bom.Get(TextValue(Request, ParameterName + 'No')) then begin
                    Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, ParameterName + 'No', '');
                    exit(false);
                end;
        exit(true);
    end;

    /// <summary>Reads a validated text parameter.</summary>
    internal procedure TextValue(Request: JsonObject; ParameterName: Text): Text
    var
        Token: JsonToken;
    begin
        Request.Get(ParameterName, Token);
        exit(Token.AsValue().AsText());
    end;

    /// <summary>Returns an optional Boolean with its documented default.</summary>
    internal procedure BooleanValue(Request: JsonObject; ParameterName: Text; DefaultValue: Boolean): Boolean
    var
        Token: JsonToken;
    begin
        if Request.Get(ParameterName, Token) then
            exit(Token.AsValue().AsBoolean());
        exit(DefaultValue);
    end;

    /// <summary>Returns the validated quantity multiplier, default one.</summary>
    internal procedure Multiplier(Request: JsonObject): Decimal
    var
        Token: JsonToken;
    begin
        if Request.Get('multiplyQtyWith', Token) then
            exit(Token.AsValue().AsDecimal());
        exit(1);
    end;

    /// <summary>Returns the validated component kind.</summary>
    internal procedure LineType(Request: JsonObject; ParameterName: Text): Enum "Production BOM Line Type"
    begin
        if TextValue(Request, ParameterName) = 'item' then
            exit(Enum::"Production BOM Line Type"::Item);
        exit(Enum::"Production BOM Line Type"::"Production BOM");
    end;

    /// <summary>Returns a structured refusal with an actionable localized next step.</summary>
    internal procedure Fail(var Argument: Record "Message Argument ori"; ErrorCode: Enum "Bifrost Error Code ori"; ParameterName: Text; Expected: Text)
    var
        NextStep: Text;
    begin
        NextStep := NextLbl;
        case ErrorCode of
            ErrorCode::UnknownParameter:
                NextStep := UnknownNextLbl;
            ErrorCode::PermissionDenied:
                NextStep := PermissionNextLbl;
            ErrorCode::ConfirmationRequired, ErrorCode::ConfirmationMismatch:
                NextStep := ConfirmationNextLbl;
        end;
        if Expected = '' then
            Expected := ExpectedLbl;
        Argument.AddError(ErrorCode, StrSubstNo(InvalidLbl, ParameterName), ParameterName, '', Expected, NextStep);
        Argument.RespondWithCollectedErrors(ErrorCode, StrSubstNo(InvalidLbl, ParameterName));
    end;

    /// <summary>Refuses a caller-owned transaction before any native write.</summary>
    internal procedure FailOmitCommit(var Argument: Record "Message Argument ori")
    begin
        Argument.AddError("Bifrost Error Code ori"::PreconditionFailed, OmitCommitLbl, '', '', ExpectedLbl, OmitCommitNextLbl);
        Argument.RespondWithCollectedErrors("Bifrost Error Code ori"::PreconditionFailed, OmitCommitLbl);
    end;

    /// <summary>Maps a rolled-back native report validation failure to a stable refusal.</summary>
    internal procedure FailNative(var Argument: Record "Message Argument ori")
    var
        Reason: Text;
    begin
        Reason := GetLastErrorText();
        Argument.AddError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NativeLbl, Reason), 'toNo', '', ExpectedLbl, NextLbl);
        Argument.RespondWithCollectedErrors("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NativeLbl, Reason));
    end;

    /// <summary>Describes the request envelope.</summary>
    internal procedure Envelope(var Chapter: JsonObject)
    var
        Subject: JsonObject;
    begin
        Subject.Add('use', 'notUsed');
        Subject.Add('description', 'The subject is not read. Supply parameters under data.');
        Chapter.Add('subject', Subject);
        Chapter.Add('version', '1.0');
        Chapter.Add('contentType', 'text/json');
        Chapter.Add('dataRequired', true);
    end;

    /// <summary>Describes the source identifier.</summary>
    internal procedure Target(var Chapter: JsonArray)
    begin
        Chapter.Add(ContractMgt.TargetEntry('data.fromType', 'item or productionBOM', 'Source component kind.'));
        Chapter.Add(ContractMgt.TargetEntry('data.fromNo', 'component number', 'Existing component to replace.'));
        Chapter.Add(ContractMgt.TargetEntry('data.toType', 'item or productionBOM', 'Replacement component kind.'));
        Chapter.Add(ContractMgt.TargetEntry('data.toNo', 'component number', 'Existing nonblank replacement, different from the source.'));
    end;

    /// <summary>Describes all accepted parameters.</summary>
    internal procedure Parameters(var Chapter: JsonArray)
    begin
        Chapter.Add(ContractMgt.Parameter('fromType', 'string', true, 'item or productionBOM.'));
        Chapter.Add(ContractMgt.Parameter('fromNo', 'string', true, 'Existing source component number, at most 20 characters.'));
        Chapter.Add(ContractMgt.Parameter('toType', 'string', true, 'item or productionBOM.'));
        Chapter.Add(ContractMgt.Parameter('toNo', 'string', true, 'Existing replacement component number, at most 20 characters. Blank is refused.'));
        Chapter.Add(ContractMgt.Parameter('multiplyQtyWith', 'number', false, 'Native quantity multiplier, default 1.'));
        Chapter.Add(ContractMgt.Parameter('startingDate', 'date', true, 'New-version starting date, yyyy-mm-dd; selects the active source versions.'));
        Chapter.Add(ContractMgt.Parameter('copyRoutingLink', 'boolean', false, 'Copy the routing link, default true.'));
        Chapter.Add(ContractMgt.Parameter('recertify', 'boolean', false, 'Certify only the new versions, default false.'));
        Chapter.Add(ContractMgt.Parameter('expectedCount', 'integer', false, 'Number of new BOM versions, one per affected active BOM. Omit to preview without writing.'));
    end;

    /// <summary>Describes the native usage rows.</summary>
    internal procedure Response(var Chapter: JsonObject)
    var
        Fields: JsonArray;
    begin
        Chapter.Add('status', 'Success');
        Fields.Add(ContractMgt.ResponseField('newVersions', 'array', 'Created versions: productionBomNo, versionCode, status (New or Certified) and startingDate.'));
        Fields.Add(ContractMgt.ResponseField('changedLines', 'array', 'Replacement lines on new versions: productionBomNo, versionCode, lineNo, fromNo, toNo and quantityPer.'));
        Fields.Add(ContractMgt.ResponseField('skipped', 'array', 'Matching lines in closed or inactive sources: productionBomNo, versionCode, lineNo and reason.'));
        Chapter.Add('fields', Fields);
    end;

    /// <summary>Lists refusals and corrective steps.</summary>
    internal procedure Errors(var Chapter: JsonArray)
    begin
        Chapter.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'A required identifier or startingDate is absent or blank.', 'Send fromType, fromNo, toType, toNo and startingDate.'));
        Chapter.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'A JSON type, source kind, number, date or identifier length is invalid.', 'Use the documented parameters and formats.'));
        Chapter.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, 'A delete, in-place or other undeclared parameter was sent.', 'Remove the undeclared parameter.'));
        Chapter.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'A source or replacement item or BOM does not exist.', 'Inspect the identifiers with Data.Records.Get.'));
        Chapter.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, 'The source and replacement are identical.', 'Send a different replacement.'));
        Chapter.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller lacks Manufacturing write access or native table permissions.', 'Ask for BIFROST Full ori with Manufacturing write access.'));
        Chapter.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'No active BOM uses the component, native validation refuses the exchange, or Omit Commit was requested. No version is kept after failure.', 'Inspect usage with Manufacturing.WhereUsed.Get and correct component units or BOM data.'));
        Chapter.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::ConfirmationRequired, 'expectedCount is absent; nothing was changed.', 'Inspect expected and send that number of new versions as expectedCount.'));
        Chapter.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::ConfirmationMismatch, 'expectedCount differs from the new-version count; nothing was changed.', 'Inspect the current count and confirm it.'));
    end;

    /// <summary>Declares an idempotent read.</summary>
    internal procedure Effect(var Chapter: JsonObject)
    begin
        // This non-posting write confirms the new-version count explicitly before invoking the native report.
        Chapter.Add('effect', 'write');
        Chapter.Add('idempotent', false);
        Chapter.Add('permissionSet', 'BIFROST Full ori');
        Chapter.Add('changes', 'Creates and commits one new production BOM version per affected active BOM. expectedCount counts those new versions. Existing headers, versions and lines are unchanged; nothing is deleted and no ledger entries are posted.');
    end;

    /// <summary>Links to record inspection.</summary>
    internal procedure Related(var Chapter: JsonArray)
    begin
        Chapter.Add(ContractMgt.RelatedEntry('Manufacturing.WhereUsed.Get', 'Inspect component usage before exchanging.'));
        Chapter.Add(ContractMgt.RelatedEntry('Manufacturing.ProductionBOM.SetStatus', 'Certify the new versions later when recertify is false.'));
    end;

    /// <summary>Explains the discovery workflow.</summary>
    internal procedure Workflow(var Chapter: JsonObject)
    var
        Steps: JsonArray;
    begin
        Steps.Add(ContractMgt.WorkflowStep('Manufacturing.WhereUsed.Get', 'Inspect the component usage.'));
        Steps.Add(ContractMgt.WorkflowStep('Manufacturing.ProductionBOM.ExchangeItem', 'Preview, then confirm the new-version count.'));
        Steps.Add(ContractMgt.WorkflowStep('Data.Records.Get', 'Inspect the affected BOMs and their active versions.'));
        Chapter.Add('steps', Steps);
        Chapter.Add('text', 'Find usage before planning an engineering change.');
    end;

    /// <summary>Provides a complete request and response example.</summary>
    internal procedure Examples(var Chapter: JsonArray)
    begin
        Chapter.Add(ContractMgt.Example('Exchange a discontinued component into one new version', '{"type":"Manufacturing.ProductionBOM.ExchangeItem","data":{"fromType":"item","fromNo":"OLD-100","toType":"item","toNo":"NEW-100","startingDate":"2026-01-01","expectedCount":1}}', '{"status":"Success","newVersions":[{"productionBomNo":"BOM-100","versionCode":"1","status":"New","startingDate":"2026-01-01"}],"changedLines":[{"productionBomNo":"BOM-100","versionCode":"1","lineNo":10000,"fromNo":"OLD-100","toNo":"NEW-100","quantityPer":3}],"skipped":[]}'));

    end;

    /// <summary>Returns the English overview.</summary>
    internal procedure Overview(): Text
    begin
        exit('Replaces an item or production BOM component in new versions of every affected active production BOM. Existing headers, versions and their lines are unchanged. Preview without expectedCount, inspect the version count, then confirm that exact count.');
    end;

    /// <summary>Returns the English operation limits.</summary>
    internal procedure Notes(): Text
    begin
        exit('Only new-version exchange is supported. Blank targets, deleteExchangedComponent and in-place options are refused. The native calculation selects the active source version on startingDate; closed and inactive sources are skipped. With recertify false the native report leaves new versions New; true certifies only the new versions. Native certification commits are suppressed until all BOMs succeed. Omit Commit is refused before any native write; run the exchange as a separate committing operation. Repeating a successful call creates another version.');
    end;
}
