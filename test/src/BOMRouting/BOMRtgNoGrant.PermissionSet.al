namespace Origo.Bifrost.Manufacturing.Test;

using System.TestLibraries.Utilities;

/// <summary>
/// Grants the test helpers Execute without granting either status implementation, so a restricted-role
/// test exercises the Manufacturing write gate and not a missing test helper permission.
/// </summary>
permissionset 97668 "BOM Rtg NoGrant ori"
{
    Assignable = true;
    Caption = 'BOM Routing permission test', Locked = true;
    IncludedPermissionSets = "Mfg Platform Tst ori";
    Permissions = codeunit "BOM Routing Test Lib ori" = X,
                  codeunit "BOM Routing Perm Tests ori" = X,
                  codeunit "Library Assert" = X;
}
