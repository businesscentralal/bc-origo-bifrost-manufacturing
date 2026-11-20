namespace Origo.Bifrost.Manufacturing;

using Microsoft.Manufacturing.Document;
using Origo.Bifrost;

/// <summary>Executes Manufacturing.ComponentAvailability.Get.</summary>
codeunit 10077048 "Mfg Component Get Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        Contract: Codeunit "Mfg Order Read Contract ori";

    /// <summary>Requires the Manufacturing read token even when native roles grant broad execution.</summary>
    procedure IsEnabled(): Boolean
    var
        Gate: Record "Mfg Write Gate ori";
    begin
        exit(Gate.ReadPermission());
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
        ValueLbl: Label 'Read production order component availability and shortages.', Comment = 'is-IS=Lestu framboð íhluta og skort fyrir framleiðslupöntun.';
    begin
        exit(ValueLbl);
    end;

    /// <summary>Returns localized catalogue keywords.</summary>
    procedure GetKeywords(): Text
    var
        ValueLbl: Label 'Read production order component availability and shortages.', Comment = 'is-IS=Lestu framboð íhluta og skort fyrir framleiðslupöntun.';
    begin
        exit(ValueLbl);
    end;

    /// <summary>Returns localized selection text.</summary>
    procedure GetSelectionDescription(): Text
    var
        ValueLbl: Label 'Read production order component availability and shortages.', Comment = 'is-IS=Lestu framboð íhluta og skort fyrir framleiðslupöntun.';
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
        Contract.GetParameters(true, Parameters);
        exit(true);
    end;

    /// <summary>Returns the response chapter.</summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    begin
        Contract.GetResponse(true, Response);
        exit(true);
    end;

    /// <summary>Returns the errors chapter.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        Contract.GetErrors(true, Errors);
        exit(true);
    end;

    /// <summary>Returns the effect chapter.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Contract.GetEffect(true, Effect);
        exit(true);
    end;

    /// <summary>Returns the related chapter.</summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    begin
        Contract.GetRelated(true, Related);
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
        Contract.GetExamples(true, Examples);
        exit(true);
    end;

    /// <summary>Returns the overview chapter.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Contract.GetOverview(true, Overview);
        exit(true);
    end;

    /// <summary>Returns the notes chapter.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Contract.GetNotes(true, Notes);
        exit(true);
    end;

    /// <summary>Declares no app-specific metering in addition to Foundation.</summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Validates the read request and returns native manufacturing calculations.</summary>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Order: Record "Production Order";
        Request: Codeunit "Mfg Order Read Request ori";
        Calculation: Codeunit "Mfg Order Read Calc ori";
        Result: JsonObject;
        LineNo: Integer;
        LocationCode: Code[10];
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        if not Request.Read(Argument, true, Order, LineNo, LocationCode) then
            exit;
        Result.Add('status', 'Success');
        Result.Add('no', Order."No.");
        Result.Add('systemId', Format(Order.SystemId, 0, 4));
        Calculation.Availability(Order, LineNo, LocationCode, Request.HasLocation(Argument), Result);
        Argument.SetResponseJson(Result);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
