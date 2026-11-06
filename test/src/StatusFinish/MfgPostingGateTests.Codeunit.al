namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Inventory.Item;
using Microsoft.Manufacturing.Document;
using Origo.Bifrost;
using System.TestLibraries.Security.AccessControl;
using System.TestLibraries.Utilities;

/// <summary>Story #6 AC13: ChangeStatus and Finish need BIFROST MfgPost ori; CheckFinish does not.</summary>
codeunit 97624 "Mfg Posting Gate Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Data: Codeunit "Mfg Test Data ori";
        Lib: Codeunit "Mfg Status Test Lib ori";
        Assert: Codeunit "Library Assert";
        LowerPermissions: Codeunit "Library - Lower Permissions";

    [Test]
    procedure Scenario_AC13_WithoutToken_WritingTypesHiddenAndDenied()
    var
        Item: Record Item;
        Order: Record "Production Order";
        Discovery: Interface "Msg Interface ori";
        StatusEnabled: Boolean;
        FinishEnabled: Boolean;
        CheckEnabled: Boolean;
        Response: JsonObject;
        Check: JsonObject;
        ResponseText: Text;
    begin
        Lib.PrepareOrder(Item, Order, Order.Status::"Firm Planned");
        Commit();
        LowerPermissions.SetExactPermissionSet('BIFROST Full ori');
        AddNativePermissions();
        Discovery := "Message Type ori"::"Manufacturing.ProductionOrder.ChangeStatus";
        StatusEnabled := Discovery.IsEnabled();
        Discovery := "Message Type ori"::"Manufacturing.ProductionOrder.Finish";
        FinishEnabled := Discovery.IsEnabled();
        Discovery := "Message Type ori"::"Manufacturing.ProductionOrder.CheckFinish";
        CheckEnabled := Discovery.IsEnabled();
        Response := Lib.ChangeStatus(Order, 'Released', 1, 1033);
        Check := Lib.CheckFinish(Order, 1033);
        LowerPermissions.SetOutsideO365Scope();

        Assert.IsFalse(StatusEnabled, 'ChangeStatus is not listed without the token.');
        Assert.IsFalse(FinishEnabled, 'Finish is not listed without the token.');
        Assert.IsTrue(CheckEnabled, 'CheckFinish is listed without the token.');
        Response.WriteTo(ResponseText);
        Assert.AreEqual('Error', Data.TextValue(Response, 'status'), 'Direct call is refused: ' + ResponseText);
        Assert.IsTrue(ResponseText.Contains('PermissionDenied'), 'PermissionDenied: ' + ResponseText);
        Assert.IsTrue(ResponseText.Contains('BIFROST MfgPost ori'), 'The refusal names the set: ' + ResponseText);
        Assert.AreEqual('Success', Data.TextValue(Check, 'status'), 'CheckFinish runs without the token.');
        Assert.IsTrue(Order.Get(Order.Status, Order."No."), 'Nothing changed.');
        Lib.Cleanup(Item."No.");
    end;

    [Test]
    procedure Scenario_AC13_WithToken_WritingTypesListed()
    var
        Discovery: Interface "Msg Interface ori";
        StatusEnabled: Boolean;
        FinishEnabled: Boolean;
    begin
        LowerPermissions.SetExactPermissionSet('BIFROST Full ori');
        AddNativePermissions();
        LowerPermissions.AddPermissionSet('BIFROST MfgPost ori');
        Discovery := "Message Type ori"::"Manufacturing.ProductionOrder.ChangeStatus";
        StatusEnabled := Discovery.IsEnabled();
        Discovery := "Message Type ori"::"Manufacturing.ProductionOrder.Finish";
        FinishEnabled := Discovery.IsEnabled();
        LowerPermissions.SetOutsideO365Scope();
        Assert.IsTrue(StatusEnabled, 'ChangeStatus is listed with the token.');
        Assert.IsTrue(FinishEnabled, 'Finish is listed with the token.');
    end;

    local procedure AddNativePermissions()
    begin
        LowerPermissions.AddPermissionSet('D365 BASIC');
        LowerPermissions.AddPermissionSet('D365PREM MFG, EDIT');
        LowerPermissions.AddPermissionSet('Mfg NoPost Tst ori');
    end;
}
