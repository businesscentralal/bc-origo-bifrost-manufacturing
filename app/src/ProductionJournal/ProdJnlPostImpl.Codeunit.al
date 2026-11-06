namespace Origo.Bifrost.Manufacturing;

using Microsoft.Finance.GeneralLedger.Preview;
using Microsoft.Foundation.Navigate;
using Microsoft.Inventory.Journal;
using Microsoft.Manufacturing.Document;
using Origo.Bifrost;

/// <summary>Executes Manufacturing.ProductionJournal.Post.</summary>
codeunit 10077074 "Prod Jnl Post Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        Contract: Codeunit "Mfg ProdJnl Contract ori";

    /// <summary>Discovery: listed only with the BIFROST MfgPost ori posting token.</summary>
    procedure IsEnabled(): Boolean
    var
        PostingGate: Codeunit "Mfg Posting Gate ori";
    begin
        exit(PostingGate.HasPostingPermission());
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
        ValueLbl: Label 'Posts output and consumption of a released production order with the standard Business Central production journal. Commits and cannot be undone.', Comment = 'is-IS=Bókar afköst og notkun útgefinnar framleiðslupöntunar með venjulegri framleiðslubók Business Central. Framkvæmir Commit og ekki er hægt að afturkalla.';
    begin
        exit(ValueLbl);
    end;

    /// <summary>Returns localized catalogue keywords.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'post production journal, post output, post consumption, scrap, run time, setup time, released production order, manufacturing', Comment = 'is-IS=bóka framleiðslubók, bóka afköst, bóka notkun, rýrnun, keyrslutími, uppsetningartími, útgefin framleiðslupöntun, framleiðsla';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Returns localized selection text.</summary>
    procedure GetSelectionDescription(): Text
    var
        ValueLbl: Label 'Post output and consumption of a released order. Commits and cannot be undone.', Comment = 'is-IS=Bókaðu afköst og notkun útgefinnar pöntunar. Framkvæmir Commit og ekki er hægt að afturkalla.';
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
        Contract.GetParameters(2, Parameters);
        exit(true);
    end;

    /// <summary>Returns the response chapter.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Contract.GetResponse(2, Response);
        exit(true);
    end;

    /// <summary>Returns the errors chapter.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        Contract.GetErrors(2, Errors);
        exit(true);
    end;

    /// <summary>Returns the effect chapter.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Contract.GetEffect(2, Effect);
        exit(true);
    end;

    /// <summary>Returns the related chapter.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        Contract.GetRelated(2, Related);
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
        Contract.GetExamples(2, Examples);
        exit(true);
    end;

    /// <summary>Returns the overview chapter.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Contract.GetOverview(2, Overview);
        exit(true);
    end;

    /// <summary>Returns the notes chapter.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Contract.GetNotes(2, Notes);
        exit(true);
    end;

    /// <summary>Declares no app-specific metering in addition to Foundation.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Checks the token, builds the journal, confirms the count and posts; a refusal leaves no journal line.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        ProductionOrder: Record "Production Order";
        Request: Codeunit "Prod Jnl Request ori";
        WriteCheck: Codeunit "Mfg Write Check ori";
        PostingGate: Codeunit "Mfg Posting Gate ori";
        Events: Codeunit "Prod Jnl Events ori";
        Result: JsonObject;
        NothingToPost: Boolean;
        BcNextLbl: Label 'Inspect the production order, correct the item, work center, quantity or period named in the Business Central error and retry. Nothing was changed.', Comment = 'is-IS=Skoðaðu framleiðslupöntunina, leiðréttu vöruna, vinnustöðina, magnið eða tímabilið sem Business Central nefnir í villunni og reyndu aftur. Engu var breytt.';
        NothingLbl: Label 'Nothing to post: every journal line has quantity 0.', Comment = 'is-IS=Ekkert að bóka: allar línur í framleiðslubók hafa magn 0.';
        NothingNextLbl: Label 'Read the proposal with Manufacturing.ProductionJournal.Get or send lines with a quantity.', Comment = 'is-IS=Lestu tillöguna með Manufacturing.ProductionJournal.Get eða sendu línur með magni.';
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        WriteCheck.AssertCanWrite('Manufacturing.ProductionJournal.Post');
        if not PostingGate.AssertCanPost(Argument) then
            exit;
        if not Request.Read(Argument, 2, ProductionOrder) then
            exit;
        // Business Central commits inside the posting; the commit is not suppressed under Omit Commit.
        if Argument."Omit Commit" then
            Codeunit.Run(Codeunit::"Prod Jnl Post Proc ori", Argument)
        else
            if not Codeunit.Run(Codeunit::"Prod Jnl Post Proc ori", Argument) then begin
                Events.EndRequest();
                Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, GetLastErrorText(), '', '', '', BcNextLbl);
                exit;
            end;
        if not Events.GetOutcome(Result, NothingToPost) then begin
            Events.EndRequest();
            exit; // the confirmation gate has answered
        end;
        Events.EndRequest();
        if NothingToPost then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, NothingLbl, 'lines', '', '', NothingNextLbl);
            exit;
        end;
        Result.Add('status', 'Success');
        Argument.SetResponseJson(Result);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
