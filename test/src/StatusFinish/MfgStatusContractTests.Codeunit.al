namespace Origo.Bifrost.Manufacturing.Test;

using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Story #6 AC16: contract chapters and effects of the three types.</summary>
codeunit 97626 "Mfg Status Contract Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Scenario_AC16_Effects_AndErrors()
    begin
        AssertContract("Message Type ori"::"Manufacturing.ProductionOrder.ChangeStatus", 'irreversible', true);
        AssertContract("Message Type ori"::"Manufacturing.ProductionOrder.Finish", 'irreversible', true);
        AssertContract("Message Type ori"::"Manufacturing.ProductionOrder.CheckFinish", 'read', false);
        AssertContract("Message Type ori"::"Manufacturing.ProductionOrder.Reopen", 'write', false);
    end;

    [Test]
    procedure Scenario_AC15_CatalogueTexts_MatchSessionLanguage()
    var
        Discovery: Interface "Msg Interface ori";
        ChangeStatusDescription: Text;
        FinishDescription: Text;
        CheckFinishDescription: Text;
    begin
        ChangeStatusDescription := 'Changes the status of a production order to Firm Planned or Released with the standard Business Central status change. Commits.';
        FinishDescription := 'Finishes a released production order: posts backward-flushed consumption, adjusts work in process and moves the order to Finished. Commits and cannot be undone.';
        CheckFinishDescription := 'Shows what would block or warn when a released production order is finished. Changes nothing.';
        if GlobalLanguage() = 1039 then begin
            ChangeStatusDescription := 'Breytir stöðu framleiðslupöntunar í fastákveðna eða útgefna með venjulegri stöðubreytingu Business Central. Framkvæmir Commit.';
            FinishDescription := 'Lýkur útgefinni framleiðslupöntun: bókar afturvirka notkun, jafnar vinnu í vinnslu og færir pöntunina í stöðuna lokið. Framkvæmir Commit og ekki er hægt að afturkalla.';
            CheckFinishDescription := 'Sýnir hvað myndi hindra eða vara við þegar útgefinni framleiðslupöntun er lokið. Breytir engu.';
        end;
        Discovery := "Message Type ori"::"Manufacturing.ProductionOrder.ChangeStatus";
        Assert.AreEqual(ChangeStatusDescription, Discovery.GetDescription(), 'ChangeStatus catalogue text.');
        Discovery := "Message Type ori"::"Manufacturing.ProductionOrder.Finish";
        Assert.AreEqual(FinishDescription, Discovery.GetDescription(), 'Finish catalogue text.');
        Discovery := "Message Type ori"::"Manufacturing.ProductionOrder.CheckFinish";
        Assert.AreEqual(CheckFinishDescription, Discovery.GetDescription(), 'CheckFinish catalogue text.');
    end;

    [Test]
    procedure Issue37_AC01_OnlyPostingTypesAreIrreversible()
    var
        MessageType: Enum "Message Type ori";
        Contract: Interface "Msg Contract ori";
        Effect: JsonObject;
        EffectToken: JsonToken;
        Ordinal: Integer;
        PostingCount: Integer;
        TypeCount: Integer;
        Posting: Boolean;
    begin
        // Story #37 + #6: enumerate every type registered in this app's ID range.
        foreach Ordinal in MessageType.Ordinals() do
            if (Ordinal >= 10077035) and (Ordinal <= 10077134) then begin
                MessageType := Enum::"Message Type ori".FromInteger(Ordinal);
                Contract := MessageType;
                Clear(Effect);
                Assert.IsTrue(Contract.GetEffect(Effect), 'Every manufacturing type declares its effect.');
                Assert.IsTrue(Effect.Get('effect', EffectToken), 'Effect classification is required.');
                Posting := MessageType in [MessageType::"Manufacturing.ProductionJournal.Post",
                    MessageType::"Manufacturing.ProductionOrder.Finish", MessageType::"Manufacturing.ProductionOrder.ChangeStatus"];
                Assert.AreEqual(Posting, EffectToken.AsValue().AsText() = 'irreversible',
                    MessageType.Names().Get(MessageType.Ordinals().IndexOf(Ordinal)));
                if Posting then
                    PostingCount += 1;
                TypeCount += 1;
            end;
        Assert.AreEqual(3, PostingCount, 'All three posting types were checked.');
        Assert.IsTrue(TypeCount > PostingCount, 'Non-posting types were also checked.');
    end;

    [Test]
    procedure Issue37_AC03_ReopenSelectionIsBilingualWrite()
    var
        Discovery: Interface "Msg Discovery ori";
        PreviousLanguage: Integer;
        English: Text;
        Icelandic: Text;
    begin
        // Story #37 + #22: localized catalogue help must describe a write.
        Discovery := "Message Type ori"::"Manufacturing.ProductionOrder.Reopen";
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(1033);
        English := Discovery.GetSelectionDescription();
        GlobalLanguage(1039);
        Icelandic := Discovery.GetSelectionDescription();
        GlobalLanguage(PreviousLanguage);
        Assert.AreEqual('Reopen a finished production order once. Writes.', English, 'English write help.');
        Assert.AreEqual('Opnaðu lokna framleiðslupöntun aftur einu sinni. Skrifar.', Icelandic, 'Icelandic write help.');
    end;

    local procedure AssertContract(MessageType: Enum "Message Type ori"; ExpectedEffect: Text; Writing: Boolean)
    var
        Contract: Interface "Msg Contract ori";
        Envelope: JsonObject;
        Effect: JsonObject;
        Response: JsonObject;
        Workflow: JsonObject;
        Target: JsonArray;
        Parameters: JsonArray;
        Errors: JsonArray;
        Related: JsonArray;
        Examples: JsonArray;
        Overview: Text;
        Notes: Text;
        ErrorsText: Text;
        EffectText: Text;
        Token: JsonToken;
    begin
        Contract := MessageType;
        Assert.IsTrue(Contract.GetEnvelope(Envelope), 'envelope');
        Assert.IsTrue(Contract.GetTarget(Target), 'target');
        Assert.IsTrue(Contract.GetParameters(Parameters), 'parameters');
        Assert.IsTrue(Contract.GetResponse(Response), 'response');
        Assert.IsTrue(Contract.GetErrors(Errors), 'errors');
        Assert.IsTrue(Contract.GetEffect(Effect), 'effect');
        Assert.IsTrue(Contract.GetRelated(Related), 'related');
        Assert.IsTrue(Contract.GetWorkflow(Workflow), 'workflow');
        Assert.IsTrue(Contract.GetExamples(Examples), 'examples');
        Assert.IsTrue(Contract.GetOverview(Overview), 'overview');
        Assert.IsTrue(Contract.GetNotes(Notes), 'notes');
        Effect.Get('effect', Token);
        Assert.AreEqual(ExpectedEffect, Token.AsValue().AsText(), 'effect');
        Errors.WriteTo(ErrorsText);
        Effect.WriteTo(EffectText);
        if Writing then begin
            Assert.IsTrue(EffectText.Contains('commits'), 'The effect text says the call commits.');
            Assert.IsTrue(ErrorsText.Contains('ConfirmationRequired'), 'ConfirmationRequired');
            Assert.IsTrue(ErrorsText.Contains('ConfirmationMismatch'), 'ConfirmationMismatch');
            Assert.IsTrue(ErrorsText.Contains('PermissionDenied'), 'PermissionDenied');
        end;
        if MessageType = "Message Type ori"::"Manufacturing.ProductionOrder.Finish" then
            Assert.IsTrue(ErrorsText.Contains('PreconditionFailed'), 'PreconditionFailed');
    end;
}
