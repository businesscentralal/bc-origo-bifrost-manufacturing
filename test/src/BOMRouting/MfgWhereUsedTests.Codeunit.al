namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Inventory.Item;
using Microsoft.Manufacturing.ProductionBOM;
using Origo.Bifrost;
using System.TestLibraries.Security.AccessControl;
using System.TestLibraries.Utilities;

/// <summary>Issue 29 AC01, AC05, C1 and C2: public dispatcher coverage of native where-used calculations.</summary>
codeunit 97649 "Mfg WhereUsed Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Lib: Codeunit "BOM Routing Test Lib ori";
        Fixture: Codeunit "Mfg WhereUsed Fixture ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        LastMessageId: Guid;

    /// <summary>Checks both hierarchy levels and direct-only usage in both languages.</summary>
    [Test]
    procedure AC01_TwoLevelsAndSingleLevel_Bilingual()
    var
        Request: JsonObject;
        Response: JsonObject;
        UsesToken: JsonToken;
        Row: JsonToken;
        Uses: JsonArray;
        LanguageId: Integer;
        Languages: List of [Integer];
        PreviousLanguage: Integer;
    begin
        // Assumption: raw owned assemblies with certified BOMs, quantities 3 and 2; no demo data.
        Fixture.Cleanup('X29TEST');
        Fixture.Seed('X29TEST');
        PreviousLanguage := GlobalLanguage();
        Languages.Add(1033);
        Languages.Add(1039);
        foreach LanguageId in Languages do begin
            GlobalLanguage(LanguageId);
            Request := ItemRequest('X29TESTLEAF');
            Response := Invoke(Request);
            Lib.AssertSuccess(Response);
            Response.Get('uses', UsesToken);
            Uses := UsesToken.AsArray();
            Assert.AreEqual(2, Uses.Count(), 'Both owning BOMs are returned.');
            Uses.Get(0, Row);
            Assert.AreEqual('X29TESTBOM1', Lib.GetText(Row.AsObject(), 'productionBomNo'), 'Direct BOM');
            Assert.AreEqual(2, Lib.GetInteger(Row.AsObject(), 'level'), 'Native direct level');
            Assert.AreEqual(3, Lib.GetInteger(Row.AsObject(), 'quantityNeeded'), 'Direct quantity');
            Uses.Get(1, Row);
            Assert.AreEqual('X29TESTBOM2', Lib.GetText(Row.AsObject(), 'productionBomNo'), 'Indirect BOM');
            Assert.AreEqual(4, Lib.GetInteger(Row.AsObject(), 'level'), 'Native indirect level');
            Assert.AreEqual(6, Lib.GetInteger(Row.AsObject(), 'quantityNeeded'), 'Multiplied quantity');
            Request.Add('multiLevel', false);
            Response := Invoke(Request);
            Lib.AssertSuccess(Response);
            Response.Get('uses', UsesToken);
            Assert.AreEqual(1, UsesToken.AsArray().Count(), 'Direct only');
        end;
        GlobalLanguage(PreviousLanguage);
        Fixture.Cleanup('X29TEST');
    end;

    /// <summary>Checks production BOM input and successful empty usage.</summary>
    [Test]
    procedure AC01_ProductionBomSourceAndUnusedItem()
    var
        Request: JsonObject;
        Response: JsonObject;
        Uses: JsonToken;
    begin
        Fixture.Cleanup('X29TEST');
        Fixture.Seed('X29TEST');
        Request.Add('type', 'productionBOM');
        Request.Add('no', 'X29TESTBOM1');
        Request.Add('calculationDate', Format(Today(), 0, 9));
        Request.Add('multiLevel', false);
        Response := Invoke(Request);
        Lib.AssertSuccess(Response);
        Response.Get('uses', Uses);
        Assert.AreEqual(1, Uses.AsArray().Count(), 'BOM owning item');
        Request := ItemRequest('X29TESTTOP');
        Response := Invoke(Request);
        Lib.AssertSuccess(Response);
        Response.Get('uses', Uses);
        Assert.AreEqual(0, Uses.AsArray().Count(), 'Unused item succeeds with no rows');
        Fixture.Cleanup('X29TEST');
    end;

    /// <summary>Checks version selection at its exact starting-date boundary.</summary>
    [Test]
    procedure AC01_CalculationDateSelectsActiveVersion()
    var
        Version: Record "Production BOM Version";
        Line: Record "Production BOM Line";
        Request: JsonObject;
        Response: JsonObject;
        UsesToken: JsonToken;
        Row: JsonToken;
        FutureDate: Date;
    begin
        Fixture.Cleanup('X29TEST');
        Fixture.Seed('X29TEST');
        FutureDate := CalcDate('<+10D>', Today());
        Version.Init();
        Version."Production BOM No." := 'X29TESTBOM1';
        Version."Version Code" := 'V1';
        Version."Unit of Measure Code" := 'X29TEST';
        Version."Starting Date" := FutureDate;
        Version.Status := Version.Status::"Under Development";
        Version.Insert(false);
        Line.Get('X29TESTBOM1', '', 10000);
        Line."Version Code" := 'V1';
        Line.Validate("Quantity per", 5);
        Line.Insert(false);
        Commit();
        Response := Lib.SetBomStatus('X29TESTBOM1', 'V1', 'Certified', false);
        Lib.AssertSuccess(Response);
        Request := ItemRequest('X29TESTLEAF');
        Request.Add('calculationDate', Format(Today(), 0, 9));
        Response := Invoke(Request);
        Lib.AssertSuccess(Response);
        Response.Get('uses', UsesToken);
        UsesToken.AsArray().Get(0, Row);
        Assert.AreEqual(3, Lib.GetInteger(Row.AsObject(), 'quantityNeeded'), 'Future version is not active yet.');
        Request.Replace('calculationDate', Format(FutureDate, 0, 9));
        Response := Invoke(Request);
        Lib.AssertSuccess(Response);
        Response.Get('uses', UsesToken);
        UsesToken.AsArray().Get(0, Row);
        Assert.AreEqual('V1', Lib.GetText(Row.AsObject(), 'versionCode'), 'Version starts on its effective date.');
        Assert.AreEqual(5, Lib.GetInteger(Row.AsObject(), 'quantityNeeded'), 'Active version quantity');
        UsesToken.AsArray().Get(1, Row);
        Assert.AreEqual(10, Lib.GetInteger(Row.AsObject(), 'quantityNeeded'), 'Indirect version quantity');
        Fixture.Cleanup('X29TEST');
    end;

    /// <summary>Checks that MCP fixture cleanup removes its raw data and can be repeated.</summary>
    [Test]
    procedure C3_McpFixtureCleansRawRecordsAndIsIdempotent()
    var
        Control: Record "Mfg WhereUsed MCP Fixture ori";
        Item: Record Item;
        Line: Record "Production BOM Line";
    begin
        Fixture.Cleanup('X29TEST');
        if Control.Get('X29TEST') then
            Control.Delete(false);
        Control.Init();
        Control.Code := 'X29TEST';
        Control.Insert(true);
        Assert.IsTrue(Item.Get('X29TESTLEAF'), 'Insert builds raw leaf.');
        Control.Cleanup := true;
        Control.Modify(true);
        Assert.IsFalse(Item.Get('X29TESTLEAF'), 'Cleanup removes leaf.');
        Line.SetRange("Production BOM No.", 'X29TESTBOM1');
        Assert.AreEqual(0, Line.Count(), 'Cleanup removes BOM lines.');
        Control.Modify(true);
        Control.Delete(true);
        Fixture.Cleanup('X29TEST');
    end;

    /// <summary>Checks structured, logged input refusals without business-data writes.</summary>
    [Test]
    procedure C1_MissingInvalidUnknownAndNotFound_ChangeNothing()
    var
        Request: JsonObject;
    begin
        Refuse(Request, 'MissingParameter');
        Request := ItemRequest('X29-NOT-FOUND');
        Refuse(Request, 'RecordNotFound');
        Request.Add('deleteExchangedComponent', true);
        Refuse(Request, 'UnknownParameter');
        Request.Remove('deleteExchangedComponent');
        Request.Replace('no', 42);
        Refuse(Request, 'InvalidParameterFormat');
        Request.Replace('no', '123456789012345678901');
        Refuse(Request, 'InvalidParameterFormat');
        Request.Replace('no', 'X29-NOT-FOUND');
        Request.Add('calculationDate', '2026-02-30');
        Refuse(Request, 'InvalidParameterFormat');
        Request.Replace('calculationDate', '2026-01-01');
        Request.Add('multiLevel', 'false');
        Refuse(Request, 'InvalidParameterFormat');
        Request.Replace('multiLevel', 1);
        Refuse(Request, 'InvalidParameterFormat');
        Request.Remove('multiLevel');
        Request.Replace('type', 'Item');
        Refuse(Request, 'InvalidParameterFormat');
    end;

    /// <summary>Checks that a native unit validation error is logged as a precondition refusal.</summary>
    [Test]
    procedure C1_NativeUnitFailureIsPreconditionFailed()
    var
        Line: Record "Production BOM Line";
        Request: JsonObject;
    begin
        Fixture.Cleanup('X29TEST');
        Fixture.Seed('X29TEST');
        Line.Get('X29TESTBOM1', '', 10000);
        Line."Unit of Measure Code" := 'X29BAD';
        Line.Modify(false);
        Commit();
        Request := ItemRequest('X29TESTLEAF');
        Refuse(Request, 'PreconditionFailed');
        Fixture.Cleanup('X29TEST');
    end;

    /// <summary>Checks successful use by a Manufacturing read caller.</summary>
    [Test]
    procedure AC05_ReadRoleSucceedsWithoutManufacturingWriteRole()
    begin
        CheckPermission(true);
    end;

    /// <summary>Checks refusal without the Manufacturing read token.</summary>
    [Test]
    procedure AC05_NoRoleRefused()
    begin
        CheckPermission(false);
    end;

    local procedure CheckPermission(WithReadRole: Boolean)
    var
        Item: Record Item;
        Line: Record "Production BOM Line";
        LogFixture: Codeunit "Mfg Reopen Fixture ori";
        Response: JsonObject;
        Request: JsonObject;
        BeforeCount: Integer;
    begin
        Fixture.Cleanup('X29TEST');
        Fixture.Seed('X29TEST');
        Request := ItemRequest('X29TESTLEAF');
        BeforeCount := Item.Count() + Line.Count();
        Commit();
        LowerPermissions.SetExactPermissionSet('BIFROST API ori');
        LowerPermissions.AddPermissionSet('D365 BASIC');
        LowerPermissions.AddPermissionSet('D365 READ');
        LowerPermissions.AddPermissionSet('BOM Rtg NoGrant ori');
        if WithReadRole then
            LowerPermissions.AddPermissionSet('BIFROST Read ori');
        Response := Invoke(Request);
        LowerPermissions.SetOutsideO365Scope();
        if WithReadRole then
            Lib.AssertSuccess(Response)
        else begin
            Lib.AssertRefusal(Response, 'PermissionDenied', '');
            LogFixture.AssertLoggedError(LastMessageId, 'PermissionDenied');
        end;
        Assert.AreEqual(BeforeCount, Item.Count() + Line.Count(), 'Role checks change no business data.');
        Fixture.Cleanup('X29TEST');
    end;

    local procedure Refuse(Request: JsonObject; ExpectedCode: Text)
    var
        Item: Record Item;
        Header: Record "Production BOM Header";
        Version: Record "Production BOM Version";
        Line: Record "Production BOM Line";
        LogFixture: Codeunit "Mfg Reopen Fixture ori";
        Response: JsonObject;
        BeforeCount: Integer;
    begin
        BeforeCount := Item.Count() + Header.Count() + Version.Count() + Line.Count();
        Response := Invoke(Request);
        Lib.AssertRefusal(Response, ExpectedCode, '');
        Assert.IsTrue(Lib.GetText(Response, 'nextStep') <> '', 'Every refusal gives a corrective step.');
        LogFixture.AssertLoggedError(LastMessageId, ExpectedCode);
        Assert.AreEqual(BeforeCount, Item.Count() + Header.Count() + Version.Count() + Line.Count(), 'No manufacturing records changed.');
    end;

    local procedure Invoke(Request: JsonObject): JsonObject
    var
        Data: Codeunit "Mfg Test Data ori";
    begin
        Commit();
        exit(Data.Invoke(Enum::"Message Type ori"::"Manufacturing.WhereUsed.Get", Request, GlobalLanguage(), false, LastMessageId));
    end;

    local procedure ItemRequest(ItemNo: Code[20]) Request: JsonObject
    begin
        Request.Add('type', 'item');
        Request.Add('no', ItemNo);
    end;
}
