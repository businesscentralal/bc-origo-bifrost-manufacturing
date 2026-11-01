namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Inventory.Item;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Checks public contract completeness, stable names and bilingual refusals.</summary>
codeunit 97606 "Mfg ProdOrder Contract Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Data: Codeunit "Mfg Test Data ori";

    [Test]
    procedure Scenario_AC14_BothContracts_HaveAllChaptersAndWriteEffect()
    var
        Types: List of [Enum "Message Type ori"];
        MessageType: Enum "Message Type ori";
        Chapters: List of [Text];
        Chapter: Text;
        Request: JsonObject;
        Names: JsonArray;
        Response: JsonObject;
        Contract: JsonObject;
        Token: JsonToken;
        Serialized: Text;
    begin
        // Story #5 AC14: invoke Help through the same public dispatcher as callers.
        Types.Add("Message Type ori"::"Manufacturing.ProductionOrder.Create");
        Types.Add("Message Type ori"::"Manufacturing.ProductionOrder.Refresh");
        Chapters := 'envelope|target|parameters|response|errors|effect|related|workflow|examples|overview|notes'.Split('|');
        foreach MessageType in Types do begin
            Clear(Request);
            Clear(Names);
            Names.Add(MessageType.Names().Get(MessageType.Ordinals().IndexOf(MessageType.AsInteger())));
            Request.Add('messageTypes', Names);
            Response := Data.Invoke("Message Type ori"::"Help.Implementation.Get", Request, 1033, true);
            Response.WriteTo(Serialized);
            Assert.IsTrue(Serialized.Contains('Retryable'), 'Foundation augments write errors with Retryable.');
            Response.Get('result', Token);
            Token.AsArray().Get(0, Token);
            Contract := Token.AsObject();
            foreach Chapter in Chapters do
                Assert.IsTrue(Contract.Contains(Chapter), 'Missing contract chapter: ' + Chapter);
            Contract.Get('effect', Token);
            Assert.AreEqual('write', Data.TextValue(Token.AsObject(), 'effect'), 'No posting effect.');
        end;
    end;

    [Test]
    procedure Scenario_AC16_Catalogue_BothLanguages()
    var
        Discovery: Interface "Msg Discovery ori";
        MessageType: Enum "Message Type ori";
        English: Text;
        Icelandic: Text;
        PriorLanguage: Integer;
    begin
        // Story #5 AC16: discovery is the catalogue interface; no customer data involved.
        PriorLanguage := GlobalLanguage();
        MessageType := "Message Type ori"::"Manufacturing.ProductionOrder.Create";
        Discovery := MessageType;
        GlobalLanguage(1033);
        English := Discovery.GetKeywords();
        GlobalLanguage(1039);
        Icelandic := Discovery.GetKeywords();
        GlobalLanguage(PriorLanguage);
        Assert.AreNotEqual(English, Icelandic, 'Keywords must be localized.');
        Assert.IsTrue(Icelandic.Split(',').Count() >= English.Split(',').Count(), 'Icelandic keyword count.');
    end;

    [Test]
    procedure Scenario_AC17_ReleasedRefusal_Bilingual()
    var
        Item: Record Item;
        Request: JsonObject;
        English: JsonObject;
        Icelandic: JsonObject;
    begin
        // Story #5 AC17: session language selects message and nextStep, not contract chapters.
        Data.SetupNumbering(false);
        Data.CreateItem(Item);
        Request := Data.CreateRequest(Item."No.");
        Request.Add('status', 'Released');
        Commit();
        English := Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Create", Request, 1033, false);
        Icelandic := Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Create", Request, 1039, false);
        Data.AssertRefusal(English, 'InvalidParameter');
        Data.AssertRefusal(Icelandic, 'InvalidParameter');
        Assert.IsTrue(Data.TextValue(English, 'error').StartsWith('Production orders'), 'English refusal.');
        Assert.IsTrue(Data.TextValue(Icelandic, 'error').StartsWith('Framleiðslupantanir'), 'Icelandic refusal.');
        Assert.IsTrue(Data.TextValue(Icelandic, 'nextStep').StartsWith('Notaðu'), 'Icelandic guidance.');
    end;
}
