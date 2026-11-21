namespace Origo.Bifrost.Manufacturing;

using Microsoft.Manufacturing.Document;

/// <summary>Suppresses the released-order document only during the bound reopen call.</summary>
codeunit 10077081 "Prod Order Reopen Events ori"
{
    Access = Internal;
    EventSubscriberInstance = Manual;

    var
        OrderId: Guid;

    /// <summary>Limits document suppression to the finished order passed to this adapter.</summary>
    /// <param name="ProductionOrder">The finished order whose native move is about to run.</param>
    procedure SetOrder(ProductionOrder: Record "Production Order")
    begin
        OrderId := ProductionOrder.SystemId;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Prod. Order Status Management", OnBeforeShowReleasedProdOrderDocument, '', false, false)]
    local procedure SkipReleasedDocument(var ProductionOrder: Record "Production Order"; var IsHandled: Boolean)
    begin
        if ProductionOrder.SystemId = OrderId then
            IsHandled := true;
    end;
}
