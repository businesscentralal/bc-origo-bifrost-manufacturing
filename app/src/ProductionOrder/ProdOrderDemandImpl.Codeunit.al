namespace Origo.Bifrost.Manufacturing;

using Microsoft.Manufacturing.Document;
using Microsoft.Sales.Document;
using Origo.Bifrost;

/// <summary>Executes Manufacturing.ProductionOrder.CreateFromDemand: production orders for the lines of a released sales order.</summary>
codeunit 10077082 "Prod Order Demand Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        Contract: Codeunit "Mfg Demand Contract ori";

    /// <summary>Discovery: listed for callers with Manufacturing write permission.</summary>
    procedure IsEnabled(): Boolean
    var
        Gate: Record "Mfg Write Gate ori";
    begin
        exit(Gate.WritePermission());
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
        ValueLbl: Label 'Creates production orders for the lines of a released sales order, one per line or one for the whole order, reserved against the sales lines. Commits and cannot be undone.', Comment = 'is-IS=Stofnar framleiðslupantanir fyrir línur útgefinnar sölupöntunar, eina á línu eða eina fyrir alla pöntunina, fráteknar á sölulínurnar. Vistar og ekki er hægt að afturkalla.';
    begin
        exit(ValueLbl);
    end;

    /// <summary>Returns localized catalogue keywords.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'production order, manufacturing, sales order, make to order, demand, sales order planning', Comment = 'is-IS=framleiðslupöntun, framleiðsla, sölupöntun, framleiðsla eftir pöntun, þörf, sölupöntunaráætlun';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Returns localized selection text.</summary>
    procedure GetSelectionDescription(): Text
    var
        ValueLbl: Label 'Create production orders from a released sales order. Writes.', Comment = 'is-IS=Stofnaðu framleiðslupantanir úr útgefinni sölupöntun. Skrifar.';
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
        Contract.GetParameters(Parameters);
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

    /// <summary>Checks permissions and the request before crossing the transaction boundary.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        SalesHeader: Record "Sales Header";
        TempEligible: Record "Sales Line" temporary;
        Plan: Codeunit "Prod Order Demand Plan ori";
        Skipped: JsonArray;
        OrderType: Enum "Create Production Order Type";
        NewStatus: Enum "Production Order Status";
        BcNextLbl: Label 'Correct the item, setup or sales line named in the Business Central error and retry. Nothing was changed.', Comment = 'is-IS=Leiðréttu vöruna, uppsetninguna eða sölulínuna sem Business Central nefnir í villunni og reyndu aftur. Engu var breytt.';
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        if not Plan.Prepare(Argument, SalesHeader, TempEligible, Skipped, OrderType, NewStatus) then
            exit;
        // Never catch a write in a TryFunction. Under Omit Commit the caller owns rollback.
        if Argument."Omit Commit" then
            Codeunit.Run(Codeunit::"Prod Order Demand Proc ori", Argument)
        else
            if not Codeunit.Run(Codeunit::"Prod Order Demand Proc ori", Argument) then
                Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, GetLastErrorText(), '', '', '', BcNextLbl);
    end;
}
