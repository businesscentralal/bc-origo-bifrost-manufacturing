namespace Origo.Bifrost.Manufacturing;

using Microsoft.Foundation.Navigate;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Requisition;
using Microsoft.Manufacturing.Document;
using Origo.Bifrost;

/// <summary>
/// Implements Manufacturing.Planning.CarryOutProduction using Microsoft's manufacturing carry-out codeunit.
/// </summary>
codeunit 10077055 "Mfg Plan Carryout Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    TableNo = "Message Argument ori";

    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        WorksheetParameterErr: Label 'Provide a valid %1.', Comment = '%1 = parameter name||is-IS=Tilgreindu gilt gildi fyrir %1.';
        LineNoRequiredErr: Label 'Provide a positive lineNo.', Comment = 'is-IS=Tilgreindu jákvætt lineNo.';
        ProductionOnlyErr: Label 'Requisition line %1 is not a production-order proposal.', Comment = '%1 = worksheet line number||is-IS=Áætlunarlína %1 er ekki tillaga að framleiðslupöntun.';
        InvalidChoiceErr: Label 'productionOrderChoice must be Planned or Firm Planned.', Comment = 'is-IS=productionOrderChoice verður að vera Planned eða Firm Planned.';
        PlannedChoiceTok: Label 'PLANNED', Locked = true;
        FirmPlannedChoiceTok: Label 'FIRM PLANNED', Locked = true;
        DescriptionLbl: Label 'Creates a Planned or Firm Planned production order from one selected production proposal line.', MaxLength = 250, Comment = 'is-IS=Stofnar áætlaða eða fasta áætlaða framleiðslupöntun úr einni valinni tillögulínu.';

    /// <summary>Reports whether production planning carry-out is available.</summary>
    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    /// <summary>Returns the requisition line table used to filter this operation.</summary>
    procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Requisition Line");
    end;

    /// <summary>Describes the production proposal carry-out operation.</summary>
    procedure GetDescription() Description: Text[250]
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns search terms for production planning carry-out.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'planning worksheet, carry out, create production order, planned order, firm planned order', Comment = 'is-IS=áætlunarblað, framkvæma, stofna framleiðslupöntun, áætluð pöntun, föst áætluð pöntun';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Explains the operation's data-changing effect when a caller selects it.</summary>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Creates a production order from one planning line. Choose Planned or Firm Planned and verify the source line before running.', Comment = 'is-IS=Stofnar framleiðslupöntun úr einni áætlunarlínu. Veldu Planned eða Firm Planned og staðfestu upprunalínuna áður en aðgerðin er keyrð.';
    begin
        exit(SelectionLbl);
    end;

    /// <summary>Describes the request envelope.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
    begin
        Subject.Add('use', 'notUsed');
        Subject.Add('description', 'The subject is not used. Identify the planning line in data.');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    /// <summary>Describes the planning worksheet line target.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        Target.Add(ContractMgt.TargetEntry('data.lineNo', 'requisition line number', 'Used with worksheetTemplateName and worksheetName.'));
        exit(true);
    end;

    /// <summary>Describes the planning worksheet line and production-order choice.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        AllowedChoices: JsonArray;
        ChoiceParameter: JsonObject;
    begin
        Parameters.Add(ContractMgt.Parameter('worksheetTemplateName', 'string', true, 'Planning worksheet template containing the selected line.'));
        Parameters.Add(ContractMgt.Parameter('worksheetName', 'string', true, 'Planning worksheet batch containing the selected line.'));
        Parameters.Add(ContractMgt.Parameter('lineNo', 'integer', true, 'Line No. of the production-order proposal to carry out.'));
        AllowedChoices.Add('Planned');
        AllowedChoices.Add('Firm Planned');
        ChoiceParameter.Add('name', 'productionOrderChoice');
        ChoiceParameter.Add('type', 'string');
        ChoiceParameter.Add('required', true);
        ChoiceParameter.Add('allowed', AllowedChoices);
        ChoiceParameter.Add('description', 'Production order status to create.');
        Parameters.Add(ChoiceParameter);
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
        ResponseField.Add('description', 'Success when the production order was created.');
        Fields.Add(ResponseField);
        Clear(ResponseField);
        ResponseField.Add('name', 'worksheetTemplateName');
        ResponseField.Add('type', 'string');
        ResponseField.Add('description', 'The source worksheet template.');
        Fields.Add(ResponseField);
        Clear(ResponseField);
        ResponseField.Add('name', 'worksheetName');
        ResponseField.Add('type', 'string');
        ResponseField.Add('description', 'The source worksheet batch.');
        Fields.Add(ResponseField);
        Clear(ResponseField);
        ResponseField.Add('name', 'lineNo');
        ResponseField.Add('type', 'integer');
        ResponseField.Add('description', 'The source requisition line carried out.');
        Fields.Add(ResponseField);
        Clear(ResponseField);
        ResponseField.Add('name', 'createdDocumentCount');
        ResponseField.Add('type', 'integer');
        ResponseField.Add('description', 'The number of created-document records reported by Microsoft.');
        Fields.Add(ResponseField);
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Describes invalid worksheet line and choice errors.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ErrorInfo: JsonObject;
    begin
        ErrorInfo.Add('error', 'Invalid production planning line.');
        ErrorInfo.Add('when', 'The selected line is missing or is not a production-order proposal.');
        ErrorInfo.Add('fix', 'Check worksheetTemplateName, worksheetName, lineNo, and productionOrderChoice.');
        Errors.Add(ErrorInfo);
        exit(true);
    end;

    /// <summary>Describes the production order created by this operation.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Creates one or more production orders from the selected planning line.');
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

    /// <summary>Describes the planning proposal carry-out workflow.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Steps: JsonArray;
        WorkflowStep: JsonObject;
    begin
        WorkflowStep.Add('messageType', 'Manufacturing.Planning.CalculatePlan then Manufacturing.Planning.CarryOutProduction');
        WorkflowStep.Add('purpose', 'Calculate and review planning proposals, then carry out a selected production line.');
        Steps.Add(WorkflowStep);
        Workflow.Add('steps', Steps);
        exit(true);
    end;

    /// <summary>Provides a representative production planning carry-out request and response.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        RequestData: JsonObject;
        Request: JsonObject;
        Response: JsonObject;
        Example: JsonObject;
    begin
        RequestData.Add('worksheetTemplateName', 'X-PLAN');
        RequestData.Add('worksheetName', 'X-DEFAULT');
        RequestData.Add('lineNo', 10000);
        RequestData.Add('productionOrderChoice', 'Firm Planned');
        Request.Add('type', 'Manufacturing.Planning.CarryOutProduction');
        Request.Add('data', RequestData);
        Response.Add('status', 'Success');
        Response.Add('worksheetTemplateName', 'X-PLAN');
        Response.Add('worksheetName', 'X-DEFAULT');
        Response.Add('lineNo', 10000);
        Response.Add('createdDocumentCount', 1);
        Example.Add('title', 'Create a firm planned order');
        Example.Add('request', Request);
        Example.Add('response', Response);
        Examples.Add(Example);
        exit(true);
    end;

    /// <summary>Explains when to carry out a production proposal.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Creates a Planned or Firm Planned production order from one selected production-order proposal line in the Requisition Line table.';
        exit(true);
    end;

    /// <summary>Documents important behavior of production planning carry-out.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Only production-order requisition lines can be carried out by this message. Each call processes one line; the Microsoft carry-out routine determines the resulting order details.';
        exit(true);
    end;

    /// <summary>Returns the inbound message direction.</summary>
    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    trigger OnRun()
    begin
        PerformCarryOut(Rec);
    end;

    /// <summary>Executes this message type through Bifrost Foundation.</summary>
    /// <param name="Argument">The message argument and response record.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        if Argument."Omit Commit" then begin
            PerformCarryOut(Argument);
            exit;
        end;

        if not Codeunit.Run(Codeunit::"Mfg Plan Carryout Impl ori", Argument) then
            Argument.RespondWithLastError();
    end;

    local procedure PerformCarryOut(var Argument: Record "Message Argument ori")
    var
        RequisitionLine: Record "Requisition Line";
        TempDocumentEntry: Record "Document Entry" temporary;
        MfgCarryOutAction: Codeunit "Mfg. Carry Out Action";
        CarryOutActionSender: Codeunit "Carry Out Action";
        RequestJson: JsonObject;
        RequestToken: JsonToken;
        ResponseJson: JsonObject;
        WorksheetTemplateName: Code[10];
        WorksheetName: Code[10];
        LineNo: Integer;
        ProductionOrderChoiceText: Text;
        ProductionOrderChoice: Enum "Planning Create Prod. Order";
    begin
        RequestJson := Argument.GetRequestJson();
        WorksheetTemplateName := GetCode10(RequestJson, 'worksheetTemplateName');
        WorksheetName := GetCode10(RequestJson, 'worksheetName');
        if not RequestJson.Get('lineNo', RequestToken) then
            Error(LineNoRequiredErr);
        if not Evaluate(LineNo, RequestToken.AsValue().AsText(), 9) then
            Error(LineNoRequiredErr);
        if LineNo <= 0 then
            Error(LineNoRequiredErr);
        if not RequestJson.Get('productionOrderChoice', RequestToken) then
            Error(InvalidChoiceErr);
        ProductionOrderChoiceText := UpperCase(RequestToken.AsValue().AsText());
        case ProductionOrderChoiceText of
            PlannedChoiceTok:
                ProductionOrderChoice := ProductionOrderChoice::Planned;
            FirmPlannedChoiceTok:
                ProductionOrderChoice := ProductionOrderChoice::"Firm Planned";
            else
                Error(InvalidChoiceErr);
        end;

        RequisitionLine.SetLoadFields("Worksheet Template Name", "Journal Batch Name", "Line No.", "Replenishment System");
        if not RequisitionLine.Get(WorksheetTemplateName, WorksheetName, LineNo) then
            Error(WorksheetParameterErr, 'lineNo');
        if RequisitionLine."Replenishment System" <> Enum::"Replenishment System"::"Prod. Order" then
            Error(ProductionOnlyErr, LineNo);

        if not MfgCarryOutAction.CarryOutActionsFromProdOrder(RequisitionLine, ProductionOrderChoice, '', '', TempDocumentEntry, CarryOutActionSender) then
            Error(ProductionOnlyErr, LineNo);

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('worksheetTemplateName', WorksheetTemplateName);
        ResponseJson.Add('worksheetName', WorksheetName);
        ResponseJson.Add('lineNo', LineNo);
        ResponseJson.Add('createdDocumentCount', TempDocumentEntry.Count());
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure GetCode10(RequestJson: JsonObject; PropertyName: Text) ResultCode: Code[10]
    var
        RequestToken: JsonToken;
        TextValue: Text;
    begin
        if not RequestJson.Get(PropertyName, RequestToken) then
            Error(WorksheetParameterErr, PropertyName);
        if not RequestToken.IsValue() then
            Error(WorksheetParameterErr, PropertyName);
        TextValue := RequestToken.AsValue().AsText();
        if StrLen(TextValue) > MaxStrLen(ResultCode) then
            Error(WorksheetParameterErr, PropertyName);
        ResultCode := CopyStr(TextValue, 1, MaxStrLen(ResultCode));
    end;
}