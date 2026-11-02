namespace Origo.Bifrost.Manufacturing.Test;

using System.Environment;
using System.TestLibraries.Utilities;

/// <summary>Proves global fixture cleanup is explicit, company-bound and restricted to its own receipt.</summary>
codeunit 97617 "Mfg MCP Cleanup Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Fixture: Codeunit "Mfg MCP Fixture Tst ori";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Cleanup_RemovesOnlyDeletedCompanyReceipt()
    var
        Receipt: Record "Mfg Licence Result Tst ori";
        ForeignId: Guid;
        FixtureId: Guid;
    begin
        FixtureId := CreateReceipt(CreateGuid(), CopyStr('X-MFG-' + Format(CreateGuid(), 0, 4), 1, 30));
        ForeignId := CreateGuid();
        Receipt.Init();
        Receipt.Id := ForeignId;
        Receipt.Insert();

        // The external cleanup runner invokes this entry point after deleting the owned company.
        Codeunit.Run(Codeunit::"Mfg MCP Cleanup Tst ori");
        Assert.IsFalse(Receipt.Get(FixtureId), 'Deleted company receipt is removed.');
        Assert.IsTrue(Receipt.Get(ForeignId), 'Other session receipts remain untouched.');
        Fixture.CleanupDeletedCompanyReceipt();
        Assert.IsTrue(Receipt.Get(ForeignId), 'Repeated empty cleanup preserves other receipts.');
    end;

    [Test]
    procedure Cleanup_RefusesExistingCompanyIdentity()
    var
        Company: Record Company;
    begin
        Company.Get(CompanyName());
        CreateReceipt(Company.SystemId, 'X-MFG-RENAMED');
        asserterror Fixture.CleanupDeletedCompanyReceipt();
        Assert.ExpectedError('Remove the owned fixture company');
    end;

    [Test]
    procedure Cleanup_RefusesExistingCompanyName()
    begin
        CreateReceipt(CreateGuid(), CompanyName());
        asserterror Fixture.CleanupDeletedCompanyReceipt();
        Assert.ExpectedError('Remove the owned fixture company');
    end;

    [Test]
    procedure Cleanup_RefusesMissingCompanyIdentity()
    var
        EmptyId: Guid;
    begin
        CreateReceipt(EmptyId, 'X-MFG-MISSING');
        asserterror Fixture.CleanupDeletedCompanyReceipt();
        Assert.ExpectedError('no valid company identity');
    end;

    local procedure CreateReceipt(CompanyId: Guid; FixtureCompanyName: Text): Guid
    var
        Receipt: Record "Mfg Licence Result Tst ori";
        Payload: JsonObject;
        Output: OutStream;
        Value: Text;
    begin
        Evaluate(Receipt.Id, '4e54efe5-d98c-499f-95bd-5cead5678305');
        Assert.IsFalse(Receipt.Get(Receipt.Id), 'Cleanup tests never overwrite a pre-existing fixture receipt.');
        Payload.Add('companyId', Format(CompanyId, 0, 4));
        Payload.Add('companyName', FixtureCompanyName);
        Payload.WriteTo(Value);
        Receipt.Response.CreateOutStream(Output, TextEncoding::UTF8);
        Output.WriteText(Value);
        Receipt.Insert();
        exit(Receipt.Id);
    end;
}
