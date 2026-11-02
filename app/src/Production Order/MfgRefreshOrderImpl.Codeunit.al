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
        Contract: Codeunit "Mfg Action Contract ori";
        AmbiguousOrderErr: Label 'The number identifies more than one active production order. Use an unambiguous order number.', Comment = 'is-IS=Númerið auðkennir fleiri en eina virka framleiðslupöntun. Notaðu ótvírætt pöntunarnúmer.';
        ProductionOrderNotFoundErr: Label 'Production order %1 was not found.', Comment = '%1 = production order number||is-IS=Framleiðslupöntun %1 fannst ekki.';
        InvalidStatusErr: Label 'newStatus must be Firm Planned, Released, or Finished.', Comment = 'is-IS=newStatus verður að vera Firm Planned, Released eða Finished.';
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
        Parameters.Add(ContractMgt.Parameter('productionOrderNo', 'string', true, 'The number must identify exactly one non-finished order. May be supplied as the subject instead.'));
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
        ResponseField: JsonObject;
    begin
        ResponseField.Add('name', 'status');
        ResponseField.Add('type', 'string');
        ResponseField.Add('description', 'Success when the production order was refreshed.');
        Fields.Add(ResponseField);
        Clear(ResponseField);
        ResponseField.Add('name', 'productionOrderNo');
        ResponseField.Add('type', 'string');
        ResponseField.Add('description', 'The refreshed production order number.');
        Fields.Add(ResponseField);
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Describes errors returned by the operation.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        Contract.Errors(Errors);
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
    begin
        Steps.Add(ContractMgt.WorkflowStep('Manufacturing.ProductionOrder.Refresh', 'Refresh calculated lines, replan dependent demand, or change the order status after reviewing its current state.'));
        Steps.Add(ContractMgt.WorkflowStep('Manufacturing.ProductionOrder.Replan', 'Refresh calculated lines, replan dependent demand, or change the order status after reviewing its current state.'));
        Steps.Add(ContractMgt.WorkflowStep('Manufacturing.ProductionOrder.ChangeStatus', 'Refresh calculated lines, replan dependent demand, or change the order status after reviewing its current state.'));
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
        Notes := 'Omit Commit is refused with PreconditionFailed before any write because standard Business Central actions may commit. Refresh, replan, and cost updates use Microsoft processing reports without showing a request page. UpdateCost defaults to one BOM level and leaves reservations unchanged. ChangeStatus uses Microsoft''s status-management codeunit; postingDate defaults to the work date. Replan may change dependent orders at lower BOM levels.';
        exit(true);
    end;

    /// <summary>Returns the inbound message direction.</summary>
    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    trigger OnRun()
    begin
        // Refresh Production Order requires Update isolation. Select it before
        // the first database access; the platform cannot promote an active transaction.
        Database.CurrentTransactionType(TransactionType::Update);
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
        ProductionOrderLine: Record "Prod. Order Line";
        ChangedProductionOrder: Record "Production Order";
        RefreshOrderReport: Report "Refresh Production Order";
        ReplanOrderReport: Report "Replan Production Order";
        UpdateUnitCostReport: Report "Update Unit Cost";
        StatusManagement: Codeunit "Prod. Order Status Management";
        ResponseJson: JsonObject;
        ProductionOrderNo: Code[20];
        ProductionOrderNoText: Text;
        StatusText: Text;
        AllowedKeys: Text;
        NewStatus: Enum "Production Order Status";
        PostingDate: Date;
        UpdateUnitCost: Boolean;
        FinishOrderWithoutOutput: Boolean;
        MultipleLevels: Boolean;
        UpdateReservations: Boolean;
        CalculationMethod: Option "One Level","All Levels";
    begin
        AllowedKeys := '|productionOrderNo|';
        case Argument.Type of
            Enum::"Message Type ori"::"Manufacturing.ProductionOrder.ChangeStatus":
                AllowedKeys += '|newStatus|postingDate|updateUnitCost|finishOrderWithoutOutput|';
            Enum::"Message Type ori"::"Manufacturing.ProductionOrder.UpdateCost":
                AllowedKeys += '|multipleLevels|updateReservations|';
        end;
        if not Contract.ValidateKeys(Argument, AllowedKeys) then
            exit;
        if not Contract.ReadCode(Argument, 'productionOrderNo', Argument.Subject, MaxStrLen(ProductionOrderNo), ProductionOrderNoText) then
            exit;
        ProductionOrderNo := CopyStr(ProductionOrderNoText, 1, MaxStrLen(ProductionOrderNo));
        if Argument.Type = Enum::"Message Type ori"::"Manufacturing.ProductionOrder.ChangeStatus" then begin
            if not Contract.ReadCode(Argument, 'newStatus', '', 20, StatusText) then
                exit;
            case UpperCase(StatusText) of
                FirmPlannedStatusTok:
                    NewStatus := NewStatus::"Firm Planned";
                ReleasedStatusTok:
                    NewStatus := NewStatus::Released;
                FinishedStatusTok:
                    NewStatus := NewStatus::Finished;
                else begin
                    Contract.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, 'newStatus', InvalidStatusErr);
                    exit;
                end;
            end;
            if not Contract.ReadDate(Argument, 'postingDate', PostingDate) then
                exit;
            if not Contract.ReadBoolean(Argument, 'updateUnitCost', UpdateUnitCost) then
                exit;
            if not Contract.ReadBoolean(Argument, 'finishOrderWithoutOutput', FinishOrderWithoutOutput) then
                exit;
        end;
        if Argument.Type = Enum::"Message Type ori"::"Manufacturing.ProductionOrder.UpdateCost" then begin
            if not Contract.ReadBoolean(Argument, 'multipleLevels', MultipleLevels) then
                exit;
            if not Contract.ReadBoolean(Argument, 'updateReservations', UpdateReservations) then
                exit;
        end;
        if not Contract.HasPermission(Argument, ProductionOrder.ReadPermission(), ProductionOrder.WritePermission()) then
            exit;
        if not Contract.HasPermission(Argument, ProductionOrderLine.ReadPermission(), ProductionOrderLine.WritePermission()) then
            exit;

        // Configure request pages before entering the locked write transaction.
        // Keep request-page setup outside the transaction that protects the order.
        case Argument.Type of
            Enum::"Message Type ori"::"Manufacturing.ProductionOrder.Refresh":
                begin
                    RefreshOrderReport.UseRequestPage(false);
                    RefreshOrderReport.InitializeRequest(1, true, true, true, false);
                    RefreshOrderReport.SetHideValidationDialog(true);
                end;
            Enum::"Message Type ori"::"Manufacturing.ProductionOrder.Replan":
                begin
                    ReplanOrderReport.UseRequestPage(false);
                    ReplanOrderReport.InitializeRequest(1, 1);
                end;
            Enum::"Message Type ori"::"Manufacturing.ProductionOrder.UpdateCost":
                begin
                    UpdateUnitCostReport.UseRequestPage(false);
                    if MultipleLevels then
                        CalculationMethod := CalculationMethod::"All Levels";
                    UpdateUnitCostReport.InitializeRequest(CalculationMethod, UpdateReservations);
                end;
        end;

        // Read the actual composite-key record under the transaction lock. A number alone
        // must resolve to exactly one active order; a finished order is never refreshed.
        ProductionOrder.LockTable();
        ProductionOrder.SetRange("No.", ProductionOrderNo);
        ProductionOrder.SetFilter(Status, '<>%1', ProductionOrder.Status::Finished);
        if ProductionOrder.IsEmpty() then begin
            Contract.Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'productionOrderNo', StrSubstNo(ProductionOrderNotFoundErr, ProductionOrderNo));
            exit;
        end;
        if ProductionOrder.Count() <> 1 then begin
            Contract.Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'productionOrderNo', AmbiguousOrderErr);
            exit;
        end;
        ProductionOrder.FindFirst();
        ProductionOrder.SetRecFilter();
        if not Contract.RequireCommittingCall(Argument) then
            exit;
        case Argument.Type of
            Enum::"Message Type ori"::"Manufacturing.ProductionOrder.ChangeStatus":
                begin
                    StatusManagement.SetFinishOrderWithoutOutput(FinishOrderWithoutOutput);
                    StatusManagement.ChangeProdOrderStatus(ProductionOrder, ChangedProductionOrder, NewStatus, PostingDate, UpdateUnitCost);
                    ProductionOrderNo := ChangedProductionOrder."No.";
                end;
            Enum::"Message Type ori"::"Manufacturing.ProductionOrder.Replan":
                begin
                    ReplanOrderReport.SetTableView(ProductionOrder);
                    ReplanOrderReport.RunModal();
                end;
            Enum::"Message Type ori"::"Manufacturing.ProductionOrder.UpdateCost":
                begin
                    UpdateUnitCostReport.SetTableView(ProductionOrder);
                    UpdateUnitCostReport.RunModal();
                end;
            else
                begin
                    RefreshOrderReport.SetTableView(ProductionOrder);
                    RefreshOrderReport.RunModal();
                end;
        end;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('productionOrderNo', ProductionOrderNo);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure CreateStatusChangeData() Data: JsonObject
    begin
        Data.Add('newStatus', 'Released');
        Data.Add('updateUnitCost', false);
    end;

}
