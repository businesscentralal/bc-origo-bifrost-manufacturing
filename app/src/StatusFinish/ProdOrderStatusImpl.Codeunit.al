namespace Origo.Bifrost.Manufacturing;

using Microsoft.Manufacturing.Document;
using Origo.Bifrost;

/// <summary>Executes Manufacturing.ProductionOrder.ChangeStatus with the standard Business Central status change.</summary>
codeunit 10077055 "Prod Order Status Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
        ValueLbl: Label 'Changes the status of a production order to Firm Planned or Released with the standard Business Central status change. Commits.', Comment = 'is-IS=Breytir stöðu framleiðslupöntunar í fastákveðna eða útgefna með venjulegri stöðubreytingu Business Central. Framkvæmir Commit.';
    begin
        exit(ValueLbl);
    end;

    /// <summary>Returns localized catalogue keywords.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'production order, manufacturing, status, firm planned, release, flushing', Comment = 'is-IS=framleiðslupöntun, framleiðsla, staða, fastákveðin, útgefa, afturvirk og framvirk notkun';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Returns localized selection text.</summary>
    procedure GetSelectionDescription(): Text
    var
        ValueLbl: Label 'Move a production order to Firm Planned or Released. Commits.', Comment = 'is-IS=Færðu framleiðslupöntun í fastákveðna eða útgefna. Framkvæmir Commit.';
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
        Contract.GetStatusParameters(Parameters);
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

    /// <summary>Validates the move and the posting token, then runs the status change; nothing changes on a refusal.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        ProductionOrder: Record "Production Order";
        Reader: Codeunit "Mfg Prod Order Request ori";
        WriteCheck: Codeunit "Mfg Write Check ori";
        PostingGate: Codeunit "Mfg Posting Gate ori";
        FinishCheck: Codeunit "Prod Order Finish Check ori";
        Lookup: Codeunit "Mfg Prod Order Lookup ori";
        WriteContext: Codeunit "Mfg Write Context ori";
        Request: JsonObject;
        NewStatusText: Text;
        NewStatus: Enum "Production Order Status";
        PostingDate: Date;
        FinishedLbl: Label 'Use Manufacturing.ProductionOrder.Finish to finish an order.', Comment = 'is-IS=Notaðu Manufacturing.ProductionOrder.Finish til að ljúka pöntun.';
        FinishedNextLbl: Label 'Send the order to Manufacturing.ProductionOrder.Finish.', Comment = 'is-IS=Sendu pöntunina í Manufacturing.ProductionOrder.Finish.';
        InvalidMoveLbl: Label 'A production order cannot move from %1 to %2.', Comment = '%1 = current status, %2 = requested status, is-IS=Ekki er hægt að færa framleiðslupöntun úr %1 í %2.';
        InvalidMoveNextLbl: Label 'Send FirmPlanned or Released as newStatus.', Comment = 'is-IS=Sendu FirmPlanned eða Released sem newStatus.';
        NotStatusLbl: Label 'newStatus must be FirmPlanned or Released.', Comment = 'is-IS=newStatus verður að vera FirmPlanned eða Released.';
        BcNextLbl: Label 'Inspect the production order, correct the item, setup or entry named in the Business Central error and retry. Nothing was changed.', Comment = 'is-IS=Skoðaðu framleiðslupöntunina, leiðréttu vöruna, uppsetninguna eða færsluna sem Business Central nefnir í villunni og reyndu aftur. Engu var breytt.';
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        WriteCheck.AssertCanWrite('Manufacturing.ProductionOrder.ChangeStatus');
        if not PostingGate.AssertCanPost(Argument) then
            exit;
        Request := Argument.GetRequestJson();
        Reader.CheckKeys('no|systemId|productionOrderStatus|newStatus|postingDate|expectedCount', Request, Argument);
        NewStatusText := Reader.ReadText(Request, 'newStatus', true, 20, Argument);
        PostingDate := ReadPostingDate(Request, Argument);
        if Reader.RespondIfErrors(Argument) then
            exit;
        if not FinishCheck.FindOrder(Argument, ProductionOrder) then
            exit;
        if NewStatusText = 'Finished' then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, FinishedLbl, 'newStatus', NewStatusText, 'FirmPlanned|Released', FinishedNextLbl);
            exit;
        end;
        if not FinishCheck.TryStatus(NewStatusText, NewStatus) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, NotStatusLbl, 'newStatus', NewStatusText, 'FirmPlanned|Released', InvalidMoveNextLbl);
            exit;
        end;
        if not IsAllowedMove(ProductionOrder.Status, NewStatus) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(InvalidMoveLbl, Lookup.StatusName(ProductionOrder.Status), NewStatusText), 'newStatus', NewStatusText, 'FirmPlanned|Released', InvalidMoveNextLbl);
            exit;
        end;
        WriteContext.SetRequest(ProductionOrder, NewStatus, PostingDate, false, false);
        // Business Central commits inside ChangeProdOrderStatus; the commit is not suppressed under Omit Commit.
        if Argument."Omit Commit" then
            Codeunit.Run(Codeunit::"Prod Order Status Proc ori", Argument)
        else
            if not Codeunit.Run(Codeunit::"Prod Order Status Proc ori", Argument) then
                Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, GetLastErrorText(), '', '', '', BcNextLbl);
        WriteContext.ClearRequest();
    end;

    /// <summary>The moves of the Business Central page Change Status on Prod. Order.</summary>
    internal procedure IsAllowedMove(FromStatus: Enum "Production Order Status"; ToStatus: Enum "Production Order Status"): Boolean
    begin
        case ToStatus of
            ToStatus::"Firm Planned":
                exit(FromStatus in [FromStatus::Simulated, FromStatus::Planned]);
            ToStatus::Released:
                exit(FromStatus in [FromStatus::Simulated, FromStatus::Planned, FromStatus::"Firm Planned"]);
        end;
        exit(false);
    end;

    /// <summary>Reads an optional strict ISO posting date; default is the session work date.</summary>
    internal procedure ReadPostingDate(Request: JsonObject; var Argument: Record "Message Argument ori"): Date
    var
        Reader: Codeunit "Mfg Prod Order Request ori";
        Value: Text;
        PostingDate: Date;
    begin
        if not Request.Contains('postingDate') then
            exit(WorkDate());
        Value := Reader.ReadText(Request, 'postingDate', true, 10, Argument);
        if not Evaluate(PostingDate, Value, 9) then begin
            Reader.BadFormat('postingDate', Argument);
            exit(0D);
        end;
        if (PostingDate = 0D) or (Format(PostingDate, 0, 9) <> Value) then
            Reader.BadFormat('postingDate', Argument);
        exit(PostingDate);
    end;
}
