namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Manufacturing.ProductionBOM;
using Microsoft.Manufacturing.Routing;
using Origo.Bifrost;
using Origo.Bifrost.Manufacturing;
using System.TestLibraries.Security.AccessControl;
using System.TestLibraries.Utilities;

/// <summary>
/// Permission tests for the two status message types.
/// BIFROST MfgRead ori does not grant the implementations. BIFROST MfgFull ori does.
/// The manufacturing tables still follow the caller's own permissions.
/// </summary>
codeunit 97664 "BOM Routing Perm Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Lib: Codeunit "BOM Routing Test Lib ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";

    [Test]
    procedure AC16_ReadSet_CannotRunEitherType()
    begin
        AssertPlatformRefusal(Enum::"Message Type ori"::"Manufacturing.ProductionBOM.SetStatus");
        AssertPlatformRefusal(Enum::"Message Type ori"::"Manufacturing.Routing.SetStatus");
    end;

    [Test]
    procedure AC16_FullSet_ReachesTheParameterCheck()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        LowerPermissions.SetOutsideO365Scope();
        LowerPermissions.SetExactPermissionSet('BIFROST Full ori');
        Request.Add('status', 'Certified');
        Response := Lib.Invoke(Enum::"Message Type ori"::"Manufacturing.ProductionBOM.SetStatus", Request, true);
        LowerPermissions.SetOutsideO365Scope();
        Lib.AssertRefusal(Response, 'MissingParameter', 'no');

        LowerPermissions.SetExactPermissionSet('BIFROST Full ori');
        Response := Lib.Invoke(Enum::"Message Type ori"::"Manufacturing.Routing.SetStatus", Request, true);
        LowerPermissions.SetOutsideO365Scope();
        Lib.AssertRefusal(Response, 'MissingParameter', 'no');
    end;

    [Test]
    procedure AC16_FullSetWithoutTablePermission_IsPermissionDenied()
    var
        BomNo: Code[20];
        RoutingNo: Code[20];
        Response: JsonObject;
    begin
        Lib.Sweep();
        BomNo := Lib.NewNo();
        RoutingNo := Lib.NewNo();
        Lib.CreateBomHeader(BomNo, Enum::"BOM Status"::New, true);
        Lib.CreateRoutingHeader(RoutingNo, Enum::"Routing Status"::New, false);
        Commit();

        LowerPermissions.SetOutsideO365Scope();
        LowerPermissions.SetExactPermissionSet('BIFROST Full ori');
        Response := Lib.SetBomStatus(BomNo, '', 'Certified', true);
        LowerPermissions.SetOutsideO365Scope();
        Lib.AssertRefusal(Response, 'PermissionDenied', 'permission');

        LowerPermissions.SetExactPermissionSet('BIFROST Full ori');
        Response := Lib.SetRoutingStatus(RoutingNo, '', 'Certified', true);
        LowerPermissions.SetOutsideO365Scope();
        Lib.AssertRefusal(Response, 'PermissionDenied', 'permission');
        Lib.Sweep();
    end;

    [Test]
    procedure AC16_FullSetWithManufacturingPermissions_Certifies()
    var
        Header: Record "Production BOM Header";
        Routing: Record "Routing Header";
        BomNo: Code[20];
        ItemNo: Code[20];
        RoutingNo: Code[20];
        WorkCenterNo: Code[20];
        Response: JsonObject;
    begin
        Lib.Sweep();
        BomNo := Lib.NewNo();
        ItemNo := Lib.NewNo();
        RoutingNo := Lib.NewNo();
        WorkCenterNo := Lib.NewNo();
        Lib.CreateItem(ItemNo, '', '');
        Lib.CreateBomHeader(BomNo, Enum::"BOM Status"::"Under Development", true);
        Lib.CreateBomLine(BomNo, '', 10000, Enum::"Production BOM Line Type"::Item, ItemNo);
        Lib.CreateWorkCenter(WorkCenterNo);
        Lib.CreateRoutingHeader(RoutingNo, Enum::"Routing Status"::"Under Development", false);
        Lib.CreateRoutingLine(RoutingNo, '', '10', WorkCenterNo, '');
        Commit();

        LowerPermissions.SetOutsideO365Scope();
        LowerPermissions.SetExactPermissionSet('D365 BUS PREMIUM');
        LowerPermissions.AddPermissionSet('BIFROST Full ori');
        Response := Lib.SetBomStatus(BomNo, '', 'Certified', false);
        LowerPermissions.SetOutsideO365Scope();
        Lib.AssertSuccess(Response);

        LowerPermissions.SetExactPermissionSet('D365 BUS PREMIUM');
        LowerPermissions.AddPermissionSet('BIFROST Full ori');
        Response := Lib.SetRoutingStatus(RoutingNo, '', 'Certified', false);
        LowerPermissions.SetOutsideO365Scope();
        Lib.AssertSuccess(Response);

        Header.Get(BomNo);
        Routing.Get(RoutingNo);
        Assert.AreEqual(Header.Status::Certified, Header.Status, 'BOM');
        Assert.AreEqual(Routing.Status::Certified, Routing.Status, 'routing');
        Lib.Sweep();
    end;

    local procedure AssertPlatformRefusal(MessageType: Enum "Message Type ori")
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        Request.Add('no', 'XMFG8');
        Request.Add('status', 'Certified');
        LowerPermissions.SetOutsideO365Scope();
        LowerPermissions.SetExactPermissionSet('BIFROST Read ori');
        Response := Lib.Invoke(MessageType, Request, false);
        LowerPermissions.SetOutsideO365Scope();
        Lib.AssertRefusal(Response, 'PermissionDenied', 'permission');
    end;
}
