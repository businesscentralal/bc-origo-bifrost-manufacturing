namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Microsoft.Manufacturing.Document;
using System.TestLibraries.Utilities;

/// <summary>Proves MCP fixture insertion and cleanup remove all owned business data.</summary>
codeunit 97639 "Mfg Reopen Fixture Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    [Test]
    procedure C3_McpFixtureCreatesFinishedOrderAndCleans()
    var
        Fixture: Record "Mfg Reopen MCP Fixture ori";
        Order: Record "Production Order";
        Item: Record Item;
        Entry: Record "Item Ledger Entry";
        Assert: Codeunit "Library Assert";
    begin
        // Story #22, C3 | Time: WorkDate postings | Risk: None
        Fixture.Code := 'X22MCPEN';
        Fixture.Insert(true);
        Assert.IsTrue(Order.Get(Order.Status::Finished, Fixture.Code), 'MCP fixture is fully posted and Finished.');
        Fixture.Delete(true);
        Order.SetRange("No.", 'X22MCPEN');
        Assert.RecordIsEmpty(Order);
        Item.SetFilter("No.", 'X22MCPEN-C|X22MCPEN-P');
        Assert.RecordIsEmpty(Item);
        Entry.SetFilter("Item No.", 'X22MCPEN-C|X22MCPEN-P');
        Assert.RecordIsEmpty(Entry);
        Commit();
    end;
}
