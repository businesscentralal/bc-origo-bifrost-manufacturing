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

    /// <summary>Checks and recalculates a production BOM and its structure.</summary>
    value(10077048; "Manufacturing.ProductionBOM.Check")
    {
        Caption = 'Manufacturing.ProductionBOM.Check', Locked = true;
        Implementation = "Msg Interface ori" = "Mfg Prod BOM Impl ori", "Msg Discovery ori" = "Mfg Prod BOM Impl ori", "Msg Contract ori" = "Mfg Prod BOM Impl ori";
    }

    /// <summary>Copies production BOM lines from a source BOM into a destination BOM or version.</summary>
    value(10077049; "Manufacturing.ProductionBOM.Copy")
    {
        Caption = 'Manufacturing.ProductionBOM.Copy', Locked = true;
        Implementation = "Msg Interface ori" = "Mfg Prod BOM Impl ori", "Msg Discovery ori" = "Mfg Prod BOM Impl ori", "Msg Contract ori" = "Mfg Prod BOM Impl ori";
    }

    /// <summary>Calculates routing sequences and validates one routing or version.</summary>
    value(10077050; "Manufacturing.Routing.Check")
    {
        Caption = 'Manufacturing.Routing.Check', Locked = true;
        Implementation = "Msg Interface ori" = "Mfg Routing Impl ori", "Msg Discovery ori" = "Mfg Routing Impl ori", "Msg Contract ori" = "Mfg Routing Impl ori";
    }

    /// <summary>Copies routing lines and related data into another routing or version.</summary>
    value(10077051; "Manufacturing.Routing.Copy")
    {
        Caption = 'Manufacturing.Routing.Copy', Locked = true;
        Implementation = "Msg Interface ori" = "Mfg Routing Impl ori", "Msg Discovery ori" = "Mfg Routing Impl ori", "Msg Contract ori" = "Mfg Routing Impl ori";
    }

    /// <summary>Recalculates calendar entries for a work center or machine center over a date range.</summary>
    value(10077052; "Manufacturing.Calendar.Recalculate")
    {
        Caption = 'Manufacturing.Calendar.Recalculate', Locked = true;
        Implementation = "Msg Interface ori" = "Mfg Calendar Impl ori", "Msg Discovery ori" = "Mfg Calendar Impl ori", "Msg Contract ori" = "Mfg Calendar Impl ori";
    }

    /// <summary>Applies an existing calendar absence entry to calendar capacity.</summary>
    value(10077053; "Manufacturing.Calendar.UpdateAbsence")
    {
        Caption = 'Manufacturing.Calendar.UpdateAbsence', Locked = true;
        Implementation = "Msg Interface ori" = "Mfg Absence Impl ori", "Msg Discovery ori" = "Mfg Absence Impl ori", "Msg Contract ori" = "Mfg Absence Impl ori";
    }

    /// <summary>Calculates a planning worksheet for a date range.</summary>
    value(10077054; "Manufacturing.Planning.CalculatePlan")
    {
        Caption = 'Manufacturing.Planning.CalculatePlan', Locked = true;
        Implementation = "Msg Interface ori" = "Mfg Plan Calc Impl ori", "Msg Discovery ori" = "Mfg Plan Calc Impl ori", "Msg Contract ori" = "Mfg Plan Calc Impl ori";
    }

    /// <summary>Carries out one production-order proposal from a planning worksheet.</summary>
    value(10077055; "Manufacturing.Planning.CarryOutProduction")
    {
        Caption = 'Manufacturing.Planning.CarryOutProduction', Locked = true;
        Implementation = "Msg Interface ori" = "Mfg Plan Carryout Impl ori", "Msg Discovery ori" = "Mfg Plan Carryout Impl ori", "Msg Contract ori" = "Mfg Plan Carryout Impl ori";
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

    /// <summary>Removes an applied calendar absence from capacity calendar entries.</summary>
    value(10077059; "Manufacturing.Calendar.RemoveAbsence")
    {
        Caption = 'Manufacturing.Calendar.RemoveAbsence', Locked = true;
        Implementation = "Msg Interface ori" = "Mfg Absence Impl ori", "Msg Discovery ori" = "Mfg Absence Impl ori", "Msg Contract ori" = "Mfg Absence Impl ori";
    }

}