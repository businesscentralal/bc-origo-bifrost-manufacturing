namespace Origo.Bifrost.Manufacturing;

/// <summary>
/// Maintains the flag to suppress standard Business Central version commit during a Bifröst SetStatus call.
/// </summary>
codeunit 10077093 "BOM Routing Context ori"
{
    Access = Internal;
    SingleInstance = true;

    var
        InsideBifrostCall: Boolean;

    /// <summary>
    /// Gets whether a Bifröst SetStatus call is currently active.
    /// </summary>
    /// <returns>True if active.</returns>
    internal procedure IsInsideBifrostCall(): Boolean
    begin
        exit(InsideBifrostCall);
    end;

    /// <summary>
    /// Sets whether a Bifröst SetStatus call is active.
    /// </summary>
    /// <param name="NewInsideBifrostCall">True to activate.</param>
    internal procedure SetInsideBifrostCall(NewInsideBifrostCall: Boolean)
    begin
        InsideBifrostCall := NewInsideBifrostCall;
    end;
}
