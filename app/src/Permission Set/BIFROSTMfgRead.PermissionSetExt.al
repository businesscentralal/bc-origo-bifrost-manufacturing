namespace Origo.Bifrost.Manufacturing;

using Origo.Bifrost;

/// <summary>
/// Extends the Bifrost read-only permission set with the Manufacturing registration codeunit.
/// Manufacturing message types that write or run inside a transaction are not granted here on
/// purpose: a read-only Bifrost user is not meant to invoke them. Invoking one requires
/// "BIFROST Mfg ori" or "BIFROST MfgFull ori". The write gate remains read-only
/// even when native D365 roles grant Execute on all codeunits.
/// </summary>
permissionsetextension 10077038 "BIFROST MfgRead ori" extends "BIFROST Read ori"
{
    Permissions =
        codeunit "Mfg Registration ori" = X,
        codeunit "Mfg Write Check ori" = X,
        codeunit "Mfg Status Contract ori" = X,
        codeunit "Prod Ord Fin Check Impl ori" = X,
        codeunit "Prod Order Finish Check ori" = X,
        codeunit "Mfg Prod Order Lookup ori" = X,
        codeunit "Mfg Prod Order Request ori" = X,
        codeunit "Prod Order Restrict ori" = X,
        codeunit "Mfg ProdJnl Contract ori" = X,
        codeunit "Prod Jnl Get Impl ori" = X,
        codeunit "Prod Jnl Preview Impl ori" = X,
        codeunit "Prod Jnl Post Proc ori" = X,
        codeunit "Prod Jnl Builder ori" = X,
        codeunit "Prod Jnl Events ori" = X,
        codeunit "Prod Jnl Request ori" = X,
        table "Mfg Write Gate ori" = X,
        tabledata "Mfg Write Gate ori" = R;
}
