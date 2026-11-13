namespace Origo.Bifrost.Manufacturing.Test;

/// <summary>Explicit post-company cleanup entry point for the owned MCP fixture receipt.</summary>
codeunit 97616 "Mfg MCP Cleanup Tst ori"
{
    trigger OnRun()
    var
        Fixture: Codeunit "Mfg MCP Fixture Tst ori";
    begin
        Fixture.CleanupDeletedCompanyReceipt();
    end;
}
