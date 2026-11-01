namespace Origo.Bifrost.Manufacturing;

/// <summary>
/// Grants execute permission on every object in the Bifrost Manufacturing extension.
/// Assign this alongside a Bifrost Core permission set to let a user or service invoke the
/// Manufacturing message types. The message types themselves run under the caller's own
/// permissions on the Business Central manufacturing tables, so this set does not widen access
/// to production or routing data. Add every new codeunit that a message type runs to this set.
/// </summary>
permissionset 10077036 "BIFROST Mfg ori"
{
    Caption = 'Bifrost Manufacturing', MaxLength = 30, Comment = 'is-IS=Bifröst - framleiðsla';
    Assignable = true;
    Access = Public;

    Permissions =
        codeunit "Mfg Registration ori" = X,
        codeunit "Mfg BOMRtg Contract ori" = X,
        codeunit "Prod BOM Status Impl ori" = X,
        codeunit "Prod BOM Status Proc ori" = X,
        codeunit "Routing Status Impl ori" = X,
        codeunit "Routing Status Proc ori" = X,
        codeunit "BOM Routing Restrict ori" = X,
        codeunit "BOM Routing Events ori" = X,
        codeunit "BOM Routing Context ori" = X;
}
