namespace Origo.Bifrost.Manufacturing;

using Microsoft.Manufacturing.Document;
using Microsoft.Warehouse.Activity;
using Origo.Bifrost;

/// <summary>
/// Implements production warehouse pick and put-away messages using Microsoft's manufacturing warehouse actions.
/// </summary>
codeunit 10077057 "Mfg Warehouse Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    TableNo = "Message Argument ori";

    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        ProductionOrderRequiredErr: Label 'Provide a released production order number in the subject or data.productionOrderNo.', Comment = 'is-IS=Tilgreindu númer útgefinnar framleiðslupöntunar í subject eða data.productionOrderNo.';
        ProductionOrderNotFoundErr: Label 'Released production order %1 was not found.', Comment = '%1 = production order number||is-IS=Útgefin framleiðslupöntun %1 fannst ekki.';
        DescriptionLbl: Label 'Creates production component warehouse picks or output put-away activities for one released production order.', MaxLength = 250, Comment = 'is-IS=Stofnar vöruafhendingarval eða frágangsaðgerðir fyrir afköst einnar útgefinnar framleiðslupöntunar.';

    /// <summary>Reports whether production warehouse actions are available.</summary>
    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    /// <summary>Returns the production order table used to filter these actions.</summary>
    procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Production Order");
    end;

    /// <summary>Describes production warehouse pick and put-away actions.</summary>
    procedure GetDescription() Description: Text[250]
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns search terms for production warehouse actions.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'production warehouse, create pick, create put-away, production components, output', Comment = 'is-IS=framleiðsluvöruhús, stofna tínslu, stofna frágang, framleiðsluíhlutir, afköst';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Explains the operation's data-changing effect when a caller selects it.</summary>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Creates warehouse activities for eligible components or output lines in one released production order. Review created activities before registration.', Comment = 'is-IS=Stofnar vöruhúsaðgerðir fyrir viðeigandi íhluti eða afkastalínur í einni útgefinni framleiðslupöntun. Farðu yfir aðgerðirnar áður en þær eru skráðar.';
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
        Subject.Add('description', 'Released production order number. When set, it takes precedence over data.productionOrderNo.');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    /// <summary>Describes the production order target.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        Target.Add(ContractMgt.TargetEntry('subject', 'production order number', 'Used when the subject is set.'));
        Target.Add(ContractMgt.TargetEntry('data.productionOrderNo', 'production order number', 'Used when the subject is empty.'));
        exit(true);
    end;

    /// <summary>Describes the production order parameter.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    begin
        Parameters.Add(ContractMgt.Parameter('productionOrderNo', 'string', true, 'Released production order to process. May be supplied as the subject instead.'));
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
        ResponseField.Add('description', 'Success when warehouse activities were created.');
        Fields.Add(ResponseField);
        Clear(ResponseField);
        ResponseField.Add('name', 'productionOrderNo');
        ResponseField.Add('type', 'string');
        ResponseField.Add('description', 'The production order processed.');
        Fields.Add(ResponseField);
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Describes missing production order errors.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ErrorInfo: JsonObject;
    begin
        ErrorInfo.Add('error', 'Released production order not found.');
        ErrorInfo.Add('when', 'The supplied number does not identify a released production order.');
        ErrorInfo.Add('fix', 'Check productionOrderNo and ensure the order is released.');
        Errors.Add(ErrorInfo);
        exit(true);
    end;

    /// <summary>Describes the warehouse data changed by the operation.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Creates warehouse pick or put-away activity records for eligible production order lines.');
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

    /// <summary>Describes production order warehouse handling.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Steps: JsonArray;
        WorkflowStep: JsonObject;
    begin
        WorkflowStep.Add('messageType', 'Manufacturing.Warehouse.CreatePick or Manufacturing.Warehouse.CreatePutAway');
        WorkflowStep.Add('purpose', 'Create warehouse activities for eligible production components or completed output.');
        Steps.Add(WorkflowStep);
        Workflow.Add('steps', Steps);
        exit(true);
    end;

    /// <summary>Provides an example production warehouse pick request.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        Request: JsonObject;
        Response: JsonObject;
        Example: JsonObject;
    begin
        Request.Add('type', 'Manufacturing.Warehouse.CreatePick');
        Request.Add('subject', 'X-PROD-0001');
        Response.Add('status', 'Success');
        Response.Add('productionOrderNo', 'X-PROD-0001');
        Example.Add('title', 'Create a production component pick');
        Example.Add('request', Request);
        Example.Add('response', Response);
        Examples.Add(Example);
        exit(true);
    end;

    /// <summary>Explains production warehouse pick and put-away actions.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'CreatePick generates warehouse picks for eligible production components. CreatePutAway generates put-away activities for production output lines.';
        exit(true);
    end;

    /// <summary>Documents important behavior of production warehouse actions.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'The order must be released. CreatePick suppresses the request page and uses Microsoft defaults; CreatePutAway only creates activities for lines and locations that require warehouse put-away.';
        exit(true);
    end;

    /// <summary>Returns the inbound message direction.</summary>
    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    trigger OnRun()
    begin
        PerformWarehouseAction(Rec);
    end;

    /// <summary>Executes this message type through Bifrost Foundation.</summary>
    /// <param name="Argument">The message argument and response record.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        if Argument."Omit Commit" then begin
            PerformWarehouseAction(Argument);
            exit;
        end;

        if not Codeunit.Run(Codeunit::"Mfg Warehouse Impl ori", Argument) then
            Argument.RespondWithLastError();
    end;

    local procedure PerformWarehouseAction(var Argument: Record "Message Argument ori")
    var
        ProductionOrder: Record "Production Order";
        ProdOrderLine: Record "Prod. Order Line";
        CreatePutAway: Codeunit "Mfg. Create Put-away";
        RequestJson: JsonObject;
        RequestToken: JsonToken;
        ResponseJson: JsonObject;
        ProductionOrderNoText: Text;
        ProductionOrderNo: Code[20];
    begin
        RequestJson := Argument.GetRequestJson();
        ProductionOrderNoText := Argument.Subject;
        if ProductionOrderNoText = '' then begin
            if not RequestJson.Get('productionOrderNo', RequestToken) then
                Error(ProductionOrderRequiredErr);
            if not RequestToken.IsValue() then
                Error(ProductionOrderRequiredErr);
            ProductionOrderNoText := RequestToken.AsValue().AsText();
        end;
        if StrLen(ProductionOrderNoText) > MaxStrLen(ProductionOrderNo) then
            Error(ProductionOrderRequiredErr);
        ProductionOrderNo := CopyStr(ProductionOrderNoText, 1, MaxStrLen(ProductionOrderNo));

        if not ProductionOrder.Get(ProductionOrder.Status::Released, ProductionOrderNo) then
            Error(ProductionOrderNotFoundErr, ProductionOrderNo);

        if Argument.Type = Enum::"Message Type ori"::"Manufacturing.Warehouse.CreatePick" then begin
            ProductionOrder.SetHideValidationDialog(true);
            ProductionOrder.CreatePick(CopyStr(UserId(), 1, 50), 0, false, false, false);
        end else begin
            ProdOrderLine.SetLoadFields(Status, "Prod. Order No.", "Line No.");
            ProdOrderLine.SetRange(Status, ProdOrderLine.Status::Released);
            ProdOrderLine.SetRange("Prod. Order No.", ProductionOrderNo);
            if ProdOrderLine.FindSet() then
                repeat
                    CreatePutAway.CreateWhsePutAwayForProdOrderOutputLine(ProdOrderLine);
                until ProdOrderLine.Next() = 0;
        end;

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('productionOrderNo', ProductionOrderNo);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}