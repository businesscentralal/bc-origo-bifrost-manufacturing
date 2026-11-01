namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Manufacturing.ProductionBOM;
using Origo.Bifrost;
using Origo.Bifrost.Manufacturing;
using System.TestLibraries.Utilities;

/// <summary>
/// Native tests for Manufacturing.ProductionBOM.SetStatus.
/// AC13, the refresh loop, stays out of this suite until Manufacturing.ProductionOrder.Refresh exists.
/// A skipped test would fail the full-suite rule, so that acceptance stays dependent rather than skipped.
/// </summary>
codeunit 97660 "Prod BOM Status Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Lib: Codeunit "BOM Routing Test Lib ori";
        Context: Codeunit "BOM Routing Context ori";

    [Test]
    procedure AC01_CertifyNewBom_ReturnsPreviousStatusAndHeaderFacts()
    var
        Header: Record "Production BOM Header";
        BomNo: Code[20];
        ComponentNo: Code[20];
        ParentItemNo: Code[20];
        Response: JsonObject;
    begin
        // [GIVEN] A new production BOM with one component item, used by a different item.
        // The component must not point back at this BOM, or the standard circular check refuses certification.
        Lib.Sweep();
        BomNo := Lib.NewNo();
        ComponentNo := Lib.NewNo();
        ParentItemNo := Lib.NewNo();
        Lib.CreateItem(ComponentNo, '', '');
        Lib.CreateItem(ParentItemNo, BomNo, '');
        Lib.CreateBomHeader(BomNo, Enum::"BOM Status"::New, true);
        Lib.CreateBomLine(BomNo, '', 10000, Enum::"Production BOM Line Type"::Item, ComponentNo);

        // [WHEN] The BOM is certified
        Response := Lib.SetBomStatus(BomNo, '', 'Certified', false);

        // [THEN] The header is certified and the answer names the previous status, the low-level code and the item count
        Lib.AssertSuccess(Response);
        Assert.AreEqual('New', Lib.GetText(Response, 'previousStatus'), 'previousStatus');
        Assert.AreEqual('Certified', Lib.GetText(Response, 'recordStatus'), 'recordStatus');
        Assert.AreEqual('', Lib.GetText(Response, 'versionCode'), 'versionCode');
        Assert.IsTrue(Lib.GetBoolean(Response, 'changed'), 'changed');
        Assert.AreEqual(1, Lib.GetInteger(Response, 'usedOnItems'), 'usedOnItems');
        Assert.IsTrue(Lib.HasProperty(Response, 'lowLevelCode'), 'lowLevelCode');
        Header.Get(BomNo);
        Assert.AreEqual(Header.Status::Certified, Header.Status, 'header status');
        Assert.IsFalse(Context.IsActive(), 'context must be clear after success');
        Lib.Sweep();
    end;

    [Test]
    procedure AC01_CertifyUnderDevelopmentBom_Succeeds()
    var
        Header: Record "Production BOM Header";
        BomNo: Code[20];
        ItemNo: Code[20];
        Response: JsonObject;
    begin
        Lib.Sweep();
        BomNo := Lib.NewNo();
        ItemNo := Lib.NewNo();
        Lib.CreateItem(ItemNo, '', '');
        Lib.CreateBomHeader(BomNo, Enum::"BOM Status"::"Under Development", true);
        Lib.CreateBomLine(BomNo, '', 10000, Enum::"Production BOM Line Type"::Item, ItemNo);

        Response := Lib.SetBomStatus(BomNo, '', 'under development', false);

        Lib.AssertSuccess(Response);
        Assert.AreEqual('UnderDevelopment', Lib.GetText(Response, 'previousStatus'), 'previousStatus');
        Assert.AreEqual('Certified', Lib.GetText(Response, 'recordStatus'), 'recordStatus');
        Header.Get(BomNo);
        Assert.AreEqual(Header.Status::Certified, Header.Status, 'header status');
        Lib.Sweep();
    end;

    [Test]
    procedure AC02_UnderDevelopment_MakesTheLineWritableAgain()
    var
        Header: Record "Production BOM Header";
        Line: Record "Production BOM Line";
        BomNo: Code[20];
        ItemNo: Code[20];
        Response: JsonObject;
    begin
        // [GIVEN] A certified production BOM
        Lib.Sweep();
        BomNo := Lib.NewNo();
        ItemNo := Lib.NewNo();
        Lib.CreateItem(ItemNo, '', '');
        Lib.CreateBomHeader(BomNo, Enum::"BOM Status"::"Under Development", true);
        Lib.CreateBomLine(BomNo, '', 10000, Enum::"Production BOM Line Type"::Item, ItemNo);
        Lib.AssertSuccess(Lib.SetBomStatus(BomNo, '', 'Certified', false));
        Line.Get(BomNo, '', 10000);

        // [WHEN] A line is edited while the BOM is certified, then the BOM is returned to Under Development and the line is edited again
        Response := Lib.SetField('Production BOM Line', Line.SystemId, 'Description', 'blocked edit');
        Lib.AssertRefusal(Response, 'BusinessCentralError', 'Status');
        Lib.AssertSuccess(Lib.SetBomStatus(BomNo, '', 'UnderDevelopment', false));
        Line.Get(BomNo, '', 10000);
        Response := Lib.SetField('Production BOM Line', Line.SystemId, 'Description', 'open edit');

        // [THEN] The second edit is stored
        Lib.AssertSuccess(Response);
        Header.Get(BomNo);
        Assert.AreEqual(Header.Status::"Under Development", Header.Status, 'header status');
        Line.Get(BomNo, '', 10000);
        Assert.AreEqual('open edit', Line.Description, 'line description');
        Lib.Sweep();
    end;

    [Test]
    procedure AC03_CircularReference_IsBusinessCentralError()
    var
        Header: Record "Production BOM Header";
        BomNo: Code[20];
        Response: JsonObject;
        PreviousDynamicLowLevelCode: Boolean;
    begin
        // The circular walk runs only when Dynamic Low-Level Code is off. Restore the company value before the assertions.
        Lib.Sweep();
        PreviousDynamicLowLevelCode := Lib.SetDynamicLowLevelCode(false);
        BomNo := Lib.NewNo();
        Lib.CreateBomHeader(BomNo, Enum::"BOM Status"::New, true);
        Lib.CreateBomLine(BomNo, '', 10000, Enum::"Production BOM Line Type"::"Production BOM", BomNo);

        Response := Lib.SetBomStatus(BomNo, '', 'Certified', false);
        Lib.SetDynamicLowLevelCode(PreviousDynamicLowLevelCode);

        Lib.AssertRefusal(Response, 'BusinessCentralError', 'circular');
        Assert.IsTrue(ResponseTextContains(Response, 'Data.Records.Set'), 'nextStep names Data.Records.Set');
        Header.Get(BomNo);
        Assert.AreEqual(Header.Status::New, Header.Status, 'status unchanged');
        Assert.IsFalse(Context.IsActive(), 'context must be clear after the error');
        Lib.Sweep();
    end;

    [Test]
    procedure AC03_MissingUnitOfMeasure_IsBusinessCentralError()
    var
        Header: Record "Production BOM Header";
        BomNo: Code[20];
        ItemNo: Code[20];
        Response: JsonObject;
    begin
        Lib.Sweep();
        BomNo := Lib.NewNo();
        ItemNo := Lib.NewNo();
        Lib.CreateItem(ItemNo, '', '');
        Lib.CreateBomHeader(BomNo, Enum::"BOM Status"::New, false);
        Lib.CreateBomLine(BomNo, '', 10000, Enum::"Production BOM Line Type"::Item, ItemNo);

        Response := Lib.SetBomStatus(BomNo, '', 'Certified', false);

        Lib.AssertRefusal(Response, 'BusinessCentralError', 'Unit of Measure');
        Header.Get(BomNo);
        Assert.AreEqual(Header.Status::New, Header.Status, 'status unchanged');
        Lib.Sweep();
    end;

    [Test]
    procedure AC03_EmptyComponent_IsBusinessCentralError()
    var
        Header: Record "Production BOM Header";
        BomNo: Code[20];
        Response: JsonObject;
    begin
        Lib.Sweep();
        BomNo := Lib.NewNo();
        Lib.CreateBomHeader(BomNo, Enum::"BOM Status"::New, true);
        Lib.CreateBomLine(BomNo, '', 10000, Enum::"Production BOM Line Type"::Item, '');

        Response := Lib.SetBomStatus(BomNo, '', 'Certified', false);

        Lib.AssertRefusal(Response, 'BusinessCentralError', 'No.');
        Header.Get(BomNo);
        Assert.AreEqual(Header.Status::New, Header.Status, 'status unchanged');
        Lib.Sweep();
    end;

    [Test]
    procedure AC04_SameStatus_ChangesNothing()
    var
        Header: Record "Production BOM Header";
        BomNo: Code[20];
        Response: JsonObject;
    begin
        Lib.Sweep();
        BomNo := Lib.NewNo();
        Lib.CreateBomHeader(BomNo, Enum::"BOM Status"::"Under Development", true);

        Response := Lib.SetBomStatus(BomNo, '', 'UnderDevelopment', false);

        Lib.AssertSuccess(Response);
        Assert.IsFalse(Lib.GetBoolean(Response, 'changed'), 'changed');
        Assert.IsTrue(Lib.GetText(Response, 'message').Contains('Nothing was changed.'), 'unchanged message');
        Header.Get(BomNo);
        Assert.AreEqual(Header.Status::"Under Development", Header.Status, 'status');
        Lib.Sweep();
    end;

    [Test]
    procedure AC05_VersionChangesWithoutTouchingTheHeader()
    var
        Header: Record "Production BOM Header";
        Version: Record "Production BOM Version";
        BomNo: Code[20];
        ItemNo: Code[20];
        Response: JsonObject;
    begin
        Lib.Sweep();
        BomNo := Lib.NewNo();
        ItemNo := Lib.NewNo();
        Lib.CreateItem(ItemNo, '', '');
        Lib.CreateBomHeader(BomNo, Enum::"BOM Status"::New, true);
        Lib.CreateBomVersion(BomNo, 'V1', Enum::"BOM Status"::"Under Development");
        Lib.CreateBomLine(BomNo, 'V1', 10000, Enum::"Production BOM Line Type"::Item, ItemNo);

        Response := Lib.SetBomStatus(BomNo, 'V1', 'Certified', false);

        Lib.AssertSuccess(Response);
        Assert.AreEqual('V1', Lib.GetText(Response, 'versionCode'), 'versionCode');
        Assert.IsFalse(Lib.HasProperty(Response, 'lowLevelCode'), 'version answer has no lowLevelCode');
        Assert.IsFalse(Lib.HasProperty(Response, 'usedOnItems'), 'version answer has no usedOnItems');
        Version.Get(BomNo, 'V1');
        Assert.AreEqual(Version.Status::Certified, Version.Status, 'version status');
        Header.Get(BomNo);
        Assert.AreEqual(Header.Status::New, Header.Status, 'header status');
        Lib.Sweep();
    end;

    [Test]
    procedure AC05_MissingVersion_IsRecordNotFound()
    var
        BomNo: Code[20];
        Response: JsonObject;
    begin
        Lib.Sweep();
        BomNo := Lib.NewNo();
        Lib.CreateBomHeader(BomNo, Enum::"BOM Status"::New, true);

        Response := Lib.SetBomStatus(BomNo, 'MISSING', 'Certified', false);

        Lib.AssertRefusal(Response, 'RecordNotFound', 'MISSING');
        Assert.AreEqual('versionCode', Lib.GetText(Response, 'parameter'), 'parameter');
        Lib.Sweep();
    end;

    [Test]
    procedure AC08_ClosedAndNewAndOtherText_AreInvalid()
    var
        Header: Record "Production BOM Header";
        BomNo: Code[20];
        Response: JsonObject;
    begin
        Lib.Sweep();
        BomNo := Lib.NewNo();
        Lib.CreateBomHeader(BomNo, Enum::"BOM Status"::New, true);

        Response := Lib.SetBomStatus(BomNo, '', 'Closed', false);
        Lib.AssertRefusal(Response, 'InvalidParameter', 'not supported');
        Assert.IsTrue(Lib.GetText(Response, 'nextStep').Contains('screen'), 'closed nextStep');

        Response := Lib.SetBomStatus(BomNo, '', 'New', false);
        Lib.AssertRefusal(Response, 'InvalidParameter', 'not supported');
        Assert.IsTrue(Lib.GetText(Response, 'nextStep').Contains('Certified'), 'new nextStep');

        Response := Lib.SetBomStatus(BomNo, '', 'Released', false);
        Lib.AssertRefusal(Response, 'InvalidParameter', 'not supported');

        Header.Get(BomNo);
        Assert.AreEqual(Header.Status::New, Header.Status, 'status unchanged');
        Lib.Sweep();
    end;

    [Test]
    procedure AC09_MissingUnknownAndSeveralProblems()
    var
        Request: JsonObject;
        Response: JsonObject;
        BomNo: Code[20];
    begin
        Lib.Sweep();
        BomNo := Lib.NewNo();

        Request.Add('status', 'Certified');
        Response := Lib.Invoke(Enum::"Message Type ori"::"Manufacturing.ProductionBOM.SetStatus", Request, true);
        Lib.AssertRefusal(Response, 'MissingParameter', 'no');

        Clear(Request);
        Request.Add('no', BomNo);
        Response := Lib.Invoke(Enum::"Message Type ori"::"Manufacturing.ProductionBOM.SetStatus", Request, true);
        Lib.AssertRefusal(Response, 'MissingParameter', 'status');

        Response := Lib.SetBomStatus(Lib.NewNo(), '', 'Certified', true);
        Lib.AssertRefusal(Response, 'RecordNotFound', 'not found');
        Assert.AreEqual('no', Lib.GetText(Response, 'parameter'), 'parameter');

        Clear(Request);
        Request.Add('status', 'Certified');
        Request.Add('extra', 'x');
        Response := Lib.Invoke(Enum::"Message Type ori"::"Manufacturing.ProductionBOM.SetStatus", Request, true);
        Lib.AssertRefusal(Response, 'MultipleErrors', 'UnknownParameter');

        Clear(Request);
        Request.Add('no', BomNo);
        Request.Add('status', 'Certified');
        Request.Add('extra', 'x');
        Response := Lib.Invoke(Enum::"Message Type ori"::"Manufacturing.ProductionBOM.SetStatus", Request, true);
        Lib.AssertRefusal(Response, 'UnknownParameter', 'extra');
        Lib.Sweep();
    end;

    [Test]
    procedure AC09_CodeLongerThanTwenty_IsInvalidParameterFormat()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        Request.Add('no', '123456789012345678901');
        Request.Add('status', 'Certified');
        Response := Lib.Invoke(Enum::"Message Type ori"::"Manufacturing.ProductionBOM.SetStatus", Request, true);
        Lib.AssertRefusal(Response, 'InvalidParameterFormat', '20');
    end;

    [Test]
    procedure AC15_IcelandicClosedRefusal()
    var
        SavedLanguageId: Integer;
        Response: JsonObject;
        BomNo: Code[20];
    begin
        Lib.Sweep();
        BomNo := Lib.NewNo();
        Lib.CreateBomHeader(BomNo, Enum::"BOM Status"::New, true);
        SavedLanguageId := GlobalLanguage();
        GlobalLanguage(1039);
        Response := Lib.SetBomStatus(BomNo, '', 'Closed', true);
        GlobalLanguage(SavedLanguageId);

        Lib.AssertRefusal(Response, 'InvalidParameter', 'ekki studd');
        Assert.IsTrue(Lib.GetText(Response, 'nextStep').Contains('skjás'), 'Icelandic closed reason');
        Lib.Sweep();
    end;

    local procedure ResponseTextContains(ResponseJson: JsonObject; Fragment: Text): Boolean
    var
        ResponseText: Text;
    begin
        ResponseJson.WriteTo(ResponseText);
        exit(ResponseText.Contains(Fragment));
    end;
}
