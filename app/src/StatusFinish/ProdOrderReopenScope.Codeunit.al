namespace Origo.Bifrost.Manufacturing;

using Microsoft.Manufacturing.Document;

/// <summary>Scopes the BC 28.5 public reopen adapter to one pre-confirmed operation.</summary>
codeunit 10077077 "Prod Order Reopen Scope ori"
{
    Access = Internal;
    SingleInstance = true;

    /// <summary>Runs the native reopen wrapper after the permission and native precondition checks.</summary>
    /// <param name="ProductionOrder">The finished order already checked by the caller.</param>
    procedure Reopen(var ProductionOrder: Record "Production Order")
    var
        Events: Codeunit "Prod Order Reopen Events ori";
        StatusMgt: Codeunit "Prod. Order Status Management";
    begin
        // Keep the subscriber local and non-single-instance: scope unwinding unbinds it on error,
        // including Omit Commit, without catching writes in a TryFunction.
        Events.SetOrder(ProductionOrder);
        BindSubscription(Events);
        // Confirm Management returns the default Yes in API sessions. GUI callers still confirm;
        // This non-posting write needs no irreversible confirmation; native preconditions were checked.
        StatusMgt.ReopenFinishedProdOrder(ProductionOrder);
        UnbindSubscription(Events);
    end;
}
