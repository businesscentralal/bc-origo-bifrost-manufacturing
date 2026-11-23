namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Manufacturing.Document;
using Origo.Bifrost;

/// <summary>Owned raw reversal fixtures for bilingual MCP tests; deletion cleans every created business record.</summary>
table 97655 "Mfg Reverse MCP Fixture ori"
{
    DataClassification = CustomerContent;
    Caption = 'Reversal MCP fixture', Locked = true;
    fields
    {
        field(1; Code; Code[10])
        {
            Caption = 'Code', Locked = true;
        }
    }
    keys
    {
        key(PK; Code)
        {
            Clustered = true;
        }
    }
    trigger OnInsert()
    var
        Order: Record "Production Order";
        Lib: Codeunit "Mfg Reverse Test Lib ori";
    begin
        if not (Code in ['X25MCPEN', 'X25MCPIS']) then
            Error('Only issue 25 MCP fixture codes are allowed.');
        Lib.Seed(Code, false, Order);
        Lib.PostOrder(Order);
        Lib.RestoreWorkDate();
    end;
    trigger OnDelete()
    var
        Lib: Codeunit "Mfg Reverse Test Lib ori";
    begin
        Lib.Cleanup(Code);
    end;
}
