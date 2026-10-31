namespace Origo.Bifrost.Manufacturing.Test;

/// <summary>
/// Refreshes the MANUFACTUR test suite when the test app is republished. OnInstallAppPerCompany
/// only fires on a genuinely fresh install, so without this an in-place version upgrade would
/// leave the suite pointing at the previous release's test methods.
/// </summary>
codeunit 97601 "Mfg Test Upgrade ori"
{
    Subtype = Upgrade;

    trigger OnUpgradePerCompany()
    var
        TestInstall: Codeunit "Mfg Test Install ori";
    begin
        TestInstall.RefreshTestSuite();
    end;
}
