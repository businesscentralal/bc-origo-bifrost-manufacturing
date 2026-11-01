namespace Origo.Bifrost.Manufacturing;

using Microsoft.Manufacturing.ProductionBOM;
using Origo.Bifrost;

/// <summary>
/// Implements Manufacturing.ProductionBOM.SetStatus.
/// Certifies a production BOM header or one version, or returns it to Under Development,
/// with the standard Business Central checks. The write runs in <c>Prod BOM Status Proc ori</c>
/// unless the caller set Omit Commit, in which case the same apply runs in the caller's transaction.
/// </summary>
codeunit 10077087 "Prod BOM Status Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    var
        Contract: Codeunit "Mfg BOMRtg Contract ori";
        DescriptionLbl: Label 'Certifies a production BOM or one of its versions, or sets it back to Under Development, with the standard Business Central checks.', MaxLength = 250, Comment = 'is-IS=Staðfestir framleiðsluefnislista eða útgáfu hans, eða setur hann aftur í þróun, með venjulegum athugunum Business Central.';

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
        KeywordsLbl: Label 'production bom, certify bom, bom status, under development, production bom version, certify production bom, bom certification, set bom status', Comment = 'is-IS=framleiðsluefnislisti, staðfesta efnislista, staða efnislista, í þróun, útgáfa framleiðsluefnislista, staðfesta framleiðsluefnislista, vottun efnislista, setja stöðu efnislista';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Longer selection text for discovery.</summary>
    /// <returns>When to choose this message type.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Certify a production BOM, or one version of it, or set it back to Under Development so its lines can be edited. Send no and status Certified or UnderDevelopment. Send versionCode only for one version. Closed is not supported.', Comment = 'is-IS=Staðfestu framleiðsluefnislista, eða eina útgáfu hans, eða settu hann aftur í þróun svo hægt sé að breyta línum hans. Sendu no og status Certified eða UnderDevelopment. Sendu versionCode aðeins fyrir eina útgáfu. Closed er ekki stutt.';
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

    /// <summary>Effect chapter. The effect is write and the call is idempotent.</summary>
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
        Contract.Related(Related);
        exit(true);
    end;

    /// <summary>Workflow chapter.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        Contract.Workflow(MessageTypeName(), Workflow);
        exit(true);
    end;

    /// <summary>Examples chapter.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    begin
        Contract.Examples(MessageTypeName(), Examples);
        exit(true);
    end;

    /// <summary>Overview chapter, English only.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := Contract.Overview(true);
        exit(true);
    end;

    /// <summary>Notes chapter, English only. Says why Closed is not supported.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := Contract.Notes();
        exit(true);
    end;

    trigger OnRun()
    var
        Proc: Codeunit "Prod BOM Status Proc ori";
    begin
        Proc.Apply(Rec);
    end;

    /// <summary>Runs the status change. Omit Commit keeps the caller's transaction.</summary>
    /// <param name="Argument">The message argument.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Proc: Codeunit "Prod BOM Status Proc ori";
        Context: Codeunit "BOM Routing Context ori";
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        if Argument."Omit Commit" then begin
            Proc.Apply(Argument);
            Context.Deactivate();
            exit;
        end;
        if not Codeunit.Run(Codeunit::"Prod BOM Status Proc ori", Argument) then
            Argument.RespondWithLastError();
        Context.Deactivate();
    end;

    local procedure MessageTypeName(): Text
    begin
        exit('Manufacturing.ProductionBOM.SetStatus');
    end;
}
