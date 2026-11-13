namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Inventory.Item;
using Microsoft.Manufacturing.Document;
using Origo.Bifrost;
using Origo.Bifrost.Manufacturing;
using System.TestLibraries.Security.AccessControl;
using System.TestLibraries.Utilities;

/// <summary>Checks that only the full Bifrost role includes the manufacturing write implementations.</summary>
codeunit 97608 "Mfg ProdOrder Perm Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Data: Codeunit "Mfg Test Data ori";
        Assert: Codeunit "Library Assert";
        LowerPermissions: Codeunit "Library - Lower Permissions";

    [Test]
    procedure Scenario_AC18_FullRole_CanCreateAndRefresh()
    var
        Item: Record Item;
        Request: JsonObject;
        Response: JsonObject;
        ResponseText: Text;
    begin
        // Story #5 AC18: the Bifrost Full extension supplies execute rights; Microsoft roles supply native data rights.
        Data.SetupNumbering(false);
        Data.CreateManufacturedItem(Item);
        Request := Data.CreateRequest(Item."No.");
        Commit();
        LowerPermissions.SetExactPermissionSet('BIFROST Full ori');
        AddNativePermissions();
        Response := Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Create", Request, GlobalLanguage(), false);
        LowerPermissions.SetOutsideO365Scope();
        Response.WriteTo(ResponseText);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Full role can create. Response: ' + ResponseText);
        Clear(Request);
        Request.Add('systemId', Data.TextValue(Response, 'systemId'));
        LowerPermissions.SetExactPermissionSet('BIFROST Full ori');
        AddNativePermissions();
        Response := Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Refresh", Request, GlobalLanguage(), false);
        LowerPermissions.SetOutsideO365Scope();
        Response.WriteTo(ResponseText);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Full role can refresh. Response: ' + ResponseText);
        Data.CleanupOrders(Item."No.");
    end;

    [Test]
    procedure Scenario_AC18_ReadRole_CannotExecuteWriteTypes()
    var
        Item: Record Item;
        Order: Record "Production Order";
        Request: JsonObject;
    begin
        // Story #5 AC18: identical native rights; both write types are refused under Bifrost Read.
        Data.SetupNumbering(false);
        Data.CreateItem(Item);
        Data.CreateOrder(Order, Item, Order.Status::Planned);
        Commit();
        Request := Data.CreateRequest(Item."No.");
        AssertReadRoleDenied("Message Type ori"::"Manufacturing.ProductionOrder.Create", Request);
        Clear(Request);
        Request.Add('systemId', Format(Order.SystemId, 0, 4));
        AssertReadRoleDenied("Message Type ori"::"Manufacturing.ProductionOrder.Refresh", Request);
        Data.CleanupOrders(Item."No.");
    end;

    [Test]
    procedure Scenario_AC01_ReadAndFullRoles_KeepGateEmpty()
    var
        Gate: Record "Mfg Write Gate ori";
        ReadCanRead: Boolean;
        ReadCanWrite: Boolean;
        FullCanWrite: Boolean;
        ManufacturingCanWrite: Boolean;
    begin
        // Issue #15 AC01 | Time: independent of WorkDate | Risk: native roles grant broad Execute.
        Assert.RecordIsEmpty(Gate);
        LowerPermissions.SetExactPermissionSet('BIFROST Read ori');
        AddNativePermissions();
        ReadCanRead := Gate.ReadPermission();
        ReadCanWrite := Gate.WritePermission();
        LowerPermissions.SetOutsideO365Scope();
        LowerPermissions.SetExactPermissionSet('BIFROST Full ori');
        AddNativePermissions();
        FullCanWrite := Gate.WritePermission();
        LowerPermissions.SetOutsideO365Scope();
        LowerPermissions.SetExactPermissionSet('BIFROST Mfg ori');
        ManufacturingCanWrite := Gate.WritePermission();
        LowerPermissions.SetOutsideO365Scope();

        Assert.IsTrue(ReadCanRead, 'The read role can read the empty Manufacturing gate.');
        Assert.IsFalse(ReadCanWrite, 'Native Execute must not give the read role Manufacturing write access.');
        Assert.IsTrue(FullCanWrite, 'The Foundation full role includes the Manufacturing write gate.');
        Assert.IsTrue(ManufacturingCanWrite, 'The Manufacturing role grants its own write gate.');
        Assert.RecordIsEmpty(Gate);
    end;

    local procedure AssertReadRoleDenied(MessageType: Enum "Message Type ori"; Request: JsonObject)
    var
        Response: JsonObject;
        ErrorText: Text;
    begin
        LowerPermissions.SetExactPermissionSet('BIFROST Read ori');
        // Issue #15 AC02: reach the feature gate through the real dispatcher, including its message envelope.
        LowerPermissions.AddPermissionSet('BIFROST API ori');
        AddNativePermissions();
        asserterror Response := Data.Invoke(MessageType, Request, GlobalLanguage(), false);
        ErrorText := GetLastErrorText();
        LowerPermissions.SetOutsideO365Scope();
        Assert.IsTrue(ErrorText.Contains('BIFROST Mfg ori'), 'The Manufacturing write gate must refuse; a native licence or table error is not proof. Actual: ' + ErrorText);
        Assert.IsTrue(LowerCase(ErrorText).Contains('permission') or LowerCase(ErrorText).Contains('heimild'), 'The localized gate must refuse write permission. Actual: ' + ErrorText);
    end;

    local procedure AddNativePermissions()
    begin
        // BC 29 refresh reads warehouse and inventory tables that the manufacturing edit set does not include.
        LowerPermissions.AddPermissionSet('D365 BASIC');
        LowerPermissions.AddPermissionSet('D365 BUS PREMIUM');
        LowerPermissions.AddPermissionSet('D365PREM MFG, EDIT');
        LowerPermissions.AddPermissionSet('Mfg NoGrant Tst ori');
    end;
}
