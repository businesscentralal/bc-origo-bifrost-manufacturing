namespace Origo.Bifrost.Manufacturing;

using Origo.Bifrost;

/// <summary>Registers the production order status change, finish and finish check operations.</summary>
enumextension 10077052 "Mfg Status MsgType ori" extends "Message Type ori"
{
    /// <summary>Change a production order to Firm Planned or Released.</summary>
    value(10077055; "Manufacturing.ProductionOrder.ChangeStatus")
    {
        Caption = 'Manufacturing.ProductionOrder.ChangeStatus', Locked = true;
        Implementation = "Msg Interface ori" = "Prod Order Status Impl ori", "Msg Discovery ori" = "Prod Order Status Impl ori", "Msg Contract ori" = "Prod Order Status Impl ori", "Msg Confirm ori" = "Prod Order Confirm ori";
    }
    /// <summary>Finish a released production order.</summary>
    value(10077057; "Manufacturing.ProductionOrder.Finish")
    {
        Caption = 'Manufacturing.ProductionOrder.Finish', Locked = true;
        Implementation = "Msg Interface ori" = "Prod Order Finish Impl ori", "Msg Discovery ori" = "Prod Order Finish Impl ori", "Msg Contract ori" = "Prod Order Finish Impl ori", "Msg Confirm ori" = "Prod Order Confirm ori";
    }
    /// <summary>Show what would block or warn when a released production order is finished.</summary>
    value(10077059; "Manufacturing.ProductionOrder.CheckFinish")
    {
        Caption = 'Manufacturing.ProductionOrder.CheckFinish', Locked = true;
        Implementation = "Msg Interface ori" = "Prod Ord Fin Check Impl ori", "Msg Discovery ori" = "Prod Ord Fin Check Impl ori", "Msg Contract ori" = "Prod Ord Fin Check Impl ori";
    }
}
