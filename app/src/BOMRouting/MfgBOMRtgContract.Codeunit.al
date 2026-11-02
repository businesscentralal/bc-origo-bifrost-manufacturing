namespace Origo.Bifrost.Manufacturing;

using Microsoft.Inventory.Item;
using Microsoft.Manufacturing.ProductionBOM;
using Microsoft.Manufacturing.Routing;
using Origo.Bifrost;

/// <summary>
/// Shared request reading, success writing and contract chapters for
/// Manufacturing.ProductionBOM.SetStatus and Manufacturing.Routing.SetStatus.
/// The answer uses status Success and recordStatus for the record, because Foundation
/// reserves status for the outcome of the message.
/// </summary>
codeunit 10077086 "Mfg BOMRtg Contract ori"
{
    Access = Internal;

    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        CertifiedTok: Label 'Certified', Locked = true;
        UnderDevelopmentTok: Label 'UnderDevelopment', Locked = true;
        NewTok: Label 'New', Locked = true;
        ClosedTok: Label 'Closed', Locked = true;
        StatusNotSupportedErr: Label 'Status %1 is not supported. Send Certified or UnderDevelopment.', Comment = '%1 = the status that was sent, is-IS=Staða %1 er ekki studd. Sendu Certified eða UnderDevelopment.';
        ClosedReasonTxt: Label 'Closing asks a question that cannot be answered without a screen, so Business Central would silently keep the old status.', Comment = 'is-IS=Lokun spyr spurningar sem ekki er hægt að svara án skjás, þannig að Business Central héldi gömlu stöðunni án athugasemdar.';
        AllowedStatusNextStepTxt: Label 'Send Certified or UnderDevelopment.', Comment = 'is-IS=Sendu Certified eða UnderDevelopment.';
        VersionMissingErr: Label 'Version %1 of %2 %3 was not found.', Comment = '%1 = version code, %2 = production BOM or routing, %3 = number, is-IS=Útgáfa %1 af %2 %3 fannst ekki.';
        VersionMissingNextStepTxt: Label 'Read the versions with Data.Records.Get.', Comment = 'is-IS=Lestu útgáfurnar með Data.Records.Get.';
        CheckFailedNextStepTxt: Label 'Correct the lines with Data.Records.Set and send the same request again.', Comment = 'is-IS=Lagfærðu línurnar með Data.Records.Set og sendu sömu beiðni aftur.';
        UnchangedMsg: Label '%1 %2 already has status %3. Nothing was changed.', Comment = '%1 = production BOM or routing, %2 = number, %3 = status, is-IS=%1 %2 er þegar með stöðuna %3. Engu var breytt.';
        MissingParameterErr: Label 'Parameter %1 is required.', Comment = '%1 = parameter name, is-IS=Færibreyta %1 er nauðsynleg.';
        MissingNextStepTxt: Label 'Send no and status. status is Certified or UnderDevelopment.', Comment = 'is-IS=Sendu no og status. status er Certified eða UnderDevelopment.';
        UnknownParameterErr: Label 'Parameter %1 is not used by this message type.', Comment = '%1 = parameter name, is-IS=Færibreytan %1 er ekki notuð af þessari skilaboðategund.';
        UnknownNextStepTxt: Label 'Remove %1 from the request.', Comment = '%1 = parameter name, is-IS=Fjarlægðu %1 úr beiðninni.';
        TooLongErr: Label 'Parameter %1 is longer than %2 characters.', Comment = '%1 = parameter name, %2 = maximum length, is-IS=Færibreyta %1 er lengri en %2 stafir.';
        TooLongNextStepTxt: Label 'Send a code of at most 20 characters.', Comment = 'is-IS=Sendu kóða sem er í mesta lagi 20 stafir.';
        NotACodeErr: Label 'Parameter %1 must be text of at most 20 characters.', Comment = '%1 = parameter name, is-IS=Færibreyta %1 verður að vera texti sem er í mesta lagi 20 stafir.';
        RecordNotFoundErr: Label '%1 %2 was not found.', Comment = '%1 = production BOM or routing, %2 = number, is-IS=%1 %2 fannst ekki.';
        RecordNextStepTxt: Label 'Read the records with Data.Records.Get.', Comment = 'is-IS=Lestu færslurnar með Data.Records.Get.';
        SeveralProblemsErr: Label 'The request has more than one problem. Nothing was changed.', Comment = 'is-IS=Beiðnin hefur fleiri en eitt vandamál. Engu var breytt.';
        PermissionDeniedErr: Label 'You do not have permission to change this %1.', Comment = '%1 = production BOM or routing, is-IS=Þú hefur ekki heimild til að breyta þessu %1.';
        PermissionExpectedTxt: Label 'read and write permission on the manufacturing tables', Comment = 'is-IS=les- og skrifheimild á framleiðslutöflunum';
        PermissionNextStepTxt: Label 'Ask for BIFROST Full ori and the manufacturing table permissions, then send the same request again.', Comment = 'is-IS=Biddu um BIFROST Full ori og heimildir á framleiðslutöflunum og sendu sömu beiðni aftur.';
        ProductionBomKindLbl: Label 'production BOM', Comment = 'is-IS=framleiðsluefnislisti';
        RoutingKindLbl: Label 'routing', Comment = 'is-IS=vinnsluleið';
        CodeExpectedTxt: Label 'text of at most 20 characters', Comment = 'is-IS=texti sem er í mesta lagi 20 stafir';
        StatusExpectedTxt: Label 'Certified or UnderDevelopment', Comment = 'is-IS=Certified eða UnderDevelopment';
        DeclaredParameterTxt: Label 'a parameter this message type declares', Comment = 'is-IS=færibreyta sem þessi skilaboðategund skilgreinir';
        ExistingVersionTxt: Label 'an existing version', Comment = 'is-IS=útgáfa sem er til';

    /// <summary>Reads no, versionCode and status. Collects every problem and returns false when any were collected.</summary>
    /// <param name="Argument">The message argument. Errors are collected on it.</param>
    /// <param name="DocumentNo">Receives the production BOM or routing number.</param>
    /// <param name="VersionCode">Receives the version code, or blank for the header.</param>
    /// <param name="StatusToken">Receives Certified or UnderDevelopment.</param>
    /// <returns>True when the request can be applied.</returns>
    internal procedure ReadSetStatusRequest(var Argument: Record "Message Argument ori"; var DocumentNo: Code[20]; var VersionCode: Code[20]; var StatusToken: Text): Boolean
    var
        RequestJson: JsonObject;
        Token: JsonToken;
    begin
        RequestJson := Argument.GetRequestJson();
        CollectUnknownKeys(Argument, RequestJson);
        DocumentNo := '';
        VersionCode := '';
        StatusToken := '';

        if not RequestJson.Get('no', Token) then
            AddMissing(Argument, 'no')
        else
            ReadRequiredCode(Argument, Token, 'no', DocumentNo);

        if RequestJson.Get('versionCode', Token) then
            ReadOptionalCode(Argument, Token, 'versionCode', VersionCode);

        if not RequestJson.Get('status', Token) then
            AddMissing(Argument, 'status')
        else
            ReadStatus(Argument, Token, StatusToken);

        exit(not Argument.HasCollectedErrors());
    end;

    /// <summary>Responds with validation errors collected before any write. One error keeps its own code.</summary>
    /// <param name="Argument">The message argument that holds the collected errors.</param>
    internal procedure RaiseCollected(var Argument: Record "Message Argument ori")
    begin
        Argument.RespondWithCollectedErrors("Bifrost Error Code ori"::MultipleErrors, SeveralProblemsErr);
    end;

    /// <summary>Preserves Foundation's platform error classification and adds the corrective next step.</summary>
    /// <param name="Argument">The message argument immediately after a failed Codeunit.Run.</param>
    internal procedure RespondWithPlatformError(var Argument: Record "Message Argument ori")
    var
        ResponseJson: JsonObject;
        CodeToken: JsonToken;
    begin
        Argument.RespondWithLastError();
        ResponseJson := Argument.GetResponseJson();
        if ResponseJson.Get('code', CodeToken) then
            if CodeToken.AsValue().AsText() = 'BusinessCentralError' then begin
                if ResponseJson.Contains('nextStep') then
                    ResponseJson.Replace('nextStep', CheckFailedNextStepTxt)
                else
                    ResponseJson.Add('nextStep', CheckFailedNextStepTxt);
                Argument.SetResponseJson(ResponseJson);
            end;
    end;

    /// <summary>Refuses the call when the caller cannot read and write the record.</summary>
    /// <param name="Argument">The message argument.</param>
    /// <param name="Kind">production BOM or routing, already translated.</param>
    /// <param name="CanRead">True when the caller can read the table.</param>
    /// <param name="CanWrite">True when the caller can write the table.</param>
    /// <returns>True when the caller may continue.</returns>
    internal procedure HasTablePermission(var Argument: Record "Message Argument ori"; Kind: Text; CanRead: Boolean; CanWrite: Boolean): Boolean
    begin
        if CanRead and CanWrite then
            exit(true);
        Argument.AddError("Bifrost Error Code ori"::PermissionDenied, StrSubstNo(PermissionDeniedErr, Kind), 'no', '', PermissionExpectedTxt, PermissionNextStepTxt);
        RaiseCollected(Argument);
        exit(false);
    end;

    /// <summary>Answers that the header record does not exist.</summary>
    /// <param name="Argument">The message argument.</param>
    /// <param name="Kind">production BOM or routing.</param>
    /// <param name="DocumentNo">The number that was not found.</param>
    internal procedure FailRecordNotFound(var Argument: Record "Message Argument ori"; Kind: Text; DocumentNo: Code[20])
    begin
        Argument.AddError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(RecordNotFoundErr, Kind, DocumentNo), 'no', DocumentNo, Kind, RecordNextStepTxt);
        RaiseCollected(Argument);
    end;

    /// <summary>Answers that the version does not exist.</summary>
    /// <param name="Argument">The message argument.</param>
    /// <param name="Kind">production BOM or routing.</param>
    /// <param name="DocumentNo">The header number.</param>
    /// <param name="VersionCode">The version code that was not found.</param>
    internal procedure FailVersionNotFound(var Argument: Record "Message Argument ori"; Kind: Text; DocumentNo: Code[20]; VersionCode: Code[20])
    begin
        Argument.AddError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(VersionMissingErr, VersionCode, Kind, DocumentNo), 'versionCode', VersionCode, ExistingVersionTxt, VersionMissingNextStepTxt);
        RaiseCollected(Argument);
    end;

    /// <summary>Writes the success answer. lowLevelCode and usedOnItems are header-only.</summary>
    /// <param name="Argument">The message argument.</param>
    /// <param name="Kind">production BOM or routing.</param>
    /// <param name="DocumentNo">The header number.</param>
    /// <param name="VersionCode">The version code, or blank for the header.</param>
    /// <param name="PreviousToken">The status before the call.</param>
    /// <param name="RecordToken">The status after the call.</param>
    /// <param name="Changed">False when the record already had the requested status.</param>
    /// <param name="LowLevelCode">The header low-level code. Written only when IncludeLowLevelCode is true.</param>
    /// <param name="UsedOnItems">Items that use the header. Written only when IncludeUsedOnItems is true.</param>
    /// <param name="IncludeLowLevelCode">True for a production BOM header.</param>
    /// <param name="IncludeUsedOnItems">True for a header. False for a version.</param>
    internal procedure WriteSuccess(var Argument: Record "Message Argument ori"; Kind: Text; DocumentNo: Code[20]; VersionCode: Code[20]; PreviousToken: Text; RecordToken: Text; Changed: Boolean; LowLevelCode: Integer; UsedOnItems: Integer; IncludeLowLevelCode: Boolean; IncludeUsedOnItems: Boolean)
    var
        ResponseJson: JsonObject;
    begin
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('no', DocumentNo);
        ResponseJson.Add('versionCode', VersionCode);
        ResponseJson.Add('previousStatus', PreviousToken);
        ResponseJson.Add('recordStatus', RecordToken);
        ResponseJson.Add('changed', Changed);
        if not Changed then
            ResponseJson.Add('message', StrSubstNo(UnchangedMsg, Kind, DocumentNo, RecordToken));
        if IncludeLowLevelCode then
            ResponseJson.Add('lowLevelCode', LowLevelCode);
        if IncludeUsedOnItems then
            ResponseJson.Add('usedOnItems', UsedOnItems);
        Argument.SetResponseJson(ResponseJson);
    end;

    /// <summary>The translated name of a production BOM.</summary>
    /// <returns>production BOM, or the Icelandic caption at lcid 1039.</returns>
    internal procedure ProductionBomKind(): Text
    begin
        exit(ProductionBomKindLbl);
    end;

    /// <summary>The translated name of a routing.</summary>
    /// <returns>routing, or the Icelandic caption at lcid 1039.</returns>
    internal procedure RoutingKind(): Text
    begin
        exit(RoutingKindLbl);
    end;

    /// <summary>Stable token for a production BOM status. Does not format the enum.</summary>
    /// <param name="Status">The status to name.</param>
    /// <returns>New, Certified, UnderDevelopment or Closed.</returns>
    internal procedure BomStatusToken(Status: Enum "BOM Status"): Text
    begin
        case Status of
            Status::New:
                exit(NewTok);
            Status::Certified:
                exit(CertifiedTok);
            Status::"Under Development":
                exit(UnderDevelopmentTok);
            Status::Closed:
                exit(ClosedTok);
        end;
    end;

    /// <summary>Stable token for a routing status. Does not format the enum.</summary>
    /// <param name="Status">The status to name.</param>
    /// <returns>New, Certified, UnderDevelopment or Closed.</returns>
    internal procedure RoutingStatusToken(Status: Enum "Routing Status"): Text
    begin
        case Status of
            Status::New:
                exit(NewTok);
            Status::Certified:
                exit(CertifiedTok);
            Status::"Under Development":
                exit(UnderDevelopmentTok);
            Status::Closed:
                exit(ClosedTok);
        end;
    end;

    /// <summary>Maps a validated token to a production BOM status.</summary>
    /// <param name="StatusToken">Certified or UnderDevelopment.</param>
    /// <returns>The matching BOM status.</returns>
    internal procedure BomStatusFromToken(StatusToken: Text): Enum "BOM Status"
    begin
        if StatusToken = CertifiedTok then
            exit(Enum::"BOM Status"::Certified);
        exit(Enum::"BOM Status"::"Under Development");
    end;

    /// <summary>Maps a validated token to a routing status.</summary>
    /// <param name="StatusToken">Certified or UnderDevelopment.</param>
    /// <returns>The matching routing status.</returns>
    internal procedure RoutingStatusFromToken(StatusToken: Text): Enum "Routing Status"
    begin
        if StatusToken = CertifiedTok then
            exit(Enum::"Routing Status"::Certified);
        exit(Enum::"Routing Status"::"Under Development");
    end;

    /// <summary>Counts items whose production BOM is this header.</summary>
    /// <param name="DocumentNo">The production BOM number.</param>
    /// <returns>The number of items.</returns>
    internal procedure CountBomItems(DocumentNo: Code[20]): Integer
    var
        Item: Record Item;
    begin
        Item.SetLoadFields("No.");
        Item.SetRange("Production BOM No.", DocumentNo);
        exit(Item.Count());
    end;

    /// <summary>Counts items whose routing is this header.</summary>
    /// <param name="DocumentNo">The routing number.</param>
    /// <returns>The number of items.</returns>
    internal procedure CountRoutingItems(DocumentNo: Code[20]): Integer
    var
        Item: Record Item;
    begin
        Item.SetLoadFields("No.");
        Item.SetRange("Routing No.", DocumentNo);
        exit(Item.Count());
    end;

    /// <summary>Builds the envelope. The subject is not read.</summary>
    /// <param name="EnvelopeChapter">Receives the chapter.</param>
    internal procedure Envelope(var EnvelopeChapter: JsonObject)
    var
        Subject: JsonObject;
    begin
        Subject.Add('use', 'notUsed');
        Subject.Add('description', 'The subject is not read. Send no and status under data.');
        EnvelopeChapter.Add('subject', Subject);
        EnvelopeChapter.Add('dataRequired', true);
        EnvelopeChapter.Add('version', '1.0');
        EnvelopeChapter.Add('contentType', 'text/json');
    end;

    /// <summary>Builds the target chapter.</summary>
    /// <param name="IsProductionBom">True for a production BOM.</param>
    /// <param name="TargetEntries">Receives the chapter.</param>
    internal procedure Target(IsProductionBom: Boolean; var TargetEntries: JsonArray)
    begin
        if IsProductionBom then
            TargetEntries.Add(ContractMgt.TargetEntry('data.no', 'production BOM no.', 'The production BOM header. A blank versionCode changes this header.'))
        else
            TargetEntries.Add(ContractMgt.TargetEntry('data.no', 'routing no.', 'The routing header. A blank versionCode changes this header.'));
        TargetEntries.Add(ContractMgt.TargetEntry('data.versionCode', 'version code', 'When set, only that version changes and the header status stays as it is.'));
    end;

    /// <summary>Builds the parameters chapter.</summary>
    /// <param name="IsProductionBom">True for a production BOM.</param>
    /// <param name="ParameterEntries">Receives the chapter.</param>
    internal procedure Parameters(IsProductionBom: Boolean; var ParameterEntries: JsonArray)
    var
        StatusParameter: JsonObject;
        Allowed: JsonArray;
    begin
        if IsProductionBom then
            ParameterEntries.Add(ContractMgt.Parameter('no', 'string', true, 'The production BOM number.'))
        else
            ParameterEntries.Add(ContractMgt.Parameter('no', 'string', true, 'The routing number.'));
        ParameterEntries.Add(ContractMgt.Parameter('versionCode', 'string', false, 'The version to change. Omit it, or send it blank, to change the header.'));
        StatusParameter := ContractMgt.Parameter('status', 'string', true, 'Certified or UnderDevelopment. Spaces and letter case are ignored, so Under Development is accepted. Closed and New are refused.');
        Allowed.Add(CertifiedTok);
        Allowed.Add(UnderDevelopmentTok);
        StatusParameter.Add('allowed', Allowed);
        ParameterEntries.Add(StatusParameter);
    end;

    /// <summary>Builds the response chapter.</summary>
    /// <param name="IsProductionBom">True for a production BOM.</param>
    /// <param name="ResponseChapter">Receives the chapter.</param>
    internal procedure Response(IsProductionBom: Boolean; var ResponseChapter: JsonObject)
    var
        Fields: JsonArray;
    begin
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success. Foundation reserves this key for the outcome of the message.'));
        Fields.Add(ContractMgt.ResponseField('no', 'string', 'The production BOM or routing number.'));
        Fields.Add(ContractMgt.ResponseField('versionCode', 'string', 'The version code, or empty when the header was changed.'));
        Fields.Add(ContractMgt.ResponseField('previousStatus', 'string', 'The status before the call: New, Certified, UnderDevelopment or Closed.'));
        Fields.Add(ContractMgt.ResponseField('recordStatus', 'string', 'The status after the call. This is not the message outcome; that is status.'));
        Fields.Add(ContractMgt.ResponseField('changed', 'boolean', 'False when the record already had the requested status. Nothing is written in that case.'));
        Fields.Add(ContractMgt.ResponseField('message', 'string', 'Present only when changed is false.'));
        if IsProductionBom then
            Fields.Add(ContractMgt.ResponseField('lowLevelCode', 'integer', 'The header low-level code after the call. Omitted for a version.'));
        Fields.Add(ContractMgt.ResponseField('usedOnItems', 'integer', 'Items that use this header. Omitted for a version.'));
        ResponseChapter.Add('fields', Fields);
    end;

    /// <summary>Builds the errors chapter, including Retryable.</summary>
    /// <param name="ErrorEntries">Receives the chapter.</param>
    internal procedure Errors(var ErrorEntries: JsonArray)
    begin
        ErrorEntries.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'no or status is missing or blank.', MissingNextStepTxt));
        ErrorEntries.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'status is not Certified or UnderDevelopment. Closed and New are refused.', AllowedStatusNextStepTxt));
        ErrorEntries.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'no or versionCode is not text of at most 20 characters.', TooLongNextStepTxt));
        ErrorEntries.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The header or the version does not exist.', RecordNextStepTxt));
        ErrorEntries.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The record cannot take the status for a reason other than a missing record or a failed line check. Closed is InvalidParameter, not this code.', AllowedStatusNextStepTxt));
        ErrorEntries.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, 'The request names a key other than no, versionCode or status.', 'Remove the unknown key.'));
        ErrorEntries.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MultipleErrors, 'Several of these problems were found in one call. errors lists each of them.', 'Correct every listed problem and send the request again.'));
        ErrorEntries.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Business Central refused the status change. The record is unchanged.', CheckFailedNextStepTxt));
        ErrorEntries.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller cannot read or write the manufacturing table.', PermissionNextStepTxt));
        ErrorEntries.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::Retryable, 'The call can be sent again after the data it names is corrected.', 'Correct the data and send the same request again.'));
    end;

    /// <summary>Builds the effect chapter. The effect is write and the call is idempotent.</summary>
    /// <param name="IsProductionBom">True for a production BOM.</param>
    /// <param name="EffectChapter">Receives the chapter.</param>
    internal procedure Effect(IsProductionBom: Boolean; var EffectChapter: JsonObject)
    var
        Preconditions: JsonArray;
    begin
        EffectChapter.Add('effect', 'write');
        if IsProductionBom then
            EffectChapter.Add('changes', 'Validates Status on the production BOM header or on one version. The header is then modified. A version modifies itself inside Business Central validation, and that commit is suppressed for this call. Lines are not written. The same status writes nothing.')
        else
            EffectChapter.Add('changes', 'Validates Status on the routing header or on one version. The header is then modified. A version modifies itself inside Business Central validation, and that commit is suppressed for this call. Lines are not written. The same status writes nothing.');
        EffectChapter.Add('idempotent', true);
        EffectChapter.Add('permissionSet', 'BIFROST Mfg ori');
        Preconditions.Add('The header already exists. This call does not create it.');
        Preconditions.Add('The caller can read and write the manufacturing tables, including Planning Assignment when certification writes it.');
        Preconditions.Add('status is Certified or UnderDevelopment.');
        EffectChapter.Add('preconditions', Preconditions);
    end;

    /// <summary>Builds the related chapter. Only message types that exist today are named.</summary>
    /// <param name="RelatedEntries">Receives the chapter.</param>
    internal procedure Related(var RelatedEntries: JsonArray)
    begin
        RelatedEntries.Add(ContractMgt.RelatedEntry('Data.Records.Set', 'Edit lines while the record is Under Development. Status on these four tables is refused there.'));
        RelatedEntries.Add(ContractMgt.RelatedEntry('Data.Records.Get', 'Read the header, the version and the lines before and after the change.'));
    end;

    /// <summary>Builds the workflow chapter.</summary>
    /// <param name="MessageType">The message type of this step.</param>
    /// <param name="WorkflowChapter">Receives the chapter.</param>
    internal procedure Workflow(MessageType: Text; var WorkflowChapter: JsonObject)
    var
        Steps: JsonArray;
    begin
        Steps.Add(ContractMgt.WorkflowStep('Data.Records.Set', 'Edit the lines while the record is Under Development.'));
        Steps.Add(ContractMgt.WorkflowStep(MessageType, 'Certify the header or one version, or return it to Under Development.'));
        Steps.Add(ContractMgt.WorkflowStep('Data.Records.Get', 'Read the status back.'));
        WorkflowChapter.Add('steps', Steps);
        WorkflowChapter.Add('text', 'Edit lines, certify, then read the status. Closing is not supported.');
    end;

    /// <summary>Builds one success example.</summary>
    /// <param name="MessageType">The message type name.</param>
    /// <param name="ExampleEntries">Receives the chapter.</param>
    internal procedure Examples(MessageType: Text; var ExampleEntries: JsonArray)
    begin
        if MessageType = 'Manufacturing.ProductionBOM.SetStatus' then
            ExampleEntries.Add(ContractMgt.Example('Certify a production BOM',
                '{"type":"Manufacturing.ProductionBOM.SetStatus","data":{"no":"BOM-100","status":"Certified"}}',
                '{"status":"Success","no":"BOM-100","versionCode":"","previousStatus":"UnderDevelopment","recordStatus":"Certified","changed":true,"lowLevelCode":0,"usedOnItems":1}'))
        else
            ExampleEntries.Add(ContractMgt.Example('Certify a routing',
                '{"type":"Manufacturing.Routing.SetStatus","data":{"no":"RT-100","status":"Certified"}}',
                '{"status":"Success","no":"RT-100","versionCode":"","previousStatus":"New","recordStatus":"Certified","changed":true,"usedOnItems":1}'));
    end;

    /// <summary>Overview text. English only, as a help chapter.</summary>
    /// <param name="IsProductionBom">True for a production BOM.</param>
    /// <returns>The overview.</returns>
    internal procedure Overview(IsProductionBom: Boolean): Text
    begin
        if IsProductionBom then
            exit('Certifies a production BOM header or one of its versions, or sets it back to Under Development, after the standard Business Central checks. ' +
                'Send no and status. Send versionCode only when one version should change. Closing is not supported.');
        exit('Certifies a routing header or one of its versions, or sets it back to Under Development, after the standard Business Central checks. ' +
            'Send no and status. Send versionCode only when one version should change. Closing is not supported.');
    end;

    /// <summary>Notes text. English only, as a help chapter. Names why Closed is refused.</summary>
    /// <returns>The notes.</returns>
    internal procedure Notes(): Text
    begin
        exit('Closed is not supported. Closing asks a question that cannot be answered without a screen, so Business Central would silently keep the old status. ' +
            'New is not a target status either. The same status again succeeds and writes nothing. ' +
            'The version status commit is suppressed only while this call runs, and the scoped subscription is released on success and on error. ' +
            'A generic Data.Records.Set of Status on the header and version tables is refused. Foundation answers that refusal with PermissionDenied and a nextStep that names this message type. ' +
            'The answer uses status Success and recordStatus for the record status, because Foundation reserves status for the outcome. ' +
            'lowLevelCode and usedOnItems are returned for the header only.');
    end;

    local procedure CollectUnknownKeys(var Argument: Record "Message Argument ori"; RequestJson: JsonObject)
    var
        Keys: List of [Text];
        ParameterKey: Text;
    begin
        Keys := RequestJson.Keys();
        foreach ParameterKey in Keys do
            if not (ParameterKey in ['no', 'versionCode', 'status']) then
                Argument.AddError("Bifrost Error Code ori"::UnknownParameter, StrSubstNo(UnknownParameterErr, ParameterKey), ParameterKey, ParameterKey, DeclaredParameterTxt, StrSubstNo(UnknownNextStepTxt, ParameterKey));
    end;

    local procedure AddMissing(var Argument: Record "Message Argument ori"; ParameterName: Text)
    begin
        Argument.AddError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(MissingParameterErr, ParameterName), ParameterName, '', ParameterName, MissingNextStepTxt);
    end;

    local procedure ReadRequiredCode(var Argument: Record "Message Argument ori"; Token: JsonToken; ParameterName: Text; var Value: Code[20])
    var
        Raw: Text;
    begin
        if not TryReadText(Token, Raw) then begin
            Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(NotACodeErr, ParameterName), ParameterName, '', CodeExpectedTxt, TooLongNextStepTxt);
            exit;
        end;
        if Raw.Trim() = '' then begin
            AddMissing(Argument, ParameterName);
            exit;
        end;
        if StrLen(Raw) > MaxStrLen(Value) then begin
            Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(TooLongErr, ParameterName, MaxStrLen(Value)), ParameterName, Raw, CodeExpectedTxt, TooLongNextStepTxt);
            exit;
        end;
        Value := CopyStr(Raw, 1, MaxStrLen(Value));
    end;

    local procedure ReadOptionalCode(var Argument: Record "Message Argument ori"; Token: JsonToken; ParameterName: Text; var Value: Code[20])
    var
        Raw: Text;
    begin
        if not TryReadText(Token, Raw) then begin
            Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(NotACodeErr, ParameterName), ParameterName, '', CodeExpectedTxt, TooLongNextStepTxt);
            exit;
        end;
        if Raw.Trim() = '' then
            exit;
        if StrLen(Raw) > MaxStrLen(Value) then begin
            Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(TooLongErr, ParameterName, MaxStrLen(Value)), ParameterName, Raw, CodeExpectedTxt, TooLongNextStepTxt);
            exit;
        end;
        Value := CopyStr(Raw, 1, MaxStrLen(Value));
    end;

    local procedure ReadStatus(var Argument: Record "Message Argument ori"; Token: JsonToken; var StatusToken: Text)
    var
        Raw: Text;
        Normalized: Text;
        NextStep: Text;
    begin
        if not TryReadText(Token, Raw) then begin
            Argument.AddError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(StatusNotSupportedErr, Raw), 'status', '', StatusExpectedTxt, AllowedStatusNextStepTxt);
            exit;
        end;
        if Raw.Trim() = '' then begin
            AddMissing(Argument, 'status');
            exit;
        end;
        Normalized := LowerCase(DelChr(Raw, '=', ' '));
        if Normalized = LowerCase(CertifiedTok) then begin
            StatusToken := CertifiedTok;
            exit;
        end;
        if Normalized = LowerCase(UnderDevelopmentTok) then begin
            StatusToken := UnderDevelopmentTok;
            exit;
        end;
        if Normalized = LowerCase(ClosedTok) then
            NextStep := ClosedReasonTxt + ' ' + AllowedStatusNextStepTxt
        else
            NextStep := AllowedStatusNextStepTxt;
        Argument.AddError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(StatusNotSupportedErr, Raw.Trim()), 'status', Raw.Trim(), StatusExpectedTxt, NextStep);
    end;

    local procedure TryReadText(Token: JsonToken; var Raw: Text): Boolean
    begin
        Raw := '';
        if not Token.IsValue() then
            exit(false);
        if Token.AsValue().IsNull() then
            exit(false);
        Raw := Token.AsValue().AsText();
        exit(true);
    end;

}
