namespace Origo.Bifrost.Manufacturing;

using Origo.Bifrost;

/// <summary>Request validation and public help for manufacturing where-used queries.</summary>
codeunit 10077083 "Mfg WhereUsed Contract ori"
{
    Access = Internal;

    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        RefusalLbl: Label 'The where-used request cannot use parameter %1.', Comment = '%1 = parameter name, is-IS=Beiðnin um notkun getur ekki notað færibreytuna %1.';
        NextStepLbl: Label 'Send type item or productionBOM and an existing no. Use a yyyy-mm-dd calculationDate and a boolean multiLevel. Check the component units and BOM structure with Data.Records.Get.', Comment = 'is-IS=Sendu type item eða productionBOM og no sem er til. Notaðu calculationDate á forminu yyyy-mm-dd og multiLevel sem rökgildi. Athugaðu mælieiningar íhluta og gerð efnislista með Data.Records.Get.';
        UnknownNextStepLbl: Label 'Remove the undeclared parameter and send the request again.', Comment = 'is-IS=Fjarlægðu óskilgreindu færibreytuna og sendu beiðnina aftur.';
        PermissionNextStepLbl: Label 'Ask for BIFROST Read ori and permission to read items and production BOMs.', Comment = 'is-IS=Biddu um BIFROST Read ori og heimild til að lesa vörur og framleiðsluefnislista.';
        CalculationFailedLbl: Label 'Business Central could not calculate usage: %1', Comment = '%1 = native validation error, is-IS=Business Central gat ekki reiknað notkun: %1';
        ExpectedLbl: Label 'a declared parameter with a valid value', Comment = 'is-IS=skilgreind færibreyta með gildu gildi';

    /// <summary>Rejects malformed input before the native calculation runs.</summary>
    /// <param name="Argument">The dispatcher argument.</param>
    /// <param name="Kind">item or productionBOM.</param>
    /// <param name="DocumentNo">The source number.</param>
    /// <param name="CalculationDate">The date, defaulting to today.</param>
    /// <param name="MultiLevel">Whether indirect assemblies are included, defaulting to true.</param>
    /// <returns>True when every supplied parameter is valid.</returns>
    internal procedure ReadRequest(var Argument: Record "Message Argument ori"; var Kind: Text; var DocumentNo: Code[20]; var CalculationDate: Date; var MultiLevel: Boolean): Boolean
    var
        Request: JsonObject;
        Token: JsonToken;
        ParameterName: Text;
        Raw: Text;
    begin
        Request := Argument.GetRequestJson();
        foreach ParameterName in Request.Keys() do
            if not (ParameterName in ['type', 'no', 'calculationDate', 'multiLevel']) then begin
                Fail(Argument, "Bifrost Error Code ori"::UnknownParameter, ParameterName);
                exit(false);
            end;
        if not ReadText(Argument, Request, 'type', Kind) then
            exit(false);
        if not (Kind in ['item', 'productionBOM']) then begin
            Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'type');
            exit(false);
        end;
        if not ReadText(Argument, Request, 'no', Raw) then
            exit(false);
        if StrLen(Raw) > MaxStrLen(DocumentNo) then begin
            Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'no');
            exit(false);
        end;
        DocumentNo := CopyStr(Raw, 1, MaxStrLen(DocumentNo));
        CalculationDate := Today();
        if Request.Contains('calculationDate') then begin
            if not ReadText(Argument, Request, 'calculationDate', Raw) then
                exit(false);
            if not Evaluate(CalculationDate, Raw, 9) then begin
                Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'calculationDate');
                exit(false);
            end;
            if (CalculationDate = 0D) or (Format(CalculationDate, 0, 9) <> Raw) then begin
                Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'calculationDate');
                exit(false);
            end;
        end;
        MultiLevel := true;
        if Request.Get('multiLevel', Token) then begin
            Token.WriteTo(Raw);
            if not (Raw in ['true', 'false']) then begin
                Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, 'multiLevel');
                exit(false);
            end;
            MultiLevel := Token.AsValue().AsBoolean();
        end;
        exit(true);
    end;

    local procedure ReadText(var Argument: Record "Message Argument ori"; Request: JsonObject; ParameterName: Text; var Value: Text): Boolean
    var
        Token: JsonToken;
        Raw: Text;
    begin
        if not Request.Get(ParameterName, Token) then begin
            Fail(Argument, "Bifrost Error Code ori"::MissingParameter, ParameterName);
            exit(false);
        end;
        Token.WriteTo(Raw);
        if not Raw.StartsWith('"') then begin
            Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, ParameterName);
            exit(false);
        end;
        Value := Token.AsValue().AsText().Trim();
        if Value = '' then begin
            Fail(Argument, "Bifrost Error Code ori"::MissingParameter, ParameterName);
            exit(false);
        end;
        exit(true);
    end;

    /// <summary>Returns a structured, logged refusal without changing manufacturing records.</summary>
    /// <param name="Argument">The dispatcher argument.</param>
    /// <param name="ErrorCode">The Foundation error code.</param>
    /// <param name="ParameterName">The refused parameter.</param>
    internal procedure Fail(var Argument: Record "Message Argument ori"; ErrorCode: Enum "Bifrost Error Code ori"; ParameterName: Text)
    var
        NextStep: Text;
    begin
        NextStep := NextStepLbl;
        if ErrorCode = ErrorCode::UnknownParameter then
            NextStep := UnknownNextStepLbl;
        if ErrorCode = ErrorCode::PermissionDenied then
            NextStep := PermissionNextStepLbl;
        Argument.AddError(ErrorCode, StrSubstNo(RefusalLbl, ParameterName), ParameterName, '', ExpectedLbl, NextStep);
        Argument.RespondWithCollectedErrors(ErrorCode, StrSubstNo(RefusalLbl, ParameterName));
    end;

    /// <summary>Preserves the native reason when the structure cannot be calculated.</summary>
    /// <param name="Argument">The dispatcher argument.</param>
    /// <param name="Reason">The native validation error.</param>
    internal procedure FailCalculation(var Argument: Record "Message Argument ori"; Reason: Text)
    begin
        Argument.AddError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(CalculationFailedLbl, Reason), 'no', '', ExpectedLbl, NextStepLbl);
        Argument.RespondWithCollectedErrors("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(CalculationFailedLbl, Reason));
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
        Chapter.Add(ContractMgt.TargetEntry('data.no', 'item or production BOM no.', 'The existing item or production BOM selected by type.'));
    end;

    /// <summary>Describes all accepted parameters.</summary>
    internal procedure Parameters(var Chapter: JsonArray)
    begin
        Chapter.Add(ContractMgt.Parameter('type', 'string', true, 'item or productionBOM. Case sensitive.'));
        Chapter.Add(ContractMgt.Parameter('no', 'string', true, 'Existing item or production BOM number, at most 20 characters.'));
        Chapter.Add(ContractMgt.Parameter('calculationDate', 'date', false, 'Active BOM versions and date-effective lines on this yyyy-mm-dd date. Defaults to today.'));
        Chapter.Add(ContractMgt.Parameter('multiLevel', 'boolean', false, 'Include indirect assemblies when true. False returns direct owning assemblies only.'));
    end;

    /// <summary>Describes the native usage rows.</summary>
    internal procedure Response(var Chapter: JsonObject)
    var
        Fields: JsonArray;
    begin
        Chapter.Add('status', 'Success');
        Fields.Add(ContractMgt.ResponseField('uses', 'array', 'Native assembly results. Each entry contains itemNo, description, productionBomNo, versionCode, level and quantityNeeded. Levels are the native traversal depth, including both item and BOM nodes. Quantities include native unit conversion and scrap. An unused component returns an empty array.'));
        Chapter.Add('fields', Fields);
    end;

    /// <summary>Lists refusals and corrective steps.</summary>
    internal procedure Errors(var Chapter: JsonArray)
    begin
        Chapter.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'type or no is missing or blank, or calculationDate is blank.', 'Send type item or productionBOM and an existing no. Use a yyyy-mm-dd calculationDate and a boolean multiLevel. Check component units and BOM structure with Data.Records.Get.'));
        Chapter.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'A parameter has an invalid JSON type, date, length or source kind.', 'Send type item or productionBOM and an existing no. Use a yyyy-mm-dd calculationDate and a boolean multiLevel. Check component units and BOM structure with Data.Records.Get.'));
        Chapter.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, 'An undeclared parameter was sent.', 'Remove the undeclared parameter and send the request again.'));
        Chapter.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The selected item or production BOM does not exist.', 'Send type item or productionBOM and an existing no. Use a yyyy-mm-dd calculationDate and a boolean multiLevel. Check component units and BOM structure with Data.Records.Get.'));
        Chapter.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller lacks the read role or access to the manufacturing records.', 'Ask for BIFROST Read ori and permission to read items and production BOMs.'));
        Chapter.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'Business Central cannot calculate the structure, for example because a component unit is missing or a BOM is circular.', 'Send type item or productionBOM and an existing no. Use a yyyy-mm-dd calculationDate and a boolean multiLevel. Check component units and BOM structure with Data.Records.Get.'));
    end;

    /// <summary>Declares an idempotent read.</summary>
    internal procedure Effect(var Chapter: JsonObject)
    begin
        Chapter.Add('effect', 'read');
        Chapter.Add('idempotent', true);
        Chapter.Add('permissionSet', 'BIFROST Read ori');
        Chapter.Add('changes', 'No manufacturing records are changed.');
    end;

    /// <summary>Links to record inspection.</summary>
    internal procedure Related(var Chapter: JsonArray)
    begin
        Chapter.Add(ContractMgt.RelatedEntry('Data.Records.Get', 'Inspect the items, BOM versions and component lines.'));
    end;

    /// <summary>Explains the discovery workflow.</summary>
    internal procedure Workflow(var Chapter: JsonObject)
    var
        Steps: JsonArray;
    begin
        Steps.Add(ContractMgt.WorkflowStep('Manufacturing.WhereUsed.Get', 'Find direct and indirect owning assemblies.'));
        Steps.Add(ContractMgt.WorkflowStep('Data.Records.Get', 'Inspect the affected BOMs and their active versions.'));
        Chapter.Add('steps', Steps);
        Chapter.Add('text', 'Find usage before planning an engineering change.');
    end;

    /// <summary>Provides a complete request and response example.</summary>
    internal procedure Examples(var Chapter: JsonArray)
    begin
        Chapter.Add(ContractMgt.Example('Find all assemblies using a component', '{"type":"Manufacturing.WhereUsed.Get","data":{"type":"item","no":"COMP-100","multiLevel":true}}', '{"status":"Success","uses":[{"itemNo":"SUB-100","description":"Subassembly","productionBomNo":"BOM-100","versionCode":"","level":2,"quantityNeeded":3}]}'));
    end;

    /// <summary>Returns the English overview in every language.</summary>
    internal procedure Overview(): Text
    begin
        exit('Finds the assemblies that use an item or production BOM on a calculation date. The calculation follows active versions and date-effective component lines, and returns levels and required quantities. Send multiLevel false to stop at direct owning assemblies.');
    end;

    /// <summary>Returns the English calculation limits in every language.</summary>
    internal procedure Notes(): Text
    begin
        exit('The calculation returns owning items, as in the standard where-used inquiry. A BOM with no owning item has no assembly row. Native traversal counts both item and BOM nodes; an item component normally has direct level 2 and its next assembly level 4. Native recursion stops at depth 30. Empty usage is a successful empty array. No records are changed.');
    end;
}
