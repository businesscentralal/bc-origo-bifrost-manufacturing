namespace Origo.Bifrost.Manufacturing.Test;

using Origo.Bifrost.Manufacturing;
using System.TestLibraries.Utilities;

/// <summary>Reaches the read-role boundary with no Manufacturing token; test execution rights only.</summary>
permissionset 97632 "Mfg Read NoGrant ori"
{
    Assignable = true;
    Caption = 'Mfg read permission test', Locked = true;
    IncludedPermissionSets = "Mfg Platform Tst ori";
    Permissions = codeunit "Mfg Read Permissions ori" = X,
                  codeunit "Mfg Test Data ori" = X,
                  codeunit "Library Assert" = X,
                  codeunit "Mfg Component Get Impl ori" = X,
                  codeunit "Mfg Statistics Get Impl ori" = X,
                  codeunit "Mfg Order Read Request ori" = X,
                  codeunit "Mfg Order Read Calc ori" = X,
                  codeunit "Mfg Order Read Contract ori" = X;
}
