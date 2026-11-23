namespace Origo.Bifrost.Manufacturing;

using Microsoft.Manufacturing.Document;
using Microsoft.Sales.Document;

/// <summary>Records the production orders Business Central creates from sales lines while it is bound.</summary>
codeunit 10077100 "Prod Order Demand Events ori"
{
    Access = Internal;
    EventSubscriberInstance = Manual;

    var
        TempCreated: Record "Production Order" temporary;
        LinkedLines: Dictionary of [Text, List of [Integer]];

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Create Prod. Order from Sale", OnAfterCreateProdOrder, '', false, false)]
    local procedure RecordCreatedOrder(var ProdOrder: Record "Production Order"; var SalesLine: Record "Sales Line")
    var
        Lines: List of [Integer];
        OrderKey: Text;
    begin
        OrderKey := Format(ProdOrder.Status.AsInteger(), 0, 9) + '|' + ProdOrder."No.";
        if not TempCreated.Get(ProdOrder.Status, ProdOrder."No.") then begin
            TempCreated := ProdOrder;
            TempCreated.Insert();
            LinkedLines.Add(OrderKey, Lines);
        end;
        LinkedLines.Get(OrderKey, Lines);
        if not Lines.Contains(SalesLine."Line No.") then
            Lines.Add(SalesLine."Line No.");
        LinkedLines.Set(OrderKey, Lines);
    end;

    /// <summary>Adds a sales line to the lines an order covers (one order for the whole sales order covers several).</summary>
    internal procedure AddLinkedLine(ProdOrder: Record "Production Order"; SalesLineNo: Integer)
    var
        Lines: List of [Integer];
        OrderKey: Text;
    begin
        OrderKey := Format(ProdOrder.Status.AsInteger(), 0, 9) + '|' + ProdOrder."No.";
        if not LinkedLines.Get(OrderKey, Lines) then
            exit;
        if not Lines.Contains(SalesLineNo) then
            Lines.Add(SalesLineNo);
        LinkedLines.Set(OrderKey, Lines);
    end;

    /// <summary>Returns the orders created since binding, in creation order.</summary>
    internal procedure GetCreated(var TempOrders: Record "Production Order" temporary)
    begin
        TempOrders.Copy(TempCreated, true);
    end;

    /// <summary>Returns the sales line numbers linked to a created order.</summary>
    internal procedure GetLinkedLines(ProdOrder: Record "Production Order"): List of [Integer]
    var
        Lines: List of [Integer];
    begin
        if LinkedLines.Get(Format(ProdOrder.Status.AsInteger(), 0, 9) + '|' + ProdOrder."No.", Lines) then;
        exit(Lines);
    end;
}
