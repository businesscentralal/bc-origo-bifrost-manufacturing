namespace Origo.Bifrost.Manufacturing;

using Microsoft.Manufacturing.ProductionBOM;
using Origo.Bifrost;

/// <summary>Exchanges components into new BOM versions through the native processing-only report.</summary>
codeunit 10077105 "Mfg Exchange Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori", "Msg Confirm ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    var
        Contract: Codeunit "Mfg Exchange Contract ori";
        DescriptionLbl: Label 'Replaces a component across active production BOMs by creating new versions; existing versions stay unchanged.', MaxLength = 250, Comment = 'is-IS=Skiptir um íhlut í virkum framleiðsluefnislistum með því að búa til nýjar útgáfur; eldri útgáfur haldast óbreyttar.';

    /// <summary>The type is always available. It does not read a setup table.</summary>
    /// <returns>True.</returns>
    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    /// <summary>The filter table is the production BOM header.</summary>
    /// <returns>The table id of Production BOM Header.</returns>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Production BOM Header");
    end;

    /// <summary>Catalogue description.</summary>
    /// <returns>The description, in the caller's language.</returns>
    procedure GetDescription(): Text[250]
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Search keywords. The Icelandic list is not shorter than the English one.</summary>
    /// <returns>Comma-separated keywords.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'exchange component, replace item, production bom, engineering change, new versions, discontinued item', Comment = 'is-IS=skipta um íhlut, skipta út vöru, framleiðsluefnislisti, verkfræðibreyting, nýjar útgáfur, hætt vara';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Longer selection text for discovery.</summary>
    /// <returns>When to choose this call.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Replaces a component in new versions of active production BOMs. Preview without expectedCount, then confirm the number of new versions. Existing headers, versions and lines stay unchanged.', Comment = 'is-IS=Skiptir út íhlut í nýjum útgáfum virkra framleiðsluefnislista. Forskoðaðu án expectedCount og staðfestu síðan fjölda nýrra útgáfa. Eldri hausar, útgáfur og línur haldast óbreytt.';
    begin
        exit(SelectionLbl);
    end;

    /// <summary>The call reads manufacturing data.</summary>
    /// <returns>Inbound.</returns>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Envelope chapter. The subject is not read.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        Contract.Envelope(Envelope);
        exit(true);
    end;

    /// <summary>Target chapter.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        Contract.Target(Target);
        exit(true);
    end;

    /// <summary>Parameters chapter.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        Contract.Parameters(Parameters);
        exit(true);
    end;

    /// <summary>Response chapter.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Contract.Response(Response);
        exit(true);
    end;

    /// <summary>Lists refusals and corrective steps.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        Contract.Errors(Errors);
        exit(true);
    end;

    /// <summary>Effect chapter. The call creates confirmed new versions and is not idempotent.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Contract.Effect(Effect);
        exit(true);
    end;

    /// <summary>Metering is filled by Foundation.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Related chapter.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        Contract.Related(Related);
        exit(true);
    end;

    /// <summary>Workflow chapter.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        Contract.Workflow(Workflow);
        exit(true);
    end;

    /// <summary>Examples chapter.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        Contract.Examples(Examples);
        exit(true);
    end;

    /// <summary>Overview chapter, English only.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := Contract.Overview();
        exit(true);
    end;

    /// <summary>Notes chapter, English only.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := Contract.Notes();
        exit(true);
    end;

    /// <summary>Counts distinct active BOMs before Foundation confirms the exchange.</summary>
    /// <param name="Argument">The dispatcher argument.</param>
    /// <param name="Count">The number of new versions.</param>
    /// <param name="Summary">A localized description of the count.</param>
    /// <returns>True when the request is ready for confirmation.</returns>
    procedure GetConfirmCount(var Argument: Record "Message Argument ori"; var Count: Integer; var Summary: Text): Boolean
    var
        TempSelected: Record "Production BOM Header" temporary;
        Proc: Codeunit "Mfg Exchange Proc ori";
        Request: JsonObject;
        Skipped: JsonArray;
        SummaryLbl: Label '%1 new production BOM versions', Comment = '%1 = new version count, is-IS=%1 nýjar útgáfur framleiðsluefnislista';
    begin
        if not Proc.Prepare(Argument, Request, TempSelected, Skipped) then
            exit(false);
        Count := TempSelected.Count();
        Summary := StrSubstNo(SummaryLbl, Count);
        exit(true);
    end;

    /// <summary>Runs the exchange within an atomic native-report boundary.</summary>
    /// <param name="Argument">The dispatcher argument.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        TempSelected: Record "Production BOM Header" temporary;
        Proc: Codeunit "Mfg Exchange Proc ori";
        Request: JsonObject;
        Skipped: JsonArray;
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        if not Proc.Prepare(Argument, Request, TempSelected, Skipped) then
            exit;
        if Argument."Omit Commit" then begin
            Contract.FailOmitCommit(Argument);
            exit;
        end;
        if not Codeunit.Run(Codeunit::"Mfg Exchange Proc ori", Argument) then
            Contract.FailNative(Argument);
    end;
}
