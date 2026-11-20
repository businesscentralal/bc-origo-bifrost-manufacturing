namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Manufacturing.Document;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Issue 22 AC07/C1: read, no-posting-token and no-permission callers cannot discover or execute Reopen.</summary>
codeunit 97636 "Mfg Reopen Perm Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Data: Codeunit "Mfg Test Data ori";
        Fixture: Codeunit "Mfg Reopen Fixture ori";
        Lib: Codeunit "Mfg Status Test Lib ori";
        Assert: Codeunit "Library Assert";
        LowerPermissions: Codeunit "Library - Lower Permissions";

    [Test]
    procedure AC07_ReadRoleRefused()
    begin
        // Story #22, AC07/C1 | Time: WorkDate postings | Risk: None
        CheckRefusal('BIFROST Read ori', false);
    end;

    [Test]
    procedure AC07_FullWithoutPostingTokenRefused()
    begin
        // Story #22, AC07/C1 | Time: WorkDate postings | Risk: None
        CheckRefusal('BIFROST Full ori', false);
    end;

    [Test]
    procedure AC07_NoManufacturingPermissionRefused()
    begin
        // Story #22, AC07/C1 | Time: WorkDate postings | Risk: None
        CheckRefusal('BIFROST API ori', false);
    end;

    [Test]
    procedure AC07_ReadWithPostingTokenStillRefused()
    begin
        // Story #22, AC07/C1 | Time: WorkDate postings | Risk: None
        CheckRefusal('BIFROST Read ori', true);
    end;

    local procedure CheckRefusal(Role: Code[20]; WithPosting: Boolean)
    var
        Order: Record "Production Order";
        Header: Record "Production Order";
        Line: Record "Prod. Order Line";
        Component: Record "Prod. Order Component";
        Routing: Record "Prod. Order Routing Line";
        Discovery: Interface "Msg Interface ori";
        Request: JsonObject;
        Response: JsonObject;
        Enabled: Boolean;
        MessageId: Guid;
        Counts: array[4] of Integer;
    begin
        Fixture.PrepareFinished('X22REOPEN', Order);
        Counts[1] := Header.Count();
        Counts[2] := Line.Count();
        Counts[3] := Component.Count();
        Counts[4] := Routing.Count();
        Request := Lib.IdRequest(Order);
        Request.Add('expectedCount', 1);
        Commit();
        LowerPermissions.SetExactPermissionSet(Role);
        LowerPermissions.AddPermissionSet('D365 BASIC');
        LowerPermissions.AddPermissionSet('D365PREM MFG, EDIT');
        LowerPermissions.AddPermissionSet('Mfg NoPost Tst ori');
        if WithPosting then
            LowerPermissions.AddPermissionSet('BIFROST MfgPost ori');
        Discovery := "Message Type ori"::"Manufacturing.ProductionOrder.Reopen";
        Enabled := Discovery.IsEnabled();
        Response := Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Reopen", Request, 1033, false, MessageId);
        LowerPermissions.SetOutsideO365Scope();
        if not WithPosting then
            Assert.IsFalse(Enabled, 'Reopen hidden without posting token.');
        Data.AssertRefusal(Response, 'PermissionDenied');
        Fixture.AssertLoggedError(MessageId, 'PermissionDenied');
        Assert.AreEqual(Counts[1], Header.Count(), 'Headers unchanged.');
        Assert.AreEqual(Counts[2], Line.Count(), 'Lines unchanged.');
        Assert.AreEqual(Counts[3], Component.Count(), 'Components unchanged.');
        Assert.AreEqual(Counts[4], Routing.Count(), 'Routings unchanged.');
        Assert.IsTrue(Order.Get(Order.Status::Finished, Order."No."), 'Order remains Finished.');
        Fixture.Cleanup('X22REOPEN');
        Commit();
    end;
}
