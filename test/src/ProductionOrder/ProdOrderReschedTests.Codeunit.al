namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Inventory.Item;
using Microsoft.Manufacturing.Document;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Issue 24: Manufacturing.ProductionOrder.Reschedule acceptance and refusals.</summary>
codeunit 97682 "Prod Order Resched Tests ori"
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
    procedure AC01_ReleasedDueDateMovesRoutingCapacityAndComponents()
    var
        Item: Record Item;
        Order: Record "Production Order";
        Line: Record "Prod. Order Line";
        Response: JsonObject;
        Raw: Text;
        RequestedDue: Date;
        BeforeDue: Date;
        BeforeRouting: DateTime;
        BeforeComponent: Date;
        BeforeCapacity: Date;
        AfterCapacity: Date;
        BeforeCount: Integer;
        AfterCount: Integer;
        LineNo: Integer;
        StartText: Text;
    begin
        // Story #24 AC01 | GIVEN a released two-operation order | WHEN the due date moves | THEN routing, capacity and components move with it.
        Lib.CreateReleasedTwoOperation(Item, Order);
        BeforeDue := Lib.DueDate(Order);
        BeforeRouting := Lib.RoutingStart(Order);
        BeforeComponent := Lib.ComponentDue(Order);
        Lib.Capacity(Order, BeforeCapacity, BeforeCount);
        Assert.IsTrue(BeforeCount > 0, 'The released order has capacity need.');
        RequestedDue := CalcDate('<+21D>', BeforeDue);
        Response := Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Reschedule", Lib.RescheduleDue(Order, Format(RequestedDue, 0, 9)), 1033, false);
        Response.WriteTo(Raw);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), Raw);
        Assert.AreEqual('Released', Data.TextValue(Response, 'productionOrderStatus'), 'Status stays Released.');
        Assert.AreEqual(Format(RequestedDue, 0, 9), Lib.ObjectText(Response, 'after', 'dueDate'), 'The response reports the new due date.');
        Assert.AreEqual(RequestedDue, Lib.DueDate(Order), 'The due date moved.');
        Assert.AreNotEqual(BeforeRouting, Lib.RoutingStart(Order), 'Routing dates moved.');
        Assert.AreNotEqual(BeforeComponent, Lib.ComponentDue(Order), 'Component due dates moved.');
        Lib.Capacity(Order, AfterCapacity, AfterCount);
        Assert.IsTrue(AfterCount > 0, 'Capacity need was rebuilt.');
        Assert.AreNotEqual(BeforeCapacity, AfterCapacity, 'Capacity dates moved.');
        Assert.IsTrue(Lib.ArrayCount(Response, 'routingLines') >= 2, 'Both operations are returned.');
        Assert.IsTrue(Lib.ArrayCount(Response, 'warnings') >= 0, 'Warnings are present.');

        RequestedDue := CalcDate('<+7D>', RequestedDue);
        Response := Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Reschedule", Lib.RescheduleDue(Order, Format(RequestedDue, 0, 9)), 1039, false);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Icelandic reschedule succeeds.');
        Assert.AreEqual(RequestedDue, Lib.DueDate(Order), 'The Icelandic call moved the due date.');

        Line.SetRange(Status, Order.Status);
        Line.SetRange("Prod. Order No.", Order."No.");
        Line.FindFirst();
        LineNo := Line."Line No.";
        BeforeRouting := Lib.RoutingStart(Order);
        StartText := Format(CreateDateTime(CalcDate('<+30D>', WorkDate()), 080000T), 0, 9);
        Response := Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Reschedule", Lib.RescheduleStart(Order, LineNo, StartText), 1033, false);
        Response.WriteTo(Raw);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Line forward edge: ' + Raw);
        Assert.AreEqual(LineNo, Data.NumberValue(Response, 'lineNo'), 'The response names the line.');
        Assert.AreNotEqual(BeforeRouting, Lib.RoutingStart(Order), 'Forward scheduling moves the routing.');
        Lib.Cleanup(Item."No.");
    end;

    [Test]
    procedure AC04_C1_StatusDatesFormatAndIdentity()
    var
        Item: Record Item;
        Planned: Record "Production Order";
        Finished: Record "Production Order";
        Firm: Record "Production Order";
        Other: Record "Production Order";
        Line: Record "Prod. Order Line";
        Request: JsonObject;
        Response: JsonObject;
        English: Text;
        Icelandic: Text;
        MessageId: Guid;
    begin
        // Story #24 AC04/C1 | GIVEN bare orders | WHEN the request is ineligible | THEN a structured refusal changes nothing.
        Data.CreateItem(Item);
        InsertOrder(Planned, Item."No.", Planned.Status::Planned);
        InsertOrder(Finished, Item."No.", Finished.Status::Finished);
        InsertOrder(Firm, Item."No.", Firm.Status::"Firm Planned");
        InsertOrder(Other, Item."No.", Other.Status::"Firm Planned");
        Line.Init();
        Line.Status := Firm.Status;
        Line."Prod. Order No." := Firm."No.";
        Line."Line No." := 10000;
        Line."Item No." := Item."No.";
        Line."Planning Level Code" := 1;
        Line.Insert(false);
        Commit();

        Response := Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Reschedule", Lib.RescheduleDue(Finished, Format(WorkDate(), 0, 9)), 1033, false, MessageId);
        Data.AssertRefusal(Response, 'PreconditionFailed');
        English := Data.TextValue(Response, 'error');
        Assert.IsFalse(LowerCase(English).Contains('message type'), 'The refusal does not say message type.');
        ReopenFixture.AssertLoggedError(MessageId, 'PreconditionFailed');
        Response := Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Reschedule", Lib.RescheduleDue(Finished, Format(WorkDate(), 0, 9)), 1039, false);
        Icelandic := Data.TextValue(Response, 'error');
        Assert.AreNotEqual(English, Icelandic, 'Finished refusal is translated.');

        Response := Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Reschedule", Lib.RescheduleDue(Planned, Format(WorkDate(), 0, 9)), 1033, false);
        Data.AssertRefusal(Response, 'PreconditionFailed');
        Assert.IsTrue(Data.TextValue(Response, 'nextStep').Contains('Manufacturing.ProductionOrder.Refresh'), 'Planned next step names Refresh.');

        Request := Lib.Identity(Other);
        Request.Add('direction', 'backward');
        Data.AssertRefusal(Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Reschedule", Request, 1033, false), 'MissingParameter');

        Request := Lib.RescheduleDue(Other, '2026/01/01');
        Data.AssertRefusal(Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Reschedule", Request, 1033, false), 'InvalidParameterFormat');

        Request := Lib.RescheduleDue(Other, Format(WorkDate(), 0, 9));
        Request.Add('startingDateTime', Format(CreateDateTime(WorkDate(), 080000T), 0, 9));
        Data.AssertRefusal(Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Reschedule", Request, 1033, false), 'InvalidParameter');

        Request := Lib.RescheduleDue(Other, Format(WorkDate(), 0, 9));
        Request.Add('expectedCount', 1);
        Data.AssertRefusal(Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Reschedule", Request, 1033, false), 'UnknownParameter');

        Request := Lib.RescheduleDue(Other, Format(WorkDate(), 0, 9));
        Request.Add('lineNo', '10');
        Data.AssertRefusal(Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Reschedule", Request, 1033, false), 'InvalidParameterFormat');

        Request := Lib.RescheduleDue(Other, Format(WorkDate(), 0, 9));
        Request.Add('lineNo', 999999);
        Data.AssertRefusal(Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Reschedule", Request, 1033, false), 'RecordNotFound');

        Clear(Request);
        Request.Add('systemId', Format(CreateGuid(), 0, 4));
        Request.Add('dueDate', Format(WorkDate(), 0, 9));
        Data.AssertRefusal(Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Reschedule", Request, 1033, false), 'RecordNotFound');

        Request := Lib.Identity(Other);
        Request.Add('no', Firm."No.");
        Request.Add('dueDate', Format(WorkDate(), 0, 9));
        Data.AssertRefusal(Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Reschedule", Request, 1033, false), 'ConflictingIdentifiers');

        Response := Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Reschedule", Lib.RescheduleDue(Firm, Format(CalcDate('<+10D>', WorkDate()), 0, 9)), 1033, false);
        Data.AssertRefusal(Response, 'PreconditionFailed');
        Assert.IsTrue(LowerCase(Data.TextValue(Response, 'error')).Contains('planning') or Data.TextValue(Response, 'nextStep').Contains('no levels') or LowerCase(Data.TextValue(Response, 'error')).Contains('stig'), 'Lower planning levels are refused.');
        Assert.IsTrue(Firm.Get(Firm.Status, Firm."No."), 'The multilevel order remains.');

        Response := Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Reschedule", Lib.RescheduleDue(Other, Format(WorkDate(), 0, 9)), 1033, true);
        Data.AssertRefusal(Response, 'PreconditionFailed');
        Assert.IsTrue(LowerCase(Data.TextValue(Response, 'error')).Contains('omit commit'), 'Omit Commit is named.');
        Lib.Cleanup(Item."No.");
    end;

    [Test]
    procedure AC05_C1_ReadRoleAndNoPermissionRefused()
    begin
        // Story #24 AC05/C1 | GIVEN a read role or no Manufacturing role | WHEN reschedule is called | THEN permission is denied.
        CheckRefusal('BIFROST Read ori');
        CheckRefusal('BIFROST API ori');
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
        Discovery := "Message Type ori"::"Manufacturing.ProductionOrder.Reschedule";
        Enabled := Discovery.IsEnabled();
        Request.Add('dueDate', Format(WorkDate(), 0, 9));
        Response := Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Reschedule", Request, 1033, false, MessageId);
        LowerPermissions.SetOutsideO365Scope();
        Assert.IsFalse(Enabled, 'Read and API roles do not see reschedule as enabled.');
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
