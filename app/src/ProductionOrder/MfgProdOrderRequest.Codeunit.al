namespace Origo.Bifrost.Manufacturing;

using Origo.Bifrost;

/// <summary>Collects typed request problems before a production order transaction starts.</summary>
codeunit 10077045 "Mfg Prod Order Request ori"
{
    Access = Internal;

    var
        MissingLbl: Label '%1 is required.', Comment = '%1 = parameter, is-IS=%1 er áskilið.';
        FormatLbl: Label '%1 has an invalid format.', Comment = '%1 = parameter, is-IS=%1 er á ógildu sniði.';
        LengthLbl: Label '%1 must not exceed %2 characters.', Comment = '%1 = parameter, %2 = maximum length, is-IS=%1 má ekki vera lengra en %2 stafir.';
        UnknownLbl: Label 'Unknown parameter %1.', Comment = '%1 = parameter, is-IS=Óþekkt færibreyta %1.';
        CorrectLbl: Label 'Send the parameter in the format documented by describe_message_type.', Comment = 'is-IS=Sendu færibreytuna á sniðinu sem describe_message_type lýsir.';
        UnknownNextLbl: Label 'Remove the unknown parameter and use the documented parameters.', Comment = 'is-IS=Fjarlægðu óþekktu færibreytuna og notaðu skjalfestar færibreytur.';
        NothingLbl: Label 'Nothing was changed.', Comment = 'is-IS=Engu var breytt.';

    /// <summary>Collects unknown keys together with other request problems.</summary>
    internal procedure CheckKeys(Allowed: Text; Request: JsonObject; var Argument: Record "Message Argument ori")
    var
        KeyName: Text;
    begin
        foreach KeyName in Request.Keys() do
            if not Allowed.Split('|').Contains(KeyName) then
                Argument.AddError("Bifrost Error Code ori"::UnknownParameter, StrSubstNo(UnknownLbl, KeyName), KeyName, '', '', UnknownNextLbl);
    end;

    /// <summary>Reads a JSON string without silently truncating identifiers.</summary>
    internal procedure ReadText(Request: JsonObject; KeyName: Text; Required: Boolean; Maximum: Integer; var Argument: Record "Message Argument ori"): Text
    var
        Token: JsonToken;
        Raw: Text;
        Value: Text;
    begin
        if not Request.Get(KeyName, Token) then begin
            if Required then
                Missing(KeyName, Argument);
            exit('');
        end;
        Token.WriteTo(Raw);
        if (CopyStr(Raw, 1, 1) <> '"') or not Token.IsValue() then begin
            BadFormat(KeyName, Argument);
            exit('');
        end;
        Value := Token.AsValue().AsText();
        if Required and (Value.Trim() = '') then
            Missing(KeyName, Argument);
        if StrLen(Value) > Maximum then
            Argument.AddError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(LengthLbl, KeyName, Maximum), KeyName, '', '', CorrectLbl);
        exit(Value);
    end;

    /// <summary>Requires a JSON number for quantity; collects invalid and missing values.</summary>
    internal procedure ReadQuantity(Request: JsonObject; var Argument: Record "Message Argument ori"): Decimal
    var
        Token: JsonToken;
        Raw: Text;
        Quantity: Decimal;
        PositiveLbl: Label 'quantity must be greater than 0.', Comment = 'is-IS=quantity verður að vera stærra en 0.';
        PositiveNextLbl: Label 'Send a positive quantity in the item base unit of measure.', Comment = 'is-IS=Sendu jákvætt magn í grunneiningu vörunnar.';
    begin
        if not Request.Get('quantity', Token) then begin
            Missing('quantity', Argument);
            exit(0);
        end;
        Token.WriteTo(Raw);
        if not Token.IsValue() or (CopyStr(Raw, 1, 1) = '"') or not Evaluate(Quantity, Raw, 9) then begin
            BadFormat('quantity', Argument);
            exit(0);
        end;
        if Quantity <= 0 then
            Argument.AddError("Bifrost Error Code ori"::InvalidParameter, PositiveLbl, 'quantity', Raw, '', PositiveNextLbl);
        exit(Quantity);
    end;

    /// <summary>Reads an optional strict ISO calendar date, defaulting to the session work date.</summary>
    internal procedure ReadDueDate(Request: JsonObject; var Argument: Record "Message Argument ori"): Date
    var
        Value: Text;
        DueDate: Date;
    begin
        if not Request.Contains('dueDate') then
            exit(WorkDate());
        Value := ReadText(Request, 'dueDate', true, 10, Argument);
        if not Evaluate(DueDate, Value, 9) then begin
            BadFormat('dueDate', Argument);
            exit(0D);
        end;
        if (DueDate = 0D) or (Format(DueDate, 0, 9) <> Value) then
            BadFormat('dueDate', Argument);
        exit(DueDate);
    end;

    /// <summary>Reads an optional JSON boolean with the documented true default.</summary>
    internal procedure ReadBoolean(Request: JsonObject; KeyName: Text; var Argument: Record "Message Argument ori"): Boolean
    var
        Token: JsonToken;
        Raw: Text;
    begin
        if not Request.Get(KeyName, Token) then
            exit(true);
        Token.WriteTo(Raw);
        case Raw of
            'true':
                exit(true);
            'false':
                exit(false);
            else
                BadFormat(KeyName, Argument);
        end;
        exit(false);
    end;

    /// <summary>Responds once after validation; returns true if execution must stop.</summary>
    internal procedure RespondIfErrors(var Argument: Record "Message Argument ori"): Boolean
    begin
        if not Argument.HasCollectedErrors() then
            exit(false);
        Argument.RespondWithCollectedErrors("Bifrost Error Code ori"::MultipleErrors, NothingLbl);
        exit(true);
    end;

    /// <summary>Adds a missing parameter without losing other errors.</summary>
    internal procedure Missing(KeyName: Text; var Argument: Record "Message Argument ori")
    begin
        Argument.AddError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(MissingLbl, KeyName), KeyName, '', '', CorrectLbl);
    end;

    /// <summary>Adds a format error without exposing a call stack.</summary>
    internal procedure BadFormat(KeyName: Text; var Argument: Record "Message Argument ori")
    begin
        Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(FormatLbl, KeyName), KeyName, '', '', CorrectLbl);
    end;
}
