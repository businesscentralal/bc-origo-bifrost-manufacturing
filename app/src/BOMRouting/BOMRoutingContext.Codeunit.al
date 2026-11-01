namespace Origo.Bifrost.Manufacturing;

/// <summary>
/// Holds the flag that is true only while a Bifrost BOM or routing status call is running.
/// The version tables commit inside status validation unless a subscriber sets SkipCommit.
/// That subscriber reads this flag, so a later page-style validate commits as standard
/// Business Central does. The flag is single-instance and is cleared on every path.
/// </summary>
codeunit 10077093 "BOM Routing Context ori"
{
    Access = Internal;
    SingleInstance = true;
    InherentPermissions = X;
    InherentEntitlements = X;

    var
        Active: Boolean;

    /// <summary>Marks the start of a Bifrost status call.</summary>
    procedure Activate()
    begin
        Active := true;
    end;

    /// <summary>Clears the flag when the call ends, including after an error.</summary>
    procedure Deactivate()
    begin
        Active := false;
    end;

    /// <summary>True only while a Bifrost status call is on the stack.</summary>
    /// <returns>True when version commits must be suppressed.</returns>
    procedure IsActive(): Boolean
    begin
        exit(Active);
    end;
}
