namespace Origo.Bifrost.Manufacturing;

using Origo.Bifrost;

/// <summary>
/// Extends the Bifrost read-only permission set with the Manufacturing registration codeunit.
/// Manufacturing message types that write or run inside a transaction are not granted here on
/// purpose: a read-only Bifrost user is not meant to invoke them. Invoking one requires
/// "BIFROST Mfg ori" or "BIFROST MfgFull ori".
/// </summary>
permissionsetextension 10077038 "BIFROST MfgRead ori" extends "BIFROST Read ori"
{
    Permissions =
        codeunit "Mfg Registration ori" = X;
}
