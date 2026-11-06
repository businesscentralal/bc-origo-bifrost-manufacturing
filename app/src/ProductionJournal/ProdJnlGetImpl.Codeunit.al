namespace Origo.Bifrost.Manufacturing;

using Microsoft.Finance.GeneralLedger.Preview;
using Microsoft.Foundation.Navigate;
using Microsoft.Inventory.Journal;
using Microsoft.Manufacturing.Document;
using Origo.Bifrost;

/// <summary>Executes Manufacturing.ProductionJournal.Get.</summary>
codeunit 10077072 "Prod Jnl Get Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
        ValueLbl: Label 'Shows what the production journal of a released production order proposes: output per operation and consumption per component.', Comment = 'is-IS=Sýnir hvað framleiðslubók útgefinnar framleiðslupöntunar leggur til: afköst á hverja aðgerð og notkun á hvern íhlut.';
    begin
        exit(ValueLbl);
    end;

    /// <summary>Returns localized catalogue keywords.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'production journal, output, consumption, proposal, released production order, manufacturing, scrap, run time', Comment = 'is-IS=framleiðslubók, afköst, notkun, tillaga, útgefin framleiðslupöntun, framleiðsla, rýrnun, keyrslutími';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Returns localized selection text.</summary>
    procedure GetSelectionDescription(): Text
    var
        ValueLbl: Label 'Read what the production journal of a released order proposes. Changes nothing.', Comment = 'is-IS=Lestu hvað framleiðslubók útgefinnar pöntunar leggur til. Breytir engu.';
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
        Contract.GetParameters(0, Parameters);
        exit(true);
    end;

    /// <summary>Returns the response chapter.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Contract.GetResponse(0, Response);
        exit(true);
    end;

    /// <summary>Returns the errors chapter.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        Contract.GetErrors(0, Errors);
        exit(true);
    end;

    /// <summary>Returns the effect chapter.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Contract.GetEffect(0, Effect);
        exit(true);
    end;

    /// <summary>Returns the related chapter.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        Contract.GetRelated(0, Related);
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
        Contract.GetExamples(0, Examples);
        exit(true);
    end;

    /// <summary>Returns the overview chapter.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Contract.GetOverview(0, Overview);
        exit(true);
    end;

    /// <summary>Returns the notes chapter.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Contract.GetNotes(0, Notes);
        exit(true);
    end;

    /// <summary>Declares no app-specific metering in addition to Foundation.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Builds the proposal in a rolled-back boundary and answers it.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        ProductionOrder: Record "Production Order";
        Request: Codeunit "Prod Jnl Request ori";
        Events: Codeunit "Prod Jnl Events ori";
        Result: JsonObject;
        NothingToPost: Boolean;
        BcNextLbl: Label 'Inspect the production order, correct the item, work center, quantity or period named in the Business Central error and retry. Nothing was changed.', Comment = 'is-IS=Skoðaðu framleiðslupöntunina, leiðréttu vöruna, vinnustöðina, magnið eða tímabilið sem Business Central nefnir í villunni og reyndu aftur. Engu var breytt.';
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        if not Request.Read(Argument, 0, ProductionOrder) then
            exit;
        if Codeunit.Run(Codeunit::"Prod Jnl Post Proc ori", Argument) then; // always ends in a rollback error
        if not Events.GetOutcome(Result, NothingToPost) then begin
            Events.EndRequest();
            Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, GetLastErrorText(), '', '', '', BcNextLbl);
            exit;
        end;
        Events.EndRequest();
        Result.Add('status', 'Success');
        Argument.SetResponseJson(Result);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
