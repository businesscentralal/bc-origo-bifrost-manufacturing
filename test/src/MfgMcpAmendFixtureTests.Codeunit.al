namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Inventory.Item;
using Microsoft.Manufacturing.ProductionBOM;
using Microsoft.Manufacturing.Routing;
using System.TestLibraries.Utilities;

/// <summary>Proves the owned amendment fixtures seed the intended shapes and clean up completely.</summary>
codeunit 97619 "Mfg MCP Amend Fix Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Fixture_SeedsNoRoutingAndLinkedItems_ThenCleansUp()
    var
        Item: Record Item;
        BomLine: Record "Production BOM Line";
        RoutingLine: Record "Routing Line";
        RoutingLink: Record "Routing Link";
        Fixture: Codeunit "Mfg MCP Amend Fixture Tst ori";
    begin
        // Idempotent cleanup first: this runner has no isolation, so a failed earlier run may have committed fixtures.
        Fixture.Cleanup();
        Fixture.Seed();
        Item.Get('X-M6-MCP-NR');
        Assert.AreEqual('', Item."Routing No.", 'No-routing item has no routing.');
        Assert.AreNotEqual('', Item."Production BOM No.", 'No-routing item has a BOM.');
        Item.Get('X-M6-MCP-LK');
        RoutingLine.SetRange("Routing No.", Item."Routing No.");
        RoutingLine.SetRange("Routing Link Code", 'X-M6LK');
        Assert.RecordIsNotEmpty(RoutingLine);
        BomLine.SetRange("Production BOM No.", Item."Production BOM No.");
        BomLine.SetRange("Routing Link Code", 'X-M6LK');
        Assert.RecordIsNotEmpty(BomLine);

        Fixture.Cleanup();
        Assert.IsFalse(Item.Get('X-M6-MCP-NR'), 'No-routing item removed.');
        Assert.IsFalse(Item.Get('X-M6-MCP-LK'), 'Link item removed.');
        Assert.IsFalse(RoutingLink.Get('X-M6LK'), 'Routing link removed.');
    end;
}
