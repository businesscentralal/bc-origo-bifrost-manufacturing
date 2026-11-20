namespace Origo.Bifrost.Manufacturing;

using Origo.Bifrost;

/// <summary>Order-level availability and costing reads.</summary>
enumextension 10077064 "Mfg Order Read MsgType ori" extends "Message Type ori"
{
    value(10077048; "Manufacturing.ComponentAvailability.Get")
    {
        Caption = 'Manufacturing.ComponentAvailability.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Mfg Component Get Impl ori", "Msg Discovery ori" = "Mfg Component Get Impl ori", "Msg Contract ori" = "Mfg Component Get Impl ori";
    }
    value(10077049; "Manufacturing.ProductionOrderStatistics.Get")
    {
        Caption = 'Manufacturing.ProductionOrderStatistics.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Mfg Statistics Get Impl ori", "Msg Discovery ori" = "Mfg Statistics Get Impl ori", "Msg Contract ori" = "Mfg Statistics Get Impl ori";
    }
}
