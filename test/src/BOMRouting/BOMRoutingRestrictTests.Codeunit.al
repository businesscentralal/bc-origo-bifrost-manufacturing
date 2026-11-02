namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Manufacturing.ProductionBOM;
using Microsoft.Manufacturing.Routing;
using Origo.Bifrost.Manufacturing;
using System.TestLibraries.Utilities;

/// <summary>
/// Generic Data.Records.Set of Status is refused. Foundation answers a field that has a dedicated
/// hint with PermissionDenied and puts the hint in nextStep. The story named BlockedByWriteGuard;
/// that code is what the change-log guard uses when no hint is present. Description stays writable
/// and Data.Records.Get stays allowed.
/// </summary>
codeunit 97662 "BOM Routing Restrict Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Lib: Codeunit "BOM Routing Test Lib ori";

    [Test]
    procedure AC12_BomHeaderStatus_IsRefusedAndDescriptionStaysWritable()
    var
        Header: Record "Production BOM Header";
        BomNo: Code[20];
        Response: JsonObject;
    begin
        Lib.Sweep();
        BomNo := Lib.NewNo();
        Lib.CreateBomHeader(BomNo, Enum::"BOM Status"::New, true);
        Header.Get(BomNo);

        Response := Lib.SetField('Production BOM Header', Header.SystemId, 'Status', 'Certified');
        AssertRefusedWithHint(Response, 'Manufacturing.ProductionBOM.SetStatus');
        Header.Get(BomNo);
        Assert.AreEqual(Header.Status::New, Header.Status, 'status unchanged');

        Response := Lib.SetField('Production BOM Header', Header.SystemId, 'Description', 'XMFG8 edited');
        Lib.AssertSuccess(Response);
        Header.Get(BomNo);
        Assert.AreEqual('XMFG8 edited', Header.Description, 'description');

        Lib.AssertSuccess(Lib.GetTable('Production BOM Header'));
        Lib.Sweep();
    end;

    [Test]
    procedure AC12_BomVersionStatus_IsRefused()
    var
        Version: Record "Production BOM Version";
        BomNo: Code[20];
        Response: JsonObject;
    begin
        Lib.Sweep();
        BomNo := Lib.NewNo();
        Lib.CreateBomHeader(BomNo, Enum::"BOM Status"::New, true);
        Lib.CreateBomVersion(BomNo, 'V1', Enum::"BOM Status"::"Under Development");
        Version.Get(BomNo, 'V1');

        Response := Lib.SetField('Production BOM Version', Version.SystemId, 'Status', 'Certified');

        AssertRefusedWithHint(Response, 'Manufacturing.ProductionBOM.SetStatus');
        Version.Get(BomNo, 'V1');
        Assert.AreEqual(Version.Status::"Under Development", Version.Status, 'status unchanged');
        Lib.Sweep();
    end;

    [Test]
    procedure AC12_RoutingHeaderAndVersionStatus_AreRefused()
    var
        Header: Record "Routing Header";
        Version: Record "Routing Version";
        RoutingNo: Code[20];
        Response: JsonObject;
    begin
        Lib.Sweep();
        RoutingNo := Lib.NewNo();
        Lib.CreateRoutingHeader(RoutingNo, Enum::"Routing Status"::New, false);
        Lib.CreateRoutingVersion(RoutingNo, 'V1', Enum::"Routing Status"::New);
        Header.Get(RoutingNo);
        Version.Get(RoutingNo, 'V1');

        Response := Lib.SetField('Routing Header', Header.SystemId, 'Status', 'Certified');
        AssertRefusedWithHint(Response, 'Manufacturing.Routing.SetStatus');
        Header.Get(RoutingNo);
        Assert.AreEqual(Header.Status::New, Header.Status, 'header status');

        Response := Lib.SetField('Routing Version', Version.SystemId, 'Status', 'Certified');
        AssertRefusedWithHint(Response, 'Manufacturing.Routing.SetStatus');
        Version.Get(RoutingNo, 'V1');
        Assert.AreEqual(Version.Status::New, Version.Status, 'version status');

        Lib.AssertSuccess(Lib.GetTable('Routing Header'));
        Lib.Sweep();
    end;

    local procedure AssertRefusedWithHint(ResponseJson: JsonObject; Hint: Text)
    var
        ResponseText: Text;
    begin
        ResponseJson.WriteTo(ResponseText);
        Assert.AreEqual('Error', Lib.GetText(ResponseJson, 'status'), ResponseText);
        Assert.AreEqual('PermissionDenied', Lib.GetText(ResponseJson, 'code'), ResponseText);
        Assert.IsTrue(Lib.GetText(ResponseJson, 'nextStep').Contains(Hint), ResponseText);
    end;
}
