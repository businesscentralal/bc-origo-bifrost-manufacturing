namespace Origo.Bifrost.Manufacturing;

using Microsoft.Inventory.Requisition;
using Microsoft.Manufacturing.Planning;
using Origo.Bifrost;

/// <summary>
/// Implements Manufacturing.Planning.CalculatePlan using Microsoft's Calculate Plan - Plan. Wksh. report.
/// </summary>
codeunit 10077054 "Mfg Plan Calc Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    TableNo = "Message Argument ori";

    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        RequiredParameterErr: Label 'Provide the required planning parameter %1.', Comment = '%1 = parameter name||is-IS=Tilgreindu nauðsynlega áætlanabreytu %1.';
        ParameterTooLongErr: Label 'Parameter %1 exceeds the maximum length of %2 characters.', Comment = '%1 = parameter name, %2 = maximum character count||is-IS=Færibreytan %1 er lengri en hámarkslengd, %2 stafir.';
        InvalidDateErr: Label '%1 must be a valid ISO date in YYYY-MM-DD format.', Comment = '%1 = parameter name||is-IS=%1 verður að vera gild dagsetning á ISO sniði ÁÁÁÁ-MM-DD.';
        InvalidDateRangeErr: Label 'toDate must be on or after fromDate.', Comment = 'is-IS=toDate verður að vera sama dagsetning eða seinna en fromDate.';
        WorksheetNotFoundErr: Label 'Planning worksheet %1 does not exist in template %2.', Comment = '%1 = worksheet name, %2 = template name||is-IS=Áætlunarblað %1 er ekki til í sniðmáti %2.';
        DescriptionLbl: Label 'Calculates supply and production proposals in one planning worksheet for a defined planning horizon.', MaxLength = 250, Comment = 'is-IS=Reiknar tillögur um framboð og framleiðslu á einu áætlunarblaði fyrir skilgreint áætlanatímabil.';

    /// <summary>Reports whether planning calculation is available.</summary>
    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    /// <summary>Returns the requisition line table used to filter planning worksheet results.</summary>
    procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Requisition Line");
    end;

    /// <summary>Describes planning worksheet calculation.</summary>
    procedure GetDescription() Description: Text[250]
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns search terms for planning calculation.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'planning worksheet, calculate plan, MPS, MRP, supply planning, regenerative planning', Comment = 'is-IS=áætlunarblað, reikna áætlun, MPS, MRP, framboðsáætlun, endurnýjunar áætlun';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Explains the operation's data-changing effect when a caller selects it.</summary>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Creates or updates planning worksheet proposals for the selected horizon and options. Review the worksheet before carrying out actions.', Comment = 'is-IS=Stofnar eða uppfærir tillögur á áætlunarblaði fyrir valið tímabil og valkosti. Farðu yfir blaðið áður en aðgerðir eru framkvæmdar.';
    begin
        exit(SelectionLbl);
    end;

    /// <summary>Describes the request envelope.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
    begin
        Subject.Add('use', 'notUsed');
        Subject.Add('description', 'The subject is not used. Pass planning worksheet and horizon in data.');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    /// <summary>Declares no single-record target for the planning calculation.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>Describes the worksheet, horizon, and planning options.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Parameter: JsonObject;
    begin
        Parameters.Add(ContractMgt.Parameter('worksheetTemplateName', 'string', true, 'Planning worksheet template name.'));
        Parameters.Add(ContractMgt.Parameter('worksheetName', 'string', true, 'Planning worksheet batch name.'));
        Parameters.Add(DateParameter('fromDate', true, 'First date in the planning horizon.'));
        Parameters.Add(DateParameter('toDate', true, 'Last date in the planning horizon.'));
        Parameter := BooleanParameter('regenerative', true, 'When true, runs regenerative planning; otherwise it runs net change planning.');
        Parameters.Add(Parameter);
        Parameters.Add(BooleanParameter('respectPlanningParameters', true, 'Uses planning parameters on items and SKUs.'));
        Parameters.Add(BooleanParameter('mps', true, 'Includes master production schedule calculation.'));
        Parameters.Add(BooleanParameter('mrp', true, 'Includes material requirements planning calculation.'));
        Parameters.Add(ContractMgt.Parameter('forecastName', 'string', false, 'Optional production forecast to use.'));
        Parameters.Add(DateParameter('excludeForecastBefore', false, 'Excludes forecast entries before this date.'));
        Parameters.Add(BooleanParameter('noPlanningResiliency', false, 'Disables planning resiliency and stops on planning errors.'));
        exit(true);
    end;

    /// <summary>Describes the successful response.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Fields: JsonArray;
        ResponseField: JsonObject;
    begin
        ResponseField.Add('name', 'status');
        ResponseField.Add('type', 'string');
        ResponseField.Add('description', 'Success when the planning calculation completed.');
        Fields.Add(ResponseField);
        Clear(ResponseField);
        ResponseField.Add('name', 'worksheetTemplateName');
        ResponseField.Add('type', 'string');
        ResponseField.Add('description', 'The planning worksheet template used.');
        Fields.Add(ResponseField);
        Clear(ResponseField);
        ResponseField.Add('name', 'worksheetName');
        ResponseField.Add('type', 'string');
        ResponseField.Add('description', 'The planning worksheet batch updated.');
        Fields.Add(ResponseField);
        Clear(ResponseField);
        ResponseField.Add('name', 'planningLinesCount');
        ResponseField.Add('type', 'integer');
        ResponseField.Add('description', 'The number of proposal lines in the worksheet after calculation.');
        Fields.Add(ResponseField);
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Describes missing worksheet and invalid horizon errors.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ErrorInfo: JsonObject;
    begin
        ErrorInfo.Add('error', 'Planning worksheet not found.');
        ErrorInfo.Add('when', 'The template and worksheet names do not identify an existing Requisition Line batch.');
        ErrorInfo.Add('fix', 'Check worksheetTemplateName and worksheetName.');
        Errors.Add(ErrorInfo);
        Clear(ErrorInfo);
        ErrorInfo.Add('error', 'Invalid planning date range.');
        ErrorInfo.Add('when', 'fromDate or toDate is invalid, or toDate is before fromDate.');
        ErrorInfo.Add('fix', 'Pass ISO dates in YYYY-MM-DD format and ensure toDate is not before fromDate.');
        Errors.Add(ErrorInfo);
        exit(true);
    end;

    /// <summary>Describes the planning proposals changed by the operation.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Creates or updates planning worksheet proposal lines.');
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', 'BIFROST Mfg ori');
        exit(true);
    end;

    /// <summary>Declares no additional manufacturing-specific metering.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Declares no related message types.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>Describes the calculate-then-review planning workflow.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Steps: JsonArray;
        WorkflowStep: JsonObject;
    begin
        WorkflowStep.Add('messageType', 'Manufacturing.Planning.CalculatePlan');
        WorkflowStep.Add('purpose', 'Calculate planning proposals, review the worksheet, then carry out selected actions.');
        Steps.Add(WorkflowStep);
        Workflow.Add('steps', Steps);
        exit(true);
    end;

    /// <summary>Provides a representative planning calculation request and response.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        RequestData: JsonObject;
        Request: JsonObject;
        Response: JsonObject;
        Example: JsonObject;
    begin
        RequestData.Add('worksheetTemplateName', 'X-PLAN');
        RequestData.Add('worksheetName', 'X-DEFAULT');
        RequestData.Add('fromDate', '2026-10-01');
        RequestData.Add('toDate', '2026-12-31');
        RequestData.Add('regenerative', true);
        RequestData.Add('mps', true);
        RequestData.Add('mrp', true);
        Request.Add('type', 'Manufacturing.Planning.CalculatePlan');
        Request.Add('data', RequestData);
        Response.Add('status', 'Success');
        Response.Add('worksheetTemplateName', 'X-PLAN');
        Response.Add('worksheetName', 'X-DEFAULT');
        Response.Add('planningLinesCount', 12);
        Example.Add('title', 'Calculate a regenerative planning worksheet');
        Example.Add('request', Request);
        Example.Add('response', Response);
        Examples.Add(Example);
        exit(true);
    end;

    /// <summary>Explains when to use planning worksheet calculation.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Calculates MPS and MRP proposals in one planning worksheet for a supplied date horizon and planning option set.';
        exit(true);
    end;

    /// <summary>Documents important behavior of planning calculation.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'The request page is not shown. Planning proposals are written to the worksheet but are not carried out; use Microsoft''s carry-out action after reviewing the results.';
        exit(true);
    end;

    /// <summary>Returns the inbound message direction.</summary>
    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    trigger OnRun()
    begin
        PerformCalculate(Rec);
    end;

    /// <summary>Executes this message type through Bifrost Foundation.</summary>
    /// <param name="Argument">The message argument and response record.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        if Argument."Omit Commit" then begin
            PerformCalculate(Argument);
            exit;
        end;

        if not Codeunit.Run(Codeunit::"Mfg Plan Calc Impl ori", Argument) then
            Argument.RespondWithLastError();
    end;

    local procedure PerformCalculate(var Argument: Record "Message Argument ori")
    var
        RequisitionLine: Record "Requisition Line";
        CalculatePlanReport: Report "Calculate Plan - Plan. Wksh.";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        WorksheetTemplateName: Code[10];
        WorksheetName: Code[10];
        ForecastName: Code[10];
        FromDate: Date;
        ToDate: Date;
        ExcludeForecastBefore: Date;
        Regenerative: Boolean;
        RespectPlanningParameters: Boolean;
        MPS: Boolean;
        MRP: Boolean;
        NoPlanningResiliency: Boolean;
        PlanningLinesCount: Integer;
    begin
        RequestJson := Argument.GetRequestJson();
        WorksheetTemplateName := GetCode10(RequestJson, 'worksheetTemplateName');
        WorksheetName := GetCode10(RequestJson, 'worksheetName');
        FromDate := GetRequiredDate(RequestJson, 'fromDate');
        ToDate := GetRequiredDate(RequestJson, 'toDate');
        if ToDate < FromDate then
            Error(InvalidDateRangeErr);

        Regenerative := GetBoolean(RequestJson, 'regenerative', true);
        RespectPlanningParameters := GetBoolean(RequestJson, 'respectPlanningParameters', true);
        MPS := GetBoolean(RequestJson, 'mps', true);
        MRP := GetBoolean(RequestJson, 'mrp', true);
        ForecastName := CopyStr(GetOptionalText(RequestJson, 'forecastName'), 1, MaxStrLen(ForecastName));
        ExcludeForecastBefore := GetOptionalDate(RequestJson, 'excludeForecastBefore');
        NoPlanningResiliency := GetBoolean(RequestJson, 'noPlanningResiliency', false);

        RequisitionLine.SetLoadFields("Worksheet Template Name", "Journal Batch Name", "Line No.");
        RequisitionLine.SetRange("Worksheet Template Name", WorksheetTemplateName);
        RequisitionLine.SetRange("Journal Batch Name", WorksheetName);
        if RequisitionLine.IsEmpty() then
            Error(WorksheetNotFoundErr, WorksheetName, WorksheetTemplateName);

        CalculatePlanReport.SetTemplAndWorksheet(WorksheetTemplateName, WorksheetName, Regenerative);
        CalculatePlanReport.InitializeRequest(FromDate, ToDate, RespectPlanningParameters, MPS, MRP, ForecastName, ExcludeForecastBefore, NoPlanningResiliency);
        CalculatePlanReport.RunModal();

        RequisitionLine.Reset();
        RequisitionLine.SetLoadFields("Worksheet Template Name", "Journal Batch Name", "Line No.");
        RequisitionLine.SetRange("Worksheet Template Name", WorksheetTemplateName);
        RequisitionLine.SetRange("Journal Batch Name", WorksheetName);
        PlanningLinesCount := RequisitionLine.Count();

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('worksheetTemplateName', WorksheetTemplateName);
        ResponseJson.Add('worksheetName', WorksheetName);
        ResponseJson.Add('planningLinesCount', PlanningLinesCount);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure GetRequiredText(RequestJson: JsonObject; PropertyName: Text): Text
    var
        RequestToken: JsonToken;
    begin
        if not RequestJson.Get(PropertyName, RequestToken) then
            Error(RequiredParameterErr, PropertyName);
        if not RequestToken.IsValue() then
            Error(RequiredParameterErr, PropertyName);
        exit(RequestToken.AsValue().AsText());
    end;

    local procedure GetCode10(RequestJson: JsonObject; PropertyName: Text) ResultCode: Code[10]
    var
        TextValue: Text;
    begin
        TextValue := GetRequiredText(RequestJson, PropertyName);
        if StrLen(TextValue) > MaxStrLen(ResultCode) then
            Error(ParameterTooLongErr, PropertyName, MaxStrLen(ResultCode));
        ResultCode := CopyStr(TextValue, 1, MaxStrLen(ResultCode));
    end;

    local procedure GetOptionalText(RequestJson: JsonObject; PropertyName: Text): Text
    var
        RequestToken: JsonToken;
    begin
        if not RequestJson.Get(PropertyName, RequestToken) then
            exit('');
        if not RequestToken.IsValue() then
            exit('');
        exit(RequestToken.AsValue().AsText());
    end;

    local procedure GetRequiredDate(RequestJson: JsonObject; PropertyName: Text) ResultDate: Date
    var
        RequestToken: JsonToken;
        DateText: Text;
    begin
        if not RequestJson.Get(PropertyName, RequestToken) then
            Error(InvalidDateErr, PropertyName);
        if not RequestToken.IsValue() then
            Error(InvalidDateErr, PropertyName);
        DateText := RequestToken.AsValue().AsText();
        if not Evaluate(ResultDate, DateText, 9) then
            Error(InvalidDateErr, PropertyName);
        if ResultDate = 0D then
            Error(InvalidDateErr, PropertyName);
    end;

    local procedure GetOptionalDate(RequestJson: JsonObject; PropertyName: Text) ResultDate: Date
    var
        RequestToken: JsonToken;
        DateText: Text;
    begin
        if not RequestJson.Get(PropertyName, RequestToken) then
            exit(0D);
        if not RequestToken.IsValue() then
            exit(0D);
        DateText := RequestToken.AsValue().AsText();
        if DateText = '' then
            exit(0D);
        if not Evaluate(ResultDate, DateText, 9) then
            Error(InvalidDateErr, PropertyName);
    end;

    local procedure GetBoolean(RequestJson: JsonObject; PropertyName: Text; DefaultValue: Boolean): Boolean
    var
        RequestToken: JsonToken;
    begin
        if not RequestJson.Get(PropertyName, RequestToken) then
            exit(DefaultValue);
        if not RequestToken.IsValue() then
            exit(DefaultValue);
        exit(RequestToken.AsValue().AsBoolean());
    end;

    local procedure DateParameter(PropertyName: Text; IsRequired: Boolean; DescriptionText: Text) Parameter: JsonObject
    begin
        Parameter.Add('name', PropertyName);
        Parameter.Add('type', 'string');
        Parameter.Add('format', 'date');
        Parameter.Add('required', IsRequired);
        Parameter.Add('description', DescriptionText);
    end;

    local procedure BooleanParameter(PropertyName: Text; DefaultValue: Boolean; DescriptionText: Text) Parameter: JsonObject
    begin
        Parameter.Add('name', PropertyName);
        Parameter.Add('type', 'boolean');
        Parameter.Add('required', false);
        Parameter.Add('default', DefaultValue);
        Parameter.Add('description', DescriptionText);
    end;
}