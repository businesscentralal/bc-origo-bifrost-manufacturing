namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Manufacturing.Document;
using Origo.Bifrost;
using System.TestLibraries.Security.AccessControl;
using System.TestLibraries.Utilities;

/// <summary>Issue 26 AC04: native read users succeed only with the Manufacturing read role.</summary>
codeunit 97631 "Mfg Read Permissions ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Data: Codeunit "Mfg Test Data ori";
        Fixture: Codeunit "Mfg Read Fixture ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure AC04_ReadRoleSucceedsForBothReads()
    begin
        CheckPermissions(true);
    end;

    [Test]
    procedure AC04_WithoutManufacturingRoleBothReadsRefused()
    begin
        CheckPermissions(false);
    end;

    local procedure CheckPermissions(WithReadRole: Boolean)
    var
        Order: Record "Production Order";
        Request: JsonObject;
        Response: JsonObject;
        Kind: Enum "Message Type ori";
        Kinds: List of [Enum "Message Type ori"];
        LanguageId: Integer;
        Languages: List of [Integer];
        Raw: Text;
        CountBefore: Integer;
    begin
        Fixture.Seed(CopyStr('X26' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, 10), Order);
        Request.Add('no', Order."No.");
        Request.Add('status', 'Released');
        Kinds.Add(Kind::"Manufacturing.ComponentAvailability.Get");
        Kinds.Add(Kind::"Manufacturing.ProductionOrderStatistics.Get");
        Languages.Add(1033);
        Languages.Add(1039);
        CountBefore := Order.Count();
        foreach Kind in Kinds do
            foreach LanguageId in Languages do begin
                LowerPermissions.SetExactPermissionSet('BIFROST API ori');
                LowerPermissions.AddPermissionSet('D365 BASIC');
                LowerPermissions.AddPermissionSet('D365 READ');
                LowerPermissions.AddPermissionSet('Mfg Read NoGrant ori');
                if WithReadRole then
                    LowerPermissions.AddPermissionSet('BIFROST Read ori');
                Response := Data.Invoke(Kind, Request, LanguageId, false);
                LowerPermissions.SetOutsideO365Scope();
                if WithReadRole then begin
                    Response.WriteTo(Raw);
                    Assert.AreEqual('Success', Data.TextValue(Response, 'status'), Raw);
                end else
                    Data.AssertRefusal(Response, 'PermissionDenied');
                Assert.AreEqual(CountBefore, Order.Count(), 'Permission checks never change orders.');
            end;
    end;
}
