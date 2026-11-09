namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Inventory.Location;
using Microsoft.Inventory.Planning;
using Microsoft.Manufacturing.WorkCenter;
using Microsoft.Warehouse.Request;
using System.TestLibraries.Utilities;

/// <summary>Grants test helper execution without granting either manufacturing write implementation.</summary>
permissionset 97609 "Mfg NoGrant Tst ori"
{
    Assignable = true;
    Caption = 'Mfg permission test', Locked = true;
    IncludedPermissionSets = "Mfg Platform Tst ori";
    Permissions = codeunit "Mfg Test Data ori" = X,
                  codeunit "Mfg ProdOrder Perm Tests ori" = X,
                  codeunit "BOM Routing Test Lib ori" = X,
                  codeunit "BOM Routing Perm Tests ori" = X,
                  codeunit "Library Assert" = X,
                  table "Mfg Licence Result Tst ori" = X,
                  tabledata "Mfg Licence Result Tst ori" = RIMD,
                  // Native Refresh inserts and updates assignments through the table's indirect permission.
                  // BC 29 production-order insert reads a stockkeeping unit before the Manufacturing gate returns.
                  tabledata "Planning Assignment" = Rim,
                  tabledata "Stockkeeping Unit" = R,
                  tabledata "Warehouse Request" = R,
                  tabledata "Work Center" = R;
}
