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
            Effect.Add('changes', 'Recalculates lines, routing and components with the standard BC refresh report.');
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
        Notes := 'Create and Refresh do not post. Released refresh is refused because the BC report can flush output and consumption. ' +
            'calculateLines=true replaces existing lines and requires routing and component calculation. ' +
            'There is no Commit in the app path. Under Omit Commit the caller owns the transaction and must roll back on a raised BC error. ' +
            'The default committing path catches BC errors at a Codeunit.Run boundary and returns BusinessCentralError without partial changes. ' +
            'A later status change replaces the order SystemId; do not cache identity across a status change.';
    end;
}
