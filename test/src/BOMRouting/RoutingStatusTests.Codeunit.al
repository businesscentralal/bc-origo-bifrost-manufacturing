namespace Origo.Bifrost.Manufacturing.Test;

using Origo.Bifrost.Foundation;
using Microsoft.Manufacturing.Routing;
using Microsoft.Manufacturing.WorkCenter;
using System.TestLibraries.Utilities;

codeunit 97661 "Routing Status Tests ori"
{
    Subtype = Test;

    var
        LibraryManufacturing: Codeunit "Library - Manufacturing";
        LibraryAssert: Codeunit "Library Assert";
        Dispatcher: Codeunit "Dispatcher ori";

    [Test]
    procedure SetStatusCertifiedOnValidRouting()
    var
        RoutingHeader: Record "Routing Header";
        RoutingLine: Record "Routing Line";
        WorkCenter: Record "Work Center";
        Response: Record "Message Response ori";
        RequestData: JsonObject;
    begin
        LibraryManufacturing.CreateRoutingHeader(RoutingHeader, '');
        LibraryManufacturing.CreateWorkCenter(WorkCenter);
        LibraryManufacturing.CreateRoutingLine(RoutingHeader, RoutingLine, '', '10', RoutingLine.Type::"Work Center", WorkCenter."No.");
        
        RequestData.Add('no', RoutingHeader."No.");
        RequestData.Add('status', 'Certified');

        Dispatcher.RunBifrostCall(Enum::"Message Type ori"::"Manufacturing.Routing.SetStatus", RequestData, Response);
        LibraryAssert.AreEqual(Enum::"Message Response Status ori"::Success, Response.Status, 'Status');
        
        RoutingHeader.Get(RoutingHeader."No.");
        LibraryAssert.AreEqual(RoutingHeader.Status::Certified, RoutingHeader.Status, 'Routing Status');
        
        LibraryAssert.AreEqual('New', Response.GetResponseString('previousStatus'), 'previousStatus');
        LibraryAssert.AreEqual('Certified', Response.GetResponseString('status'), 'status');
        LibraryAssert.IsTrue(Response.GetResponseBoolean('changed'), 'changed');
        LibraryAssert.AreEqual(0, Response.GetResponseInteger('usedOnItems'), 'usedOnItems');
    end;

    [Test]
    procedure CertifyingRoutingWithNoLinesFails()
    var
        RoutingHeader: Record "Routing Header";
        Response: Record "Message Response ori";
        RequestData: JsonObject;
    begin
        LibraryManufacturing.CreateRoutingHeader(RoutingHeader, '');
        
        RequestData.Add('no', RoutingHeader."No.");
        RequestData.Add('status', 'Certified');

        Dispatcher.RunBifrostCall(Enum::"Message Type ori"::"Manufacturing.Routing.SetStatus", RequestData, Response);
        LibraryAssert.AreEqual(Enum::"Message Response Status ori"::Error, Response.Status, 'Status');
        LibraryAssert.AreEqual('BusinessCentralError', Response.ErrorType, 'ErrorType');
        
        RoutingHeader.Get(RoutingHeader."No.");
        LibraryAssert.AreEqual(RoutingHeader.Status::New, RoutingHeader.Status, 'Routing Status unchanged');
    end;

    [Test]
    procedure SetStatusUnderDevelopmentOnCertifiedRouting()
    var
        RoutingHeader: Record "Routing Header";
        RoutingLine: Record "Routing Line";
        WorkCenter: Record "Work Center";
        Response: Record "Message Response ori";
        RequestData: JsonObject;
    begin
        LibraryManufacturing.CreateRoutingHeader(RoutingHeader, '');
        LibraryManufacturing.CreateWorkCenter(WorkCenter);
        LibraryManufacturing.CreateRoutingLine(RoutingHeader, RoutingLine, '', '10', RoutingLine.Type::"Work Center", WorkCenter."No.");
        RoutingHeader.Validate(Status, RoutingHeader.Status::Certified);
        RoutingHeader.Modify(true);
        
        RequestData.Add('no', RoutingHeader."No.");
        RequestData.Add('status', 'UnderDevelopment');

        Dispatcher.RunBifrostCall(Enum::"Message Type ori"::"Manufacturing.Routing.SetStatus", RequestData, Response);
        LibraryAssert.AreEqual(Enum::"Message Response Status ori"::Success, Response.Status, 'Status');
        
        RoutingHeader.Get(RoutingHeader."No.");
        LibraryAssert.AreEqual(RoutingHeader.Status::"Under Development", RoutingHeader.Status, 'Routing Status');
    end;
}
