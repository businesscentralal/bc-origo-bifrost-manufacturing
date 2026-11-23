namespace Origo.Bifrost.Manufacturing;

using Microsoft.Inventory.Ledger;
using Microsoft.Manufacturing.Capacity;
using Microsoft.Manufacturing.Document;
using Origo.Bifrost;

/// <summary>Validates reversal identity, whole-entry lists and mandatory confirmation without writes.</summary>
codeunit 10077110 "Mfg Reverse Plan ori"
{
    Access = Internal;

    var
        InvalidLbl: Label 'The reversal request has an invalid parameter.', Comment = 'is-IS=Ógild færibreyta er í bakfærslubeiðninni.';
        CorrectLbl: Label 'Use describe_message_type, supply the order and arrays of unique positive integer entry numbers.', Comment = 'is-IS=Notaðu describe_message_type og sendu pöntunina og fylki með einkvæmum jákvæðum heiltölum fyrir færslunúmer.';
        MissingLbl: Label 'Supply a production order and at least one ledger entry.', Comment = 'is-IS=Sendu framleiðslupöntun og að minnsta kosti eina fjárhagsfærslu.';
        NotFoundLbl: Label 'The production order or selected ledger entry does not exist.', Comment = 'is-IS=Framleiðslupöntunin eða valin fjárhagsfærsla er ekki til.';
        ReadLbl: Label 'Read the production order and its ledger entries with Data.Records.Get, then retry.', Comment = 'is-IS=Lestu framleiðslupöntunina og færslur hennar með Data.Records.Get og reyndu aftur.';
        ConflictLbl: Label 'The supplied identifiers name different production orders.', Comment = 'is-IS=Send auðkenni vísa á ólíkar framleiðslupantanir.';
        StateLbl: Label 'Only a Released production order can be corrected.', Comment = 'is-IS=Aðeins er hægt að leiðrétta útgefna framleiðslupöntun.';
        ReopenLbl: Label 'Use Manufacturing.ProductionOrder.Reopen for a Finished order, or release the order before retrying.', Comment = 'is-IS=Notaðu Manufacturing.ProductionOrder.Reopen fyrir lokna pöntun eða gefðu pöntunina út áður en þú reynir aftur.';
        CountLbl: Label 'Confirm the number of selected ledger entries with expectedCount.', Comment = 'is-IS=Staðfestu fjölda valinna fjárhagsfærslna með expectedCount.';
        CountNextLbl: Label 'Send the same request with expectedCount equal to %1.', Comment = '%1 = selected entry count, is-IS=Sendu sömu beiðni með expectedCount jafnt og %1.';
        NativeNextLbl: Label 'Correct the condition named by Business Central and retry. For a last operation, reverse its output item entry; for a Finished order use Manufacturing.ProductionOrder.Reopen. Nothing was changed.', Comment = 'is-IS=Leiðréttu skilyrðið sem Business Central nefnir og reyndu aftur. Fyrir síðustu aðgerð skaltu bakfæra afkastafærslu vörunnar; fyrir lokna pöntun skaltu nota Manufacturing.ProductionOrder.Reopen. Engu var breytt.';

    /// <summary>Reads both entry lists, checks permissions and resolves agreeing order identifiers.</summary>
    internal procedure Prepare(var Argument: Record "Message Argument ori"; var Order: Record "Production Order"; var Items: List of [Integer]; var Capacity: List of [Integer]): Boolean
    var
        Gate: Record "Mfg Write Gate ori";
        PostingGate: Codeunit "Mfg Posting Gate ori";
        Request: JsonObject;
        KeyName: Text;
        Number: Text;
        Alias: Text;
        IdText: Text;
        Id: Guid;
        IsOutput: Boolean;
        DeniedLbl: Label 'Manufacturing write permission is required.', Comment = 'is-IS=Skrifheimild fyrir framleiðslu er áskilin.';
        DeniedNextLbl: Label 'Ask an administrator for BIFROST Mfg ori and BIFROST MfgPost ori.', Comment = 'is-IS=Biddu stjórnanda um BIFROST Mfg ori og BIFROST MfgPost ori.';
    begin
        Clear(Items);
        Clear(Capacity);
        if not Gate.WritePermission() then
            exit(Fail(Argument, "Bifrost Error Code ori"::PermissionDenied, DeniedLbl, '', DeniedNextLbl));
        if not PostingGate.AssertCanPost(Argument) then
            exit(false);
        IsOutput := Argument.Type = "Message Type ori"::"Manufacturing.Output.Reverse";
        Request := Argument.GetRequestJson();
        foreach KeyName in Request.Keys() do
            if not 'prodOrderNo|no|systemId|itemLedgerEntryNos|expectedCount'.Split('|').Contains(KeyName) then
                if (KeyName <> 'capacityLedgerEntryNos') or not IsOutput then
                    exit(Fail(Argument, "Bifrost Error Code ori"::UnknownParameter, InvalidLbl, KeyName, CorrectLbl));
        if not ReadIdentifier(Argument, Request, 'prodOrderNo', 20, Number) then
            exit(false);
        if not ReadIdentifier(Argument, Request, 'no', 20, Alias) then
            exit(false);
        if not ReadIdentifier(Argument, Request, 'systemId', 50, IdText) then
            exit(false);
        if (Number <> '') and (Alias <> '') and (UpperCase(Number) <> UpperCase(Alias)) then
            exit(Fail(Argument, "Bifrost Error Code ori"::ConflictingIdentifiers, ConflictLbl, 'prodOrderNo/no', ReadLbl));
        if Number = '' then
            Number := Alias;
        if (Number = '') and (IdText = '') then
            exit(Fail(Argument, "Bifrost Error Code ori"::MissingParameter, MissingLbl, 'prodOrderNo', CorrectLbl));
        if IdText <> '' then begin
            if not Evaluate(Id, IdText) or IsNullGuid(Id) then
                exit(Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, InvalidLbl, 'systemId', CorrectLbl));
            if not Order.GetBySystemId(Id) then
                exit(Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, NotFoundLbl, 'systemId', ReadLbl));
            if (Number <> '') and (Order."No." <> UpperCase(Number)) then
                exit(Fail(Argument, "Bifrost Error Code ori"::ConflictingIdentifiers, ConflictLbl, 'prodOrderNo/systemId', ReadLbl));
        end else begin
            Order.SetRange("No.", Number);
            Order.SetRange(Status, Order.Status::Released);
            if not Order.FindFirst() then begin
                Order.SetRange(Status);
                if Order.IsEmpty() then
                    exit(Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, NotFoundLbl, 'prodOrderNo', ReadLbl));
                exit(Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, StateLbl, 'prodOrderNo', ReopenLbl));
            end;
        end;
        if Order.Status <> Order.Status::Released then
            exit(Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, StateLbl, 'prodOrderNo', ReopenLbl));
        if not ReadEntries(Argument, Request, 'itemLedgerEntryNos', Items) then
            exit(false);
        if IsOutput then
            if not ReadEntries(Argument, Request, 'capacityLedgerEntryNos', Capacity) then
                exit(false);
        if Items.Count() + Capacity.Count() = 0 then
            exit(Fail(Argument, "Bifrost Error Code ori"::MissingParameter, MissingLbl, 'itemLedgerEntryNos', CorrectLbl));
        exit(ValidateEntries(Argument, Order, Items, Capacity));
    end;

    local procedure ReadIdentifier(var Argument: Record "Message Argument ori"; Request: JsonObject; KeyName: Text; Maximum: Integer; var Value: Text): Boolean
    var
        Token: JsonToken;
        Raw: Text;
    begin
        Value := '';
        if not Request.Get(KeyName, Token) then
            exit(true);
        Token.WriteTo(Raw);
        if not Token.IsValue() or (CopyStr(Raw, 1, 1) <> '"') then
            exit(Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, InvalidLbl, KeyName, CorrectLbl));
        Value := Token.AsValue().AsText();
        if StrLen(Value) > Maximum then
            exit(Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, InvalidLbl, KeyName, CorrectLbl));
        exit(true);
    end;

    local procedure ReadEntries(var Argument: Record "Message Argument ori"; Request: JsonObject; KeyName: Text; var Entries: List of [Integer]): Boolean
    var
        Token: JsonToken;
        Element: JsonToken;
        Raw: Text;
        Number: Integer;
    begin
        if not Request.Get(KeyName, Token) then
            exit(true);
        if not Token.IsArray() then
            exit(Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, InvalidLbl, KeyName, CorrectLbl));
        foreach Element in Token.AsArray() do begin
            Element.WriteTo(Raw);
            if not Element.IsValue() or not Evaluate(Number, Raw, 9) or (Number <= 0) or (Raw <> Format(Number, 0, 9)) then
                exit(Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, InvalidLbl, KeyName, CorrectLbl));
            if Entries.Contains(Number) then
                exit(Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, InvalidLbl, KeyName, CorrectLbl));
            Entries.Add(Number);
        end;
        exit(true);
    end;

    local procedure ValidateEntries(var Argument: Record "Message Argument ori"; Order: Record "Production Order"; Items: List of [Integer]; Capacity: List of [Integer]): Boolean
    var
        ItemEntry: Record "Item Ledger Entry";
        CapacityEntry: Record "Capacity Ledger Entry";
        Application: Record "Item Application Entry";
        ReverseEntry: Record "Item Ledger Entry";
        Number: Integer;
        IsOutput: Boolean;
        ReversedLbl: Label 'The entry is already corrected or is itself a correcting entry.', Comment = 'is-IS=Færslan hefur þegar verið leiðrétt eða er sjálf mótfærsla.';
    begin
        IsOutput := Argument.Type = "Message Type ori"::"Manufacturing.Output.Reverse";
        foreach Number in Items do begin
            if not ItemEntry.Get(Number) then
                exit(Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, NotFoundLbl, 'itemLedgerEntryNos', ReadLbl));
            if (ItemEntry."Order Type" <> ItemEntry."Order Type"::Production) or (ItemEntry."Order No." <> Order."No.") or
               (IsOutput and (ItemEntry."Entry Type" <> ItemEntry."Entry Type"::Output)) or
               (not IsOutput and (ItemEntry."Entry Type" <> ItemEntry."Entry Type"::Consumption))
            then
                exit(Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, InvalidLbl, 'itemLedgerEntryNos', ReadLbl));
            if ItemEntry.Correction or (IsOutput and ((ItemEntry.Quantity <= 0) or (ItemEntry."Remaining Quantity" <> ItemEntry.Quantity))) or
               (not IsOutput and (ItemEntry.Quantity >= 0))
            then
                exit(Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, ReversedLbl, 'itemLedgerEntryNos', ReadLbl));
            if not IsOutput then begin
                Application.SetRange("Outbound Item Entry No.", Number);
                Application.SetFilter("Inbound Item Entry No.", '>%1', Number);
                if Application.FindSet() then
                    repeat
                        if ReverseEntry.Get(Application."Inbound Item Entry No.") then
                            if (ReverseEntry."Entry Type" = ReverseEntry."Entry Type"::Consumption) and (ReverseEntry.Quantity > 0) then
                                exit(Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, ReversedLbl, 'itemLedgerEntryNos', ReadLbl));
                    until Application.Next() = 0;
            end;
        end;
        foreach Number in Capacity do begin
            if not CapacityEntry.Get(Number) then
                exit(Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, NotFoundLbl, 'capacityLedgerEntryNos', ReadLbl));
            if (CapacityEntry."Order Type" <> CapacityEntry."Order Type"::Production) or (CapacityEntry."Order No." <> Order."No.") then
                exit(Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, InvalidLbl, 'capacityLedgerEntryNos', ReadLbl));
            if CapacityEntry.Reversed then
                exit(Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, ReversedLbl, 'capacityLedgerEntryNos', ReadLbl));
        end;
        exit(true);
    end;

    /// <summary>Foundation's preview count includes selected entries, never implicitly reversed last-operation capacity.</summary>
    internal procedure GetConfirmCount(var Argument: Record "Message Argument ori"; var Count: Integer; var Summary: Text): Boolean
    var
        Order: Record "Production Order";
        Items: List of [Integer];
        Capacity: List of [Integer];
        SummaryLbl: Label '%1 selected production ledger entries', Comment = '%1 = entry count, is-IS=%1 valdar framleiðslufærslur';
    begin
        if not Prepare(Argument, Order, Items, Capacity) then
            exit(false);
        Count := Items.Count() + Capacity.Count();
        Summary := StrSubstNo(SummaryLbl, Count);
        exit(true);
    end;

    /// <summary>Requires explicit confirmation even when company-wide optional confirmation is disabled.</summary>
    internal procedure Confirm(var Argument: Record "Message Argument ori"; Count: Integer): Boolean
    var
        Request: JsonObject;
        Token: JsonToken;
        Raw: Text;
        Expected: Integer;
    begin
        Request := Argument.GetRequestJson();
        if not Request.Get('expectedCount', Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::ConfirmationRequired, CountLbl, 'expectedCount', Format(Count, 0, 9), '', StrSubstNo(CountNextLbl, Count));
            exit(false);
        end;
        Token.WriteTo(Raw);
        if not Token.IsValue() or not Evaluate(Expected, Raw, 9) or (Raw <> Format(Expected, 0, 9)) then
            exit(Fail(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, InvalidLbl, 'expectedCount', CorrectLbl));
        if Expected <> Count then
            exit(Fail(Argument, "Bifrost Error Code ori"::ConfirmationMismatch, CountLbl, 'expectedCount', StrSubstNo(CountNextLbl, Count)));
        exit(true);
    end;

    /// <summary>Executes one rollback boundary after the read-only checks.</summary>
    internal procedure Execute(var Argument: Record "Message Argument ori")
    var
        Order: Record "Production Order";
        Context: Codeunit "Mfg Write Context ori";
        Items: List of [Integer];
        Capacity: List of [Integer];
        OmitLbl: Label 'Reversal posts correcting entries and requires Commit.', Comment = 'is-IS=Bakfærsla bókar mótfærslur og krefst vistunar.';
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();
        if not Prepare(Argument, Order, Items, Capacity) then
            exit;
        if not Confirm(Argument, Items.Count() + Capacity.Count()) then
            exit;
        if Argument."Omit Commit" then begin
            Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, OmitLbl, '', CorrectLbl);
            exit;
        end;
        Context.SetReverseRequest(Order, Items, Capacity);
        if not Codeunit.Run(Codeunit::"Mfg Reverse Proc ori", Argument) then
            Fail(Argument, "Bifrost Error Code ori"::PreconditionFailed, GetLastErrorText(), '', NativeNextLbl);
        Context.ClearRequest();
    end;

    local procedure Fail(var Argument: Record "Message Argument ori"; ErrorCode: Enum "Bifrost Error Code ori"; MessageText: Text; Parameter: Text; NextStep: Text): Boolean
    begin
        Argument.RespondWithError(ErrorCode, MessageText, Parameter, '', '', NextStep);
        exit(false);
    end;
}
