namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Inventory.Item;
using Microsoft.Manufacturing.ProductionBOM;
using Origo.Bifrost;
using System.TestLibraries.Security.AccessControl;
using System.TestLibraries.Utilities;

/// <summary>Issue 29 AC02–AC05 and C1: version-only exchange, confirmation, permissions and atomic native rollback.</summary>
codeunit 97646 "Mfg Exchange Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Lib: Codeunit "BOM Routing Test Lib ori";
        Fixture: Codeunit "Mfg WhereUsed Fixture ori";
        Data: Codeunit "Mfg Test Data ori";
        LogFixture: Codeunit "Mfg Reopen Fixture ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        LastMessageId: Guid;

    /// <summary>Checks replacement and multiplication on a new version while all old rows remain unchanged.</summary>
    [Test]
    procedure AC02_NewVersionPreservesHeaderAndExistingVersions_Bilingual()
    var
        Header: Record "Production BOM Header";
        Version: Record "Production BOM Version";
        OriginalVersion: Record "Production BOM Version";
        Line: Record "Production BOM Line";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        Row: JsonToken;
        OriginalHeaderId: Guid;
        NewCode: Code[20];
        Languages: List of [Integer];
        LanguageId: Integer;
        PreviousLanguage: Integer;
    begin
        // Assumption: raw owned items and certified source versions, with an inactive version that must not change.
        PreviousLanguage := GlobalLanguage();
        Languages.Add(1033);
        Languages.Add(1039);
        foreach LanguageId in Languages do begin
            GlobalLanguage(LanguageId);
            Seed();
            AddVersion('1', Enum::"BOM Status"::Certified, CalcDate('<-10D>', Today()), 3);
            AddVersion('2', Enum::"BOM Status"::"Under Development", CalcDate('<+10D>', Today()), 4);
            Header.Get('X29TESTBOM1');
            OriginalHeaderId := Header.SystemId;
            OriginalVersion.Get('X29TESTBOM1', '1');
            Request := ExchangeRequest();
            Request.Add('expectedCount', 1);
            Request.Add('multiplyQtyWith', 2);
            Response := Invoke(Request, false);
            Lib.AssertSuccess(Response);
            Response.Get('newVersions', Token);
            Assert.AreEqual(1, Token.AsArray().Count(), 'One new version per active affected BOM.');
            Token.AsArray().Get(0, Row);
            NewCode := CopyStr(Lib.GetText(Row.AsObject(), 'versionCode'), 1, MaxStrLen(NewCode));
            Version.Get('X29TESTBOM1', NewCode);
            Assert.AreEqual(Version.Status::New, Version.Status, 'Native default status is New.');
            Line.Get('X29TESTBOM1', NewCode, 10000);
            Assert.AreEqual('X29TESTNEW', Line."No.", 'Replacement component');
            Assert.AreEqual(6, Line."Quantity per", 'Multiplied source quantity');
            Response.Get('changedLines', Token);
            Assert.AreEqual(1, Token.AsArray().Count(), 'Only exchanged source lines are reported.');
            Header.Get('X29TESTBOM1');
            Assert.AreEqual(OriginalHeaderId, Header.SystemId, 'Header identity stays.');
            Assert.AreEqual(Header.Status::Certified, Header.Status, 'Header status stays.');
            Version.Get('X29TESTBOM1', '1');
            Assert.AreEqual(OriginalVersion.SystemId, Version.SystemId, 'Source version identity stays.');
            Assert.AreEqual(OriginalVersion.Status, Version.Status, 'Source version status stays.');
            Line.Get('X29TESTBOM1', '', 10000);
            Assert.AreEqual('X29TESTLEAF', Line."No.", 'Header line stays.');
            Assert.AreEqual(3, Line."Quantity per", 'Header quantity stays.');
            Line.Get('X29TESTBOM1', '1', 10000);
            Assert.AreEqual('X29TESTLEAF', Line."No.", 'Old source line stays.');
            Assert.AreEqual(3, Line."Quantity per", 'Old source quantity stays.');
            Line.Get('X29TESTBOM1', '2', 10000);
            Assert.AreEqual(4, Line."Quantity per", 'Inactive version stays.');
            Line.SetRange("Production BOM No.", 'X29TESTBOM1');
            Assert.AreEqual(4, Line.Count(), 'Three existing lines plus one new line, no deletion.');
            Fixture.Cleanup('X29TEST');
        end;
        GlobalLanguage(PreviousLanguage);
    end;

    /// <summary>Checks preview and mismatched confirmation without creating versions.</summary>
    [Test]
    procedure AC03_RequiredAndWrongCountWriteNothing()
    var
        Request: JsonObject;
    begin
        Seed();
        Request := ExchangeRequest();
        Refuse(Request, 'ConfirmationRequired');
        Request.Add('expectedCount', 2);
        Refuse(Request, 'ConfirmationMismatch');
        Fixture.Cleanup('X29TEST');
    end;

    /// <summary>Checks every declared refusal and persisted Foundation error entries.</summary>
    [Test]
    procedure AC04_C1_InvalidDeleteBlankMissingUnknownAndConflict()
    var
        Request: JsonObject;
    begin
        Seed();
        Request := ExchangeRequest();
        Request.Add('deleteExchangedComponent', true);
        Refuse(Request, 'UnknownParameter');
        Request := ExchangeRequest();
        Request.Add('createNewVersion', false);
        Refuse(Request, 'UnknownParameter');
        Request := ExchangeRequest();
        Request.Replace('toNo', '');
        Refuse(Request, 'MissingParameter');
        Request := ExchangeRequest();
        Request.Remove('startingDate');
        Refuse(Request, 'MissingParameter');
        Request := ExchangeRequest();
        Request.Replace('startingDate', '2026-02-30');
        Refuse(Request, 'InvalidParameterFormat');
        Request := ExchangeRequest();
        Request.Replace('toNo', 'X29TESTLEAF');
        Refuse(Request, 'ConflictingIdentifiers');
        Request := ExchangeRequest();
        Request.Replace('toNo', 'X29-NOT-FOUND');
        Refuse(Request, 'RecordNotFound');
        Request := ExchangeRequest();
        Request.Replace('fromNo', 'X29TESTTOP');
        Refuse(Request, 'PreconditionFailed');
        Request := ExchangeRequest();
        Request.Add('multiplyQtyWith', 'bad');
        Refuse(Request, 'InvalidParameterFormat');
        Request := ExchangeRequest();
        Request.Add('recertify', 'true');
        Refuse(Request, 'InvalidParameterFormat');
        Fixture.Cleanup('X29TEST');
    end;

    /// <summary>Checks the zero multiplier boundary without removing source or new-version lines.</summary>
    [Test]
    procedure AC02_ZeroMultiplierKeepsSourceAndReplacementLines()
    var
        Line: Record "Production BOM Line";
        Request: JsonObject;
        Response: JsonObject;
    begin
        Seed();
        Request := ExchangeRequest();
        Request.Add('expectedCount', 1);
        Request.Add('multiplyQtyWith', 0);
        Response := Invoke(Request, false);
        Lib.AssertSuccess(Response);
        Line.Get('X29TESTBOM1', '1', 10000);
        Assert.AreEqual(0, Line."Quantity per", 'Zero quantity is a supported native multiplier boundary.');
        Line.Get('X29TESTBOM1', '', 10000);
        Assert.AreEqual(3, Line."Quantity per", 'Source line stays unchanged.');
        Fixture.Cleanup('X29TEST');
    end;

    /// <summary>Refuses a caller-owned transaction before creating any version.</summary>
    [Test]
    procedure AC02_OmitCommitRefusesBeforeAnyWrite()
    var
        Version: Record "Production BOM Version";
        Request: JsonObject;
        Response: JsonObject;
    begin
        Seed();
        Request := ExchangeRequest();
        Request.Add('expectedCount', 1);
        Response := Invoke(Request, true);
        Lib.AssertRefusal(Response, 'PreconditionFailed', '');
        Version.SetRange("Production BOM No.", 'X29TESTBOM1');
        Assert.AreEqual(0, Version.Count(), 'No native writes before refusing Omit Commit.');
        Fixture.Cleanup('X29TEST');
    end;

    /// <summary>Checks native certification on new versions only.</summary>
    [Test]
    procedure AC02_RecertifyChangesOnlyNewVersion()
    var
        Version: Record "Production BOM Version";
        Header: Record "Production BOM Header";
        Request: JsonObject;
        Response: JsonObject;
    begin
        Seed();
        Request := ExchangeRequest();
        Request.Add('expectedCount', 1);
        Request.Add('recertify', true);
        Response := Invoke(Request, false);
        Lib.AssertSuccess(Response);
        Version.Get('X29TESTBOM1', '1');
        Assert.AreEqual(Version.Status::Certified, Version.Status, 'New version certified.');
        Header.Get('X29TESTBOM1');
        Assert.AreEqual(Header.Status::Certified, Header.Status, 'Existing header stays certified.');
        Fixture.Cleanup('X29TEST');
    end;

    /// <summary>Proves a later BOM certification failure rolls back even the earlier successful certification.</summary>
    [Test]
    procedure C1_LaterCertificationFailureRollsBackWholeBatch()
    var
        Line: Record "Production BOM Line";
        Version: Record "Production BOM Version";
        Request: JsonObject;
    begin
        Seed();
        AddLine('X29TESTBOM2', 20000, Enum::"Production BOM Line Type"::Item, 'X29TESTLEAF', 4);
        // The unrelated self-reference is copied untouched, then refused while certifying the second new version.
        AddLine('X29TESTBOM2', 30000, Enum::"Production BOM Line Type"::"Production BOM", 'X29TESTBOM2', 1);
        Request := ExchangeRequest();
        Request.Add('expectedCount', 2);
        Request.Add('recertify', true);
        Refuse(Request, 'PreconditionFailed');
        Version.SetFilter("Production BOM No.", 'X29TESTBOM1|X29TESTBOM2');
        Assert.AreEqual(0, Version.Count(), 'Neither native certification committed a version.');
        Line.Get('X29TESTBOM1', '', 10000);
        Assert.AreEqual('X29TESTLEAF', Line."No.", 'Original component stays after rollback.');
        Fixture.Cleanup('X29TEST');
    end;

    /// <summary>Checks multiple direct parents and unchanged preexisting replacement lines.</summary>
    [Test]
    procedure AC02_AC03_MultipleBomsCountVersionsNotLines()
    var
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        Seed();
        AddLine('X29TESTBOM1', 20000, Enum::"Production BOM Line Type"::Item, 'X29TESTLEAF', 2);
        AddLine('X29TESTBOM1', 30000, Enum::"Production BOM Line Type"::Item, 'X29TESTNEW', 7);
        AddLine('X29TESTBOM2', 20000, Enum::"Production BOM Line Type"::Item, 'X29TESTLEAF', 4);
        Request := ExchangeRequest();
        Request.Add('expectedCount', 2);
        Response := Invoke(Request, false);
        Lib.AssertSuccess(Response);
        Response.Get('newVersions', Token);
        Assert.AreEqual(2, Token.AsArray().Count(), 'Two active BOMs, not three matching lines.');
        Response.Get('changedLines', Token);
        Assert.AreEqual(3, Token.AsArray().Count(), 'Preexisting replacement line is not reported as changed.');
        Fixture.Cleanup('X29TEST');
    end;

    /// <summary>Checks that read-role and no-role callers cannot exchange components.</summary>
    [Test]
    procedure AC05_ReadRoleAndNoRoleRefused()
    var
        Request: JsonObject;
        Response: JsonObject;
        WithReadRole: Boolean;
        Cases: List of [Boolean];
    begin
        Seed();
        Request := ExchangeRequest();
        Request.Add('expectedCount', 1);
        Cases.Add(true);
        Cases.Add(false);
        foreach WithReadRole in Cases do begin
            LowerPermissions.SetExactPermissionSet('BIFROST API ori');
            LowerPermissions.AddPermissionSet('D365 BASIC');
            LowerPermissions.AddPermissionSet('D365 READ');
            LowerPermissions.AddPermissionSet('BOM Rtg NoGrant ori');
            if WithReadRole then
                LowerPermissions.AddPermissionSet('BIFROST Read ori');
            Response := Invoke(Request, false);
            LowerPermissions.SetOutsideO365Scope();
            Lib.AssertRefusal(Response, 'PermissionDenied', '');
            LogFixture.AssertLoggedError(LastMessageId, 'PermissionDenied');
        end;
        Fixture.Cleanup('X29TEST');
    end;

    local procedure Seed()
    begin
        Fixture.Cleanup('X29TEST');
        Fixture.Seed('X29TEST');
    end;

    local procedure AddVersion(VersionCode: Code[20]; Status: Enum "BOM Status"; StartingDate: Date; Quantity: Decimal)
    var
        Version: Record "Production BOM Version";
        Source: Record "Production BOM Line";
    begin
        Version.Init();
        Version."Production BOM No." := 'X29TESTBOM1';
        Version."Version Code" := VersionCode;
        Version."Unit of Measure Code" := 'X29TEST';
        Version.Status := Version.Status::"Under Development";
        Version."Starting Date" := StartingDate;
        Version.Insert(false);
        Source.Get('X29TESTBOM1', '', 10000);
        Source."Version Code" := VersionCode;
        Source."Quantity per" := Quantity;
        Source.Quantity := Quantity;
        Source.Insert(false);
        if Status = Status::Certified then begin
            Commit();
            Lib.AssertSuccess(Lib.SetBomStatus('X29TESTBOM1', VersionCode, 'Certified', false));
        end;
    end;

    local procedure AddLine(BomNo: Code[20]; LineNo: Integer; Kind: Enum "Production BOM Line Type"; ComponentNo: Code[20]; Quantity: Decimal)
    var
        Line: Record "Production BOM Line";
    begin
        Line.Init();
        Line."Production BOM No." := BomNo;
        Line."Line No." := LineNo;
        Line.Type := Kind;
        Line."No." := ComponentNo;
        Line."Unit of Measure Code" := 'X29TEST';
        Line."Quantity per" := Quantity;
        Line.Quantity := Quantity;
        Line.Insert(false);
    end;

    local procedure Refuse(Request: JsonObject; ExpectedCode: Text)
    var
        Item: Record Item;
        Header: Record "Production BOM Header";
        Version: Record "Production BOM Version";
        Line: Record "Production BOM Line";
        Response: JsonObject;
        BeforeCount: Integer;
    begin
        BeforeCount := Item.Count() + Header.Count() + Version.Count() + Line.Count();
        Response := Invoke(Request, false);
        Lib.AssertRefusal(Response, ExpectedCode, '');
        LogFixture.AssertLoggedError(LastMessageId, ExpectedCode);
        Assert.AreEqual(BeforeCount, Item.Count() + Header.Count() + Version.Count() + Line.Count(), 'Refusal leaves all business-record counts unchanged.');
    end;

    local procedure Invoke(Request: JsonObject; OmitCommit: Boolean): JsonObject
    begin
        Commit();
        exit(Data.Invoke(Enum::"Message Type ori"::"Manufacturing.ProductionBOM.ExchangeItem", Request, GlobalLanguage(), OmitCommit, LastMessageId));
    end;

    local procedure ExchangeRequest() Request: JsonObject
    begin
        Request.Add('fromType', 'item');
        Request.Add('fromNo', 'X29TESTLEAF');
        Request.Add('toType', 'item');
        Request.Add('toNo', 'X29TESTNEW');
        Request.Add('startingDate', Format(Today(), 0, 9));
    end;
}
