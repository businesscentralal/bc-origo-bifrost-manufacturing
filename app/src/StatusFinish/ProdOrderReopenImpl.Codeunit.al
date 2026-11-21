namespace Origo.Bifrost.Manufacturing;

using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Setup;
using Microsoft.Manufacturing.Document;
using Origo.Bifrost;

/// <summary>Reopens a finished production order once through the standard no-UI status move.</summary>
codeunit 10077068 "Prod Order Reopen Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        Contract: Codeunit "Mfg Status Contract ori";

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
        ValueLbl: Label 'Reopens a finished production order once, moving it to Released so missing output or consumption can be posted. Commits; no ledger entries are posted.', Comment = 'is-IS=Opnar lokna framleiðslupöntun aftur einu sinni og færir hana í útgefna stöðu svo hægt sé að bóka afköst eða notkun sem vantar. Vistar breytingar; engar fjárhagsfærslur eru bókaðar.';
    begin
        exit(ValueLbl);
    end;

    /// <summary>Returns localized catalogue keywords.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'production order, manufacturing, reopen, finished, released, missing output', Comment = 'is-IS=framleiðslupöntun, framleiðsla, opna aftur, lokið, útgefin, afköst vantar';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Returns localized selection text.</summary>
    procedure GetSelectionDescription(): Text
    var
        ValueLbl: Label 'Reopen a finished production order once. Writes.', Comment = 'is-IS=Opnaðu lokna framleiðslupöntun aftur einu sinni. Skrifar.';
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
        Contract.GetReopenTarget(Target);
        exit(true);
    end;

    /// <summary>Returns the parameters chapter.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        Contract.GetReopenParameters(Parameters);
        exit(true);
    end;

    /// <summary>Returns the response chapter.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Contract.GetResponse(3, Response);
        exit(true);
    end;

    /// <summary>Returns the errors chapter.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        Contract.GetErrors(3, Errors);
        exit(true);
    end;

    /// <summary>Returns the effect chapter.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Contract.GetEffect(3, Effect);
        exit(true);
    end;

    /// <summary>Returns the related chapter.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        Contract.GetRelated(3, Related);
        exit(true);
    end;

    /// <summary>Returns the workflow chapter.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        Contract.GetReopenWorkflow(Workflow);
        exit(true);
    end;

    /// <summary>Returns the examples chapter.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        Contract.GetExamples(3, Examples);
        exit(true);
    end;

    /// <summary>Returns the overview chapter.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Contract.GetOverview(3, Overview);
        exit(true);
    end;

    /// <summary>Returns the notes chapter.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Contract.GetNotes(3, Notes);
        exit(true);
    end;

    /// <summary>Declares no app-specific metering in addition to Foundation.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Validates the request before crossing the transaction boundary.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        ProductionOrder: Record "Production Order";
        WriteContext: Codeunit "Mfg Write Context ori";
        BcNextLbl: Label 'Correct the order or setup named in the Business Central error, then retry Manufacturing.ProductionOrder.Reopen. Nothing was changed.', Comment = 'is-IS=Leiðréttu pöntunina eða uppsetninguna sem Business Central nefnir í villunni og reyndu Manufacturing.ProductionOrder.Reopen aftur. Engu var breytt.';
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        if not CanReopen(Argument) then
            exit;
        if not ReadRequest(Argument, ProductionOrder) then
            exit;
        if not CheckPreconditions(Argument, ProductionOrder) then
            exit;
        WriteContext.SetRequest(ProductionOrder, ProductionOrder.Status::Released, 0D, false, false);
        if Argument."Omit Commit" then
            Codeunit.Run(Codeunit::"Prod Order Reopen Proc ori", Argument)
        else
            if not Codeunit.Run(Codeunit::"Prod Order Reopen Proc ori", Argument) then
                Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, GetLastErrorText(), '', '', '', BcNextLbl);
        WriteContext.ClearRequest();
    end;

    local procedure CanReopen(var Argument: Record "Message Argument ori"): Boolean
    var
        Gate: Record "Mfg Write Gate ori";
        PostingGate: Codeunit "Mfg Posting Gate ori";
        DeniedLbl: Label 'Manufacturing write permission is required to reopen a production order.', Comment = 'is-IS=Skrifheimild framleiðslu er áskilin til að opna framleiðslupöntun aftur.';
        NextLbl: Label 'Ask an administrator to assign BIFROST Mfg ori or BIFROST Full ori together with BIFROST MfgPost ori.', Comment = 'is-IS=Biddu stjórnanda um að úthluta BIFROST Mfg ori eða BIFROST Full ori ásamt BIFROST MfgPost ori.';
    begin
        if not Gate.WritePermission() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, DeniedLbl, '', '', '', NextLbl);
            exit(false);
        end;
        exit(PostingGate.AssertCanPost(Argument));
    end;

    local procedure ReadRequest(var Argument: Record "Message Argument ori"; var ProductionOrder: Record "Production Order"): Boolean
    var
        Reader: Codeunit "Mfg Prod Order Request ori";
        Lookup: Codeunit "Prod Order Finish Check ori";
    begin
        Reader.CheckKeys('no|systemId|expectedCount', Argument.GetRequestJson(), Argument);
        if Reader.RespondIfErrors(Argument) then
            exit(false);
        exit(Lookup.FindOrder(Argument, ProductionOrder));
    end;

    /// <summary>Checks once-only, output and valuation rules before any move and again under lock.</summary>
    internal procedure CheckPreconditions(var Argument: Record "Message Argument ori"; ProductionOrder: Record "Production Order"): Boolean
    var
        Line: Record "Prod. Order Line";
        ValueEntry: Record "Value Entry";
        InventorySetup: Record "Inventory Setup";
        NotFinishedLbl: Label 'Production order %1 is not Finished. Nothing was changed.', Comment = '%1 = order number, is-IS=Framleiðslupöntun %1 er ekki lokið. Engu var breytt.';
        FinishNextLbl: Label 'Use Manufacturing.ProductionOrder.CheckFinish and Manufacturing.ProductionOrder.Finish before reopening.', Comment = 'is-IS=Notaðu Manufacturing.ProductionOrder.CheckFinish og Manufacturing.ProductionOrder.Finish áður en pöntunin er opnuð aftur.';
        AlreadyLbl: Label 'Production order %1 has already been reopened before. Nothing was changed.', Comment = '%1 = order number, is-IS=Framleiðslupöntun %1 hefur þegar verið opnuð aftur. Engu var breytt.';
        OnceNextLbl: Label 'Continue on the Released order with Manufacturing.ProductionJournal.Get/Post, then CheckFinish and Finish; an order can only be reopened once.', Comment = 'is-IS=Haltu áfram á útgefinni pöntun með Manufacturing.ProductionJournal.Get/Post, síðan CheckFinish og Finish; aðeins má opna pöntun aftur einu sinni.';
        NoOutputLbl: Label 'Production order %1 cannot be reopened because a line has no posted output. Nothing was changed.', Comment = '%1 = order number, is-IS=Ekki er hægt að opna framleiðslupöntun %1 aftur þar sem línu vantar bókuð afköst. Engu var breytt.';
        OutputNextLbl: Label 'Inspect the finished order lines with Data.Records.Get. Reopen requires posted output on every line; no override is available.', Comment = 'is-IS=Skoðaðu línur loknu pöntunarinnar með Data.Records.Get. Bókuð afköst verða að vera á hverri línu; ekki er hægt að hunsa skilyrðið.';
        ValuationLbl: Label 'Production order %1 cannot be reopened because it has value entries with a Valuation Date before the Earliest Allowed Valuation Date %2 in Inventory Setup.', Comment = '%1 = order number, %2 = setup date, is-IS=Ekki er hægt að opna framleiðslupöntun %1 aftur þar sem hún hefur virðisfærslur með virðisdagsetningu fyrir fyrstu leyfðu virðisdagsetningu %2 í birgðagrunni.';
        ValuationNextLbl: Label 'Ask the inventory administrator to review the Earliest Allowed Valuation Date and the order value entries before retrying.', Comment = 'is-IS=Biddu birgðastjóra að yfirfara fyrstu leyfðu virðisdagsetningu og virðisfærslur pöntunarinnar áður en reynt er aftur.';
    begin
        if ProductionOrder.Reopened then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(AlreadyLbl, ProductionOrder."No."), '', '', '', OnceNextLbl);
            exit(false);
        end;
        if ProductionOrder.Status <> ProductionOrder.Status::Finished then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NotFinishedLbl, ProductionOrder."No."), '', '', '', FinishNextLbl);
            exit(false);
        end;
        // Default inherits the caller's LockTable on the execution path; preview stays read-only.
        Line.ReadIsolation := IsolationLevel::Default;
        ValueEntry.ReadIsolation := IsolationLevel::Default;
        Line.SetRange(Status, ProductionOrder.Status);
        Line.SetRange("Prod. Order No.", ProductionOrder."No.");
        Line.SetFilter("Finished Quantity", '<=%1', 0);
        if not Line.IsEmpty() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NoOutputLbl, ProductionOrder."No."), '', '', '', OutputNextLbl);
            exit(false);
        end;
        if InventorySetup.Get() then
            if InventorySetup."Earliest Allowed Val. Date" <> 0D then begin
                ValueEntry.SetCurrentKey("Order Type", "Order No.", "Order Line No.");
                ValueEntry.SetRange("Order Type", ValueEntry."Order Type"::Production);
                ValueEntry.SetRange("Order No.", ProductionOrder."No.");
                ValueEntry.SetFilter("Valuation Date", '<%1', InventorySetup."Earliest Allowed Val. Date");
                if not ValueEntry.IsEmpty() then begin
                    Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(ValuationLbl, ProductionOrder."No.", InventorySetup."Earliest Allowed Val. Date"), '', '', '', ValuationNextLbl);
                    exit(false);
                end;
            end;
        exit(true);
    end;
}
