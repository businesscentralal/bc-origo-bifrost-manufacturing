namespace Origo.Bifrost.Manufacturing;

using Microsoft.Inventory.Ledger;
using Microsoft.Manufacturing.Capacity;
using Microsoft.Manufacturing.Document;
using Origo.Bifrost;

/// <summary>Executes Manufacturing.ProductionOrder.Replan for one firm planned or released order at no levels.</summary>
codeunit 10077113 "Prod Order Replan Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    begin
        ExecuteBifrostTask(Rec);
    end;

    /// <summary>Listed only for callers with Manufacturing write permission.</summary>
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
        ValueLbl: Label 'Recalculates routing, capacity and component dates for one firm planned or released production order. Refuses one level and all levels. Commits and cannot be undone.', Comment = 'is-IS=Endurreiknar vinnsluleið, afköst og efnisdagsetningar einnar fastákveðinnar eða útgefinar framleiðslupöntunar. Hafnar einu stigi og öllum stigum. Vistar og ekki er hægt að afturkalla.';
    begin
        exit(ValueLbl);
    end;

    /// <summary>Returns localized catalogue keywords.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'production order, manufacturing, replan, scheduling', Comment = 'is-IS=framleiðslupöntun, framleiðsla, endurskipuleggja, áætlanagerð';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Returns localized selection text.</summary>
    procedure GetSelectionDescription(): Text
    var
        ValueLbl: Label 'Replan one firm planned or released order at no levels. Commits.', Comment = 'is-IS=Endurskipuleggðu eina fastákveðna eða útgefna pöntun án undirstiga. Vistar.';
    begin
        exit(ValueLbl);
    end;

    /// <summary>Returns the envelope chapter.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Contract: Codeunit "Mfg ProdOrder Contract ori";
    begin
        Contract.GetScheduleEnvelope(Envelope);
        exit(true);
    end;

    /// <summary>Returns the target chapter.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        Contract: Codeunit "Mfg ProdOrder Contract ori";
    begin
        Contract.GetScheduleTarget(Target);
        exit(true);
    end;

    /// <summary>Returns the parameters chapter.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Contract: Codeunit "Mfg ProdOrder Contract ori";
    begin
        Contract.GetReplanParameters(Parameters);
        exit(true);
    end;

    /// <summary>Returns the response chapter.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Contract: Codeunit "Mfg ProdOrder Contract ori";
    begin
        Contract.GetScheduleResponse(true, Response);
        exit(true);
    end;

    /// <summary>Returns the errors chapter.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Contract: Codeunit "Mfg ProdOrder Contract ori";
    begin
        Contract.GetScheduleErrors(true, Errors);
        exit(true);
    end;

    /// <summary>Returns the effect chapter. The effect is write; expectedCount is enforced by this operation.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Contract: Codeunit "Mfg ProdOrder Contract ori";
    begin
        Contract.GetScheduleEffect(true, Effect);
        exit(true);
    end;

    /// <summary>Returns the related chapter.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        Contract: Codeunit "Mfg ProdOrder Contract ori";
    begin
        Contract.GetScheduleRelated(true, Related);
        exit(true);
    end;

    /// <summary>Returns the workflow chapter.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Contract: Codeunit "Mfg ProdOrder Contract ori";
    begin
        Contract.GetScheduleWorkflow(true, Workflow);
        exit(true);
    end;

    /// <summary>Returns the examples chapter.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Contract: Codeunit "Mfg ProdOrder Contract ori";
    begin
        Contract.GetScheduleExamples(true, Examples);
        exit(true);
    end;

    /// <summary>Returns the overview chapter.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    var
        Contract: Codeunit "Mfg ProdOrder Contract ori";
    begin
        Contract.GetScheduleOverview(true, Overview);
        exit(true);
    end;

    /// <summary>Returns the notes chapter.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    var
        Contract: Codeunit "Mfg ProdOrder Contract ori";
    begin
        Contract.GetScheduleNotes(true, Notes);
        exit(true);
    end;

    /// <summary>Declares no app-specific metering in addition to Foundation.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Validates the request, enforces expectedCount 1, then replans in a committing operation.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        ProductionOrder: Record "Production Order";
        Gate: Record "Mfg Write Gate ori";
        Reader: Codeunit "Mfg Prod Order Request ori";
        Lookup: Codeunit "Mfg Prod Order Lookup ori";
        Request: JsonObject;
        Direction: Text;
        CalcText: Text;
        Level: Option NoLevels,OneLevel,AllLevels;
        ExpectedCount: Integer;
        ExpectedSpecified: Boolean;
        PreviousTransactionType: TransactionType;
        Succeeded: Boolean;
        DeniedLbl: Label 'Manufacturing write permission is required to replan a production order.', Comment = 'is-IS=Skrifheimild framleiðslu er áskilin til að endurskipuleggja framleiðslupöntun.';
        DeniedNextLbl: Label 'Ask an administrator to assign BIFROST Mfg ori or BIFROST Full ori.', Comment = 'is-IS=Biddu stjórnanda um að úthluta BIFROST Mfg ori eða BIFROST Full ori.';
        OmitLbl: Label 'Replan always commits and cannot run with Omit Commit. Nothing was changed.', Comment = 'is-IS=Endurskipulagning vistar alltaf og getur ekki keyrt með Omit Commit. Engu var breytt.';
        OmitNextLbl: Label 'Run the replan as a separate committing operation without Omit Commit.', Comment = 'is-IS=Keyrðu endurskipulagninguna sem aðskilda aðgerð sem vistar, án Omit Commit.';
        DirectionLbl: Label 'direction must be forward or backward.', Comment = 'is-IS=direction verður að vera forward eða backward.';
        DirectionNextLbl: Label 'Send forward or backward, or omit direction to use backward.', Comment = 'is-IS=Sendu forward eða backward, eða slepptu direction til að nota backward.';
        CalcLbl: Label 'calcMethod must be noLevels, oneLevel or allLevels.', Comment = 'is-IS=calcMethod verður að vera noLevels, oneLevel eða allLevels.';
        CalcNextLbl: Label 'Send noLevels or omit calcMethod. oneLevel and allLevels are refused.', Comment = 'is-IS=Sendu noLevels eða slepptu calcMethod. oneLevel og allLevels er hafnað.';
        LevelsLbl: Label 'calcMethod %1 is refused. No production order was deleted. Nothing was changed.', Comment = '%1 = calcMethod, is-IS=calcMethod %1 er hafnað. Engri framleiðslupöntun var eytt. Engu var breytt.';
        LevelsNextLbl: Label 'Send calcMethod noLevels, or omit it, to recalculate only this production order.', Comment = 'is-IS=Sendu calcMethod noLevels, eða slepptu því, til að endurreikna aðeins þessa framleiðslupöntun.';
        PlannedLbl: Label 'Production order %1 is %2 and cannot be replanned. Nothing was changed.', Comment = '%1 = order number, %2 = status, is-IS=Framleiðslupöntun %1 er %2 og ekki er hægt að endurskipuleggja hana. Engu var breytt.';
        PlannedNextLbl: Label 'Refresh the planning order with Manufacturing.ProductionOrder.Refresh before replanning it.', Comment = 'is-IS=Endurnýjaðu áætlaða pöntun með Manufacturing.ProductionOrder.Refresh áður en hún er endurskipulögð.';
        FinishedLbl: Label 'Production order %1 is Finished and cannot be replanned. Nothing was changed.', Comment = '%1 = order number, is-IS=Framleiðslupöntun %1 er lokið og ekki er hægt að endurskipuleggja hana. Engu var breytt.';
        FinishedNextLbl: Label 'Finished orders stay unchanged.', Comment = 'is-IS=Lokið pöntunum er ekki breytt.';
        PostedLbl: Label 'Production order %1 has posted output or consumption. Nothing was changed.', Comment = '%1 = order number, is-IS=Framleiðslupöntun %1 er með bókaða afurð eða notkun. Engu var breytt.';
        PostedNextLbl: Label 'Reverse the posted entries before replanning. This operation does not post.', Comment = 'is-IS=Bakfærðu bókuðu færslurnar áður en endurskipulagt er. Þessi aðgerð bókar ekki.';
        PostedFallbackLbl: Label 'Posted output or consumption prevents replanning. Nothing was changed.', Comment = 'is-IS=Bókuð afurð eða notkun kemur í veg fyrir endurskipulagningu. Engu var breytt.';
        ConfirmReqLbl: Label 'Confirm expectedCount 1 before this production order is replanned. Nothing was changed.', Comment = 'is-IS=Staðfestu expectedCount 1 áður en þessi framleiðslupöntun er endurskipulögð. Engu var breytt.';
        ConfirmMisLbl: Label 'expectedCount must be 1. Nothing was changed.', Comment = 'is-IS=expectedCount verður að vera 1. Engu var breytt.';
        ConfirmNextLbl: Label 'Send expectedCount 1 to replan this one production order. The call then commits and cannot be undone.', Comment = 'is-IS=Sendu expectedCount 1 til að endurskipuleggja þessa eina framleiðslupöntun. Kallið vistar þá og ekki er hægt að afturkalla það.';
        BcNextLbl: Label 'Correct the calendar, routing, BOM or field named in the Business Central error and retry. Nothing was changed.', Comment = 'is-IS=Leiðréttu dagatalið, vinnsluleiðina, efnislistann eða reitinn sem Business Central nefnir og reyndu aftur. Engu var breytt.';
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        if not Gate.WritePermission() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, DeniedLbl, '', '', 'BIFROST Mfg ori', DeniedNextLbl);
            exit;
        end;
        if Argument."Omit Commit" then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, OmitLbl, '', '', '', OmitNextLbl);
            exit;
        end;

        Request := Argument.GetRequestJson();
        Reader.CheckKeys('no|systemId|status|direction|calcMethod|expectedCount', Request, Argument);
        Direction := LowerCase(Reader.ReadText(Request, 'direction', false, 8, Argument));
        if Request.Contains('direction') and (Direction <> 'forward') and (Direction <> 'backward') then
            Argument.AddError("Bifrost Error Code ori"::InvalidParameter, DirectionLbl, 'direction', Direction, 'forward|backward', DirectionNextLbl);
        Level := Level::NoLevels;
        if Request.Contains('calcMethod') then begin
            CalcText := Reader.ReadText(Request, 'calcMethod', true, 9, Argument);
            if CalcText <> '' then
                case LowerCase(CalcText) of
                    'nolevels':
                        Level := Level::NoLevels;
                    'onelevel':
                        Level := Level::OneLevel;
                    'alllevels':
                        Level := Level::AllLevels;
                    else
                        Argument.AddError("Bifrost Error Code ori"::InvalidParameter, CalcLbl, 'calcMethod', CalcText, 'noLevels|oneLevel|allLevels', CalcNextLbl);
                end;
        end;
        ExpectedSpecified := Request.Contains('expectedCount');
        if ExpectedSpecified then
            ExpectedCount := Reader.ReadInteger(Request, 'expectedCount', true, Argument);
        if not Lookup.FindSchedulingOrder(Argument, ProductionOrder) then
            exit;

        case ProductionOrder.Status of
            ProductionOrder.Status::"Firm Planned", ProductionOrder.Status::Released:
                ;
            ProductionOrder.Status::Planned, ProductionOrder.Status::Simulated:
                Argument.AddError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(PlannedLbl, ProductionOrder."No.", Lookup.StatusName(ProductionOrder.Status)), 'status', Lookup.StatusName(ProductionOrder.Status), '', PlannedNextLbl);
            else
                Argument.AddError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(FinishedLbl, ProductionOrder."No."), 'status', Lookup.StatusName(ProductionOrder.Status), '', FinishedNextLbl);
        end;
        if Level <> Level::NoLevels then
            Argument.AddError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(LevelsLbl, CalcText), 'calcMethod', CalcText, 'noLevels', LevelsNextLbl);
        if HasPostedActivity(ProductionOrder."No.") then
            Argument.AddError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(PostedLbl, ProductionOrder."No."), 'no', ProductionOrder."No.", '', PostedNextLbl);
        if Reader.RespondIfErrors(Argument) then
            exit;

        // Foundation enforces expectedCount for an irreversible effect only. This write enforces the count itself.
        if not ExpectedSpecified then begin
            Argument.RespondWithError("Bifrost Error Code ori"::ConfirmationRequired, ConfirmReqLbl, 'expectedCount', '', '1', ConfirmNextLbl);
            exit;
        end;
        if ExpectedCount <> 1 then begin
            Argument.RespondWithError("Bifrost Error Code ori"::ConfirmationMismatch, ConfirmMisLbl, 'expectedCount', Format(ExpectedCount, 0, 9), '1', ConfirmNextLbl);
            exit;
        end;

        Commit();
        PreviousTransactionType := CurrentTransactionType();
        Succeeded := Codeunit.Run(Codeunit::"Prod Order Replan Proc ori", Argument);
        if not Succeeded then
            RespondFromBusinessCentral(Argument, GetLastErrorText(), BcNextLbl, PostedFallbackLbl, PostedNextLbl);
        CurrentTransactionType(PreviousTransactionType);
    end;

    local procedure HasPostedActivity(OrderNo: Code[20]): Boolean
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
        CapacityLedgerEntry: Record "Capacity Ledger Entry";
    begin
        ItemLedgerEntry.SetLoadFields("Entry No.");
        ItemLedgerEntry.SetRange("Order Type", ItemLedgerEntry."Order Type"::Production);
        ItemLedgerEntry.SetRange("Order No.", OrderNo);
        ItemLedgerEntry.SetFilter("Entry Type", '%1|%2', ItemLedgerEntry."Entry Type"::Output, ItemLedgerEntry."Entry Type"::Consumption);
        if not ItemLedgerEntry.IsEmpty() then
            exit(true);
        CapacityLedgerEntry.SetLoadFields("Entry No.");
        CapacityLedgerEntry.SetRange("Order Type", CapacityLedgerEntry."Order Type"::Production);
        CapacityLedgerEntry.SetRange("Order No.", OrderNo);
        exit(not CapacityLedgerEntry.IsEmpty());
    end;

    local procedure RespondFromBusinessCentral(var Argument: Record "Message Argument ori"; Failure: Text; BcNext: Text; PostedMessage: Text; PostedNext: Text)
    var
        Folded: Text;
    begin
        Folded := LowerCase(Failure);
        if Folded.Contains('output') or Folded.Contains('consumption') or Folded.Contains('capacity ledger') then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, PostedMessage, '', '', '', PostedNext);
            exit;
        end;
        Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, Failure, '', '', '', BcNext);
    end;
}
