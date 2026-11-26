namespace Origo.Bifrost.Manufacturing;

using Origo.Bifrost;

/// <summary>Committing boundary for Manufacturing.ProductionOrder.Reschedule.</summary>
codeunit 10077116 "Prod Order Reschedule Proc ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        Engine: Codeunit "Prod Order Replan Proc ori";
    begin
        // Isolate the schedule write before the engine reads the order.
        CurrentTransactionType(TransactionType::Update);
        Engine.RunReschedule(Rec);
    end;
}
