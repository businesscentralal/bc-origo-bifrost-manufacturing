namespace Origo.Bifrost.Manufacturing;

/// <summary>
/// Permission target for Manufacturing write messages. No records are stored.
/// Unlike broad native codeunit Execute grants, write access to this app-owned table
/// is supplied only by the Manufacturing full role.
/// </summary>
table 10077046 "Mfg Write Gate ori"
{
    Access = Internal;
    Caption = 'Manufacturing Write Gate', Comment = 'is-IS=Skrifhlið framleiðslu';
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key', Comment = 'is-IS=Aðallykill';
        }
    }
    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }
}
