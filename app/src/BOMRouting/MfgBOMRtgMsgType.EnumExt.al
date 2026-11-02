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
}
