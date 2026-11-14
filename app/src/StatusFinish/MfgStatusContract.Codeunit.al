namespace Origo.Bifrost.Manufacturing;

using Origo.Bifrost;

/// <summary>
/// Single source for the ChangeStatus (Kind 0), Finish (Kind 1) and CheckFinish (Kind 2) contract chapters.
/// Foundation adds the expectedCount parameter and the confirmation effect to the irreversible types.
/// </summary>
codeunit 10077054 "Mfg Status Contract ori"
{
    Access = Internal;

    /// <summary>Declares JSON version 1.0 data requests; subject is not used.</summary>
    internal procedure GetEnvelope(var Envelope: JsonObject)
    var
        Subject: JsonObject;
    begin
        Subject.Add('use', 'notUsed');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
    end;

    /// <summary>Describes the production order identity.</summary>
    internal procedure GetTarget(var Target: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Target.Add(Contract.TargetEntry('data.no', 'document no.', 'The order number; optionally narrow it with productionOrderStatus.'));
        Target.Add(Contract.TargetEntry('data.systemId', 'guid', 'The production order SystemId. Supplied identifiers must agree.'));
    end;

    /// <summary>Lists the accepted ChangeStatus data keys and their rules.</summary>
    internal procedure GetStatusParameters(var Parameters: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(Contract.Parameter('no', 'string', false, 'Order number; required unless systemId is supplied. More than one matching status is AmbiguousRecord.'));
        Parameters.Add(Contract.Parameter('systemId', 'string', false, 'Order SystemId GUID; required unless no is supplied. Every supplied identifier must agree.'));
        Parameters.Add(Contract.Parameter('productionOrderStatus', 'string', false, 'Optional current status that narrows the lookup: Simulated, Planned, FirmPlanned, Released or Finished.'));
        Parameters.Add(Contract.Parameter('newStatus', 'string', true, 'FirmPlanned or Released. Finished is refused (use Manufacturing.ProductionOrder.Finish); Planned, Simulated, backward moves and the current status are refused.'));
        Parameters.Add(Contract.Parameter('postingDate', 'string', false, 'ISO date yyyy-mm-dd for the entries forward flushing posts on release. Default is the session work date.'));
    end;

    /// <summary>Lists the accepted Finish data keys and their rules.</summary>
    internal procedure GetFinishParameters(var Parameters: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(Contract.Parameter('no', 'string', false, 'Order number; required unless systemId is supplied. More than one matching status is AmbiguousRecord.'));
        Parameters.Add(Contract.Parameter('systemId', 'string', false, 'Order SystemId GUID; required unless no is supplied. Every supplied identifier must agree.'));
        Parameters.Add(Contract.Parameter('productionOrderStatus', 'string', false, 'Optional current status that narrows the lookup: Simulated, Planned, FirmPlanned, Released or Finished.'));
        Parameters.Add(Contract.Parameter('postingDate', 'string', false, 'ISO date yyyy-mm-dd for backward flushing and the finished date. Default is the session work date.'));
        Parameters.Add(Contract.Parameter('updateUnitCost', 'boolean', false, 'Default false (the Business Central page default): update the unit cost of the produced item.'));
        Parameters.Add(Contract.Parameter('finishWithoutOutput', 'boolean', false, 'Default false. True finishes an order that has consumption or capacity posted but no output.'));
        Parameters.Add(Contract.Parameter('acceptMissingOutput', 'boolean', false, 'Default false. True acknowledges that some output is still missing.'));
        Parameters.Add(Contract.Parameter('acceptMissingConsumption', 'boolean', false, 'Default false. True acknowledges that some consumption is still missing.'));
    end;

    /// <summary>Lists the accepted CheckFinish data keys and their rules.</summary>
    internal procedure GetCheckParameters(var Parameters: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(Contract.Parameter('no', 'string', false, 'Order number; required unless systemId is supplied. More than one matching status is AmbiguousRecord.'));
        Parameters.Add(Contract.Parameter('systemId', 'string', false, 'Order SystemId GUID; required unless no is supplied. Every supplied identifier must agree.'));
        Parameters.Add(Contract.Parameter('productionOrderStatus', 'string', false, 'Optional current status that narrows the lookup: Simulated, Planned, FirmPlanned, Released or Finished.'));
    end;

    /// <summary>Documents response fields.</summary>
    internal procedure GetResponse(Kind: Integer; var Response: JsonObject)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
        Children: JsonArray;
        Field: JsonObject;
    begin
        case Kind of
            0:
                begin
                    Fields.Add(Contract.ResponseField('status', 'string', 'Success; refusals use the standard Error envelope.'));
                    Fields.Add(Contract.ResponseField('fromStatus', 'string', 'Status before the call.'));
                    Fields.Add(Contract.ResponseField('toStatus', 'string', 'FirmPlanned or Released.'));
                    Fields.Add(Contract.ResponseField('oldNo', 'string', 'Order number before the call.'));
                    Fields.Add(Contract.ResponseField('no', 'string', 'Order number after the call. It differs from oldNo when the target status uses another number series.'));
                    Fields.Add(Contract.ResponseField('systemId', 'string', 'The new SystemId. The order record is re-created under the new status, so the SystemId always changes.'));
                    Fields.Add(Contract.ResponseField('numberChanged', 'boolean', 'True when no differs from oldNo.'));
                    Fields.Add(Contract.ResponseField('postingDate', 'string', 'Posting date used, yyyy-mm-dd.'));
                    Fields.Add(Contract.ResponseField('postedItemEntries', 'integer', 'Item Ledger Entries the call created for the order (forward flushing on release); 0 otherwise.'));
                    Fields.Add(Contract.ResponseField('lines', 'integer', 'Number of order lines after the move.'));
                end;
            1:
                begin
                    Fields.Add(Contract.ResponseField('status', 'string', 'Success; refusals use the standard Error envelope.'));
                    Fields.Add(Contract.ResponseField('no', 'string', 'Order number of the finished order.'));
                    Fields.Add(Contract.ResponseField('systemId', 'string', 'The new SystemId of the finished order.'));
                    Fields.Add(Contract.ResponseField('finishedDate', 'string', 'Finished Date, yyyy-mm-dd.'));
                    Fields.Add(Contract.ResponseField('postingDate', 'string', 'Posting date used, yyyy-mm-dd.'));
                    Fields.Add(Contract.ResponseField('updateUnitCost', 'boolean', 'The updateUnitCost value used.'));
                    Fields.Add(Contract.ResponseField('postedItemEntries', 'integer', 'Item Ledger Entries the call created (backward flushing).'));
                    Fields.Add(Contract.ResponseField('acknowledgedWarnings', 'array', 'missingOutput and/or missingConsumption when the caller acknowledged them.'));
                    Children.Add(Contract.ResponseField('lineNo', 'integer', 'Production order line number.'));
                    Children.Add(Contract.ResponseField('itemNo', 'string', 'Item number on the line.'));
                    Children.Add(Contract.ResponseField('quantity', 'number', 'Line quantity.'));
                    Children.Add(Contract.ResponseField('finishedQuantity', 'number', 'Finished quantity on the line.'));
                    Field := Contract.ResponseField('lines', 'array', 'The lines of the finished order.');
                    Field.Add('children', Children);
                    Fields.Add(Field);
                end;
            2:
                begin
                    Fields.Add(Contract.ResponseField('status', 'string', 'Success; refusals use the standard Error envelope.'));
                    Fields.Add(Contract.ResponseField('no', 'string', 'Order number.'));
                    Fields.Add(Contract.ResponseField('productionOrderStatus', 'string', 'Current status.'));
                    Fields.Add(Contract.ResponseField('canFinish', 'boolean', 'True when blockers is empty.'));
                    Fields.Add(Contract.ResponseField('blockers', 'array', 'Each {code, message, nextStep?, lineNo?, itemNo?}; code is OutstandingSubcontractOrder, OutstandingPick, ConsumptionWithoutOutput or NotReleased.'));
                    Fields.Add(Contract.ResponseField('warnings', 'array', 'Each {kind, message, nextStep}; kind is missingOutput or missingConsumption. Finish refuses them unless acknowledged.'));
                    Fields.Add(Contract.ResponseField('lines', 'array', 'Each {lineNo, itemNo, quantity, finishedQuantity, remainingQuantity}.'));
                    Fields.Add(Contract.ResponseField('components', 'array', 'Each {prodOrderLineNo, lineNo, itemNo, expectedQuantity, remainingQuantity, flushingMethod}.'));
                end;
        end;
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
    end;

    /// <summary>Declares refusals.</summary>
    internal procedure GetErrors(Kind: Integer; var Errors: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'A required parameter is absent.', 'Supply the required parameter.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'A value or status is not allowed.', 'Use the parameter values in this contract.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'A JSON type, date or GUID is invalid.', 'Correct the JSON type and format.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The production order does not exist.', 'Read the record with Data.Records.Get first.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::AmbiguousRecord, 'An order number exists under more than one status.', 'Send productionOrderStatus or systemId.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, 'Identifiers name different orders or statuses.', 'Send identifiers belonging to the same order.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, 'An undeclared key was supplied.', 'Remove the unknown key.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MultipleErrors, 'Several request problems were collected; nothing was changed.', 'Correct every error entry before retrying.'));
        if Kind = 2 then
            exit;
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConfirmationRequired, 'The call cannot be undone and expectedCount was not sent; nothing was changed.', 'Send the same request again with expectedCount from the refusal.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConfirmationMismatch, 'expectedCount differs from the current count; nothing was changed.', 'Check the preview and send the current count.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller does not hold the BIFROST MfgPost ori permission set.', 'Ask an administrator to assign BIFROST MfgPost ori.'));
        if Kind = 1 then
            Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The order is not Released, output or consumption is missing without acknowledgment, consumption is posted without output, or a subcontract purchase order or pick is outstanding.', 'Act on the returned message and nextStep; outstanding purchase orders and picks cannot be overridden.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Business Central rejected the status change, for example an item blocked for production output; the transaction was rolled back.', 'Correct the field or setup named in the returned BC text.'));
    end;

    /// <summary>Declares irreversible committing effects for the writing types and read for CheckFinish.</summary>
    internal procedure GetEffect(Kind: Integer; var Effect: JsonObject)
    var
        Preconditions: JsonArray;
    begin
        if Kind = 2 then begin
            Effect.Add('effect', 'read');
            Effect.Add('idempotent', true);
            Effect.Add('permissionSet', 'BIFROST MfgRead ori');
            Effect.Add('changes', 'Changes nothing and posts nothing.');
            Effect.Add('preconditions', Preconditions);
            exit;
        end;
        Effect.Add('effect', 'irreversible');
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', 'BIFROST Mfg ori + BIFROST MfgPost ori');
        Effect.Add('count', 'one production order');
        if Kind = 0 then
            Effect.Add('changes', 'This call commits. Moves the order, its lines, routing and components to the new status with the standard Business Central status change and posts forward-flushed consumption and output on release.')
        else
            Effect.Add('changes', 'This call commits and cannot be undone. Posts backward-flushed consumption and output, adjusts work in process and moves the order to Finished.');
        Preconditions.Add('The caller holds BIFROST MfgPost ori.');
        Preconditions.Add('expectedCount 1 from the ConfirmationRequired preview when the company requires confirmation.');
        if Kind = 1 then
            Preconditions.Add('The order is Released, without outstanding subcontract purchase orders or picks.');
        Preconditions.Add('The caller has native permissions on the entries the status change posts.');
        Effect.Add('preconditions', Preconditions);
    end;

    /// <summary>Names the other lifecycle operations.</summary>
    internal procedure GetRelated(Kind: Integer; var Related: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        if Kind <> 0 then
            Related.Add(Contract.RelatedEntry('Manufacturing.ProductionOrder.ChangeStatus', 'Release the order first.'));
        if Kind <> 1 then
            Related.Add(Contract.RelatedEntry('Manufacturing.ProductionOrder.Finish', 'Finish a released order.'));
        if Kind <> 2 then
            Related.Add(Contract.RelatedEntry('Manufacturing.ProductionOrder.CheckFinish', 'See what would block or warn before finishing.'));
        Related.Add(Contract.RelatedEntry('Manufacturing.ProductionOrder.Refresh', 'Calculate lines, routing and components before release.'));
        Related.Add(Contract.RelatedEntry('Data.Records.Get', 'Read production order records.'));
    end;

    /// <summary>Explains the lifecycle.</summary>
    internal procedure GetWorkflow(var Workflow: JsonObject)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Steps.Add(Contract.WorkflowStep('Manufacturing.ProductionOrder.Refresh', 'Calculate the order before releasing it.'));
        Steps.Add(Contract.WorkflowStep('Manufacturing.ProductionOrder.ChangeStatus', 'Send without expectedCount to read the preview, then again with expectedCount 1 to move to FirmPlanned or Released.'));
        Steps.Add(Contract.WorkflowStep('Manufacturing.ProductionOrder.CheckFinish', 'After output and consumption are posted, check blockers and warnings.'));
        Steps.Add(Contract.WorkflowStep('Manufacturing.ProductionOrder.Finish', 'Finish with expectedCount 1, acknowledging any warning you accept.'));
        Workflow.Add('steps', Steps);
        Workflow.Add('text', 'Each status change re-creates the order: use the systemId and no from the response for the next call.');
    end;

    /// <summary>Provides a data payload example.</summary>
    internal procedure GetExamples(Kind: Integer; var Examples: JsonArray)
    var
        Example: JsonObject;
        Request: JsonObject;
        Data: JsonObject;
    begin
        case Kind of
            0:
                begin
                    Example.Add('title', 'Release a firm planned order');
                    Request.Add('type', 'Manufacturing.ProductionOrder.ChangeStatus');
                    Data.Add('no', '101001');
                    Data.Add('productionOrderStatus', 'FirmPlanned');
                    Data.Add('newStatus', 'Released');
                    Data.Add('expectedCount', 1);
                end;
            1:
                begin
                    Example.Add('title', 'Finish a released order whose output is posted');
                    Request.Add('type', 'Manufacturing.ProductionOrder.Finish');
                    Data.Add('no', '101001');
                    Data.Add('productionOrderStatus', 'Released');
                    Data.Add('expectedCount', 1);
                end;
            2:
                begin
                    Example.Add('title', 'Check a released order before finishing');
                    Request.Add('type', 'Manufacturing.ProductionOrder.CheckFinish');
                    Data.Add('no', '101001');
                    Data.Add('productionOrderStatus', 'Released');
                end;
        end;
        Request.Add('data', Data);
        Example.Add('request', Request);
        Examples.Add(Example);
    end;

    /// <summary>States what the operation does.</summary>
    internal procedure GetOverview(Kind: Integer; var Overview: Text)
    begin
        case Kind of
            0:
                Overview := 'Changes the status of a production order to Firm Planned or Released with the standard Business Central status change. This call commits.';
            1:
                Overview := 'Finishes a released production order with the standard Business Central status change. This call commits and cannot be undone.';
            2:
                Overview := 'Shows what would block or warn when a released production order is finished. Changes nothing.';
        end;
    end;

    /// <summary>Documents transaction and identity behaviour.</summary>
    internal procedure GetNotes(Kind: Integer; var Notes: Text)
    begin
        if Kind = 2 then begin
            Notes := 'CheckFinish computes the same findings Finish refuses on and needs no posting token. It never asks a question and never writes.';
            exit;
        end;
        Notes := 'This call commits: Business Central commits at the end of its status change and the commit is not suppressed, also under Omit Commit. ' +
            'A failure before that commit rolls the whole change back; the order keeps its old status, lines, routing and components. ' +
            'The order is re-created under the new status, so the SystemId always changes and the number changes when the target status uses another number series. ';
        if Kind = 1 then
            Notes += 'Business Central would answer its own missing-output and missing-consumption questions with yes; this type refuses instead unless acceptMissingOutput or acceptMissingConsumption is true. ' +
                'Outstanding subcontract purchase orders and picks cannot be overridden.';
    end;
}
