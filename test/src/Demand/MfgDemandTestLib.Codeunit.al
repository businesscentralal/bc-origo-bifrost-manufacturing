namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Foundation.NoSeries;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Tracking;
using Microsoft.Manufacturing.Document;
using Microsoft.Manufacturing.ProductionBOM;
using Microsoft.Manufacturing.Setup;
using Microsoft.Sales.Customer;
using Microsoft.Sales.Document;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Builds owned customers, manufactured items and released sales orders for CreateFromDemand, and removes what the calls committed.</summary>
codeunit 97644 "Mfg Demand Test Lib ori"
{
    var
        Data: Codeunit "Mfg Test Data ori";
        Assert: Codeunit "Library Assert";

    /// <summary>Gives every production order status its own owned number series.</summary>
    procedure SetupNumbering()
    var
        Setup: Record "Manufacturing Setup";
        Series: Record "No. Series";
        SeriesLine: Record "No. Series Line";
        Utility: Codeunit "Library - Utility";
        Prefix: Code[10];
    begin
        Data.SetupNumbering(false);
        Prefix := CopyStr('R' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, 9) + 'N';
        Utility.CreateNoSeries(Series, true, false, false);
        Series.Rename(CopyStr('X' + Series.Code, 1, MaxStrLen(Series.Code)));
        Utility.CreateNoSeriesLine(SeriesLine, Series.Code, Prefix + '000001', Prefix + '999999');
        Setup.Get();
        Setup.Validate("Released Order Nos.", Series.Code);
        Setup.Modify(true);
    end;

    /// <summary>Creates an owned item replenished by production order with its own certified BOM and routing.</summary>
    procedure CreateManufacturedItem(var Item: Record Item)
    begin
        Data.CreateManufacturedItem(Item);
        Item.Validate("Replenishment System", Item."Replenishment System"::"Prod. Order");
        Item.Validate("Manufacturing Policy", Item."Manufacturing Policy"::"Make-to-Order");
        Item.Modify(true);
    end;

    /// <summary>Creates an owned purchased item.</summary>
    procedure CreatePurchasedItem(var Item: Record Item)
    begin
        Data.CreateItem(Item);
        Item.Validate("Replenishment System", Item."Replenishment System"::Purchase);
        Item.Modify(true);
    end;

    /// <summary>Sets the item BOM back to Under Development.</summary>
    procedure UncertifyBom(Item: Record Item)
    var
        Bom: Record "Production BOM Header";
    begin
        Bom.Get(Item."Production BOM No.");
        Bom.Validate(Status, Bom.Status::"Under Development");
        Bom.Modify(true);
    end;

    /// <summary>Creates an owned customer and a sales order with one line per item; releases it when asked.</summary>
    procedure CreateSalesOrder(var SalesHeader: Record "Sales Header"; ItemNos: List of [Code[20]]; Release: Boolean)
    var
        Customer: Record Customer;
        SalesLine: Record "Sales Line";
        LibrarySales: Codeunit "Library - Sales";
        ItemNo: Code[20];
        Quantity: Integer;
    begin
        LibrarySales.CreateCustomer(Customer);
        LibrarySales.CreateSalesHeader(SalesHeader, SalesHeader."Document Type"::Order, Customer."No.");
        SalesHeader.Validate("Shipment Date", CalcDate('<+1M>', WorkDate()));
        SalesHeader.Modify(true);
        Quantity := 2;
        foreach ItemNo in ItemNos do begin
            LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, ItemNo, Quantity);
            Quantity += 1;
        end;
        if Release then
            LibrarySales.ReleaseSalesDocument(SalesHeader);
    end;

    /// <summary>Builds a request with an expected count; a negative count omits it.</summary>
    procedure Request(SalesHeader: Record "Sales Header"; Status: Text; OrderType: Text; ExpectedCount: Integer): JsonObject
    var
        Result: JsonObject;
    begin
        Result.Add('sourceType', 'salesOrder');
        Result.Add('sourceNo', SalesHeader."No.");
        if Status <> '' then
            Result.Add('status', Status);
        if OrderType <> '' then
            Result.Add('orderType', OrderType);
        if ExpectedCount >= 0 then
            Result.Add('expectedCount', ExpectedCount);
        exit(Result);
    end;

    /// <summary>Dispatches CreateFromDemand through Foundation.</summary>
    procedure Invoke(Payload: JsonObject; LanguageId: Integer; var MessageId: Guid): JsonObject
    begin
        exit(Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.CreateFromDemand", Payload, LanguageId, false, MessageId));
    end;

    /// <summary>Counts production orders made for an item or for the sales order.</summary>
    procedure CountOrders(SalesHeader: Record "Sales Header"; ItemNos: List of [Code[20]]): Integer
    var
        ProductionOrder: Record "Production Order";
        ItemNo: Code[20];
        Total: Integer;
    begin
        foreach ItemNo in ItemNos do begin
            ProductionOrder.SetRange("Source Type", ProductionOrder."Source Type"::Item);
            ProductionOrder.SetRange("Source No.", ItemNo);
            Total += ProductionOrder.Count();
        end;
        ProductionOrder.SetRange("Source Type", ProductionOrder."Source Type"::"Sales Header");
        ProductionOrder.SetRange("Source No.", SalesHeader."No.");
        exit(Total + ProductionOrder.Count());
    end;

    /// <summary>Counts reservation or tracking entries of a sales line.</summary>
    procedure CountSalesLineLinks(SalesLine: Record "Sales Line"): Integer
    var
        ReservationEntry: Record "Reservation Entry";
    begin
        ReservationEntry.SetRange("Source Type", Database::"Sales Line");
        ReservationEntry.SetRange("Source Subtype", SalesLine."Document Type".AsInteger());
        ReservationEntry.SetRange("Source ID", SalesLine."Document No.");
        ReservationEntry.SetRange("Source Ref. No.", SalesLine."Line No.");
        exit(ReservationEntry.Count());
    end;

    /// <summary>Deletes the committed production orders and the sales order with native cascades.</summary>
    procedure Cleanup(SalesHeader: Record "Sales Header"; ItemNos: List of [Code[20]])
    var
        ProductionOrder: Record "Production Order";
        LibrarySales: Codeunit "Library - Sales";
        ItemNo: Code[20];
    begin
        foreach ItemNo in ItemNos do begin
            ProductionOrder.SetRange("Source Type", ProductionOrder."Source Type"::Item);
            ProductionOrder.SetRange("Source No.", ItemNo);
            ProductionOrder.DeleteAll(true);
        end;
        ProductionOrder.SetRange("Source Type", ProductionOrder."Source Type"::"Sales Header");
        ProductionOrder.SetRange("Source No.", SalesHeader."No.");
        ProductionOrder.DeleteAll(true);
        if SalesHeader.Get(SalesHeader."Document Type", SalesHeader."No.") then begin
            if SalesHeader.Status = SalesHeader.Status::Released then
                LibrarySales.ReopenSalesDocument(SalesHeader);
            SalesHeader.Delete(true);
        end;
        Commit();
        Assert.AreEqual(0, CountOrders(SalesHeader, ItemNos), 'Cleanup removed every owned order.');
    end;

    /// <summary>Reads an array from a response.</summary>
    procedure ArrayValue(Response: JsonObject; Name: Text): JsonArray
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(Response.Get(Name, Token), 'Missing response key: ' + Name);
        exit(Token.AsArray());
    end;

    /// <summary>Reads a text member of an array element.</summary>
    procedure Member(Entries: JsonArray; Index: Integer; Name: Text): Text
    var
        Entry: JsonToken;
        Token: JsonToken;
    begin
        Entries.Get(Index, Entry);
        Assert.IsTrue(Entry.AsObject().Get(Name, Token), 'Missing member: ' + Name);
        if Token.IsValue() then
            exit(Token.AsValue().AsText());
        Token.WriteTo(Name);
        exit(Name);
    end;
}
