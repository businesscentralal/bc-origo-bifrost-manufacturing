namespace Origo.Bifrost.Manufacturing.Test;

using Origo.Bifrost.Manufacturing;
using System.TestLibraries.Utilities;

/// <summary>Story #7 AC16: the three types describe themselves completely.</summary>
codeunit 97645 "Prod Jnl Contract Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Scenario_AC16_Contracts_Are_Complete()
    var
        GetImpl: Codeunit "Prod Jnl Get Impl ori";
        PreviewImpl: Codeunit "Prod Jnl Preview Impl ori";
        PostImpl: Codeunit "Prod Jnl Post Impl ori";
        Effect: JsonObject;
        Parameters: JsonArray;
        Workflow: JsonObject;
        Notes: Text;
        Json: Text;
    begin
        GetImpl.GetEffect(Effect);
        Effect.WriteTo(Json);
        Assert.IsTrue(Json.Contains('"effect":"read"'), 'Get is read.');
        Clear(Effect);
        PreviewImpl.GetEffect(Effect);
        Effect.WriteTo(Json);
        Assert.IsTrue(Json.Contains('"effect":"read"'), 'PreviewPost is read.');
        Clear(Effect);
        PostImpl.GetEffect(Effect);
        Effect.WriteTo(Json);
        Assert.IsTrue(Json.Contains('"effect":"irreversible"'), 'Post is irreversible.');
        Assert.IsTrue(Json.Contains('commits'), 'Post says it commits.');
        PostImpl.GetNotes(Notes);
        Assert.IsTrue(Notes.Contains('Item Journal Line'), 'The generic-write decision is documented in the Post notes.');
        GetImpl.GetWorkflow(Workflow);
        Workflow.WriteTo(Json);
        Assert.IsTrue(Json.Contains('ChangeStatus') and Json.Contains('Manufacturing.ProductionJournal.Post') and Json.Contains('Finish'), 'The workflow names ChangeStatus, Post and Finish.');
        PostImpl.GetParameters(Parameters);
        Assert.IsTrue(Parameters.Count() > 0, 'Post declares parameters.');
    end;
}
