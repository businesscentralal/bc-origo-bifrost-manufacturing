namespace Origo.Bifrost.Manufacturing.Test;

using Origo.Bifrost;
using System.TestLibraries.Security.AccessControl;
using System.TestLibraries.Utilities;

/// <summary>
/// Asserts that Bifrost Manufacturing makes itself known to Bifrost Foundation's application
/// registry, including while Bifrost Setup opens under the exact licence administrator role.
/// Foundation shows the setup notifications for the whole family on its own Bifrost Setup page,
/// and it can only report on an application that answers <c>OnRegisterApps</c> - so losing the
/// subscriber, or a missing InherentPermissions on it, would silently drop this app off that page
/// or break the page for a licence administrator.
/// </summary>
codeunit 97602 "Mfg Registration Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        AppUnderTestId: Guid;
        AppNameTok: Label 'Bifrost Manufacturing', Locked = true;
        AppIdNotFoundErr: Label 'The test app must depend on %1 for this test to resolve its app id.', Comment = '%1 = the app name', Locked = true;

    [Test]
    procedure GetApps_ListsManufacturing()
    var
        TempApps: Record "Registered App ori" temporary;
        AppRegistry: Codeunit "App Registry ori";
    begin
        // [GIVEN] The module id of the app under test
        Initialize();

        // [WHEN] Foundation builds the registry of installed Bifrost applications
        AppRegistry.GetApps(TempApps);

        // [THEN] Bifrost Manufacturing is in it, under its own module id and name
        Assert.IsTrue(TempApps.Get(AppUnderTestId), 'Bifrost Manufacturing should register itself with the Bifrost application registry.');
        Assert.AreEqual(AppNameTok, TempApps."App Name", 'The registry should carry the app display name.');
        Assert.AreEqual(0, TempApps."Setup Page Id", 'This app has no setup page of its own.');
    end;

    [Test]
    procedure GetApps_UnderLicenseAdminRole_ListsManufacturing()
    var
        TempApps: Record "Registered App ori" temporary;
        AppRegistry: Codeunit "App Registry ori";
        Found: Boolean;
    begin
        // [GIVEN] The module id of the app under test and a session that holds only the licence administrator role
        Initialize();
        LowerPermissions.SetExactPermissionSet('BIFROST LicAdm ori');
        LowerPermissions.AddPermissionSet('Wizard Platform ori');

        // [WHEN] Foundation builds the registry, as it does when Bifrost Setup opens
        AppRegistry.GetApps(TempApps);
        Found := TempApps.Get(AppUnderTestId);
        LowerPermissions.SetOutsideO365Scope();

        // [THEN] The registration subscriber ran without a permission error and the app is listed
        Assert.IsTrue(Found, 'Bifrost Manufacturing should register itself under the licence administrator role.');
    end;

    /// <summary>
    /// Resolves the module id of Bifrost Manufacturing from this test app's own dependency
    /// list, so the test never carries a hard-coded guid.
    /// </summary>
    local procedure Initialize()
    var
        TestAppInfo: ModuleInfo;
        Dependency: ModuleDependencyInfo;
    begin
        Clear(AppUnderTestId);
        NavApp.GetCurrentModuleInfo(TestAppInfo);
        foreach Dependency in TestAppInfo.Dependencies() do
            if Dependency.Name() = AppNameTok then
                AppUnderTestId := Dependency.Id();

        if IsNullGuid(AppUnderTestId) then
            Error(AppIdNotFoundErr, AppNameTok);
    end;
}
