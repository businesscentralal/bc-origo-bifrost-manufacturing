namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Foundation.UOM;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Planning;
using Microsoft.Manufacturing.ProductionBOM;
using Origo.Bifrost;
using System.Diagnostics;
using System.TestLibraries.Utilities;

/// <summary>Builds and removes an owned two-level structure from raw records for issue 29.</summary>
codeunit 97650 "Mfg WhereUsed Fixture ori"
{
    Access = Internal;

    /// <summary>Seeds a leaf, a subassembly containing three leaves, and a top assembly containing two subassemblies.</summary>
    /// <param name="Prefix">An owned X29 prefix of at most ten characters.</param>
    procedure Seed(Prefix: Code[10])
    var
        Unit: Record "Unit of Measure";
    begin
        CheckPrefix(Prefix);
        Unit.Init();
        Unit.Code := Prefix;
        Unit.Description := Prefix;
        Unit.Insert(false);
        CreateItem(Prefix + 'LEAF', '', Prefix);
        CreateItem(Prefix + 'NEW', '', Prefix);
        CreateItem(Prefix + 'SUB', Prefix + 'BOM1', Prefix);
        CreateItem(Prefix + 'TOP', Prefix + 'BOM2', Prefix);
        CreateBom(Prefix + 'BOM1', Prefix + 'LEAF', Prefix, 3);
        CreateBom(Prefix + 'BOM2', Prefix + 'SUB', Prefix, 2);
    end;

    /// <summary>Deletes only this fixture's raw records; refuses a foreign prefix.</summary>
    /// <param name="Prefix">The owned X29 prefix.</param>
    procedure Cleanup(Prefix: Code[10])
    var
        Item: Record Item;
        ItemUnit: Record "Item Unit of Measure";
        Unit: Record "Unit of Measure";
        Header: Record "Production BOM Header";
        Version: Record "Production BOM Version";
        Line: Record "Production BOM Line";
        Planning: Record "Planning Assignment";
        ChangeLogEntry: Record "Change Log Entry";
    begin
        CheckPrefix(Prefix);
        ChangeLogEntry.SetFilter("Primary Key Field 1 Value", Prefix + '*');
        ChangeLogEntry.DeleteAll(false);
        Line.SetFilter("Production BOM No.", '%1|%2', Prefix + 'BOM1', Prefix + 'BOM2');
        Line.DeleteAll(false);
        Version.SetFilter("Production BOM No.", '%1|%2', Prefix + 'BOM1', Prefix + 'BOM2');
        Version.DeleteAll(false);
        Header.SetFilter("No.", '%1|%2', Prefix + 'BOM1', Prefix + 'BOM2');
        Header.DeleteAll(false);
        ItemUnit.SetFilter("Item No.", '%1|%2|%3|%4', Prefix + 'LEAF', Prefix + 'SUB', Prefix + 'TOP', Prefix + 'NEW');
        ItemUnit.DeleteAll(false);
        Planning.SetFilter("Item No.", '%1|%2|%3|%4', Prefix + 'LEAF', Prefix + 'SUB', Prefix + 'TOP', Prefix + 'NEW');
        Planning.DeleteAll(false);
        Item.SetFilter("No.", '%1|%2|%3|%4', Prefix + 'LEAF', Prefix + 'SUB', Prefix + 'TOP', Prefix + 'NEW');
        Item.DeleteAll(false);
        if Unit.Get(Prefix) then
            Unit.Delete(false);
    end;

    /// <summary>Probes the native processing-only exchange entry point on owned raw data.</summary>
    /// <param name="Prefix">The owned fixture prefix.</param>
    procedure ProbeNativeExchange(Prefix: Code[10])
    var
        Exchange: Report "Exchange Production BOM Item";
        Parameters: Text;
    begin
        CheckPrefix(Prefix);
        Parameters := StrSubstNo(
            '<?xml version="1.0" standalone="yes"?><ReportParameters name="Exchange Production BOM Item" id="99001043"><Options>' +
            '<Field name="FromProductionBOMLineType">1</Field><Field name="FromProductionBOMNo">%1LEAF</Field>' +
            '<Field name="ToProductionBOMLineType">1</Field><Field name="ToProductionBOMNo">%1NEW</Field>' +
            '<Field name="CreateNewVersion">true</Field><Field name="QtyMultiply">2</Field>' +
            '<Field name="StartingDate">%2</Field><Field name="Recertify">false</Field>' +
            '<Field name="CopyRoutingLink">true</Field><Field name="DeleteExcComp">false</Field>' +
            '</Options><DataItems /></ReportParameters>', Prefix, Format(Today(), 0, 9));
        Exchange.Execute(Parameters);
    end;

    local procedure CheckPrefix(Prefix: Code[10])
    begin
        if (CopyStr(Prefix, 1, 3) <> 'X29') or (StrLen(Prefix) < 5) then
            Error('An owned issue 29 fixture prefix is required.');
    end;

    local procedure CreateItem(ItemNo: Code[20]; BomNo: Code[20]; UnitCode: Code[10])
    var
        Item: Record Item;
        ItemUnit: Record "Item Unit of Measure";
    begin
        Item.Init();
        Item."No." := ItemNo;
        Item.Description := ItemNo;
        Item."Base Unit of Measure" := UnitCode;
        if BomNo <> '' then begin
            Item."Replenishment System" := Item."Replenishment System"::"Prod. Order";
            Item."Production BOM No." := BomNo;
        end;
        Item.Insert(false);
        ItemUnit.Init();
        ItemUnit."Item No." := ItemNo;
        ItemUnit.Code := UnitCode;
        ItemUnit."Qty. per Unit of Measure" := 1;
        ItemUnit.Insert(false);
    end;

    local procedure CreateBom(BomNo: Code[20]; ComponentNo: Code[20]; UnitCode: Code[10]; Quantity: Decimal)
    var
        Header: Record "Production BOM Header";
        Line: Record "Production BOM Line";
        Lib: Codeunit "BOM Routing Test Lib ori";
        Response: JsonObject;
    begin
        Header.Init();
        Header."No." := BomNo;
        Header.Description := BomNo;
        Header."Unit of Measure Code" := UnitCode;
        Header.Status := Header.Status::"Under Development";
        Header.Insert(false);
        Line.Init();
        Line."Production BOM No." := BomNo;
        Line."Line No." := 10000;
        Line.Type := Line.Type::Item;
        Line."No." := ComponentNo;
        Line."Unit of Measure Code" := UnitCode;
        Line.Validate("Quantity per", Quantity);
        Line.Insert(false);
        Commit();
        Response := Lib.SetBomStatus(BomNo, '', 'Certified', false);
        Lib.AssertSuccess(Response);
    end;
}
