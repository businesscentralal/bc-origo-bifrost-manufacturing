namespace Origo.Bifrost.Manufacturing;

using Microsoft.Manufacturing.Document;
using Origo.Bifrost;

/// <summary>Executes Manufacturing.ProductionOrder.Finish; refuses every question Business Central would answer silently.</summary>
codeunit 10077057 "Prod Order Finish Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        Contract: Codeunit "Mfg Status Contract ori";

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
        ValueLbl: Label 'Finishes a released production order: posts backward-flushed consumption, adjusts work in process and moves the order to Finished. Commits and cannot be undone.', Comment = 'is-IS=Lýkur útgefinni framleiðslupöntun: bókar afturvirka notkun, jafnar vinnu í vinnslu og færir pöntunina í stöðuna lokið. Framkvæmir Commit og ekki er hægt að afturkalla.';
    begin
        exit(ValueLbl);
    end;

    /// <summary>Returns localized catalogue keywords.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'production order, manufacturing, finish, close, backward flushing, work in process', Comment = 'is-IS=framleiðslupöntun, framleiðsla, ljúka, loka, afturvirk notkun, vinna í vinnslu';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Returns localized selection text.</summary>
    procedure GetSelectionDescription(): Text
    var
        ValueLbl: Label 'Finish a released production order. Commits and cannot be undone.', Comment = 'is-IS=Ljúktu útgefinni framleiðslupöntun. Framkvæmir Commit og ekki er hægt að afturkalla.';
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
        Contract.GetFinishParameters(Parameters);
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

    /// <summary>Checks the token, status and findings, then finishes; nothing changes on a refusal.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        ProductionOrder: Record "Production Order";
        Reader: Codeunit "Mfg Prod Order Request ori";
        WriteCheck: Codeunit "Mfg Write Check ori";
        PostingGate: Codeunit "Mfg Posting Gate ori";
        FinishCheck: Codeunit "Prod Order Finish Check ori";
        StatusImpl: Codeunit "Prod Order Status Impl ori";
        WriteContext: Codeunit "Mfg Write Context ori";
        Request: JsonObject;
        Blockers: JsonArray;
        Warnings: JsonArray;
        Token: JsonToken;
        Finding: JsonObject;
        PostingDate: Date;
        UpdateUnitCost: Boolean;
        FinishWithoutOutput: Boolean;
        AcceptMissingOutput: Boolean;
        AcceptMissingConsumption: Boolean;
        BcNextLbl: Label 'Inspect the production order, correct the item, setup or entry named in the Business Central error and retry. Nothing was changed.', Comment = 'is-IS=Skoðaðu framleiðslupöntunina, leiðréttu vöruna, uppsetninguna eða færsluna sem Business Central nefnir í villunni og reyndu aftur. Engu var breytt.';
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        WriteCheck.AssertCanWrite('Manufacturing.ProductionOrder.Finish');
        if not PostingGate.AssertCanPost(Argument) then
            exit;
        Request := Argument.GetRequestJson();
        Reader.CheckKeys('no|systemId|productionOrderStatus|postingDate|updateUnitCost|finishWithoutOutput|acceptMissingOutput|acceptMissingConsumption|expectedCount', Request, Argument);
        PostingDate := StatusImpl.ReadPostingDate(Request, Argument);
        UpdateUnitCost := ReadFlag(Request, 'updateUnitCost', Argument);
        FinishWithoutOutput := ReadFlag(Request, 'finishWithoutOutput', Argument);
        AcceptMissingOutput := ReadFlag(Request, 'acceptMissingOutput', Argument);
        AcceptMissingConsumption := ReadFlag(Request, 'acceptMissingConsumption', Argument);
        if Reader.RespondIfErrors(Argument) then
            exit;
        if not FinishCheck.FindOrder(Argument, ProductionOrder) then
            exit;
        FinishCheck.CollectFindings(ProductionOrder, FinishWithoutOutput, Blockers, Warnings);
        foreach Token in Blockers do begin
            Finding := Token.AsObject();
            Argument.AddError("Bifrost Error Code ori"::PreconditionFailed, TextOf(Finding, 'message'), CodeParameter(TextOf(Finding, 'code')), '', '', TextOf(Finding, 'nextStep'));
        end;
        foreach Token in Warnings do begin
            Finding := Token.AsObject();
            if not IsAcknowledged(TextOf(Finding, 'kind'), AcceptMissingOutput, AcceptMissingConsumption) then
                Argument.AddError("Bifrost Error Code ori"::PreconditionFailed, TextOf(Finding, 'message'), TextOf(Finding, 'kind'), '', '', TextOf(Finding, 'nextStep'));
        end;
        if RespondWithFindings(Argument) then
            exit;
        WriteContext.SetRequest(ProductionOrder, ProductionOrder.Status::Finished, PostingDate, UpdateUnitCost, FinishWithoutOutput);
        // Business Central commits inside ChangeProdOrderStatus; the commit is not suppressed under Omit Commit.
        if Argument."Omit Commit" then
            Codeunit.Run(Codeunit::"Prod Order Finish Proc ori", Argument)
        else
            if not Codeunit.Run(Codeunit::"Prod Order Finish Proc ori", Argument) then
                Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, GetLastErrorText(), '', '', '', BcNextLbl);
        WriteContext.ClearRequest();
    end;

    local procedure RespondWithFindings(var Argument: Record "Message Argument ori"): Boolean
    var
        NothingLbl: Label 'The production order cannot be finished. Nothing was changed.', Comment = 'is-IS=Ekki er hægt að ljúka framleiðslupöntuninni. Engu var breytt.';
    begin
        if not Argument.HasCollectedErrors() then
            exit(false);
        Argument.RespondWithCollectedErrors("Bifrost Error Code ori"::PreconditionFailed, NothingLbl);
        exit(true);
    end;

    local procedure IsAcknowledged(Kind: Text; AcceptMissingOutput: Boolean; AcceptMissingConsumption: Boolean): Boolean
    begin
        case Kind of
            'missingOutput':
                exit(AcceptMissingOutput);
            'missingConsumption':
                exit(AcceptMissingConsumption);
        end;
        exit(false);
    end;

    local procedure CodeParameter(FindingCode: Text): Text
    begin
        case FindingCode of
            'NotReleased':
                exit('productionOrderStatus');
            'ConsumptionWithoutOutput':
                exit('finishWithoutOutput');
        end;
        exit(FindingCode);
    end;

    local procedure TextOf(Finding: JsonObject; KeyName: Text): Text
    var
        Token: JsonToken;
    begin
        if Finding.Get(KeyName, Token) then
            exit(Token.AsValue().AsText());
        exit('');
    end;

    /// <summary>Reads an optional JSON boolean with a false default.</summary>
    internal procedure ReadFlag(Request: JsonObject; KeyName: Text; var Argument: Record "Message Argument ori"): Boolean
    var
        Reader: Codeunit "Mfg Prod Order Request ori";
        Token: JsonToken;
        Raw: Text;
    begin
        if not Request.Get(KeyName, Token) then
            exit(false);
        Token.WriteTo(Raw);
        case Raw of
            'true':
                exit(true);
            'false':
                exit(false);
        end;
        Reader.BadFormat(KeyName, Argument);
        exit(false);
    end;
}
