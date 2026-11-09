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
        codeunit "Mfg ProdOrder Contract ori" = X,
        codeunit "Prod Order Create Impl ori" = X,
        codeunit "Prod Order Refresh Impl ori" = X,
        codeunit "Prod Order Refresh Proc ori" = X,
        codeunit "Mfg Prod Order Lookup ori" = X,
        codeunit "Mfg Prod Order Request ori" = X,
        codeunit "Mfg BOMRtg Contract ori" = X,
        codeunit "Prod BOM Status Impl ori" = X,
        codeunit "Prod BOM Status Proc ori" = X,
        codeunit "Routing Status Impl ori" = X,
        codeunit "Routing Status Proc ori" = X,
        codeunit "BOM Routing Restrict ori" = X,
        codeunit "BOM Routing Events ori" = X,
        codeunit "BOM Routing Context ori" = X,
        codeunit "Mfg Write Check ori" = X,
        codeunit "Mfg Posting Gate ori" = X,
        codeunit "Mfg Status Contract ori" = X,
        codeunit "Prod Order Status Impl ori" = X,
        codeunit "Prod Order Status Proc ori" = X,
        codeunit "Prod Order Finish Impl ori" = X,
        codeunit "Prod Order Finish Proc ori" = X,
        codeunit "Prod Ord Fin Check Impl ori" = X,
        codeunit "Prod Order Finish Check ori" = X,
        codeunit "Prod Order Confirm ori" = X,
        codeunit "Prod Order Restrict ori" = X,
        codeunit "Mfg Write Context ori" = X,
        codeunit "Mfg ProdJnl Contract ori" = X,
        codeunit "Prod Jnl Get Impl ori" = X,
        codeunit "Prod Jnl Preview Impl ori" = X,
        codeunit "Prod Jnl Post Impl ori" = X,
        codeunit "Prod Jnl Post Proc ori" = X,
        codeunit "Prod Jnl Builder ori" = X,
        codeunit "Prod Jnl Events ori" = X,
        codeunit "Prod Jnl Confirm ori" = X,
        codeunit "Prod Jnl Request ori" = X,
        table "Mfg Posting ori" = X,
        table "Mfg Write Gate ori" = X,
        tabledata "Mfg Write Gate ori" = RIMD;
}
