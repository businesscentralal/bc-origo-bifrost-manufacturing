namespace Origo.Bifrost.Manufacturing;

using Microsoft.Manufacturing.ProductionBOM;
using Origo.Bifrost;

/// <summary>
/// Implements production BOM validation and copy messages using Microsoft's manufacturing codeunits.
/// </summary>
codeunit 10077048 "Mfg Prod BOM Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    TableNo = "Message Argument ori";

    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        ProductionBOMRequiredErr: Label 'Provide a production BOM number in the subject or data.productionBOMNo.', Comment = 'is-IS=Tilgreindu uppskriftarnúmer í subject eða data.productionBOMNo.';
        SourceProductionBOMRequiredErr: Label 'Provide sourceProductionBOMNo for Manufacturing.ProductionBOM.Copy.', Comment = 'is-IS=Tilgreindu sourceProductionBOMNo fyrir Manufacturing.ProductionBOM.Copy.';
        ProductionBOMNotFoundErr: Label 'Production BOM %1 does not exist.', Comment = '%1 = production BOM number||is-IS=Framleiðsluuppskrift %1 er ekki til.';
        DescriptionLbl: Label 'Checks production BOM structure or copies BOM lines from one production BOM into another BOM or version.', MaxLength = 250, Comment = 'is-IS=Yfirfer byggingu framleiðsluuppskriftar eða afritar uppskriftarlínur úr einni framleiðsluuppskrift í aðra uppskrift eða útgáfu.';

    /// <summary>Reports whether production BOM operations are available.</summary>
    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    /// <summary>Returns the production BOM header table used to filter these operations.</summary>
    procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Production BOM Header");
    end;

    /// <summary>Describes production BOM check and copy actions.</summary>
    procedure GetDescription() Description: Text[250]
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns search terms for production BOM actions.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'production BOM, check BOM, copy BOM, version, components, low-level code', Comment = 'is-IS=framleiðsluuppskrift, yfirfara uppskrift, afrita uppskrift, útgáfa, íhlutir, lágstigskóði';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Explains the effects of checking or copying a production BOM.</summary>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Check recalculates low-level codes; Copy replaces destination lines unless the source and destination version are the same. Certified destinations cannot be overwritten.', Comment = 'is-IS=Check endurreiknar lágstigskóða; Copy skiptir út línum í áfangauppskrift nema uppruna- og áfangagerð séu sömu. Vottuðum áföngum er ekki hægt að skrifa yfir.';
    begin
        exit(SelectionLbl);
    end;

    /// <summary>Describes the request envelope.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
        SubjectForms: JsonArray;
    begin
        Subject.Add('use', 'optional');
        SubjectForms.Add('string');
        Subject.Add('forms', SubjectForms);
        Subject.Add('description', 'Production BOM number. For Copy, this is the destination BOM number.');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    /// <summary>Describes the destination production BOM.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        Target.Add(ContractMgt.TargetEntry('subject', 'destination production BOM number', 'Used when the subject is set.'));
        Target.Add(ContractMgt.TargetEntry('data.productionBOMNo', 'production BOM number', 'Used when the subject is empty.'));
        exit(true);
    end;

    /// <summary>Describes the parameters used by BOM check and copy.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        Parameters.Add(ContractMgt.Parameter('productionBOMNo', 'string', false, 'The BOM to check, or the destination BOM for Copy. May be supplied as the subject instead.'));
        Parameters.Add(ContractMgt.Parameter('versionCode', 'string', false, 'The version to check. Used by Check; omit for the BOM header.'));
        Parameters.Add(ContractMgt.Parameter('sourceProductionBOMNo', 'string', false, 'The source BOM to copy from. Required by Copy.'));
        Parameters.Add(ContractMgt.Parameter('sourceVersionCode', 'string', false, 'The source BOM version. Used by Copy.'));
        Parameters.Add(ContractMgt.Parameter('destinationVersionCode', 'string', false, 'The destination version. Omit to copy to the BOM header.'));
        exit(true);
    end;

    /// <summary>Describes the successful response.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        Fields: JsonArray;
        ResponseField: JsonObject;
    begin
        ResponseField.Add('name', 'status');
        ResponseField.Add('type', 'string');
        ResponseField.Add('description', 'Success when the check or copy completed.');
        Fields.Add(ResponseField);
        Clear(ResponseField);
        ResponseField.Add('name', 'productionBOMNo');
        ResponseField.Add('type', 'string');
        ResponseField.Add('description', 'The checked or destination BOM number.');
        Fields.Add(ResponseField);
        Clear(ResponseField);
        ResponseField.Add('name', 'versionCode');
        ResponseField.Add('type', 'string');
        ResponseField.Add('description', 'The version checked or copied to.');
        Fields.Add(ResponseField);
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Describes missing BOM and source parameters.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ErrorInfo: JsonObject;
    begin
        ErrorInfo.Add('error', 'Production BOM not found.');
        ErrorInfo.Add('when', 'The destination or source BOM number does not identify an existing BOM.');
        ErrorInfo.Add('fix', 'Check productionBOMNo and sourceProductionBOMNo.');
        Errors.Add(ErrorInfo);
        exit(true);
    end;

    /// <summary>Describes the write effect of BOM operations.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Check updates low-level codes; Copy can replace destination BOM component and comment lines.');
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', 'BIFROST Mfg ori');
        exit(true);
    end;

    /// <summary>Declares no additional manufacturing-specific metering.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Declares no related message types.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>Describes the BOM maintenance workflow.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Steps: JsonArray;
        WorkflowStep: JsonObject;
    begin
        WorkflowStep.Add('messageType', 'Manufacturing.ProductionBOM.Copy then Manufacturing.ProductionBOM.Check');
        WorkflowStep.Add('purpose', 'Copy source lines into the destination, then check the destination BOM before certifying it.');
        Steps.Add(WorkflowStep);
        Workflow.Add('steps', Steps);
        exit(true);
    end;

    /// <summary>Provides examples for checking and copying production BOMs.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        RequestData: JsonObject;
        Request: JsonObject;
        Response: JsonObject;
        Example: JsonObject;
    begin
        RequestData.Add('productionBOMNo', 'X-BOM-001');
        RequestData.Add('versionCode', 'X-01');
        Request.Add('type', 'Manufacturing.ProductionBOM.Check');
        Request.Add('data', RequestData);
        Response.Add('status', 'Success');
        Response.Add('productionBOMNo', 'X-BOM-001');
        Response.Add('versionCode', 'X-01');
        Example.Add('title', 'Check a production BOM version');
        Example.Add('request', Request);
        Example.Add('response', Response);
        Examples.Add(Example);

        Clear(RequestData);
        Clear(Request);
        Clear(Response);
        Clear(Example);
        RequestData.Add('productionBOMNo', 'X-BOM-002');
        RequestData.Add('sourceProductionBOMNo', 'X-BOM-001');
        RequestData.Add('sourceVersionCode', 'X-01');
        RequestData.Add('destinationVersionCode', 'X-02');
        Request.Add('type', 'Manufacturing.ProductionBOM.Copy');
        Request.Add('data', RequestData);
        Response.Add('status', 'Success');
        Response.Add('productionBOMNo', 'X-BOM-002');
        Response.Add('versionCode', 'X-02');
        Example.Add('title', 'Copy a production BOM version');
        Example.Add('request', Request);
        Example.Add('response', Response);
        Examples.Add(Example);
        exit(true);
    end;

    /// <summary>Explains production BOM validation and copy.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Check runs Microsoft production BOM structure and circular-reference validation. Copy copies component and comment lines from a source BOM or version to an existing destination.';
        exit(true);
    end;

    /// <summary>Documents important behavior of BOM checking and copying.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Check can update low-level codes and may fail on missing units, circular references, or invalid routing links. Copy replaces destination lines and comments unless Microsoft skips deletion; certified destinations are rejected.';
        exit(true);
    end;

    /// <summary>Returns the inbound message direction.</summary>
    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    trigger OnRun()
    begin
        PerformBOMAction(Rec);
    end;

    /// <summary>Executes this message type through Bifrost Foundation.</summary>
    /// <param name="Argument">The message argument and response record.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        if Argument."Omit Commit" then begin
            PerformBOMAction(Argument);
            exit;
        end;

        if not Codeunit.Run(Codeunit::"Mfg Prod BOM Impl ori", Argument) then
            Argument.RespondWithLastError();
    end;

    local procedure PerformBOMAction(var Argument: Record "Message Argument ori")
    var
        ProductionBOMHeader: Record "Production BOM Header";
        SourceProductionBOMHeader: Record "Production BOM Header";
        ProductionBOMCheck: Codeunit "Production BOM-Check";
        ProductionBOMCopy: Codeunit "Production BOM-Copy";
        RequestJson: JsonObject;
        RequestToken: JsonToken;
        ResponseJson: JsonObject;
        ProductionBOMNo: Code[20];
        ProductionBOMNoText: Text;
        SourceProductionBOMNo: Code[20];
        VersionCode: Code[20];
        SourceVersionCode: Code[20];
        DestinationVersionCode: Code[20];
    begin
        RequestJson := Argument.GetRequestJson();
        ProductionBOMNoText := Argument.Subject;
        if ProductionBOMNoText = '' then begin
            if not RequestJson.Get('productionBOMNo', RequestToken) then
                Error(ProductionBOMRequiredErr);
            if not RequestToken.IsValue() then
                Error(ProductionBOMRequiredErr);
            ProductionBOMNoText := RequestToken.AsValue().AsText();
        end;
        if StrLen(ProductionBOMNoText) > MaxStrLen(ProductionBOMNo) then
            Error(ProductionBOMRequiredErr);
        ProductionBOMNo := CopyStr(ProductionBOMNoText, 1, MaxStrLen(ProductionBOMNo));

        ProductionBOMHeader.SetLoadFields("No.", "Unit of Measure Code", "Low-Level Code", Status);
        if not ProductionBOMHeader.Get(ProductionBOMNo) then
            Error(ProductionBOMNotFoundErr, ProductionBOMNo);

        if Argument.Type = Enum::"Message Type ori"::"Manufacturing.ProductionBOM.Copy" then begin
            if not RequestJson.Get('sourceProductionBOMNo', RequestToken) then
                Error(SourceProductionBOMRequiredErr);
            if not RequestToken.IsValue() then
                Error(SourceProductionBOMRequiredErr);
            if StrLen(RequestToken.AsValue().AsText()) > MaxStrLen(SourceProductionBOMNo) then
                Error(SourceProductionBOMRequiredErr);
            SourceProductionBOMNo := CopyStr(RequestToken.AsValue().AsText(), 1, MaxStrLen(SourceProductionBOMNo));

            SourceProductionBOMHeader.SetLoadFields("No.");
            if not SourceProductionBOMHeader.Get(SourceProductionBOMNo) then
                Error(ProductionBOMNotFoundErr, SourceProductionBOMNo);

            SourceVersionCode := CopyStr(GetOptionalText(RequestJson, 'sourceVersionCode'), 1, MaxStrLen(SourceVersionCode));
            DestinationVersionCode := CopyStr(GetOptionalText(RequestJson, 'destinationVersionCode'), 1, MaxStrLen(DestinationVersionCode));
            ProductionBOMCopy.CopyBOM(SourceProductionBOMNo, SourceVersionCode, ProductionBOMHeader, DestinationVersionCode);
            VersionCode := DestinationVersionCode;
        end else begin
            VersionCode := CopyStr(GetOptionalText(RequestJson, 'versionCode'), 1, MaxStrLen(VersionCode));
            ProductionBOMCheck.Code(ProductionBOMHeader, VersionCode);
        end;

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('productionBOMNo', ProductionBOMNo);
        ResponseJson.Add('versionCode', VersionCode);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure GetOptionalText(RequestJson: JsonObject; PropertyName: Text): Text
    var
        RequestToken: JsonToken;
    begin
        if not RequestJson.Get(PropertyName, RequestToken) then
            exit('');
        if not RequestToken.IsValue() then
            exit('');
        exit(RequestToken.AsValue().AsText());
    end;
}