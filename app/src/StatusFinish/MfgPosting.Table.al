namespace Origo.Bifrost.Manufacturing;

/// <summary>
/// Posting token for the irreversible Manufacturing status types. No records are stored.
/// Write permission on this table is granted only by the assignable BIFROST MfgPost ori set.
/// </summary>
table 10077050 "Mfg Posting ori"
{
    Access = Internal;
    Caption = 'Manufacturing Posting', Comment = 'is-IS=Bókun framleiðslu';
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
