namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Inventory.Item;
using Origo.Bifrost;
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
    begin
        // Story #5 AC18: the Bifrost Full extension supplies execute rights; Microsoft roles supply native data rights.
        Data.SetupNumbering(false);
        Data.CreateManufacturedItem(Item);
        Request := Data.CreateRequest(Item."No.");
        Commit();
        LowerPermissions.SetExactPermissionSet('BIFROST Full ori');
        AddNativePermissions();
        Response := Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Create", Request, 1033, false);
        LowerPermissions.SetOutsideO365Scope();
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Full role can create.');
        Clear(Request);
        Request.Add('systemId', Data.TextValue(Response, 'systemId'));
        LowerPermissions.SetExactPermissionSet('BIFROST Full ori');
        AddNativePermissions();
        Response := Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Refresh", Request, 1033, false);
        LowerPermissions.SetOutsideO365Scope();
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Full role can refresh.');
    end;

    [Test]
    procedure Scenario_AC18_ReadRole_CannotExecuteWriteTypes()
    var
        Item: Record Item;
        Request: JsonObject;
        Response: JsonObject;
        ErrorText: Text;
    begin
        // Story #5 AC18: native rights are identical; only the Bifrost role changes.
        Data.SetupNumbering(false);
        Data.CreateItem(Item);
        Request := Data.CreateRequest(Item."No.");
        Commit();
        LowerPermissions.SetExactPermissionSet('BIFROST Read ori');
        AddNativePermissions();
        asserterror Response := Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Create", Request, 1033, false);
        ErrorText := GetLastErrorText();
        LowerPermissions.SetOutsideO365Scope();
        Assert.IsTrue(ErrorText.Contains('permission') or ErrorText.Contains('Permission'), 'Platform must refuse execution permission.');
    end;

    local procedure AddNativePermissions()
    begin
        LowerPermissions.AddPermissionSet('D365 BASIC');
        LowerPermissions.AddPermissionSet('D365PREM MFG, EDIT');
        LowerPermissions.AddPermissionSet('Mfg NoGrant Tst ori');
    end;
}
