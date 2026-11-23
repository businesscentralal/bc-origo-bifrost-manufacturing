namespace Origo.Bifrost.Manufacturing;

using Microsoft.Manufacturing.Document;
using Microsoft.Sales.Document;
using Origo.Bifrost;

/// <summary>Creates production orders from sales demand with the standard no-dialog routine inside one rollback boundary.</summary>
codeunit 10077083 "Prod Order Demand Proc ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        TempEligible: Record "Sales Line" temporary;
        TempOrders: Record "Production Order" temporary;
        ProductionOrder: Record "Production Order";
        Plan: Codeunit "Prod Order Demand Plan ori";
        Events: Codeunit "Prod Order Demand Events ori";
        CreateFromSale: Codeunit "Create Prod. Order from Sale";
        Lookup: Codeunit "Mfg Prod Order Lookup ori";
        Skipped: JsonArray;
        Orders: JsonArray;
        OrderType: Enum "Create Production Order Type";
        NewStatus: Enum "Production Order Status";
        Response: JsonObject;
        NextLbl: Label 'Read the orders with Data.Records.Get; release planned orders with Manufacturing.ProductionOrder.ChangeStatus.', Comment = 'is-IS=Lestu pantanirnar með Data.Records.Get; gefðu áætlaðar pantanir út með Manufacturing.ProductionOrder.ChangeStatus.';
    begin
        SalesLine.LockTable();
        if not Plan.BuildPlan(Rec, SalesHeader, TempEligible, Skipped, OrderType, NewStatus) then
            exit;
        BindSubscription(Events);
        TempEligible.FindSet();
        repeat
            SalesLine.Get(TempEligible."Document Type", TempEligible."Document No.", TempEligible."Line No.");
            Clear(CreateFromSale);
            CreateFromSale.SetHideValidationDialog(true);
            CreateFromSale.CreateProductionOrder(SalesLine, NewStatus, OrderType);
        until (TempEligible.Next() = 0) or (OrderType = OrderType::ProjectOrder);
        if OrderType = OrderType::ProjectOrder then begin
            Events.GetCreated(TempOrders);
            if TempOrders.FindFirst() then begin
                TempEligible.FindSet();
                repeat
                    Events.AddLinkedLine(TempOrders, TempEligible."Line No.");
                until TempEligible.Next() = 0;
            end;
        end;
        UnbindSubscription(Events);
        Events.GetCreated(TempOrders);
        if TempOrders.FindSet() then
            repeat
                ProductionOrder.Get(TempOrders.Status, TempOrders."No.");
                Orders.Add(OrderJson(ProductionOrder, Events.GetLinkedLines(TempOrders), Lookup));
            until TempOrders.Next() = 0;
        Response.Add('status', 'Success');
        Response.Add('orderType', OrderType.Names().Get(OrderType.Ordinals().IndexOf(OrderType.AsInteger())));
        Response.Add('sourceType', 'salesOrder');
        Response.Add('sourceNo', SalesHeader."No.");
        Response.Add('ordersCreated', Orders.Count());
        Response.Add('orders', Orders);
        Response.Add('skipped', Skipped);
        Response.Add('nextStep', NextLbl);
        Rec.SetResponseJson(Response);
        Rec."Content Type" := Rec.GetContentTypeJson();
    end;

    local procedure OrderJson(ProductionOrder: Record "Production Order"; LinkedLineNos: List of [Integer]; Lookup: Codeunit "Mfg Prod Order Lookup ori"): JsonObject
    var
        Line: Record "Prod. Order Line";
        Component: Record "Prod. Order Component";
        Entry: JsonObject;
        Linked: JsonArray;
        LineNo: Integer;
    begin
        Entry.Add('no', ProductionOrder."No.");
        Entry.Add('systemId', Format(ProductionOrder.SystemId, 0, 4));
        Entry.Add('status', Lookup.StatusName(ProductionOrder.Status));
        if ProductionOrder."Source Type" = ProductionOrder."Source Type"::"Sales Header" then
            Entry.Add('sourceType', 'SalesHeader')
        else
            Entry.Add('sourceType', 'Item');
        Entry.Add('sourceNo', ProductionOrder."Source No.");
        Entry.Add('quantity', ProductionOrder.Quantity);
        Entry.Add('dueDate', Format(ProductionOrder."Due Date", 0, 9));
        foreach LineNo in LinkedLineNos do
            Linked.Add(LineNo);
        Entry.Add('linkedLines', Linked);
        Line.SetRange(Status, ProductionOrder.Status);
        Line.SetRange("Prod. Order No.", ProductionOrder."No.");
        Entry.Add('lineCount', Line.Count());
        Component.SetRange(Status, ProductionOrder.Status);
        Component.SetRange("Prod. Order No.", ProductionOrder."No.");
        Entry.Add('componentCount', Component.Count());
        exit(Entry);
    end;
}
