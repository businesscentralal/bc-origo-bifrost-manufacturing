namespace Origo.Bifrost.Manufacturing;

using Microsoft.Inventory.Item;
using Microsoft.Manufacturing.Document;
using Microsoft.Manufacturing.Setup;
using Origo.Bifrost;

/// <summary>Executes Manufacturing.ProductionOrder.Refresh with native Business Central validation.</summary>
codeunit 10077042 "Prod Order Refresh Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    begin
        RunRefresh(Rec);
    end;

    /// <summary>Discovery has no data-table reads or permission side effects.</summary>
    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    /// <summary>Identifies the manufacturing header table for discovery.</summary>
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
        ValueLbl: Label 'Recalculates the lines, routing and components of a planned or firm planned production order with the standard Business Central refresh.', Comment = 'is-IS=Endurreiknar línur, vinnsluleið og efnisþörf áætlaðrar eða fastákveðinnar framleiðslupöntunar með venjulegri endurnýjun Business Central.';
    begin
        exit(ValueLbl);
    end;

    /// <summary>Returns localized catalogue text.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'production order, manufacturing, planning, refresh', Comment = 'is-IS=framleiðslupöntun, framleiðsla, áætlanagerð, endurnýja';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Returns localized catalogue text.</summary>
    procedure GetSelectionDescription(): Text
    var
        ValueLbl: Label 'Recalculate a planning order. Released and Finished orders are refused.', Comment = 'is-IS=Endurreiknaðu áætlaða pöntun. Útgefnum og loknum pöntunum er hafnað.';
    begin
        exit(ValueLbl);
    end;

    /// <summary>Returns the envelope contract chapter from the shared production order contract.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Contract: Codeunit "Mfg ProdOrder Contract ori";
    begin
        Contract.GetEnvelope(false, Envelope);
        exit(true);
    end;

    /// <summary>Returns the target contract chapter from the shared production order contract.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        Contract: Codeunit "Mfg ProdOrder Contract ori";
    begin
        Contract.GetTarget(false, Target);
        exit(true);
    end;

    /// <summary>Returns the parameters contract chapter from the shared production order contract.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Contract: Codeunit "Mfg ProdOrder Contract ori";
    begin
        Contract.GetRefreshParameters(Parameters);
        exit(true);
    end;

    /// <summary>Returns the response contract chapter from the shared production order contract.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Contract: Codeunit "Mfg ProdOrder Contract ori";
    begin
        Contract.GetResponse(false, Response);
        exit(true);
    end;

    /// <summary>Returns the errors contract chapter from the shared production order contract.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Contract: Codeunit "Mfg ProdOrder Contract ori";
    begin
        Contract.GetErrors(false, Errors);
        exit(true);
    end;

    /// <summary>Returns the effect contract chapter from the shared production order contract.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Contract: Codeunit "Mfg ProdOrder Contract ori";
    begin
        Contract.GetEffect(false, Effect);
        exit(true);
    end;

    /// <summary>Returns the related contract chapter from the shared production order contract.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        Contract: Codeunit "Mfg ProdOrder Contract ori";
    begin
        Contract.GetRelated(false, Related);
        exit(true);
    end;

    /// <summary>Returns the workflow contract chapter from the shared production order contract.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Contract: Codeunit "Mfg ProdOrder Contract ori";
    begin
        Contract.GetWorkflow(false, Workflow);
        exit(true);
    end;

    /// <summary>Returns the examples contract chapter from the shared production order contract.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Contract: Codeunit "Mfg ProdOrder Contract ori";
    begin
        Contract.GetExamples(false, Examples);
        exit(true);
    end;

    /// <summary>Returns the overview contract chapter from the shared production order contract.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    var
        Contract: Codeunit "Mfg ProdOrder Contract ori";
    begin
        Contract.GetOverview(false, Overview);
        exit(true);
    end;

    /// <summary>Returns the notes contract chapter from the shared production order contract.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    var
        Contract: Codeunit "Mfg ProdOrder Contract ori";
    begin
        Contract.GetNotes(false, Notes);
        exit(true);
    end;

    /// <summary>Declares no app-specific metering in addition to Foundation.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Checks refresh options and order status before running BC's report in an atomic boundary.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        ProductionOrder: Record "Production Order";
        Reader: Codeunit "Mfg Prod Order Request ori";
        Lookup: Codeunit "Mfg Prod Order Lookup ori";
        Request: JsonObject;
        Direction: Text;
        CalculateLines: Boolean;
        CalculateRoutings: Boolean;
        CalculateComponents: Boolean;
        DirectionLbl: Label 'direction must be Forward or Backward.', Comment = 'is-IS=direction verður að vera Forward eða Backward.';
        DirectionNextLbl: Label 'Send Forward or Backward, or omit direction for Backward.', Comment = 'is-IS=Sendu Forward eða Backward, eða slepptu direction til að nota Backward.';
        CalculateLbl: Label 'When calculateLines is true, calculateRoutings and calculateComponents must both be true.', Comment = 'is-IS=Þegar calculateLines er true verða calculateRoutings og calculateComponents bæði að vera true.';
        CalculateNextLbl: Label 'Enable routing and component calculation or set calculateLines to false.', Comment = 'is-IS=Virkjaðu útreikning vinnsluleiða og efnisþarfar eða stilltu calculateLines á false.';
        ReleasedLbl: Label 'Production order %1 is Released and cannot be refreshed by this message type. Nothing was changed.', Comment = '%1 = order number, is-IS=Framleiðslupöntun %1 er útgefin og ekki er hægt að endurnýja hana með þessari skilaboðagerð. Engu var breytt.';
        FinishedLbl: Label 'Production order %1 is Finished and cannot be refreshed.', Comment = '%1 = order number, is-IS=Framleiðslupöntun %1 er lokið og ekki er hægt að endurnýja hana.';
        StatusNextLbl: Label 'Refresh a Planned or FirmPlanned order before releasing it. Released orders are not refreshed by this type.', Comment = 'is-IS=Endurnýjaðu áætlaða eða fastákveðna pöntun áður en hún er gefin út. Þessi gerð endurnýjar ekki útgefnar pantanir.';
        BcNextLbl: Label 'Correct the Business Central field, BOM, routing or setup named in the error and retry. Nothing was changed.', Comment = 'is-IS=Leiðréttu reitinn, framleiðsluuppskriftina, vinnsluleiðina eða uppsetninguna sem Business Central nefnir í villunni og reyndu aftur. Engu var breytt.';
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        Request := Argument.GetRequestJson();
        Reader.CheckKeys('no|systemId|productionOrderStatus|direction|calculateLines|calculateRoutings|calculateComponents', Request, Argument);
        Direction := Reader.ReadText(Request, 'direction', false, 8, Argument);
        if Request.Contains('direction') and (Direction <> 'Forward') and (Direction <> 'Backward') then
            Argument.AddError("Bifrost Error Code ori"::InvalidParameter, DirectionLbl, 'direction', Direction, 'Forward|Backward', DirectionNextLbl);
        CalculateLines := Reader.ReadBoolean(Request, 'calculateLines', Argument);
        CalculateRoutings := Reader.ReadBoolean(Request, 'calculateRoutings', Argument);
        CalculateComponents := Reader.ReadBoolean(Request, 'calculateComponents', Argument);
        if CalculateLines and not (CalculateRoutings and CalculateComponents) then
            Argument.AddError("Bifrost Error Code ori"::InvalidParameter, CalculateLbl, 'calculateLines', '', '', CalculateNextLbl);
        if not Lookup.FindOrder(Argument, ProductionOrder) then
            exit;
        case ProductionOrder.Status of
            ProductionOrder.Status::Released:
                Argument.AddError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(ReleasedLbl, ProductionOrder."No."), 'productionOrderStatus', 'Released', '', StatusNextLbl);
            ProductionOrder.Status::Finished:
                Argument.AddError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(FinishedLbl, ProductionOrder."No."), 'productionOrderStatus', 'Finished', '', StatusNextLbl);
        end;
        if Reader.RespondIfErrors(Argument) then
            exit;
        if Argument."Omit Commit" then
            Codeunit.Run(Codeunit::"Prod Order Refresh Proc ori", Argument)
        else
            if not Codeunit.Run(Codeunit::"Prod Order Refresh Proc ori", Argument) then
                Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, GetLastErrorText(), '', '', '', BcNextLbl);
    end;

    local procedure RunRefresh(var Argument: Record "Message Argument ori")
    begin
        Codeunit.Run(Codeunit::"Prod Order Refresh Proc ori", Argument);
    end;
}
