namespace Origo.Bifrost.Manufacturing;

using Microsoft.Manufacturing.ProductionBOM;
using Origo.Bifrost;

/// <summary>
/// Implements Manufacturing.ProductionBOM.CopyVersion.
/// Copies the lines of a production BOM, or of one version, into a new version on the same BOM.
/// The write runs in <c>Prod BOM Copy Proc ori</c> unless the caller set Omit Commit.
/// </summary>
codeunit 10077094 "Prod BOM Copy Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    var
        Contract: Codeunit "Mfg Copy Contract ori";
        DescriptionLbl: Label 'Copies the lines of a production BOM, or of one version, into a new version that is Under Development.', MaxLength = 250, Comment = 'is-IS=Afritar línur framleiðsluefnislista, eða einnar útgáfu, yfir í nýja útgáfu sem er í þróun.';

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
        KeywordsLbl: Label 'production bom, copy bom, bom version, new version, engineering change, copy production bom, version code, starting date', Comment = 'is-IS=framleiðsluefnislisti, afrita efnislista, útgáfa efnislista, ný útgáfa, verkfræðibreyting, afrita framleiðsluefnislista, útgáfunúmer, upphafsdagur';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Longer selection text for discovery.</summary>
    /// <returns>When to choose this call.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Copies a production BOM, or one version of it, into a new version that stays Under Development. Send no or systemId, and startingDate. Omit targetVersionCode to take the next number from Version Nos. A code that already exists is refused, and nothing already present is deleted.', Comment = 'is-IS=Afritar framleiðsluefnislista, eða eina útgáfu hans, yfir í nýja útgáfu sem er í þróun. Sendu no eða systemId, og startingDate. Slepptu targetVersionCode til að taka næsta númer úr Version Nos. Númer sem er þegar til er hafnað og engu sem er þegar til er eytt.';
    begin
        exit(SelectionLbl);
    end;

    /// <summary>The message is inbound.</summary>
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
        Contract.Target(true, Target);
        exit(true);
    end;

    /// <summary>Parameters chapter.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        Contract.Parameters(true, Parameters);
        exit(true);
    end;

    /// <summary>Response chapter.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Contract.Response(true, Response);
        exit(true);
    end;

    /// <summary>Errors chapter, including Retryable.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        Contract.Errors(Errors);
        exit(true);
    end;

    /// <summary>Effect chapter. The effect is write and the call is not idempotent.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Contract.Effect(true, Effect);
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
        Contract.Related(true, Related);
        exit(true);
    end;

    /// <summary>Workflow chapter.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        Contract.Workflow(true, Workflow);
        exit(true);
    end;

    /// <summary>Examples chapter.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        Contract.Examples(true, Examples);
        exit(true);
    end;

    /// <summary>Overview chapter, English only.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := Contract.Overview(true);
        exit(true);
    end;

    /// <summary>Notes chapter, English only.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := Contract.Notes();
        exit(true);
    end;

    trigger OnRun()
    var
        Proc: Codeunit "Prod BOM Copy Proc ori";
    begin
        Proc.Apply(Rec);
    end;

    /// <summary>Runs the copy. Omit Commit keeps the caller's transaction.</summary>
    /// <param name="Argument">The message argument.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        WriteCheck: Codeunit "Mfg Write Check ori";
        Proc: Codeunit "Prod BOM Copy Proc ori";
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        WriteCheck.AssertCanWrite('Manufacturing.ProductionBOM.CopyVersion');
        if Argument."Omit Commit" then begin
            Proc.Apply(Argument);
            exit;
        end;
        if not Codeunit.Run(Codeunit::"Prod BOM Copy Proc ori", Argument) then
            Contract.RespondWithCopyError(Argument);
    end;
}
