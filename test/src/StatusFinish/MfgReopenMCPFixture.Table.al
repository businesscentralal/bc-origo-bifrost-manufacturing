namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Manufacturing.Document;
using Origo.Bifrost;

/// <summary>Own-tenant raw MCP fixture, operated through Foundation Tests; no product operation is added.</summary>
table 97638 "Mfg Reopen MCP Fixture ori"
{
    DataClassification = CustomerContent;
    Caption = 'Reopen MCP fixture', Locked = true;

    fields
    {
        field(1; Code; Code[10])
        {
            Caption = 'Code', Locked = true;
        }
        field(2; "Original Confirm"; Boolean)
        {
            Caption = 'Original confirmation', Locked = true;
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
        Fixture: Codeunit "Mfg Reopen Fixture ori";
        Lib: Codeunit "Mfg Status Test Lib ori";
        Setup: RecordRef;
        ConfirmField: FieldRef;
    begin
        if not (Code in ['X22MCPEN', 'X22MCPIS']) then
            Error('Only issue 22 MCP fixtures are allowed.');
        Setup.Open(Database::"Setup ori");
        if Setup.FindFirst() then begin
            ConfirmField := Setup.Field(36);
            "Original Confirm" := ConfirmField.Value;
        end;
        Setup.Close();
        Fixture.PrepareFinished(Code, Order);
        Lib.SetConfirmRequired(true);
    end;

    trigger OnDelete()
    var
        Fixture: Codeunit "Mfg Reopen Fixture ori";
        Lib: Codeunit "Mfg Status Test Lib ori";
    begin
        Fixture.Cleanup(Code);
        Lib.SetConfirmRequired("Original Confirm");
    end;
}
