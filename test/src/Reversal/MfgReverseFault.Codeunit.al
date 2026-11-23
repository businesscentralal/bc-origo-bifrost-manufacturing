namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Inventory.Ledger;
using Microsoft.Manufacturing.Journal;

/// <summary>Manual, prefix-scoped fault injection after native correction posting to verify the rollback boundary.</summary>
codeunit 97657 "Mfg Reverse Fault ori"
{
    EventSubscriberInstance = Manual;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Undo Prod. Posting Mgmt.", OnReverseProdItemLedgerEntryOnAfterProcessItemLedgerEntry, '', false, false)]
    local procedure FailAfterPostedEntry(ItemLedgerEntry: Record "Item Ledger Entry")
    begin
        if ItemLedgerEntry."Order No." = 'X25REV' then
            Error('Injected reversal rollback probe');
    end;
}
