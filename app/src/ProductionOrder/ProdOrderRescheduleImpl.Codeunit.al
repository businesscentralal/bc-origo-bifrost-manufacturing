namespace Origo.Bifrost.Manufacturing;

using Microsoft.Inventory.Ledger;
using Microsoft.Manufacturing.Capacity;
using Microsoft.Manufacturing.Document;
using Origo.Bifrost;

/// <summary>Executes Manufacturing.ProductionOrder.Reschedule by moving one order or line through Business Central scheduling.</summary>
codeunit 10077115 "Prod Order Reschedule Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
        ValueLbl: Label 'Moves the due date or starting date-time of one firm planned or released production order or one of its lines, then recalculates routing, capacity and component dates. Commits.', Comment = 'is-IS=Færir gjalddaga eða upphafsdagsetningu einnar fastákveðinnar eða útgefinar framleiðslupöntunar eða einnar línu og endurreiknar vinnsluleið, afköst og efnisdagsetningar. Vistar.';
    begin
        exit(ValueLbl);
    end;

    /// <summary>Returns localized catalogue keywords.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'production order, manufacturing, reschedule, dates', Comment = 'is-IS=framleiðslupöntun, framleiðsla, endurtímasetja, dagsetningar';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Returns localized selection text.</summary>
    procedure GetSelectionDescription(): Text
    var
        ValueLbl: Label 'Move the dates of one firm planned or released order or line. Commits.', Comment = 'is-IS=Færðu dagsetningar einnar fastákveðinnar eða útgefinar pöntunar eða línu. Vistar.';
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
        Contract.GetRescheduleParameters(Parameters);
        exit(true);
    end;

    /// <summary>Returns the response chapter.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Contract: Codeunit "Mfg ProdOrder Contract ori";
    begin
        Contract.GetScheduleResponse(false, Response);
        exit(true);
    end;

    /// <summary>Returns the errors chapter.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Contract: Codeunit "Mfg ProdOrder Contract ori";
    begin
        Contract.GetScheduleErrors(false, Errors);
        exit(true);
    end;

    /// <summary>Returns the effect chapter.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Contract: Codeunit "Mfg ProdOrder Contract ori";
    begin
        Contract.GetScheduleEffect(false, Effect);
        exit(true);
    end;

    /// <summary>Returns the related chapter.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        Contract: Codeunit "Mfg ProdOrder Contract ori";
    begin
        Contract.GetScheduleRelated(false, Related);
        exit(true);
    end;

    /// <summary>Returns the workflow chapter.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Contract: Codeunit "Mfg ProdOrder Contract ori";
    begin
        Contract.GetScheduleWorkflow(false, Workflow);
        exit(true);
    end;

    /// <summary>Returns the examples chapter.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Contract: Codeunit "Mfg ProdOrder Contract ori";
    begin
        Contract.GetScheduleExamples(false, Examples);
        exit(true);
    end;

    /// <summary>Returns the overview chapter.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    var
        Contract: Codeunit "Mfg ProdOrder Contract ori";
    begin
        Contract.GetScheduleOverview(false, Overview);
        exit(true);
    end;

    /// <summary>Returns the notes chapter.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    var
        Contract: Codeunit "Mfg ProdOrder Contract ori";
    begin
        Contract.GetScheduleNotes(false, Notes);
        exit(true);
    end;

    /// <summary>Declares no app-specific metering in addition to Foundation.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Validates the request, then moves the dates in a committing operation.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        ProductionOrder: Record "Production Order";
        ProdOrderLine: Record "Prod. Order Line";
        Gate: Record "Mfg Write Gate ori";
        Reader: Codeunit "Mfg Prod Order Request ori";
        Lookup: Codeunit "Mfg Prod Order Lookup ori";
        Request: JsonObject;
        Direction: Text;
        LineNo: Integer;
        DirectionOk: Boolean;
        Forward: Boolean;
        PreviousTransactionType: TransactionType;
        Succeeded: Boolean;
        DeniedLbl: Label 'Manufacturing write permission is required to reschedule a production order.', Comment = 'is-IS=Skrifheimild framleiðslu er áskilin til að endurtímasetja framleiðslupöntun.';
        DeniedNextLbl: Label 'Ask an administrator to assign BIFROST Mfg ori or BIFROST Full ori.', Comment = 'is-IS=Biddu stjórnanda um að úthluta BIFROST Mfg ori eða BIFROST Full ori.';
        OmitLbl: Label 'Reschedule always commits and cannot run with Omit Commit. Nothing was changed.', Comment = 'is-IS=Endurtímasetning vistar alltaf og getur ekki keyrt með Omit Commit. Engu var breytt.';
        OmitNextLbl: Label 'Run the reschedule as a separate committing operation without Omit Commit.', Comment = 'is-IS=Keyrðu endurtímasetninguna sem aðskilda aðgerð sem vistar, án Omit Commit.';
        DirectionLbl: Label 'direction must be forward or backward.', Comment = 'is-IS=direction verður að vera forward eða backward.';
        DirectionNextLbl: Label 'Send forward or backward, or omit direction to use backward.', Comment = 'is-IS=Sendu forward eða backward, eða slepptu direction til að nota backward.';
        LineLbl: Label 'lineNo must be 0 or a positive line number.', Comment = 'is-IS=lineNo verður að vera 0 eða jákvætt línunúmer.';
        LineNextLbl: Label 'Omit lineNo to move the whole order, or send the line number from the order.', Comment = 'is-IS=Slepptu lineNo til að færa alla pöntunina, eða sendu línunúmerið af pöntuninni.';
        LineMissingLbl: Label 'Production order line %1 was not found. Nothing was changed.', Comment = '%1 = line number, is-IS=Framleiðslupöntunarlínan %1 fannst ekki. Engu var breytt.';
        LineMissingNextLbl: Label 'Read the order lines and send a lineNo that belongs to this order, or omit lineNo.', Comment = 'is-IS=Lestu línur pöntunarinnar og sendu lineNo sem tilheyrir henni, eða slepptu lineNo.';
        BothDatesLbl: Label 'Send either dueDate or startingDateTime, not both. Nothing was changed.', Comment = 'is-IS=Sendu annað hvort dueDate eða startingDateTime, ekki bæði. Engu var breytt.';
        BothDatesNextLbl: Label 'Use dueDate with backward, or startingDateTime with forward.', Comment = 'is-IS=Notaðu dueDate með backward, eða startingDateTime með forward.';
        DateChoiceLbl: Label 'This direction does not accept %1. Nothing was changed.', Comment = '%1 = parameter, is-IS=Þessi stefna tekur ekki við %1. Engu var breytt.';
        PlannedLbl: Label 'Production order %1 is %2 and cannot be rescheduled. Nothing was changed.', Comment = '%1 = order number, %2 = status, is-IS=Framleiðslupöntun %1 er %2 og ekki er hægt að endurtímasetja hana. Engu var breytt.';
        PlannedNextLbl: Label 'Refresh the planning order with Manufacturing.ProductionOrder.Refresh before changing its dates.', Comment = 'is-IS=Endurnýjaðu áætlaða pöntun með Manufacturing.ProductionOrder.Refresh áður en dagsetningum hennar er breytt.';
        FinishedLbl: Label 'Production order %1 is Finished and cannot be rescheduled. Nothing was changed.', Comment = '%1 = order number, is-IS=Framleiðslupöntun %1 er lokið og ekki er hægt að endurtímasetja hana. Engu var breytt.';
        FinishedNextLbl: Label 'Finished orders stay unchanged.', Comment = 'is-IS=Lokið pöntunum er ekki breytt.';
        PostedLbl: Label 'Production order %1 has posted output or consumption. Nothing was changed.', Comment = '%1 = order number, is-IS=Framleiðslupöntun %1 er með bókaða afurð eða notkun. Engu var breytt.';
        PostedNextLbl: Label 'Reverse the posted entries before rescheduling. This operation does not post.', Comment = 'is-IS=Bakfærðu bókuðu færslurnar áður en endurtímasett er. Þessi aðgerð bókar ekki.';
        PostedFallbackLbl: Label 'Posted output or consumption prevents rescheduling. Nothing was changed.', Comment = 'is-IS=Bókuð afurð eða notkun kemur í veg fyrir endurtímasetningu. Engu var breytt.';
        MultiLbl: Label 'Production order %1 has lower planning levels and cannot be rescheduled. Nothing was changed.', Comment = '%1 = order number, is-IS=Framleiðslupöntun %1 er með neðri áætlunarstig og ekki er hægt að endurtímasetja hana. Engu var breytt.';
        MultiNextLbl: Label 'Reschedule is available for a single-level order. Replan at no levels only when that operation allows it.', Comment = 'is-IS=Endurtímasetning er í boði fyrir pöntun á einu stigi. Endurskipuleggðu án undirstiga aðeins þegar sú aðgerð leyfir það.';
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
        Reader.CheckKeys('no|systemId|status|direction|lineNo|dueDate|startingDateTime', Request, Argument);
        Direction := LowerCase(Reader.ReadText(Request, 'direction', false, 8, Argument));
        DirectionOk := (not Request.Contains('direction')) or (Direction = 'forward') or (Direction = 'backward');
        if not DirectionOk then
            Argument.AddError("Bifrost Error Code ori"::InvalidParameter, DirectionLbl, 'direction', Direction, 'forward|backward', DirectionNextLbl);
        Forward := Direction = 'forward';
        if Request.Contains('lineNo') then begin
            LineNo := Reader.ReadInteger(Request, 'lineNo', true, Argument);
            if LineNo < 0 then
                Argument.AddError("Bifrost Error Code ori"::InvalidParameter, LineLbl, 'lineNo', Format(LineNo, 0, 9), '0 or a line number', LineNextLbl);
        end;
        if Request.Contains('dueDate') then
            Reader.ReadCalendarDate(Request, 'dueDate', Argument);
        if Request.Contains('startingDateTime') then
            Reader.ReadDateTime(Request, 'startingDateTime', true, Argument);
        if DirectionOk then
            if Request.Contains('dueDate') and Request.Contains('startingDateTime') then
                Argument.AddError("Bifrost Error Code ori"::InvalidParameter, BothDatesLbl, 'dueDate', '', 'dueDate or startingDateTime', BothDatesNextLbl)
            else
                if Forward and Request.Contains('dueDate') then
                    Argument.AddError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(DateChoiceLbl, 'dueDate'), 'dueDate', '', 'startingDateTime', BothDatesNextLbl)
                else
                    if (not Forward) and Request.Contains('startingDateTime') then
                        Argument.AddError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(DateChoiceLbl, 'startingDateTime'), 'startingDateTime', '', 'dueDate', BothDatesNextLbl)
                    else
                        if Forward and not Request.Contains('startingDateTime') then
                            Reader.Missing('startingDateTime', Argument)
                        else
                            if (not Forward) and not Request.Contains('dueDate') then
                                Reader.Missing('dueDate', Argument);
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
        if (LineNo > 0) and not ProdOrderLine.Get(ProductionOrder.Status, ProductionOrder."No.", LineNo) then
            Argument.AddError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(LineMissingLbl, LineNo), 'lineNo', Format(LineNo, 0, 9), '', LineMissingNextLbl);
        if HasLowerLevel(ProductionOrder) then
            Argument.AddError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(MultiLbl, ProductionOrder."No."), 'no', ProductionOrder."No.", '', MultiNextLbl);
        if HasPostedActivity(ProductionOrder."No.") then
            Argument.AddError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(PostedLbl, ProductionOrder."No."), 'no', ProductionOrder."No.", '', PostedNextLbl);
        if Reader.RespondIfErrors(Argument) then
            exit;

        Commit();
        PreviousTransactionType := CurrentTransactionType();
        Succeeded := Codeunit.Run(Codeunit::"Prod Order Reschedule Proc ori", Argument);
        if not Succeeded then
            RespondFromBusinessCentral(Argument, GetLastErrorText(), BcNextLbl, PostedFallbackLbl, PostedNextLbl);
        CurrentTransactionType(PreviousTransactionType);
    end;

    local procedure HasLowerLevel(ProductionOrder: Record "Production Order"): Boolean
    var
        ProdOrderLine: Record "Prod. Order Line";
    begin
        ProdOrderLine.SetLoadFields("Line No.");
        ProdOrderLine.SetRange(Status, ProductionOrder.Status);
        ProdOrderLine.SetRange("Prod. Order No.", ProductionOrder."No.");
        ProdOrderLine.SetFilter("Planning Level Code", '>%1', 0);
        exit(not ProdOrderLine.IsEmpty());
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
