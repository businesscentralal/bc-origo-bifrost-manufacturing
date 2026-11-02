namespace Origo.Bifrost.Manufacturing;

using Microsoft.Manufacturing.Capacity;
using Origo.Bifrost;

/// <summary>
/// Implements calendar absence application and removal using Microsoft's Calendar Absence Management codeunit.
/// </summary>
codeunit 10077053 "Mfg Absence Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    TableNo = "Message Argument ori";

    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        CapacityTypeRequiredErr: Label 'capacityType must be WorkCenter or MachineCenter.', Comment = 'is-IS=capacityType verður að vera WorkCenter eða MachineCenter.';
        CapacityNoRequiredErr: Label 'Provide a capacityNo.', Comment = 'is-IS=Tilgreindu capacityNo.';
        InvalidAbsenceKeyErr: Label 'Provide a valid absenceDate, startingTime, and endingTime.', Comment = 'is-IS=Tilgreindu gilda absenceDate, startingTime og endingTime.';
        AbsenceNotFoundErr: Label 'No calendar absence entry exists for center %1 on %2.', Comment = '%1 = capacity center number, %2 = absence date||is-IS=Engin fjarvistarfærsla er til fyrir miðstöð %1 þann %2.';
        WorkCenterTypeTok: Label 'WORKCENTER', Locked = true;
        MachineCenterTypeTok: Label 'MACHINECENTER', Locked = true;
        DescriptionLbl: Label 'Applies or removes an existing Calendar Absence Entry from capacity calendar records for a work center or machine center.', MaxLength = 250, Comment = 'is-IS=Beitir eða fjarlægir fyrirliggjandi Calendar Absence Entry úr afkastadagatal vinnustöðvar eða vélar.';

    /// <summary>Reports whether calendar absence processing is available.</summary>
    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    /// <summary>Returns the calendar absence table used to filter this operation.</summary>
    procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Calendar Absence Entry");
    end;

    /// <summary>Describes the calendar absence application operation.</summary>
    procedure GetDescription() Description: Text[250]
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns search terms for calendar absence application.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'calendar absence, work center absence, machine center absence, update absence, remove absence, capacity', Comment = 'is-IS=dagatalsfjarvist, fjarvist vinnustöðvar, fjarvist vélar, uppfæra fjarvist, fjarlægja fjarvist, afkastageta';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Explains the operation's data-changing effect when a caller selects it.</summary>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Applies or removes the selected absence interval from calendar capacity. The Calendar Absence Entry must already exist.', Comment = 'is-IS=Beitir valda fjarvistartímabilinu á dagatalsafköst eða fjarlægir það. Calendar Absence Entry verður að vera til.';
    begin
        exit(SelectionLbl);
    end;

    /// <summary>Describes the request envelope.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
    begin
        Subject.Add('use', 'notUsed');
        Subject.Add('description', 'The subject is not used.');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    /// <summary>Declares no single-record target because the key spans center and time fields.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>Describes the absence entry key parameters.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        AllowedCapacityTypes: JsonArray;
        CapacityTypeParameter: JsonObject;
        AbsenceDateParameter: JsonObject;
        StartingTimeParameter: JsonObject;
        EndingTimeParameter: JsonObject;
    begin
        AllowedCapacityTypes.Add('WorkCenter');
        AllowedCapacityTypes.Add('MachineCenter');
        CapacityTypeParameter.Add('name', 'capacityType');
        CapacityTypeParameter.Add('type', 'string');
        CapacityTypeParameter.Add('required', true);
        CapacityTypeParameter.Add('allowed', AllowedCapacityTypes);
        CapacityTypeParameter.Add('description', 'The type of capacity center.');
        Parameters.Add(CapacityTypeParameter);
        Parameters.Add(ContractMgt.Parameter('capacityNo', 'string', true, 'The work center or machine center number.'));
        AbsenceDateParameter.Add('name', 'absenceDate');
        AbsenceDateParameter.Add('type', 'string');
        AbsenceDateParameter.Add('format', 'date');
        AbsenceDateParameter.Add('required', true);
        AbsenceDateParameter.Add('description', 'The absence date in YYYY-MM-DD format.');
        Parameters.Add(AbsenceDateParameter);
        StartingTimeParameter.Add('name', 'startingTime');
        StartingTimeParameter.Add('type', 'string');
        StartingTimeParameter.Add('format', 'time');
        StartingTimeParameter.Add('required', true);
        StartingTimeParameter.Add('description', 'The absence start time.');
        Parameters.Add(StartingTimeParameter);
        EndingTimeParameter.Add('name', 'endingTime');
        EndingTimeParameter.Add('type', 'string');
        EndingTimeParameter.Add('format', 'time');
        EndingTimeParameter.Add('required', true);
        EndingTimeParameter.Add('description', 'The absence end time.');
        Parameters.Add(EndingTimeParameter);
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
        ResponseField.Add('description', 'Success when the absence interval was applied.');
        Fields.Add(ResponseField);
        Clear(ResponseField);
        ResponseField.Add('name', 'capacityNo');
        ResponseField.Add('type', 'string');
        ResponseField.Add('description', 'The capacity center updated.');
        Fields.Add(ResponseField);
        Clear(ResponseField);
        ResponseField.Add('name', 'absenceDate');
        ResponseField.Add('type', 'string');
        ResponseField.Add('description', 'The absence date applied.');
        Fields.Add(ResponseField);
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Describes errors returned by the operation.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ErrorInfo: JsonObject;
    begin
        ErrorInfo.Add('error', 'Calendar absence entry not found.');
        ErrorInfo.Add('when', 'The supplied center and time interval do not identify an existing Calendar Absence Entry.');
        ErrorInfo.Add('fix', 'Check capacityType, capacityNo, absenceDate, startingTime, and endingTime.');
        Errors.Add(ErrorInfo);
        exit(true);
    end;

    /// <summary>Describes the data changed by the operation.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Applies or removes the selected absence interval from calendar capacity.');
        Effect.Add('idempotent', true);
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

    /// <summary>Describes the calendar absence workflow.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Steps: JsonArray;
        WorkflowStep: JsonObject;
    begin
        WorkflowStep.Add('messageType', 'Manufacturing.Calendar.UpdateAbsence or Manufacturing.Calendar.RemoveAbsence');
        WorkflowStep.Add('purpose', 'Apply or remove a previously created absence entry, or recalculate the affected calendar date range.');
        Steps.Add(WorkflowStep);
        Workflow.Add('steps', Steps);
        exit(true);
    end;

    /// <summary>Provides a representative calendar absence request and response.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        RequestData: JsonObject;
        Request: JsonObject;
        Response: JsonObject;
        Example: JsonObject;
    begin
        RequestData.Add('capacityType', 'WorkCenter');
        RequestData.Add('capacityNo', 'X-WC-01');
        RequestData.Add('absenceDate', '2026-10-31');
        RequestData.Add('startingTime', '12:00:00');
        RequestData.Add('endingTime', '16:00:00');
        Request.Add('type', 'Manufacturing.Calendar.UpdateAbsence');
        Request.Add('data', RequestData);
        Response.Add('status', 'Success');
        Response.Add('capacityNo', 'X-WC-01');
        Response.Add('absenceDate', '2026-10-31');
        Example.Add('title', 'Apply a work-center absence');
        Example.Add('request', Request);
        Example.Add('response', Response);
        Examples.Add(Example);
        exit(true);
    end;

    /// <summary>Explains when to use calendar absence application.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Applies or removes an existing Calendar Absence Entry from the matching work-center or machine-center calendar interval.';
        exit(true);
    end;

    /// <summary>Documents important behavior of absence application.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'The Calendar Absence Entry must already exist. RemoveAbsence keeps the entry but removes its effect from capacity calendar rows. Recalculate Calendar also applies pending absence entries for the selected capacity center and date range.';
        exit(true);
    end;

    /// <summary>Returns the inbound message direction.</summary>
    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    trigger OnRun()
    begin
        PerformUpdateAbsence(Rec);
    end;

    /// <summary>Executes this message type through Bifrost Foundation.</summary>
    /// <param name="Argument">The message argument and response record.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        if Argument."Omit Commit" then begin
            PerformUpdateAbsence(Argument);
            exit;
        end;

        if not Codeunit.Run(Codeunit::"Mfg Absence Impl ori", Argument) then
            Argument.RespondWithLastError();
    end;

    local procedure PerformUpdateAbsence(var Argument: Record "Message Argument ori")
    var
        CalendarAbsenceEntry: Record "Calendar Absence Entry";
        CalendarAbsenceManagement: Codeunit "Calendar Absence Management";
        RequestJson: JsonObject;
        RequestToken: JsonToken;
        ResponseJson: JsonObject;
        CapacityType: Enum "Capacity Type";
        CapacityTypeText: Text;
        CapacityNo: Code[20];
        CapacityNoText: Text;
        AbsenceDateText: Text;
        StartingTimeText: Text;
        EndingTimeText: Text;
        AbsenceDate: Date;
        StartingTime: Time;
        EndingTime: Time;
        CapacityTypeName: Text;
    begin
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('capacityType', RequestToken) then
            Error(CapacityTypeRequiredErr);
        if not RequestToken.IsValue() then
            Error(CapacityTypeRequiredErr);
        CapacityTypeText := UpperCase(RequestToken.AsValue().AsText());
        CapacityType := ParseCapacityType(CapacityTypeText);

        if not RequestJson.Get('capacityNo', RequestToken) then
            Error(CapacityNoRequiredErr);
        if not RequestToken.IsValue() then
            Error(CapacityNoRequiredErr);
        CapacityNoText := RequestToken.AsValue().AsText();
        if StrLen(CapacityNoText) > MaxStrLen(CapacityNo) then
            Error(CapacityNoRequiredErr);
        CapacityNo := CopyStr(CapacityNoText, 1, MaxStrLen(CapacityNo));

        if not RequestJson.Get('absenceDate', RequestToken) then
            Error(InvalidAbsenceKeyErr);
        AbsenceDateText := RequestToken.AsValue().AsText();
        if not Evaluate(AbsenceDate, AbsenceDateText, 9) then
            Error(InvalidAbsenceKeyErr);
        if not RequestJson.Get('startingTime', RequestToken) then
            Error(InvalidAbsenceKeyErr);
        StartingTimeText := RequestToken.AsValue().AsText();
        if not Evaluate(StartingTime, StartingTimeText, 9) then
            Error(InvalidAbsenceKeyErr);
        if not RequestJson.Get('endingTime', RequestToken) then
            Error(InvalidAbsenceKeyErr);
        EndingTimeText := RequestToken.AsValue().AsText();
        if not Evaluate(EndingTime, EndingTimeText, 9) then
            Error(InvalidAbsenceKeyErr);
        if (AbsenceDate = 0D) or (EndingTime <= StartingTime) then
            Error(InvalidAbsenceKeyErr);

        CalendarAbsenceEntry.SetLoadFields();
        if not CalendarAbsenceEntry.Get(CapacityType, CapacityNo, AbsenceDate, StartingTime, EndingTime) then
            Error(AbsenceNotFoundErr, CapacityNo, Format(AbsenceDate, 0, 9));
        if Argument.Type = Enum::"Message Type ori"::"Manufacturing.Calendar.RemoveAbsence" then
            CalendarAbsenceManagement.RemoveAbsence(CalendarAbsenceEntry)
        else
            CalendarAbsenceManagement.UpdateAbsence(CalendarAbsenceEntry);

        case CapacityType of
            CapacityType::"Work Center":
                CapacityTypeName := 'WorkCenter';
            CapacityType::"Machine Center":
                CapacityTypeName := 'MachineCenter';
        end;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('capacityType', CapacityTypeName);
        ResponseJson.Add('capacityNo', CapacityNo);
        ResponseJson.Add('absenceDate', Format(AbsenceDate, 0, 9));
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure ParseCapacityType(CapacityTypeText: Text): Enum "Capacity Type"
    begin
        case CapacityTypeText of
            WorkCenterTypeTok:
                exit(Enum::"Capacity Type"::"Work Center");
            MachineCenterTypeTok:
                exit(Enum::"Capacity Type"::"Machine Center");
            else
                Error(CapacityTypeRequiredErr);
        end;
    end;
}