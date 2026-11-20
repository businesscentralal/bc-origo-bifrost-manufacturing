namespace Origo.Bifrost.Manufacturing;

using Microsoft.Manufacturing.Document;
using Origo.Bifrost;

/// <summary>Validates order read identity, status, filters and the Manufacturing read role.</summary>
codeunit 10077065 "Mfg Order Read Request ori"
{
    Access = Internal;
    Permissions =
        tabledata "Production Order" = R,
        tabledata "Prod. Order Line" = R;

    var
        InvalidLbl: Label 'Invalid value for %1.', Comment = '%1 = parameter, is-IS=Ógilt gildi fyrir %1.';
        MissingLbl: Label '%1 is required.', Comment = '%1 = parameter, is-IS=%1 er áskilið.';
        UnknownLbl: Label 'Unknown parameter %1.', Comment = '%1 = parameter, is-IS=Óþekkt færibreyta %1.';
        FormatNextLbl: Label 'Use the parameters and formats documented by describe_message_type.', Comment = 'is-IS=Notaðu færibreytur og snið sem describe_message_type lýsir.';
        NotFoundLbl: Label 'The production order or selected line was not found.', Comment = 'is-IS=Framleiðslupöntunin eða valin lína fannst ekki.';
        LookupNextLbl: Label 'Read production orders with Data.Records.Get and send matching identifiers and status.', Comment = 'is-IS=Lestu framleiðslupantanir með Data.Records.Get og sendu samsvarandi auðkenni og stöðu.';
        ConflictLbl: Label 'The identifiers refer to different production orders or statuses.', Comment = 'is-IS=Auðkennin vísa á mismunandi framleiðslupantanir eða stöður.';
        FinishedLbl: Label 'Component availability is not available for a finished production order.', Comment = 'is-IS=Framboð íhluta er ekki tiltækt fyrir lokið framleiðslupöntun.';
        FinishedNextLbl: Label 'Use a Planned, FirmPlanned or Released order for component availability.', Comment = 'is-IS=Notaðu pöntun í stöðunni Planned, FirmPlanned eða Released fyrir framboð íhluta.';
        PermissionLbl: Label 'The Manufacturing read role is required.', Comment = 'is-IS=Leshlutverk framleiðslu er áskilið.';
        PermissionNextLbl: Label 'Ask an administrator to assign the Bifrost Read or Full role with Manufacturing access.', Comment = 'is-IS=Biddu stjórnanda um að úthluta Bifrost Read eða Full hlutverki með aðgangi að framleiðslu.';

    /// <summary>Checks a strict request before reading business data. Refusals never mutate business records.</summary>
    internal procedure Read(var Argument: Record "Message Argument ori"; Availability: Boolean; var Order: Record "Production Order"; var LineNo: Integer; var LocationCode: Code[10]): Boolean
    var
        Gate: Record "Mfg Write Gate ori";
        Line: Record "Prod. Order Line";
        Request: JsonObject;
        Token: JsonToken;
        KeyName: Text;
        Allowed: List of [Text];
        Number: Text;
        IdText: Text;
        StatusText: Text;
        LocationText: Text;
        Raw: Text;
        Id: Guid;
        OrderStatus: Enum "Production Order Status";
    begin
        if not Gate.ReadPermission() then
            exit(Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, PermissionLbl, '', PermissionNextLbl));
        Request := Argument.GetRequestJson();
        Allowed := 'no|systemId|status|lineNo'.Split('|');
        if Availability then
            Allowed.Add('locationCode');
        foreach KeyName in Request.Keys() do
            if not Allowed.Contains(KeyName) then
                exit(Refuse(Argument, "Bifrost Error Code ori"::UnknownParameter, StrSubstNo(UnknownLbl, KeyName), KeyName, FormatNextLbl));
        if not ReadText(Request, 'no', 20, Argument, Number) then
            exit(false);
        if not ReadText(Request, 'systemId', 50, Argument, IdText) then
            exit(false);
        if (Number = '') and (IdText = '') then
            exit(Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, StrSubstNo(MissingLbl, 'no/systemId'), 'no/systemId', LookupNextLbl));
        if not ReadText(Request, 'status', 20, Argument, StatusText) then
            exit(false);
        if StatusText = '' then
            exit(Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, StrSubstNo(MissingLbl, 'status'), 'status', FormatNextLbl));
        case StatusText of
            'Planned': OrderStatus := OrderStatus::Planned;
            'FirmPlanned': OrderStatus := OrderStatus::"Firm Planned";
            'Released': OrderStatus := OrderStatus::Released;
            'Finished': OrderStatus := OrderStatus::Finished;
            else
                exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(InvalidLbl, 'status'), 'status', FormatNextLbl));
        end;
        if Request.Get('lineNo', Token) then begin
            Token.WriteTo(Raw);
            if not Token.IsValue() or (CopyStr(Raw, 1, 1) = '"') or not Evaluate(LineNo, Raw, 9) then
                exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(InvalidLbl, 'lineNo'), 'lineNo', FormatNextLbl));
            if LineNo <= 0 then
                exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(InvalidLbl, 'lineNo'), 'lineNo', FormatNextLbl));
        end;
        if not ReadText(Request, 'locationCode', 10, Argument, LocationText) then
            exit(false);
        LocationCode := CopyStr(LocationText, 1, MaxStrLen(LocationCode));
        Order.SetLoadFields(Status, "No.");
        if IdText <> '' then begin
            if not Evaluate(Id, IdText) or IsNullGuid(Id) then
                exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(InvalidLbl, 'systemId'), 'systemId', FormatNextLbl));
            if not Order.GetBySystemId(Id) then
                exit(Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, NotFoundLbl, 'systemId', LookupNextLbl));
            if ((Number <> '') and (Order."No." <> UpperCase(Number))) or (Order.Status <> OrderStatus) then
                exit(Refuse(Argument, "Bifrost Error Code ori"::ConflictingIdentifiers, ConflictLbl, 'no/systemId/status', LookupNextLbl));
        end else
            if not Order.Get(OrderStatus, Number) then
                exit(Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, NotFoundLbl, 'no/status', LookupNextLbl));
        if Availability and (Order.Status = Order.Status::Finished) then
            exit(Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, FinishedLbl, 'status', FinishedNextLbl));
        if LineNo <> 0 then
            if not Line.Get(Order.Status, Order."No.", LineNo) then
                exit(Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, NotFoundLbl, 'lineNo', LookupNextLbl));
        exit(true);
    end;

    /// <summary>Distinguishes an explicit blank location from an omitted filter.</summary>
    internal procedure HasLocation(var Argument: Record "Message Argument ori"): Boolean
    var
        Request: JsonObject;
    begin
        Request := Argument.GetRequestJson();
        exit(Request.Contains('locationCode'));
    end;

    local procedure ReadText(Request: JsonObject; Name: Text; Maximum: Integer; var Argument: Record "Message Argument ori"; var Value: Text): Boolean
    var
        Token: JsonToken;
        Raw: Text;
    begin
        if not Request.Get(Name, Token) then
            exit(true);
        Token.WriteTo(Raw);
        if not Token.IsValue() or (CopyStr(Raw, 1, 1) <> '"') then
            exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(InvalidLbl, Name), Name, FormatNextLbl));
        Value := Token.AsValue().AsText();
        if StrLen(Value) > Maximum then
            exit(Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(InvalidLbl, Name), Name, FormatNextLbl));
        exit(true);
    end;

    local procedure Refuse(var Argument: Record "Message Argument ori"; ErrorCode: Enum "Bifrost Error Code ori"; MessageText: Text; Parameter: Text; NextStep: Text): Boolean
    begin
        Argument.RespondWithError(ErrorCode, MessageText, Parameter, '', '', NextStep);
        exit(false);
    end;
}
