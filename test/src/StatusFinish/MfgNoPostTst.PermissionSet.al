namespace Origo.Bifrost.Manufacturing.Test;

using System.TestLibraries.Utilities;

/// <summary>Grants the status test helpers without the BIFROST MfgPost ori posting token.</summary>
permissionset 97627 "Mfg NoPost Tst ori"
{
    Assignable = true;
    Caption = 'Mfg no posting test', Locked = true;
    IncludedPermissionSets = "Mfg NoGrant Tst ori";
    Permissions = codeunit "Mfg Status Test Lib ori" = X,
                  codeunit "Mfg Posting Gate Tests ori" = X,
                  codeunit "Prod Jnl Test Lib ori" = X,
                  codeunit "Prod Jnl Gap Tests ori" = X,
                  codeunit "Library Assert" = X;
}
