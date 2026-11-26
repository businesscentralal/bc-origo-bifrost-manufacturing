namespace Origo.Bifrost.Manufacturing;

using Origo.Bifrost;

/// <summary>Single source for the English Create and Refresh contract chapters.</summary>
codeunit 10077040 "Mfg ProdOrder Contract ori"
{
    Access = Internal;

    /// <summary>Declares JSON version 1.0 data requests; subject is not used.</summary>
    internal procedure GetEnvelope(IsCreate: Boolean; var Envelope: JsonObject)
    var
        Subject: JsonObject;
    begin
        Subject.Add('use', 'notUsed');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
    end;

    /// <summary>Describes the source item or the production order identity.</summary>
    internal procedure GetTarget(IsCreate: Boolean; var Target: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        if IsCreate then
            Target.Add(Contract.TargetEntry('data.sourceNo', 'item no.', 'The item to manufacture.'))
        else begin
            Target.Add(Contract.TargetEntry('data.no', 'document no.', 'The order number; optionally narrow it with productionOrderStatus.'));
            Target.Add(Contract.TargetEntry('data.systemId', 'guid', 'The production order SystemId. Supplied identifiers must agree.'));
        end;
    end;

    /// <summary>Lists the accepted Create data keys and their rules.</summary>
    internal procedure GetCreateParameters(var Parameters: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(Contract.Parameter('sourceNo', 'string', true, 'Item number. Source type is Item only.'));
        Parameters.Add(Contract.Parameter('quantity', 'number', true, 'Positive quantity in the item base unit of measure.'));
        Parameters.Add(Contract.Parameter('status', 'string', false, 'Planned (default) or FirmPlanned. Released is refused; use ChangeStatus after Refresh.'));
        Parameters.Add(Contract.Parameter('dueDate', 'string', false, 'ISO date yyyy-mm-dd. Default is the session work date.'));
        Parameters.Add(Contract.Parameter('variantCode', 'string', false, 'Optional item variant, at most 10 characters.'));
        Parameters.Add(Contract.Parameter('description', 'string', false, 'Optional description, at most 100 characters. Default is the item description.'));
        Parameters.Add(Contract.Parameter('locationCode', 'string', false, 'Optional location, at most 10 characters.'));
        Parameters.Add(Contract.Parameter('binCode', 'string', false, 'Optional bin at the location, at most 20 characters.'));
        Parameters.Add(Contract.Parameter('no', 'string', false, 'Optional manual order number, at most 20 characters. The number series must allow manual numbers.'));
    end;

    /// <summary>Lists the accepted Refresh data keys and their rules.</summary>
    internal procedure GetRefreshParameters(var Parameters: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(Contract.Parameter('no', 'string', false, 'Order number; required unless systemId is supplied. More than one matching status is AmbiguousRecord.'));
        Parameters.Add(Contract.Parameter('systemId', 'string', false, 'Order SystemId GUID; required unless no is supplied. Every supplied identifier must agree.'));
        Parameters.Add(Contract.Parameter('productionOrderStatus', 'string', false, 'Optional lookup status: Simulated, Planned or FirmPlanned.'));
        Parameters.Add(Contract.Parameter('direction', 'string', false, 'Forward or Backward. Default Backward.'));
        Parameters.Add(Contract.Parameter('calculateLines', 'boolean', false, 'Default true: deletes and recalculates lines. Requires both other calculation flags true.'));
        Parameters.Add(Contract.Parameter('calculateRoutings', 'boolean', false, 'Default true: recalculate routing lines.'));
        Parameters.Add(Contract.Parameter('calculateComponents', 'boolean', false, 'Default true: recalculate components.'));
    end;

    /// <summary>Documents response fields and nested refreshed line summaries.</summary>
    internal procedure GetResponse(IsCreate: Boolean; var Response: JsonObject)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
        Children: JsonArray;
        LineField: JsonObject;
    begin
        Fields.Add(Contract.ResponseField('status', 'string', 'Success; refusals use the standard Error envelope.'));
        Fields.Add(Contract.ResponseField('productionOrderStatus', 'string', 'Invariant status name: Simulated, Planned or FirmPlanned.'));
        Fields.Add(Contract.ResponseField('no', 'string', 'Production order number.'));
        Fields.Add(Contract.ResponseField('systemId', 'string', 'Production order SystemId. It changes on a later status change.'));
        Fields.Add(Contract.ResponseField('quantity', 'number', 'Order quantity.'));
        Fields.Add(Contract.ResponseField('dueDate', 'string', 'Due date as yyyy-mm-dd.'));
        if IsCreate then begin
            Fields.Add(Contract.ResponseField('sourceNo', 'string', 'Source item number.'));
            Fields.Add(Contract.ResponseField('linesCreated', 'integer', 'Always 0; call Refresh to create the lines.'));
            Fields.Add(Contract.ResponseField('nextStep', 'string', 'Localized guidance to call Manufacturing.ProductionOrder.Refresh.'));
        end else begin
            Fields.Add(Contract.ResponseField('direction', 'string', 'Forward or Backward.'));
            Fields.Add(Contract.ResponseField('startingDate', 'string', 'Calculated start date as yyyy-mm-dd.'));
            Fields.Add(Contract.ResponseField('endingDate', 'string', 'Calculated end date as yyyy-mm-dd.'));
            Children.Add(Contract.ResponseField('lineNo', 'integer', 'Production order line number.'));
            Children.Add(Contract.ResponseField('itemNo', 'string', 'Item number on the line.'));
            Children.Add(Contract.ResponseField('quantity', 'number', 'Line quantity.'));
            Children.Add(Contract.ResponseField('routingNo', 'string', 'Routing number on the line.'));
            Children.Add(Contract.ResponseField('productionBomNo', 'string', 'Production BOM number on the line.'));
            LineField := Contract.ResponseField('lines', 'array', 'Current lines after refresh.');
            LineField.Add('children', Children);
            Fields.Add(LineField);
            Fields.Add(Contract.ResponseField('routingLineCount', 'integer', 'Actual routing line count for this order and status.'));
            Fields.Add(Contract.ResponseField('componentCount', 'integer', 'Actual component count for this order and status.'));
        end;
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
    end;

    /// <summary>Declares refusals; Foundation adds Retryable for the write effect.</summary>
    internal procedure GetErrors(IsCreate: Boolean; var Errors: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'A required parameter is absent.', 'Supply the required parameter.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'A value, status or calculation combination is not allowed.', 'Use the parameter values in this contract.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'A JSON type, date or GUID is invalid.', 'Correct the JSON type and format.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The item or production order does not exist.', 'Read the record with Data.Records.Get first.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::AmbiguousRecord, 'An order number exists under more than one status.', 'Send productionOrderStatus or systemId.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, 'Identifiers name different orders or statuses.', 'Send identifiers belonging to the same order.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The item is blocked, numbering is missing, or refresh is requested for Released or Finished.', 'Correct the named precondition; refresh planning orders before release.'));
        if not IsCreate then
            Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'Refresh always commits; Omit Commit is refused before any write.', 'Run Refresh as a separate committing operation without Omit Commit.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, 'An undeclared key was supplied.', 'Remove the unknown key.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MultipleErrors, 'Several request problems were collected; nothing was changed.', 'Correct every error entry before retrying.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Business Central rejected the operation, including BOM, routing, numbering or duplicate number checks.', 'Correct the field or setup named in the returned BC text.'));
    end;

    /// <summary>Declares non-idempotent writes without posting.</summary>
    internal procedure GetEffect(IsCreate: Boolean; var Effect: JsonObject)
    var
        Preconditions: JsonArray;
    begin
        Effect.Add('effect', 'write');
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', 'BIFROST Mfg ori');
        if IsCreate then begin
            Effect.Add('changes', 'Inserts one Planned or FirmPlanned production order header. Does not create lines or post entries.');
            Preconditions.Add('An unblocked item and a configured production order number series.');
        end else begin
            Effect.Add('changes', 'Recalculates and commits lines, routing and components with the standard BC refresh report.');
            Preconditions.Add('Omit Commit must be false: Refresh always commits.');
            Preconditions.Add('The order is Simulated, Planned or FirmPlanned, with a due date and certified BOM/routing when assigned.');
        end;
        Preconditions.Add('The caller has native permissions on the affected records.');
        Effect.Add('preconditions', Preconditions);
    end;

    /// <summary>Names the other lifecycle operations without duplicating generic reads and edits.</summary>
    internal procedure GetRelated(IsCreate: Boolean; var Related: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        if IsCreate then
            Related.Add(Contract.RelatedEntry('Manufacturing.ProductionOrder.Refresh', 'Calculate the new header lines, routing and components.'))
        else
            Related.Add(Contract.RelatedEntry('Manufacturing.ProductionOrder.Create', 'Create a planning header first.'));
        Related.Add(Contract.RelatedEntry('Data.Records.Get', 'Read production order records.'));
        Related.Add(Contract.RelatedEntry('Data.Records.Set', 'Edit ordinary production order fields with native validation.'));
    end;

    /// <summary>Explains the safe create then refresh lifecycle.</summary>
    internal procedure GetWorkflow(IsCreate: Boolean; var Workflow: JsonObject)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Steps.Add(Contract.WorkflowStep('Manufacturing.ProductionOrder.Create', 'Create a Planned or FirmPlanned order header.'));
        Steps.Add(Contract.WorkflowStep('Manufacturing.ProductionOrder.Refresh', 'Calculate and inspect the production plan before releasing the order.'));
        Workflow.Add('steps', Steps);
        Workflow.Add('text', 'Release is a separate Manufacturing.ProductionOrder.ChangeStatus operation. Re-read identity after a status change.');
    end;

    /// <summary>Provides a data payload example for each operation.</summary>
    internal procedure GetExamples(IsCreate: Boolean; var Examples: JsonArray)
    var
        Example: JsonObject;
        Request: JsonObject;
        Data: JsonObject;
    begin
        if IsCreate then begin
            Example.Add('title', 'Create a planned order for a configured item');
            Request.Add('type', 'Manufacturing.ProductionOrder.Create');
            Data.Add('sourceNo', 'X-MANUFACTURED');
            Data.Add('quantity', 10);
        end else begin
            Example.Add('title', 'Refresh an order using the SystemId returned by Create');
            Request.Add('type', 'Manufacturing.ProductionOrder.Refresh');
            Data.Add('systemId', '01234567-89ab-cdef-0123-456789abcdef');
            Data.Add('direction', 'Backward');
        end;
        Request.Add('data', Data);
        Example.Add('request', Request);
        Examples.Add(Example);
    end;

    /// <summary>States what the operation changes.</summary>
    internal procedure GetOverview(IsCreate: Boolean; var Overview: Text)
    begin
        if IsCreate then
            Overview := 'Creates a Planned or FirmPlanned production order for one item using Business Central numbering and validation.'
        else
            Overview := 'Recalculates a planning production order with the standard Business Central refresh report.';
    end;

    /// <summary>Documents transaction and status limitations.</summary>
    internal procedure GetNotes(IsCreate: Boolean; var Notes: Text)
    begin
        if IsCreate then
            Notes := 'Create does not post. Under Omit Commit the caller owns the transaction and must roll back on a raised BC error. '
        else
            Notes := 'Refresh always commits: the standard BC report commits internally. Omit Commit is refused with PreconditionFailed before any write. ' +
                'Run Refresh as a separate committing operation, never as part of a caller rollback transaction. ' +
                'Refresh does not post. Released refresh is refused because the BC report can flush output and consumption. ' +
                'calculateLines=true replaces existing lines and requires routing and component calculation. ';
        Notes += 'The committing path catches BC errors at a Codeunit.Run boundary and returns BusinessCentralError. ' +
            'A later status change replaces the order SystemId; do not cache identity across a status change.';
    end;

    /// <summary>Declares the scheduling envelope. Chapter text stays English.</summary>
    internal procedure GetScheduleEnvelope(var Envelope: JsonObject)
    begin
        GetEnvelope(false, Envelope);
    end;

    /// <summary>Describes no or systemId plus the status parameter used by scheduling.</summary>
    internal procedure GetScheduleTarget(var Target: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Target.Add(Contract.TargetEntry('data.no', 'document no.', 'The order number. Narrow it with status when the same number exists in more than one status.'));
        Target.Add(Contract.TargetEntry('data.systemId', 'guid', 'The production order SystemId. Supplied identifiers must agree. A status change assigns a new SystemId.'));
        Target.Add(Contract.TargetEntry('data.status', 'Simulated, Planned, FirmPlanned, Released or Finished', 'Optional filter. Only FirmPlanned and Released are scheduled.'));
    end;

    /// <summary>Lists the accepted Replan data keys.</summary>
    internal procedure GetReplanParameters(var Parameters: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        AddScheduleIdentity(Parameters);
        Parameters.Add(Contract.Parameter('direction', 'string', false, 'forward or backward. Default backward. Case does not matter.'));
        Parameters.Add(Contract.Parameter('calcMethod', 'string', false, 'noLevels (default). oneLevel and allLevels are refused before anything is written.'));
        Parameters.Add(Contract.Parameter('expectedCount', 'number', true, 'Must be the JSON number 1. Missing and wrong counts change nothing.'));
    end;

    /// <summary>Lists the accepted Reschedule data keys.</summary>
    internal procedure GetRescheduleParameters(var Parameters: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        AddScheduleIdentity(Parameters);
        Parameters.Add(Contract.Parameter('direction', 'string', false, 'forward or backward. Default backward. forward requires startingDateTime. backward requires dueDate.'));
        Parameters.Add(Contract.Parameter('lineNo', 'number', false, 'Production order line number. Omit or send 0 to move the whole order.'));
        Parameters.Add(Contract.Parameter('dueDate', 'string', false, 'New due date, yyyy-mm-dd. Required for backward. Do not send it together with startingDateTime.'));
        Parameters.Add(Contract.Parameter('startingDateTime', 'string', false, 'New starting date-time in XML format. Required for forward. Do not send it together with dueDate.'));
    end;

    /// <summary>Documents the scheduling response.</summary>
    internal procedure GetScheduleResponse(IsReplan: Boolean; var Response: JsonObject)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
        BeforeDates: JsonArray;
        AfterDates: JsonArray;
        LineFields: JsonArray;
        RoutingFields: JsonArray;
        WarningFields: JsonArray;
        BeforeField: JsonObject;
        AfterField: JsonObject;
        LinesField: JsonObject;
        RoutingField: JsonObject;
        WarningsField: JsonObject;
    begin
        Fields.Add(Contract.ResponseField('status', 'string', 'Success. Refusals use the standard Error envelope.'));
        Fields.Add(Contract.ResponseField('productionOrderStatus', 'string', 'Invariant status name: FirmPlanned or Released.'));
        Fields.Add(Contract.ResponseField('no', 'string', 'Production order number.'));
        Fields.Add(Contract.ResponseField('systemId', 'string', 'Production order SystemId.'));
        Fields.Add(Contract.ResponseField('direction', 'string', 'forward or backward.'));
        if IsReplan then
            Fields.Add(Contract.ResponseField('calcMethod', 'string', 'Always noLevels.'));
        if not IsReplan then
            Fields.Add(Contract.ResponseField('lineNo', 'integer', '0 when the whole order moved; otherwise the requested line.'));
        AddDateFields(BeforeDates);
        BeforeField := Contract.ResponseField('before', 'object', 'Header dates before the change.');
        BeforeField.Add('children', BeforeDates);
        Fields.Add(BeforeField);
        AddDateFields(AfterDates);
        AfterField := Contract.ResponseField('after', 'object', 'Header dates after the change.');
        AfterField.Add('children', AfterDates);
        Fields.Add(AfterField);
        LineFields.Add(Contract.ResponseField('lineNo', 'integer', 'Production order line number.'));
        LineFields.Add(Contract.ResponseField('startingDateTime', 'string', 'Line starting date-time.'));
        LineFields.Add(Contract.ResponseField('endingDateTime', 'string', 'Line ending date-time.'));
        LineFields.Add(Contract.ResponseField('dueDate', 'string', 'Line due date as yyyy-mm-dd.'));
        LinesField := Contract.ResponseField('lines', 'array', 'Lines after the change.');
        LinesField.Add('children', LineFields);
        Fields.Add(LinesField);
        RoutingFields.Add(Contract.ResponseField('operationNo', 'string', 'Operation number.'));
        RoutingFields.Add(Contract.ResponseField('type', 'string', 'workCenter or machineCenter.'));
        RoutingFields.Add(Contract.ResponseField('no', 'string', 'Work center or machine center number.'));
        RoutingFields.Add(Contract.ResponseField('workCenterNo', 'string', 'Work center number.'));
        RoutingFields.Add(Contract.ResponseField('startingDateTime', 'string', 'Operation starting date-time.'));
        RoutingFields.Add(Contract.ResponseField('endingDateTime', 'string', 'Operation ending date-time.'));
        RoutingField := Contract.ResponseField('routingLines', 'array', 'Routing operations after the change.');
        RoutingField.Add('children', RoutingFields);
        Fields.Add(RoutingField);
        WarningFields.Add(Contract.ResponseField('code', 'string', 'dueDateBeforeToday or capacityExceeded.'));
        WarningFields.Add(Contract.ResponseField('message', 'string', 'Localized explanation.'));
        WarningsField := Contract.ResponseField('warnings', 'array', 'Always present. Empty when nothing needs attention.');
        WarningsField.Add('children', WarningFields);
        Fields.Add(WarningsField);
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
    end;

    /// <summary>Declares scheduling refusals. Foundation adds Retryable for the write effect.</summary>
    internal procedure GetScheduleErrors(IsReplan: Boolean; var Errors: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'A required parameter is absent.', 'Supply the required parameter.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'A value or combination is not allowed.', 'Use the parameter values in this contract.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'A JSON type, date, date-time or GUID is invalid.', 'Correct the JSON type and format.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, 'An undeclared key was supplied.', 'Remove the unknown key.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The production order or line does not exist.', 'Read the order with Data.Records.Get and send a valid no, systemId or lineNo.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::AmbiguousRecord, 'An order number exists under more than one status.', 'Send status or systemId.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, 'Identifiers name different orders or statuses.', 'Send identifiers belonging to the same order.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'Manufacturing write permission is missing.', 'Ask an administrator to assign BIFROST Mfg ori or BIFROST Full ori.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The order is Planned, Simulated or Finished, has posted output or consumption, has lower planning levels, or the call uses Omit Commit.', 'Refresh a planning order, or reverse posted entries, before scheduling. Run the call without Omit Commit.'));
        if IsReplan then begin
            Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'calcMethod oneLevel or allLevels is refused. No production order is deleted.', 'Send calcMethod noLevels or omit it.'));
            Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConfirmationRequired, 'expectedCount was omitted. Nothing was changed.', 'Send expectedCount 1.'));
            Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConfirmationMismatch, 'expectedCount was not 1. Nothing was changed.', 'Send expectedCount 1.'));
        end;
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MultipleErrors, 'Several request problems were collected. Nothing was changed.', 'Correct every error entry before retrying.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Business Central rejected the schedule.', 'Correct the field, calendar, BOM or routing named in the returned text.'));
    end;

    /// <summary>Declares a committing write that does not post.</summary>
    internal procedure GetScheduleEffect(IsReplan: Boolean; var Effect: JsonObject)
    var
        Preconditions: JsonArray;
    begin
        Effect.Add('effect', 'write');
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', 'BIFROST Mfg ori');
        if IsReplan then
            Effect.Add('changes', 'Recalculates routing, capacity need and component due dates on one firm planned or released production order. May rebuild that order''s own unreserved lower planning lines. Does not delete other production orders and does not post.')
        else
            Effect.Add('changes', 'Moves the due date or starting date-time of one firm planned or released production order or one of its lines. Business Central recalculates routing, capacity need and component due dates. Does not post.');
        Preconditions.Add('Omit Commit must be false. The operation always commits.');
        Preconditions.Add('The order is FirmPlanned or Released and has no posted output or consumption.');
        if IsReplan then
            Preconditions.Add('calcMethod is noLevels and expectedCount is 1.');
        Preconditions.Add('The caller has BIFROST Mfg ori or BIFROST Full ori and native permissions on the affected records.');
        Effect.Add('preconditions', Preconditions);
    end;

    /// <summary>Names the surrounding production-order operations.</summary>
    internal procedure GetScheduleRelated(IsReplan: Boolean; var Related: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(Contract.RelatedEntry('Manufacturing.ProductionOrder.Refresh', 'Calculate a Planned or FirmPlanned order before release. Released orders are not refreshed here.'));
        if IsReplan then
            Related.Add(Contract.RelatedEntry('Manufacturing.ProductionOrder.Reschedule', 'Move a due date or starting date-time without replanning from the routing times.'))
        else
            Related.Add(Contract.RelatedEntry('Manufacturing.ProductionOrder.Replan', 'Recalculate the order from its routing times at no levels.'));
        Related.Add(Contract.RelatedEntry('Manufacturing.ProductionOrder.ChangeStatus', 'Release a firm planned order. The SystemId changes.'));
        Related.Add(Contract.RelatedEntry('Data.Records.Get', 'Read production order records.'));
    end;

    /// <summary>Explains refresh, schedule, then a later date move.</summary>
    internal procedure GetScheduleWorkflow(IsReplan: Boolean; var Workflow: JsonObject)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Steps.Add(Contract.WorkflowStep('Manufacturing.ProductionOrder.Refresh', 'Calculate a planning order and inspect its routing.'));
        Steps.Add(Contract.WorkflowStep('Manufacturing.ProductionOrder.ChangeStatus', 'Release the order when it should be scheduled as Released. Read the new SystemId.'));
        if IsReplan then
            Steps.Add(Contract.WorkflowStep('Manufacturing.ProductionOrder.Replan', 'Send expectedCount 1 and calcMethod noLevels after a routing time change.'))
        else
            Steps.Add(Contract.WorkflowStep('Manufacturing.ProductionOrder.Reschedule', 'Send a new dueDate or startingDateTime for the order or one line.'));
        Workflow.Add('steps', Steps);
        Workflow.Add('text', 'Read the returned dates, routing lines and warnings. A later status change replaces the SystemId.');
    end;

    /// <summary>Provides one data payload example.</summary>
    internal procedure GetScheduleExamples(IsReplan: Boolean; var Examples: JsonArray)
    var
        Example: JsonObject;
        Request: JsonObject;
        Data: JsonObject;
    begin
        if IsReplan then begin
            Example.Add('title', 'Replan one released order backward');
            Request.Add('type', 'Manufacturing.ProductionOrder.Replan');
            Data.Add('no', 'X-REL-0001');
            Data.Add('status', 'Released');
            Data.Add('direction', 'backward');
            Data.Add('calcMethod', 'noLevels');
            Data.Add('expectedCount', 1);
        end else begin
            Example.Add('title', 'Move the due date of one released order');
            Request.Add('type', 'Manufacturing.ProductionOrder.Reschedule');
            Data.Add('no', 'X-REL-0001');
            Data.Add('status', 'Released');
            Data.Add('direction', 'backward');
            Data.Add('dueDate', '2026-12-15');
        end;
        Request.Add('data', Data);
        Example.Add('request', Request);
        Examples.Add(Example);
    end;

    /// <summary>States what scheduling changes.</summary>
    internal procedure GetScheduleOverview(IsReplan: Boolean; var Overview: Text)
    begin
        if IsReplan then
            Overview := 'Recalculates one firm planned or released production order from its routing times. Only no levels is accepted, and the call commits.'
        else
            Overview := 'Moves the due date or starting date-time of one firm planned or released production order or line. Business Central recalculates the schedule, and the call commits.';
    end;

    /// <summary>Documents transaction, confirmation and status limits.</summary>
    internal procedure GetScheduleNotes(IsReplan: Boolean; var Notes: Text)
    begin
        Notes := 'The operation always commits. Omit Commit is refused with PreconditionFailed before any write. It does not post. ';
        Notes += 'Planned and Simulated orders are refused; refresh them first. Finished orders are refused. Posted output or consumption is refused before any capacity row is removed. ';
        if IsReplan then
            Notes += 'expectedCount must be the JSON number 1. A missing count returns ConfirmationRequired and a different count returns ConfirmationMismatch; nothing is changed. ' +
                'calcMethod oneLevel and allLevels return PreconditionFailed and do not delete any production order. Only unreserved lower planning lines of this order may be rebuilt. '
        else
            Notes += 'expectedCount is not accepted. backward requires dueDate. forward requires startingDateTime. Sending both dates is refused. lineNo 0 or omitted moves the whole order. ' +
                'An order with lower planning levels is refused before any date changes. ';
        Notes += 'Business Central errors are returned as BusinessCentralError and the schedule write is rolled back. Do not cache the SystemId across a status change.';
    end;

    local procedure AddScheduleIdentity(var Parameters: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(Contract.Parameter('no', 'string', false, 'Order number, at most 20 characters. Required unless systemId is supplied.'));
        Parameters.Add(Contract.Parameter('systemId', 'string', false, 'Order SystemId. Required unless no is supplied. Every supplied identifier must agree.'));
        Parameters.Add(Contract.Parameter('status', 'string', false, 'Simulated, Planned, FirmPlanned, Released or Finished. Only FirmPlanned and Released are scheduled.'));
    end;

    local procedure AddDateFields(var DateFields: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        DateFields.Add(Contract.ResponseField('startingDate', 'string', 'Starting date as yyyy-mm-dd.'));
        DateFields.Add(Contract.ResponseField('endingDate', 'string', 'Ending date as yyyy-mm-dd.'));
        DateFields.Add(Contract.ResponseField('dueDate', 'string', 'Due date as yyyy-mm-dd.'));
        DateFields.Add(Contract.ResponseField('startingDateTime', 'string', 'Starting date-time.'));
        DateFields.Add(Contract.ResponseField('endingDateTime', 'string', 'Ending date-time.'));
    end;
}
