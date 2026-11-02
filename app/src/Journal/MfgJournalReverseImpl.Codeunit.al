namespace Origo.Bifrost.Manufacturing;

using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Manufacturing.Capacity;
using Microsoft.Manufacturing.Journal;
using Origo.Bifrost;

/// <summary>
/// Implements Manufacturing.Journal.ReversePosting using Microsoft's production posting undo routines.
/// </summary>
codeunit 10077047 "Mfg Journal Reverse Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    TableNo = "Message Argument ori";

    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Contract: Codeunit "Mfg Action Contract ori";
        LedgerTypeRequiredErr: Label 'ledgerType must be Item or Capacity.', Comment = 'is-IS=ledgerType verður að vera Item eða Capacity.';
        ItemEntryNotFoundErr: Label 'Production item ledger entry %1 was not found.', Comment = '%1 = item ledger entry number||is-IS=Færslubókarfærsla framleiðsluvöru %1 fannst ekki.';
        CapacityEntryNotFoundErr: Label 'Production capacity ledger entry %1 was not found.', Comment = '%1 = capacity ledger entry number||is-IS=Afkastabókafærsla framleiðslu %1 fannst ekki.';
        ProductionEntryErr: Label 'Only an unreversed production-order posting can be reversed.', Comment = 'is-IS=Aðeins má bakfæra óbakfærða bókun framleiðslupöntunar.';
        OutputAppliedErr: Label 'Only positive production output with its full quantity remaining can be reversed.', Comment = 'is-IS=Aðeins má bakfæra jákvæð framleiðsluafköst þegar allt magnið er enn eftir.';
        DescriptionLbl: Label 'Reverses one posted production item or capacity ledger entry using Microsoft production undo logic.', MaxLength = 250, Comment = 'is-IS=Bakfærir eina bókaða vöru- eða afkastabókafærslu framleiðslu með bakfærslurökfræði Microsoft.';

    /// <summary>Reports whether production posting reversal is available.</summary>
    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    /// <summary>Returns zero because the ledger type selects one of two target tables.</summary>
    procedure GetFilterTableNo() FilterTableId: Integer
    begin
        exit(0);
    end;

    /// <summary>Describes production posting reversal.</summary>
    procedure GetDescription() Description: Text[250]
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Returns search terms for production posting reversal.</summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'production journal, reverse posting, undo output, undo consumption, capacity ledger', Comment = 'is-IS=framleiðslufærslubók, bakfæra bókun, afturkalla afköst, afturkalla notkun, afkastabók';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Warns that the selected posted entry will be reversed.</summary>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Irreversible accounting action. Reverses the selected production item or capacity ledger entry and creates correcting entries.', Comment = 'is-IS=Óafturkræf bókunaraðgerð. Bakfærir valda vöru- eða afkastabókafærslu framleiðslu og stofnar leiðréttingarfærslur.';
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

    /// <summary>Declares no single-table target because ledgerType chooses the table.</summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>Describes the ledger type and entry number parameters.</summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        LedgerTypeParameter: JsonObject;
        AllowedLedgerTypes: JsonArray;
    begin
        AllowedLedgerTypes.Add('Item');
        AllowedLedgerTypes.Add('Capacity');
        LedgerTypeParameter.Add('name', 'ledgerType');
        LedgerTypeParameter.Add('type', 'string');
        LedgerTypeParameter.Add('required', true);
        LedgerTypeParameter.Add('allowed', AllowedLedgerTypes);
        LedgerTypeParameter.Add('description', 'Item reverses a production item ledger entry; Capacity reverses a capacity ledger entry.');
        Parameters.Add(LedgerTypeParameter);
        Parameters.Add(ContractMgt.Parameter('entryNo', 'integer', true, 'The entry number in the selected production ledger.'));
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
        ResponseField.Add('description', 'Success when the ledger entry was reversed.');
        Fields.Add(ResponseField);
        Clear(ResponseField);
        ResponseField.Add('name', 'ledgerType');
        ResponseField.Add('type', 'string');
        ResponseField.Add('description', 'The production ledger reversed.');
        Fields.Add(ResponseField);
        Clear(ResponseField);
        ResponseField.Add('name', 'entryNo');
        ResponseField.Add('type', 'integer');
        ResponseField.Add('description', 'The original ledger entry number.');
        Fields.Add(ResponseField);
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Describes errors returned by the operation.</summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    begin
        Contract.Errors(Errors);
        exit(true);
    end;

    /// <summary>Describes the irreversible accounting effect.</summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    begin
        Effect.Add('effect', 'irreversible');
        Effect.Add('changes', 'Reverses a posted production item or capacity ledger entry and creates correcting entries.');
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

    /// <summary>Describes the production posting reversal workflow.</summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    var
        Steps: JsonArray;
        WorkflowStep: JsonObject;
    begin
        WorkflowStep.Add('messageType', 'Manufacturing.Journal.ReversePosting');
        WorkflowStep.Add('purpose', 'Reverse one production posting only after confirming the original ledger entry and its downstream effects.');
        Steps.Add(WorkflowStep);
        Workflow.Add('steps', Steps);
        exit(true);
    end;

    /// <summary>Provides a representative item-ledger reversal request and response.</summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        RequestData: JsonObject;
        Request: JsonObject;
        Response: JsonObject;
        Example: JsonObject;
    begin
        RequestData.Add('ledgerType', 'Item');
        RequestData.Add('entryNo', 10000);
        Request.Add('type', 'Manufacturing.Journal.ReversePosting');
        Request.Add('data', RequestData);
        Response.Add('status', 'Success');
        Response.Add('ledgerType', 'Item');
        Response.Add('entryNo', 10000);
        Example.Add('title', 'Reverse a production item ledger entry');
        Example.Add('request', Request);
        Example.Add('response', Response);
        Examples.Add(Example);
        exit(true);
    end;

    /// <summary>Explains when to use production posting reversal.</summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Reverses a production item or capacity ledger entry using Microsoft''s Undo Prod. Posting Mgmt. codeunit.';
        exit(true);
    end;

    /// <summary>Documents important behavior of production posting reversal.</summary>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Omit Commit is refused with PreconditionFailed before any write because standard Business Central actions may commit. Reversal writes correcting entries and cannot be repeated as a no-op. Confirm the entry belongs to a production order before calling this message.';
        exit(true);
    end;

    /// <summary>Returns the inbound message direction.</summary>
    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    trigger OnRun()
    begin
        PerformReverse(Rec);
    end;

    /// <summary>Executes this message type through Bifrost Foundation.</summary>
    /// <param name="Argument">The message argument and response record.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        if Argument."Omit Commit" then begin
            PerformReverse(Argument);
            exit;
        end;

        if not Codeunit.Run(Codeunit::"Mfg Journal Reverse Impl ori", Argument) then
            Argument.RespondWithLastError();
    end;

    local procedure PerformReverse(var Argument: Record "Message Argument ori")
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
        ItemJournalLine: Record "Item Journal Line";
        CapacityLedgerEntry: Record "Capacity Ledger Entry";
        UndoProdPosting: Codeunit "Undo Prod. Posting Mgmt.";
        ResponseJson: JsonObject;
        LedgerTypeText: Text;
        EntryNo: Integer;
    begin
        if not Contract.ValidateKeys(Argument, '|ledgerType|entryNo|') then
            exit;
        if not Contract.ReadCode(Argument, 'ledgerType', '', 20, LedgerTypeText) then
            exit;
        LedgerTypeText := UpperCase(LedgerTypeText);
        if not (LedgerTypeText in ['ITEM', 'CAPACITY']) then begin
            Contract.Refuse(Argument, "Bifrost Error Code ori"::InvalidParameter, 'ledgerType', LedgerTypeRequiredErr);
            exit;
        end;
        if not Contract.ReadPositiveInteger(Argument, 'entryNo', EntryNo) then
            exit;
        // Reversal creates a correcting journal. Standard posting enforces its own
        // indirect ledger permissions; callers must not need direct ledger editing.
        case LedgerTypeText of
            'ITEM':
                begin
                    if not Contract.HasPermission(Argument, ItemLedgerEntry.ReadPermission(), ItemJournalLine.WritePermission()) then
                        exit;
                    ItemLedgerEntry.LockTable();
                    if not ItemLedgerEntry.Get(EntryNo) then begin
                        Contract.Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'entryNo', StrSubstNo(ItemEntryNotFoundErr, EntryNo));
                        exit;
                    end;
                    if (ItemLedgerEntry."Order Type" <> ItemLedgerEntry."Order Type"::Production) or
                       (ItemLedgerEntry."Order No." = '') or ItemLedgerEntry.Correction or
                       not (ItemLedgerEntry."Entry Type" in [ItemLedgerEntry."Entry Type"::Consumption, ItemLedgerEntry."Entry Type"::Output])
                    then begin
                        Contract.Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'entryNo', ProductionEntryErr);
                        exit;
                    end;
                    if ItemLedgerEntry."Entry Type" = ItemLedgerEntry."Entry Type"::Output then
                        if (ItemLedgerEntry.Quantity <= 0) or (ItemLedgerEntry."Remaining Quantity" <> ItemLedgerEntry.Quantity) then begin
                            Contract.Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'entryNo', OutputAppliedErr);
                            exit;
                        end;
                    if not Contract.RequireCommittingCall(Argument) then
                        exit;
                    ItemLedgerEntry.SetRecFilter();
                    UndoProdPosting.ReverseProdItemLedgerEntry(ItemLedgerEntry);
                end;
            'CAPACITY':
                begin
                    if not Contract.HasPermission(Argument, CapacityLedgerEntry.ReadPermission(), ItemJournalLine.WritePermission()) then
                        exit;
                    CapacityLedgerEntry.LockTable();
                    if not CapacityLedgerEntry.Get(EntryNo) then begin
                        Contract.Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, 'entryNo', StrSubstNo(CapacityEntryNotFoundErr, EntryNo));
                        exit;
                    end;
                    if (CapacityLedgerEntry."Order Type" <> CapacityLedgerEntry."Order Type"::Production) or
                       (CapacityLedgerEntry."Order No." = '') or CapacityLedgerEntry.Reversed
                    then begin
                        Contract.Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, 'entryNo', ProductionEntryErr);
                        exit;
                    end;
                    if not Contract.RequireCommittingCall(Argument) then
                        exit;
                    CapacityLedgerEntry.SetRecFilter();
                    UndoProdPosting.ReverseCapacityLedgerEntry(CapacityLedgerEntry);
                end;
        end;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('ledgerType', LedgerTypeText);
        ResponseJson.Add('entryNo', EntryNo);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
