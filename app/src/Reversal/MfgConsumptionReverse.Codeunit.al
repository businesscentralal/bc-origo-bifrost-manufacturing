namespace Origo.Bifrost.Manufacturing;

using Microsoft.Finance.GeneralLedger.Preview;
using Microsoft.Foundation.Navigate;
using Microsoft.Inventory.Journal;
using Microsoft.Manufacturing.Document;
using Origo.Bifrost;

/// <summary>Executes Manufacturing.Consumption.Reverse.</summary>
codeunit 10077109 "Mfg Consumption Reverse ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori", "Msg Confirm ori"
{
    Access = Internal;

    var
        Contract: Codeunit "Mfg Reverse Contract ori";

    /// <summary>Discovery: listed only with the BIFROST MfgPost ori posting token.</summary>
    procedure IsEnabled(): Boolean
    var
        Gate: Record "Mfg Write Gate ori";
        PostingGate: Codeunit "Mfg Posting Gate ori";
    begin
        exit(Gate.WritePermission() and PostingGate.HasPostingPermission());
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
        ValueLbl: Label 'Reverses whole posted consumption entries of a released production order by posting correcting entries.', Comment = 'is-IS=Bakfærir heilar bókaðar notkunarfærslur útgefinnar framleiðslupöntunar með mótfærslum.';
    begin
        exit(ValueLbl);
    end;

    /// <summary>Returns localized catalogue keywords.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'reverse production, correct output, correct consumption, capacity, item tracking', Comment = 'is-IS=bakfæra framleiðslu, leiðrétta afköst, leiðrétta notkun, afkastageta, vörurakning';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Returns localized selection text.</summary>
    procedure GetSelectionDescription(): Text
    var
        ValueLbl: Label 'Reverse whole entries with expectedCount. Original entries remain; correcting entries are posted.', Comment = 'is-IS=Bakfærðu heilar færslur með expectedCount. Upprunalegar færslur haldast; mótfærslur eru bókaðar.';
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
        Contract.GetParameters(false, Parameters);
        exit(true);
    end;

    /// <summary>Returns the response chapter.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Contract.GetResponse(Response);
        exit(true);
    end;

    /// <summary>Returns the errors chapter.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        Contract.GetErrors(Errors);
        exit(true);
    end;

    /// <summary>Returns the effect chapter.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Contract.GetEffect(Effect);
        exit(true);
    end;

    /// <summary>Returns the related chapter.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        Contract.GetRelated(Related);
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
        Contract.GetExamples(Examples);
        exit(true);
    end;

    /// <summary>Returns the overview chapter.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Contract.GetOverview(Overview);
        exit(true);
    end;

    /// <summary>Returns the notes chapter.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Contract.GetNotes(Notes);
        exit(true);
    end;

    /// <summary>Declares no app-specific metering in addition to Foundation.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Counts only selected original ledger entries before confirmation.</summary>
    procedure GetConfirmCount(var Argument: Record "Message Argument ori"; var Count: Integer; var Summary: Text): Boolean
    var
        Plan: Codeunit "Mfg Reverse Plan ori";
    begin
        exit(Plan.GetConfirmCount(Argument, Count, Summary));
    end;

    /// <summary>Validates the complete selection and posts it atomically.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Plan: Codeunit "Mfg Reverse Plan ori";
    begin
        Plan.Execute(Argument);
    end;
}
