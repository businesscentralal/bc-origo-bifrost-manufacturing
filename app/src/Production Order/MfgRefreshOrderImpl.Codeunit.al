namespace Origo.Bifrost.Manufacturing;

using Microsoft.Manufacturing.Document;
using Origo.Bifrost;

/// <summary>
/// Implements Manufacturing.ProductionOrder.Refresh using Microsoft's Refresh Production Order report.
/// </summary>
codeunit 10077040 "Mfg Refresh Order Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    TableNo = "Message Argument ori";

    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        ProductionOrderNotFoundErr: Label 'Production order %1 was not found.', Comment = '%1 = production order number||is-IS=Framleiðslupöntun %1 fannst ekki.';
        ProductionOrderRequiredErr: Label 'Provide a production order number in the subject or data.productionOrderNo.', Comment = 'is-IS=Tilgreindu framleiðslupöntunarnúmer í subject eða data.productionOrderNo.';
        InvalidStatusErr: Label 'newStatus must be Firm Planned, Released, or Finished.', Comment = 'is-IS=newStatus verður að vera Firm Planned, Released eða Finished.';
        InvalidPostingDateErr: Label 'postingDate must be a valid ISO date in YYYY-MM-DD format.', Comment = 'is-IS=postingDate verður að vera gild dagsetning á ISO sniði ÁÁÁÁ-MM-DD.';
        DescriptionLbl: Label 'Recalculates component and routing demand for one production order by refreshing its lines or replanning dependent demand.', MaxLength = 250, Comment = 'is-IS=Endurreiknar íhluta- og leiðarþörf fyrir eina framleiðslupöntun með því að uppfæra línur hennar eða endurskipuleggja háða þörf.';
        FirmPlannedStatusTok: Label 'FIRM PLANNED', Locked = true;
        ReleasedStatusTok: Label 'RELEASED', Locked = true;
        FinishedStatusTok: Label 'FINISHED', Locked = true;

    /// <summary>Reports whether the refresh operation is available.</summary>
    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    /// <summary>Returns the production order table used to filter this operation.</summary>
    procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Production Order");
    end;

    /// <summary>Describes the production order refresh operation.</summary>
    procedure GetDescription() Description: Text[250]
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns search terms for this operation.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'production order, refresh, replan, change status, recalculate, components, routing, dependent demand', Comment = 'is-IS=framleiðslupöntun, endurlesa, endurskipuleggja, breyta stöðu, endurreikna, íhlutir, leið, háð þörf';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Explains the operation's data-changing effect when a caller selects it.</summary>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Refresh replaces calculated lines; replan recalculates dependent demand; change status may post consumption, output, or capacity. Review the order before running.', Comment = 'is-IS=Uppfærsla skiptir út reiknuðum línum; endurskipulagning endurreiknar háða þörf; stöðubreyting getur bókað notkun, afköst eða afkastagetu. Farðu yfir pöntunina áður en aðgerðin er keyrð.';
    begin
        exit(SelectionLbl);
    end;

    /// <summary>Describes the request envelope.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
        SubjectForms: JsonArray;
    begin
        Subject.Add('use', 'optional');
        SubjectForms.Add('string');
        Subject.Add('forms', SubjectForms);
        Subject.Add('description', 'Production order number. When set, it takes precedence over data.productionOrderNo.');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    /// <summary>Describes how this operation identifies the production order.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        Target.Add(ContractMgt.TargetEntry('subject', 'production order number', 'Used when the subject is set.'));
        Target.Add(ContractMgt.TargetEntry('data.productionOrderNo', 'production order number', 'Used when the subject is empty.'));
        exit(true);
    end;

    /// <summary>Describes the request parameter.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        AllowedStatuses: JsonArray;
        StatusParameter: JsonObject;
        PostingDateParameter: JsonObject;
        UpdateUnitCostParameter: JsonObject;
        FinishWithoutOutputParameter: JsonObject;
        MultipleLevelsParameter: JsonObject;
        UpdateReservationsParameter: JsonObject;
    begin
        Parameters.Add(ContractMgt.Parameter('productionOrderNo', 'string', true, 'The production order to process. May be supplied as the subject instead.'));
        AllowedStatuses.Add('Firm Planned');
        AllowedStatuses.Add('Released');
        AllowedStatuses.Add('Finished');
        StatusParameter.Add('name', 'newStatus');
        StatusParameter.Add('type', 'string');
        StatusParameter.Add('required', false);
        StatusParameter.Add('allowed', AllowedStatuses);
        StatusParameter.Add('description', 'Required only for Manufacturing.ProductionOrder.ChangeStatus.');
        Parameters.Add(StatusParameter);
        PostingDateParameter.Add('name', 'postingDate');
        PostingDateParameter.Add('type', 'string');
        PostingDateParameter.Add('required', false);
        PostingDateParameter.Add('format', 'date');
        PostingDateParameter.Add('description', 'Posting date for automatic consumption, output, and capacity. Defaults to the work date; used by ChangeStatus.');
        Parameters.Add(PostingDateParameter);
        UpdateUnitCostParameter.Add('name', 'updateUnitCost');
        UpdateUnitCostParameter.Add('type', 'boolean');
        UpdateUnitCostParameter.Add('required', false);
        UpdateUnitCostParameter.Add('default', false);
        UpdateUnitCostParameter.Add('description', 'Whether to update the produced item unit cost when changing status.');
        Parameters.Add(UpdateUnitCostParameter);
        FinishWithoutOutputParameter.Add('name', 'finishOrderWithoutOutput');
        FinishWithoutOutputParameter.Add('type', 'boolean');
        FinishWithoutOutputParameter.Add('required', false);
        FinishWithoutOutputParameter.Add('default', false);
        FinishWithoutOutputParameter.Add('description', 'Allows a Released order with no output to be finished when Manufacturing Setup permits it.');
        Parameters.Add(FinishWithoutOutputParameter);
        MultipleLevelsParameter.Add('name', 'multipleLevels');
        MultipleLevelsParameter.Add('type', 'boolean');
        MultipleLevelsParameter.Add('required', false);
        MultipleLevelsParameter.Add('default', false);
        MultipleLevelsParameter.Add('description', 'For Manufacturing.ProductionOrder.UpdateCost, recalculate costs using all BOM levels instead of one level.');
        Parameters.Add(MultipleLevelsParameter);
        UpdateReservationsParameter.Add('name', 'updateReservations');
        UpdateReservationsParameter.Add('type', 'boolean');
        UpdateReservationsParameter.Add('required', false);
        UpdateReservationsParameter.Add('default', false);
        UpdateReservationsParameter.Add('description', 'For Manufacturing.ProductionOrder.UpdateCost, update related reserved document lines.');
        Parameters.Add(UpdateReservationsParameter);
        exit(true);
    end;

    /// <summary>Describes the successful response.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Fields: JsonArray;
        Field: JsonObject;
    begin
        Field.Add('name', 'status');
        Field.Add('type', 'string');
        Field.Add('description', 'Success when the production order was refreshed.');
        Fields.Add(Field);
        Clear(Field);
        Field.Add('name', 'productionOrderNo');
        Field.Add('type', 'string');
        Field.Add('description', 'The refreshed production order number.');
        Fields.Add(Field);
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Describes errors returned by the operation.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ErrorInfo: JsonObject;
    begin
        ErrorInfo.Add('error', 'Production order not found.');
        ErrorInfo.Add('when', 'The supplied production order number does not identify an existing production order.');
        ErrorInfo.Add('fix', 'Check the number and pass it as the subject or data.productionOrderNo.');
        Errors.Add(ErrorInfo);
        Clear(ErrorInfo);
        ErrorInfo.Add('error', 'Invalid production order status.');
        ErrorInfo.Add('when', 'newStatus is missing or is not Firm Planned, Released, or Finished.');
        ErrorInfo.Add('fix', 'Pass one of the allowed values for Manufacturing.ProductionOrder.ChangeStatus.');
        Errors.Add(ErrorInfo);
        Clear(ErrorInfo);
        ErrorInfo.Add('error', 'Invalid posting date.');
        ErrorInfo.Add('when', 'postingDate is not a valid ISO date.');
        ErrorInfo.Add('fix', 'Pass postingDate as YYYY-MM-DD or omit it to use the work date.');
        Errors.Add(ErrorInfo);
        exit(true);
    end;

    /// <summary>Describes the data changed by the operation.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Recalculates production order lines, changes order status, or posts automatic consumption, output, or capacity. Replanning can create dependent orders.');
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

    /// <summary>Describes the order refresh workflow.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Steps: JsonArray;
        Step: JsonObject;
    begin
        Step.Add('messageType', 'Manufacturing.ProductionOrder.Refresh, Manufacturing.ProductionOrder.Replan, or Manufacturing.ProductionOrder.ChangeStatus');
        Step.Add('purpose', 'Refresh calculated lines, replan dependent demand, or change the order status after reviewing its current state.');
        Steps.Add(Step);
        Workflow.Add('steps', Steps);
        exit(true);
    end;

    /// <summary>Provides a representative request and response.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Request: JsonObject;
        Response: JsonObject;
        Example: JsonObject;
    begin
        Request.Add('type', 'Manufacturing.ProductionOrder.Refresh');
        Request.Add('subject', 'X-PROD-0001');
        Response.Add('status', 'Success');
        Response.Add('productionOrderNo', 'X-PROD-0001');
        Example.Add('title', 'Refresh a production order');
        Example.Add('request', Request);
        Example.Add('response', Response);
        Examples.Add(Example);

        Clear(Request);
        Clear(Response);
        Clear(Example);
        Request.Add('type', 'Manufacturing.ProductionOrder.Replan');
        Request.Add('subject', 'X-PROD-0001');
        Response.Add('status', 'Success');
        Response.Add('productionOrderNo', 'X-PROD-0001');
        Example.Add('title', 'Replan a production order');
        Example.Add('request', Request);
        Example.Add('response', Response);
        Examples.Add(Example);

        Clear(Request);
        Clear(Response);
        Clear(Example);
        Request.Add('type', 'Manufacturing.ProductionOrder.ChangeStatus');
        Request.Add('subject', 'X-PROD-0001');
        Request.Add('data', CreateStatusChangeData());
        Response.Add('status', 'Success');
        Response.Add('productionOrderNo', 'X-PROD-0001');
        Example.Add('title', 'Release a production order');
        Example.Add('request', Request);
        Example.Add('response', Response);
        Examples.Add(Example);

        Clear(Request);
        Clear(Response);
        Clear(Example);
        Request.Add('type', 'Manufacturing.ProductionOrder.UpdateCost');
        Request.Add('subject', 'X-PROD-0001');
        Response.Add('status', 'Success');
        Response.Add('productionOrderNo', 'X-PROD-0001');
        Example.Add('title', 'Recalculate a production order unit cost');
        Example.Add('request', Request);
        Example.Add('response', Response);
        Examples.Add(Example);
        exit(true);
    end;

    /// <summary>Explains when to use production order refresh.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Refresh recalculates component and routing lines. Replan recalculates dependent demand and can create lower-level orders. ChangeStatus moves an order to Firm Planned, Released, or Finished and may post automatic consumption, output, or capacity. UpdateCost recalculates production-order unit costs.';
        exit(true);
    end;

    /// <summary>Documents important behavior of the refresh operation.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Refresh, replan, and cost updates use Microsoft processing reports without showing a request page. UpdateCost defaults to one BOM level and leaves reservations unchanged. ChangeStatus uses Microsoft''s status-management codeunit; postingDate defaults to the work date. Replan may change dependent orders at lower BOM levels.';
        exit(true);
    end;

    /// <summary>Returns the inbound message direction.</summary>
    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    trigger OnRun()
    begin
        PerformRefresh(Rec);
    end;

    /// <summary>Executes this message type through Bifrost Foundation.</summary>
    /// <param name="Argument">The message argument and response record.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        if Argument."Omit Commit" then begin
            PerformRefresh(Argument);
            exit;
        end;

        if not Codeunit.Run(Codeunit::"Mfg Refresh Order Impl ori", Argument) then
            Argument.RespondWithLastError();
    end;

    local procedure PerformRefresh(var Argument: Record "Message Argument ori")
    var
        ProductionOrder: Record "Production Order";
        ProductionOrderLookup: Record "Production Order";
        RequestJson: JsonObject;
        RequestToken: JsonToken;
        ResponseJson: JsonObject;
        ProductionOrderNo: Code[20];
        ProductionOrderNoText: Text;
    begin
        RequestJson := Argument.GetRequestJson();
        ProductionOrderNoText := Argument.Subject;
        if ProductionOrderNoText = '' then begin
            if not RequestJson.Get('productionOrderNo', RequestToken) then
                Error(ProductionOrderRequiredErr);
            if not RequestToken.IsValue() then
                Error(ProductionOrderRequiredErr);
            ProductionOrderNoText := RequestToken.AsValue().AsText();
        end;
        if StrLen(ProductionOrderNoText) > MaxStrLen(ProductionOrderNo) then
            Error(ProductionOrderRequiredErr);
        ProductionOrderNo := CopyStr(ProductionOrderNoText, 1, MaxStrLen(ProductionOrderNo));

        ProductionOrderLookup.SetLoadFields("No.");
        ProductionOrderLookup.SetRange("No.", ProductionOrderNo);
        if ProductionOrderLookup.IsEmpty() then
            Error(ProductionOrderNotFoundErr, ProductionOrderNo);

        ProductionOrder.SetRange("No.", ProductionOrderNo);
        case Argument.Type of
            Enum::"Message Type ori"::"Manufacturing.ProductionOrder.ChangeStatus":
                PerformChangeStatus(ProductionOrder, RequestJson);
            Enum::"Message Type ori"::"Manufacturing.ProductionOrder.Replan":
                Report.RunModal(Report::"Replan Production Order", false, false, ProductionOrder);
            Enum::"Message Type ori"::"Manufacturing.ProductionOrder.UpdateCost":
                PerformUpdateCost(ProductionOrder, RequestJson);
            else
                Report.RunModal(Report::"Refresh Production Order", false, false, ProductionOrder);
        end;

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('productionOrderNo', ProductionOrderNo);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure PerformChangeStatus(var ProductionOrder: Record "Production Order"; RequestJson: JsonObject)
    var
        StatusManagement: Codeunit "Prod. Order Status Management";
        RequestToken: JsonToken;
        NewStatus: Enum "Production Order Status";
        StatusText: Text;
        PostingDate: Date;
        UpdateUnitCost: Boolean;
        FinishOrderWithoutOutput: Boolean;
    begin
        if not RequestJson.Get('newStatus', RequestToken) then
            Error(InvalidStatusErr);
        if not RequestToken.IsValue() then
            Error(InvalidStatusErr);
        StatusText := UpperCase(RequestToken.AsValue().AsText());
        case StatusText of
            FirmPlannedStatusTok:
                NewStatus := NewStatus::"Firm Planned";
            ReleasedStatusTok:
                NewStatus := NewStatus::Released;
            FinishedStatusTok:
                NewStatus := NewStatus::Finished;
            else
                Error(InvalidStatusErr);
        end;

        PostingDate := WorkDate();
        if RequestJson.Get('postingDate', RequestToken) then
            if not Evaluate(PostingDate, RequestToken.AsValue().AsText(), 9) then
                Error(InvalidPostingDateErr);

        if RequestJson.Get('updateUnitCost', RequestToken) then
            UpdateUnitCost := RequestToken.AsValue().AsBoolean();
        if RequestJson.Get('finishOrderWithoutOutput', RequestToken) then
            FinishOrderWithoutOutput := RequestToken.AsValue().AsBoolean();

        StatusManagement.SetFinishOrderWithoutOutput(FinishOrderWithoutOutput);
        StatusManagement.ChangeProdOrderStatus(ProductionOrder, NewStatus, PostingDate, UpdateUnitCost);
    end;

    local procedure CreateStatusChangeData() Data: JsonObject
    begin
        Data.Add('newStatus', 'Released');
        Data.Add('updateUnitCost', false);
    end;

    local procedure PerformUpdateCost(var ProductionOrder: Record "Production Order"; RequestJson: JsonObject)
    var
        UpdateUnitCostReport: Report "Update Unit Cost";
        RequestToken: JsonToken;
        CalculationMethod: Option "One Level","All Levels";
        MultipleLevels: Boolean;
        UpdateReservations: Boolean;
    begin
        if RequestJson.Get('multipleLevels', RequestToken) then
            MultipleLevels := RequestToken.AsValue().AsBoolean();
        if RequestJson.Get('updateReservations', RequestToken) then
            UpdateReservations := RequestToken.AsValue().AsBoolean();

        if MultipleLevels then
            CalculationMethod := CalculationMethod::"All Levels";
        UpdateUnitCostReport.InitializeRequest(CalculationMethod, UpdateReservations);
        UpdateUnitCostReport.SetTableView(ProductionOrder);
        UpdateUnitCostReport.RunModal();
    end;
}