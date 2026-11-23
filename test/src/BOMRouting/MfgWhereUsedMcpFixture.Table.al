namespace Origo.Bifrost.Manufacturing.Test;

/// <summary>Self-seeded where-used MCP fixture. Only issue 29 test prefixes are accepted.</summary>
table 97644 "Mfg WhereUsed MCP Fixture ori"
{
    DataClassification = CustomerContent;
    Caption = 'Where-used MCP fixture', Locked = true;

    fields
    {
        field(1; Code; Code[10])
        {
            Caption = 'Code', Locked = true;
        }
        field(3; "Probe Native Exchange"; Boolean)
        {
            Caption = 'Probe native exchange', Locked = true;
        }
        field(2; Cleanup; Boolean)
        {
            Caption = 'Cleanup', Locked = true;
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
        Fixture: Codeunit "Mfg WhereUsed Fixture ori";
    begin
        if not (Code in ['X29MCPEN', 'X29MCPIS', 'X29TEST']) then
            Error('Only owned issue 29 test prefixes are accepted.');
        if Cleanup then
            Error('A new fixture must start before cleanup.');
        Fixture.Seed(Code);
    end;

    trigger OnModify()
    var
        Previous: Record "Mfg WhereUsed MCP Fixture ori";
        Fixture: Codeunit "Mfg WhereUsed Fixture ori";
    begin
        Previous.Get(Code);
        if Cleanup <> Previous.Cleanup then
            if Cleanup then
                Fixture.Cleanup(Code)
            else
                Fixture.Seed(Code);
        if "Probe Native Exchange" and not Previous."Probe Native Exchange" then
            Fixture.ProbeNativeExchange(Code);
    end;

    trigger OnDelete()
    var
        Fixture: Codeunit "Mfg WhereUsed Fixture ori";
    begin
        if not Cleanup then
            Fixture.Cleanup(Code);
    end;
}
