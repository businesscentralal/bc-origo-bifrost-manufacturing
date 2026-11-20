namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Inventory.Item;
using Microsoft.Manufacturing.Document;
using Microsoft.Manufacturing.ProductionBOM;
using Origo.Bifrost;
using Origo.Bifrost.Manufacturing;
using System.TestLibraries.Utilities;

/// <summary>
/// Manufacturing.ProductionBOM.CopyVersion. Issue #28.
/// Fixtures are created in the test. XMFG8 rows are removed by the shared sweep.
/// The refresh check runs in 1033 because version selection does not depend on language.
/// The 1039 test checks the Icelandic answer.
/// </summary>
codeunit 97628 "Prod BOM Copy Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Data: Codeunit "Mfg Test Data ori";
        Lib: Codeunit "BOM Routing Test Lib ori";

    [Test]
    procedure AC01_CertifiedBom_CopyThenRefreshUsesVersion()
    var
        Item: Record Item;
        Bom: Record "Production BOM Header";
        Version: Record "Production BOM Version";
        HeaderLine: Record "Production BOM Line";
        VersionLine: Record "Production BOM Line";
        Order: Record "Production Order";
        OrderLine: Record "Prod. Order Line";
        Response: JsonObject;
        Request: JsonObject;
        SeriesCode: Code[20];
        VersionCode: Code[20];
        StartingDate: Date;
        HeaderCount: Integer;
        PreviousLanguage: Integer;
    begin
        // [GIVEN] A certified production BOM with its own version number series
        Data.SetupNumbering(false);
        Data.CreateManufacturedItem(Item);
        Bom.Get(Item."Production BOM No.");
        SeriesCode := Lib.CreateVersionSeries();
        Bom."Version Nos." := SeriesCode;
        Bom.Modify(false);
        HeaderLine.SetRange("Production BOM No.", Bom."No.");
        HeaderLine.SetRange("Version Code", '');
        HeaderCount := HeaderLine.Count();
        Assert.IsTrue(HeaderCount > 0, 'The certified BOM has lines to copy.');
        StartingDate := CalcDate('<-20Y>', WorkDate());
        Commit();

        // [WHEN] CopyVersion creates the next version and SetStatus certifies it
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        Request.Add('no', Bom."No.");
        Request.Add('startingDate', Format(StartingDate, 0, 9));
        Response := Lib.Invoke(Enum::"Message Type ori"::"Manufacturing.ProductionBOM.CopyVersion", Request, false);
        Lib.AssertSuccess(Response);
        Assert.AreEqual('UnderDevelopment', Lib.GetText(Response, 'recordStatus'), 'recordStatus');
        Assert.AreEqual(Format(StartingDate, 0, 9), Lib.GetText(Response, 'startingDate'), 'startingDate');
        Assert.AreEqual(HeaderCount, IntValue(Response, 'lineCount'), 'lineCount');
        Assert.IsTrue(Lib.GetText(Response, 'nextStep').Contains('Manufacturing.ProductionBOM.SetStatus'), 'nextStep names SetStatus');
        VersionCode := CopyStr(Lib.GetText(Response, 'versionCode'), 1, MaxStrLen(VersionCode));
        Version.Get(Bom."No.", VersionCode);
        Assert.AreEqual(Version.Status::"Under Development", Version.Status, 'version status');
        Assert.AreEqual(StartingDate, Version."Starting Date", 'version starting date');
        VersionLine.SetRange("Production BOM No.", Bom."No.");
        VersionLine.SetRange("Version Code", VersionCode);
        Assert.AreEqual(HeaderCount, VersionLine.Count(), 'copied lines');
        Assert.AreEqual(HeaderCount, HeaderLine.Count(), 'header lines stay');
        Response := Lib.SetBomStatus(Bom."No.", VersionCode, 'Certified', false);
        Lib.AssertSuccess(Response);
        GlobalLanguage(PreviousLanguage);
        Version.Get(Bom."No.", VersionCode);
        Assert.AreEqual(Version.Status::Certified, Version.Status, 'version certified');
        Commit();

        // [THEN] A new order refreshed after that starting date uses the version
        Data.CreateOrder(Order, Item, Order.Status::Planned);
        Response := Refresh(Order);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Refresh succeeds.');
        OrderLine.SetRange(Status, Order.Status);
        OrderLine.SetRange("Prod. Order No.", Order."No.");
        Assert.AreEqual(1, OrderLine.Count(), 'one order line');
        OrderLine.FindFirst();
        Assert.AreEqual(VersionCode, OrderLine."Production BOM Version Code", 'the order uses the new version');
        Data.CleanupOrders(Item."No.");
        Lib.Sweep();
    end;

    [Test]
    procedure Edge_SourceVersion_SystemIdDescriptionAndComment()
    var
        Header: Record "Production BOM Header";
        Version: Record "Production BOM Version";
        CommentLine: Record "Production BOM Comment Line";
        Line: Record "Production BOM Line";
        BomNo: Code[20];
        ItemNo: Code[20];
        Response: JsonObject;
        Request: JsonObject;
        PreviousLanguage: Integer;
    begin
        // [GIVEN] A certified BOM and one source version with a different line count
        Lib.Sweep();
        BomNo := Lib.NewNo();
        ItemNo := Lib.NewNo();
        Lib.CreateItem(ItemNo, '', '');
        Lib.CreateBomHeader(BomNo, Enum::"BOM Status"::Certified, true);
        Lib.CreateBomLine(BomNo, '', 10000, Enum::"Production BOM Line Type"::Item, ItemNo);
        Lib.CreateBomVersion(BomNo, 'VSRC', Enum::"BOM Status"::"Under Development");
        Lib.CreateBomLine(BomNo, 'VSRC', 10000, Enum::"Production BOM Line Type"::Item, ItemNo);
        Lib.CreateBomLine(BomNo, 'VSRC', 20000, Enum::"Production BOM Line Type"::Item, ItemNo);
        CommentLine.Init();
        CommentLine."Production BOM No." := BomNo;
        CommentLine."Version Code" := 'VSRC';
        CommentLine."Line No." := 10000;
        CommentLine.Date := WorkDate();
        CommentLine.Comment := 'note';
        CommentLine.Insert(false);
        Commit();
        Header.Get(BomNo);

        // [WHEN] systemId selects the BOM, the source version is copied, and the description is replaced
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(1039);
        Request.Add('systemId', Format(Header.SystemId, 0, 4));
        Request.Add('sourceVersionCode', 'VSRC');
        Request.Add('targetVersionCode', 'VNEW');
        Request.Add('startingDate', '2020-01-01');
        Request.Add('description', 'Ný lýsing');
        Response := Lib.Invoke(Enum::"Message Type ori"::"Manufacturing.ProductionBOM.CopyVersion", Request, false);
        Lib.AssertSuccess(Response);
        Assert.AreEqual('VNEW', Lib.GetText(Response, 'versionCode'), 'explicit target');
        Assert.AreEqual(2, IntValue(Response, 'lineCount'), 'source version lines');
        Assert.IsTrue(Lib.GetText(Response, 'nextStep').Contains('Staðfestu'), Lib.GetText(Response, 'nextStep'));
        GlobalLanguage(PreviousLanguage);

        // [THEN] The new version holds the copy and the source is unchanged
        Version.Get(BomNo, 'VNEW');
        Assert.AreEqual('Ný lýsing', Version.Description, 'description');
        Assert.AreEqual(Version.Status::"Under Development", Version.Status, 'status');
        Assert.AreEqual(DMY2Date(1, 1, 2020), Version."Starting Date", 'starting date');
        Line.SetRange("Production BOM No.", BomNo);
        Line.SetRange("Version Code", '');
        Assert.AreEqual(1, Line.Count(), 'header lines stay');
        Line.SetRange("Version Code", 'VSRC');
        Assert.AreEqual(2, Line.Count(), 'source lines stay');
        CommentLine.SetRange("Production BOM No.", BomNo);
        CommentLine.SetRange("Version Code", 'VNEW');
        Assert.AreEqual(1, CommentLine.Count(), 'comment copied');
        CommentLine.SetRange("Version Code", 'VSRC');
        Assert.AreEqual(1, CommentLine.Count(), 'source comment stays');
        Lib.Sweep();
    end;

    [Test]
    procedure AC03_ExistingTarget_RemovesNothing()
    var
        BomNo: Code[20];
        ItemNo: Code[20];
        Response: JsonObject;
        BeforeHeader: Integer;
        BeforeVersion: Integer;
    begin
        // [GIVEN] A version that already has a line
        Lib.Sweep();
        BomNo := Lib.NewNo();
        ItemNo := Lib.NewNo();
        Lib.CreateItem(ItemNo, '', '');
        Lib.CreateBomHeader(BomNo, Enum::"BOM Status"::Certified, true);
        Lib.CreateBomLine(BomNo, '', 10000, Enum::"Production BOM Line Type"::Item, ItemNo);
        Lib.CreateBomVersion(BomNo, 'VOLD', Enum::"BOM Status"::"Under Development");
        Lib.CreateBomLine(BomNo, 'VOLD', 10000, Enum::"Production BOM Line Type"::Item, ItemNo);
        Commit();
        BeforeHeader := CountLines(BomNo, '');
        BeforeVersion := CountLines(BomNo, 'VOLD');

        // [WHEN] The target version already exists
        Response := SendCopy(BomNo, '', 'VOLD', '2020-01-01', '', '', false);

        // [THEN] The call is refused and no line is removed
        RequireRefusal(Response, 'PreconditionFailed', Lib.ExpectedText('already exists', 'þegar til'));
        Assert.AreEqual(BeforeHeader, CountLines(BomNo, ''), 'header lines');
        Assert.AreEqual(BeforeVersion, CountLines(BomNo, 'VOLD'), 'existing version lines');
        Lib.Sweep();
    end;

    [Test]
    procedure Edge_SameVersion_IsConflictingIdentifiers()
    var
        BomNo: Code[20];
        ItemNo: Code[20];
        Response: JsonObject;
    begin
        Lib.Sweep();
        BomNo := Lib.NewNo();
        ItemNo := Lib.NewNo();
        Lib.CreateItem(ItemNo, '', '');
        Lib.CreateBomHeader(BomNo, Enum::"BOM Status"::New, true);
        Lib.CreateBomVersion(BomNo, 'VOLD', Enum::"BOM Status"::"Under Development");
        Lib.CreateBomLine(BomNo, 'VOLD', 10000, Enum::"Production BOM Line Type"::Item, ItemNo);
        Commit();

        Response := SendCopy(BomNo, 'VOLD', 'VOLD', '2020-01-01', '', '', false);
        RequireRefusal(Response, 'ConflictingIdentifiers', Lib.ExpectedText('same', 'sú sama'));
        Assert.AreEqual(1, CountLines(BomNo, 'VOLD'), 'source lines stay');
        Lib.Sweep();
    end;

    [Test]
    procedure Edge_OmitCommit_RollsBackTheNewVersion()
    var
        Version: Record "Production BOM Version";
        Header: Record "Production BOM Header";
        BomNo: Code[20];
        ItemNo: Code[20];
    begin
        Lib.Sweep();
        BomNo := Lib.NewNo();
        ItemNo := Lib.NewNo();
        Lib.CreateItem(ItemNo, '', '');
        Lib.CreateBomHeader(BomNo, Enum::"BOM Status"::Certified, true);
        Lib.CreateBomLine(BomNo, '', 10000, Enum::"Production BOM Line Type"::Item, ItemNo);
        Header.Get(BomNo);
        Header."Version Nos." := Lib.CreateVersionSeries();
        Header.Modify(false);
        Commit();

        asserterror CopyThenRollBack(BomNo);
        Assert.ExpectedError('rollback');
        Version.SetRange("Production BOM No.", BomNo);
        Assert.AreEqual(0, Version.Count(), 'the new version rolls back with the caller');
        Assert.AreEqual(1, CountLines(BomNo, ''), 'header lines stay');
        Lib.Sweep();
    end;

    [Test]
    procedure C1_InvalidInput_IsRefused()
    var
        Response: JsonObject;
        Request: JsonObject;
        LongNo: Text;
    begin
        Request.Add('no', 'XMFG8');
        Response := Lib.Invoke(Enum::"Message Type ori"::"Manufacturing.ProductionBOM.CopyVersion", Request, true);
        RequireRefusal(Response, 'MissingParameter', 'startingDate');

        Clear(Request);
        Request.Add('no', 'XMFG8');
        Request.Add('startingDate', '2020-13-40');
        Response := Lib.Invoke(Enum::"Message Type ori"::"Manufacturing.ProductionBOM.CopyVersion", Request, true);
        RequireRefusal(Response, 'InvalidParameterFormat', 'startingDate');

        LongNo := 'XMFG8XXXXXXXXXXXXXXXX';
        Assert.IsTrue(StrLen(LongNo) > 20, 'fixture longer than a code');
        Clear(Request);
        Request.Add('no', LongNo);
        Request.Add('startingDate', '2020-01-01');
        Response := Lib.Invoke(Enum::"Message Type ori"::"Manufacturing.ProductionBOM.CopyVersion", Request, true);
        RequireRefusal(Response, 'InvalidParameterFormat', 'no');

        Clear(Request);
        Request.Add('no', 'XMFG8');
        Request.Add('systemId', 'not-a-guid');
        Request.Add('startingDate', '2020-01-01');
        Response := Lib.Invoke(Enum::"Message Type ori"::"Manufacturing.ProductionBOM.CopyVersion", Request, true);
        RequireRefusal(Response, 'InvalidParameterFormat', 'systemId');

        Clear(Request);
        Request.Add('no', 'XMFG8');
        Request.Add('startingDate', '2020-01-01');
        Request.Add('closed', true);
        Response := Lib.Invoke(Enum::"Message Type ori"::"Manufacturing.ProductionBOM.CopyVersion", Request, true);
        RequireRefusal(Response, 'UnknownParameter', 'closed');
    end;

    [Test]
    procedure C1_NotFoundConflictAndEmptySeries()
    var
        HeaderA: Record "Production BOM Header";
        HeaderB: Record "Production BOM Header";
        Version: Record "Production BOM Version";
        BomA: Code[20];
        BomB: Code[20];
        ItemNo: Code[20];
        Response: JsonObject;
        Request: JsonObject;
        PreviousLanguage: Integer;
    begin
        Lib.Sweep();
        BomA := Lib.NewNo();
        BomB := Lib.NewNo();
        ItemNo := Lib.NewNo();
        Lib.CreateItem(ItemNo, '', '');
        Lib.CreateBomHeader(BomA, Enum::"BOM Status"::New, true);
        Lib.CreateBomLine(BomA, '', 10000, Enum::"Production BOM Line Type"::Item, ItemNo);
        Lib.CreateBomHeader(BomB, Enum::"BOM Status"::New, true);
        Commit();
        HeaderA.Get(BomA);
        HeaderB.Get(BomB);

        Response := SendCopy('XMFG8MISSING', '', '', '2020-01-01', '', '', true);
        RequireRefusal(Response, 'RecordNotFound', Lib.ExpectedText('not found', 'fannst ekki'));

        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(1039);
        Response := SendCopy(BomA, 'MISSING', 'VNEW', '2020-01-01', '', '', true);
        RequireRefusal(Response, 'RecordNotFound', 'fannst ekki');
        GlobalLanguage(PreviousLanguage);
        Version.SetRange("Production BOM No.", BomA);
        Assert.AreEqual(0, Version.Count(), 'unknown source writes nothing');

        Request.Add('no', BomA);
        Request.Add('systemId', Format(HeaderB.SystemId, 0, 4));
        Request.Add('startingDate', '2020-01-01');
        Response := Lib.Invoke(Enum::"Message Type ori"::"Manufacturing.ProductionBOM.CopyVersion", Request, true);
        RequireRefusal(Response, 'ConflictingIdentifiers', Lib.ExpectedText('different records', 'mismunandi'));

        Response := SendCopy(BomA, '', '', '2020-01-01', '', '', true);
        RequireRefusal(Response, 'PreconditionFailed', 'Version Nos.');
        Assert.AreEqual(0, Version.Count(), 'empty Version Nos. writes nothing');
        Assert.AreEqual(1, CountLines(BomA, ''), 'header line stays');
        Lib.Sweep();
    end;

    [Test]
    procedure C2_Contract_IsWriteAndNotIdempotent()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        PreviousLanguage: Integer;
        Bom: Interface "Msg Interface ori";
        Routing: Interface "Msg Interface ori";
        Contract: JsonObject;
        Effect: JsonObject;
        EffectToken: JsonToken;
        ContractText: Text;
    begin
        AssertContract(Enum::"Message Type ori"::"Manufacturing.ProductionBOM.CopyVersion", 'Manufacturing.ProductionBOM.SetStatus');
        AssertContract(Enum::"Message Type ori"::"Manufacturing.Routing.CopyVersion", 'Manufacturing.Routing.SetStatus');

        Bom := Enum::"Message Type ori"::"Manufacturing.ProductionBOM.CopyVersion";
        Routing := Enum::"Message Type ori"::"Manufacturing.Routing.CopyVersion";
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        Assert.AreEqual('Copies the lines of a production BOM, or of one version, into a new version that is Under Development.', Bom.GetDescription(), 'BOM description 1033');
        GlobalLanguage(1039);
        Assert.AreEqual('Afritar línur framleiðsluefnislista, eða einnar útgáfu, yfir í nýja útgáfu sem er í þróun.', Bom.GetDescription(), 'BOM description 1039');
        Assert.AreEqual('Afritar línur, verkfæri, starfsfólk, gæðamælingar og athugasemdir vinnsluleiðar, eða einnar útgáfu, yfir í nýja útgáfu sem er í þróun.', Routing.GetDescription(), 'routing description 1039');
        GlobalLanguage(PreviousLanguage);

        Assert.IsTrue(ContractMgt.GetContract(Enum::"Message Type ori"::"Manufacturing.ProductionBOM.CopyVersion", Contract), 'contract');
        Contract.WriteTo(ContractText);
        Assert.IsFalse(LowerCase(ContractText).Contains('message type'), 'help does not say message type');
        Assert.IsFalse(ContractText.Contains('Prod BOM Copy'), 'help does not name the codeunit');
        Contract.Get('effect', EffectToken);
        Effect := EffectToken.AsObject();
        Assert.AreEqual('write', ReadText(Effect, 'effect'), 'effect');
        Assert.IsFalse(ReadBoolean(Effect, 'idempotent'), 'not idempotent');
    end;

    local procedure AssertContract(MessageType: Enum "Message Type ori"; StatusTypeName: Text)
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Contract: JsonObject;
        Effect: JsonObject;
        EffectToken: JsonToken;
        ContractText: Text;
    begin
        Assert.IsTrue(ContractMgt.GetContract(MessageType, Contract), 'contract');
        Contract.WriteTo(ContractText);
        Assert.IsTrue(Contract.Contains('overview'), 'overview');
        Assert.IsTrue(Contract.Contains('notes'), 'notes');
        Assert.IsTrue(ContractText.Contains('"no"'), 'no');
        Assert.IsTrue(ContractText.Contains('systemId'), 'systemId');
        Assert.IsTrue(ContractText.Contains('sourceVersionCode'), 'sourceVersionCode');
        Assert.IsTrue(ContractText.Contains('targetVersionCode'), 'targetVersionCode');
        Assert.IsTrue(ContractText.Contains('startingDate'), 'startingDate');
        Assert.IsTrue(ContractText.Contains('description'), 'description');
        Assert.IsTrue(ContractText.Contains('MissingParameter'), 'MissingParameter');
        Assert.IsTrue(ContractText.Contains('InvalidParameterFormat'), 'InvalidParameterFormat');
        Assert.IsTrue(ContractText.Contains('UnknownParameter'), 'UnknownParameter');
        Assert.IsTrue(ContractText.Contains('RecordNotFound'), 'RecordNotFound');
        Assert.IsTrue(ContractText.Contains('ConflictingIdentifiers'), 'ConflictingIdentifiers');
        Assert.IsTrue(ContractText.Contains('PermissionDenied'), 'PermissionDenied');
        Assert.IsTrue(ContractText.Contains('PreconditionFailed'), 'PreconditionFailed');
        Assert.IsTrue(ContractText.Contains('Retryable'), 'Retryable');
        Assert.IsTrue(ContractText.Contains(StatusTypeName), 'related SetStatus');
        Assert.IsTrue(ContractText.Contains('Data.Records.Get'), 'related get');
        Contract.Get('effect', EffectToken);
        Effect := EffectToken.AsObject();
        Assert.AreEqual('write', ReadText(Effect, 'effect'), 'effect');
        Assert.IsFalse(ReadBoolean(Effect, 'idempotent'), 'idempotent');
        Assert.AreEqual('BIFROST Mfg ori', ReadText(Effect, 'permissionSet'), 'permissionSet');
    end;

    local procedure CopyThenRollBack(BomNo: Code[20])
    var
        Response: JsonObject;
    begin
        Response := SendCopy(BomNo, '', '', '2020-01-01', '', '', true);
        Lib.AssertSuccess(Response);
        Error('rollback');
    end;

    local procedure SendCopy(DocumentNo: Code[20]; SourceVersion: Code[20]; TargetVersion: Code[20]; StartingDate: Text; Description: Text; SystemId: Text; OmitCommit: Boolean): JsonObject
    var
        Request: JsonObject;
    begin
        if DocumentNo <> '' then
            Request.Add('no', DocumentNo);
        if SystemId <> '' then
            Request.Add('systemId', SystemId);
        if SourceVersion <> '' then
            Request.Add('sourceVersionCode', SourceVersion);
        if TargetVersion <> '' then
            Request.Add('targetVersionCode', TargetVersion);
        if StartingDate <> '' then
            Request.Add('startingDate', StartingDate);
        if Description <> '' then
            Request.Add('description', Description);
        exit(Lib.Invoke(Enum::"Message Type ori"::"Manufacturing.ProductionBOM.CopyVersion", Request, OmitCommit));
    end;

    local procedure Refresh(Order: Record "Production Order"): JsonObject
    var
        Request: JsonObject;
    begin
        Request.Add('systemId', Format(Order.SystemId, 0, 4));
        Request.Add('direction', 'Backward');
        Request.Add('calculateLines', true);
        Request.Add('calculateRoutings', true);
        Request.Add('calculateComponents', true);
        exit(Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Refresh", Request, 1033, false));
    end;

    local procedure CountLines(BomNo: Code[20]; VersionCode: Code[20]): Integer
    var
        Line: Record "Production BOM Line";
    begin
        Line.SetRange("Production BOM No.", BomNo);
        Line.SetRange("Version Code", VersionCode);
        exit(Line.Count());
    end;

    local procedure RequireRefusal(Response: JsonObject; ExpectedCode: Text; Fragment: Text)
    begin
        Lib.AssertRefusal(Response, ExpectedCode, Fragment);
        Assert.AreNotEqual('', Lib.GetText(Response, 'nextStep'), 'nextStep');
    end;

    local procedure IntValue(Response: JsonObject; Name: Text): Integer
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(Response.Get(Name, Token), Name);
        exit(Token.AsValue().AsInteger());
    end;

    local procedure ReadText(Object: JsonObject; Name: Text): Text
    var
        Token: JsonToken;
    begin
        Object.Get(Name, Token);
        exit(Token.AsValue().AsText());
    end;

    local procedure ReadBoolean(Object: JsonObject; Name: Text): Boolean
    var
        Token: JsonToken;
    begin
        Object.Get(Name, Token);
        exit(Token.AsValue().AsBoolean());
    end;
}
