namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Foundation.UOM;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Planning;
using Microsoft.Manufacturing.ProductionBOM;
using Microsoft.Manufacturing.Routing;
using Microsoft.Manufacturing.Setup;
using Microsoft.Manufacturing.WorkCenter;
using Origo.Bifrost;
using Origo.Bifrost.Manufacturing;
using System.Diagnostics;
using System.TestLibraries.Utilities;
using System.Utilities;

/// <summary>
/// Fixture and dispatch helpers for production BOM and routing status tests.
/// Every record uses the XMFG8 prefix so a sweep can remove it, including after a committed call.
/// Message types are invoked only through <c>Dispatcher ori</c>.
/// Object 97666 is the shared library for the reserved test range 97660-97679.
/// The story name of the omit-commit codeunit is shortened in that codeunit because thirty characters is the limit.
/// </summary>
codeunit 97666 "BOM Routing Test Lib ori"
{
    Access = Internal;

    var
        Assert: Codeunit "Library Assert";
        UomCodeTok: Label 'XMFG8', Locked = true;
        PrefixTok: Label 'XMFG8*', Locked = true;

    /// <summary>Removes every XMFG8 fixture this library created and commits the delete.</summary>
    procedure Sweep()
    var
        Item: Record Item;
        ItemUnitOfMeasure: Record "Item Unit of Measure";
        PlanningAssignment: Record "Planning Assignment";
        ChangeLogEntry: Record "Change Log Entry";
        UnitOfMeasure: Record "Unit of Measure";
        ProdBomHeader: Record "Production BOM Header";
        ProdBomVersion: Record "Production BOM Version";
        ProdBomLine: Record "Production BOM Line";
        RoutingHeader: Record "Routing Header";
        RoutingVersion: Record "Routing Version";
        RoutingLine: Record "Routing Line";
        WorkCenter: Record "Work Center";
    begin
        ProdBomLine.SetFilter("Production BOM No.", PrefixTok);
        ProdBomLine.DeleteAll(false);
        ProdBomVersion.SetFilter("Production BOM No.", PrefixTok);
        ProdBomVersion.DeleteAll(false);
        ProdBomHeader.SetFilter("No.", PrefixTok);
        ProdBomHeader.DeleteAll(false);
        RoutingLine.SetFilter("Routing No.", PrefixTok);
        RoutingLine.DeleteAll(false);
        RoutingVersion.SetFilter("Routing No.", PrefixTok);
        RoutingVersion.DeleteAll(false);
        RoutingHeader.SetFilter("No.", PrefixTok);
        RoutingHeader.DeleteAll(false);
        PlanningAssignment.SetFilter("Item No.", PrefixTok);
        PlanningAssignment.DeleteAll(false);
        ChangeLogEntry.SetFilter("Primary Key Field 1 Value", PrefixTok);
        ChangeLogEntry.DeleteAll(false);
        ItemUnitOfMeasure.SetFilter("Item No.", PrefixTok);
        ItemUnitOfMeasure.DeleteAll(false);
        Item.SetFilter("No.", PrefixTok);
        Item.DeleteAll(false);
        WorkCenter.SetFilter("No.", PrefixTok);
        WorkCenter.DeleteAll(false);
        if UnitOfMeasure.Get(UomCodeTok) then
            UnitOfMeasure.Delete(false);
        Commit();
    end;

    /// <summary>Seeds fresh, individually owned records for MCP and Web Client acceptance.</summary>
    procedure SeedVerificationData()
    begin
        // Fail on an existing key instead of replaying or overwriting a prior fixture.
        CreateItem('XMFG8MCP-COMP', '', '');
        CreateBomHeader('XMFG8MCP-BOM', Enum::"BOM Status"::New, true);
        CreateBomLine('XMFG8MCP-BOM', '', 10000, Enum::"Production BOM Line Type"::Item, 'XMFG8MCP-COMP');
        CreateBomVersion('XMFG8MCP-BOM', 'V1', Enum::"BOM Status"::"Under Development");
        CreateBomLine('XMFG8MCP-BOM', 'V1', 10000, Enum::"Production BOM Line Type"::Item, 'XMFG8MCP-COMP');
        CreateWorkCenter('XMFG8MCP-WC');
        CreateRoutingHeader('XMFG8MCP-RT', Enum::"Routing Status"::New, false);
        CreateRoutingLine('XMFG8MCP-RT', '', '10', 'XMFG8MCP-WC', '');
        CreateRoutingVersion('XMFG8MCP-RT', 'V1', Enum::"Routing Status"::"Under Development");
        CreateRoutingLine('XMFG8MCP-RT', 'V1', '10', 'XMFG8MCP-WC', '');
        CreateItem('XMFG8MCP-PARENT', 'XMFG8MCP-BOM', 'XMFG8MCP-RT');
        Commit();
    end;

    /// <summary>Deletes owned fixtures and asserts that all fixture tables are empty for the prefix.</summary>
    procedure SweepAndAssert()
    var
        Item: Record Item;
        ItemUnitOfMeasure: Record "Item Unit of Measure";
        PlanningAssignment: Record "Planning Assignment";
        ChangeLogEntry: Record "Change Log Entry";
        Bom: Record "Production BOM Header";
        BomVersion: Record "Production BOM Version";
        BomLine: Record "Production BOM Line";
        Routing: Record "Routing Header";
        RoutingVersion: Record "Routing Version";
        RoutingLine: Record "Routing Line";
        WorkCenter: Record "Work Center";
        UnitOfMeasure: Record "Unit of Measure";
    begin
        Sweep();
        Item.SetFilter("No.", PrefixTok);
        ItemUnitOfMeasure.SetFilter("Item No.", PrefixTok);
        PlanningAssignment.SetFilter("Item No.", PrefixTok);
        ChangeLogEntry.SetFilter("Primary Key Field 1 Value", PrefixTok);
        Bom.SetFilter("No.", PrefixTok);
        BomVersion.SetFilter("Production BOM No.", PrefixTok);
        BomLine.SetFilter("Production BOM No.", PrefixTok);
        Routing.SetFilter("No.", PrefixTok);
        RoutingVersion.SetFilter("Routing No.", PrefixTok);
        RoutingLine.SetFilter("Routing No.", PrefixTok);
        WorkCenter.SetFilter("No.", PrefixTok);
        UnitOfMeasure.SetRange(Code, UomCodeTok);
        Assert.AreEqual(0, Item.Count() + ItemUnitOfMeasure.Count() + PlanningAssignment.Count() + ChangeLogEntry.Count() + Bom.Count() + BomVersion.Count() + BomLine.Count() + Routing.Count() + RoutingVersion.Count() + RoutingLine.Count() + WorkCenter.Count() + UnitOfMeasure.Count(), 'No owned fixture records may remain.');
    end;

    /// <summary>A new XMFG8 number, twenty characters at most.</summary>
    procedure NewNo(): Code[20]
    begin
        exit(CopyStr(UomCodeTok + CopyStr(DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, 15), 1, 20));
    end;

    /// <summary>Dispatches a message type and returns the JSON answer.</summary>
    procedure Invoke(MessageType: Enum "Message Type ori"; RequestJson: JsonObject; OmitCommit: Boolean) ResponseJson: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        ResponseTempBlob: Codeunit "Temp Blob";
        RequestContent: BigText;
        ResponseStream: InStream;
        MessageId: Guid;
        TaskId: Guid;
        ResponseTime: Duration;
        RequestText: Text;
        ResponseText: Text;
        ResponseContentType: Text[100];
    begin
        RequestJson.WriteTo(RequestText);
        RequestContent.AddText(RequestText);
        Dispatcher.EnqueueAndProcess(MessageType, Enum::"Message Version ori"::"1.0", '', 'XMFG8', 'application/json', RequestContent, TaskId, GlobalLanguage(), MessageId, ResponseTempBlob, ResponseContentType, ResponseTime, OmitCommit);
        ResponseTempBlob.CreateInStream(ResponseStream, TextEncoding::UTF8);
        ResponseStream.ReadText(ResponseText);
        Assert.IsTrue(ResponseJson.ReadFrom(ResponseText), 'The dispatcher must answer with JSON: ' + ResponseText);
    end;

    /// <summary>Sends Manufacturing.ProductionBOM.SetStatus.</summary>
    procedure SetBomStatus(DocumentNo: Code[20]; VersionCode: Code[20]; StatusToken: Text; OmitCommit: Boolean) ResponseJson: JsonObject
    begin
        ResponseJson := Invoke(Enum::"Message Type ori"::"Manufacturing.ProductionBOM.SetStatus", StatusRequest(DocumentNo, VersionCode, StatusToken), OmitCommit);
        AssertPlatformNextStep(ResponseJson);
    end;

    /// <summary>Sends Manufacturing.Routing.SetStatus.</summary>
    procedure SetRoutingStatus(DocumentNo: Code[20]; VersionCode: Code[20]; StatusToken: Text; OmitCommit: Boolean) ResponseJson: JsonObject
    begin
        ResponseJson := Invoke(Enum::"Message Type ori"::"Manufacturing.Routing.SetStatus", StatusRequest(DocumentNo, VersionCode, StatusToken), OmitCommit);
        AssertPlatformNextStep(ResponseJson);
    end;

    local procedure AssertPlatformNextStep(ResponseJson: JsonObject)
    var
        CodeToken: JsonToken;
    begin
        if ResponseJson.Get('code', CodeToken) then
            if CodeToken.AsValue().AsText() = 'BusinessCentralError' then
                Assert.IsTrue(GetText(ResponseJson, 'nextStep').Contains('Data.Records.Set'), 'A manufacturing status validation error must explain how to correct the lines.');
    end;

    /// <summary>Asserts a Success answer.</summary>
    procedure AssertSuccess(ResponseJson: JsonObject)
    var
        ResponseText: Text;
    begin
        ResponseJson.WriteTo(ResponseText);
        Assert.AreEqual('Success', GetText(ResponseJson, 'status'), 'Expected Success: ' + ResponseText);
    end;

    /// <summary>Asserts an error answer with the given code and a fragment of the text.</summary>
    procedure AssertRefusal(ResponseJson: JsonObject; ExpectedCode: Text; ExpectedFragment: Text)
    var
        ResponseText: Text;
    begin
        ResponseJson.WriteTo(ResponseText);
        Assert.AreEqual('Error', GetText(ResponseJson, 'status'), 'Expected a refusal: ' + ResponseText);
        Assert.AreEqual(ExpectedCode, GetText(ResponseJson, 'code'), 'Unexpected error code: ' + ResponseText);
        Assert.IsTrue(ResponseText.Contains(ExpectedFragment), 'The refusal must contain ''' + ExpectedFragment + ''': ' + ResponseText);
    end;

    /// <summary>Reads a text property. Fails when it is missing.</summary>
    procedure GetText(ResponseJson: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(ResponseJson.Get(PropertyName, Token), 'Missing response property: ' + PropertyName);
        exit(Token.AsValue().AsText());
    end;

    /// <summary>Reads a boolean property. Fails when it is missing.</summary>
    procedure GetBoolean(ResponseJson: JsonObject; PropertyName: Text): Boolean
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(ResponseJson.Get(PropertyName, Token), 'Missing response property: ' + PropertyName);
        exit(Token.AsValue().AsBoolean());
    end;

    /// <summary>Reads an integer property. Fails when it is missing.</summary>
    procedure GetInteger(ResponseJson: JsonObject; PropertyName: Text): Integer
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(ResponseJson.Get(PropertyName, Token), 'Missing response property: ' + PropertyName);
        exit(Token.AsValue().AsInteger());
    end;

    /// <summary>True when the response has the property.</summary>
    procedure HasProperty(ResponseJson: JsonObject; PropertyName: Text): Boolean
    begin
        exit(ResponseJson.Contains(PropertyName));
    end;

    /// <summary>
    /// Sets Manufacturing Setup "Dynamic Low-Level Code" and returns the previous value.
    /// The production BOM circular check runs only while this field is false.
    /// </summary>
    /// <param name="Enabled">The value to store.</param>
    /// <returns>The value before the change.</returns>
    procedure SetDynamicLowLevelCode(Enabled: Boolean) Previous: Boolean
    var
        ManufacturingSetup: Record "Manufacturing Setup";
    begin
        ManufacturingSetup.Get();
        Previous := ManufacturingSetup."Dynamic Low-Level Code";
        if Previous = Enabled then
            exit;
        ManufacturingSetup."Dynamic Low-Level Code" := Enabled;
        ManufacturingSetup.Modify(false);
    end;

    /// <summary>Inserts the shared unit of measure when it is missing.</summary>
    procedure EnsureUnitOfMeasure()
    var
        UnitOfMeasure: Record "Unit of Measure";
    begin
        if UnitOfMeasure.Get(UomCodeTok) then
            exit;
        UnitOfMeasure.Init();
        UnitOfMeasure.Code := UomCodeTok;
        UnitOfMeasure.Description := UomCodeTok;
        UnitOfMeasure.Insert(false);
    end;

    /// <summary>Inserts an item and its unit of measure. Optional BOM and routing numbers are stored on the item.</summary>
    procedure CreateItem(ItemNo: Code[20]; BomNo: Code[20]; RoutingNo: Code[20])
    var
        Item: Record Item;
        ItemUnitOfMeasure: Record "Item Unit of Measure";
    begin
        EnsureUnitOfMeasure();
        Item.Init();
        Item."No." := ItemNo;
        Item.Description := ItemNo;
        Item."Base Unit of Measure" := UomCodeTok;
        if BomNo <> '' then
            Item."Production BOM No." := BomNo;
        if RoutingNo <> '' then
            Item."Routing No." := RoutingNo;
        Item.Insert(false);
        ItemUnitOfMeasure.Init();
        ItemUnitOfMeasure."Item No." := ItemNo;
        ItemUnitOfMeasure.Code := UomCodeTok;
        ItemUnitOfMeasure."Qty. per Unit of Measure" := 1;
        ItemUnitOfMeasure.Insert(false);
    end;

    /// <summary>Inserts a production BOM header. Status is assigned, not validated.</summary>
    procedure CreateBomHeader(BomNo: Code[20]; Status: Enum "BOM Status"; WithUnitOfMeasure: Boolean)
    var
        Header: Record "Production BOM Header";
    begin
        EnsureUnitOfMeasure();
        Header.Init();
        Header."No." := BomNo;
        Header.Description := BomNo;
        if WithUnitOfMeasure then
            Header."Unit of Measure Code" := UomCodeTok;
        Header.Status := Status;
        Header.Insert(false);
    end;

    /// <summary>Inserts one production BOM line without validating status.</summary>
    procedure CreateBomLine(BomNo: Code[20]; VersionCode: Code[20]; LineNo: Integer; LineType: Enum "Production BOM Line Type"; ComponentNo: Code[20])
    var
        Line: Record "Production BOM Line";
    begin
        Line.Init();
        Line."Production BOM No." := BomNo;
        Line."Version Code" := VersionCode;
        Line."Line No." := LineNo;
        Line.Type := LineType;
        Line."No." := ComponentNo;
        Line.Description := ComponentNo;
        Line."Quantity per" := 1;
        if ComponentNo <> '' then
            Line."Unit of Measure Code" := UomCodeTok;
        Line.Insert(false);
    end;

    /// <summary>Inserts a production BOM version. Status is assigned, not validated.</summary>
    procedure CreateBomVersion(BomNo: Code[20]; VersionCode: Code[20]; Status: Enum "BOM Status")
    var
        Version: Record "Production BOM Version";
    begin
        EnsureUnitOfMeasure();
        Version.Init();
        Version."Production BOM No." := BomNo;
        Version."Version Code" := VersionCode;
        Version.Description := VersionCode;
        Version."Unit of Measure Code" := UomCodeTok;
        Version.Status := Status;
        Version.Insert(false);
    end;

    /// <summary>Inserts an unblocked work center.</summary>
    procedure CreateWorkCenter(WorkCenterNo: Code[20])
    var
        WorkCenter: Record "Work Center";
    begin
        WorkCenter.Init();
        WorkCenter."No." := WorkCenterNo;
        WorkCenter.Name := WorkCenterNo;
        WorkCenter.Blocked := false;
        WorkCenter.Insert(false);
    end;

    /// <summary>Inserts a routing header. Status is assigned, not validated.</summary>
    procedure CreateRoutingHeader(RoutingNo: Code[20]; Status: Enum "Routing Status"; Parallel: Boolean)
    var
        Header: Record "Routing Header";
    begin
        Header.Init();
        Header."No." := RoutingNo;
        Header.Description := RoutingNo;
        Header.Status := Status;
        if Parallel then
            Header.Type := Header.Type::Parallel
        else
            Header.Type := Header.Type::Serial;
        Header.Insert(false);
    end;

    /// <summary>Inserts a routing line that names a work center. Next operation is left as sent.</summary>
    procedure CreateRoutingLine(RoutingNo: Code[20]; VersionCode: Code[20]; OperationNo: Code[10]; WorkCenterNo: Code[20]; NextOperationNo: Code[30])
    var
        RoutingLine: Record "Routing Line";
    begin
        RoutingLine.Init();
        RoutingLine."Routing No." := RoutingNo;
        RoutingLine."Version Code" := VersionCode;
        RoutingLine."Operation No." := OperationNo;
        RoutingLine.Type := RoutingLine.Type::"Work Center";
        RoutingLine."No." := WorkCenterNo;
        RoutingLine."Next Operation No." := NextOperationNo;
        RoutingLine.Insert(false);
    end;

    /// <summary>Inserts a routing version. Status is assigned, not validated.</summary>
    procedure CreateRoutingVersion(RoutingNo: Code[20]; VersionCode: Code[20]; Status: Enum "Routing Status")
    var
        Version: Record "Routing Version";
    begin
        Version.Init();
        Version."Routing No." := RoutingNo;
        Version."Version Code" := VersionCode;
        Version.Description := VersionCode;
        Version.Status := Status;
        Version.Insert(false);
    end;

    /// <summary>Writes one field through Data.Records.Set, identified by system id.</summary>
    procedure SetField(TableName: Text; SystemId: Guid; FieldName: Text; FieldValue: Text) ResponseJson: JsonObject
    var
        ChangeLogSetup: Record "Change Log Setup";
        PreviousSetup: Record "Change Log Setup";
        ChangeLogTable: Record "Change Log Setup (Table)";
        PreviousTable: Record "Change Log Setup (Table)";
        RequestJson: JsonObject;
        RecordJson: JsonObject;
        FieldsJson: JsonObject;
        DataJson: JsonArray;
        HadSetup: Boolean;
        HadTable: Boolean;
        TableId: Integer;
    begin
        // Cover these owned fixtures using the standard change log, not a guard bypass.
        case TableName of
            'Production BOM Header':
                TableId := Database::"Production BOM Header";
            'Production BOM Version':
                TableId := Database::"Production BOM Version";
            'Production BOM Line':
                TableId := Database::"Production BOM Line";
            'Routing Header':
                TableId := Database::"Routing Header";
            'Routing Version':
                TableId := Database::"Routing Version";
        end;
        HadSetup := ChangeLogSetup.Get();
        PreviousSetup := ChangeLogSetup;
        if not HadSetup then
            ChangeLogSetup.Insert();
        ChangeLogSetup."Change Log Activated" := true;
        ChangeLogSetup.Modify();
        HadTable := ChangeLogTable.Get(TableId);
        PreviousTable := ChangeLogTable;
        if not HadTable then begin
            ChangeLogTable.Init();
            ChangeLogTable."Table No." := TableId;
            ChangeLogTable.Insert();
        end;
        ChangeLogTable."Log Modification" := ChangeLogTable."Log Modification"::"All Fields";
        ChangeLogTable.Modify();
        FieldsJson.Add(FieldName, FieldValue);
        RecordJson.Add('id', Format(SystemId, 0, 4));
        RecordJson.Add('fields', FieldsJson);
        DataJson.Add(RecordJson);
        RequestJson.Add('tableName', TableName);
        RequestJson.Add('data', DataJson);
        ResponseJson := Invoke(Enum::"Message Type ori"::"Data.Records.Set", RequestJson, false);
        if HadTable then begin
            ChangeLogTable := PreviousTable;
            ChangeLogTable.Modify();
        end else
            ChangeLogTable.Delete();
        if HadSetup then begin
            ChangeLogSetup := PreviousSetup;
            ChangeLogSetup.Modify();
        end else
            ChangeLogSetup.Delete();
    end;

    /// <summary>Reads one page through Data.Records.Get. Proves the table is not hidden.</summary>
    procedure GetTable(TableName: Text) ResponseJson: JsonObject
    var
        RequestJson: JsonObject;
    begin
        RequestJson.Add('tableName', TableName);
        RequestJson.Add('take', 1);
        ResponseJson := Invoke(Enum::"Message Type ori"::"Data.Records.Get", RequestJson, true);
    end;

    local procedure StatusRequest(DocumentNo: Code[20]; VersionCode: Code[20]; StatusToken: Text) RequestJson: JsonObject
    begin
        if DocumentNo <> '' then
            RequestJson.Add('no', DocumentNo);
        if VersionCode <> '' then
            RequestJson.Add('versionCode', VersionCode);
        if StatusToken <> '' then
            RequestJson.Add('status', StatusToken);
    end;
}
