namespace Origo.Bifrost.Manufacturing.Test;

using Origo.Bifrost.Foundation;
using Microsoft.Manufacturing.ProductionBOM;
using Microsoft.Manufacturing.Routing;
using System.TestLibraries.Utilities;

codeunit 97662 "BOM Routing Restrict Tests ori"
{
    Subtype = Test;

    var
        LibraryManufacturing: Codeunit "Library - Manufacturing";
        LibraryAssert: Codeunit "Library Assert";
        Dispatcher: Codeunit "Dispatcher ori";

    [Test]
    procedure DataRecordsSetRefusedOnBOMStatus()
    var
        ProductionBOMHeader: Record "Production BOM Header";
        Response: Record "Message Response ori";
        RequestData: JsonObject;
    begin
        LibraryManufacturing.CreateProductionBOMHeader(ProductionBOMHeader, '');
        
        RequestData.Add('table', 'Production BOM Header');
        RequestData.Add('no', ProductionBOMHeader."No.");
        RequestData.Add('Status', 'Certified');

        Dispatcher.RunBifrostCall(Enum::"Message Type ori"::"Data.Records.Set", RequestData, Response);
        LibraryAssert.AreEqual(Enum::"Message Response Status ori"::Error, Response.Status, 'Status');
        LibraryAssert.AreEqual('BlockedByWriteGuard', Response.ErrorType, 'ErrorType');
        LibraryAssert.IsTrue(Response.NextStep.Contains('SetStatus'), 'NextStep contains SetStatus hint');
    end;

    [Test]
    procedure DataRecordsSetRefusedOnBOMVersionStatus()
    var
        ProductionBOMVersion: Record "Production BOM Version";
        Response: Record "Message Response ori";
        RequestData: JsonObject;
    begin
        // Insert dummy version
        ProductionBOMVersion.Init();
        ProductionBOMVersion."Production BOM No." := 'BOM1';
        ProductionBOMVersion."Version Code" := 'V1';
        ProductionBOMVersion.Insert();
        
        RequestData.Add('table', 'Production BOM Version');
        RequestData.Add('Production BOM No.', 'BOM1');
        RequestData.Add('Version Code', 'V1');
        RequestData.Add('Status', 'Certified');

        Dispatcher.RunBifrostCall(Enum::"Message Type ori"::"Data.Records.Set", RequestData, Response);
        LibraryAssert.AreEqual(Enum::"Message Response Status ori"::Error, Response.Status, 'Status');
        LibraryAssert.AreEqual('BlockedByWriteGuard', Response.ErrorType, 'ErrorType');
        LibraryAssert.IsTrue(Response.NextStep.Contains('SetStatus'), 'NextStep contains SetStatus hint');
    end;

    [Test]
    procedure DataRecordsSetRefusedOnRoutingStatus()
    var
        RoutingHeader: Record "Routing Header";
        Response: Record "Message Response ori";
        RequestData: JsonObject;
    begin
        LibraryManufacturing.CreateRoutingHeader(RoutingHeader, '');
        
        RequestData.Add('table', 'Routing Header');
        RequestData.Add('no', RoutingHeader."No.");
        RequestData.Add('Status', 'Certified');

        Dispatcher.RunBifrostCall(Enum::"Message Type ori"::"Data.Records.Set", RequestData, Response);
        LibraryAssert.AreEqual(Enum::"Message Response Status ori"::Error, Response.Status, 'Status');
        LibraryAssert.AreEqual('BlockedByWriteGuard', Response.ErrorType, 'ErrorType');
        LibraryAssert.IsTrue(Response.NextStep.Contains('SetStatus'), 'NextStep contains SetStatus hint');
    end;

    [Test]
    procedure DataRecordsSetRefusedOnRoutingVersionStatus()
    var
        RoutingVersion: Record "Routing Version";
        Response: Record "Message Response ori";
        RequestData: JsonObject;
    begin
        // Insert dummy version
        RoutingVersion.Init();
        RoutingVersion."Routing No." := 'RTG1';
        RoutingVersion."Version Code" := 'V1';
        RoutingVersion.Insert();
        
        RequestData.Add('table', 'Routing Version');
        RequestData.Add('Routing No.', 'RTG1');
        RequestData.Add('Version Code', 'V1');
        RequestData.Add('Status', 'Certified');

        Dispatcher.RunBifrostCall(Enum::"Message Type ori"::"Data.Records.Set", RequestData, Response);
        LibraryAssert.AreEqual(Enum::"Message Response Status ori"::Error, Response.Status, 'Status');
        LibraryAssert.AreEqual('BlockedByWriteGuard', Response.ErrorType, 'ErrorType');
        LibraryAssert.IsTrue(Response.NextStep.Contains('SetStatus'), 'NextStep contains SetStatus hint');
    end;

    [Test]
    procedure DataRecordsSetAllowedOnOtherFields()
    var
        ProductionBOMHeader: Record "Production BOM Header";
        Response: Record "Message Response ori";
        RequestData: JsonObject;
    begin
        LibraryManufacturing.CreateProductionBOMHeader(ProductionBOMHeader, '');
        
        RequestData.Add('table', 'Production BOM Header');
        RequestData.Add('no', ProductionBOMHeader."No.");
        RequestData.Add('Description', 'New description');

        Dispatcher.RunBifrostCall(Enum::"Message Type ori"::"Data.Records.Set", RequestData, Response);
        LibraryAssert.AreEqual(Enum::"Message Response Status ori"::Success, Response.Status, 'Status');
        
        ProductionBOMHeader.Get(ProductionBOMHeader."No.");
        LibraryAssert.AreEqual('New description', ProductionBOMHeader.Description, 'Description');
    end;
}
