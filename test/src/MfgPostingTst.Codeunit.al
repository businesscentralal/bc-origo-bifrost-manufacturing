namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Origo.Bifrost;
using System.TestLibraries.Security.AccessControl;
using System.TestLibraries.Utilities;

/// <summary>Tests journal output through the public dispatcher and verifies ledger and journal outcomes.</summary>
codeunit 97615 "Mfg Posting Tst ori"
{
    Subtype = Test;
    TestPermissions = Restrictive;

    var
        Assert: Codeunit "Library Assert";
        Lib: Codeunit "BOM Routing Test Lib ori";
        Fixtures: Codeunit "Mfg Posting Fixture ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";

    /// <summary>Posting without SUPER creates the output ledger entry and removes the journal line without a dialog.</summary>
    [Test]
    procedure Post_Output_CreatesLedgerEntry()
    var
        Entry: Record "Item Ledger Entry";
        JournalLine: Record "Item Journal Line";
        Request: JsonObject;
        Response: JsonObject;
        FixtureNo: Code[20];
        JournalName: Code[10];
    begin
        LowerPermissions.SetOutsideO365Scope();
        LowerPermissions.SetExactPermissionSet('D365 BUS PREMIUM');
        LowerPermissions.AddPermissionSet('BIFROST Full ori');
        FixtureNo := CopyStr('XM11' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, 20);
        Fixtures.Seed(FixtureNo);
        Request.Add('productionOrderNo', FixtureNo);
        Lib.AssertSuccess(Lib.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Refresh", Request, false));
        Fixtures.CreateOutputLine(FixtureNo);
        Clear(Request);
        JournalName := CopyStr(FixtureNo, 1, MaxStrLen(JournalName));
        Request.Add('journalTemplateName', JournalName);
        Request.Add('journalBatchName', JournalName);
        Response := Lib.Invoke("Message Type ori"::"Manufacturing.Journal.Post", Request, false);
        Lib.AssertSuccess(Response);
        Entry.SetRange("Item No.", FixtureNo);
        Entry.SetRange("Order Type", Entry."Order Type"::Production);
        Entry.SetRange("Order No.", FixtureNo);
        Entry.SetRange("Entry Type", Entry."Entry Type"::Output);
        Assert.AreEqual(1, Entry.Count(), 'Exactly one production output entry.');
        Entry.FindFirst();
        Assert.AreEqual(2, Entry.Quantity, 'Posted output quantity.');
        JournalLine.SetRange("Journal Template Name", JournalName);
        JournalLine.SetRange("Journal Batch Name", JournalName);
        Assert.IsTrue(JournalLine.IsEmpty(), 'Posted journal line removed.');
        Fixtures.Cleanup(FixtureNo);
        LowerPermissions.SetOutsideO365Scope();
    end;
}
