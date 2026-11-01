namespace Origo.Bifrost.Manufacturing;

/// <summary>
/// Reports whether a status call has bound its local commit-suppression subscriber.
/// The binding is released by AL when the call returns or unwinds on an error,
/// including Omit Commit calls, without a write inside a TryFunction.
/// </summary>
codeunit 10077093 "BOM Routing Context ori"
{
    Access = Internal;
    SingleInstance = true;
    InherentPermissions = X;
    InherentEntitlements = X;

    /// <summary>True only while a status call owns a manual subscription.</summary>
    /// <returns>True when version commits must be suppressed.</returns>
    procedure IsActive() Active: Boolean
    begin
        OnIsActive(Active);
    end;

    [IntegrationEvent(false, false)]
    local procedure OnIsActive(var Active: Boolean)
    begin
    end;
}
