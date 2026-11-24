namespace Origo.Bifrost.Manufacturing;

using Origo.Bifrost;

/// <summary>
/// Contract chapters for Manufacturing.ProductionOrder.CreateFromDemand.
/// Foundation adds the expectedCount parameter and the confirmation effect to this type.
/// </summary>
codeunit 10077099 "Mfg Demand Contract ori"
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

    /// <summary>Describes the sales order identity.</summary>
    internal procedure GetTarget(var Target: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Target.Add(Contract.TargetEntry('data.sourceNo', 'document no.', 'The sales order number.'));
        Target.Add(Contract.TargetEntry('data.sourceSystemId', 'guid', 'The sales order SystemId. Supplied identifiers must agree.'));
    end;

    /// <summary>Lists the accepted data keys and their rules.</summary>
    internal procedure GetParameters(var Parameters: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(Contract.Parameter('sourceType', 'string', true, 'salesOrder. Project demand is not supported.'));
        Parameters.Add(Contract.Parameter('sourceNo', 'string', false, 'Sales order number; required unless sourceSystemId is supplied.'));
        Parameters.Add(Contract.Parameter('sourceSystemId', 'string', false, 'Sales order SystemId GUID; required unless sourceNo is supplied. Both must name the same sales order.'));
        Parameters.Add(Contract.Parameter('lineNos', 'array', false, 'Sales line numbers (integers) to supply. Default: every item line that needs a production order. Only with orderType ItemOrder.'));
        Parameters.Add(Contract.Parameter('status', 'string', false, 'Planned, FirmPlanned (default) or Released. Released also needs the posting permission set and posts forward-flushed consumption and output.'));
        Parameters.Add(Contract.Parameter('orderType', 'string', false, 'ItemOrder (default): one production order per sales line. ProjectOrder: one production order for the whole sales order, with one line per sales line. ProjectOrder has nothing to do with projects.'));
    end;

    /// <summary>Describes the success response.</summary>
    internal procedure GetResponse(var Response: JsonObject)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(Contract.ResponseField('status', 'string', 'Success; refusals use the standard Error envelope.'));
        Fields.Add(Contract.ResponseField('orderType', 'string', 'ItemOrder or ProjectOrder.'));
        Fields.Add(Contract.ResponseField('sourceType', 'string', 'salesOrder.'));
        Fields.Add(Contract.ResponseField('sourceNo', 'string', 'Sales order number.'));
        Fields.Add(Contract.ResponseField('ordersCreated', 'integer', 'Number of production orders created.'));
        Fields.Add(Contract.ResponseField('orders', 'array', 'Each {no, systemId, status, sourceType (Item or SalesHeader), sourceNo, quantity, dueDate, linkedLines (sales line numbers), lineCount, componentCount}.'));
        Fields.Add(Contract.ResponseField('skipped', 'array', 'Each {salesLineNo, itemNo, reasonCode, reason, nextStep}; reasonCode is alreadySupplied, notManufactured, itemBlocked, bomNotCertified, routingNotCertified, missingShipmentDate or notAnItem.'));
        Fields.Add(Contract.ResponseField('nextStep', 'string', 'Localized guidance for the next call.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
    end;

    /// <summary>Declares refusals.</summary>
    internal procedure GetErrors(var Errors: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'sourceType, or both sourceNo and sourceSystemId, are absent.', 'Supply the required parameter.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'A value is not allowed, for example an unknown status or orderType, project demand, or lineNos with ProjectOrder.', 'Use the parameter values in this contract.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'A JSON type or GUID is invalid, or lineNos is not an array of integers.', 'Correct the JSON type and format.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, 'An undeclared key was supplied.', 'Remove the unknown key.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MultipleErrors, 'Several request problems were collected; nothing was changed.', 'Correct every error entry before retrying.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The sales order or a requested sales line does not exist.', 'Read the sales order with Data.Records.Get first.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, 'sourceNo and sourceSystemId name different sales orders.', 'Send identifiers of the same sales order.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller has no Manufacturing write permission, or status Released was requested without BIFROST MfgPost ori.', 'Ask an administrator to assign BIFROST Mfg ori, and BIFROST MfgPost ori for Released.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The sales order is not released, no line needs a production order, a line blocks one order for the whole sales order, or Business Central rejected the creation; nothing was created.', 'Act on the returned message and nextStep.'));
    end;

    /// <summary>Declares the write effect.</summary>
    internal procedure GetEffect(var Effect: JsonObject)
    var
        Preconditions: JsonArray;
    begin
        Effect.Add('effect', 'write');
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', 'BIFROST Mfg ori (Released: + BIFROST MfgPost ori)');
        Effect.Add('count', 'production orders created: one per eligible sales line for ItemOrder, one per sales order for ProjectOrder');
        Effect.Add('changes', 'This write commits. Creates production orders with lines, routing and components, and reserves or tracks them against the sales lines. Status Released also posts forward-flushed consumption and output.');
        Preconditions.Add('The sales order is released.');
        Preconditions.Add('Supplied lines are items replenished by production order, not blocked, with certified production BOM and routing, a shipment date and an unreserved outstanding quantity; other lines are listed in skipped.');
        Preconditions.Add('The caller has native permissions on sales orders, reservations and production orders.');
        Effect.Add('preconditions', Preconditions);
    end;

    /// <summary>Names the related lifecycle operations.</summary>
    internal procedure GetRelated(var Related: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(Contract.RelatedEntry('Manufacturing.ProductionOrder.Create', 'Create an order for an item without a sales link.'));
        Related.Add(Contract.RelatedEntry('Manufacturing.ProductionBOM.SetStatus', 'Certify a production BOM a skipped line names.'));
        Related.Add(Contract.RelatedEntry('Manufacturing.Routing.SetStatus', 'Certify a routing a skipped line names.'));
        Related.Add(Contract.RelatedEntry('Manufacturing.ProductionOrder.ChangeStatus', 'Release a planned or firm planned order.'));
        Related.Add(Contract.RelatedEntry('Data.Records.Get', 'Read sales orders and the created production orders.'));
    end;

    /// <summary>Explains the workflow.</summary>
    internal procedure GetWorkflow(var Workflow: JsonObject)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Steps.Add(Contract.WorkflowStep('Manufacturing.ProductionOrder.CreateFromDemand', 'Send the request; no confirmation preview is required. expectedCount is accepted and ignored.'));
        Steps.Add(Contract.WorkflowStep('Manufacturing.ProductionOrder.ChangeStatus', 'Release the orders when production starts.'));
        Workflow.Add('steps', Steps);
        Workflow.Add('text', 'Fix the lines listed in skipped (certify BOM or routing, set a shipment date) and send the request again for those lines.');
    end;

    /// <summary>Provides a data payload example.</summary>
    internal procedure GetExamples(var Examples: JsonArray)
    var
        Example: JsonObject;
        Request: JsonObject;
        Data: JsonObject;
    begin
        Example.Add('title', 'One firm planned production order per line of a released sales order');
        Request.Add('type', 'Manufacturing.ProductionOrder.CreateFromDemand');
        Data.Add('sourceType', 'salesOrder');
        Data.Add('sourceNo', '101005');
        Data.Add('status', 'FirmPlanned');
        Data.Add('orderType', 'ItemOrder');
        Request.Add('data', Data);
        Example.Add('request', Request);
        Examples.Add(Example);
    end;

    /// <summary>States what the operation does.</summary>
    internal procedure GetOverview(var Overview: Text)
    begin
        Overview := 'Creates production orders for the demand of a released sales order, the same way as creating production orders from sales order planning in Business Central. ' +
            'ItemOrder creates one order per sales line; ProjectOrder creates one order for the whole sales order. Every new order line is reserved or tracked against its sales line. This call commits and cannot be undone.';
    end;

    /// <summary>Documents transaction and eligibility behaviour.</summary>
    internal procedure GetNotes(var Notes: Text)
    begin
        Notes := 'Business Central decides the order lines, routing and components, including lines for manufactured sub-assemblies. ' +
            'Lines that are not items replenished by production order, already fully reserved, blocked, without a shipment date, or whose production BOM or routing is not certified are returned in skipped and get no order. ' +
            'With ProjectOrder, a blocked item or uncertified BOM or routing refuses the whole call because Business Central would include that line. ' +
            'All orders are created in one transaction: a failure creates nothing. No dialog is shown. Project demand is not supported.';
    end;
}
