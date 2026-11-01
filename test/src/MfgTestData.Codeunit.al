namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Foundation.NoSeries;
using Microsoft.Inventory.Item;
using Microsoft.Manufacturing.Document;
using Microsoft.Manufacturing.ProductionBOM;
using Microsoft.Manufacturing.Routing;
using Microsoft.Manufacturing.Setup;
using Microsoft.Manufacturing.WorkCenter;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Creates isolated manufacturing fixtures and invokes the public dispatcher, never feature internals.</summary>
codeunit 97607 "Mfg Test Data ori"
{
    var
        Assert: Codeunit "Library Assert";

    /// <summary>Creates a number series for each planning status without modifying licence or consent state.</summary>
    procedure SetupNumbering(Manual: Boolean)
    var
        Setup: Record "Manufacturing Setup";
        Series: Record "No. Series";
        SeriesLine: Record "No. Series Line";
        Utility: Codeunit "Library - Utility";
    begin
        Utility.CreateNoSeries(Series, true, Manual, false);
        Series.Rename(CopyStr('X' + Series.Code, 1, MaxStrLen(Series.Code)));
        Utility.CreateNoSeriesLine(SeriesLine, Series.Code, 'X000001', 'X999999');
        Setup.SetLoadFields("Planned Order Nos.", "Firm Planned Order Nos.");
        if not Setup.Get() then begin
            Setup.Init();
            Setup.Insert(true);
        end;
        Setup.Validate("Planned Order Nos.", Series.Code);
        Setup.Validate("Firm Planned Order Nos.", Series.Code);
        Setup.Modify(true);
    end;

    /// <summary>Creates an item with its own certified BOM, component and routing.</summary>
    procedure CreateManufacturedItem(var Item: Record Item)
    var
        ComponentItem: Record Item;
        Bom: Record "Production BOM Header";
        Routing: Record "Routing Header";
        RoutingLine: Record "Routing Line";
        Center: Record "Work Center";
        Inventory: Codeunit "Library - Inventory";
        Manufacturing: Codeunit "Library - Manufacturing";
    begin
        Inventory.CreateItem(ComponentItem);
        ComponentItem.Rename(CopyStr('X' + ComponentItem."No.", 1, MaxStrLen(ComponentItem."No.")));
        Manufacturing.CreateCertifiedProductionBOM(Bom, ComponentItem."No.", 2);
        Manufacturing.CreateWorkCenterWithCalendar(Center);
        Manufacturing.CalculateWorkCenterCalendar(Center, CalcDate('<-1Y>', WorkDate()), CalcDate('<1Y>', WorkDate()));
        Manufacturing.CreateRoutingHeader(Routing, Routing.Type::Serial);
        Manufacturing.CreateRoutingLine(Routing, RoutingLine, '', '10', RoutingLine.Type::"Work Center", Center."No.");
        RoutingLine.Validate("Run Time", 60);
        RoutingLine.Modify(true);
        Manufacturing.UpdateRoutingStatus(Routing, Routing.Status::Certified);
        Manufacturing.CreateItemManufacturing(Item, Item."Costing Method"::FIFO, 10, Item."Reordering Policy"::Order, Item."Flushing Method"::Backward, Routing."No.", Bom."No.");
        Item.Rename(CopyStr('X' + Item."No.", 1, MaxStrLen(Item."No.")));
    end;

    /// <summary>Creates a basic item for validation-only scenarios.</summary>
    procedure CreateItem(var Item: Record Item)
    var
        Inventory: Codeunit "Library - Inventory";
    begin
        Inventory.CreateItem(Item);
        Item.Rename(CopyStr('X' + Item."No.", 1, MaxStrLen(Item."No.")));
    end;

    /// <summary>Creates a native order fixture using BC validation.</summary>
    procedure CreateOrder(var ProductionOrder: Record "Production Order"; Item: Record Item; Status: Enum "Production Order Status")
    var
        Manufacturing: Codeunit "Library - Manufacturing";
    begin
        Manufacturing.CreateProductionOrder(ProductionOrder, Status, ProductionOrder."Source Type"::Item, Item."No.", 5);
    end;

    /// <summary>Builds the minimal Create payload.</summary>
    procedure CreateRequest(ItemNo: Code[20]): JsonObject
    var
        Request: JsonObject;
    begin
        Request.Add('sourceNo', ItemNo);
        Request.Add('quantity', 5);
        exit(Request);
    end;

    /// <summary>Dispatches through Foundation with explicit language and transaction mode.</summary>
    procedure Invoke(MessageType: Enum "Message Type ori"; Request: JsonObject; LanguageId: Integer; OmitCommit: Boolean): JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        Input: BigText;
        Output: BigText;
        RequestText: Text;
        ResponseText: Text;
        ContentType: Text[100];
        PreviousLanguage: Integer;
        TaskId: Guid;
        MessageId: Guid;
        ResponseTime: Duration;
        Response: JsonObject;
    begin
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Request.WriteTo(RequestText);
        Input.AddText(RequestText);
        // Native message types are an API surface: the public dispatcher is the user's entry point.
        if OmitCommit then
            Dispatcher.Execute(MessageType, "Message Version ori"::"1.0", '', '', 'text/json', Input, Output, ContentType, true)
        else
            Dispatcher.EnqueueAndProcess(MessageType, "Message Version ori"::"1.0", '', '', 'text/json', Input, TaskId, LanguageId, MessageId, Output, ContentType, ResponseTime);
        GlobalLanguage(PreviousLanguage);
        Output.GetSubText(ResponseText, 1);
        Assert.IsTrue(Response.ReadFrom(ResponseText), 'Dispatcher must return JSON.');
        exit(Response);
    end;

    /// <summary>Reads a required response string for assertions.</summary>
    procedure TextValue(Response: JsonObject; Name: Text): Text
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(Response.Get(Name, Token), 'Missing response key: ' + Name);
        exit(Token.AsValue().AsText());
    end;

    /// <summary>Reads a required response numeric value.</summary>
    procedure NumberValue(Response: JsonObject; Name: Text): Decimal
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(Response.Get(Name, Token), 'Missing response key: ' + Name);
        exit(Token.AsValue().AsDecimal());
    end;

    /// <summary>Asserts a structured refusal with next-step guidance.</summary>
    procedure AssertRefusal(Response: JsonObject; Code: Text)
    begin
        Assert.AreEqual('Error', TextValue(Response, 'status'), 'Expected a refusal.');
        Assert.AreEqual(Code, TextValue(Response, 'code'), 'Unexpected error code.');
        Assert.AreNotEqual('', TextValue(Response, 'error'), 'Refusal must explain the problem.');
        if Code <> 'MultipleErrors' then
            Assert.AreNotEqual('', TextValue(Response, 'nextStep'), 'Refusal must offer recovery guidance.');
    end;
}
