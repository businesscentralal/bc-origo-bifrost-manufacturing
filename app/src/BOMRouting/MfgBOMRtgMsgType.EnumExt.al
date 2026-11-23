namespace Origo.Bifrost.Manufacturing;

using Origo.Bifrost;

/// <summary>
/// Registers the production BOM and routing certification message types.
/// Generic Data.Records.Set cannot certify these records: Business Central runs the
/// standard checks on validate, and a version status change commits unless this app
/// suppresses that commit for the duration of the call.
/// </summary>
enumextension 10077085 "Mfg BOMRtg MsgType ori" extends "Message Type ori"
{
    /// <summary>Certifies a production BOM or one version, or returns it to Under Development.</summary>
    value(10077087; "Manufacturing.ProductionBOM.SetStatus")
    {
        Caption = 'Manufacturing.ProductionBOM.SetStatus', Locked = true;
        Implementation = "Msg Interface ori" = "Prod BOM Status Impl ori", "Msg Discovery ori" = "Prod BOM Status Impl ori", "Msg Contract ori" = "Prod BOM Status Impl ori";
    }

    /// <summary>Certifies a routing or one version, or returns it to Under Development.</summary>
    value(10077089; "Manufacturing.Routing.SetStatus")
    {
        Caption = 'Manufacturing.Routing.SetStatus', Locked = true;
        Implementation = "Msg Interface ori" = "Routing Status Impl ori", "Msg Discovery ori" = "Routing Status Impl ori", "Msg Contract ori" = "Routing Status Impl ori";
    }

    /// <summary>Copies a production BOM into a new version on the same BOM.</summary>
    value(10077094; "Manufacturing.ProductionBOM.CopyVersion")
    {
        Caption = 'Manufacturing.ProductionBOM.CopyVersion', Locked = true;
        Implementation = "Msg Interface ori" = "Prod BOM Copy Impl ori", "Msg Discovery ori" = "Prod BOM Copy Impl ori", "Msg Contract ori" = "Prod BOM Copy Impl ori";
    }

    /// <summary>Copies a routing into a new version on the same routing.</summary>
    value(10077096; "Manufacturing.Routing.CopyVersion")
    {
        Caption = 'Manufacturing.Routing.CopyVersion', Locked = true;
        Implementation = "Msg Interface ori" = "Routing Copy Impl ori", "Msg Discovery ori" = "Routing Copy Impl ori", "Msg Contract ori" = "Routing Copy Impl ori";
    }
    /// <summary>Finds assemblies using an item or production BOM.</summary>
    value(10077102; "Manufacturing.WhereUsed.Get")
    {
        Caption = 'Manufacturing.WhereUsed.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Mfg WhereUsed Impl ori", "Msg Discovery ori" = "Mfg WhereUsed Impl ori", "Msg Contract ori" = "Mfg WhereUsed Impl ori";
    }
    /// <summary>Exchanges components by creating confirmed new production BOM versions.</summary>
    value(10077105; "Manufacturing.ProductionBOM.ExchangeItem")
    {
        Caption = 'Manufacturing.ProductionBOM.ExchangeItem', Locked = true;
        Implementation = "Msg Interface ori" = "Mfg Exchange Impl ori", "Msg Discovery ori" = "Mfg Exchange Impl ori", "Msg Contract ori" = "Mfg Exchange Impl ori", "Msg Confirm ori" = "Mfg Exchange Impl ori";
    }
}
