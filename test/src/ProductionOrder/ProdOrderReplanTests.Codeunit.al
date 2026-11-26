namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Inventory.Item;
using Microsoft.Manufacturing.Document;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Issue 24: Manufacturing.ProductionOrder.Replan acceptance, confirmation and refusals.</summary>
codeunit 97681 "Prod Order Replan Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Lib: Codeunit "Mfg Schedule Test Lib ori";
        Data: Codeunit "Mfg Test Data ori";
        ReopenFixture: Codeunit "Mfg Reopen Fixture ori";
        Assert: Codeunit "Library Assert";
        LowerPermissions: Codeunit "Library - Lower Permissions";

    [Test]
    procedure AC02_ReplanMovesDatesAndConfirmsCount()
    var
        Item: Record Item;
        Order: Record "Production Order";
        Released: Record "Production Order";
        StatusLib: Codeunit "Mfg Status Test Lib ori";
        Response: JsonObject;
        Raw: Text;
        BeforeStart: DateTime;
        MessageId: Guid;
    begin
        // Story #24 AC02 | GIVEN a refreshed firm planned order | WHEN run time changes and replan runs | THEN dates move only after expectedCount 1.
        Lib.CreateRefreshedOrder(Item, Order);
        BeforeStart := Lib.StartingDateTime(Order);
        Lib.StretchRunTime(Order, 2400);
        Assert.AreEqual(BeforeStart, Lib.StartingDateTime(Order), 'Changing run time does not schedule by itself.');

        Response := Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Replan", Lib.ReplanRequest(Order, 'backward', 'noLevels', 0, false), 1033, false, MessageId);
        Data.AssertRefusal(Response, 'ConfirmationRequired');
        Assert.IsTrue(Data.TextValue(Response, 'error').Contains('1'), 'The required count is visible.');
        ReopenFixture.AssertLoggedError(MessageId, 'ConfirmationRequired');
        Assert.AreEqual(BeforeStart, Lib.StartingDateTime(Order), 'A missing count changes nothing.');

        Response := Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Replan", Lib.ReplanRequest(Order, 'backward', 'noLevels', 2, true), 1033, false);
        Data.AssertRefusal(Response, 'ConfirmationMismatch');
        Assert.AreEqual(BeforeStart, Lib.StartingDateTime(Order), 'A wrong count changes nothing.');

        Response := Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Replan", Lib.ReplanRequest(Order, 'backward', 'noLevels', 1, true), 1033, false);
        Response.WriteTo(Raw);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), Raw);
        Assert.AreEqual('noLevels', Data.TextValue(Response, 'calcMethod'), 'Only no levels runs.');
        Assert.AreEqual('backward', Data.TextValue(Response, 'direction'), 'Direction is returned in lower case.');
        Assert.AreNotEqual(BeforeStart, Lib.StartingDateTime(Order), 'Backward replan moves the start after a longer run time.');
        Assert.IsTrue(Lib.ArrayCount(Response, 'lines') > 0, 'Lines are returned.');
        Assert.IsTrue(Lib.ArrayCount(Response, 'routingLines') > 0, 'Routing lines are returned.');
        Assert.IsTrue(Lib.ArrayCount(Response, 'warnings') >= 0, 'Warnings are always present.');
        Order.Get(Order.Status, Order."No.");

        Response := Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Replan", Lib.ReplanRequest(Order, 'backward', '', 1, true), 1039, false);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Icelandic replan succeeds.');

        Response := Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Replan", Lib.ReplanRequest(Order, 'forward', 'noLevels', 1, true), 1033, false);
        Response.WriteTo(Raw);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Forward edge: ' + Raw);
        Assert.AreNotEqual(0DT, Lib.StartingDateTime(Order), 'Forward replan leaves a starting date-time.');

        Response := StatusLib.ChangeStatus(Order, 'Released', 1, 1033);
        Response.WriteTo(Raw);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Release for replan: ' + Raw);
        StatusLib.ReadBack(Response, Released);
        Response := Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Replan", Lib.ReplanRequest(Released, 'backward', 'noLevels', 1, true), 1033, false);
        Response.WriteTo(Raw);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Released replan: ' + Raw);
        Lib.Cleanup(Item."No.");
    end;

    [Test]
    procedure AC03_OneLevelAndAllLevelsDeleteNothing()
    var
        Item: Record Item;
        FirstOrder: Record "Production Order";
        SecondOrder: Record "Production Order";
        Response: JsonObject;
        BeforeCount: Integer;
    begin
        // Story #24 AC03 | GIVEN two firm planned orders | WHEN oneLevel and allLevels are requested | THEN both orders remain.
        Data.CreateItem(Item);
        InsertOrder(FirstOrder, Item."No.", FirstOrder.Status::"Firm Planned");
        InsertOrder(SecondOrder, Item."No.", SecondOrder.Status::"Firm Planned");
        BeforeCount := Lib.CountOrders(Item."No.");
        Commit();
        Response := Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Replan", Lib.ReplanRequest(FirstOrder, 'backward', 'oneLevel', 1, true), 1033, false);
        Data.AssertRefusal(Response, 'PreconditionFailed');
        Assert.IsTrue(Data.TextValue(Response, 'error').Contains('oneLevel') or Data.TextValue(Response, 'error').Contains('OneLevel'), 'The refusal names oneLevel.');
        Response := Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Replan", Lib.ReplanRequest(SecondOrder, 'backward', 'allLevels', 0, false), 1033, false);
        Data.AssertRefusal(Response, 'PreconditionFailed');
        Assert.AreEqual('PreconditionFailed', Data.TextValue(Response, 'code'), 'allLevels is not a confirmation refusal.');
        Assert.AreEqual(BeforeCount, Lib.CountOrders(Item."No."), 'No production order was deleted.');
        Assert.IsTrue(FirstOrder.Get(FirstOrder.Status, FirstOrder."No."), 'The first order remains.');
        Assert.IsTrue(SecondOrder.Get(SecondOrder.Status, SecondOrder."No."), 'The second order remains.');
        Lib.Cleanup(Item."No.");
    end;

    [Test]
    procedure AC04_C1_StatusFormatMissingUnknownAndConflict()
    var
        Item: Record Item;
        Planned: Record "Production Order";
        Finished: Record "Production Order";
        Other: Record "Production Order";
        Firm: Record "Production Order";
        Request: JsonObject;
        Response: JsonObject;
        English: Text;
        Icelandic: Text;
        MessageId: Guid;
    begin
        // Story #24 AC04/C1 | GIVEN bare orders | WHEN status, format or identity is wrong | THEN a structured refusal changes nothing.
        Data.CreateItem(Item);
        InsertOrder(Planned, Item."No.", Planned.Status::Planned);
        InsertOrder(Finished, Item."No.", Finished.Status::Finished);
        InsertOrder(Firm, Item."No.", Firm.Status::"Firm Planned");
        InsertOrder(Other, Item."No.", Other.Status::"Firm Planned");
        Commit();

        Response := Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Replan", Lib.ReplanRequest(Finished, 'backward', 'noLevels', 1, true), 1033, false, MessageId);
        Data.AssertRefusal(Response, 'PreconditionFailed');
        English := Data.TextValue(Response, 'error');
        Assert.IsFalse(LowerCase(English).Contains('message type'), 'The refusal does not say message type.');
        ReopenFixture.AssertLoggedError(MessageId, 'PreconditionFailed');
        Response := Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Replan", Lib.ReplanRequest(Finished, 'backward', 'noLevels', 1, true), 1039, false);
        Icelandic := Data.TextValue(Response, 'error');
        Assert.AreNotEqual(English, Icelandic, 'Finished refusal is translated.');
        Assert.IsTrue(Finished.Get(Finished.Status, Finished."No."), 'Finished order remains.');

        Response := Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Replan", Lib.ReplanRequest(Planned, 'backward', 'noLevels', 1, true), 1033, false);
        Data.AssertRefusal(Response, 'PreconditionFailed');
        Assert.IsTrue(Data.TextValue(Response, 'nextStep').Contains('Manufacturing.ProductionOrder.Refresh'), 'Planned next step names Refresh.');

        Clear(Request);
        Request.Add('systemId', 'not-a-guid');
        Request.Add('expectedCount', 1);
        Data.AssertRefusal(Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Replan", Request, 1033, false), 'InvalidParameterFormat');

        Clear(Request);
        Request.Add('expectedCount', 1);
        Request.Add('calcMethod', 'noLevels');
        Request.Add('direction', 'backward');
        Data.AssertRefusal(Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Replan", Request, 1033, false), 'MissingParameter');

        Request := Lib.ReplanRequest(Firm, 'backward', 'noLevels', 1, true);
        Request.Add('foo', 'bar');
        Data.AssertRefusal(Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Replan", Request, 1033, false), 'UnknownParameter');

        Clear(Request);
        Request.Add('systemId', Format(CreateGuid(), 0, 4));
        Request.Add('expectedCount', 1);
        Data.AssertRefusal(Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Replan", Request, 1033, false), 'RecordNotFound');

        Request := Lib.Identity(Firm);
        Request.Add('no', Other."No.");
        Request.Add('expectedCount', 1);
        Data.AssertRefusal(Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Replan", Request, 1033, false), 'ConflictingIdentifiers');

        Request := Lib.Identity(Firm);
        Request.Add('expectedCount', '1');
        Data.AssertRefusal(Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Replan", Request, 1033, false), 'InvalidParameterFormat');

        Request := Lib.ReplanRequest(Firm, 'backward', 'sideways', 1, true);
        Data.AssertRefusal(Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Replan", Request, 1033, false), 'InvalidParameter');

        Planned.Init();
        Planned.Status := Planned.Status::Planned;
        Planned."No." := Firm."No.";
        Planned."Source Type" := Planned."Source Type"::Item;
        Planned."Source No." := Item."No.";
        Planned.Insert(false);
        Clear(Request);
        Request.Add('no', Firm."No.");
        Request.Add('expectedCount', 1);
        Data.AssertRefusal(Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Replan", Request, 1033, false), 'AmbiguousRecord');
        Lib.Cleanup(Item."No.");
    end;

    [Test]
    procedure C1_PostedOutputAndOmitCommitChangeNothing()
    var
        Item: Record Item;
        Order: Record "Production Order";
        Response: JsonObject;
        BeforeDue: Date;
    begin
        // Story #24 C1 | GIVEN posted output or Omit Commit | WHEN replan is called | THEN nothing changes.
        Data.CreateItem(Item);
        InsertOrder(Order, Item."No.", Order.Status::Released);
        Order."Due Date" := WorkDate();
        Order.Modify(false);
        Lib.InsertOutput(Order."No.", Item."No.");
        BeforeDue := Order."Due Date";
        Commit();
        Response := Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Replan", Lib.ReplanRequest(Order, 'backward', 'noLevels', 1, true), 1033, false);
        Data.AssertRefusal(Response, 'PreconditionFailed');
        Order.Get(Order.Status, Order."No.");
        Assert.AreEqual(BeforeDue, Order."Due Date", 'Posted output does not change the order.');
        Assert.AreEqual(1, Lib.CountOrders(Item."No."), 'The order was not deleted.');

        Response := Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Replan", Lib.ReplanRequest(Order, 'backward', 'noLevels', 1, true), 1033, true);
        Data.AssertRefusal(Response, 'PreconditionFailed');
        Assert.IsTrue(LowerCase(Data.TextValue(Response, 'error')).Contains('omit commit'), 'Omit Commit is named.');
        Lib.Cleanup(Item."No.");
    end;

    [Test]
    procedure AC05_C1_ReadRoleAndNoPermissionRefused()
    begin
        // Story #24 AC05/C1 | GIVEN a read role or no Manufacturing role | WHEN replan is called | THEN permission is denied.
        CheckRefusal('BIFROST Read ori');
        CheckRefusal('BIFROST API ori');
    end;

    [Test]
    procedure C2_ContractChaptersAreEnglishAndBilingual()
    var
        Discovery: Interface "Msg Discovery ori";
        Catalogue: Interface "Msg Interface ori";
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
        ChapterText: Text;
        English: Text;
        Icelandic: Text;
        PriorLanguage: Integer;
    begin
        // Story #24 C2 | GIVEN the public help | WHEN both scheduling operations are described | THEN chapters are complete and catalogue text is bilingual.
        Types.Add("Message Type ori"::"Manufacturing.ProductionOrder.Replan");
        Types.Add("Message Type ori"::"Manufacturing.ProductionOrder.Reschedule");
        Chapters := 'envelope|target|parameters|response|errors|effect|related|workflow|examples|overview|notes'.Split('|');
        foreach MessageType in Types do begin
            Clear(Request);
            Clear(Names);
            Names.Add(MessageType.Names().Get(MessageType.Ordinals().IndexOf(MessageType.AsInteger())));
            Request.Add('messageTypes', Names);
            Response := Data.Invoke("Message Type ori"::"Help.Implementation.Get", Request, 1033, true);
            Response.WriteTo(Serialized);
            Assert.IsTrue(Serialized.Contains('Retryable'), 'Foundation adds Retryable for a write.');
            Response.Get('result', Token);
            Token.AsArray().Get(0, Token);
            Contract := Token.AsObject();
            Contract.WriteTo(ChapterText);
            Assert.IsFalse(LowerCase(ChapterText).Contains('message type'), 'Chapter text does not say message type.');
            foreach Chapter in Chapters do
                Assert.IsTrue(Contract.Contains(Chapter), 'Missing chapter ' + Chapter);
            Contract.Get('effect', Token);
            Assert.AreEqual('write', Data.TextValue(Token.AsObject(), 'effect'), 'Scheduling commits, so the effect is write.');
            Contract.Get('notes', Token);
            Assert.IsTrue(Token.AsValue().AsText().Contains('Omit Commit'), 'Notes disclose the commit.');
        end;
        PriorLanguage := GlobalLanguage();
        MessageType := "Message Type ori"::"Manufacturing.ProductionOrder.Replan";
        Discovery := MessageType;
        GlobalLanguage(1033);
        English := Discovery.GetKeywords();
        GlobalLanguage(1039);
        Icelandic := Discovery.GetKeywords();
        GlobalLanguage(PriorLanguage);
        Assert.AreNotEqual(English, Icelandic, 'Replan keywords are localized.');
        Assert.IsTrue(Icelandic.Split(',').Count() >= English.Split(',').Count(), 'Icelandic replan keywords are at least as long.');
        MessageType := "Message Type ori"::"Manufacturing.ProductionOrder.Reschedule";
        Catalogue := MessageType;
        GlobalLanguage(1033);
        English := Catalogue.GetDescription();
        GlobalLanguage(1039);
        Icelandic := Catalogue.GetDescription();
        GlobalLanguage(PriorLanguage);
        Assert.AreNotEqual(English, Icelandic, 'Reschedule description is localized.');
    end;

    local procedure CheckRefusal(Role: Code[20])
    var
        Discovery: Interface "Msg Interface ori";
        Request: JsonObject;
        Response: JsonObject;
        MessageId: Guid;
        Enabled: Boolean;
    begin
        Commit();
        LowerPermissions.SetExactPermissionSet(Role);
        LowerPermissions.AddPermissionSet('D365 BASIC');
        LowerPermissions.AddPermissionSet('D365PREM MFG, EDIT');
        LowerPermissions.AddPermissionSet('D365 SALES DOC, EDIT');
        Discovery := "Message Type ori"::"Manufacturing.ProductionOrder.Replan";
        Enabled := Discovery.IsEnabled();
        Request.Add('expectedCount', 1);
        Response := Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Replan", Request, 1033, false, MessageId);
        LowerPermissions.SetOutsideO365Scope();
        Assert.IsFalse(Enabled, 'Read and API roles do not see replan as enabled.');
        Data.AssertRefusal(Response, 'PermissionDenied');
        ReopenFixture.AssertLoggedError(MessageId, 'PermissionDenied');
    end;

    local procedure InsertOrder(var Order: Record "Production Order"; ItemNo: Code[20]; OrderStatus: Enum "Production Order Status")
    begin
        Order.Init();
        Order.Status := OrderStatus;
        Order."No." := CopyStr('X' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, 20);
        Order."Source Type" := Order."Source Type"::Item;
        Order."Source No." := ItemNo;
        Order.Insert(false);
    end;
}
