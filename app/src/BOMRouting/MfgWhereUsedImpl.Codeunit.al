namespace Origo.Bifrost.Manufacturing;

using Microsoft.Manufacturing.ProductionBOM;
using Origo.Bifrost;

/// <summary>Finds item and production BOM usage through native manufacturing calculations.</summary>
codeunit 10077082 "Mfg WhereUsed Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    var
        Contract: Codeunit "Mfg WhereUsed Contract ori";
        DescriptionLbl: Label 'Finds the assemblies that use an item or production BOM, with levels and required quantities.', MaxLength = 250, Comment = 'is-IS=Finnur samsetningar sem nota vöru eða framleiðsluefnislista, með þrepum og nauðsynlegu magni.';

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
        KeywordsLbl: Label 'where used, component, production bom, assembly, multilevel, quantity, engineering', Comment = 'is-IS=hvar notað, íhlutur, framleiðsluefnislisti, samsetning, mörg þrep, magn, verkfræði';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Longer selection text for discovery.</summary>
    /// <returns>When to choose this call.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Finds the assemblies using an item or production BOM on a calculation date. Choose multiLevel for indirect usage. Nothing is changed.', Comment = 'is-IS=Finnur samsetningar sem nota vöru eða framleiðsluefnislista á útreikningsdegi. Veldu multiLevel fyrir óbeina notkun. Engu er breytt.';
    begin
        exit(SelectionLbl);
    end;

    /// <summary>The call reads manufacturing data.</summary>
    /// <returns>Outbound.</returns>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
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

    /// <summary>Effect chapter. The effect is read and the call is idempotent.</summary>
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

    /// <summary>Reads where-used results without changing manufacturing records.</summary>
    /// <param name="Argument">The dispatcher argument.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Calculation: Codeunit "Mfg WhereUsed Calc ori";
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        Calculation.Apply(Argument);
    end;
}
