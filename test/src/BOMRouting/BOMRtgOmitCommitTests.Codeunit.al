namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Manufacturing.ProductionBOM;
using Microsoft.Manufacturing.Routing;
using Origo.Bifrost.Manufacturing;
using System.TestLibraries.Utilities;

/// <summary>
/// Proves that a version status change does not commit, and that the flag is clear afterwards.
/// The story object name "BOM Routing OmitCommit Tests ori" is 32 characters, so this object is
/// "BOM Rtg OmitCommit Tests ori".
/// </summary>
codeunit 97665 "BOM Rtg OmitCommit Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Lib: Codeunit "BOM Routing Test Lib ori";
        Context: Codeunit "BOM Routing Context ori";

    [Test]
    procedure AC10_OmitCommit_RollsBackBomVersionStatus()
    var
        Version: Record "Production BOM Version";
        BomNo: Code[20];
        ItemNo: Code[20];
    begin
        // [GIVEN] A committed under-development version with a valid line
        Lib.Sweep();
        BomNo := Lib.NewNo();
        ItemNo := Lib.NewNo();
        Lib.CreateItem(ItemNo, '', '');
        Lib.CreateBomHeader(BomNo, Enum::"BOM Status"::New, true);
        Lib.CreateBomVersion(BomNo, 'V1', Enum::"BOM Status"::"Under Development");
        Lib.CreateBomLine(BomNo, 'V1', 10000, Enum::"Production BOM Line Type"::Item, ItemNo);
        Commit();

        // [WHEN] Certification runs with Omit Commit and the caller then rolls back
        asserterror CertifyBomVersionThenFail(BomNo);
        Assert.ExpectedError('rollback');

        // [THEN] The version still has the committed status, and the flag is clear
        Version.Get(BomNo, 'V1');
        Assert.AreEqual(Version.Status::"Under Development", Version.Status, 'version status rolled back');
        Assert.IsFalse(Context.IsActive(), 'flag clear');
        Lib.Sweep();
    end;

    [Test]
    procedure AC11_FlagClear_LaterRoutingVersionValidateCommits()
    var
        Version: Record "Routing Version";
        Line: Record "Routing Line";
        RoutingNo: Code[20];
        WorkCenterNo: Code[20];
        MissingNo: Code[20];
        Response: JsonObject;
    begin
        // [GIVEN] A routing version whose line names a work center that does not exist
        Lib.Sweep();
        RoutingNo := Lib.NewNo();
        WorkCenterNo := Lib.NewNo();
        MissingNo := Lib.NewNo();
        Lib.CreateWorkCenter(WorkCenterNo);
        Lib.CreateRoutingHeader(RoutingNo, Enum::"Routing Status"::New, false);
        Lib.CreateRoutingVersion(RoutingNo, 'V1', Enum::"Routing Status"::"Under Development");
        Lib.CreateRoutingLine(RoutingNo, 'V1', '10', MissingNo, '');
        Commit();

        // [WHEN] Certification fails, and a later page-style validate then commits
        Response := Lib.SetRoutingStatus(RoutingNo, 'V1', 'Certified', false);
        Lib.AssertRefusal(Response, 'BusinessCentralError', 'no longer exists');
        Assert.IsFalse(Context.IsActive(), 'flag clear after the error');
        Version.Get(RoutingNo, 'V1');
        Assert.AreEqual(Version.Status::"Under Development", Version.Status, 'status unchanged by the failed call');

        Line.Get(RoutingNo, 'V1', '10');
        Line."No." := WorkCenterNo;
        Line.Modify(false);
        asserterror ValidateRoutingVersionThenFail(RoutingNo);
        Assert.ExpectedError('rollback');

        // [THEN] Standard Business Central committed the version, so the rollback did not undo it
        Version.Get(RoutingNo, 'V1');
        Assert.AreEqual(Version.Status::Certified, Version.Status, 'later validate committed');
        Assert.IsFalse(Context.IsActive(), 'flag still clear');
        Lib.Sweep();
    end;

    local procedure CertifyBomVersionThenFail(BomNo: Code[20])
    var
        Response: JsonObject;
    begin
        Response := Lib.SetBomStatus(BomNo, 'V1', 'Certified', true);
        Lib.AssertSuccess(Response);
        Error('rollback');
    end;

    local procedure ValidateRoutingVersionThenFail(RoutingNo: Code[20])
    var
        Version: Record "Routing Version";
    begin
        Version.Get(RoutingNo, 'V1');
        Version.Validate(Status, Version.Status::Certified);
        Error('rollback');
    end;
}
