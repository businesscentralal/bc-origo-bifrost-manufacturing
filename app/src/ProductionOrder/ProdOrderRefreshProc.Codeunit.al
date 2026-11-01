namespace Origo.Bifrost.Manufacturing;

using Microsoft.Manufacturing.Document;
using Origo.Bifrost;

/// <summary>Runs the standard refresh report and builds the response within the caller's rollback boundary.</summary>
codeunit 10077043 "Prod Order Refresh Proc ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        ProductionOrder: Record "Production Order";
        ProductionLine: Record "Prod. Order Line";
        RoutingLine: Record "Prod. Order Routing Line";
        Component: Record "Prod. Order Component";
        Refresh: Report "Refresh Production Order";
        Lookup: Codeunit "Mfg Prod Order Lookup ori";
        Reader: Codeunit "Mfg Prod Order Request ori";
        Request: JsonObject;
        Response: JsonObject;
        Line: JsonObject;
        Lines: JsonArray;
        Direction: Option Forward,Backward;
        DirectionText: Text;
        ChangedLbl: Label 'The production order is no longer in a planning status. Nothing was changed.', Comment = 'is-IS=Framleiðslupöntunin er ekki lengur í áætlunarstöðu. Engu var breytt.';
    begin
        Request := Rec.GetRequestJson();
        ProductionOrder.ReadIsolation := IsolationLevel::UpdLock;
        if not Lookup.FindOrder(Rec, ProductionOrder) then
            exit;
        if not (ProductionOrder.Status in [ProductionOrder.Status::Simulated, ProductionOrder.Status::Planned, ProductionOrder.Status::"Firm Planned"]) then
            Error(ChangedLbl);
        DirectionText := Reader.ReadText(Request, 'direction', false, 8, Rec);
        Direction := Direction::Backward;
        if DirectionText = 'Forward' then
            Direction := Direction::Forward
        else
            DirectionText := 'Backward';
        ProductionOrder.SetRecFilter();
        Refresh.InitializeRequest(Direction, Reader.ReadBoolean(Request, 'calculateLines', Rec), Reader.ReadBoolean(Request, 'calculateRoutings', Rec), Reader.ReadBoolean(Request, 'calculateComponents', Rec), false);
        Refresh.SetHideValidationDialog(true);
        Refresh.SetTableView(ProductionOrder);
        Refresh.UseRequestPage(false);
        Refresh.RunModal();
        ProductionOrder.Get(ProductionOrder.Status, ProductionOrder."No.");
        ProductionLine.SetLoadFields(Status, "Prod. Order No.", "Line No.", "Item No.", Quantity, "Routing No.", "Production BOM No.");
        ProductionLine.SetRange(Status, ProductionOrder.Status);
        ProductionLine.SetRange("Prod. Order No.", ProductionOrder."No.");
        if ProductionLine.FindSet() then
            repeat
                Clear(Line);
                Line.Add('lineNo', ProductionLine."Line No.");
                Line.Add('itemNo', ProductionLine."Item No.");
                Line.Add('quantity', ProductionLine.Quantity);
                Line.Add('routingNo', ProductionLine."Routing No.");
                Line.Add('productionBomNo', ProductionLine."Production BOM No.");
                Lines.Add(Line);
            until ProductionLine.Next() = 0;
        RoutingLine.SetLoadFields(Status, "Prod. Order No.");
        RoutingLine.SetRange(Status, ProductionOrder.Status);
        RoutingLine.SetRange("Prod. Order No.", ProductionOrder."No.");
        Component.SetLoadFields(Status, "Prod. Order No.");
        Component.SetRange(Status, ProductionOrder.Status);
        Component.SetRange("Prod. Order No.", ProductionOrder."No.");
        Response.Add('status', 'Success');
        Response.Add('productionOrderStatus', Lookup.StatusName(ProductionOrder.Status));
        Response.Add('no', ProductionOrder."No.");
        Response.Add('systemId', Format(ProductionOrder.SystemId, 0, 4));
        Response.Add('direction', DirectionText);
        Response.Add('startingDate', Format(ProductionOrder."Starting Date", 0, 9));
        Response.Add('endingDate', Format(ProductionOrder."Ending Date", 0, 9));
        Response.Add('dueDate', Format(ProductionOrder."Due Date", 0, 9));
        Response.Add('quantity', ProductionOrder.Quantity);
        Response.Add('lines', Lines);
        Response.Add('routingLineCount', RoutingLine.Count());
        Response.Add('componentCount', Component.Count());
        Rec.SetResponseJson(Response);
        Rec."Content Type" := Rec.GetContentTypeJson();
    end;
}
