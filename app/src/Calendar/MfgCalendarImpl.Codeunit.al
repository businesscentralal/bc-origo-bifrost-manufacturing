namespace Origo.Bifrost.Manufacturing;

using Microsoft.Manufacturing.Capacity;
using Microsoft.Manufacturing.MachineCenter;
using Microsoft.Manufacturing.WorkCenter;
using Origo.Bifrost;

/// <summary>
/// Implements Manufacturing.Calendar.Recalculate using Microsoft's Recalculate Calendar report.
/// </summary>
codeunit 10077052 "Mfg Calendar Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    TableNo = "Message Argument ori";

    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        CapacityTypeRequiredErr: Label 'capacityType must be WorkCenter or MachineCenter.', Comment = 'is-IS=capacityType verður að vera WorkCenter eða MachineCenter.';
        CapacityNoRequiredErr: Label 'Provide a capacityNo.', Comment = 'is-IS=Tilgreindu capacityNo.';
        InvalidDateRangeErr: Label 'Provide valid startingDate and endingDate values in YYYY-MM-DD format, with endingDate on or after startingDate.', Comment = 'is-IS=Tilgreindu gild startingDate og endingDate á sniðinu ÁÁÁÁ-MM-DD, þar sem endingDate er sama dagsetning eða seinna en startingDate.';
        CapacityCenterNotFoundErr: Label 'The %1 %2 does not exist.', Comment = '%1 = capacity type, %2 = capacity center number||is-IS=%1 %2 er ekki til.';
        WorkCenterTypeTok: Label 'WORKCENTER', Locked = true;
        MachineCenterTypeTok: Label 'MACHINECENTER', Locked = true;
        DescriptionLbl: Label 'Recalculates shop-calendar entries for one work center or machine center over a selected date range.', MaxLength = 250, Comment = 'is-IS=Endurreiknar dagatalsfærslur fyrir eina vinnustöð eða vél yfir valið tímabil.';

    /// <summary>Reports whether calendar recalculation is available.</summary>
    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    /// <summary>Returns the calendar entry table used by this operation.</summary>
    procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(Database::"Calendar Entry");
    end;

    /// <summary>Describes the calendar recalculation operation.</summary>
    procedure GetDescription() Description: Text[250]
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns search terms for calendar recalculation.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'shop calendar, capacity calendar, recalculate calendar, work center, machine center, absence', Comment = 'is-IS=verslunardagatal, afkastadagatal, endurreikna dagatal, vinnustöð, vél, fjarvera';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Explains the operation's data-changing effect when a caller selects it.</summary>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Recalculates calendar capacity and processes pending absence entries for the selected center and dates.', Comment = 'is-IS=Endurreiknar dagatalsafkast og vinnur úr biðfærslum fjarvista fyrir valda miðstöð og dagsetningar.';
    begin
        exit(SelectionLbl);
    end;

    /// <summary>Describes the request envelope.</summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
    begin
        Subject.Add('use', 'notUsed');
        Subject.Add('description', 'The subject is not used. Pass the center and date range in data.');
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    /// <summary>Declares no single-record target; the request filters a center and date range.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>Describes the center and date-range parameters.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        CapacityTypeParameter: JsonObject;
        AllowedCapacityTypes: JsonArray;
        StartingDateParameter: JsonObject;
        EndingDateParameter: JsonObject;
    begin
        AllowedCapacityTypes.Add('WorkCenter');
        AllowedCapacityTypes.Add('MachineCenter');
        CapacityTypeParameter.Add('name', 'capacityType');
        CapacityTypeParameter.Add('type', 'string');
        CapacityTypeParameter.Add('required', true);
        CapacityTypeParameter.Add('allowed', AllowedCapacityTypes);
        CapacityTypeParameter.Add('description', 'WorkCenter or MachineCenter.');
        Parameters.Add(CapacityTypeParameter);
        Parameters.Add(ContractMgt.Parameter('capacityNo', 'string', true, 'The work center or machine center number.'));
        StartingDateParameter.Add('name', 'startingDate');
        StartingDateParameter.Add('type', 'string');
        StartingDateParameter.Add('format', 'date');
        StartingDateParameter.Add('required', true);
        StartingDateParameter.Add('description', 'First calendar date to recalculate, in YYYY-MM-DD format.');
        Parameters.Add(StartingDateParameter);
        EndingDateParameter.Add('name', 'endingDate');
        EndingDateParameter.Add('type', 'string');
        EndingDateParameter.Add('format', 'date');
        EndingDateParameter.Add('required', true);
        EndingDateParameter.Add('description', 'Last calendar date to recalculate, in YYYY-MM-DD format.');
        Parameters.Add(EndingDateParameter);
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
        ResponseField.Add('description', 'Success when the calendar was recalculated.');
        Fields.Add(ResponseField);
        Clear(ResponseField);
        ResponseField.Add('name', 'capacityType');
        ResponseField.Add('type', 'string');
        ResponseField.Add('description', 'The center type recalculated.');
        Fields.Add(ResponseField);
        Clear(ResponseField);
        ResponseField.Add('name', 'capacityNo');
        ResponseField.Add('type', 'string');
        ResponseField.Add('description', 'The center recalculated.');
        Fields.Add(ResponseField);
        Clear(ResponseField);
        ResponseField.Add('name', 'calendarEntriesAfter');
        ResponseField.Add('type', 'integer');
        ResponseField.Add('description', 'Calendar entry count after recalculation.');
        Fields.Add(ResponseField);
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Describes input and center errors.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ErrorInfo: JsonObject;
    begin
        ErrorInfo.Add('error', 'Invalid calendar request.');
        ErrorInfo.Add('when', 'The capacity type, center, or date range is missing or invalid.');
        ErrorInfo.Add('fix', 'Pass a valid center and an inclusive YYYY-MM-DD date range.');
        Errors.Add(ErrorInfo);
        exit(true);
    end;

    /// <summary>Describes the calendar data changed by the operation.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Recalculates calendar entries and applies pending absence entries for the selected capacity center and dates.');
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

    /// <summary>Describes calendar recalculation.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Steps: JsonArray;
        WorkflowStep: JsonObject;
    begin
        WorkflowStep.Add('messageType', 'Manufacturing.Calendar.Recalculate');
        WorkflowStep.Add('purpose', 'Rebuild capacity calendar entries and apply pending absences for a center and date range.');
        Steps.Add(WorkflowStep);
        Workflow.Add('steps', Steps);
        exit(true);
    end;

    /// <summary>Provides a representative work-center calendar request and response.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        RequestData: JsonObject;
        Request: JsonObject;
        Response: JsonObject;
        Example: JsonObject;
    begin
        RequestData.Add('capacityType', 'WorkCenter');
        RequestData.Add('capacityNo', 'X-WC-01');
        RequestData.Add('startingDate', '2026-10-01');
        RequestData.Add('endingDate', '2026-10-31');
        Request.Add('type', 'Manufacturing.Calendar.Recalculate');
        Request.Add('data', RequestData);
        Response.Add('status', 'Success');
        Response.Add('capacityType', 'WorkCenter');
        Response.Add('capacityNo', 'X-WC-01');
        Response.Add('calendarEntriesAfter', 22);
        Example.Add('title', 'Recalculate a work-center calendar');
        Example.Add('request', Request);
        Example.Add('response', Response);
        Examples.Add(Example);
        exit(true);
    end;

    /// <summary>Explains when to use calendar recalculation.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Recalculates Calendar Entry records for one work or machine center over an inclusive date range using Microsoft''s Recalculate Calendar report.';
        exit(true);
    end;

    /// <summary>Documents important behavior of calendar recalculation.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'The report request page is not shown. Pending Calendar Absence Entry records are applied for the selected center and dates.';
        exit(true);
    end;

    /// <summary>Returns the inbound message direction.</summary>
    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    trigger OnRun()
    begin
        PerformRecalculate(Rec);
    end;

    /// <summary>Executes this message type through Bifrost Foundation.</summary>
    /// <param name="Argument">The message argument and response record.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        if Argument."Omit Commit" then begin
            PerformRecalculate(Argument);
            exit;
        end;

        if not Codeunit.Run(Codeunit::"Mfg Calendar Impl ori", Argument) then
            Argument.RespondWithLastError();
    end;

    local procedure PerformRecalculate(var Argument: Record "Message Argument ori")
    var
        CalendarEntry: Record "Calendar Entry";
        WorkCenter: Record "Work Center";
        MachineCenter: Record "Machine Center";
        RecalculateCalendar: Report "Recalculate Calendar";
        RequestJson: JsonObject;
        RequestToken: JsonToken;
        ResponseJson: JsonObject;
        CapacityType: Enum "Capacity Type";
        CapacityTypeText: Text;
        CapacityNo: Code[20];
        CapacityNoText: Text;
        StartingDateText: Text;
        EndingDateText: Text;
        StartingDate: Date;
        EndingDate: Date;
        CalendarEntriesAfter: Integer;
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

        if not RequestJson.Get('startingDate', RequestToken) then
            Error(InvalidDateRangeErr);
        StartingDateText := RequestToken.AsValue().AsText();
        if not Evaluate(StartingDate, StartingDateText, 9) then
            Error(InvalidDateRangeErr);
        if not RequestJson.Get('endingDate', RequestToken) then
            Error(InvalidDateRangeErr);
        EndingDateText := RequestToken.AsValue().AsText();
        if not Evaluate(EndingDate, EndingDateText, 9) then
            Error(InvalidDateRangeErr);
        if (StartingDate = 0D) or (EndingDate = 0D) or (EndingDate < StartingDate) then
            Error(InvalidDateRangeErr);

        case CapacityType of
            CapacityType::"Work Center":
                begin
                    WorkCenter.SetLoadFields("No.");
                    if not WorkCenter.Get(CapacityNo) then
                        Error(CapacityCenterNotFoundErr, 'Work Center', CapacityNo);
                    CapacityTypeName := 'WorkCenter';
                end;
            CapacityType::"Machine Center":
                begin
                    MachineCenter.SetLoadFields("No.");
                    if not MachineCenter.Get(CapacityNo) then
                        Error(CapacityCenterNotFoundErr, 'Machine Center', CapacityNo);
                    CapacityTypeName := 'MachineCenter';
                end;
        end;

        CalendarEntry.SetLoadFields("Capacity Type", "No.", Date, "Starting Time", "Ending Time", "Work Shift Code");
        CalendarEntry.SetRange("Capacity Type", CapacityType);
        CalendarEntry.SetRange("No.", CapacityNo);
        CalendarEntry.SetRange(Date, StartingDate, EndingDate);
        RecalculateCalendar.SetTableView(CalendarEntry);
        RecalculateCalendar.RunModal();

        CalendarEntry.Reset();
        CalendarEntry.SetLoadFields("Capacity Type", "No.", Date, "Starting Time", "Ending Time", "Work Shift Code");
        CalendarEntry.SetRange("Capacity Type", CapacityType);
        CalendarEntry.SetRange("No.", CapacityNo);
        CalendarEntry.SetRange(Date, StartingDate, EndingDate);
        CalendarEntriesAfter := CalendarEntry.Count();

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('capacityType', CapacityTypeName);
        ResponseJson.Add('capacityNo', CapacityNo);
        ResponseJson.Add('calendarEntriesAfter', CalendarEntriesAfter);
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