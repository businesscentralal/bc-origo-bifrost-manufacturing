namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Inventory.Item;
using Microsoft.Sales.Document;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Issue 23 AC05/C1: read, no-Manufacturing and no-posting-token callers cannot create production orders from demand.</summary>
codeunit 97643 "Mfg Demand Perm Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Lib: Codeunit "Mfg Demand Test Lib ori";
        Data: Codeunit "Mfg Test Data ori";
        ReopenFixture: Codeunit "Mfg Reopen Fixture ori";
        Assert: Codeunit "Library Assert";
        LowerPermissions: Codeunit "Library - Lower Permissions";

    [Test]
    procedure AC05_ReleasedWithoutPostingTokenRefused()
    begin
        // Story #23, AC05 | Time: WorkDate + 1M shipment | Risk: None
        CheckRefusal('BIFROST Full ori', 'Released', true);
    end;

    [Test]
    procedure AC05_ReadRoleRefused()
    begin
        // Story #23, AC05/C1 | Time: WorkDate + 1M shipment | Risk: None
        CheckRefusal('BIFROST Read ori', 'FirmPlanned', false);
    end;

    [Test]
    procedure AC05_NoManufacturingPermissionRefused()
    begin
        // Story #23, AC05/C1 | Time: WorkDate + 1M shipment | Risk: None
        CheckRefusal('BIFROST API ori', 'FirmPlanned', false);
    end;

    local procedure CheckRefusal(Role: Code[20]; Status: Text; ExpectEnabled: Boolean)
    var
        Item: Record Item;
        SalesHeader: Record "Sales Header";
        Discovery: Interface "Msg Interface ori";
        ItemNos: List of [Code[20]];
        Response: JsonObject;
        Enabled: Boolean;
        MessageId: Guid;
    begin
        Lib.SetupNumbering();
        Lib.CreateManufacturedItem(Item);
        ItemNos.Add(Item."No.");
        Lib.CreateSalesOrder(SalesHeader, ItemNos, true);
        Commit();
        LowerPermissions.SetExactPermissionSet(Role);
        LowerPermissions.AddPermissionSet('D365 BASIC');
        LowerPermissions.AddPermissionSet('D365PREM MFG, EDIT');
        LowerPermissions.AddPermissionSet('D365 SALES DOC, EDIT');
        LowerPermissions.AddPermissionSet('Mfg NoPost Tst ori');
        Discovery := "Message Type ori"::"Manufacturing.ProductionOrder.CreateFromDemand";
        Enabled := Discovery.IsEnabled();
        Response := Lib.Invoke(Lib.Request(SalesHeader, Status, '', 1), 1033, MessageId);
        LowerPermissions.SetOutsideO365Scope();
        Assert.AreEqual(ExpectEnabled, Enabled, 'Discovery follows Manufacturing write permission.');
        Data.AssertRefusal(Response, 'PermissionDenied');
        ReopenFixture.AssertLoggedError(MessageId, 'PermissionDenied');
        Assert.AreEqual(0, Lib.CountOrders(SalesHeader, ItemNos), 'Nothing created.');
        Lib.Cleanup(SalesHeader, ItemNos);
    end;
}
