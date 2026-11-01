namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Inventory.Item;
using Microsoft.Manufacturing.Document;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Exercises production order creation through Foundation's public dispatcher.</summary>
codeunit 97604 "Prod Order Create Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Data: Codeunit "Mfg Test Data ori";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Scenario_AC01_Planned_DefaultsAndNumbering()
    var
        Item: Record Item;
        Order: Record "Production Order";
        Request: JsonObject;
        Response: JsonObject;
        Id: Guid;
    begin
        // Story #5 AC01: due date follows WorkDate; no dependency on demo items.
        Data.SetupNumbering(false);
        Data.CreateManufacturedItem(Item);
        Request := Data.CreateRequest(Item."No.");
        Response := Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Create", Request, 1033, true);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Create must succeed.');
        Assert.AreEqual('Planned', Data.TextValue(Response, 'productionOrderStatus'), 'Default status.');
        Assert.AreEqual(Format(WorkDate(), 0, 9), Data.TextValue(Response, 'dueDate'), 'Work-date default.');
        Assert.AreEqual(0, Data.NumberValue(Response, 'linesCreated'), 'Create never refreshes implicitly.');
        Evaluate(Id, Data.TextValue(Response, 'systemId'));
        Assert.IsTrue(Order.GetBySystemId(Id), 'Response must identify an actual order.');
        Assert.AreEqual(Order."Source Type"::Item, Order."Source Type", 'Item source.');
        Assert.AreEqual(Item."No.", Order."Source No.", 'Source item.');
        Assert.AreEqual(5, Order.Quantity, 'Quantity persisted.');
        Assert.IsTrue(CopyStr(Order."No.", 1, 1) = 'X', 'Configured numbering used.');
    end;

    [Test]
    procedure Scenario_AC02_FirmPlanned_ExplicitOptions()
    var
        Item: Record Item;
        Order: Record "Production Order";
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Story #5 AC02: explicit due date overrides WorkDate.
        Data.SetupNumbering(false);
        Data.CreateItem(Item);
        Request := Data.CreateRequest(Item."No.");
        Request.Add('status', 'FirmPlanned');
        Request.Add('dueDate', '2026-12-01');
        Request.Add('description', 'X explicit description');
        Response := Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Create", Request, 1039, true);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Firm planned creation.');
        Assert.IsTrue(Order.Get(Order.Status::"Firm Planned", Data.TextValue(Response, 'no')), 'Firm planned persisted.');
        Assert.AreEqual(20261201D, Order."Due Date", 'Explicit due date.');
        Assert.AreEqual('X explicit description', Order.Description, 'Explicit description.');
    end;

    [Test]
    procedure Scenario_AC03_Released_RefusedWithoutInsert()
    var
        Item: Record Item;
        Order: Record "Production Order";
        Request: JsonObject;
        Response: JsonObject;
        BeforeCount: Integer;
    begin
        // Story #5 AC03: refusal is independent of date and no posting is allowed.
        Data.SetupNumbering(false);
        Data.CreateItem(Item);
        Order.SetRange("Source No.", Item."No.");
        BeforeCount := Order.Count();
        Request := Data.CreateRequest(Item."No.");
        Request.Add('status', 'Released');
        Commit();
        Response := Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Create", Request, 1033, false);
        Data.AssertRefusal(Response, 'InvalidParameter');
        Assert.AreEqual('status', Data.TextValue(Response, 'parameter'), 'Rejected parameter.');
        Assert.IsTrue(Data.TextValue(Response, 'nextStep').Contains('Manufacturing.ProductionOrder.ChangeStatus'), 'Release guidance.');
        Assert.AreEqual(BeforeCount, Order.Count(), 'Refusal must not insert.');
    end;

    [Test]
    procedure Scenario_AC04_MissingRequired_Collected()
    var
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
    begin
        // Story #5 AC04: all independent request errors survive aggregation.
        Data.SetupNumbering(false);
        Commit();
        Response := Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Create", Request, 1033, false);
        Data.AssertRefusal(Response, 'MultipleErrors');
        Response.Get('errors', Token);
        Assert.AreEqual(2, Token.AsArray().Count(), 'Both required fields are reported.');
    end;

    [Test]
    procedure Scenario_UnknownParameter_FoundationRefusesBeforeExecution()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        // Foundation rejects unknown write parameters before the implementation executes.
        Request.Add('surprise', true);
        Response := Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Create", Request, 1033, false);
        Data.AssertRefusal(Response, 'UnknownParameter');
    end;

    [Test]
    procedure Scenario_AC04_Quantity_BoundariesAndFormat()
    var
        Item: Record Item;
        Request: JsonObject;
    begin
        // Story #5 AC04: numeric JSON type and strict positive boundary.
        Data.SetupNumbering(false);
        Data.CreateItem(Item);
        Request := Data.CreateRequest(Item."No.");
        Commit();
        Request.Replace('quantity', 0);
        Data.AssertRefusal(Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Create", Request, 1033, false), 'InvalidParameter');
        Request.Replace('quantity', -1);
        Data.AssertRefusal(Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Create", Request, 1033, false), 'InvalidParameter');
        Request.Replace('quantity', '5');
        Data.AssertRefusal(Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Create", Request, 1033, false), 'InvalidParameterFormat');
        Request.Replace('quantity', 'no number');
        Data.AssertRefusal(Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Create", Request, 1033, false), 'InvalidParameterFormat');
    end;

    [Test]
    procedure Scenario_AC05_UnknownItem_Refused()
    var
        Request: JsonObject;
    begin
        // Story #5 AC05: generated absent identifier; no customer fixtures.
        Data.SetupNumbering(false);
        Request := Data.CreateRequest(CopyStr('X' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, 20));
        Commit();
        Data.AssertRefusal(Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Create", Request, 1033, false), 'RecordNotFound');
    end;

    [Test]
    procedure Scenario_AC05_OutputBlocked_Refused()
    var
        Item: Record Item;
        Request: JsonObject;
    begin
        // Story #5 AC05: the native item production block must be respected.
        Data.SetupNumbering(false);
        Data.CreateItem(Item);
        Item.Validate("Production Blocked", Item."Production Blocked"::Output);
        Item.Modify(true);
        Request := Data.CreateRequest(Item."No.");
        Commit();
        Data.AssertRefusal(Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Create", Request, 1033, false), 'PreconditionFailed');
    end;

    [Test]
    procedure Scenario_AC06_ManualNumber_RequiresManualSeries()
    var
        Item: Record Item;
        Order: Record "Production Order";
        Request: JsonObject;
        Response: JsonObject;
        ManualNo: Code[20];
    begin
        // Story #5 AC06: BC owns the manual-number rule, including duplicate refusal.
        Data.SetupNumbering(false);
        Data.CreateItem(Item);
        ManualNo := CopyStr('X' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, 20);
        Request := Data.CreateRequest(Item."No.");
        Request.Add('no', ManualNo);
        Commit();
        Data.AssertRefusal(Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Create", Request, 1033, false), 'BusinessCentralError');
        Assert.IsFalse(Order.Get(Order.Status::Planned, ManualNo), 'No nonmanual insert.');
        Data.SetupNumbering(true);
        Commit();
        Response := Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Create", Request, 1033, false);
        Assert.AreEqual(ManualNo, Data.TextValue(Response, 'no'), 'Manual number used.');
        Data.AssertRefusal(Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Create", Request, 1033, false), 'BusinessCentralError');
        Order.Get(Order.Status::Planned, ManualNo);
        Assert.AreEqual(5, Order.Quantity, 'Duplicate did not overwrite.');
    end;

    [Test]
    procedure Scenario_AC04_OverlongAndInvalidDate_Refused()
    var
        Item: Record Item;
        Request: JsonObject;
    begin
        // Story #5 AC04: overlong text must not silently select another record.
        Data.SetupNumbering(false);
        Data.CreateItem(Item);
        Request := Data.CreateRequest(Item."No.");
        Request.Add('description', PadStr('X', 101, 'X'));
        Commit();
        Data.AssertRefusal(Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Create", Request, 1033, false), 'InvalidParameter');
        Request.Remove('description');
        Request.Add('dueDate', '2026-02-30');
        Data.AssertRefusal(Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Create", Request, 1033, false), 'InvalidParameterFormat');
    end;
}
