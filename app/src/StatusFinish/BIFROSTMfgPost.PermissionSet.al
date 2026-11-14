namespace Origo.Bifrost.Manufacturing;

/// <summary>
/// Posting token for Manufacturing.ProductionOrder.ChangeStatus and Finish. Assign it explicitly
/// next to BIFROST Mfg ori; neither BIFROST MfgFull ori nor BIFROST MfgRead ori includes it.
/// </summary>
permissionset 10077051 "BIFROST MfgPost ori"
{
    Caption = 'Bifrost Manufacturing Posting', MaxLength = 30, Comment = 'is-IS=Bifröst - framleiðslubókun';
    Assignable = true;
    Access = Public;

    Permissions =
        table "Mfg Posting ori" = X,
        tabledata "Mfg Posting ori" = RIMD;
}
