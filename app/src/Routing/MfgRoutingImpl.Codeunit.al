namespace Origo.Bifrost.Manufacturing;

using Microsoft.Manufacturing.Routing;
using Origo.Bifrost;

/// <summary>
/// Implements routing check and copy messages using Microsoft's routing management codeunits.
/// </summary>
codeunit 10077050 "Mfg Routing Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    TableNo = "Message Argument ori";

    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        RoutingRequiredErr: Label 'Provide a routing number in the subject or data.routingNo.', Comment = 'is-IS=Tilgreindu leiðarnúmer í subject eða data.routingNo.';
        SourceRoutingRequiredErr: Label 'Provide sourceRoutingNo for Manufacturing.Routing.Copy.', Comment = 'is-IS=Tilgreindu sourceRoutingNo fyrir Manufacturing.Routing.Copy.';
        RoutingNotFoundErr: Label 'Routing %1 does not exist.', Comment = '%1 = routing number||is-IS=Leið %1 er ekki til.';
        DescriptionLbl: Label 'Calculates routing sequences and validates a routing, or copies routing and related lines into a destination routing or version.', MaxLength = 250, Comment = 'is-IS=Reiknar raðir og yfirfer leið eða afritar leið og tengdar línur í áfangaleið eða útgáfu.';

    /// <summary>Reports whether routing operations are available.</summary>
    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    /// <summary>Returns the routing header table used to filter these operations.</summary>
    procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Routing Header");
    end;

    /// <summary>Describes routing check and copy operations.</summary>
    procedure GetDescription() Description: Text[250]
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns search terms for routing operations.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'routing, check routing, calculate routing, copy routing, operation sequence', Comment = 'is-IS=leið, yfirfara leið, reikna leið, afrita leið, raðnúmer aðgerðar';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Explains the effects of checking or copying a routing.</summary>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Check recalculates routing sequences; Copy replaces destination lines, tools, personnel, quality measures, and comments. Certified destinations cannot be overwritten.', Comment = 'is-IS=Check endurreiknar raðir leiðar; Copy skiptir út línum, verkfærum, starfsfólki, gæðamælingum og athugasemdum á áfangaleið. Ekki er hægt að skrifa yfir vottaðar leiðir.';
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
        Subject.Add('description', 'Routing number. For Copy, this is the destination routing number.');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    /// <summary>Describes the destination routing.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        Target.Add(ContractMgt.TargetEntry('subject', 'destination routing number', 'Used when the subject is set.'));
        Target.Add(ContractMgt.TargetEntry('data.routingNo', 'routing number', 'Used when the subject is empty.'));
        exit(true);
    end;

    /// <summary>Describes the parameters used by routing check and copy.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        Parameters.Add(ContractMgt.Parameter('routingNo', 'string', false, 'The routing to check, or the destination routing for Copy. May be supplied as the subject instead.'));
        Parameters.Add(ContractMgt.Parameter('versionCode', 'string', false, 'The routing version to check. Used by Check; omit for the routing header.'));
        Parameters.Add(ContractMgt.Parameter('sourceRoutingNo', 'string', false, 'The source routing to copy from. Required by Copy.'));
        Parameters.Add(ContractMgt.Parameter('sourceVersionCode', 'string', false, 'The source routing version. Used by Copy.'));
        Parameters.Add(ContractMgt.Parameter('destinationVersionCode', 'string', false, 'The destination version. Omit to copy to the routing header.'));
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
        ResponseField.Add('name', 'routingNo');
        ResponseField.Add('type', 'string');
        ResponseField.Add('description', 'The checked or destination routing number.');
        Fields.Add(ResponseField);
        Clear(ResponseField);
        ResponseField.Add('name', 'versionCode');
        ResponseField.Add('type', 'string');
        ResponseField.Add('description', 'The routing version checked or copied to.');
        Fields.Add(ResponseField);
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Describes missing routing and source parameters.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ErrorInfo: JsonObject;
    begin
        ErrorInfo.Add('error', 'Routing not found.');
        ErrorInfo.Add('when', 'The destination or source routing number does not identify an existing routing.');
        ErrorInfo.Add('fix', 'Check routingNo and sourceRoutingNo.');
        Errors.Add(ErrorInfo);
        exit(true);
    end;

    /// <summary>Describes the write effect of routing operations.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Check recalculates route sequences; Copy can replace routing lines and related data.');
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

    /// <summary>Describes the routing maintenance workflow.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Steps: JsonArray;
        WorkflowStep: JsonObject;
    begin
        WorkflowStep.Add('messageType', 'Manufacturing.Routing.Copy then Manufacturing.Routing.Check');
        WorkflowStep.Add('purpose', 'Copy routing data into the destination, then check its operation sequence before certifying it.');
        Steps.Add(WorkflowStep);
        Workflow.Add('steps', Steps);
        exit(true);
    end;

    /// <summary>Provides examples for checking and copying routings.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        RequestData: JsonObject;
        Request: JsonObject;
        Response: JsonObject;
        Example: JsonObject;
    begin
        RequestData.Add('routingNo', 'X-ROUTE-01');
        RequestData.Add('versionCode', 'X-01');
        Request.Add('type', 'Manufacturing.Routing.Check');
        Request.Add('data', RequestData);
        Response.Add('status', 'Success');
        Response.Add('routingNo', 'X-ROUTE-01');
        Response.Add('versionCode', 'X-01');
        Example.Add('title', 'Check a routing version');
        Example.Add('request', Request);
        Example.Add('response', Response);
        Examples.Add(Example);

        Clear(RequestData);
        Clear(Request);
        Clear(Response);
        Clear(Example);
        RequestData.Add('routingNo', 'X-ROUTE-02');
        RequestData.Add('sourceRoutingNo', 'X-ROUTE-01');
        RequestData.Add('sourceVersionCode', 'X-01');
        RequestData.Add('destinationVersionCode', 'X-02');
        Request.Add('type', 'Manufacturing.Routing.Copy');
        Request.Add('data', RequestData);
        Response.Add('status', 'Success');
        Response.Add('routingNo', 'X-ROUTE-02');
        Response.Add('versionCode', 'X-02');
        Example.Add('title', 'Copy a routing version');
        Example.Add('request', Request);
        Example.Add('response', Response);
        Examples.Add(Example);
        exit(true);
    end;

    /// <summary>Explains routing validation and copy.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Check calculates routing sequences and validates operation centers. Copy duplicates routing lines and related routing data to a destination routing or version.';
        exit(true);
    end;

    /// <summary>Documents important behavior of routing check and copy.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Check recalculates sequence and accumulated scrap values and raises an error for invalid routing structure. Copy deletes destination lines and related routing tools, personnel, quality measures, and comments; certified destinations are rejected.';
        exit(true);
    end;

    /// <summary>Returns the inbound message direction.</summary>
    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    trigger OnRun()
    begin
        PerformRoutingAction(Rec);
    end;

    /// <summary>Executes this message type through Bifrost Foundation.</summary>
    /// <param name="Argument">The message argument and response record.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        if Argument."Omit Commit" then begin
            PerformRoutingAction(Argument);
            exit;
        end;

        if not Codeunit.Run(Codeunit::"Mfg Routing Impl ori", Argument) then
            Argument.RespondWithLastError();
    end;

    local procedure PerformRoutingAction(var Argument: Record "Message Argument ori")
    var
        RoutingHeader: Record "Routing Header";
        SourceRoutingHeader: Record "Routing Header";
        CheckRoutingLines: Codeunit "Check Routing Lines";
        RoutingLineCopy: Codeunit "Routing Line-Copy Lines";
        RequestJson: JsonObject;
        RequestToken: JsonToken;
        ResponseJson: JsonObject;
        RoutingNo: Code[20];
        RoutingNoText: Text;
        SourceRoutingNo: Code[20];
        VersionCode: Code[20];
        SourceVersionCode: Code[20];
        DestinationVersionCode: Code[20];
    begin
        RequestJson := Argument.GetRequestJson();
        RoutingNoText := Argument.Subject;
        if RoutingNoText = '' then begin
            if not RequestJson.Get('routingNo', RequestToken) then
                Error(RoutingRequiredErr);
            if not RequestToken.IsValue() then
                Error(RoutingRequiredErr);
            RoutingNoText := RequestToken.AsValue().AsText();
        end;
        if StrLen(RoutingNoText) > MaxStrLen(RoutingNo) then
            Error(RoutingRequiredErr);
        RoutingNo := CopyStr(RoutingNoText, 1, MaxStrLen(RoutingNo));

        RoutingHeader.SetLoadFields("No.", Type, Status);
        if not RoutingHeader.Get(RoutingNo) then
            Error(RoutingNotFoundErr, RoutingNo);

        if Argument.Type = Enum::"Message Type ori"::"Manufacturing.Routing.Copy" then begin
            if not RequestJson.Get('sourceRoutingNo', RequestToken) then
                Error(SourceRoutingRequiredErr);
            if not RequestToken.IsValue() then
                Error(SourceRoutingRequiredErr);
            if StrLen(RequestToken.AsValue().AsText()) > MaxStrLen(SourceRoutingNo) then
                Error(SourceRoutingRequiredErr);
            SourceRoutingNo := CopyStr(RequestToken.AsValue().AsText(), 1, MaxStrLen(SourceRoutingNo));

            SourceRoutingHeader.SetLoadFields("No.");
            if not SourceRoutingHeader.Get(SourceRoutingNo) then
                Error(RoutingNotFoundErr, SourceRoutingNo);

            SourceVersionCode := CopyStr(GetOptionalText(RequestJson, 'sourceVersionCode'), 1, MaxStrLen(SourceVersionCode));
            DestinationVersionCode := CopyStr(GetOptionalText(RequestJson, 'destinationVersionCode'), 1, MaxStrLen(DestinationVersionCode));
            RoutingLineCopy.CopyRouting(SourceRoutingNo, SourceVersionCode, RoutingHeader, DestinationVersionCode);
            VersionCode := DestinationVersionCode;
        end else begin
            VersionCode := CopyStr(GetOptionalText(RequestJson, 'versionCode'), 1, MaxStrLen(VersionCode));
            CheckRoutingLines.Calculate(RoutingHeader, VersionCode);
        end;

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('routingNo', RoutingNo);
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