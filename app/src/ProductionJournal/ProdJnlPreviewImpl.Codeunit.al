namespace Origo.Bifrost.Manufacturing;

using Microsoft.Finance.GeneralLedger.Preview;
using Microsoft.Foundation.Navigate;
using Microsoft.Inventory.Journal;
using Microsoft.Manufacturing.Document;
using Origo.Bifrost;

/// <summary>Executes Manufacturing.ProductionJournal.PreviewPost.</summary>
codeunit 10077073 "Prod Jnl Preview Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        Contract: Codeunit "Mfg ProdJnl Contract ori";

    /// <summary>Discovery: listed to a caller who can build journal lines.</summary>
    procedure IsEnabled(): Boolean
    var
        JournalLine: RecordRef;
        HasPermission: Boolean;
    begin
        JournalLine.Open(Database::"Item Journal Line");
        HasPermission := JournalLine.WritePermission();
        JournalLine.Close();
        exit(HasPermission);
    end;

    /// <summary>Identifies the production order table for discovery.</summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Production Order");
    end;

    /// <summary>Declares an inbound operation.</summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Inbound);
    end;

    /// <summary>Returns localized catalogue text.</summary>
    procedure GetDescription(): Text[250]
    var
        ValueLbl: Label 'Shows the entries that posting output and consumption would create. Changes nothing.', Comment = 'is-IS=Sýnir færslurnar sem bókun afkasta og notkunar myndi búa til. Breytir engu.';
    begin
        exit(ValueLbl);
    end;

    /// <summary>Returns localized catalogue keywords.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'preview posting, production journal, output, consumption, simulate, what would post, manufacturing', Comment = 'is-IS=forskoða bókun, framleiðslubók, afköst, notkun, herma, hvað myndi bókast, framleiðsla';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Returns localized selection text.</summary>
    procedure GetSelectionDescription(): Text
    var
        ValueLbl: Label 'Preview the entries that posting output and consumption would create. Changes nothing.', Comment = 'is-IS=Forskoðaðu færslurnar sem bókun afkasta og notkunar myndi búa til. Breytir engu.';
    begin
        exit(ValueLbl);
    end;

    /// <summary>Returns the envelope chapter.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Contract.GetEnvelope(Envelope);
        exit(true);
    end;

    /// <summary>Returns the target chapter.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        Contract.GetTarget(Target);
        exit(true);
    end;

    /// <summary>Returns the parameters chapter.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        Contract.GetParameters(1, Parameters);
        exit(true);
    end;

    /// <summary>Returns the response chapter.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Contract.GetResponse(1, Response);
        exit(true);
    end;

    /// <summary>Returns the errors chapter.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        Contract.GetErrors(1, Errors);
        exit(true);
    end;

    /// <summary>Returns the effect chapter.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Contract.GetEffect(1, Effect);
        exit(true);
    end;

    /// <summary>Returns the related chapter.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        Contract.GetRelated(1, Related);
        exit(true);
    end;

    /// <summary>Returns the workflow chapter.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        Contract.GetWorkflow(Workflow);
        exit(true);
    end;

    /// <summary>Returns the examples chapter.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        Contract.GetExamples(1, Examples);
        exit(true);
    end;

    /// <summary>Returns the overview chapter.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Contract.GetOverview(1, Overview);
        exit(true);
    end;

    /// <summary>Returns the notes chapter.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Contract.GetNotes(1, Notes);
        exit(true);
    end;

    /// <summary>Declares no app-specific metering in addition to Foundation.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Builds the journal, runs the posting and reads the entries, then rolls everything back.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        ProductionOrder: Record "Production Order";
        TempDocumentEntry: Record "Document Entry" temporary;
        Request: Codeunit "Prod Jnl Request ori";
        Lookup: Codeunit "Mfg Prod Order Lookup ori";
        Events: Codeunit "Prod Jnl Events ori";
        Process: Codeunit "Prod Jnl Post Proc ori";
        GenJnlPostPreview: Codeunit "Gen. Jnl.-Post Preview";
        PostingPreviewEventHandler: Codeunit "Posting Preview Event Handler";
        PreviewHelper: Codeunit "Posting Preview Helper ori";
        Result: JsonObject;
        Preview: JsonArray;
        PreviewFieldNames: List of [Text];
        Totals: JsonObject;
        Balanced: Boolean;
        EntryCount: Integer;
        GLEntryCount: Integer;
        NothingToPost: Boolean;
        LinesToPost: Integer;
        PostingDate: Date;
        Basis: Integer;
        OmitCommitLbl: Label 'Preview needs its own transaction and cannot run under Omit Commit.', Comment = 'is-IS=Forskoðun þarf eigin færslu og getur ekki keyrt undir Omit Commit.';
        OmitCommitNextLbl: Label 'Run the preview without Omit Commit.', Comment = 'is-IS=Keyrðu forskoðunina án Omit Commit.';
        BcNextLbl: Label 'Inspect the production order, correct the item, work center, quantity or period named in the Business Central error and retry. Nothing was changed.', Comment = 'is-IS=Skoðaðu framleiðslupöntunina, leiðréttu vöruna, vinnustöðina, magnið eða tímabilið sem Business Central nefnir í villunni og reyndu aftur. Engu var breytt.';
        NothingLbl: Label 'Nothing to post: every journal line has quantity 0.', Comment = 'is-IS=Ekkert að bóka: allar línur í framleiðslubók hafa magn 0.';
        NothingNextLbl: Label 'Read the proposal with Manufacturing.ProductionJournal.Get or send lines with a quantity.', Comment = 'is-IS=Lestu tillöguna með Manufacturing.ProductionJournal.Get eða sendu línur með magni.';
        SummaryLbl: Label 'Posting %1 journal lines of production order %2 would create %3 ledger entries across %4 tables.', Comment = '%1 = line count, %2 = order number, %3 = entry count, %4 = table count, is-IS=Bókun %1 lína í framleiðslubók framleiðslupöntunar %2 myndi stofna %3 færslur í %4 töflum.';
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        if not Request.Read(Argument, 1, ProductionOrder) then
            exit;
        if Argument."Omit Commit" then begin
            Events.EndRequest();
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, OmitCommitLbl, '', '', '', OmitCommitNextLbl);
            exit;
        end;
        BindSubscription(Process);
        GenJnlPostPreview.SetContext(Process, Argument);
        ClearLastError();
        if GenJnlPostPreview.Run() then; // the standard preview always ends in a rollback error
        UnbindSubscription(Process);
        Events.GetOutcome(Result, NothingToPost);
        if not NothingToPost then
            if not GenJnlPostPreview.IsSuccess() then begin
                Events.EndRequest();
                Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, GetLastErrorText(), '', '', '', BcNextLbl);
                exit;
            end;
        LinesToPost := Events.GetPreviewLines();
        Events.GetUsedSetup(PostingDate, Basis);
        Events.EndRequest();
        if NothingToPost then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, NothingLbl, 'lines', '', '', NothingNextLbl);
            exit;
        end;
        GenJnlPostPreview.GetPreviewHandler(PostingPreviewEventHandler);
        PreviewHelper.GetPreviewFieldNames(PreviewFieldNames);
        PostingPreviewEventHandler.FillDocumentEntry(TempDocumentEntry);
        if TempDocumentEntry.FindSet() then
            repeat
                PreviewHelper.AddTableToPreview(Preview, PostingPreviewEventHandler, TempDocumentEntry."Table ID", TempDocumentEntry."Table Name", PreviewFieldNames);
            until TempDocumentEntry.Next() = 0;
        if not PreviewHelper.EvaluatePreviewOutcome(Argument, Preview, PostingPreviewEventHandler, NothingNextLbl, Totals, Balanced, EntryCount, GLEntryCount) then
            exit;
        Result.Add('entryCount', EntryCount);
        Result.Add('glEntryCount', GLEntryCount);
        Result.Add('preview', Preview);
        Result.Add('status', 'Success');
        Result.Add('rollback', true);
        Result.Add('summary', StrSubstNo(SummaryLbl, LinesToPost, ProductionOrder."No.", EntryCount, Preview.Count()));
        Result.Add('no', ProductionOrder."No.");
        Result.Add('productionOrderStatus', Lookup.StatusName(ProductionOrder.Status));
        Result.Add('postingDate', Format(PostingDate, 0, 9));
        Result.Add('linesToPost', LinesToPost);
        Argument.SetResponseJson(Result);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

}
