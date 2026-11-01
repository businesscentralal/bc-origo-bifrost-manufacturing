namespace Origo.Bifrost.Manufacturing;

using Origo.Bifrost.Foundation;

/// <summary>
/// Registers the Production BOM and Routing SetStatus message types.
/// </summary>
enumextension 10077085 "Mfg BOMRtg MsgType ori" extends "Message Type ori"
{
    value(10077087; "Manufacturing.ProductionBOM.SetStatus")
    {
        Implementation = "Msg Interface ori" = "Prod BOM Status Impl ori",
                         "Msg Discovery ori" = "Prod BOM Status Impl ori",
                         "Msg Contract ori" = "Prod BOM Status Impl ori";
    }
    value(10077089; "Manufacturing.Routing.SetStatus")
    {
        Implementation = "Msg Interface ori" = "Routing Status Impl ori",
                         "Msg Discovery ori" = "Routing Status Impl ori",
                         "Msg Contract ori" = "Routing Status Impl ori";
    }
}
