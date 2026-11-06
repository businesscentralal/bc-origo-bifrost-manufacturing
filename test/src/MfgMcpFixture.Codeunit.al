namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Inventory.Item;
using Microsoft.Manufacturing.Setup;
using System.Environment;

/// <summary>Seeds owned MCP fixtures through native BC validation, without changing consent or write guards.</summary>
codeunit 97614 "Mfg MCP Fixture Tst ori"
{
    trigger OnRun()
    var
        Item: Record Item;
        Setup: Record "Manufacturing Setup";
        Company: Record Company;
        Result: Record "Mfg Licence Result Tst ori";
        Data: Codeunit "Mfg Test Data ori";
        JournalLib: Codeunit "Prod Jnl Test Lib ori";
        Payload: JsonObject;
        Value: Text;
        Output: OutStream;
        FixtureId: Guid;
    begin
        // Posting needs production accounts; fill only empty ones on this owned container so MCP Post can succeed.
        JournalLib.FillPostingAccounts();
        Evaluate(FixtureId, '4e54efe5-d98c-499f-95bd-5cead5678305');
        if Result.Get(FixtureId) then
            Error('Owned MCP fixture already exists. Inspect its recorded identifiers before recovery.');
        Company.Get(CompanyName());
        Payload.Add('companyName', Company.Name);
        Payload.Add('companyId', Format(Company.SystemId, 0, 4));
        Setup.Get();
        Payload.Add('originalPlannedSeries', Setup."Planned Order Nos.");
        Payload.Add('originalFirmPlannedSeries', Setup."Firm Planned Order Nos.");
        Data.SetupNumbering(true);
        Data.CreateManufacturedItem(Item);
        Item.Rename('X-M5-MCP-ITEM');
        Payload.Add('itemNo', Item."No.");
        Payload.Add('bomNo', Item."Production BOM No.");
        Payload.Add('routingNo', Item."Routing No.");
        Setup.Get();
        Payload.Add('seriesCode', Setup."Planned Order Nos.");
        Payload.WriteTo(Value);
        Result.Init();
        Result.Id := FixtureId;
        Result.Response.CreateOutStream(Output, TextEncoding::UTF8);
        Output.WriteText(Value);
        Result.Completed := true;
        Result.Insert();
    end;

    /// <summary>Deletes only this fixture's global receipt after its owning company has been removed.</summary>
    procedure CleanupDeletedCompanyReceipt()
    var
        Result: Record "Mfg Licence Result Tst ori";
        Company: Record Company;
        Payload: JsonObject;
        Token: JsonToken;
        Input: InStream;
        Value: Text;
        FixtureId: Guid;
        CompanyId: Guid;
        FixtureCompanyName: Text;
    begin
        Evaluate(FixtureId, '4e54efe5-d98c-499f-95bd-5cead5678305');
        Result.ReadIsolation := IsolationLevel::UpdLock;
        if not Result.Get(FixtureId) then
            exit;
        Result.CalcFields(Response);
        Result.Response.CreateInStream(Input, TextEncoding::UTF8);
        Input.ReadText(Value);
        if not Payload.ReadFrom(Value) then
            Error('The owned fixture receipt is not valid JSON. Inspect it before cleanup.');
        if not Payload.Get('companyId', Token) then
            Error('The owned fixture receipt has no company identity. Inspect it before cleanup.');
        if not Evaluate(CompanyId, Token.AsValue().AsText()) then
            Error('The owned fixture receipt has no valid company identity. Inspect it before cleanup.');
        if IsNullGuid(CompanyId) then
            Error('The owned fixture receipt has no valid company identity. Inspect it before cleanup.');
        if not Payload.Get('companyName', Token) then
            Error('The owned fixture receipt has no company name. Inspect it before cleanup.');
        FixtureCompanyName := Token.AsValue().AsText();
        if FixtureCompanyName = '' then
            Error('The owned fixture receipt has no company name. Inspect it before cleanup.');
        if Company.GetBySystemId(CompanyId) or Company.Get(FixtureCompanyName) then
            Error('Remove the owned fixture company before deleting its global receipt.');
        Result.Delete();
        if Result.Get(FixtureId) then
            Error('Owned fixture receipt cleanup failed.');
    end;
}
