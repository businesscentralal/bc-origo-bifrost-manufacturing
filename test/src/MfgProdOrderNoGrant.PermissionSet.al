namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Inventory.Planning;
using Microsoft.Manufacturing.WorkCenter;

/// <summary>Grants test helper execution without granting either manufacturing write implementation.</summary>
permissionset 97609 "Mfg NoGrant Tst ori"
{
    Assignable = true;
    Caption = 'Mfg permission test', Locked = true;
    IncludedPermissionSets = "Mfg Platform Tst ori";
    Permissions = codeunit "Mfg Test Data ori" = X,
                  codeunit "Mfg ProdOrder Perm Tests ori" = X,
                  table "Mfg Licence Result Tst ori" = X,
                  tabledata "Mfg Licence Result Tst ori" = RIMD,
                  // Native Refresh inserts and updates assignments through the table's indirect permission.
                  tabledata "Planning Assignment" = Rim,
                  tabledata "Work Center" = R;
}
