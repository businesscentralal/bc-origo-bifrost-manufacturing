namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Inventory.Item;
using Microsoft.Manufacturing.Document;
using Microsoft.Sales.Document;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Issue 23: Manufacturing.ProductionOrder.CreateFromDemand through Foundation's public dispatcher, with owned data only.</summary>
codeunit 97641 "Prod Order Demand Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Lib: Codeunit "Mfg Demand Test Lib ori";
        Data: Codeunit "Mfg Test Data ori";
        StatusLib: Codeunit "Mfg Status Test Lib ori";
        ReopenFixture: Codeunit "Mfg Reopen Fixture ori";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure AC01_ItemOrder_TwoFirmPlannedOrdersLinkedToTheirLines()
    var
        ItemA: Record Item;
        ItemB: Record Item;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        ProductionOrder: Record "Production Order";
        ItemNos: List of [Code[20]];
        Orders: JsonArray;
        Response: JsonObject;
        MessageId: Guid;
        Index: Integer;
    begin
        // Story #23, AC01 | Time: WorkDate + 1M shipment | Risk: None
        Lib.SetupNumbering();
        Lib.CreateManufacturedItem(ItemA);
        Lib.CreateManufacturedItem(ItemB);
        ItemNos.Add(ItemA."No.");
        ItemNos.Add(ItemB."No.");
        Lib.CreateSalesOrder(SalesHeader, ItemNos, true);
        Response := Lib.Invoke(Lib.Request(SalesHeader, 'FirmPlanned', 'ItemOrder', 2), 1033, MessageId);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'CreateFromDemand succeeds.');
        Assert.AreEqual(2, Data.NumberValue(Response, 'ordersCreated'), 'One order per sales line.');
        Orders := Lib.ArrayValue(Response, 'orders');
        Assert.AreEqual(2, Orders.Count(), 'Two orders returned.');
        Assert.AreEqual(0, Lib.ArrayValue(Response, 'skipped').Count(), 'Nothing skipped.');
        for Index := 0 to 1 do begin
            Assert.AreEqual('FirmPlanned', Lib.Member(Orders, Index, 'status'), 'Firm planned.');
            Assert.AreEqual('Item', Lib.Member(Orders, Index, 'sourceType'), 'Item order.');
            Assert.IsTrue(ProductionOrder.Get(ProductionOrder.Status::"Firm Planned", Lib.Member(Orders, Index, 'no')), 'Order persisted.');
            Assert.AreNotEqual('0', Lib.Member(Orders, Index, 'lineCount'), 'Order has a line.');
            Assert.AreNotEqual('0', Lib.Member(Orders, Index, 'componentCount'), 'Order has components.');
            Assert.AreEqual('[' + Format(SalesLineNo(SalesHeader, Lib.Member(Orders, Index, 'sourceNo')), 0, 9) + ']', Lib.Member(Orders, Index, 'linkedLines'), 'Order names its sales line.');
        end;
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.FindSet();
        repeat
            Assert.IsTrue(Lib.CountSalesLineLinks(SalesLine) > 0, 'Sales line is reserved or tracked against its order.');
        until SalesLine.Next() = 0;
        Lib.Cleanup(SalesHeader, ItemNos);
    end;

    [Test]
    procedure AC02_ProjectOrder_OneOrderForTheWholeSalesOrder()
    var
        ItemA: Record Item;
        ItemB: Record Item;
        SalesHeader: Record "Sales Header";
        ProductionOrder: Record "Production Order";
        ProdOrderLine: Record "Prod. Order Line";
        ItemNos: List of [Code[20]];
        Orders: JsonArray;
        Response: JsonObject;
        MessageId: Guid;
    begin
        // Story #23, AC02 | Time: WorkDate + 1M shipment | Risk: None
        Lib.SetupNumbering();
        Lib.CreateManufacturedItem(ItemA);
        Lib.CreateManufacturedItem(ItemB);
        ItemNos.Add(ItemA."No.");
        ItemNos.Add(ItemB."No.");
        Lib.CreateSalesOrder(SalesHeader, ItemNos, true);
        Response := Lib.Invoke(Lib.Request(SalesHeader, '', 'ProjectOrder', 1), 1039, MessageId);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'CreateFromDemand succeeds in 1039.');
        Orders := Lib.ArrayValue(Response, 'orders');
        Assert.AreEqual(1, Orders.Count(), 'One order for the sales order.');
        Assert.AreEqual('SalesHeader', Lib.Member(Orders, 0, 'sourceType'), 'Sales header source.');
        Assert.AreEqual(SalesHeader."No.", Lib.Member(Orders, 0, 'sourceNo'), 'Source is the sales order.');
        Assert.IsTrue(ProductionOrder.Get(ProductionOrder.Status::"Firm Planned", Lib.Member(Orders, 0, 'no')), 'Default status is firm planned.');
        Assert.AreEqual(ProductionOrder."Source Type"::"Sales Header", ProductionOrder."Source Type", 'Native source type.');
        ProdOrderLine.SetRange(Status, ProductionOrder.Status);
        ProdOrderLine.SetRange("Prod. Order No.", ProductionOrder."No.");
        ProdOrderLine.SetFilter("Item No.", '%1|%2', ItemA."No.", ItemB."No.");
        Assert.AreEqual(2, ProdOrderLine.Count(), 'One order line per sales line.');
        Assert.AreEqual('2', Lib.Member(Orders, 0, 'lineCount'), 'Response line count.');
        Lib.Cleanup(SalesHeader, ItemNos);
    end;

    [Test]
    procedure AC03_WriteEffectNeedsNoConfirmation()
    var
        Item: Record Item;
        SalesHeader: Record "Sales Header";
        ItemNos: List of [Code[20]];
        Response: JsonObject;
        MessageId: Guid;
    begin
        // Gunnar 24.11.2026 (#42): CreateFromDemand is a write; no expectedCount is required even when confirmation is on.
        Lib.SetupNumbering();
        Lib.CreateManufacturedItem(Item);
        ItemNos.Add(Item."No.");
        Lib.CreateSalesOrder(SalesHeader, ItemNos, true);
        StatusLib.SetConfirmRequired(true);
        Commit();
        Response := Lib.Invoke(Lib.Request(SalesHeader, 'FirmPlanned', 'ItemOrder', -1), 1033, MessageId);
        Assert.IsTrue(Response.Contains('ordersCreated'), 'Request was accepted.');
        Assert.AreEqual(1, Lib.CountOrders(SalesHeader, ItemNos), 'One order created without expectedCount.');
        Lib.Cleanup(SalesHeader, ItemNos);
    end;

    [Test]
    procedure AC04_PurchasedAndUncertifiedLinesAreSkipped()
    var
        Made: Record Item;
        Bought: Record Item;
        Uncertified: Record Item;
        SalesHeader: Record "Sales Header";
        ItemNos: List of [Code[20]];
        Skipped: JsonArray;
        Response: JsonObject;
        MessageId: Guid;
    begin
        // Story #23, AC04 | Time: WorkDate + 1M shipment | Risk: None
        Lib.SetupNumbering();
        Lib.CreateManufacturedItem(Made);
        Lib.CreatePurchasedItem(Bought);
        Lib.CreateManufacturedItem(Uncertified);
        Lib.UncertifyBom(Uncertified);
        ItemNos.Add(Made."No.");
        ItemNos.Add(Bought."No.");
        ItemNos.Add(Uncertified."No.");
        Lib.CreateSalesOrder(SalesHeader, ItemNos, true);
        Response := Lib.Invoke(Lib.Request(SalesHeader, 'Planned', 'ItemOrder', 1), 1033, MessageId);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Eligible line still gets its order.');
        Assert.AreEqual(1, Lib.ArrayValue(Response, 'orders').Count(), 'Only the manufactured line.');
        Assert.AreEqual('Planned', Lib.Member(Lib.ArrayValue(Response, 'orders'), 0, 'status'), 'Planned status.');
        Skipped := Lib.ArrayValue(Response, 'skipped');
        Assert.AreEqual(2, Skipped.Count(), 'Two lines skipped.');
        Assert.AreEqual('notManufactured', Lib.Member(Skipped, 0, 'reasonCode'), 'Purchased item.');
        Assert.AreEqual('bomNotCertified', Lib.Member(Skipped, 1, 'reasonCode'), 'Uncertified BOM.');
        Assert.IsTrue(Lib.Member(Skipped, 1, 'nextStep').Contains('Manufacturing.ProductionBOM.SetStatus'), 'Next step names BOM certification.');
        Assert.AreNotEqual('', Lib.Member(Skipped, 0, 'nextStep'), 'Purchased line has a next step.');
        Lib.Cleanup(SalesHeader, ItemNos);
    end;

    [Test]
    procedure AC04_OpenSalesOrderPreconditionFailed()
    var
        Item: Record Item;
        SalesHeader: Record "Sales Header";
        ItemNos: List of [Code[20]];
        Response: JsonObject;
        MessageId: Guid;
    begin
        // Story #23, AC04/C1 | Time: WorkDate + 1M shipment | Risk: None
        Lib.SetupNumbering();
        Lib.CreateManufacturedItem(Item);
        ItemNos.Add(Item."No.");
        Lib.CreateSalesOrder(SalesHeader, ItemNos, false);
        Response := Lib.Invoke(Lib.Request(SalesHeader, 'FirmPlanned', 'ItemOrder', 1), 1039, MessageId);
        Data.AssertRefusal(Response, 'PreconditionFailed');
        ReopenFixture.AssertLoggedError(MessageId, 'PreconditionFailed');
        Assert.AreEqual(0, Lib.CountOrders(SalesHeader, ItemNos), 'Nothing created for an open sales order.');
        Lib.Cleanup(SalesHeader, ItemNos);
    end;

    [Test]
    procedure AC04_ProjectOrderWithUncertifiedLineRefusedWhole()
    var
        Made: Record Item;
        Uncertified: Record Item;
        SalesHeader: Record "Sales Header";
        ItemNos: List of [Code[20]];
        Response: JsonObject;
        MessageId: Guid;
    begin
        // Story #23, AC04 edge | Time: WorkDate + 1M shipment | Risk: None
        Lib.SetupNumbering();
        Lib.CreateManufacturedItem(Made);
        Lib.CreateManufacturedItem(Uncertified);
        Lib.UncertifyBom(Uncertified);
        ItemNos.Add(Made."No.");
        ItemNos.Add(Uncertified."No.");
        Lib.CreateSalesOrder(SalesHeader, ItemNos, true);
        Response := Lib.Invoke(Lib.Request(SalesHeader, 'FirmPlanned', 'ProjectOrder', 1), 1033, MessageId);
        Data.AssertRefusal(Response, 'PreconditionFailed');
        Assert.AreEqual(0, Lib.CountOrders(SalesHeader, ItemNos), 'Nothing created.');
        Lib.Cleanup(SalesHeader, ItemNos);
    end;

    [Test]
    procedure AC05_ReleasedWithPostingTokenReleasesTheOrder()
    var
        Item: Record Item;
        SalesHeader: Record "Sales Header";
        ProductionOrder: Record "Production Order";
        ItemNos: List of [Code[20]];
        Response: JsonObject;
        MessageId: Guid;
    begin
        // Story #23, AC05 happy path (test runs with full native and Bifrost permissions) | Time: WorkDate | Risk: None
        Lib.SetupNumbering();
        Lib.CreateManufacturedItem(Item);
        ItemNos.Add(Item."No.");
        Lib.CreateSalesOrder(SalesHeader, ItemNos, true);
        Response := Lib.Invoke(Lib.Request(SalesHeader, 'Released', '', 1), 1033, MessageId);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Released creation succeeds.');
        Assert.IsTrue(ProductionOrder.Get(ProductionOrder.Status::Released, Lib.Member(Lib.ArrayValue(Response, 'orders'), 0, 'no')), 'Released order exists.');
        Lib.Cleanup(SalesHeader, ItemNos);
    end;

    [Test]
    procedure C1_RequestRefusalsChangeNothing()
    var
        Item: Record Item;
        SalesHeader: Record "Sales Header";
        OtherHeader: Record "Sales Header";
        ItemNos: List of [Code[20]];
        Request: JsonObject;
        LineNos: JsonArray;
    begin
        // Story #23, C1: MissingParameter, InvalidParameterFormat, UnknownParameter, RecordNotFound, ConflictingIdentifiers, InvalidParameter | Risk: None
        Lib.SetupNumbering();
        Lib.CreateManufacturedItem(Item);
        ItemNos.Add(Item."No.");
        Lib.CreateSalesOrder(SalesHeader, ItemNos, true);
        Lib.CreateSalesOrder(OtherHeader, ItemNos, true);
        Commit();

        Request := Lib.Request(SalesHeader, '', '', 1);
        Request.Remove('sourceType');
        CheckRefusal(Request, 'MissingParameter', SalesHeader, ItemNos);

        Request := Lib.Request(SalesHeader, '', '', 1);
        Request.Add('lineNos', 'all');
        CheckRefusal(Request, 'InvalidParameterFormat', SalesHeader, ItemNos);

        Request := Lib.Request(SalesHeader, '', '', 1);
        Request.Add('includeMultiLevel', true);
        CheckRefusal(Request, 'UnknownParameter', SalesHeader, ItemNos);

        Request := Lib.Request(SalesHeader, '', '', 1);
        Request.Replace('sourceNo', 'XNOSUCHORDER');
        CheckRefusal(Request, 'RecordNotFound', SalesHeader, ItemNos);

        Request := Lib.Request(SalesHeader, '', '', 1);
        LineNos.Add(999999);
        Request.Add('lineNos', LineNos);
        CheckRefusal(Request, 'RecordNotFound', SalesHeader, ItemNos);

        Request := Lib.Request(SalesHeader, '', '', 1);
        Request.Add('sourceSystemId', Format(OtherHeader.SystemId, 0, 4));
        CheckRefusal(Request, 'ConflictingIdentifiers', SalesHeader, ItemNos);

        Request := Lib.Request(SalesHeader, '', '', 1);
        Request.Replace('sourceType', 'project');
        CheckRefusal(Request, 'InvalidParameter', SalesHeader, ItemNos);

        Request := Lib.Request(SalesHeader, 'Finished', '', 1);
        CheckRefusal(Request, 'InvalidParameter', SalesHeader, ItemNos);

        Lib.Cleanup(OtherHeader, ItemNos);
        Lib.Cleanup(SalesHeader, ItemNos);
    end;

    [Test]
    procedure Edge_LineNosSelectsOneLineAndSystemIdIdentifiesTheOrder()
    var
        ItemA: Record Item;
        ItemB: Record Item;
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        ItemNos: List of [Code[20]];
        LineNos: JsonArray;
        Request: JsonObject;
        Response: JsonObject;
        MessageId: Guid;
    begin
        // Story #23, edge: lineNos and sourceSystemId | Time: WorkDate + 1M shipment | Risk: None
        Lib.SetupNumbering();
        Lib.CreateManufacturedItem(ItemA);
        Lib.CreateManufacturedItem(ItemB);
        ItemNos.Add(ItemA."No.");
        ItemNos.Add(ItemB."No.");
        Lib.CreateSalesOrder(SalesHeader, ItemNos, true);
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.SetRange("No.", ItemB."No.");
        SalesLine.FindFirst();
        LineNos.Add(SalesLine."Line No.");
        Request := Lib.Request(SalesHeader, '', '', 1);
        Request.Remove('sourceNo');
        Request.Add('sourceSystemId', Format(SalesHeader.SystemId, 0, 4));
        Request.Add('lineNos', LineNos);
        Response := Lib.Invoke(Request, 1033, MessageId);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Selected line succeeds.');
        Assert.AreEqual(ItemB."No.", Lib.Member(Lib.ArrayValue(Response, 'orders'), 0, 'sourceNo'), 'Only the selected line.');
        Assert.AreEqual(1, Lib.CountOrders(SalesHeader, ItemNos), 'One order created.');
        Lib.Cleanup(SalesHeader, ItemNos);
    end;

    local procedure CheckRefusal(Request: JsonObject; Code: Text; SalesHeader: Record "Sales Header"; ItemNos: List of [Code[20]])
    var
        Response: JsonObject;
        MessageId: Guid;
    begin
        Response := Lib.Invoke(Request, 1033, MessageId);
        Data.AssertRefusal(Response, Code);
        ReopenFixture.AssertLoggedError(MessageId, Code);
        Assert.AreEqual(0, Lib.CountOrders(SalesHeader, ItemNos), 'Refusal ' + Code + ' created nothing.');
    end;

    local procedure SalesLineNo(SalesHeader: Record "Sales Header"; ItemNo: Text): Integer
    var
        SalesLine: Record "Sales Line";
    begin
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.SetRange("No.", ItemNo);
        SalesLine.FindFirst();
        exit(SalesLine."Line No.");
    end;
}
