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
        JournalTemplateRequiredErr: Label 'Provide a journal template name in data.journalTemplateName.', Comment = 'is-IS=Tilgreindu heiti færslubókarsniðmáts í data.journalTemplateName.';
        JournalBatchRequiredErr: Label 'Provide a journal batch name in the subject or data.journalBatchName.', Comment = 'is-IS=Tilgreindu heiti færslubókarlotu í subject eða data.journalBatchName.';
        JournalBatchNotFoundErr: Label 'Journal batch %1 does not exist in template %2.', Comment = '%1 = batch name, %2 = template name||is-IS=Færslubókarlota %1 er ekki til í sniðmáti %2.';
        JournalBatchEmptyErr: Label 'Journal batch %1 in template %2 has no lines to post.', Comment = '%1 = batch name, %2 = template name||is-IS=Færslubókarlota %1 í sniðmáti %2 inniheldur engar línur til bókunar.';
        JournalLineNoRequiredErr: Label 'Provide journalLineNo for Manufacturing.Journal.ExplodeRouting.', Comment = 'is-IS=Tilgreindu journalLineNo fyrir Manufacturing.Journal.ExplodeRouting.';
        JournalLineNotFoundErr: Label 'Journal line %1 does not exist in batch %2.', Comment = '%1 = line number, %2 = batch name||is-IS=Færslubókarlína %1 er ekki til í lotu %2.';
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
    var
        ErrorInfo: JsonObject;
    begin
        ErrorInfo.Add('error', 'Journal batch not found.');
        ErrorInfo.Add('when', 'The template and batch names do not identify an existing Item Journal Batch.');
        ErrorInfo.Add('fix', 'Check journalTemplateName and journalBatchName.');
        Errors.Add(ErrorInfo);
        Clear(ErrorInfo);
        ErrorInfo.Add('error', 'Journal batch is empty.');
        ErrorInfo.Add('when', 'Manufacturing.Journal.Post is called for a batch without lines.');
        ErrorInfo.Add('fix', 'Add or calculate journal lines before posting the batch.');
        Errors.Add(ErrorInfo);
        Clear(ErrorInfo);
        ErrorInfo.Add('error', 'Journal line not found.');
        ErrorInfo.Add('when', 'journalLineNo does not identify a line in the selected batch.');
        ErrorInfo.Add('fix', 'Check the line number and the selected journal template and batch.');
        Errors.Add(ErrorInfo);
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
        WorkflowStep: JsonObject;
    begin
        WorkflowStep.Add('messageType', 'Manufacturing.Journal.CalculateConsumption, Manufacturing.Journal.ExplodeRouting, or Manufacturing.Journal.Post');
        WorkflowStep.Add('purpose', 'Calculate consumption, explode a selected output line into routing lines, review the batch, then post it.');
        Steps.Add(WorkflowStep);
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
        Notes := 'CalculateConsumption uses Microsoft''s default report options and does not post. ExplodeRouting deletes its source line and inserts calculated operation lines. Post submits all lines in the selected batch through Microsoft''s production journal posting routine.';
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
        ItemJournalBatch: Record "Item Journal Batch";
        ItemJournalLine: Record "Item Journal Line";
        ConsumptionReport: Report "Calc. Consumption";
        RequestJson: JsonObject;
        RequestToken: JsonToken;
        ResponseJson: JsonObject;
        JournalTemplateName: Code[10];
        JournalBatchName: Code[10];
        JournalBatchNameText: Text;
        JournalLineNo: Integer;
        LinesBefore: Integer;
        LinesAfter: Integer;
    begin
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('journalTemplateName', RequestToken) then
            Error(JournalTemplateRequiredErr);
        if not RequestToken.IsValue() then
            Error(JournalTemplateRequiredErr);
        if StrLen(RequestToken.AsValue().AsText()) > MaxStrLen(JournalTemplateName) then
            Error(JournalTemplateRequiredErr);
        JournalTemplateName := CopyStr(RequestToken.AsValue().AsText(), 1, MaxStrLen(JournalTemplateName));

        JournalBatchNameText := Argument.Subject;
        if JournalBatchNameText = '' then begin
            if not RequestJson.Get('journalBatchName', RequestToken) then
                Error(JournalBatchRequiredErr);
            if not RequestToken.IsValue() then
                Error(JournalBatchRequiredErr);
            JournalBatchNameText := RequestToken.AsValue().AsText();
        end;
        if StrLen(JournalBatchNameText) > MaxStrLen(JournalBatchName) then
            Error(JournalBatchRequiredErr);
        JournalBatchName := CopyStr(JournalBatchNameText, 1, MaxStrLen(JournalBatchName));

        if not ItemJournalBatch.Get(JournalTemplateName, JournalBatchName) then
            Error(JournalBatchNotFoundErr, JournalBatchName, JournalTemplateName);

        ItemJournalLine.SetLoadFields("Journal Template Name", "Journal Batch Name", "Line No.");
        ItemJournalLine.SetRange("Journal Template Name", JournalTemplateName);
        ItemJournalLine.SetRange("Journal Batch Name", JournalBatchName);
        LinesBefore := ItemJournalLine.Count();
        case Argument.Type of
            Enum::"Message Type ori"::"Manufacturing.Journal.ExplodeRouting":
                begin
                    if not RequestJson.Get('journalLineNo', RequestToken) then
                        Error(JournalLineNoRequiredErr);
                    if not Evaluate(JournalLineNo, RequestToken.AsValue().AsText(), 9) then
                        Error(JournalLineNoRequiredErr);
                    if JournalLineNo <= 0 then
                        Error(JournalLineNoRequiredErr);

                    ItemJournalLine.Reset();
                    ItemJournalLine.SetLoadFields();
                    if not ItemJournalLine.Get(JournalTemplateName, JournalBatchName, JournalLineNo) then
                        Error(JournalLineNotFoundErr, JournalLineNo, JournalBatchName);
                    Codeunit.Run(Codeunit::"Output Jnl.-Expl. Route", ItemJournalLine);

                    ItemJournalLine.Reset();
                    ItemJournalLine.SetLoadFields("Journal Template Name", "Journal Batch Name", "Line No.");
                    ItemJournalLine.SetRange("Journal Template Name", JournalTemplateName);
                    ItemJournalLine.SetRange("Journal Batch Name", JournalBatchName);
                    LinesAfter := ItemJournalLine.Count();
                end;
            Enum::"Message Type ori"::"Manufacturing.Journal.Post":
                begin
                    if LinesBefore = 0 then
                        Error(JournalBatchEmptyErr, JournalBatchName, JournalTemplateName);
                    ItemJournalLine.PostingItemJnlFromProduction(false);
                    LinesAfter := LinesBefore;
                end;
            else begin
                ConsumptionReport.SetTemplateAndBatchName(JournalTemplateName, JournalBatchName);
                ConsumptionReport.RunModal();

                ItemJournalLine.Reset();
                ItemJournalLine.SetLoadFields("Journal Template Name", "Journal Batch Name", "Line No.");
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