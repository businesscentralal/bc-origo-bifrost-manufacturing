namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Inventory.Item;
using Microsoft.Manufacturing.Setup;

/// <summary>Seeds owned MCP fixtures through native BC validation, without changing consent or write guards.</summary>
codeunit 97614 "Mfg MCP Fixture Tst ori"
{
    trigger OnRun()
    var
        Item: Record Item;
        Setup: Record "Manufacturing Setup";
        Result: Record "Mfg Licence Result Tst ori";
        Data: Codeunit "Mfg Test Data ori";
        Payload: JsonObject;
        Value: Text;
        Output: OutStream;
        FixtureId: Guid;
    begin
        Evaluate(FixtureId, '4e54efe5-d98c-499f-95bd-5cead5678305');
        if Result.Get(FixtureId) then
            Error('Owned MCP fixture already exists. Inspect its recorded identifiers before recovery.');
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
}
