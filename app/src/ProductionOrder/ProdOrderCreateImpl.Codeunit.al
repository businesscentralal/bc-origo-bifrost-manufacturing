namespace Origo.Bifrost.Manufacturing;

using Microsoft.Inventory.Item;
using Microsoft.Manufacturing.Document;
using Microsoft.Manufacturing.Setup;
using Origo.Bifrost;

/// <summary>Executes Manufacturing.ProductionOrder.Create with native Business Central validation.</summary>
codeunit 10077041 "Prod Order Create Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    begin
        RunCreate(Rec);
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
        ValueLbl: Label 'Creates a planned or firm planned production order for an item, with the standard Business Central numbering. Use Refresh to calculate its lines.', Comment = 'is-IS=Stofnar áætlaða eða fastákveðna framleiðslupöntun fyrir vöru með venjulegri númeraröðun Business Central. Notaðu Refresh til að reikna línur hennar.';
    begin
        exit(ValueLbl);
    end;

    /// <summary>Returns localized catalogue text.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'production order, manufacturing, planning, create', Comment = 'is-IS=framleiðslupöntun, framleiðsla, áætlanagerð, stofna';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Returns localized catalogue text.</summary>
    procedure GetSelectionDescription(): Text
    var
        ValueLbl: Label 'Create a Planned or FirmPlanned header; then use Manufacturing.ProductionOrder.Refresh.', Comment = 'is-IS=Stofnaðu áætlaða eða fastákveðna pöntun; notaðu síðan Manufacturing.ProductionOrder.Refresh.';
    begin
        exit(ValueLbl);
    end;

    /// <summary>Returns the envelope contract chapter from the shared production order contract.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Contract: Codeunit "Mfg ProdOrder Contract ori";
    begin
        Contract.GetEnvelope(true, Envelope);
        exit(true);
    end;

    /// <summary>Returns the target contract chapter from the shared production order contract.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        Contract: Codeunit "Mfg ProdOrder Contract ori";
    begin
        Contract.GetTarget(true, Target);
        exit(true);
    end;

    /// <summary>Returns the parameters contract chapter from the shared production order contract.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        Contract: Codeunit "Mfg ProdOrder Contract ori";
    begin
        Contract.GetCreateParameters(Parameters);
        exit(true);
    end;

    /// <summary>Returns the response contract chapter from the shared production order contract.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Contract: Codeunit "Mfg ProdOrder Contract ori";
    begin
        Contract.GetResponse(true, Response);
        exit(true);
    end;

    /// <summary>Returns the errors contract chapter from the shared production order contract.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        Contract: Codeunit "Mfg ProdOrder Contract ori";
    begin
        Contract.GetErrors(true, Errors);
        exit(true);
    end;

    /// <summary>Returns the effect contract chapter from the shared production order contract.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Contract: Codeunit "Mfg ProdOrder Contract ori";
    begin
        Contract.GetEffect(true, Effect);
        exit(true);
    end;

    /// <summary>Returns the related contract chapter from the shared production order contract.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        Contract: Codeunit "Mfg ProdOrder Contract ori";
    begin
        Contract.GetRelated(true, Related);
        exit(true);
    end;

    /// <summary>Returns the workflow contract chapter from the shared production order contract.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Contract: Codeunit "Mfg ProdOrder Contract ori";
    begin
        Contract.GetWorkflow(true, Workflow);
        exit(true);
    end;

    /// <summary>Returns the examples contract chapter from the shared production order contract.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Contract: Codeunit "Mfg ProdOrder Contract ori";
    begin
        Contract.GetExamples(true, Examples);
        exit(true);
    end;

    /// <summary>Returns the overview contract chapter from the shared production order contract.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    var
        Contract: Codeunit "Mfg ProdOrder Contract ori";
    begin
        Contract.GetOverview(true, Overview);
        exit(true);
    end;

    /// <summary>Returns the notes contract chapter from the shared production order contract.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    var
        Contract: Codeunit "Mfg ProdOrder Contract ori";
    begin
        Contract.GetNotes(true, Notes);
        exit(true);
    end;

    /// <summary>Declares no app-specific metering in addition to Foundation.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Validates all inputs before opening the atomic header creation boundary.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Item: Record Item;
        Setup: Record "Manufacturing Setup";
        Reader: Codeunit "Mfg Prod Order Request ori";
        Request: JsonObject;
        SourceNo: Text;
        StatusText: Text;
        ItemMissingLbl: Label 'Item %1 was not found.', Comment = '%1 = item number, is-IS=Vara %1 fannst ekki.';
        ItemNextLbl: Label 'Read the item list with Data.Records.Get and send a valid sourceNo.', Comment = 'is-IS=Lestu vörulistann með Data.Records.Get og sendu gilt sourceNo.';
        StatusLbl: Label 'Production orders are created as Planned or Firm Planned. Create the order, refresh it, then change its status to Released.', Comment = 'is-IS=Framleiðslupantanir eru stofnaðar sem áætlaðar eða fastákveðnar. Stofnaðu pöntunina, endurnýjaðu hana og breyttu síðan stöðu hennar í útgefin.';
        StatusNextLbl: Label 'Use Manufacturing.ProductionOrder.Create, Manufacturing.ProductionOrder.Refresh, then Manufacturing.ProductionOrder.ChangeStatus.', Comment = 'is-IS=Notaðu Manufacturing.ProductionOrder.Create, Manufacturing.ProductionOrder.Refresh og síðan Manufacturing.ProductionOrder.ChangeStatus.';
        SeriesLbl: Label 'The production order number series is not configured.', Comment = 'is-IS=Númeraröð framleiðslupantana hefur ekki verið sett upp.';
        SeriesNextLbl: Label 'Set the production order number series in Manufacturing Setup.', Comment = 'is-IS=Settu upp númeraröð framleiðslupantana í framleiðslugrunni.';
        BcNextLbl: Label 'Correct the Business Central field or setup named in the error and retry. Nothing was changed.', Comment = 'is-IS=Leiðréttu reitinn eða uppsetninguna sem Business Central nefnir í villunni og reyndu aftur. Engu var breytt.';
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        Request := Argument.GetRequestJson();
        Reader.CheckKeys('sourceNo|quantity|status|dueDate|variantCode|description|locationCode|binCode|no', Request, Argument);
        SourceNo := Reader.ReadText(Request, 'sourceNo', true, 20, Argument);
        Reader.ReadQuantity(Request, Argument);
        Reader.ReadDueDate(Request, Argument);
        Reader.ReadText(Request, 'variantCode', false, 10, Argument);
        Reader.ReadText(Request, 'description', false, 100, Argument);
        Reader.ReadText(Request, 'locationCode', false, 10, Argument);
        Reader.ReadText(Request, 'binCode', false, 20, Argument);
        Reader.ReadText(Request, 'no', false, 20, Argument);
        StatusText := Reader.ReadText(Request, 'status', false, 20, Argument);
        if Request.Contains('status') and (StatusText <> 'Planned') and (StatusText <> 'FirmPlanned') then
            Argument.AddError("Bifrost Error Code ori"::InvalidParameter, StatusLbl, 'status', StatusText, 'Planned|FirmPlanned', StatusNextLbl);
        if (SourceNo <> '') and (StrLen(SourceNo) <= MaxStrLen(Item."No.")) then begin
            Item.SetLoadFields("No.", Blocked, "Production Blocked");
            if not Item.Get(SourceNo) then
                Argument.AddError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(ItemMissingLbl, SourceNo), 'sourceNo', SourceNo, '', ItemNextLbl)
            else
                if not CheckItem(Item) then
                    Argument.AddError("Bifrost Error Code ori"::PreconditionFailed, GetLastErrorText(), 'sourceNo', SourceNo, '', ItemNextLbl);
        end;
        Setup.SetLoadFields("Planned Order Nos.", "Firm Planned Order Nos.");
        if not Setup.Get() then
            Argument.AddError("Bifrost Error Code ori"::PreconditionFailed, SeriesLbl, '', '', '', SeriesNextLbl)
        else
            if ((StatusText <> 'FirmPlanned') and (Setup."Planned Order Nos." = '')) or
               ((StatusText = 'FirmPlanned') and (Setup."Firm Planned Order Nos." = ''))
            then
                Argument.AddError("Bifrost Error Code ori"::PreconditionFailed, SeriesLbl, '', '', '', SeriesNextLbl);
        if Reader.RespondIfErrors(Argument) then
            exit;
        // Never catch a write in a TryFunction. Under Omit Commit the caller owns rollback.
        if Argument."Omit Commit" then
            Codeunit.Run(Codeunit::"Prod Order Create Impl ori", Argument)
        else
            if not Codeunit.Run(Codeunit::"Prod Order Create Impl ori", Argument) then
                Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, GetLastErrorText(), '', '', '', BcNextLbl);
    end;

    [TryFunction]
    local procedure CheckItem(Item: Record Item)
    begin
        Item.TestField(Blocked, false);
        if Item."Production Blocked" = Item."Production Blocked"::Output then
            Item.TestField("Production Blocked", Item."Production Blocked"::" ");
    end;

    local procedure RunCreate(var Argument: Record "Message Argument ori")
    var
        ProductionOrder: Record "Production Order";
        Reader: Codeunit "Mfg Prod Order Request ori";
        Lookup: Codeunit "Mfg Prod Order Lookup ori";
        Request: JsonObject;
        Response: JsonObject;
        StatusText: Text;
        NextLbl: Label 'Use Manufacturing.ProductionOrder.Refresh to calculate lines, routing and components.', Comment = 'is-IS=Notaðu Manufacturing.ProductionOrder.Refresh til að reikna línur, vinnsluleið og efnisþörf.';
    begin
        Request := Argument.GetRequestJson();
        ProductionOrder.Init();
        ProductionOrder.Status := ProductionOrder.Status::Planned;
        StatusText := Reader.ReadText(Request, 'status', false, 20, Argument);
        if StatusText = 'FirmPlanned' then
            ProductionOrder.Status := ProductionOrder.Status::"Firm Planned";
        ProductionOrder.Validate("Source Type", ProductionOrder."Source Type"::Item);
        ProductionOrder.Validate("Source No.", CopyStr(Reader.ReadText(Request, 'sourceNo', true, 20, Argument), 1, 20));
        if Request.Contains('variantCode') then
            ProductionOrder.Validate("Variant Code", CopyStr(Reader.ReadText(Request, 'variantCode', false, 10, Argument), 1, 10));
        if Request.Contains('locationCode') then
            ProductionOrder.Validate("Location Code", CopyStr(Reader.ReadText(Request, 'locationCode', false, 10, Argument), 1, 10));
        if Request.Contains('binCode') then
            ProductionOrder.Validate("Bin Code", CopyStr(Reader.ReadText(Request, 'binCode', false, 20, Argument), 1, 20));
        ProductionOrder.Validate(Quantity, Reader.ReadQuantity(Request, Argument));
        ProductionOrder.Validate("Due Date", Reader.ReadDueDate(Request, Argument));
        if Request.Contains('description') then
            ProductionOrder.Validate(Description, CopyStr(Reader.ReadText(Request, 'description', false, 100, Argument), 1, MaxStrLen(ProductionOrder.Description)));
        if Request.Contains('no') then
            ProductionOrder.Validate("No.", CopyStr(Reader.ReadText(Request, 'no', false, 20, Argument), 1, 20));
        ProductionOrder.Insert(true);
        Response.Add('status', 'Success');
        Response.Add('productionOrderStatus', Lookup.StatusName(ProductionOrder.Status));
        Response.Add('no', ProductionOrder."No.");
        Response.Add('systemId', Format(ProductionOrder.SystemId, 0, 4));
        Response.Add('sourceNo', ProductionOrder."Source No.");
        Response.Add('quantity', ProductionOrder.Quantity);
        Response.Add('dueDate', Format(ProductionOrder."Due Date", 0, 9));
        Response.Add('linesCreated', 0);
        Response.Add('nextStep', NextLbl);
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
