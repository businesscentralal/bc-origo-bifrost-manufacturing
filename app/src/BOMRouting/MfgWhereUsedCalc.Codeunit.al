namespace Origo.Bifrost.Manufacturing;

using Microsoft.Inventory.Item;
using Microsoft.Manufacturing.ProductionBOM;
using Origo.Bifrost;

/// <summary>Validates a where-used request and reads the native temporary calculation.</summary>
codeunit 10077104 "Mfg WhereUsed Calc ori"
{
    Access = Internal;

    /// <summary>Returns assemblies using the requested item or BOM. No persistent records are changed.</summary>
    /// <param name="Argument">The dispatcher argument.</param>
    internal procedure Apply(var Argument: Record "Message Argument ori")
    var
        Gate: Record "Mfg Write Gate ori";
        Item: Record Item;
        Header: Record "Production BOM Header";
        Line: Record "Production BOM Line";
        Version: Record "Production BOM Version";
        Contract: Codeunit "Mfg WhereUsed Contract ori";
        Kind: Text;
        DocumentNo: Code[20];
        CalculationDate: Date;
        MultiLevel: Boolean;
        Uses: JsonArray;
        Response: JsonObject;
    begin
        if not Gate.ReadPermission() then begin
            Contract.Fail(Argument, "Bifrost Error Code ori"::PermissionDenied, 'type');
            exit;
        end;
        if not Contract.ReadRequest(Argument, Kind, DocumentNo, CalculationDate, MultiLevel) then
            exit;
        if not (Item.ReadPermission() and Header.ReadPermission() and Line.ReadPermission() and Version.ReadPermission()) then begin
            Contract.Fail(Argument, "Bifrost Error Code ori"::PermissionDenied, 'type');
            exit;
        end;
        Item.SetLoadFields("No.", "Production BOM No.");
        Header.SetLoadFields("No.");
        if Kind = 'item' then begin
            if not Item.Get(DocumentNo) then begin
                Contract.Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, 'no');
                exit;
            end;
        end else
            if not Header.Get(DocumentNo) then begin
                Contract.Fail(Argument, "Bifrost Error Code ori"::RecordNotFound, 'no');
                exit;
            end;
        if not TryCalculate(Kind, Item, Header, CalculationDate, MultiLevel, Uses) then begin
            Contract.FailCalculation(Argument, GetLastErrorText());
            exit;
        end;
        Response.Add('status', 'Success');
        Response.Add('uses', Uses);
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    [TryFunction]
    local procedure TryCalculate(Kind: Text; Item: Record Item; Header: Record "Production BOM Header"; CalculationDate: Date; MultiLevel: Boolean; var Uses: JsonArray)
    var
        TempResult: Record "Where-Used Line" temporary;
        Assembly: Record Item;
        WhereUsed: Codeunit "Where-Used Management";
        UseEntry: JsonObject;
    begin
        if Kind = 'item' then
            WhereUsed.WhereUsedFromItem(Item, CalculationDate, MultiLevel)
        else
            WhereUsed.WhereUsedFromProdBOM(Header, CalculationDate, MultiLevel);
        Assembly.SetLoadFields("Production BOM No.");
        if WhereUsed.FindRecord('-', TempResult) then
            repeat
                Clear(UseEntry);
                UseEntry.Add('itemNo', TempResult."Item No.");
                UseEntry.Add('description', TempResult.Description);
                // Native results name the owning item; the BOM field is not filled by the native calculation.
                Assembly.Get(TempResult."Item No.");
                UseEntry.Add('productionBomNo', Assembly."Production BOM No.");
                UseEntry.Add('versionCode', TempResult."Version Code");
                UseEntry.Add('level', TempResult."Level Code");
                UseEntry.Add('quantityNeeded', TempResult."Quantity Needed");
                Uses.Add(UseEntry);
            until WhereUsed.NextRecord(1, TempResult) = 0;
    end;
}
