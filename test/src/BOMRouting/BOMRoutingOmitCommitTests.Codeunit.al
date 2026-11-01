namespace Origo.Bifrost.Manufacturing.Test;

using Origo.Bifrost.Foundation;
using Microsoft.Manufacturing.ProductionBOM;
using Microsoft.Inventory.Item;
using System.TestLibraries.Utilities;

codeunit 97665 "BOM Routing OmitCommit Tests ori"
{
    Subtype = Test;

    var
        LibraryManufacturing: Codeunit "Library - Manufacturing";
        LibraryAssert: Codeunit "Library Assert";
        Dispatcher: Codeunit "Dispatcher ori";

    [Test]
    procedure StatusChangeDoesNotCommitAndIsRolledBack()
    var
        ProductionBOMHeader: Record "Production BOM Header";
        ProductionBOMLine: Record "Production BOM Line";
        ProductionBOMVersion: Record "Production BOM Version";
        Item: Record Item;
        Response: Record "Message Response ori";
        RequestData: JsonObject;
        BOMNo: Code[20];
    begin
        LibraryManufacturing.CreateProductionBOMHeader(ProductionBOMHeader, '');
        BOMNo := ProductionBOMHeader."No.";
        LibraryManufacturing.CreateItem(Item);
        LibraryManufacturing.CreateProductionBOMLine(ProductionBOMHeader, ProductionBOMLine, '', ProductionBOMLine.Type::Item, Item."No.", 1);
        
        // Create version
        ProductionBOMVersion.Init();
        ProductionBOMVersion."Production BOM No." := BOMNo;
        ProductionBOMVersion."Version Code" := 'V1';
        ProductionBOMVersion.Status := ProductionBOMVersion.Status::"Under Development";
        ProductionBOMVersion.Insert(true);

        RequestData.Add('no', BOMNo);
        RequestData.Add('versionCode', 'V1');
        RequestData.Add('status', 'Certified');

        Dispatcher.RunBifrostCallOmitCommit(Enum::"Message Type ori"::"Manufacturing.ProductionBOM.SetStatus", RequestData, Response);
        LibraryAssert.AreEqual(Enum::"Message Response Status ori"::Success, Response.Status, 'Status');

        // Rollback
        asserterror Error('Rollback');

        // Verify version status is back to Under Development
        ProductionBOMVersion.Get(BOMNo, 'V1');
        LibraryAssert.AreEqual(ProductionBOMVersion.Status::"Under Development", ProductionBOMVersion.Status, 'Version Status Rolled Back');
    end;
}
