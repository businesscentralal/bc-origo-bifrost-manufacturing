namespace Origo.Bifrost.Manufacturing;

using Origo.Bifrost;

/// <summary>Registers the production journal read, preview and post operations.</summary>
enumextension 10077070 "Mfg ProdJnl MsgType ori" extends "Message Type ori"
{
    /// <summary>Read what the production journal of a released order proposes.</summary>
    value(10077072; "Manufacturing.ProductionJournal.Get")
    {
        Caption = 'Manufacturing.ProductionJournal.Get', Locked = true;
        Implementation = "Msg Interface ori" = "Prod Jnl Get Impl ori", "Msg Discovery ori" = "Prod Jnl Get Impl ori", "Msg Contract ori" = "Prod Jnl Get Impl ori";
    }
    /// <summary>Show the entries that posting output and consumption would create.</summary>
    value(10077073; "Manufacturing.ProductionJournal.PreviewPost")
    {
        Caption = 'Manufacturing.ProductionJournal.PreviewPost', Locked = true;
        Implementation = "Msg Interface ori" = "Prod Jnl Preview Impl ori", "Msg Discovery ori" = "Prod Jnl Preview Impl ori", "Msg Contract ori" = "Prod Jnl Preview Impl ori";
    }
    /// <summary>Post output and consumption of a released order.</summary>
    value(10077074; "Manufacturing.ProductionJournal.Post")
    {
        Caption = 'Manufacturing.ProductionJournal.Post', Locked = true;
        Implementation = "Msg Interface ori" = "Prod Jnl Post Impl ori", "Msg Discovery ori" = "Prod Jnl Post Impl ori", "Msg Contract ori" = "Prod Jnl Post Impl ori", "Msg Confirm ori" = "Prod Jnl Confirm ori";
    }
}
