namespace Origo.Bifrost.Manufacturing;

using Origo.Bifrost;

/// <summary>
/// Single source for the Get (Kind 0), PreviewPost (Kind 1) and Post (Kind 2) contract chapters.
/// Foundation adds the expectedCount parameter and the confirmation effect to Post.
/// </summary>
codeunit 10077071 "Mfg ProdJnl Contract ori"
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

    /// <summary>Lists the accepted data keys and their rules.</summary>
    internal procedure GetParameters(Kind: Integer; var Parameters: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(Contract.Parameter('no', 'string', false, 'Order number; required unless systemId is supplied. More than one matching status is AmbiguousRecord.'));
        Parameters.Add(Contract.Parameter('systemId', 'string', false, 'Order SystemId GUID; required unless no is supplied. Every supplied identifier must agree.'));
        Parameters.Add(Contract.Parameter('productionOrderStatus', 'string', false, 'Optional current status that narrows the lookup. The order must be Released.'));
        Parameters.Add(Contract.Parameter('lineNo', 'integer', false, 'Production order line. Default all lines.'));
        Parameters.Add(Contract.Parameter('postingDate', 'string', false, 'ISO date yyyy-mm-dd. Default is the session work date.'));
        Parameters.Add(Contract.Parameter('consumptionBasis', 'string', false, 'ActualOutput or ExpectedOutput. Default is Default Consum. Calc. Based on in Manufacturing Setup.'));
        Parameters.Add(Contract.Parameter('include', 'array of string', false, 'output and/or consumption. Default both.'));
        if Kind = 0 then
            exit;
        Parameters.Add(Contract.Parameter('lines', 'array', false, 'Exactly these lines are used and nothing else; default is the Business Central proposal. Output: {"kind":"output","lineNo":10000,"operationNo":"10","outputQuantity":5,"scrapQuantity":0,"setupTime":0,"runTime":0,"finished":false}. Consumption: {"kind":"consumption","lineNo":10000,"componentLineNo":20000,"quantity":10}. Lines with quantity 0 and no time are dropped. Use proposedLines from Manufacturing.ProductionJournal.Get.'));
    end;

    /// <summary>Documents response fields.</summary>
    internal procedure GetResponse(Kind: Integer; var Response: JsonObject)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(Contract.ResponseField('status', 'string', 'Success.'));
        Fields.Add(Contract.ResponseField('no', 'string', 'The production order number.'));
        Fields.Add(Contract.ResponseField('productionOrderStatus', 'string', 'Released.'));
        Fields.Add(Contract.ResponseField('postingDate', 'string', 'The posting date used.'));
        case Kind of
            0:
                begin
                    Fields.Add(Contract.ResponseField('consumptionBasis', 'string', 'ActualOutput or ExpectedOutput, as used for the proposal.'));
                    Fields.Add(Contract.ResponseField('outputLines', 'array', 'Per operation: lineNo, itemNo, operationNo, flushingMethod, expectedQuantity, finishedQuantity, remainingQuantity, outputQuantity (proposed), scrapQuantity, setupTime, runTime, finished.'));
                    Fields.Add(Contract.ResponseField('consumptionLines', 'array', 'Per component: lineNo, componentLineNo, itemNo, expectedQuantity, remainingQuantity, quantity (proposed), flushingMethod, locationCode, binCode, quantityPicked.'));
                    Fields.Add(Contract.ResponseField('proposedLines', 'array', 'The same lines in the shape that lines accepts in PreviewPost and Post.'));
                end;
            1:
                begin
                    Fields.Add(Contract.ResponseField('entryCount', 'integer', 'Entries that Post would create.'));
                    Fields.Add(Contract.ResponseField('linesToPost', 'integer', 'Non-empty journal lines.'));
                    Fields.Add(Contract.ResponseField('rollback', 'boolean', 'Always true: nothing was posted.'));
                    Fields.Add(Contract.ResponseField('preview', 'array', 'Entries per table.'));
                end;
            2:
                begin
                    Fields.Add(Contract.ResponseField('postedLines', 'integer', 'Journal lines posted.'));
                    Fields.Add(Contract.ResponseField('outputQuantityPosted', 'decimal', 'Output quantity posted.'));
                    Fields.Add(Contract.ResponseField('scrapQuantityPosted', 'decimal', 'Scrap quantity posted.'));
                    Fields.Add(Contract.ResponseField('consumptionLinesPosted', 'integer', 'Consumption entries posted.'));
                    Fields.Add(Contract.ResponseField('capacityEntriesPosted', 'integer', 'Capacity ledger entries posted.'));
                    Fields.Add(Contract.ResponseField('itemRegisterNo', 'integer', 'The item register created.'));
                    Fields.Add(Contract.ResponseField('itemRegisterId', 'string', 'The item register SystemId.'));
                    Fields.Add(Contract.ResponseField('fromEntryNo', 'integer', 'First item ledger entry.'));
                    Fields.Add(Contract.ResponseField('toEntryNo', 'integer', 'Last item ledger entry.'));
                    Fields.Add(Contract.ResponseField('lines', 'array', 'Per order line: lineNo, quantity posted, finishedQuantity, remainingQuantity.'));
                end;
        end;
        Response.Add('fields', Fields);
    end;

    /// <summary>Declares refusals.</summary>
    internal procedure GetErrors(Kind: Integer; var Errors: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, 'A value is not allowed.', 'Use the parameter values in this contract.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'A JSON type, date or GUID is invalid.', 'Correct the JSON type and format.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The production order does not exist.', 'Read the record with Data.Records.Get first.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::AmbiguousRecord, 'An order number exists under more than one status.', 'Send productionOrderStatus or systemId.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The order is not Released, or there is nothing to post.', 'Change the status with Manufacturing.ProductionOrder.ChangeStatus or send lines with a quantity.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, 'An undeclared key was supplied.', 'Remove the unknown key.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::MultipleErrors, 'Several request problems were collected, with the line index; nothing was changed.', 'Correct every error entry before retrying.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Business Central refused the journal or the posting, for example a blocked item or work center; nothing was posted and no journal line remains.', 'Correct the item, work center, quantity or period named in the returned BC text.'));
        if Kind <> 2 then
            exit;
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConfirmationRequired, 'The call cannot be undone and expectedCount was not sent; nothing was posted.', 'Send the same request again with expectedCount from the refusal.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::ConfirmationMismatch, 'expectedCount differs from the number of journal lines; nothing was posted.', 'Preview the posting and send the current count.'));
        Errors.Add(Contract.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'The caller does not hold the BIFROST MfgPost ori permission set.', 'Ask an administrator to assign BIFROST MfgPost ori.'));
    end;

    /// <summary>Declares read effects for Get and PreviewPost and an irreversible committing effect for Post.</summary>
    internal procedure GetEffect(Kind: Integer; var Effect: JsonObject)
    var
        Preconditions: JsonArray;
    begin
        Preconditions.Add('The production order is Released.');
        if Kind < 2 then begin
            Effect.Add('effect', 'read');
            Effect.Add('idempotent', true);
            Effect.Add('permissionSet', 'BIFROST MfgRead ori');
            if Kind = 0 then
                Effect.Add('changes', 'Changes nothing. The journal is built with Business Central and rolled back.')
            else
                Effect.Add('changes', 'Changes nothing. The posting runs as a preview and is rolled back.');
            Effect.Add('preconditions', Preconditions);
            exit;
        end;
        Effect.Add('effect', 'irreversible');
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', 'BIFROST Mfg ori + BIFROST MfgPost ori');
        Effect.Add('count', 'non-empty production journal lines');
        Effect.Add('changes', 'This call commits and cannot be undone. Posts output and consumption of the production order with the standard Business Central production journal: item ledger, capacity ledger and value entries.');
        Preconditions.Add('The caller holds BIFROST MfgPost ori.');
        Preconditions.Add('expectedCount equal to the number of non-empty journal lines when the company requires confirmation.');
        Preconditions.Add('The caller has native permissions on the entries the posting creates.');
        Effect.Add('preconditions', Preconditions);
    end;

    /// <summary>Names the other lifecycle operations.</summary>
    internal procedure GetRelated(Kind: Integer; var Related: JsonArray)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
    begin
        if Kind <> 0 then
            Related.Add(Contract.RelatedEntry('Manufacturing.ProductionJournal.Get', 'Read what the journal proposes first.'));
        if Kind <> 1 then
            Related.Add(Contract.RelatedEntry('Manufacturing.ProductionJournal.PreviewPost', 'See the entries before posting.'));
        if Kind <> 2 then
            Related.Add(Contract.RelatedEntry('Manufacturing.ProductionJournal.Post', 'Post output and consumption.'));
        Related.Add(Contract.RelatedEntry('Manufacturing.ProductionOrder.ChangeStatus', 'Release the order first.'));
        Related.Add(Contract.RelatedEntry('Manufacturing.ProductionOrder.Finish', 'Finish the order once output is posted.'));
        Related.Add(Contract.RelatedEntry('Data.Records.Get', 'Read item ledger entries and order lines.'));
    end;

    /// <summary>Explains the lifecycle.</summary>
    internal procedure GetWorkflow(var Workflow: JsonObject)
    var
        Contract: Codeunit "Msg Contract Mgt ori";
        Steps: JsonArray;
    begin
        Steps.Add(Contract.WorkflowStep('Manufacturing.ProductionOrder.ChangeStatus', 'Release the order; the journal exists only for a Released order.'));
        Steps.Add(Contract.WorkflowStep('Manufacturing.ProductionJournal.Get', 'Read the proposal; edit a quantity in proposedLines if needed.'));
        Steps.Add(Contract.WorkflowStep('Manufacturing.ProductionJournal.PreviewPost', 'Optionally preview the entries.'));
        Steps.Add(Contract.WorkflowStep('Manufacturing.ProductionJournal.Post', 'Post with expectedCount from the ConfirmationRequired refusal. Repeat for partial output.'));
        Steps.Add(Contract.WorkflowStep('Manufacturing.ProductionOrder.Finish', 'Finish the order when all output is posted.'));
        Workflow.Add('steps', Steps);
        Workflow.Add('text', 'Output is posted first on the last operation; a second Post continues from the remaining quantities.');
    end;

    /// <summary>Provides a data payload example.</summary>
    internal procedure GetExamples(Kind: Integer; var Examples: JsonArray)
    var
        Example: JsonObject;
        Request: JsonObject;
        Data: JsonObject;
    begin
        Data.Add('no', '101001');
        case Kind of
            0:
                begin
                    Example.Add('title', 'Read the proposal of a released order');
                    Request.Add('type', 'Manufacturing.ProductionJournal.Get');
                end;
            1:
                begin
                    Example.Add('title', 'Preview the posting of the proposal');
                    Request.Add('type', 'Manufacturing.ProductionJournal.PreviewPost');
                end;
            2:
                begin
                    Example.Add('title', 'Post the proposal after the confirmation count');
                    Request.Add('type', 'Manufacturing.ProductionJournal.Post');
                    Data.Add('expectedCount', 2);
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
                Overview := 'Shows what the production journal of a released production order proposes. Changes nothing.';
            1:
                Overview := 'Shows the entries that posting output and consumption would create. Changes nothing.';
            2:
                Overview := 'Posts output and consumption of a released production order with the standard Business Central production journal. This call commits and cannot be undone.';
        end;
    end;

    /// <summary>Documents transaction and generic write behaviour.</summary>
    internal procedure GetNotes(Kind: Integer; var Notes: Text)
    begin
        Notes := 'The journal is built with Business Central''s Production Journal Mgt, so flushing methods, routing links, picks and blocked items follow standard rules. ' +
            'The calling user''s own production journal batch is used and never keeps lines from this call. ';
        if Kind = 2 then
            Notes += 'This call commits. Generic writes: Data.Records.Set on Item Journal Line is deliberately not restricted by this app, because Item Journal Line is shared with every inventory flow and Foundation''s generic journal types stay open; the dedicated type is the supported path for production output and consumption.';
    end;
}
