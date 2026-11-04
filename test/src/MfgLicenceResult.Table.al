namespace Origo.Bifrost.Manufacturing.Test;

/// <summary>Holds one owned background-session result for an actual unlicensed-company test.</summary>
table 97612 "Mfg Licence Result Tst ori"
{
    DataClassification = SystemMetadata;
    DataPerCompany = false;

    fields
    {
        field(1; Id; Guid) { }
        field(2; Completed; Boolean) { }
        field(3; Response; Blob) { }
    }
    keys
    {
        key(PK; Id) { Clustered = true; }
    }
}
