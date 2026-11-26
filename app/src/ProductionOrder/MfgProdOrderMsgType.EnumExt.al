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
    /// <summary>Create production orders from sales order demand.</summary>
    value(10077082; "Manufacturing.ProductionOrder.CreateFromDemand")
    {
        Caption = 'Manufacturing.ProductionOrder.CreateFromDemand', Locked = true;
        Implementation = "Msg Interface ori" = "Prod Order Demand Impl ori", "Msg Discovery ori" = "Prod Order Demand Impl ori", "Msg Contract ori" = "Prod Order Demand Impl ori", "Msg Confirm ori" = "Prod Order Demand Plan ori";
    }
    /// <summary>Replan one firm planned or released production order at no levels.</summary>
    value(10077113; "Manufacturing.ProductionOrder.Replan")
    {
        Caption = 'Manufacturing.ProductionOrder.Replan', Locked = true;
        Implementation = "Msg Interface ori" = "Prod Order Replan Impl ori", "Msg Discovery ori" = "Prod Order Replan Impl ori", "Msg Contract ori" = "Prod Order Replan Impl ori";
    }
    /// <summary>Move the dates of one firm planned or released production order or line.</summary>
    value(10077115; "Manufacturing.ProductionOrder.Reschedule")
    {
        Caption = 'Manufacturing.ProductionOrder.Reschedule', Locked = true;
        Implementation = "Msg Interface ori" = "Prod Order Reschedule Impl ori", "Msg Discovery ori" = "Prod Order Reschedule Impl ori", "Msg Contract ori" = "Prod Order Reschedule Impl ori";
    }
}
