namespace Origo.Bifrost.Manufacturing.Test;

/// <summary>Explicit fixture setup and verified cleanup for owned MCP and Web Client verification.</summary>
page 97667 "BOM Routing Fixtures ori"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    Caption = 'Manufacturing test fixtures', Comment = 'is-IS=Prófunargögn framleiðslu';

    layout
    {
        area(Content)
        {
            group(Fixtures)
            {
                Caption = 'Owned test data', Comment = 'is-IS=Eigin prófunargögn';
                field(Result; ResultText)
                {
                    Caption = 'Result', Comment = 'is-IS=Niðurstaða';
                    ToolTip = 'Shows the result of explicit fixture setup or cleanup.', Comment = 'is-IS=Sýnir niðurstöðu uppsetningar eða hreinsunar prófunargagna.';
                    Editable = false;
                    MultiLine = true;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Seed)
            {
                Caption = 'Seed owned fixtures', Comment = 'is-IS=Búa til eigin prófunargögn';
                ToolTip = 'Creates new XMFG8MCP records. Existing keys are refused.', Comment = 'is-IS=Býr til nýjar XMFG8MCP færslur. Fyrirliggjandi lyklar eru ekki leyfðir.';
                Image = New;

                trigger OnAction()
                begin
                    FixtureLibrary.SeedVerificationData();
                    ResultText := SeededMsg;
                end;
            }
            action(Cleanup)
            {
                Caption = 'Clean and verify', Comment = 'is-IS=Hreinsa og staðfesta';
                ToolTip = 'Removes only XMFG8 test fixtures and asserts that no fixture records remain.', Comment = 'is-IS=Fjarlægir aðeins XMFG8 prófunargögn og staðfestir að engar prófunarfærslur séu eftir.';
                Image = Delete;

                trigger OnAction()
                begin
                    FixtureLibrary.SweepAndAssert();
                    ResultText := CleanedMsg;
                end;
            }
        }
    }

    var
        FixtureLibrary: Codeunit "BOM Routing Test Lib ori";
        ResultText: Text;
        SeededMsg: Label 'Fresh XMFG8MCP fixtures created. No existing keys were overwritten.', Comment = 'is-IS=Ný XMFG8MCP prófunargögn voru búin til. Engir fyrirliggjandi lyklar voru yfirskrifaðir.';
        CleanedMsg: Label 'Cleanup verified: zero owned records remain in all twelve fixture tables.', Comment = 'is-IS=Hreinsun staðfest: engar eigin færslur eru eftir í prófunartöflunum tólf.';
}
