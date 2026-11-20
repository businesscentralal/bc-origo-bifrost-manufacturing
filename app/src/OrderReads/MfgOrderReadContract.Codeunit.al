namespace Origo.Bifrost.Manufacturing;

using Origo.Bifrost;

/// <summary>English public help for component availability and production order statistics.</summary>
codeunit 10077067 "Mfg Order Read Contract ori"
{
    Access = Internal;

    /// <summary>Declares synchronous JSON reads.</summary>
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

    /// <summary>Describes the order identity.</summary>
    internal procedure GetTarget(var Target: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Target.Add(Contract.TargetEntry('data.no', 'document no.', 'Production order number together with status.'));
        Target.Add(Contract.TargetEntry('data.systemId', 'guid', 'Order SystemId; every supplied identifier must agree.'));
    end;

    /// <summary>Documents strict identity and optional filters.</summary>
    internal procedure GetParameters(Availability: Boolean; var Parameters: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(Contract.Parameter('no', 'string', false, 'Order number, at most 20 characters; required unless systemId is supplied.'));
        Parameters.Add(Contract.Parameter('systemId', 'string', false, 'Nonzero GUID; required unless no is supplied.'));
        if Availability then
            Parameters.Add(Contract.Parameter('status', 'string', true, 'Planned, FirmPlanned or Released. Finished is refused.'))
        else
            Parameters.Add(Contract.Parameter('status', 'string', true, 'Planned, FirmPlanned, Released or Finished.'));
        Parameters.Add(Contract.Parameter('lineNo', 'integer', false, 'Positive production order line number. Omit for the whole order. An absent line is refused.'));
        if Availability then
            Parameters.Add(Contract.Parameter('locationCode', 'string', false, 'At most 10 characters. Omit for every location; an explicit empty string selects the blank location.'));
    end;

    /// <summary>Documents quantity units, cost blocks and variance semantics.</summary>
    internal procedure GetResponse(Availability: Boolean; var Response: JsonObject)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(Contract.ResponseField('status', 'string', 'Success, or the standard Error envelope.'));
        Fields.Add(Contract.ResponseField('no', 'string', 'Production order number.'));
        Fields.Add(Contract.ResponseField('systemId', 'string', 'Production order SystemId.'));
        if Availability then
            Fields.Add(Contract.ResponseField('components', 'array', 'Inventory components with lineNo, componentLineNo, itemNo, variantCode, locationCode, expectedQuantity, remainingQuantity, inventory, scheduledReceipts, grossRequirement, projectedAvailable, shortage, dueDate and flushingMethod. All quantities use the item base unit. Inventory and demand are net of reservations; receipts include purchases. Same-day production uses Shortage List priority. Repeated items with the same due date on the same order line share the same shortage, so do not sum those shortages.'))
        else begin
            Fields.Add(Contract.ResponseField('standard', 'object', 'LCY material, capacity, subcontracted, capacityOverhead, manufacturingOverhead and total. Material includes non-inventory material when enabled.'));
            Fields.Add(Contract.ResponseField('expected', 'object', 'The same LCY cost breakdown for expected production.'));
            Fields.Add(Contract.ResponseField('actual', 'object', 'The same LCY cost breakdown from posted usage. Final only after Inventory.AdjustCost.Run.'));
            Fields.Add(Contract.ResponseField('variance', 'object', 'amount and percent cost blocks: actual minus standard, percentage rounded to a whole percent as in Statistics; zero when standard is zero.'));
            Fields.Add(Contract.ResponseField('capacityNeed', 'number', 'Expected capacity excluding subcontracting, in capacityUnitOfMeasure.'));
            Fields.Add(Contract.ResponseField('capacityUsed', 'number', 'Posted capacity excluding subcontracting, in capacityUnitOfMeasure.'));
            Fields.Add(Contract.ResponseField('capacityUnitOfMeasure', 'string', 'Manufacturing Show Capacity In setting.'));
            Fields.Add(Contract.ResponseField('output', 'number', 'Finished output in base units over selected top-level production lines.'));
            Fields.Add(Contract.ResponseField('scrap', 'number', 'Sum of posted operation scrap quantities over selected production lines.'));
            Fields.Add(Contract.ResponseField('currencyCode', 'string', 'Blank means local currency (LCY).'));
        end;
        Response.Add('fields', Fields);
    end;

    /// <summary>Lists refusals with recovery guidance.</summary>
    internal procedure GetErrors(Availability: Boolean; var Errors: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'Identity or status is missing.', 'Send no or systemId and status.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'A value has the wrong type, length or format, or status is unknown.', 'Use the documented formats and status names.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, 'An undeclared parameter was supplied.', 'Remove the unknown key.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The order or selected line was not found.', 'Read production orders with Data.Records.Get and correct the identifiers.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, 'Supplied identities or status disagree.', 'Send identifiers for the same order and status.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'Manufacturing read access is missing.', 'Ask an administrator to assign Bifrost Read or Full with Manufacturing access.'));
        if Availability then
            Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The order is Finished.', 'Use a Planned, FirmPlanned or Released order.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Native calculation or setup validation failed.', 'Correct the setup or record named in the error, then retry.'));
    end;

    /// <summary>Declares an idempotent read without confirmation.</summary>
    internal procedure GetEffect(Availability: Boolean; var Effect: JsonObject)
    begin
        Effect.Add('effect', 'read');
        Effect.Add('idempotent', true);
        Effect.Add('permissionSet', 'BIFROST Read ori');
        Effect.Add('changes', 'No business records are changed. No confirmation is required.');
    end;

    /// <summary>Links to detailed inventory and lifecycle operations.</summary>
    internal procedure GetRelated(Availability: Boolean; var Related: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        if Enum::"Message Type ori".Names().Contains('Inventory.AvailabilityByEvent.Get') then
            Related.Add(Contract.RelatedEntry('Inventory.AvailabilityByEvent.Get', 'Inspect the events behind an item shortage.'));
        if Enum::"Message Type ori".Names().Contains('Inventory.AvailabilityByPeriod.Get') then
            Related.Add(Contract.RelatedEntry('Inventory.AvailabilityByPeriod.Get', 'Inspect item supply and demand by period.'));
        if Enum::"Message Type ori".Names().Contains('Inventory.AvailableToPromise.Get') then
            Related.Add(Contract.RelatedEntry('Inventory.AvailableToPromise.Get', 'Check an item promise date.'));
        if Enum::"Message Type ori".Names().Contains('Inventory.AdjustCost.Run') then
            Related.Add(Contract.RelatedEntry('Inventory.AdjustCost.Run', 'Finalize posted costs before reading final actual cost.'));
        Related.Add(Contract.RelatedEntry('Manufacturing.ProductionOrder.CheckFinish', 'Inspect readiness to finish.'));
        Related.Add(Contract.RelatedEntry('Data.Records.Get', 'Find production orders and their identifiers.'));
    end;

    /// <summary>Describes the planning and costing workflow.</summary>
    internal procedure GetWorkflow(var Workflow: JsonObject)
    begin
        Workflow.Add('text', 'Read component availability before release or picking. Post output and consumption, finish the order, and run Inventory.AdjustCost.Run before relying on final actual costs.');
    end;

    /// <summary>Provides a concrete read request.</summary>
    internal procedure GetExamples(Availability: Boolean; var Examples: JsonArray)
    var
        Example: JsonObject;
        Request: JsonObject;
        Data: JsonObject;
    begin
        Example.Add('title', 'Read a released order');
        if Availability then
            Request.Add('type', 'Manufacturing.ComponentAvailability.Get')
        else
            Request.Add('type', 'Manufacturing.ProductionOrderStatistics.Get');
        Data.Add('no', 'X-PROD-001');
        Data.Add('status', 'Released');
        Request.Add('data', Data);
        Example.Add('request', Request);
        Examples.Add(Example);
    end;

    /// <summary>Summarizes the read.</summary>
    internal procedure GetOverview(Availability: Boolean; var Overview: Text)
    begin
        if Availability then
            Overview := 'Read a production order component shortage using the Business Central Shortage List calculation.'
        else
            Overview := 'Read standard, expected and actual production costs using Business Central Statistics calculations, including variance and capacity.';
    end;

    /// <summary>Explains scope and rounding limits.</summary>
    internal procedure GetNotes(Availability: Boolean; var Notes: Text)
    begin
        if Availability then
            Notes := 'Non-inventory components are excluded as in the Shortage List. Figures are base quantities and include reservation and same-day order priority. Use Inventory.AvailabilityByEvent.Get, Inventory.AvailabilityByPeriod.Get or Inventory.AvailableToPromise.Get for item detail when Bifrost Inventory is installed. This is a snapshot, not an allocation or reservation.'
        else
            Notes := 'Amounts are LCY. Cost and output totals include top-level lines as in Statistics. Capacity and operation scrap cover the selected order or line. Actual cost is final only after Inventory.AdjustCost.Run. A zero standard cost gives a zero variance percentage. Planned orders have no actual usage.';
    end;
}
