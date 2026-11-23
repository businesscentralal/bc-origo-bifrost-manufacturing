namespace Origo.Bifrost.Manufacturing;

using Origo.Bifrost;

/// <summary>Registers whole-entry production posting corrections.</summary>
enumextension 10077107 "Mfg Reverse MsgType ori" extends "Message Type ori"
{
    /// <summary>Reverse whole posted output entries.</summary>
    value(10077108; "Manufacturing.Output.Reverse")
    {
        Caption = 'Manufacturing.Output.Reverse', Locked = true;
        Implementation = "Msg Interface ori" = "Mfg Output Reverse ori", "Msg Discovery ori" = "Mfg Output Reverse ori", "Msg Contract ori" = "Mfg Output Reverse ori", "Msg Confirm ori" = "Mfg Output Reverse ori";
    }
    /// <summary>Reverse whole posted consumption entries.</summary>
    value(10077109; "Manufacturing.Consumption.Reverse")
    {
        Caption = 'Manufacturing.Consumption.Reverse', Locked = true;
        Implementation = "Msg Interface ori" = "Mfg Consumption Reverse ori", "Msg Discovery ori" = "Mfg Consumption Reverse ori", "Msg Contract ori" = "Mfg Consumption Reverse ori", "Msg Confirm ori" = "Mfg Consumption Reverse ori";
    }
}
