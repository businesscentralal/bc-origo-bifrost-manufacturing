namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Inventory.Costing;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Microsoft.Manufacturing.Document;
using Microsoft.Manufacturing.Setup;
using System.TestLibraries.Utilities;

/// <summary>Exercises every persistent MCP fixture stage and proves owned cleanup and setup restoration.</summary>
codeunit 97634 "Mfg Read Fixture Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    [Test]
    procedure MCPFixture_PostsFinishesAndCleans()
    var
        Fixture: Record "Mfg Read MCP Fixture ori";
        Setup: Record "Manufacturing Setup";
        Order: Record "Production Order";
        Item: Record Item;
        Entry: Record "Item Ledger Entry";
        ValueEntry: Record "Value Entry";
        PostingQueue: Record "Post Value Entry to G/L";
        Assert: Codeunit "Library Assert";
        Original: Code[10];
    begin
        Setup.Get();
        Original := Setup."Show Capacity In";
        Fixture.Code := 'X26MCPT';
        Fixture.Insert(true);
        Item.Get('X26MCPT-C');
        Item.CalcFields(Inventory);
        Assert.AreEqual(2, Item.Inventory, 'Seed posts two.');
        Fixture.Stage := 1;
        Fixture.Modify(true);
        Item.CalcFields(Inventory);
        Assert.AreEqual(5, Item.Inventory, 'Replenish posts three more.');
        Fixture.Stage := 2;
        Fixture.Modify(true);
        Assert.IsTrue(Order.Get(Order.Status::Finished, Fixture.Code), 'Native finish completed.');
        Fixture.Stage := 3;
        Fixture.Modify(true);
        Fixture.Delete(true);
        Order.SetRange("No.", 'X26MCPT');
        Assert.RecordIsEmpty(Order);
        Item.SetFilter("No.", 'X26MCPT-C|X26MCPT-P');
        Assert.RecordIsEmpty(Item);
        Entry.SetFilter("Item No.", 'X26MCPT-C|X26MCPT-P');
        Assert.RecordIsEmpty(Entry);
        ValueEntry.SetFilter("Item No.", 'X26MCPT-C|X26MCPT-P');
        Assert.RecordIsEmpty(ValueEntry);
        PostingQueue.SetFilter("Item No.", 'X26MCPT-C|X26MCPT-P');
        Assert.RecordIsEmpty(PostingQueue);
        Clear(Fixture);
        Fixture.Code := 'X26MCPT';
        Fixture.Insert(true);
        Fixture.Delete(true);
        Assert.RecordIsEmpty(PostingQueue);
        Setup.Get();
        Assert.AreEqual(Original, Setup."Show Capacity In", 'Company setup restored after cleanup and repeat seed.');
    end;
}
