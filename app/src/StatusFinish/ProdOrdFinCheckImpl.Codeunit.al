namespace Origo.Bifrost.Manufacturing;

using Microsoft.Manufacturing.Document;
using Origo.Bifrost;

/// <summary>Executes Manufacturing.ProductionOrder.CheckFinish: reports the Finish findings and changes nothing.</summary>
codeunit 10077059 "Prod Ord Fin Check Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        Contract: Codeunit "Mfg Status Contract ori";

    /// <summary>Discovery: always listed.</summary>
    procedure IsEnabled(): Boolean
    begin
        exit(true);
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
        ValueLbl: Label 'Shows what would block or warn when a released production order is finished. Changes nothing.', Comment = 'is-IS=Sýnir hvað myndi hindra eða vara við þegar útgefinni framleiðslupöntun er lokið. Breytir engu.';
    begin
        exit(ValueLbl);
    end;

    /// <summary>Returns localized catalogue keywords.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'production order, manufacturing, finish, check, warnings, blockers', Comment = 'is-IS=framleiðslupöntun, framleiðsla, ljúka, athuga, viðvaranir, hindranir';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Returns localized selection text.</summary>
    procedure GetSelectionDescription(): Text
    var
        ValueLbl: Label 'Check a released production order before finishing it. Changes nothing.', Comment = 'is-IS=Athugaðu útgefna framleiðslupöntun áður en henni er lokið. Breytir engu.';
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
        Contract.GetCheckParameters(Parameters);
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

    /// <summary>Reads the order and returns the findings; posts and writes nothing.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        ProductionOrder: Record "Production Order";
        Reader: Codeunit "Mfg Prod Order Request ori";
        FinishCheck: Codeunit "Prod Order Finish Check ori";
        Lookup: Codeunit "Mfg Prod Order Lookup ori";
        Request: JsonObject;
        Response: JsonObject;
        Blockers: JsonArray;
        Warnings: JsonArray;
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        Request := Argument.GetRequestJson();
        Reader.CheckKeys('no|systemId|productionOrderStatus', Request, Argument);
        if Reader.RespondIfErrors(Argument) then
            exit;
        if not FinishCheck.FindOrder(Argument, ProductionOrder) then
            exit;
        FinishCheck.CollectFindings(ProductionOrder, false, Blockers, Warnings);
        Response.Add('status', 'Success');
        Response.Add('no', ProductionOrder."No.");
        Response.Add('productionOrderStatus', Lookup.StatusName(ProductionOrder.Status));
        Response.Add('canFinish', Blockers.Count() = 0);
        Response.Add('blockers', Blockers);
        Response.Add('warnings', Warnings);
        Response.Add('lines', FinishCheck.GetLines(ProductionOrder, true));
        Response.Add('components', FinishCheck.GetComponents(ProductionOrder));
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
