namespace Origo.Bifrost.Manufacturing;

using Origo.Bifrost;

/// <summary>Registers production planning operations.</summary>
enumextension 10077039 "Mfg ProdOrder MsgType ori" extends "Message Type ori"
{
    /// <summary>Create a production planning order.</summary>
    value(10077041; "Manufacturing.ProductionOrder.Create")
    {
        Caption = 'Manufacturing.ProductionOrder.Create', Locked = true;
        Implementation = "Msg Interface ori" = "Prod Order Create Impl ori", "Msg Discovery ori" = "Prod Order Create Impl ori", "Msg Contract ori" = "Prod Order Create Impl ori";
    }
    /// <summary>Refresh a production planning order.</summary>
    value(10077042; "Manufacturing.ProductionOrder.Refresh")
    {
        Caption = 'Manufacturing.ProductionOrder.Refresh', Locked = true;
        Implementation = "Msg Interface ori" = "Prod Order Refresh Impl ori", "Msg Discovery ori" = "Prod Order Refresh Impl ori", "Msg Contract ori" = "Prod Order Refresh Impl ori";
    }
}
