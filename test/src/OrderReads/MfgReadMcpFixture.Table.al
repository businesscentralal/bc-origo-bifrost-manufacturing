namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Manufacturing.Document;
using Microsoft.Manufacturing.Setup;
using Microsoft.Inventory.Ledger;

/// <summary>Test-only staged, self-owned MCP fixture. Public Test.Records.Set runs its triggers; no product UI or new operation is exposed.</summary>
table 97633 "Mfg Read MCP Fixture ori"
{
    DataClassification = CustomerContent;
    Caption = 'Manufacturing read MCP fixture', Locked = true;

    fields
    {
        field(1; Code; Code[10])
        {
            Caption = 'Code', Locked = true;
        }
        field(2; Stage; Integer)
        {
            Caption = 'Stage', Locked = true;
        }
        field(3; "Original Capacity Unit"; Code[10])
        {
            Caption = 'Original capacity unit', Locked = true;
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
        Setup: Record "Manufacturing Setup";
        Fixture: Codeunit "Mfg Read Fixture ori";
    begin
        if not (Code in ['X26MCPW', 'X26MCPI', 'X26MCPT']) then
            Error('Only issue 26 MCP fixture prefixes are allowed.');
        Setup.Get();
        "Original Capacity Unit" := Setup."Show Capacity In";
        Fixture.Seed(Code, Order);
        Fixture.Post(Code, "Item Ledger Entry Type"::"Positive Adjmt.", 2);
    end;

    trigger OnModify()
    var
        Previous: Record "Mfg Read MCP Fixture ori";
        Order: Record "Production Order";
        Fixture: Codeunit "Mfg Read Fixture ori";
    begin
        Previous.Get(Code);
        if Stage = Previous.Stage then
            exit;
        if Stage <> Previous.Stage + 1 then
            Error('Advance the fixture by exactly one stage.');
        case Stage of
            1:
                Fixture.Post(Code, "Item Ledger Entry Type"::"Positive Adjmt.", 3);
            2:
                begin
                    Fixture.Post(Code, "Item Ledger Entry Type"::Consumption, 5);
                    Fixture.Post(Code, "Item Ledger Entry Type"::Output, 1);
                    Order.Get(Order.Status::Released, Code);
                    Fixture.FinishAndAdjust(Order);
                end;
            3:
                Cleanup();
            else
                Error('The fixture has already been cleaned.');
        end;
    end;

    trigger OnDelete()
    begin
        if Stage <> 3 then
            Cleanup();
    end;

    local procedure Cleanup()
    var
        Setup: Record "Manufacturing Setup";
        Fixture: Codeunit "Mfg Read Fixture ori";
    begin
        Setup.Get();
        if Setup."Show Capacity In" = Code then begin
            Setup."Show Capacity In" := "Original Capacity Unit";
            Setup.Modify();
        end;
        Fixture.Cleanup(Code);
    end;
}
