namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Manufacturing.Routing;
using Microsoft.Manufacturing.Setup;
using Origo.Bifrost;
using Origo.Bifrost.Manufacturing;
using System.TestLibraries.Utilities;

/// <summary>
/// Manufacturing.Routing.CopyVersion. Issue #28.
/// The routing and its tools, personnel, quality measures and comments are built in the test and removed by the sweep.
/// </summary>
codeunit 97630 "Routing Copy Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Lib: Codeunit "BOM Routing Test Lib ori";

    [Test]
    procedure AC02_Copy_CarriesLinesToolsPersonnelMeasuresAndComments_1033()
    begin
        RunCopy(1033);
    end;

    [Test]
    procedure AC02_Copy_CarriesLinesToolsPersonnelMeasuresAndComments_1039()
    begin
        RunCopy(1039);
    end;

    [Test]
    procedure AC03_ExistingRoutingTarget_RemovesNothing()
    var
        Line: Record "Routing Line";
        RoutingNo: Code[20];
        WorkCenterNo: Code[20];
        Response: JsonObject;
    begin
        Lib.Sweep();
        RoutingNo := Lib.NewNo();
        WorkCenterNo := Lib.NewNo();
        Lib.CreateWorkCenter(WorkCenterNo);
        Lib.CreateRoutingHeader(RoutingNo, Enum::"Routing Status"::Certified, false);
        Lib.CreateRoutingLine(RoutingNo, '', '10', WorkCenterNo, '');
        Lib.CreateRoutingVersion(RoutingNo, 'VOLD', Enum::"Routing Status"::"Under Development");
        Lib.CreateRoutingLine(RoutingNo, 'VOLD', '10', WorkCenterNo, '');
        Commit();

        Response := SendCopy(RoutingNo, '', 'VOLD', '2020-01-01', false);
        Lib.AssertRefusal(Response, 'PreconditionFailed', Lib.ExpectedText('already exists', 'þegar til'));
        Line.SetRange("Routing No.", RoutingNo);
        Line.SetRange("Version Code", 'VOLD');
        Assert.AreEqual(1, Line.Count(), 'existing version line stays');
        Line.SetRange("Version Code", '');
        Assert.AreEqual(1, Line.Count(), 'header line stays');
        Lib.Sweep();
    end;

    [Test]
    procedure C1_UnknownRouting_IsRecordNotFound()
    var
        Response: JsonObject;
        Request: JsonObject;
    begin
        Request.Add('no', 'XMFG8MISSING');
        Request.Add('startingDate', '2020-01-01');
        Response := Lib.Invoke(Enum::"Message Type ori"::"Manufacturing.Routing.CopyVersion", Request, true);
        Lib.AssertRefusal(Response, 'RecordNotFound', Lib.ExpectedText('not found', 'fannst ekki'));
        Assert.AreNotEqual('', Lib.GetText(Response, 'nextStep'), 'nextStep');
    end;

    local procedure RunCopy(LanguageId: Integer)
    var
        Header: Record "Routing Header";
        Version: Record "Routing Version";
        Measure: Record "Quality Measure";
        Response: JsonObject;
        RoutingNo: Code[20];
        WorkCenterNo: Code[20];
        VersionCode: Code[20];
        MeasureCode: Code[10];
        PreviousLanguage: Integer;
    begin
        // [GIVEN] A certified routing whose header lines have one tool, one person, one quality measure and one comment
        Lib.Sweep();
        RoutingNo := Lib.NewNo();
        WorkCenterNo := Lib.NewNo();
        MeasureCode := CopyStr(Lib.NewNo(), 1, MaxStrLen(MeasureCode));
        Lib.CreateWorkCenter(WorkCenterNo);
        Measure.Init();
        Measure.Code := MeasureCode;
        Measure.Description := MeasureCode;
        Measure.Insert(true);
        Lib.CreateRoutingHeader(RoutingNo, Enum::"Routing Status"::Certified, true);
        Lib.CreateRoutingLine(RoutingNo, '', '10', WorkCenterNo, '');
        InsertChildRows(RoutingNo, '', WorkCenterNo, MeasureCode);
        Header.Get(RoutingNo);
        Header."Version Nos." := Lib.CreateVersionSeries();
        Header.Modify(false);
        Commit();

        // [WHEN] CopyVersion takes the next version code
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Response := SendCopy(RoutingNo, '', '', '2020-01-01', false);
        Lib.AssertSuccess(Response);
        Assert.AreEqual('UnderDevelopment', Lib.GetText(Response, 'recordStatus'), 'recordStatus');
        Assert.AreEqual(1, IntValue(Response, 'lineCount'), 'lineCount');
        Assert.AreEqual(1, IntValue(Response, 'toolCount'), 'toolCount');
        Assert.AreEqual(1, IntValue(Response, 'personnelCount'), 'personnelCount');
        Assert.AreEqual(1, IntValue(Response, 'qualityMeasureCount'), 'qualityMeasureCount');
        Assert.AreEqual(1, IntValue(Response, 'commentCount'), 'commentCount');
        Assert.IsTrue(Lib.GetText(Response, 'nextStep').Contains(Lib.ExpectedText('Certify the new version', 'Staðfestu nýju útgáfuna')), Lib.GetText(Response, 'nextStep'));
        VersionCode := CopyStr(Lib.GetText(Response, 'versionCode'), 1, MaxStrLen(VersionCode));
        GlobalLanguage(PreviousLanguage);

        // [THEN] The new version matches the source and the source counts stay
        Version.Get(RoutingNo, VersionCode);
        Assert.AreEqual(Version.Status::"Under Development", Version.Status, 'status');
        Assert.AreEqual(Version.Type::Parallel, Version.Type, 'type copied from the header');
        Assert.AreEqual(DMY2Date(1, 1, 2020), Version."Starting Date", 'starting date');
        Assert.AreEqual(1, CountOf(RoutingNo, ''), 'header line stays');
        Assert.AreEqual(1, CountOf(RoutingNo, VersionCode), 'version line');
        Lib.Sweep();
    end;

    local procedure InsertChildRows(RoutingNo: Code[20]; VersionCode: Code[20]; WorkCenterNo: Code[20]; MeasureCode: Code[10])
    var
        Tool: Record "Routing Tool";
        Personnel: Record "Routing Personnel";
        Measure: Record "Routing Quality Measure";
        CommentLine: Record "Routing Comment Line";
    begin
        Tool.Init();
        Tool."Routing No." := RoutingNo;
        Tool."Version Code" := VersionCode;
        Tool."Operation No." := '10';
        Tool."Line No." := 10000;
        Tool."No." := WorkCenterNo;
        Tool.Insert(false);
        Personnel.Init();
        Personnel."Routing No." := RoutingNo;
        Personnel."Version Code" := VersionCode;
        Personnel."Operation No." := '10';
        Personnel."Line No." := 10000;
        Personnel."No." := WorkCenterNo;
        Personnel.Insert(false);
        Measure.Init();
        Measure."Routing No." := RoutingNo;
        Measure."Version Code" := VersionCode;
        Measure."Operation No." := '10';
        Measure."Line No." := 10000;
        Measure."Qlty Measure Code" := MeasureCode;
        Measure.Insert(false);
        CommentLine.Init();
        CommentLine."Routing No." := RoutingNo;
        CommentLine."Version Code" := VersionCode;
        CommentLine."Operation No." := '10';
        CommentLine."Line No." := 10000;
        CommentLine.Date := WorkDate();
        CommentLine.Comment := 'note';
        CommentLine.Insert(false);
    end;

    local procedure SendCopy(DocumentNo: Code[20]; SourceVersion: Code[20]; TargetVersion: Code[20]; StartingDate: Text; OmitCommit: Boolean): JsonObject
    var
        Request: JsonObject;
    begin
        Request.Add('no', DocumentNo);
        if SourceVersion <> '' then
            Request.Add('sourceVersionCode', SourceVersion);
        if TargetVersion <> '' then
            Request.Add('targetVersionCode', TargetVersion);
        Request.Add('startingDate', StartingDate);
        exit(Lib.Invoke(Enum::"Message Type ori"::"Manufacturing.Routing.CopyVersion", Request, OmitCommit));
    end;

    local procedure CountOf(RoutingNo: Code[20]; VersionCode: Code[20]): Integer
    var
        Line: Record "Routing Line";
    begin
        Line.SetRange("Routing No.", RoutingNo);
        Line.SetRange("Version Code", VersionCode);
        exit(Line.Count());
    end;

    local procedure IntValue(Response: JsonObject; Name: Text): Integer
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(Response.Get(Name, Token), Name);
        exit(Token.AsValue().AsInteger());
    end;
}
