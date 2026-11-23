namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Manufacturing.Document;
using Microsoft.Inventory.Ledger;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Issue 25 AC05/C1: read, no-posting-token and no-permission callers cannot discover or execute reversal.</summary>
codeunit 97654 "Mfg Reverse Perm Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Data: Codeunit "Mfg Test Data ori";
        Fixture: Codeunit "Mfg Reopen Fixture ori";
        LibReverse: Codeunit "Mfg Reverse Test Lib ori";
        Assert: Codeunit "Library Assert";
        LowerPermissions: Codeunit "Library - Lower Permissions";

    [Test]
    procedure AC05_ReadRoleRefused()
    begin
        // Story #22, AC05/C1 | Time: WorkDate postings | Risk: None
        CheckRefusal('BIFROST Read ori', false);
    end;

    [Test]
    procedure AC05_FullWithoutPostingTokenRefused()
    begin
        // Story #22, AC05/C1 | Time: WorkDate postings | Risk: None
        CheckRefusal('BIFROST Full ori', false);
    end;

    [Test]
    procedure AC05_NoManufacturingPermissionRefused()
    begin
        // Story #22, AC05/C1 | Time: WorkDate postings | Risk: None
        CheckRefusal('BIFROST API ori', false);
    end;

    [Test]
    procedure AC05_ReadWithPostingTokenStillRefused()
    begin
        // Story #22, AC05/C1 | Time: WorkDate postings | Risk: None
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
        OutputMessageId: Guid;
        CountsBefore: Text;
        Counts: array[4] of Integer;
    begin
        LibReverse.Seed('X25REV', false, Order);
        LibReverse.PostOrder(Order);
        CountsBefore := LibReverse.Snapshot();
        Counts[1] := Header.Count();
        Counts[2] := Line.Count();
        Counts[3] := Component.Count();
        Counts[4] := Routing.Count();
        Request := LibReverse.Request(Order, LibReverse.Original(Order, "Item Ledger Entry Type"::Output));
        Commit();
        LowerPermissions.SetExactPermissionSet(Role);
        LowerPermissions.AddPermissionSet('D365 BASIC');
        LowerPermissions.AddPermissionSet('D365PREM MFG, EDIT');
        LowerPermissions.AddPermissionSet('Mfg NoPost Tst ori');
        if WithPosting then
            LowerPermissions.AddPermissionSet('BIFROST MfgPost ori');
        Discovery := "Message Type ori"::"Manufacturing.Output.Reverse";
        Enabled := Discovery.IsEnabled();
        Response := Data.Invoke("Message Type ori"::"Manufacturing.Output.Reverse", Request, 1033, false, MessageId);
        Data.AssertRefusal(Response, 'PermissionDenied');
        OutputMessageId := MessageId;
        Response := Data.Invoke("Message Type ori"::"Manufacturing.Consumption.Reverse", Request, 1039, false, MessageId);
        LowerPermissions.SetOutsideO365Scope();
        Fixture.AssertLoggedError(OutputMessageId, 'PermissionDenied');
        if not WithPosting then
            Assert.IsFalse(Enabled, 'reversal hidden without posting token.');
        Data.AssertRefusal(Response, 'PermissionDenied');
        Fixture.AssertLoggedError(MessageId, 'PermissionDenied');
        Assert.AreEqual(CountsBefore, LibReverse.Snapshot(), 'Posting and production counts unchanged under both denied calls.');
        Assert.AreEqual(Counts[1], Header.Count(), 'Headers unchanged.');
        Assert.AreEqual(Counts[2], Line.Count(), 'Lines unchanged.');
        Assert.AreEqual(Counts[3], Component.Count(), 'Components unchanged.');
        Assert.AreEqual(Counts[4], Routing.Count(), 'Routings unchanged.');
        Assert.IsTrue(Order.Get(Order.Status::Released, Order."No."), 'Order remains Finished.');
        LibReverse.Cleanup('X25REV');
        Commit();
    end;
}
