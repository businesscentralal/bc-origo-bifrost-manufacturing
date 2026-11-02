namespace Origo.Bifrost.Manufacturing;

using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Posting;

/// <summary>Suppresses journal confirmation only while a production message invokes standard posting.</summary>
codeunit 10077061 "Mfg Posting Dialog ori"
{
    Access = Internal;
    EventSubscriberInstance = Manual;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post", 'OnBeforeCode', '', false, false)]
    local procedure HidePostingDialog(var ItemJournalLine: Record "Item Journal Line"; var HideDialog: Boolean; var SuppressCommit: Boolean; var IsHandled: Boolean)
    begin
        HideDialog := true;
    end;
}
