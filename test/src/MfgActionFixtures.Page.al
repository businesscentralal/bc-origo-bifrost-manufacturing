namespace Origo.Bifrost.Manufacturing.Test;

using Origo.Bifrost;

/// <summary>Explicit setup, public-message execution and cleanup for owned production MCP/Web Client verification.</summary>
page 97617 "Mfg Action Fixtures ori"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    Caption = 'Production action test fixtures', Comment = 'is-IS=Prófunargögn framleiðsluaðgerða';

    layout
    {
        area(Content)
        {
            group(OwnedFixtures)
            {
                Caption = 'Owned test data', Comment = 'is-IS=Eigin prófunargögn';
                field(FixtureNo; FixtureNo)
                {
                    ApplicationArea = All;
                    Caption = 'Fixture number', Comment = 'is-IS=Prófunarnúmer';
                    ToolTip = 'Specifies the XM11 prefix used only for owned production test records.', Comment = 'is-IS=Tilgreinir XM11 forskeytið sem er aðeins notað fyrir eigin framleiðsluprófunarfærslur.';
                }
                field(Result; ResultText)
                {
                    ApplicationArea = All;
                    Caption = 'Result', Comment = 'is-IS=Niðurstaða';
                    ToolTip = 'Shows the actual message response or verified fixture cleanup result.', Comment = 'is-IS=Sýnir raunverulegt svar skilaboðanna eða staðfesta niðurstöðu hreinsunar prófunargagna.';
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
                ApplicationArea = All;
                Caption = 'Seed production fixture', Comment = 'is-IS=Búa til framleiðsluprófunargögn';
                ToolTip = 'Creates new owned item, production order, posting setup and journal batch. Existing keys are refused.', Comment = 'is-IS=Býr til nýja eigin vöru, framleiðslupöntun, bókunaruppsetningu og færslubókarlotu. Fyrirliggjandi lyklar eru ekki leyfðir.';
                Image = New;
                trigger OnAction()
                begin
                    Fixtures.Seed(FixtureNo);
                    ResultText := SeededMsg;
                end;
            }
            action(Refresh)
            {
                ApplicationArea = All;
                Caption = 'Refresh production order', Comment = 'is-IS=Endurlesa framleiðslupöntun';
                ToolTip = 'Runs the public refresh message against the owned order and displays its response.', Comment = 'is-IS=Keyrir opinber endurlestrarskilaboð á eigin pöntun og sýnir svarið.';
                Image = Refresh;
                trigger OnAction()
                begin
                    RunRefresh();
                end;
            }
            action(OutputLine)
            {
                ApplicationArea = All;
                Caption = 'Create output line', Comment = 'is-IS=Búa til afkastalínu';
                ToolTip = 'Creates an output journal line for two units of the owned item.', Comment = 'is-IS=Býr til afkastafærslubókarlínu fyrir tvær einingar af eigin vöru.';
                Image = New;
                trigger OnAction()
                begin
                    Fixtures.CreateOutputLine(FixtureNo);
                    ResultText := OutputCreatedMsg;
                end;
            }
            action(Post)
            {
                ApplicationArea = All;
                Caption = 'Post owned output', Comment = 'is-IS=Bóka eigin afköst';
                ToolTip = 'Runs the public posting message for the owned batch and displays its response.', Comment = 'is-IS=Keyrir opinber bókunarskilaboð fyrir eigin lotu og sýnir svarið.';
                Image = Post;
                trigger OnAction()
                begin
                    RunPost();
                end;
            }
            action(Cleanup)
            {
                ApplicationArea = All;
                Caption = 'Clean production fixture', Comment = 'is-IS=Hreinsa framleiðsluprófunargögn';
                ToolTip = 'Removes owned production, item, journal, ledger and posting setup records and verifies cleanup.', Comment = 'is-IS=Fjarlægir eigin framleiðslu-, vöru-, færslubókar-, höfuðbókar- og bókunaruppsetningarfærslur og staðfestir hreinsun.';
                Image = Delete;
                trigger OnAction()
                begin
                    Fixtures.Cleanup(FixtureNo);
                    ResultText := CleanedMsg;
                end;
            }
        }
    }

    var
        Fixtures: Codeunit "Mfg Posting Fixture ori";
        Lib: Codeunit "BOM Routing Test Lib ori";
        FixtureNo: Code[20];
        ResultText: Text;
        SeededMsg: Label 'Fresh owned production fixture created.', Comment = 'is-IS=Ný eigin framleiðsluprófunargögn voru búin til.';
        OutputCreatedMsg: Label 'Owned output journal line created.', Comment = 'is-IS=Eigin afkastafærslubókarlína var búin til.';
        CleanedMsg: Label 'Owned production and ledger cleanup verified.', Comment = 'is-IS=Hreinsun eigin framleiðslu- og höfuðbókargagna staðfest.';

    trigger OnOpenPage()
    begin
        FixtureNo := 'XM11MCP';
    end;

    local procedure RunRefresh()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        Request.Add('productionOrderNo', FixtureNo);
        Response := Lib.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Refresh", Request, false);
        Response.WriteTo(ResultText);
    end;

    local procedure RunPost()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        Request.Add('journalTemplateName', CopyStr(FixtureNo, 1, 10));
        Request.Add('journalBatchName', CopyStr(FixtureNo, 1, 10));
        Response := Lib.Invoke("Message Type ori"::"Manufacturing.Journal.Post", Request, false);
        Response.WriteTo(ResultText);
    end;
}
