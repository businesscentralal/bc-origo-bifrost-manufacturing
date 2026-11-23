namespace Origo.Bifrost.Manufacturing;

using Origo.Bifrost;

/// <summary>English contract chapters for whole-entry output and consumption corrections.</summary>
codeunit 10077112 "Mfg Reverse Contract ori"
{
    Access = Internal;

    /// <summary>Declares the version 1 JSON envelope.</summary>
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

    /// <summary>Identifies the production order.</summary>
    internal procedure GetTarget(var Target: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Target.Add(Contract.TargetEntry('data.prodOrderNo', 'document no.', 'Released production order number.'));
        Target.Add(Contract.TargetEntry('data.systemId', 'guid', 'Optional production order identity. Every supplied identifier must agree.'));
    end;

    /// <summary>Lists accepted parameters.</summary>
    internal procedure GetParameters(WithCapacity: Boolean; var Parameters: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(Contract.Parameter('prodOrderNo', 'string', false, 'Released production order number; required unless no or systemId identifies the order.'));
        Parameters.Add(Contract.Parameter('no', 'string', false, 'Alias for prodOrderNo. All supplied identifiers must agree.'));
        Parameters.Add(Contract.Parameter('systemId', 'string', false, 'Production order GUID. All supplied identifiers must agree.'));
        Parameters.Add(Contract.Parameter('itemLedgerEntryNos', 'array', false, 'Unique positive integer entry numbers. Output accepts output entries; Consumption accepts consumption entries. Each entry is reversed in full.'));
        if WithCapacity then
            Parameters.Add(Contract.Parameter('capacityLedgerEntryNos', 'array', false, 'Output only: unique capacity entry numbers for intermediate operations. Consumption refuses this parameter. Supply at least one entry across the lists. Reverse the last operation through its output item entry.'));
        Parameters.Add(Contract.Parameter('expectedCount', 'integer', true, 'Number of explicitly selected item plus capacity entries. Implicit last-operation capacity corrections do not add to this count. Omit it to receive ConfirmationRequired without posting.'));
    end;

    /// <summary>Documents success and correcting entry identities.</summary>
    internal procedure GetResponse(var Response: JsonObject)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(Contract.ResponseField('status', 'string', 'Success. Refusals use the standard Error envelope.'));
        Fields.Add(Contract.ResponseField('prodOrderNo', 'string', 'Released production order number.'));
        Fields.Add(Contract.ResponseField('reversed', 'array', 'Each {originalEntryNo, newEntryNo, quantity, itemNo, lotNo, serialNo}. Quantity is the posted correction in the base unit.'));
        Fields.Add(Contract.ResponseField('capacityEntriesReversed', 'array', 'Each {originalEntryNo, newEntryNo, quantity, operationNo}, including last-operation capacity corrected with output.'));
        Fields.Add(Contract.ResponseField('remainingOutput', 'array', 'Each {lineNo, remainingQuantity} in the order line unit.'));
        Fields.Add(Contract.ResponseField('remainingConsumption', 'array', 'Each {orderLineNo, componentLineNo, itemNo, remainingQuantity} in the component unit.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
    end;

    /// <summary>Documents every structured refusal and recovery.</summary>
    internal procedure GetErrors(var Errors: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'No order identity or no entries supplied.', 'Supply the production order and at least one entry.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'Wrong JSON shape, duplicate or invalid entry number, wrong order or wrong entry type.', 'Use unique positive integers belonging to this order and operation.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, 'An undeclared parameter, or capacity entries on Consumption, was supplied.', 'Remove the unknown parameter.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConflictingIdentifiers, 'Supplied order identifiers disagree.', 'Send identifiers for the same production order.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'An order or selected entry does not exist.', 'Read the order and entries with Data.Records.Get.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'Manufacturing write or posting permission is missing.', 'Ask an administrator for BIFROST Mfg ori and BIFROST MfgPost ori.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'Order is not Released; entry is corrected, reserved, applied or subcontracted; last-operation capacity must be reversed through output; Business Central rejected posting; or Omit Commit was requested.', 'For a Finished order use Manufacturing.ProductionOrder.Reopen. For last-operation capacity reverse its output entry. Otherwise correct the condition in the returned Business Central text and retry. Nothing was changed.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConfirmationRequired, 'expectedCount was omitted; nothing posted.', 'Repeat with expectedCount equal to the selected entry count.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConfirmationMismatch, 'expectedCount differs from selected entry count; nothing posted.', 'Read the entries and send their exact count.'));
    end;

    /// <summary>Declares the posting effect and exact count.</summary>
    internal procedure GetEffect(var Effect: JsonObject)
    var
        Preconditions: JsonArray;
    begin
        Effect.Add('effect', 'irreversible');
        Preconditions.Add('The production order is Released.');
        Preconditions.Add('Every selected entry belongs to the order, has the matching entry type and has not already been corrected. Native reservations, applications and subcontracting rules apply.');
        Preconditions.Add('expectedCount exactly matches the number of explicitly selected entries.');
        Effect.Add('preconditions', Preconditions);
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', 'BIFROST Mfg ori + BIFROST MfgPost ori');
        Effect.Add('count', 'explicitly selected item ledger entries plus capacity ledger entries');
        Effect.Add('changes', 'Posts correcting entries using the original posting dates, dimensions and item tracking. Original ledger entries remain; their application and reversal state changes under standard posting. The complete selection is atomic and commits. Repeated correction is refused.');
    end;

    /// <summary>Points to discovery, reopening and cost adjustment.</summary>
    internal procedure GetRelated(var Related: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(Contract.RelatedEntry('Data.Records.Get', 'Read production orders and their ledger entries.'));
        Related.Add(Contract.RelatedEntry('Manufacturing.ProductionJournal.Post', 'Post corrected output or consumption after reversing.'));
        Related.Add(Contract.RelatedEntry('Manufacturing.ProductionOrder.Reopen', 'Reopen a Finished order before correction, subject to its own rules.'));
        Related.Add(Contract.RelatedEntry('Inventory.AdjustCost.Run', 'Settle item costs after the corrections.'));
    end;

    /// <summary>Explains selection, confirmation and correction.</summary>
    internal procedure GetWorkflow(var Workflow: JsonObject)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Steps.Add(Contract.WorkflowStep('Data.Records.Get', 'Read the Released order and select its original output or consumption entries.'));
        Steps.Add(Contract.WorkflowStep('Manufacturing.Output.Reverse / Manufacturing.Consumption.Reverse', 'Call the matching operation without expectedCount to read the selected entry count.'));
        Steps.Add(Contract.WorkflowStep('Manufacturing.ProductionJournal.Post', 'After reversal with the exact count, post corrected quantities and use Inventory.AdjustCost.Run.'));
        Workflow.Add('steps', Steps);
    end;

    /// <summary>Shows whole-entry requests for both operations.</summary>
    internal procedure GetExamples(var Examples: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(Contract.Example('Reverse one output entry', '{"prodOrderNo":"P100","itemLedgerEntryNos":[123],"expectedCount":1}', '{"status":"Success","prodOrderNo":"P100","reversed":[{"originalEntryNo":123,"newEntryNo":124,"quantity":-10,"itemNo":"P","lotNo":"","serialNo":""}]}'));
        Examples.Add(Contract.Example('Reverse one consumption entry', '{"prodOrderNo":"P100","itemLedgerEntryNos":[122],"expectedCount":1}', '{"status":"Success","prodOrderNo":"P100","reversed":[{"originalEntryNo":122,"newEntryNo":125,"quantity":20,"itemNo":"C","lotNo":"LOT1","serialNo":""}]}'));
    end;

    /// <summary>Explains the correction scope.</summary>
    internal procedure GetOverview(var Overview: Text)
    begin
        Overview := 'Posts whole-entry corrections for a Released production order. Output reverses output item entries and intermediate capacity entries; Consumption reverses consumption item entries. Original entries remain. Partial quantities are not supported.';
    end;

    /// <summary>Explains native restrictions and API dialog behavior.</summary>
    internal procedure GetNotes(var Notes: Text)
    begin
        Notes := 'Business Central validates posting dates, applications, reservations, item tracking and subcontracting. Reverse last-operation capacity through the associated output item entry. Calls use the standard non-interactive API path. The entire selection rolls back on any refusal; no journal lines are left behind.';
    end;
}
