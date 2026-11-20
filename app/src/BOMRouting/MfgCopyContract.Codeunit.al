namespace Origo.Bifrost.Manufacturing;

using Microsoft.Manufacturing.ProductionBOM;
using Microsoft.Manufacturing.Routing;
using Origo.Bifrost;

/// <summary>
/// Request reading, success writing and help chapters for
/// Manufacturing.ProductionBOM.CopyVersion and Manufacturing.Routing.CopyVersion.
/// The call creates one new version and copies into it. It never deletes an existing line.
/// </summary>
codeunit 10077098 "Mfg Copy Contract ori"
{
    Access = Internal;

    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        UnderDevelopmentTok: Label 'UnderDevelopment', Locked = true;
        SeveralProblemsErr: Label 'The request has more than one problem. Nothing was changed.', Comment = 'is-IS=Beiðnin hefur fleiri en eitt vandamál. Engu var breytt.';
        MissingParameterErr: Label 'Parameter %1 is required.', Comment = '%1 = parameter name, is-IS=Færibreyta %1 er nauðsynleg.';
        MissingNextStepTxt: Label 'Send no or systemId, and startingDate as yyyy-mm-dd.', Comment = 'is-IS=Sendu no eða systemId, og startingDate á forminu yyyy-mm-dd.';
        UnknownParameterErr: Label 'Parameter %1 is not accepted here.', Comment = '%1 = parameter name, is-IS=Færibreyta %1 er ekki tekin gild hér.';
        UnknownNextStepTxt: Label 'Remove %1 from the request.', Comment = '%1 = parameter name, is-IS=Fjarlægðu %1 úr beiðninni.';
        TooLongErr: Label 'Parameter %1 is longer than %2 characters.', Comment = '%1 = parameter name, %2 = maximum length, is-IS=Færibreyta %1 er lengri en %2 stafir.';
        TooLongNextStepTxt: Label 'Send a shorter value.', Comment = 'is-IS=Sendu styttra gildi.';
        NotACodeErr: Label 'Parameter %1 must be text of at most %2 characters.', Comment = '%1 = parameter name, %2 = maximum length, is-IS=Færibreyta %1 verður að vera texti sem er í mesta lagi %2 stafir.';
        DateFormatErr: Label 'Parameter startingDate must be a date in the form yyyy-mm-dd.', Comment = 'is-IS=Færibreytan startingDate verður að vera dagsetning á forminu yyyy-mm-dd.';
        GuidFormatErr: Label 'Parameter systemId must be a GUID.', Comment = 'is-IS=Færibreytan systemId verður að vera GUID.';
        CodeExpectedTxt: Label 'text of at most 20 characters', Comment = 'is-IS=texti sem er í mesta lagi 20 stafir';
        DateExpectedTxt: Label 'yyyy-mm-dd', Locked = true;
        GuidExpectedTxt: Label 'a GUID', Comment = 'is-IS=GUID';
        DescriptionExpectedTxt: Label 'text of at most 100 characters', Comment = 'is-IS=texti sem er í mesta lagi 100 stafir';
        DeclaredParameterTxt: Label 'a parameter this request declares', Comment = 'is-IS=færibreyta sem þessi beiðni skilgreinir';
        RecordNotFoundErr: Label '%1 %2 was not found.', Comment = '%1 = production BOM or routing, %2 = number, is-IS=%1 %2 fannst ekki.';
        RecordNextStepTxt: Label 'Read the records with Data.Records.Get.', Comment = 'is-IS=Lestu færslurnar með Data.Records.Get.';
        VersionMissingErr: Label 'Version %1 of %2 %3 was not found.', Comment = '%1 = version code, %2 = production BOM or routing, %3 = number, is-IS=Útgáfa %1 af %2 %3 fannst ekki.';
        VersionMissingNextStepTxt: Label 'Read the versions with Data.Records.Get and send a sourceVersionCode that exists, or omit it to copy the header.', Comment = 'is-IS=Lestu útgáfurnar með Data.Records.Get og sendu sourceVersionCode sem er til, eða slepptu henni til að afrita hausinn.';
        ExistingVersionTxt: Label 'an existing version', Comment = 'is-IS=útgáfa sem er til';
        SystemIdNotFoundErr: Label 'No %1 has systemId %2.', Comment = '%1 = production BOM or routing, %2 = system id, is-IS=Ekkert %1 er með systemId %2.';
        ConflictErr: Label 'no and systemId name different records. Nothing was changed.', Comment = 'is-IS=no og systemId nefna mismunandi færslur. Engu var breytt.';
        ConflictNextStepTxt: Label 'Send no and systemId of the same record, or send only one of them.', Comment = 'is-IS=Sendu no og systemId sömu færslu, eða sendu aðeins annað hvort.';
        SameVersionErr: Label 'The source version and the target version are the same. Nothing was copied.', Comment = 'is-IS=Upprunaútgáfan og markútgáfan eru sú sama. Engu var afritað.';
        SameVersionNextStepTxt: Label 'Send a different targetVersionCode, or omit it to create the next version.', Comment = 'is-IS=Sendu annað targetVersionCode, eða slepptu því til að búa til næstu útgáfu.';
        ExistsErr: Label 'Version %1 of %2 %3 already exists. Nothing was copied and no line was removed.', Comment = '%1 = version code, %2 = production BOM or routing, %3 = number, is-IS=Útgáfa %1 af %2 %3 er þegar til. Engu var afritað og engin lína var fjarlægð.';
        ExistsNextStepTxt: Label 'Send a new targetVersionCode, or omit it to take the next number from Version Nos.', Comment = 'is-IS=Sendu nýtt targetVersionCode, eða slepptu því til að taka næsta númer úr Version Nos.';
        VersionNosErr: Label 'Version Nos. is empty on %1 %2, so the next version code cannot be chosen. Nothing was copied.', Comment = '%1 = production BOM or routing, %2 = number, is-IS=Version Nos. er autt á %1 %2, svo ekki er hægt að velja næsta útgáfunúmer. Engu var afritað.';
        VersionNosNextStepTxt: Label 'Send targetVersionCode, or set Version Nos. on the header with Data.Records.Set and send the request again.', Comment = 'is-IS=Sendu targetVersionCode, eða settu Version Nos. á hausinn með Data.Records.Set og sendu beiðnina aftur.';
        CopyFailedNextStepTxt: Label 'Correct the data and send the request again. An existing version is left unchanged.', Comment = 'is-IS=Lagfærðu gögnin og sendu beiðnina aftur. Útgáfa sem er þegar til er óbreytt.';
        UnitOfMeasureNextStepTxt: Label 'Use a unit of measure that exists for the component, then send the request again.', Comment = 'is-IS=Notaðu mælieiningu sem er til fyrir íhlutinn og sendu beiðnina aftur.';
        PermissionDeniedErr: Label 'You do not have permission to change this %1.', Comment = '%1 = production BOM or routing, is-IS=Þú hefur ekki heimild til að breyta þessu %1.';
        PermissionExpectedTxt: Label 'read and write permission on the manufacturing tables', Comment = 'is-IS=les- og skrifheimild á framleiðslutöflunum';
        PermissionNextStepTxt: Label 'Ask for BIFROST Full ori and the manufacturing table permissions, then send the same request again.', Comment = 'is-IS=Biddu um BIFROST Full ori og heimildir á framleiðslutöflunum og sendu sömu beiðni aftur.';
        ProductionBomKindLbl: Label 'production BOM', Comment = 'is-IS=framleiðsluefnislisti';
        RoutingKindLbl: Label 'routing', Comment = 'is-IS=vinnsluleið';
        BomCertifyNextStepTxt: Label 'Certify the new version with Manufacturing.ProductionBOM.SetStatus.', Comment = 'is-IS=Staðfestu nýju útgáfuna með Manufacturing.ProductionBOM.SetStatus.';
        RoutingCertifyNextStepTxt: Label 'Certify the new version with Manufacturing.Routing.SetStatus.', Comment = 'is-IS=Staðfestu nýju útgáfuna með Manufacturing.Routing.SetStatus.';
        SameRecordExpectedTxt: Label 'the same record', Comment = 'is-IS=sama færslan';
        DifferentVersionExpectedTxt: Label 'a different version', Comment = 'is-IS=önnur útgáfa';
        NewVersionExpectedTxt: Label 'a new version code', Comment = 'is-IS=nýtt útgáfunúmer';
        VersionNosExpectedTxt: Label 'Version Nos. or targetVersionCode', Comment = 'is-IS=Version Nos. eða targetVersionCode';

    /// <summary>Reads the copy request and collects every problem.</summary>
    /// <param name="Argument">The message argument.</param>
    /// <param name="DocumentNo">Receives the header number when no was sent.</param>
    /// <param name="SystemId">Receives the header system id when systemId was sent.</param>
    /// <param name="HasSystemId">True when a systemId was sent.</param>
    /// <param name="SourceVersionCode">Receives the source version, or blank for the header lines.</param>
    /// <param name="TargetVersionCode">Receives the requested new version code.</param>
    /// <param name="HasTarget">True when a non-blank targetVersionCode was sent.</param>
    /// <param name="StartingDate">Receives the starting date of the new version.</param>
    /// <param name="Description">Receives the description when one was sent.</param>
    /// <param name="HasDescription">True when a non-blank description was sent.</param>
    /// <returns>True when the request can be applied.</returns>
    internal procedure ReadCopyRequest(var Argument: Record "Message Argument ori"; var DocumentNo: Code[20]; var SystemId: Guid; var HasSystemId: Boolean; var SourceVersionCode: Code[20]; var TargetVersionCode: Code[20]; var HasTarget: Boolean; var StartingDate: Date; var Description: Text; var HasDescription: Boolean): Boolean
    var
        RequestJson: JsonObject;
        Token: JsonToken;
        NoRejected: Boolean;
    begin
        RequestJson := Argument.GetRequestJson();
        CollectUnknownKeys(Argument, RequestJson);
        DocumentNo := '';
        Clear(SystemId);
        HasSystemId := false;
        SourceVersionCode := '';
        TargetVersionCode := '';
        HasTarget := false;
        StartingDate := 0D;
        Description := '';
        HasDescription := false;

        if RequestJson.Get('no', Token) then
            if not ReadCode(Argument, Token, 'no', DocumentNo, true) then
                NoRejected := true;
        if RequestJson.Get('systemId', Token) then
            HasSystemId := ReadSystemId(Argument, Token, SystemId);
        if (DocumentNo = '') and (not HasSystemId) and (not NoRejected) then
            AddMissing(Argument, 'no');

        if RequestJson.Get('sourceVersionCode', Token) then
            ReadCode(Argument, Token, 'sourceVersionCode', SourceVersionCode, true);
        if RequestJson.Get('targetVersionCode', Token) then begin
            ReadCode(Argument, Token, 'targetVersionCode', TargetVersionCode, true);
            HasTarget := TargetVersionCode <> '';
        end;
        if RequestJson.Get('description', Token) then
            HasDescription := ReadDescription(Argument, Token, Description);

        if not RequestJson.Get('startingDate', Token) then
            AddMissing(Argument, 'startingDate')
        else
            ReadStartingDate(Argument, Token, StartingDate);

        exit(not Argument.HasCollectedErrors());
    end;

    /// <summary>Responds with the errors collected before any write.</summary>
    /// <param name="Argument">The message argument that holds the collected errors.</param>
    internal procedure RaiseCollected(var Argument: Record "Message Argument ori")
    begin
        Argument.RespondWithCollectedErrors("Bifrost Error Code ori"::MultipleErrors, SeveralProblemsErr);
    end;

    /// <summary>Refuses the call when the caller cannot read and write the record.</summary>
    /// <param name="Argument">The message argument.</param>
    /// <param name="Kind">production BOM or routing, already translated.</param>
    /// <param name="CanRead">True when the caller can read the tables.</param>
    /// <param name="CanWrite">True when the caller can write the tables.</param>
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

    /// <summary>Answers that the system id does not exist.</summary>
    /// <param name="Argument">The message argument.</param>
    /// <param name="Kind">production BOM or routing.</param>
    /// <param name="SystemId">The system id that was not found.</param>
    internal procedure FailSystemIdNotFound(var Argument: Record "Message Argument ori"; Kind: Text; SystemId: Guid)
    begin
        Argument.AddError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(SystemIdNotFoundErr, Kind, Format(SystemId, 0, 4)), 'systemId', Format(SystemId, 0, 4), Kind, RecordNextStepTxt);
        RaiseCollected(Argument);
    end;

    /// <summary>Answers that the source version does not exist.</summary>
    /// <param name="Argument">The message argument.</param>
    /// <param name="Kind">production BOM or routing.</param>
    /// <param name="DocumentNo">The header number.</param>
    /// <param name="VersionCode">The source version code that was not found.</param>
    internal procedure FailSourceVersionNotFound(var Argument: Record "Message Argument ori"; Kind: Text; DocumentNo: Code[20]; VersionCode: Code[20])
    begin
        Argument.AddError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(VersionMissingErr, VersionCode, Kind, DocumentNo), 'sourceVersionCode', VersionCode, ExistingVersionTxt, VersionMissingNextStepTxt);
        RaiseCollected(Argument);
    end;

    /// <summary>Answers that no and systemId name different records.</summary>
    /// <param name="Argument">The message argument.</param>
    internal procedure FailIdentifierConflict(var Argument: Record "Message Argument ori")
    begin
        Argument.AddError("Bifrost Error Code ori"::ConflictingIdentifiers, ConflictErr, 'no', '', SameRecordExpectedTxt, ConflictNextStepTxt);
        RaiseCollected(Argument);
    end;

    /// <summary>Answers that the source version and the target version are the same code.</summary>
    /// <param name="Argument">The message argument.</param>
    /// <param name="VersionCode">The code that was sent as both source and target.</param>
    internal procedure FailSameVersion(var Argument: Record "Message Argument ori"; VersionCode: Code[20])
    begin
        Argument.AddError("Bifrost Error Code ori"::ConflictingIdentifiers, SameVersionErr, 'targetVersionCode', VersionCode, DifferentVersionExpectedTxt, SameVersionNextStepTxt);
        RaiseCollected(Argument);
    end;

    /// <summary>Raises the same-version refusal so a failed run rolls the new version back.</summary>
    internal procedure ErrorSameVersion()
    begin
        Error(SameVersionErr);
    end;

    /// <summary>Answers that the target version already exists, so nothing may be deleted or copied.</summary>
    /// <param name="Argument">The message argument.</param>
    /// <param name="Kind">production BOM or routing.</param>
    /// <param name="DocumentNo">The header number.</param>
    /// <param name="VersionCode">The version code that already exists.</param>
    internal procedure FailTargetExists(var Argument: Record "Message Argument ori"; Kind: Text; DocumentNo: Code[20]; VersionCode: Code[20])
    begin
        Argument.AddError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(ExistsErr, VersionCode, Kind, DocumentNo), 'targetVersionCode', VersionCode, NewVersionExpectedTxt, ExistsNextStepTxt);
        RaiseCollected(Argument);
    end;

    /// <summary>Answers that the next version code cannot be taken because Version Nos. is empty.</summary>
    /// <param name="Argument">The message argument.</param>
    /// <param name="Kind">production BOM or routing.</param>
    /// <param name="DocumentNo">The header number.</param>
    internal procedure FailVersionNos(var Argument: Record "Message Argument ori"; Kind: Text; DocumentNo: Code[20])
    begin
        Argument.AddError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(VersionNosErr, Kind, DocumentNo), 'targetVersionCode', '', VersionNosExpectedTxt, VersionNosNextStepTxt);
        RaiseCollected(Argument);
    end;

    /// <summary>
    /// Keeps Foundation's platform error and turns a known copy refusal into its stable code.
    /// A unit-of-measure refusal from Business Central is PreconditionFailed. Copying a version onto itself is ConflictingIdentifiers.
    /// </summary>
    /// <param name="Argument">The message argument immediately after a failed Codeunit.Run.</param>
    internal procedure RespondWithCopyError(var Argument: Record "Message Argument ori")
    var
        ResponseJson: JsonObject;
        ErrorToken: JsonToken;
        PlatformError: Text;
    begin
        Argument.RespondWithLastError();
        ResponseJson := Argument.GetResponseJson();
        if not ResponseJson.Get('error', ErrorToken) then
            exit;
        PlatformError := ErrorToken.AsValue().AsText();
        if IsSameVersionText(PlatformError) then
            ReplaceOutcome(ResponseJson, 'ConflictingIdentifiers', SameVersionNextStepTxt)
        else
            if IsUnitOfMeasureText(PlatformError) then
                ReplaceOutcome(ResponseJson, 'PreconditionFailed', UnitOfMeasureNextStepTxt)
            else
                ReplaceOutcome(ResponseJson, '', CopyFailedNextStepTxt);
        Argument.SetResponseJson(ResponseJson);
    end;

    /// <summary>Writes the success answer. Routing counts are omitted for a production BOM.</summary>
    /// <param name="Argument">The message argument.</param>
    /// <param name="IsRouting">True for a routing.</param>
    /// <param name="DocumentNo">The header number.</param>
    /// <param name="VersionCode">The new version code.</param>
    /// <param name="StartingDate">The starting date stored on the version.</param>
    /// <param name="LineCount">Lines copied onto the version.</param>
    /// <param name="ToolCount">Routing tools copied. Ignored for a production BOM.</param>
    /// <param name="PersonnelCount">Routing personnel copied. Ignored for a production BOM.</param>
    /// <param name="QualityMeasureCount">Routing quality measures copied. Ignored for a production BOM.</param>
    /// <param name="CommentCount">Routing comments copied. Ignored for a production BOM.</param>
    internal procedure WriteCopySuccess(var Argument: Record "Message Argument ori"; IsRouting: Boolean; DocumentNo: Code[20]; VersionCode: Code[20]; StartingDate: Date; LineCount: Integer; ToolCount: Integer; PersonnelCount: Integer; QualityMeasureCount: Integer; CommentCount: Integer)
    var
        ResponseJson: JsonObject;
    begin
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('no', DocumentNo);
        ResponseJson.Add('versionCode', VersionCode);
        ResponseJson.Add('recordStatus', UnderDevelopmentTok);
        ResponseJson.Add('startingDate', Format(StartingDate, 0, 9));
        ResponseJson.Add('lineCount', LineCount);
        if IsRouting then begin
            ResponseJson.Add('toolCount', ToolCount);
            ResponseJson.Add('personnelCount', PersonnelCount);
            ResponseJson.Add('qualityMeasureCount', QualityMeasureCount);
            ResponseJson.Add('commentCount', CommentCount);
            ResponseJson.Add('nextStep', RoutingCertifyNextStepTxt);
        end else
            ResponseJson.Add('nextStep', BomCertifyNextStepTxt);
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

    /// <summary>Builds the envelope. The subject is not read.</summary>
    /// <param name="EnvelopeChapter">Receives the chapter.</param>
    internal procedure Envelope(var EnvelopeChapter: JsonObject)
    var
        Subject: JsonObject;
    begin
        Subject.Add('use', 'notUsed');
        Subject.Add('description', 'The subject is not read. Send no or systemId, and startingDate, under data.');
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
        if IsProductionBom then begin
            TargetEntries.Add(ContractMgt.TargetEntry('data.no', 'production BOM no.', 'The production BOM to copy. Required unless systemId is sent. Both must name the same record.'));
            TargetEntries.Add(ContractMgt.TargetEntry('data.systemId', 'guid', 'The production BOM system id. Required unless no is sent.'));
        end else begin
            TargetEntries.Add(ContractMgt.TargetEntry('data.no', 'routing no.', 'The routing to copy. Required unless systemId is sent. Both must name the same record.'));
            TargetEntries.Add(ContractMgt.TargetEntry('data.systemId', 'guid', 'The routing system id. Required unless no is sent.'));
        end;
        TargetEntries.Add(ContractMgt.TargetEntry('data.sourceVersionCode', 'version code', 'The version to copy. Omit it, or send it blank, to copy the header lines.'));
        TargetEntries.Add(ContractMgt.TargetEntry('data.targetVersionCode', 'version code', 'The new version code. Omit it to take the next number from Version Nos. on the header. An existing code is refused.'));
    end;

    /// <summary>Builds the parameters chapter.</summary>
    /// <param name="IsProductionBom">True for a production BOM.</param>
    /// <param name="ParameterEntries">Receives the chapter.</param>
    internal procedure Parameters(IsProductionBom: Boolean; var ParameterEntries: JsonArray)
    begin
        if IsProductionBom then
            ParameterEntries.Add(ContractMgt.Parameter('no', 'string', false, 'The production BOM number. Required unless systemId is sent.'))
        else
            ParameterEntries.Add(ContractMgt.Parameter('no', 'string', false, 'The routing number. Required unless systemId is sent.'));
        ParameterEntries.Add(ContractMgt.Parameter('systemId', 'string', false, 'The header system id. Required unless no is sent. When both are sent they must name the same record.'));
        ParameterEntries.Add(ContractMgt.Parameter('sourceVersionCode', 'string', false, 'The version to copy. Omit it to copy the lines of the header.'));
        ParameterEntries.Add(ContractMgt.Parameter('targetVersionCode', 'string', false, 'The code of the new version. Omit it to take the next number from Version Nos. A code that already exists is refused.'));
        ParameterEntries.Add(ContractMgt.Parameter('startingDate', 'string', true, 'The starting date of the new version, as yyyy-mm-dd. After certification, a production order on or after this date uses the version.'));
        ParameterEntries.Add(ContractMgt.Parameter('description', 'string', false, 'The description of the new version. Omit it to keep the description of the source.'));
    end;

    /// <summary>Builds the response chapter.</summary>
    /// <param name="IsProductionBom">True for a production BOM.</param>
    /// <param name="ResponseChapter">Receives the chapter.</param>
    internal procedure Response(IsProductionBom: Boolean; var ResponseChapter: JsonObject)
    var
        Fields: JsonArray;
    begin
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success. This is the outcome of the call, not the version status.'));
        Fields.Add(ContractMgt.ResponseField('no', 'string', 'The production BOM or routing number.'));
        Fields.Add(ContractMgt.ResponseField('versionCode', 'string', 'The new version code.'));
        Fields.Add(ContractMgt.ResponseField('recordStatus', 'string', 'UnderDevelopment. The version is not certified by this call.'));
        Fields.Add(ContractMgt.ResponseField('startingDate', 'string', 'The starting date stored on the version, as yyyy-mm-dd.'));
        Fields.Add(ContractMgt.ResponseField('lineCount', 'integer', 'Lines on the new version. The count matches the source.'));
        if not IsProductionBom then begin
            Fields.Add(ContractMgt.ResponseField('toolCount', 'integer', 'Tools on the new version.'));
            Fields.Add(ContractMgt.ResponseField('personnelCount', 'integer', 'Personnel rows on the new version.'));
            Fields.Add(ContractMgt.ResponseField('qualityMeasureCount', 'integer', 'Quality measures on the new version.'));
            Fields.Add(ContractMgt.ResponseField('commentCount', 'integer', 'Comments on the new version.'));
        end;
        Fields.Add(ContractMgt.ResponseField('nextStep', 'string', 'Certify the new version when the engineering change is ready.'));
        ResponseChapter.Add('fields', Fields);
    end;

    /// <summary>Builds the errors chapter, including Retryable.</summary>
    /// <param name="ErrorEntries">Receives the chapter.</param>
    internal procedure Errors(var ErrorEntries: JsonArray)
    begin
        ErrorEntries.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'no and systemId are both missing, or startingDate is missing or blank.', MissingNextStepTxt));
        ErrorEntries.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'no, systemId, a version code, startingDate or description has the wrong type or is too long.', TooLongNextStepTxt));
        ErrorEntries.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, 'The request names a key other than no, systemId, sourceVersionCode, targetVersionCode, startingDate or description.', 'Remove the unknown key.'));
        ErrorEntries.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The header or the source version does not exist.', RecordNextStepTxt));
        ErrorEntries.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, 'no and systemId name different records, or the source version and the target version are the same code.', ConflictNextStepTxt));
        ErrorEntries.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The target version already exists, Version Nos. is empty and no target code was sent, or Business Central refuses a unit of measure. No existing line is removed.', ExistsNextStepTxt));
        ErrorEntries.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller cannot read or write the manufacturing tables.', PermissionNextStepTxt));
        ErrorEntries.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MultipleErrors, 'Several of these problems were found in one call. errors lists each of them.', 'Correct every listed problem and send the request again.'));
        ErrorEntries.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Business Central refused the copy for another reason. The new version is not kept.', CopyFailedNextStepTxt));
        ErrorEntries.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::Retryable, 'The call can be sent again after the data it names is corrected.', 'Correct the data and send the same request again.'));
    end;

    /// <summary>Builds the effect chapter. The call commits and is not idempotent.</summary>
    /// <param name="IsProductionBom">True for a production BOM.</param>
    /// <param name="EffectChapter">Receives the chapter.</param>
    internal procedure Effect(IsProductionBom: Boolean; var EffectChapter: JsonObject)
    var
        Preconditions: JsonArray;
    begin
        EffectChapter.Add('effect', 'write');
        if IsProductionBom then
            EffectChapter.Add('changes', 'Creates one new production BOM version on the same production BOM and copies the source lines and comments into it. The version is left Under Development. Lines of every existing version stay as they are.')
        else
            EffectChapter.Add('changes', 'Creates one new routing version on the same routing and copies the source lines, tools, personnel, quality measures and comments into it. The version is left Under Development. Lines of every existing version stay as they are.');
        EffectChapter.Add('idempotent', false);
        EffectChapter.Add('permissionSet', 'BIFROST Mfg ori');
        Preconditions.Add('The header already exists. This call does not create it and does not copy onto another number.');
        Preconditions.Add('The target version does not exist. Business Central would otherwise delete the lines of that version before copying, and this call refuses that path.');
        Preconditions.Add('When targetVersionCode is omitted, Version Nos. on the header can issue the next code.');
        Preconditions.Add('The caller can read and write the manufacturing tables.');
        EffectChapter.Add('preconditions', Preconditions);
    end;

    /// <summary>Builds the related chapter.</summary>
    /// <param name="IsProductionBom">True for a production BOM.</param>
    /// <param name="RelatedEntries">Receives the chapter.</param>
    internal procedure Related(IsProductionBom: Boolean; var RelatedEntries: JsonArray)
    begin
        RelatedEntries.Add(ContractMgt.RelatedEntry('Data.Records.Get', 'Read the header, the versions and the lines before and after the copy.'));
        RelatedEntries.Add(ContractMgt.RelatedEntry('Data.Records.Set', 'Edit the new version while it is Under Development. Status on these tables is refused there.'));
        if IsProductionBom then
            RelatedEntries.Add(ContractMgt.RelatedEntry('Manufacturing.ProductionBOM.SetStatus', 'Certify the new version, or return it to Under Development.'))
        else
            RelatedEntries.Add(ContractMgt.RelatedEntry('Manufacturing.Routing.SetStatus', 'Certify the new version, or return it to Under Development.'));
    end;

    /// <summary>Builds the workflow chapter.</summary>
    /// <param name="IsProductionBom">True for a production BOM.</param>
    /// <param name="WorkflowChapter">Receives the chapter.</param>
    internal procedure Workflow(IsProductionBom: Boolean; var WorkflowChapter: JsonObject)
    var
        Steps: JsonArray;
    begin
        if IsProductionBom then begin
            Steps.Add(ContractMgt.WorkflowStep('Manufacturing.ProductionBOM.CopyVersion', 'Copy the header or one version into a new version.'));
            Steps.Add(ContractMgt.WorkflowStep('Data.Records.Set', 'Edit the new version while it is Under Development.'));
            Steps.Add(ContractMgt.WorkflowStep('Manufacturing.ProductionBOM.SetStatus', 'Certify the new version.'));
        end else begin
            Steps.Add(ContractMgt.WorkflowStep('Manufacturing.Routing.CopyVersion', 'Copy the header or one version into a new version.'));
            Steps.Add(ContractMgt.WorkflowStep('Data.Records.Set', 'Edit the new version while it is Under Development.'));
            Steps.Add(ContractMgt.WorkflowStep('Manufacturing.Routing.SetStatus', 'Certify the new version.'));
        end;
        WorkflowChapter.Add('steps', Steps);
        WorkflowChapter.Add('text', 'Copy into a new version, edit it, then certify it. Nothing that already exists is deleted.');
    end;

    /// <summary>Builds one success example.</summary>
    /// <param name="IsProductionBom">True for a production BOM.</param>
    /// <param name="ExampleEntries">Receives the chapter.</param>
    internal procedure Examples(IsProductionBom: Boolean; var ExampleEntries: JsonArray)
    begin
        if IsProductionBom then
            ExampleEntries.Add(ContractMgt.Example('Copy a certified production BOM into the next version',
                '{"type":"Manufacturing.ProductionBOM.CopyVersion","data":{"no":"BOM-100","startingDate":"2020-01-01"}}',
                '{"status":"Success","no":"BOM-100","versionCode":"V-001","recordStatus":"UnderDevelopment","startingDate":"2020-01-01","lineCount":2,"nextStep":"Certify the new version with Manufacturing.ProductionBOM.SetStatus."}'))
        else
            ExampleEntries.Add(ContractMgt.Example('Copy a certified routing into the next version',
                '{"type":"Manufacturing.Routing.CopyVersion","data":{"no":"RT-100","startingDate":"2020-01-01"}}',
                '{"status":"Success","no":"RT-100","versionCode":"V-001","recordStatus":"UnderDevelopment","startingDate":"2020-01-01","lineCount":1,"toolCount":1,"personnelCount":1,"qualityMeasureCount":1,"commentCount":1,"nextStep":"Certify the new version with Manufacturing.Routing.SetStatus."}'));
    end;

    /// <summary>Overview text. English only.</summary>
    /// <param name="IsProductionBom">True for a production BOM.</param>
    /// <returns>The overview.</returns>
    internal procedure Overview(IsProductionBom: Boolean): Text
    begin
        if IsProductionBom then
            exit('Copies the lines of a production BOM header, or of one of its versions, into a new version on the same production BOM. ' +
                'The new version is Under Development. Send no or systemId, and startingDate. ' +
                'Omit targetVersionCode to take the next number from Version Nos. An existing target is refused, so no line that already exists is removed.');
        exit('Copies the lines, tools, personnel, quality measures and comments of a routing header, or of one of its versions, into a new version on the same routing. ' +
            'The new version is Under Development. Send no or systemId, and startingDate. ' +
            'Omit targetVersionCode to take the next number from Version Nos. An existing target is refused, so no line that already exists is removed.');
    end;

    /// <summary>Notes text. English only.</summary>
    /// <returns>The notes.</returns>
    internal procedure Notes(): Text
    begin
        exit('The copy always creates a new empty version and then copies into it. Business Central deletes the lines of the target before it copies, so a target that already exists is refused and nothing is deleted. ' +
            'Copying onto another production BOM or routing number is not supported. The source version and the target version cannot be the same code. ' +
            'A unit of measure that Business Central refuses is returned as PreconditionFailed and the new version is not kept. ' +
            'The answer uses status Success and recordStatus UnderDevelopment, because status is reserved for the outcome of the call. ' +
            'Certify the new version afterwards. A read-only caller is refused.');
    end;

    local procedure CollectUnknownKeys(var Argument: Record "Message Argument ori"; RequestJson: JsonObject)
    var
        Keys: List of [Text];
        ParameterKey: Text;
    begin
        Keys := RequestJson.Keys();
        foreach ParameterKey in Keys do
            if not (ParameterKey in ['no', 'systemId', 'sourceVersionCode', 'targetVersionCode', 'startingDate', 'description']) then
                Argument.AddError("Bifrost Error Code ori"::UnknownParameter, StrSubstNo(UnknownParameterErr, ParameterKey), ParameterKey, ParameterKey, DeclaredParameterTxt, StrSubstNo(UnknownNextStepTxt, ParameterKey));
    end;

    local procedure AddMissing(var Argument: Record "Message Argument ori"; ParameterName: Text)
    begin
        Argument.AddError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(MissingParameterErr, ParameterName), ParameterName, '', ParameterName, MissingNextStepTxt);
    end;

    local procedure ReadCode(var Argument: Record "Message Argument ori"; Token: JsonToken; ParameterName: Text; var Value: Code[20]; Optional: Boolean): Boolean
    var
        Raw: Text;
    begin
        if not TryReadText(Token, Raw) then begin
            Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(NotACodeErr, ParameterName, MaxStrLen(Value)), ParameterName, '', CodeExpectedTxt, TooLongNextStepTxt);
            exit(false);
        end;
        Raw := Raw.Trim();
        if Raw = '' then begin
            if not Optional then
                AddMissing(Argument, ParameterName);
            exit(Optional);
        end;
        if StrLen(Raw) > MaxStrLen(Value) then begin
            Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(TooLongErr, ParameterName, MaxStrLen(Value)), ParameterName, Raw, CodeExpectedTxt, TooLongNextStepTxt);
            exit(false);
        end;
        Value := CopyStr(Raw, 1, MaxStrLen(Value));
        exit(true);
    end;

    local procedure ReadSystemId(var Argument: Record "Message Argument ori"; Token: JsonToken; var SystemId: Guid): Boolean
    var
        Raw: Text;
    begin
        if not TryReadText(Token, Raw) then begin
            Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, GuidFormatErr, 'systemId', '', GuidExpectedTxt, MissingNextStepTxt);
            exit(false);
        end;
        Raw := Raw.Trim();
        if Raw = '' then
            exit(false);
        if not Evaluate(SystemId, Raw) or IsNullGuid(SystemId) then begin
            Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, GuidFormatErr, 'systemId', Raw, GuidExpectedTxt, MissingNextStepTxt);
            exit(false);
        end;
        exit(true);
    end;

    local procedure ReadDescription(var Argument: Record "Message Argument ori"; Token: JsonToken; var Description: Text): Boolean
    var
        Version: Record "Production BOM Version";
        Raw: Text;
    begin
        if not TryReadText(Token, Raw) then begin
            Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(NotACodeErr, 'description', MaxStrLen(Version.Description)), 'description', '', DescriptionExpectedTxt, TooLongNextStepTxt);
            exit(false);
        end;
        Raw := Raw.Trim();
        if Raw = '' then
            exit(false);
        if StrLen(Raw) > MaxStrLen(Version.Description) then begin
            Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(TooLongErr, 'description', MaxStrLen(Version.Description)), 'description', Raw, DescriptionExpectedTxt, TooLongNextStepTxt);
            exit(false);
        end;
        Description := Raw;
        exit(true);
    end;

    local procedure ReadStartingDate(var Argument: Record "Message Argument ori"; Token: JsonToken; var StartingDate: Date)
    var
        Raw: Text;
    begin
        if not TryReadText(Token, Raw) then begin
            Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, DateFormatErr, 'startingDate', '', DateExpectedTxt, MissingNextStepTxt);
            exit;
        end;
        Raw := Raw.Trim();
        if Raw = '' then begin
            AddMissing(Argument, 'startingDate');
            exit;
        end;
        if not Evaluate(StartingDate, Raw, 9) or (StartingDate = 0D) or (Format(StartingDate, 0, 9) <> Raw) then
            Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, DateFormatErr, 'startingDate', Raw, DateExpectedTxt, MissingNextStepTxt);
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

    local procedure IsSameVersionText(PlatformError: Text): Boolean
    var
        Lower: Text;
    begin
        Lower := LowerCase(PlatformError);
        exit(Lower.Contains('cannot be copied to itself') or Lower.Contains(LowerCase(SameVersionErr)));
    end;

    local procedure IsUnitOfMeasureText(PlatformError: Text): Boolean
    var
        Lower: Text;
    begin
        Lower := LowerCase(PlatformError);
        exit(Lower.Contains('unit of measure') or Lower.Contains('mælieining'));
    end;

    local procedure ReplaceOutcome(var ResponseJson: JsonObject; NewCode: Text; NextStep: Text)
    begin
        if NewCode <> '' then
            if ResponseJson.Contains('code') then
                ResponseJson.Replace('code', NewCode)
            else
                ResponseJson.Add('code', NewCode);
        if ResponseJson.Contains('nextStep') then
            ResponseJson.Replace('nextStep', NextStep)
        else
            ResponseJson.Add('nextStep', NextStep);
    end;
}
