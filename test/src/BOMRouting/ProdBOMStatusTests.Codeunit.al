namespace Origo.Bifrost.Manufacturing.Test;

using Origo.Bifrost.Foundation;
using Microsoft.Manufacturing.ProductionBOM;
using Microsoft.Inventory.Item;
using System.TestLibraries.Utilities;

codeunit 97660 "Prod BOM Status Tests ori"
{
    Subtype = Test;

    var
        LibraryManufacturing: Codeunit "Library - Manufacturing";
        LibraryAssert: Codeunit "Library Assert";
        Dispatcher: Codeunit "Dispatcher ori";

    [Test]
    procedure SetStatusCertifiedOnValidBOM()
    var
        ProductionBOMHeader: Record "Production BOM Header";
        ProductionBOMLine: Record "Production BOM Line";
        Item: Record Item;
        Response: Record "Message Response ori";
        RequestData: JsonObject;
    begin
        LibraryManufacturing.CreateProductionBOMHeader(ProductionBOMHeader, '');
        LibraryManufacturing.CreateItem(Item);
        LibraryManufacturing.CreateProductionBOMLine(ProductionBOMHeader, ProductionBOMLine, '', ProductionBOMLine.Type::Item, Item."No.", 1);
        
        RequestData.Add('no', ProductionBOMHeader."No.");
        RequestData.Add('status', 'Certified');

        Dispatcher.RunBifrostCall(Enum::"Message Type ori"::"Manufacturing.ProductionBOM.SetStatus", RequestData, Response);
        LibraryAssert.AreEqual(Enum::"Message Response Status ori"::Success, Response.Status, 'Status');
        
        ProductionBOMHeader.Get(ProductionBOMHeader."No.");
        LibraryAssert.AreEqual(ProductionBOMHeader.Status::Certified, ProductionBOMHeader.Status, 'BOM Status');
        
        LibraryAssert.AreEqual('New', Response.GetResponseString('previousStatus'), 'previousStatus');
        LibraryAssert.AreEqual('Certified', Response.GetResponseString('status'), 'status');
        LibraryAssert.IsTrue(Response.GetResponseBoolean('changed'), 'changed');
        LibraryAssert.IsTrue(Response.GetResponseInteger('lowLevelCode') >= 0, 'lowLevelCode');
        LibraryAssert.AreEqual(0, Response.GetResponseInteger('usedOnItems'), 'usedOnItems');
    end;

    [Test]
    procedure SetStatusUnderDevelopmentOnCertifiedBOM()
    var
        ProductionBOMHeader: Record "Production BOM Header";
        Response: Record "Message Response ori";
        RequestData: JsonObject;
    begin
        LibraryManufacturing.CreateCertifiedProductionBOM(ProductionBOMHeader, '', '');
        
        RequestData.Add('no', ProductionBOMHeader."No.");
        RequestData.Add('status', 'UnderDevelopment');

        Dispatcher.RunBifrostCall(Enum::"Message Type ori"::"Manufacturing.ProductionBOM.SetStatus", RequestData, Response);
        LibraryAssert.AreEqual(Enum::"Message Response Status ori"::Success, Response.Status, 'Status');
        
        ProductionBOMHeader.Get(ProductionBOMHeader."No.");
        LibraryAssert.AreEqual(ProductionBOMHeader.Status::"Under Development", ProductionBOMHeader.Status, 'BOM Status');
        
        LibraryAssert.AreEqual('Certified', Response.GetResponseString('previousStatus'), 'previousStatus');
        LibraryAssert.AreEqual('UnderDevelopment', Response.GetResponseString('status'), 'status');
        LibraryAssert.IsTrue(Response.GetResponseBoolean('changed'), 'changed');
    end;

    [Test]
    procedure CertifyingBOMWithEmptyComponentFails()
    var
        ProductionBOMHeader: Record "Production BOM Header";
        ProductionBOMLine: Record "Production BOM Line";
        Response: Record "Message Response ori";
        RequestData: JsonObject;
    begin
        LibraryManufacturing.CreateProductionBOMHeader(ProductionBOMHeader, '');
        // Line with no item no.
        LibraryManufacturing.CreateProductionBOMLine(ProductionBOMHeader, ProductionBOMLine, '', ProductionBOMLine.Type::Item, '', 1);
        
        RequestData.Add('no', ProductionBOMHeader."No.");
        RequestData.Add('status', 'Certified');

        Dispatcher.RunBifrostCall(Enum::"Message Type ori"::"Manufacturing.ProductionBOM.SetStatus", RequestData, Response);
        LibraryAssert.AreEqual(Enum::"Message Response Status ori"::Error, Response.Status, 'Status');
        LibraryAssert.AreEqual('BusinessCentralError', Response.ErrorType, 'ErrorType');
        
        ProductionBOMHeader.Get(ProductionBOMHeader."No.");
        LibraryAssert.AreEqual(ProductionBOMHeader.Status::New, ProductionBOMHeader.Status, 'BOM Status unchanged');
    end;

    [Test]
    procedure SameStatusReturnsUnchanged()
    var
        ProductionBOMHeader: Record "Production BOM Header";
        Response: Record "Message Response ori";
        RequestData: JsonObject;
    begin
        LibraryManufacturing.CreateCertifiedProductionBOM(ProductionBOMHeader, '', '');
        
        RequestData.Add('no', ProductionBOMHeader."No.");
        RequestData.Add('status', 'Certified');

        Dispatcher.RunBifrostCall(Enum::"Message Type ori"::"Manufacturing.ProductionBOM.SetStatus", RequestData, Response);
        LibraryAssert.AreEqual(Enum::"Message Response Status ori"::Success, Response.Status, 'Status');
        
        LibraryAssert.IsFalse(Response.GetResponseBoolean('changed'), 'changed');
        LibraryAssert.AreEqual('Certified', Response.GetResponseString('previousStatus'), 'previousStatus');
    end;

    [Test]
    procedure StatusClosedIsRefused()
    var
        ProductionBOMHeader: Record "Production BOM Header";
        Response: Record "Message Response ori";
        RequestData: JsonObject;
    begin
        LibraryManufacturing.CreateProductionBOMHeader(ProductionBOMHeader, '');
        
        RequestData.Add('no', ProductionBOMHeader."No.");
        RequestData.Add('status', 'Closed');

        Dispatcher.RunBifrostCall(Enum::"Message Type ori"::"Manufacturing.ProductionBOM.SetStatus", RequestData, Response);
        LibraryAssert.AreEqual(Enum::"Message Response Status ori"::Error, Response.Status, 'Status');
        LibraryAssert.AreEqual('InvalidParameter', Response.ErrorType, 'ErrorType');
    end;

    [Test]
    procedure MissingParametersRefused()
    var
        Response: Record "Message Response ori";
        RequestData: JsonObject;
    begin
        RequestData.Add('no', 'BOM1');
        // Missing status
        Dispatcher.RunBifrostCall(Enum::"Message Type ori"::"Manufacturing.ProductionBOM.SetStatus", RequestData, Response);
        LibraryAssert.AreEqual(Enum::"Message Response Status ori"::Error, Response.Status, 'Status');
        LibraryAssert.AreEqual('MissingParameter', Response.ErrorType, 'ErrorType');
    end;
}
