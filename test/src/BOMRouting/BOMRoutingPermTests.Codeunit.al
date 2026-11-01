namespace Origo.Bifrost.Manufacturing.Test;

using Origo.Bifrost.Foundation;
using Microsoft.Manufacturing.ProductionBOM;
using Microsoft.Manufacturing.Routing;
using System.TestLibraries.Security.AccessControl;
using System.TestLibraries.Utilities;

codeunit 97664 "BOM Routing Perm Tests ori"
{
    Subtype = Test;

    var
        LibraryManufacturing: Codeunit "Library - Manufacturing";
        LibraryAssert: Codeunit "Library Assert";
        PermissionsMock: Codeunit "Permissions Mock";
        Dispatcher: Codeunit "Dispatcher ori";

    [Test]
    procedure MfgReadCannotSetStatus()
    var
        ProductionBOMHeader: Record "Production BOM Header";
        Response: Record "Message Response ori";
        RequestData: JsonObject;
    begin
        LibraryManufacturing.CreateProductionBOMHeader(ProductionBOMHeader, '');
        
        PermissionsMock.ClearAssignments();
        PermissionsMock.Assign('BIFROST Core ori');
        PermissionsMock.Assign('BIFROST MfgRead ori');
        
        RequestData.Add('no', ProductionBOMHeader."No.");
        RequestData.Add('status', 'UnderDevelopment');

        Dispatcher.RunBifrostCall(Enum::"Message Type ori"::"Manufacturing.ProductionBOM.SetStatus", RequestData, Response);
        LibraryAssert.AreEqual(Enum::"Message Response Status ori"::Error, Response.Status, 'Status');
        LibraryAssert.AreEqual('PermissionDenied', Response.ErrorType, 'ErrorType');
    end;

    [Test]
    procedure MfgFullCanSetStatus()
    var
        RoutingHeader: Record "Routing Header";
        Response: Record "Message Response ori";
        RequestData: JsonObject;
    begin
        LibraryManufacturing.CreateRoutingHeader(RoutingHeader, '');
        
        PermissionsMock.ClearAssignments();
        PermissionsMock.Assign('BIFROST Core ori');
        PermissionsMock.Assign('BIFROST MfgFull ori');
        PermissionsMock.Assign('D365 MFG SETUP');
        
        RequestData.Add('no', RoutingHeader."No.");
        RequestData.Add('status', 'UnderDevelopment');

        Dispatcher.RunBifrostCall(Enum::"Message Type ori"::"Manufacturing.Routing.SetStatus", RequestData, Response);
        // It might be a business central error if the routing is invalid, but not a permission error.
        LibraryAssert.AreNotEqual('PermissionDenied', Response.ErrorType, 'ErrorType');
    end;
}
