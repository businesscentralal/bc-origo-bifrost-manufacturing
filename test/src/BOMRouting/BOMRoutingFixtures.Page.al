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
            action(SeedProductionOrder)
            {
                Caption = 'Seed production order fixtures', Comment = 'is-IS=Búa til prófunargögn framleiðslupantana';
                ToolTip = 'Creates an owned manufactured item, certified BOM, routing, calendar and number series. Existing fixture keys are refused.', Comment = 'is-IS=Býr til eigin framleiðsluvöru, staðfesta uppskrift, leið, dagatal og númeraröð. Fyrirliggjandi prófunarlyklar eru ekki leyfðir.';
                Image = New;
                trigger OnAction()
                var
                    Fixture: Codeunit "Mfg MCP Fixture Tst ori";
                begin
                    Fixture.Run();
                end;
            }
            action(SeedAmend)
            {
                Caption = 'Seed Finish and Post amendment fixtures', Comment = 'is-IS=Búa til prófunargögn fyrir lokun og bókun';
                ToolTip = 'Creates an owned item without routing and an owned item whose routing operation and backward component share a routing link (matched shape; the unmatched case is made afterwards on the released order). Existing fixture keys are refused.', Comment = 'is-IS=Býr til eigin vöru án leiðar og eigin vöru þar sem aðgerð í leið og hráefni deila tengikóða (samsvarandi form; ósamsvörun er útbúin síðar á útgefinni pöntun). Fyrirliggjandi prófunarlyklar eru ekki leyfðir.';
                Image = New;
                trigger OnAction()
                var
                    AmendFixture: Codeunit "Mfg MCP Amend Fixture Tst ori";
                begin
                    AmendFixture.Seed();
                    ResultText := AmendSeededMsg;
                end;
            }
            action(CleanupAmend)
            {
                Caption = 'Clean Finish and Post amendment fixtures', Comment = 'is-IS=Hreinsa prófunargögn fyrir lokun og bókun';
                ToolTip = 'Removes only the owned amendment fixture items with their orders, BOMs, routings and routing link, and asserts that none remain.', Comment = 'is-IS=Fjarlægir aðeins eigin vörur með pöntunum, uppskriftum, leiðum og tengikóða og staðfestir að ekkert sé eftir.';
                Image = Delete;
                trigger OnAction()
                var
                    AmendFixture: Codeunit "Mfg MCP Amend Fixture Tst ori";
                begin
                    AmendFixture.Cleanup();
                    ResultText := AmendCleanedMsg;
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
        AmendSeededMsg: Label 'Amendment fixtures X-M6-MCP-NR and X-M6-MCP-LK created.', Comment = 'is-IS=Prófunargögn X-M6-MCP-NR og X-M6-MCP-LK voru búin til.';
        AmendCleanedMsg: Label 'Amendment fixtures removed and verified.', Comment = 'is-IS=Prófunargögn fjarlægð og staðfest.';
        CleanedMsg: Label 'Cleanup verified: zero owned records remain in all twelve fixture tables.', Comment = 'is-IS=Hreinsun staðfest: engar eigin færslur eru eftir í prófunartöflunum tólf.';
}
