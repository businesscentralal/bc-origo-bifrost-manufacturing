namespace Origo.Bifrost.Manufacturing;

using Microsoft.Inventory.Journal;
using Microsoft.Manufacturing.Document;
using Microsoft.Manufacturing.Journal;
using Origo.Bifrost;

/// <summary>
/// Implements Manufacturing.Journal.CalculateConsumption using Microsoft's Calc. Consumption report.
/// </summary>
codeunit 10077044 "Mfg Calc Consumption Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    TableNo = "Message Argument ori";

    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Contract: Codeunit "Mfg Action Contract ori";
        JournalTemplateRequiredErr: Label 'Provide a journal template name in data.journalTemplateName.', Comment = 'is-IS=Tilgreindu heiti færslubókarsniðmáts í data.journalTemplateName.';
        JournalBatchNotFoundErr: Label 'Journal batch %1 does not exist in template %2.', Comment = '%1 = batch name, %2 = template name||is-IS=Færslubókarlota %1 er ekki til í sniðmáti %2.';
        JournalBatchEmptyErr: Label 'Journal batch %1 in template %2 has no lines to post.', Comment = '%1 = batch name, %2 = template name||is-IS=Færslubókarlota %1 í sniðmáti %2 inniheldur engar línur til bókunar.';
        JournalLineNotFoundErr: Label 'Journal line %1 does not exist in batch %2.', Comment = '%1 = line number, %2 = batch name||is-IS=Færslubókarlína %1 er ekki til í lotu %2.';
        ConsumptionTemplateErr: Label 'Use a Consumption journal template.', Comment = 'is-IS=Notaðu færslubókarsniðmát fyrir notkun.';
        OutputTemplateErr: Label 'Use an Output journal template.', Comment = 'is-IS=Notaðu færslubókarsniðmát fyrir afköst.';
        ProductionTemplateErr: Label 'Use a Consumption or Output journal template.', Comment = 'is-IS=Notaðu færslubókarsniðmát fyrir notkun eða afköst.';
        ProductionLineErr: Label 'Only production-order consumption or output lines can be processed.', Comment = 'is-IS=Aðeins má vinna notkunar- eða afkastalínur framleiðslupantana.';
        DescriptionLbl: Label 'Calculates consumption, explodes output routing, or posts a production journal batch.', MaxLength = 250, Comment = 'is-IS=Reiknar notkun, springur út afkastaleið eða bókar framleiðslufærslubókarlotu.';

    /// <summary>Reports whether the calculation is available.</summary>
    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    /// <summary>Returns the journal batch table used to filter this operation.</summary>
    procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Item Journal Batch");
    end;

    /// <summary>Describes the consumption calculation.</summary>
    procedure GetDescription() Description: Text[250]
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns search terms for the consumption calculation.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'production journal, consumption, calculate consumption, explode routing, post journal, output, batch', Comment = 'is-IS=framleiðslufærslubók, notkun, reikna notkun, springa út leið, bóka færslubók, afköst, lota';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Explains the operation's data-changing effect when a caller selects it.</summary>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Calculate adds consumption lines; ExplodeRouting replaces one output line with routing lines; Post records the batch. Review journal lines before posting.', Comment = 'is-IS=Calculate bætir notkunarlínum við; ExplodeRouting skiptir einni afkastalínu út fyrir leiðarlínur; Post færir lotuna. Farðu yfir línur áður en þær eru bókaðar.';
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
        Subject.Add('description', 'Journal batch name. When set, it takes precedence over data.journalBatchName.');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    /// <summary>Describes how this operation identifies the journal batch.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        Target.Add(ContractMgt.TargetEntry('data.journalTemplateName', 'journal template name', 'The journal template that contains the batch.'));
        Target.Add(ContractMgt.TargetEntry('subject', 'journal batch name', 'Used when the subject is set.'));
        Target.Add(ContractMgt.TargetEntry('data.journalBatchName', 'journal batch name', 'Used when the subject is empty.'));
        exit(true);
    end;

    /// <summary>Describes the request parameters.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        JournalLineNoParameter: JsonObject;
    begin
        Parameters.Add(ContractMgt.Parameter('journalTemplateName', 'string', true, 'The template that contains the consumption journal batch.'));
        Parameters.Add(ContractMgt.Parameter('journalBatchName', 'string', false, 'The batch to receive calculated lines. May be supplied as the subject instead.'));
        JournalLineNoParameter.Add('name', 'journalLineNo');
        JournalLineNoParameter.Add('type', 'integer');
        JournalLineNoParameter.Add('required', false);
        JournalLineNoParameter.Add('description', 'Required only for Manufacturing.Journal.ExplodeRouting; identifies the output journal line to replace with routing lines.');
        Parameters.Add(JournalLineNoParameter);
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
        ResponseField.Add('description', 'Success when consumption lines were calculated.');
        Fields.Add(ResponseField);
        Clear(ResponseField);
        ResponseField.Add('name', 'journalTemplateName');
        ResponseField.Add('type', 'string');
        ResponseField.Add('description', 'The journal template used.');
        Fields.Add(ResponseField);
        Clear(ResponseField);
        ResponseField.Add('name', 'journalLinesPosted');
        ResponseField.Add('type', 'integer');
        ResponseField.Add('description', 'The number of journal lines submitted for posting; returned by Manufacturing.Journal.Post.');
        Fields.Add(ResponseField);
        Clear(ResponseField);
        ResponseField.Add('name', 'journalLinesDeleted');
        ResponseField.Add('type', 'integer');
        ResponseField.Add('description', 'The number of source lines replaced; returned by Manufacturing.Journal.ExplodeRouting.');
        Fields.Add(ResponseField);
        Clear(ResponseField);
        ResponseField.Add('name', 'journalLineNo');
        ResponseField.Add('type', 'integer');
        ResponseField.Add('description', 'The source output journal line used for route explosion.');
        Fields.Add(ResponseField);
        Clear(ResponseField);
        ResponseField.Add('name', 'journalBatchName');
        ResponseField.Add('type', 'string');
        ResponseField.Add('description', 'The journal batch updated.');
        Fields.Add(ResponseField);
        Clear(ResponseField);
        ResponseField.Add('name', 'journalLinesCreated');
        ResponseField.Add('type', 'integer');
        ResponseField.Add('description', 'The number of consumption lines added by this call.');
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
        Effect.Add('changes', 'Adds consumption lines, posts the selected journal batch, or replaces an output line with routing lines.');
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

    /// <summary>Describes the consumption calculation workflow.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Steps: JsonArray;
    begin
        Steps.Add(ContractMgt.WorkflowStep('Manufacturing.Journal.CalculateConsumption', 'Calculate consumption, explode a selected output line into routing lines, review the batch, then post it.'));
        Steps.Add(ContractMgt.WorkflowStep('Manufacturing.Journal.ExplodeRouting', 'Calculate consumption, explode a selected output line into routing lines, review the batch, then post it.'));
        Steps.Add(ContractMgt.WorkflowStep('Manufacturing.Journal.Post', 'Calculate consumption, explode a selected output line into routing lines, review the batch, then post it.'));
        Workflow.Add('steps', Steps);
        exit(true);
    end;

    /// <summary>Provides a representative request and response.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Request: JsonObject;
        RequestData: JsonObject;
        Response: JsonObject;
        Example: JsonObject;
    begin
        RequestData.Add('journalTemplateName', 'X-PROD');
        RequestData.Add('journalBatchName', 'X-DEFAULT');
        Request.Add('type', 'Manufacturing.Journal.CalculateConsumption');
        Request.Add('data', RequestData);
        Response.Add('status', 'Success');
        Response.Add('journalTemplateName', 'X-PROD');
        Response.Add('journalBatchName', 'X-DEFAULT');
        Response.Add('journalLinesCreated', 2);
        Example.Add('title', 'Calculate consumption for a batch');
        Example.Add('request', Request);
        Example.Add('response', Response);
        Examples.Add(Example);

        Clear(Request);
        Clear(RequestData);
        Clear(Response);
        Clear(Example);
        RequestData.Add('journalTemplateName', 'X-PROD');
        RequestData.Add('journalLineNo', 10000);
        Request.Add('type', 'Manufacturing.Journal.ExplodeRouting');
        Request.Add('subject', 'X-DEFAULT');
        Request.Add('data', RequestData);
        Response.Add('status', 'Success');
        Response.Add('journalTemplateName', 'X-PROD');
        Response.Add('journalBatchName', 'X-DEFAULT');
        Response.Add('journalLinesDeleted', 1);
        Response.Add('journalLineNo', 10000);
        Example.Add('title', 'Explode output routing');
        Example.Add('request', Request);
        Example.Add('response', Response);
        Examples.Add(Example);

        Clear(Request);
        Clear(RequestData);
        Clear(Response);
        Clear(Example);
        RequestData.Add('journalTemplateName', 'X-PROD');
        RequestData.Add('journalBatchName', 'X-DEFAULT');
        Request.Add('type', 'Manufacturing.Journal.Post');
        Request.Add('data', RequestData);
        Response.Add('status', 'Success');
        Response.Add('journalTemplateName', 'X-PROD');
        Response.Add('journalBatchName', 'X-DEFAULT');
        Response.Add('journalLinesPosted', 2);
        Example.Add('title', 'Post a production journal batch');
        Example.Add('request', Request);
        Example.Add('response', Response);
        Examples.Add(Example);
        exit(true);
    end;

    /// <summary>Explains when to use consumption calculation.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'CalculateConsumption fills an Item Journal Batch with outstanding production component consumption. ExplodeRouting replaces a selected output line with routing-operation lines. Post records the batch to the inventory and capacity ledgers.';
        exit(true);
    end;

    /// <summary>Documents important behavior of consumption calculation.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Omit Commit is refused with PreconditionFailed before any write because standard Business Central actions may commit. CalculateConsumption uses Microsoft''s default report options and does not post. ExplodeRouting deletes its source line and inserts calculated operation lines. Post submits all lines in the selected batch through Microsoft''s production journal posting routine.';
        exit(true);
    end;

    /// <summary>Returns the inbound message direction.</summary>
    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    trigger OnRun()
    begin
        PerformCalculate(Rec);
    end;

    /// <summary>Executes this message type through Bifrost Foundation.</summary>
    /// <param name="Argument">The message argument and response record.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        if Argument."Omit Commit" then begin
            PerformCalculate(Argument);
            exit;
        end;

        if not Codeunit.Run(Codeunit::"Mfg Calc Consumption Impl ori", Argument) then
            Argument.RespondWithLastError();
    end;

    local procedure PerformCalculate(var Argument: Record "Message Argument ori")
    var
        ItemJournalTemplate: Record "Item Journal Template";
        ItemJournalBatch: Record "Item Journal Batch";
        ItemJournalLine: Record "Item Journal Line";
        ConsumptionReport: Report "Calc. Consumption";
        PostingDialog: Codeunit "Mfg Posting Dialog ori";
        ResponseJson: JsonObject;
        JournalTemplateName: Code[10];
        JournalBatchName: Code[10];
        ParameterText: Text;
        AllowedKeys: Text;
        JournalLineNo: Integer;
        LinesBefore: Integer;
        LinesAfter: Integer;
    begin
        AllowedKeys := '|journalTemplateName|journalBatchName|';
        if Argument.Type = Enum::"Message Type ori"::"Manufacturing.Journal.ExplodeRouting" then
            AllowedKeys += '|journalLineNo|';
        if not Contract.ValidateKeys(Argument, AllowedKeys) then
            exit;
        if not Contract.ReadCode(Argument, 'journalTemplateName', '', MaxStrLen(JournalTemplateName), ParameterText) then
            exit;
        JournalTemplateName := CopyStr(ParameterText, 1, MaxStrLen(JournalTemplateName));
        if not Contract.ReadCode(Argument, 'journalBatchName', Argument.Subject, MaxStrLen(JournalBatchName), ParameterText) then
            exit;
        JournalBatchName := CopyStr(ParameterText, 1, MaxStrLen(JournalBatchName));
        if Argument.Type = Enum::"Message Type ori"::"Manufacturing.Journal.ExplodeRouting" then
            if not Contract.ReadPositiveInteger(Argument, 'journalLineNo', JournalLineNo) then
                exit;
        if not Contract.HasPermission(Argument, ItemJournalTemplate.ReadPermission(), true) then
            exit;
        if not Contract.HasPermission(Argument, ItemJournalBatch.ReadPermission(), ItemJournalBatch.WritePermission()) then
            exit;
        if not Contract.HasPermission(Argument, ItemJournalLine.ReadPermission(), ItemJournalLine.WritePermission()) then
            exit;
        ItemJournalTemplate.LockTable();
        if not ItemJournalTemplate.Get(JournalTemplateName) then begin
            Contract.Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'journalTemplateName', JournalTemplateRequiredErr);
            exit;
        end;
        case Argument.Type of
            Enum::"Message Type ori"::"Manufacturing.Journal.CalculateConsumption":
                if ItemJournalTemplate.Type <> ItemJournalTemplate.Type::Consumption then begin
                    Contract.Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'journalTemplateName', ConsumptionTemplateErr);
                    exit;
                end;
            Enum::"Message Type ori"::"Manufacturing.Journal.ExplodeRouting":
                if ItemJournalTemplate.Type <> ItemJournalTemplate.Type::Output then begin
                    Contract.Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'journalTemplateName', OutputTemplateErr);
                    exit;
                end;
            else
                if not (ItemJournalTemplate.Type in [ItemJournalTemplate.Type::Consumption, ItemJournalTemplate.Type::Output]) then begin
                    Contract.Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'journalTemplateName', ProductionTemplateErr);
                    exit;
                end;
        end;
        ItemJournalBatch.LockTable();
        if not ItemJournalBatch.Get(JournalTemplateName, JournalBatchName) then begin
            Contract.Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'journalBatchName', StrSubstNo(JournalBatchNotFoundErr, JournalBatchName, JournalTemplateName));
            exit;
        end;
        ItemJournalLine.LockTable();
        ItemJournalLine.SetRange("Journal Template Name", JournalTemplateName);
        ItemJournalLine.SetRange("Journal Batch Name", JournalBatchName);
        LinesBefore := ItemJournalLine.Count();
        case Argument.Type of
            Enum::"Message Type ori"::"Manufacturing.Journal.ExplodeRouting":
                begin
                    if not ItemJournalLine.Get(JournalTemplateName, JournalBatchName, JournalLineNo) then begin
                        Contract.Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'journalLineNo', StrSubstNo(JournalLineNotFoundErr, JournalLineNo, JournalBatchName));
                        exit;
                    end;
                    if (ItemJournalLine."Order Type" <> ItemJournalLine."Order Type"::Production) or
                       (ItemJournalLine."Entry Type" <> ItemJournalLine."Entry Type"::Output) or (ItemJournalLine."Order No." = '')
                    then begin
                        Contract.Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'journalLineNo', ProductionLineErr);
                        exit;
                    end;
                    if not Contract.RequireCommittingCall(Argument) then
                        exit;
                    Codeunit.Run(Codeunit::"Output Jnl.-Expl. Route", ItemJournalLine);
                    ItemJournalLine.Reset();
                    ItemJournalLine.SetRange("Journal Template Name", JournalTemplateName);
                    ItemJournalLine.SetRange("Journal Batch Name", JournalBatchName);
                    LinesAfter := ItemJournalLine.Count();
                end;
            Enum::"Message Type ori"::"Manufacturing.Journal.Post":
                begin
                    if LinesBefore = 0 then begin
                        Contract.Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'journalBatchName', StrSubstNo(JournalBatchEmptyErr, JournalBatchName, JournalTemplateName));
                        exit;
                    end;
                    if ItemJournalLine.FindSet() then
                        repeat
                            if (ItemJournalLine."Order Type" <> ItemJournalLine."Order Type"::Production) or
                               (ItemJournalLine."Order No." = '') or
                               not (ItemJournalLine."Entry Type" in [ItemJournalLine."Entry Type"::Consumption, ItemJournalLine."Entry Type"::Output])
                            then begin
                                Contract.Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'journalBatchName', ProductionLineErr);
                                exit;
                            end;
                        until ItemJournalLine.Next() = 0;
                    if not Contract.RequireCommittingCall(Argument) then
                        exit;
                    ItemJournalLine.FindFirst();
                    BindSubscription(PostingDialog);
                    ItemJournalLine.PostingItemJnlFromProduction(false);
                    UnbindSubscription(PostingDialog);
                    LinesAfter := LinesBefore;
                end;
            else begin
                if not Contract.RequireCommittingCall(Argument) then
                    exit;
                ConsumptionReport.SetTemplateAndBatchName(JournalTemplateName, JournalBatchName);
                ConsumptionReport.InitializeRequest(WorkDate(), 0);
                ConsumptionReport.UseRequestPage(false);
                ConsumptionReport.RunModal();
                ItemJournalLine.Reset();
                ItemJournalLine.SetRange("Journal Template Name", JournalTemplateName);
                ItemJournalLine.SetRange("Journal Batch Name", JournalBatchName);
                LinesAfter := ItemJournalLine.Count();
            end;
        end;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('journalTemplateName', JournalTemplateName);
        ResponseJson.Add('journalBatchName', JournalBatchName);
        case Argument.Type of
            Enum::"Message Type ori"::"Manufacturing.Journal.Post":
                ResponseJson.Add('journalLinesPosted', LinesBefore);
            Enum::"Message Type ori"::"Manufacturing.Journal.ExplodeRouting":
                begin
                    ResponseJson.Add('journalLinesCreated', LinesAfter - LinesBefore + 1);
                    ResponseJson.Add('journalLinesDeleted', 1);
                    ResponseJson.Add('journalLineNo', JournalLineNo);
                end;
            else
                ResponseJson.Add('journalLinesCreated', LinesAfter - LinesBefore);
        end;
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
