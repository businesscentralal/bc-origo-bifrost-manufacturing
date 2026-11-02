namespace Origo.Bifrost.Manufacturing;

using Origo.Bifrost;

/// <summary>
/// Registers the manufacturing message types on Bifrost Foundation's message type enum.
/// </summary>
enumextension 10077039 "Mfg Msg Type ori" extends "Message Type ori"
{
    /// <summary>Refreshes the component and routing lines of one production order.</summary>
    value(10077040; "Manufacturing.ProductionOrder.Refresh")
    {
        Caption = 'Manufacturing.ProductionOrder.Refresh', Locked = true;
        Implementation = "Msg Interface ori" = "Mfg Refresh Order Impl ori", "Msg Discovery ori" = "Mfg Refresh Order Impl ori", "Msg Contract ori" = "Mfg Refresh Order Impl ori";
    }

    /// <summary>Replans component and routing demand for one production order.</summary>
    value(10077041; "Manufacturing.ProductionOrder.Replan")
    {
        Caption = 'Manufacturing.ProductionOrder.Replan', Locked = true;
        Implementation = "Msg Interface ori" = "Mfg Refresh Order Impl ori", "Msg Discovery ori" = "Mfg Refresh Order Impl ori", "Msg Contract ori" = "Mfg Refresh Order Impl ori";
    }

    /// <summary>Changes one production order to Firm Planned, Released, or Finished.</summary>
    value(10077042; "Manufacturing.ProductionOrder.ChangeStatus")
    {
        Caption = 'Manufacturing.ProductionOrder.ChangeStatus', Locked = true;
        Implementation = "Msg Interface ori" = "Mfg Refresh Order Impl ori", "Msg Discovery ori" = "Mfg Refresh Order Impl ori", "Msg Contract ori" = "Mfg Refresh Order Impl ori";
    }

    /// <summary>Recalculates unit costs on one production order.</summary>
    value(10077043; "Manufacturing.ProductionOrder.UpdateCost")
    {
        Caption = 'Manufacturing.ProductionOrder.UpdateCost', Locked = true;
        Implementation = "Msg Interface ori" = "Mfg Refresh Order Impl ori", "Msg Discovery ori" = "Mfg Refresh Order Impl ori", "Msg Contract ori" = "Mfg Refresh Order Impl ori";
    }

    /// <summary>Calculates consumption lines for one journal batch.</summary>
    value(10077044; "Manufacturing.Journal.CalculateConsumption")
    {
        Caption = 'Manufacturing.Journal.CalculateConsumption', Locked = true;
        Implementation = "Msg Interface ori" = "Mfg Calc Consumption Impl ori", "Msg Discovery ori" = "Mfg Calc Consumption Impl ori", "Msg Contract ori" = "Mfg Calc Consumption Impl ori";
    }

    /// <summary>Posts one production journal batch.</summary>
    value(10077045; "Manufacturing.Journal.Post")
    {
        Caption = 'Manufacturing.Journal.Post', Locked = true;
        Implementation = "Msg Interface ori" = "Mfg Calc Consumption Impl ori", "Msg Discovery ori" = "Mfg Calc Consumption Impl ori", "Msg Contract ori" = "Mfg Calc Consumption Impl ori";
    }

    /// <summary>Explodes a production order routing into output journal lines.</summary>
    value(10077046; "Manufacturing.Journal.ExplodeRouting")
    {
        Caption = 'Manufacturing.Journal.ExplodeRouting', Locked = true;
        Implementation = "Msg Interface ori" = "Mfg Calc Consumption Impl ori", "Msg Discovery ori" = "Mfg Calc Consumption Impl ori", "Msg Contract ori" = "Mfg Calc Consumption Impl ori";
    }

    /// <summary>Reverses one posted production item or capacity ledger entry.</summary>
    value(10077047; "Manufacturing.Journal.ReversePosting")
    {
        Caption = 'Manufacturing.Journal.ReversePosting', Locked = true;
        Implementation = "Msg Interface ori" = "Mfg Journal Reverse Impl ori", "Msg Discovery ori" = "Mfg Journal Reverse Impl ori", "Msg Contract ori" = "Mfg Journal Reverse Impl ori";
    }

    /// <summary>Creates warehouse picks for a released production order.</summary>
    value(10077057; "Manufacturing.Warehouse.CreatePick")
    {
        Caption = 'Manufacturing.Warehouse.CreatePick', Locked = true;
        Implementation = "Msg Interface ori" = "Mfg Warehouse Impl ori", "Msg Discovery ori" = "Mfg Warehouse Impl ori", "Msg Contract ori" = "Mfg Warehouse Impl ori";
    }

    /// <summary>Creates warehouse put-aways for a released production order's output lines.</summary>
    value(10077058; "Manufacturing.Warehouse.CreatePutAway")
    {
        Caption = 'Manufacturing.Warehouse.CreatePutAway', Locked = true;
        Implementation = "Msg Interface ori" = "Mfg Warehouse Impl ori", "Msg Discovery ori" = "Mfg Warehouse Impl ori", "Msg Contract ori" = "Mfg Warehouse Impl ori";
    }

}