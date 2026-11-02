namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Manufacturing.Routing;
using Origo.Bifrost.Manufacturing;
using System.TestLibraries.Utilities;

/// <summary>
/// Native tests for Manufacturing.Routing.SetStatus.
/// A serial routing rewrites the next operation, so the sequence failures are built as parallel routings.
/// </summary>
codeunit 97661 "Routing Status Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Lib: Codeunit "BOM Routing Test Lib ori";
        Context: Codeunit "BOM Routing Context ori";

    [Test]
    procedure AC06_CertifyValidRouting_Succeeds()
    var
        Header: Record "Routing Header";
        RoutingNo: Code[20];
        WorkCenterNo: Code[20];
        ItemNo: Code[20];
        Response: JsonObject;
    begin
        Lib.Sweep();
        RoutingNo := Lib.NewNo();
        WorkCenterNo := Lib.NewNo();
        ItemNo := Lib.NewNo();
        Lib.CreateWorkCenter(WorkCenterNo);
        Lib.CreateItem(ItemNo, '', RoutingNo);
        Lib.CreateRoutingHeader(RoutingNo, Enum::"Routing Status"::New, false);
        Lib.CreateRoutingLine(RoutingNo, '', '10', WorkCenterNo, '');

        Response := Lib.SetRoutingStatus(RoutingNo, '', 'Certified', false);

        Lib.AssertSuccess(Response);
        Assert.AreEqual('New', Lib.GetText(Response, 'previousStatus'), 'previousStatus');
        Assert.AreEqual('Certified', Lib.GetText(Response, 'recordStatus'), 'recordStatus');
        Assert.AreEqual(1, Lib.GetInteger(Response, 'usedOnItems'), 'usedOnItems');
        Assert.IsFalse(Lib.HasProperty(Response, 'lowLevelCode'), 'a routing header has no lowLevelCode');
        Header.Get(RoutingNo);
        Assert.AreEqual(Header.Status::Certified, Header.Status, 'header status');
        Assert.IsFalse(Context.IsActive(), 'context must be clear after success');
        Lib.Sweep();
    end;

    [Test]
    procedure AC06_TwoEndOperations_IsBusinessCentralError()
    var
        Header: Record "Routing Header";
        RoutingNo: Code[20];
        WorkCenterNo: Code[20];
        Response: JsonObject;
    begin
        Lib.Sweep();
        RoutingNo := Lib.NewNo();
        WorkCenterNo := Lib.NewNo();
        Lib.CreateWorkCenter(WorkCenterNo);
        Lib.CreateRoutingHeader(RoutingNo, Enum::"Routing Status"::"Under Development", true);
        Lib.CreateRoutingLine(RoutingNo, '', '10', WorkCenterNo, '');
        Lib.CreateRoutingLine(RoutingNo, '', '20', WorkCenterNo, '');

        Response := Lib.SetRoutingStatus(RoutingNo, '', 'Certified', false);

        Lib.AssertRefusal(Response, 'BusinessCentralError', 'termination');
        Header.Get(RoutingNo);
        Assert.AreEqual(Header.Status::"Under Development", Header.Status, 'status unchanged');
        Lib.Sweep();
    end;

    [Test]
    procedure AC06_MissingStartOperation_IsBusinessCentralError()
    var
        Header: Record "Routing Header";
        RoutingNo: Code[20];
        WorkCenterNo: Code[20];
        Response: JsonObject;
    begin
        Lib.Sweep();
        RoutingNo := Lib.NewNo();
        WorkCenterNo := Lib.NewNo();
        Lib.CreateWorkCenter(WorkCenterNo);
        Lib.CreateRoutingHeader(RoutingNo, Enum::"Routing Status"::New, true);
        Lib.CreateRoutingLine(RoutingNo, '', '10', WorkCenterNo, '20');
        Lib.CreateRoutingLine(RoutingNo, '', '20', WorkCenterNo, '');
        Lib.CreateRoutingLine(RoutingNo, '', '30', WorkCenterNo, '20');

        Response := Lib.SetRoutingStatus(RoutingNo, '', 'Certified', false);

        Lib.AssertRefusal(Response, 'BusinessCentralError', 'start');
        Header.Get(RoutingNo);
        Assert.AreEqual(Header.Status::New, Header.Status, 'status unchanged');
        Lib.Sweep();
    end;

    [Test]
    procedure AC06_NonSequencedRoute_IsBusinessCentralError()
    var
        Header: Record "Routing Header";
        RoutingNo: Code[20];
        WorkCenterNo: Code[20];
        Response: JsonObject;
    begin
        Lib.Sweep();
        RoutingNo := Lib.NewNo();
        WorkCenterNo := Lib.NewNo();
        Lib.CreateWorkCenter(WorkCenterNo);
        Lib.CreateRoutingHeader(RoutingNo, Enum::"Routing Status"::New, true);
        Lib.CreateRoutingLine(RoutingNo, '', '10', WorkCenterNo, '20');
        Lib.CreateRoutingLine(RoutingNo, '', '20', WorkCenterNo, '');
        Lib.CreateRoutingLine(RoutingNo, '', '30', WorkCenterNo, '30');

        Response := Lib.SetRoutingStatus(RoutingNo, '', 'Certified', false);

        Lib.AssertRefusal(Response, 'BusinessCentralError', 'sequenced');
        Header.Get(RoutingNo);
        Assert.AreEqual(Header.Status::New, Header.Status, 'status unchanged');
        Lib.Sweep();
    end;

    [Test]
    procedure AC06_MissingWorkCenter_IsBusinessCentralError()
    var
        Header: Record "Routing Header";
        RoutingNo: Code[20];
        Response: JsonObject;
    begin
        Lib.Sweep();
        RoutingNo := Lib.NewNo();
        Lib.CreateRoutingHeader(RoutingNo, Enum::"Routing Status"::New, false);
        Lib.CreateRoutingLine(RoutingNo, '', '10', Lib.NewNo(), '');

        Response := Lib.SetRoutingStatus(RoutingNo, '', 'Certified', false);

        Lib.AssertRefusal(Response, 'BusinessCentralError', 'no longer exists');
        Header.Get(RoutingNo);
        Assert.AreEqual(Header.Status::New, Header.Status, 'status unchanged');
        Assert.IsFalse(Context.IsActive(), 'context must be clear after the error');
        Lib.Sweep();
    end;

    [Test]
    procedure AC07_VersionChangesWithoutTouchingTheHeader()
    var
        Header: Record "Routing Header";
        Version: Record "Routing Version";
        RoutingNo: Code[20];
        WorkCenterNo: Code[20];
        Response: JsonObject;
    begin
        Lib.Sweep();
        RoutingNo := Lib.NewNo();
        WorkCenterNo := Lib.NewNo();
        Lib.CreateWorkCenter(WorkCenterNo);
        Lib.CreateRoutingHeader(RoutingNo, Enum::"Routing Status"::New, false);
        Lib.CreateRoutingVersion(RoutingNo, 'V1', Enum::"Routing Status"::"Under Development");
        Lib.CreateRoutingLine(RoutingNo, 'V1', '10', WorkCenterNo, '');

        Response := Lib.SetRoutingStatus(RoutingNo, 'V1', 'Certified', false);

        Lib.AssertSuccess(Response);
        Assert.AreEqual('V1', Lib.GetText(Response, 'versionCode'), 'versionCode');
        Assert.IsFalse(Lib.HasProperty(Response, 'usedOnItems'), 'version answer has no usedOnItems');
        Version.Get(RoutingNo, 'V1');
        Assert.AreEqual(Version.Status::Certified, Version.Status, 'version status');
        Header.Get(RoutingNo);
        Assert.AreEqual(Header.Status::New, Header.Status, 'header status');
        Lib.Sweep();
    end;

    [Test]
    procedure AC07_MissingVersion_IsRecordNotFound()
    var
        RoutingNo: Code[20];
        Response: JsonObject;
    begin
        Lib.Sweep();
        RoutingNo := Lib.NewNo();
        Lib.CreateRoutingHeader(RoutingNo, Enum::"Routing Status"::New, false);

        Response := Lib.SetRoutingStatus(RoutingNo, 'MISSING', 'Certified', false);

        Lib.AssertRefusal(Response, 'RecordNotFound', 'MISSING');
        Assert.AreEqual('versionCode', Lib.GetText(Response, 'parameter'), 'parameter');
        Lib.Sweep();
    end;

    [Test]
    procedure AC08_Closed_IsInvalidAndNamesTheReason()
    var
        RoutingNo: Code[20];
        Response: JsonObject;
    begin
        Lib.Sweep();
        RoutingNo := Lib.NewNo();
        Lib.CreateRoutingHeader(RoutingNo, Enum::"Routing Status"::New, false);

        Response := Lib.SetRoutingStatus(RoutingNo, '', 'Closed', true);

        Lib.AssertRefusal(Response, 'InvalidParameter', 'not supported');
        Assert.IsTrue(Lib.GetText(Response, 'nextStep').Contains('screen'), 'closed nextStep');
        Lib.Sweep();
    end;
}
