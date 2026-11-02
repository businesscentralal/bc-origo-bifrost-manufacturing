namespace Origo.Bifrost.Manufacturing;

using Origo.Bifrost;

/// <summary>Shared typed validation and coded refusals for production-order actions.</summary>
codeunit 10077060 "Mfg Action Contract ori"
{
    Access = Internal;

    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MissingErr: Label 'Provide %1.', Comment = '%1 = parameter, is-IS=Tilgreindu %1.';
        FormatErr: Label 'Parameter %1 must be %2.', Comment = '%1 = parameter, %2 = expected format, is-IS=Færibreytan %1 verður að vera %2.';
        UnknownErr: Label 'Parameter %1 is not used by this operation.', Comment = '%1 = parameter, is-IS=Færibreytan %1 er ekki notuð af þessari aðgerð.';
        CorrectRequestTxt: Label 'Correct the named parameter and send the request again.', Comment = 'is-IS=Leiðréttu tilgreinda færibreytu og sendu beiðnina aftur.';
        RefusalErr: Label 'The production action cannot run.', Comment = 'is-IS=Ekki er hægt að keyra framleiðsluaðgerðina.';
        PermissionErr: Label 'You do not have permission to read and change the required production records.', Comment = 'is-IS=Þú hefur ekki heimild til að lesa og breyta nauðsynlegum framleiðslufærslum.';
        PermissionNextTxt: Label 'Ask for the production table permissions and BIFROST Full ori.', Comment = 'is-IS=Biddu um heimildir á framleiðslutöflum og BIFROST Full ori.';
        CommitErr: Label 'This operation calls Business Central routines that may commit. Omit Commit is not supported.', Comment = 'is-IS=Þessi aðgerð kallar á Business Central aðgerðir sem geta staðfest færslur. Omit Commit er ekki stutt.';
        CommitNextTxt: Label 'Run this operation as a separate request with Omit Commit disabled.', Comment = 'is-IS=Keyrðu þessa aðgerð sem sérstaka beiðni með Omit Commit óvirkt.';

    /// <summary>Refuses undeclared parameters before any record is read or changed.</summary>
    internal procedure ValidateKeys(var Argument: Record "Message Argument ori"; AllowedKeys: Text): Boolean
    var
        Request: JsonObject;
        ParameterName: Text;
    begin
        Request := Argument.GetRequestJson();
        foreach ParameterName in Request.Keys() do
            if not AllowedKeys.Contains('|' + ParameterName + '|') then
                exit(Refuse(Argument, "Bifrost Error Code ori"::UnknownParameter, ParameterName, StrSubstNo(UnknownErr, ParameterName)));
        exit(true);
    end;

    /// <summary>Reads required text, with an optional subject override and an exact maximum length.</summary>
    internal procedure ReadCode(var Argument: Record "Message Argument ori"; Name: Text; SubjectValue: Text; MaxLength: Integer; var Value: Text): Boolean
    var
        Request: JsonObject;
        Token: JsonToken;
        Serialized: Text;
    begin
        Value := SubjectValue;
        if Value = '' then begin
            Request := Argument.GetRequestJson();
            if not Request.Get(Name, Token) then
                exit(Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, Name, StrSubstNo(MissingErr, Name)));
            Token.WriteTo(Serialized);
            if CopyStr(Serialized, 1, 1) <> '"' then
                exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, Name, StrSubstNo(FormatErr, Name, 'text')));
            Value := Token.AsValue().AsText();
        end;
        if Value.Trim() = '' then
            exit(Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, Name, StrSubstNo(MissingErr, Name)));
        if StrLen(Value) > MaxLength then
            exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, Name, StrSubstNo(FormatErr, Name, 'text within the declared length')));
        exit(true);
    end;

    /// <summary>Reads a strictly positive JSON integer without throwing conversion errors.</summary>
    internal procedure ReadPositiveInteger(var Argument: Record "Message Argument ori"; Name: Text; var Value: Integer): Boolean
    var
        Request: JsonObject;
        Token: JsonToken;
        Serialized: Text;
    begin
        Request := Argument.GetRequestJson();
        if not Request.Get(Name, Token) then
            exit(Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, Name, StrSubstNo(MissingErr, Name)));
        Token.WriteTo(Serialized);
        if not Evaluate(Value, Serialized, 9) then
            exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, Name, StrSubstNo(FormatErr, Name, 'a positive integer')));
        if Value <= 0 then
            exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, Name, StrSubstNo(FormatErr, Name, 'a positive integer')));
        exit(true);
    end;

    /// <summary>Reads an optional JSON boolean; absent means false.</summary>
    internal procedure ReadBoolean(var Argument: Record "Message Argument ori"; Name: Text; var Value: Boolean): Boolean
    var
        Request: JsonObject;
        Token: JsonToken;
        Serialized: Text;
    begin
        Value := false;
        Request := Argument.GetRequestJson();
        if not Request.Get(Name, Token) then
            exit(true);
        Token.WriteTo(Serialized);
        if not (Serialized in ['true', 'false']) then
            exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, Name, StrSubstNo(FormatErr, Name, 'a boolean')));
        Value := Serialized = 'true';
        exit(true);
    end;

    /// <summary>Reads an optional ISO date; absent means the session work date.</summary>
    internal procedure ReadDate(var Argument: Record "Message Argument ori"; Name: Text; var Value: Date): Boolean
    var
        Request: JsonObject;
        Token: JsonToken;
        Serialized: Text;
        Raw: Text;
    begin
        Value := WorkDate();
        Request := Argument.GetRequestJson();
        if not Request.Get(Name, Token) then
            exit(true);
        Token.WriteTo(Serialized);
        if CopyStr(Serialized, 1, 1) <> '"' then
            exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, Name, StrSubstNo(FormatErr, Name, 'YYYY-MM-DD')));
        Raw := Token.AsValue().AsText();
        if (StrLen(Raw) <> 10) or (CopyStr(Raw, 5, 1) <> '-') or (CopyStr(Raw, 8, 1) <> '-') then
            exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, Name, StrSubstNo(FormatErr, Name, 'YYYY-MM-DD')));
        if not Evaluate(Value, Raw, 9) then
            exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, Name, StrSubstNo(FormatErr, Name, 'YYYY-MM-DD')));
        exit(true);
    end;

    /// <summary>Checks the caller's table permissions without elevating access.</summary>
    internal procedure HasPermission(var Argument: Record "Message Argument ori"; CanRead: Boolean; CanWrite: Boolean): Boolean
    begin
        if CanRead and CanWrite then
            exit(true);
        Argument.AddError("Bifrost Error Code ori"::PermissionDenied, PermissionErr, 'permission', '', '', PermissionNextTxt);
        Argument.RespondWithCollectedErrors("Bifrost Error Code ori"::MultipleErrors, RefusalErr);
        exit(false);
    end;

    /// <summary>Refuses unsafe transaction composition before invoking a committing standard routine.</summary>
    internal procedure RequireCommittingCall(var Argument: Record "Message Argument ori"): Boolean
    begin
        if not Argument."Omit Commit" then
            exit(true);
        Argument.AddError("Bifrost Error Code ori"::PreconditionFailed, CommitErr, 'omitCommit', 'true', 'false', CommitNextTxt);
        Argument.RespondWithCollectedErrors("Bifrost Error Code ori"::MultipleErrors, RefusalErr);
        exit(false);
    end;

    /// <summary>Returns a coded refusal with parameter and recovery guidance.</summary>
    internal procedure Refuse(var Argument: Record "Message Argument ori"; ErrorCode: Enum "Bifrost Error Code ori"; ParameterName: Text; MessageText: Text): Boolean
    begin
        Argument.AddError(ErrorCode, MessageText, ParameterName, '', '', CorrectRequestTxt);
        Argument.RespondWithCollectedErrors("Bifrost Error Code ori"::MultipleErrors, RefusalErr);
        exit(false);
    end;

    /// <summary>Documents the common stable error codes of production actions.</summary>
    internal procedure Errors(var ErrorEntries: JsonArray)
    begin
        ErrorEntries.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'A required parameter is missing or blank.', CorrectRequestTxt));
        ErrorEntries.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'A parameter is outside the allowed values.', CorrectRequestTxt));
        ErrorEntries.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'A parameter has the wrong JSON type, format or length.', CorrectRequestTxt));
        ErrorEntries.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, 'The request contains an undeclared parameter.', CorrectRequestTxt));
        ErrorEntries.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The requested production record does not exist.', 'Read the target before retrying.'));
        ErrorEntries.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The record state is unsuitable, the target is ambiguous, or Omit Commit is enabled.', 'Correct the state; run committing actions as a separate request.'));
        ErrorEntries.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, PermissionErr, PermissionNextTxt));
        ErrorEntries.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Business Central refused the operation.', 'Correct the reported Business Central setup or data error before retrying.'));
    end;
}
