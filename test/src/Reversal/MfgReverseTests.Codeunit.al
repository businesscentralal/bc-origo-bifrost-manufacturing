namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Inventory.Ledger;
using Microsoft.Manufacturing.Capacity;
using Microsoft.Manufacturing.Document;
using Microsoft.Manufacturing.WorkCenter;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Issue 25 acceptance through the public dispatcher with raw owned data and logged refusals.</summary>
codeunit 97653 "Mfg Reverse Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Lib: Codeunit "Mfg Reverse Test Lib ori";
        Data: Codeunit "Mfg Test Data ori";
        Fixture: Codeunit "Mfg Reopen Fixture ori";
        Assert: Codeunit "Library Assert";

    [Test]
    [HandlerFunctions('ConfirmNative,MessageNative')]
    procedure AC01_OutputTenAndLastCapacity_1033()
    begin
        OutputLifecycle(1033);
    end;

    [Test]
    [HandlerFunctions('ConfirmNative,MessageNative')]
    procedure AC01_OutputTenAndLastCapacity_1039()
    begin
        OutputLifecycle(1039);
    end;

    local procedure OutputLifecycle(LanguageId: Integer)
    var
        Order: Record "Production Order";
        Line: Record "Prod. Order Line";
        Entry: Record "Item Ledger Entry";
        Capacity: Record "Capacity Ledger Entry";
        Response: JsonObject;
        Token: JsonToken;
        Detail: JsonToken;
        Request: JsonObject;
        OriginalNo: Integer;
        OriginalQuantity: Decimal;
        OriginalDate: Date;
        OriginalDimensions: Integer;
        Raw: Text;
    begin
        Lib.Seed('X25REV', false, Order);
        Lib.PostOrder(Order);
        OriginalNo := Lib.Original(Order, Entry."Entry Type"::Output);
        Entry.Get(OriginalNo);
        OriginalQuantity := Entry.Quantity;
        OriginalDate := Entry."Posting Date";
        OriginalDimensions := Entry."Dimension Set ID";
        Assert.AreEqual(10, OriginalQuantity, 'Fixture posted output ten.');
        Request := Lib.Request(Order, OriginalNo);
        Response := Data.Invoke("Message Type ori"::"Manufacturing.Output.Reverse", Request, LanguageId, false);
        Response.WriteTo(Raw);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), Raw);
        Response.Get('reversed', Token);
        Token.AsArray().Get(0, Detail);
        Entry.Get(Data.NumberValue(Detail.AsObject(), 'newEntryNo'));
        Assert.AreEqual(-10, Entry.Quantity, 'Correcting output is minus ten.');
        Assert.AreEqual(OriginalDate, Entry."Posting Date", 'Original posting date preserved.');
        Assert.AreEqual(OriginalDimensions, Entry."Dimension Set ID", 'Original dimensions preserved.');
        Entry.Get(OriginalNo);
        Assert.AreEqual(OriginalQuantity, Entry.Quantity, 'Original posted quantity unchanged.');
        Line.Get(Order.Status, Order."No.", 10000);
        Assert.AreEqual(10, Line."Remaining Quantity", 'All output is again outstanding.');
        Capacity.SetRange("Order No.", Order."No.");
        Capacity.SetRange(Reversed, true);
        Assert.AreEqual(2, Capacity.Count(), 'Original and correcting last-operation capacity are linked as reversed.');
        Refusal("Message Type ori"::"Manufacturing.Output.Reverse", Request, 'PreconditionFailed', LanguageId);
        Lib.Cleanup('X25REV');
        Commit();
    end;

    [Test]
    [HandlerFunctions('ConfirmNative,MessageNative')]
    procedure AC02_ConsumptionReturnsToSameLot()
    var
        Order: Record "Production Order";
        Entry: Record "Item Ledger Entry";
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        Detail: JsonToken;
        OriginalNo: Integer;
        Raw: Text;
    begin
        Lib.Seed('X25REV', true, Order);
        OriginalNo := Lib.Original(Order, Entry."Entry Type"::Consumption);
        Request := Lib.Request(Order, OriginalNo);
        Response := Data.Invoke("Message Type ori"::"Manufacturing.Consumption.Reverse", Request, 1039, false);
        Response.WriteTo(Raw);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), Raw);
        Response.Get('reversed', Token);
        Token.AsArray().Get(0, Detail);
        Entry.Get(Data.NumberValue(Detail.AsObject(), 'newEntryNo'));
        Assert.AreEqual(50, Entry.Quantity, 'Consumed fifty returned.');
        Assert.AreEqual('X25REV-LOT', Entry."Lot No.", 'Returns to original lot.');
        Entry.Get(OriginalNo);
        Assert.AreEqual(-50, Entry.Quantity, 'Original consumption remains.');
        Refusal("Message Type ori"::"Manufacturing.Consumption.Reverse", Request, 'PreconditionFailed', 1039);
        Lib.Cleanup('X25REV');
        Commit();
    end;

    [Test]
    procedure AC03_ConfirmationRequiredAndMismatch()
    var
        Order: Record "Production Order";
        Entry: Record "Item Ledger Entry";
        Request: JsonObject;
    begin
        Lib.Seed('X25REV', false, Order);
        Lib.PostOrder(Order);
        Request := Lib.Request(Order, Lib.Original(Order, Entry."Entry Type"::Output));
        Request.Remove('expectedCount');
        Refusal("Message Type ori"::"Manufacturing.Output.Reverse", Request, 'ConfirmationRequired', 1033);
        Request.Add('expectedCount', 2);
        Refusal("Message Type ori"::"Manufacturing.Output.Reverse", Request, 'ConfirmationMismatch', 1039);
        Lib.Cleanup('X25REV');
        Commit();
    end;

    [Test]
    procedure C1_InputRefusalsAndConflictingIdentifiers()
    var
        Order: Record "Production Order";
        Other: Record "Production Order";
        Entry: Record "Item Ledger Entry";
        Request: JsonObject;
        Entries: JsonArray;
    begin
        Lib.Seed('X25REV', false, Order);
        Lib.PostOrder(Order);
        Refusal("Message Type ori"::"Manufacturing.Output.Reverse", Request, 'MissingParameter', 1033);
        Request := Lib.Request(Order, Lib.Original(Order, Entry."Entry Type"::Output));
        Request.Add('unexpected', true);
        Refusal("Message Type ori"::"Manufacturing.Output.Reverse", Request, 'UnknownParameter', 1039);
        Request.Remove('unexpected');
        Request.Replace('prodOrderNo', true);
        Refusal("Message Type ori"::"Manufacturing.Output.Reverse", Request, 'InvalidParameterFormat', 1039);
        Request.Replace('prodOrderNo', Order."No.");
        Request.Replace('itemLedgerEntryNos', 'bad');
        Refusal("Message Type ori"::"Manufacturing.Output.Reverse", Request, 'InvalidParameterFormat', 1033);
        Clear(Entries);
        Entries.Add(2147483647);
        Request.Replace('itemLedgerEntryNos', Entries);
        Refusal("Message Type ori"::"Manufacturing.Output.Reverse", Request, 'RecordNotFound', 1039);
        Request := Lib.Request(Order, Lib.Original(Order, Entry."Entry Type"::Consumption));
        Refusal("Message Type ori"::"Manufacturing.Output.Reverse", Request, 'InvalidParameterFormat', 1033);
        Lib.Seed('X25OTHER', false, Other);
        Request := Lib.Request(Order, Lib.Original(Order, Entry."Entry Type"::Output));
        Request.Add('systemId', Format(Other.SystemId, 0, 4));
        Refusal("Message Type ori"::"Manufacturing.Output.Reverse", Request, 'ConflictingIdentifiers', 1039);
        Request.Remove('systemId');
        Request.Replace('prodOrderNo', Other."No.");
        Refusal("Message Type ori"::"Manufacturing.Output.Reverse", Request, 'InvalidParameterFormat', 1033);
        Lib.Cleanup('X25OTHER');
        Lib.Cleanup('X25REV');
        Commit();
    end;

    [Test]
    [HandlerFunctions('ConfirmNative')]
    procedure AC04_LastCapacityAndSubcontractingRefused()
    var
        Order: Record "Production Order";
        Capacity: Record "Capacity Ledger Entry";
        Center: Record "Work Center";
        Request: JsonObject;
        Entries: JsonArray;
    begin
        Lib.Seed('X25REV', false, Order);
        Lib.PostOrder(Order);
        Capacity.SetRange("Order No.", Order."No.");
        Capacity.FindFirst();
        Request.Add('prodOrderNo', Order."No.");
        Entries.Add(Capacity."Entry No.");
        Request.Add('capacityLedgerEntryNos', Entries);
        Request.Add('expectedCount', 1);
        Refusal("Message Type ori"::"Manufacturing.Output.Reverse", Request, 'PreconditionFailed', 1033);
        Center.Get('X25REV');
        Center."Subcontractor No." := 'X25-UNUSED';
        Center.Modify();
        Commit();
        Request := Lib.Request(Order, Lib.Original(Order, "Item Ledger Entry Type"::Output));
        Refusal("Message Type ori"::"Manufacturing.Output.Reverse", Request, 'PreconditionFailed', 1039);
        Lib.Cleanup('X25REV');
        Commit();
    end;

    [Test]
    procedure AC04_FinishedOrderAndDuplicateRefused()
    var
        Order: Record "Production Order";
        Request: JsonObject;
        Entries: JsonArray;
        Number: Integer;
    begin
        Lib.Seed('X25REV', false, Order);
        Lib.PostOrder(Order);
        Number := Lib.Original(Order, "Item Ledger Entry Type"::Output);
        Request := Lib.Request(Order, Number);
        Entries.Add(Number);
        Entries.Add(Number);
        Request.Replace('itemLedgerEntryNos', Entries);
        Refusal("Message Type ori"::"Manufacturing.Output.Reverse", Request, 'InvalidParameterFormat', 1033);
        Fixture.FinishAndAdjust(Order);
        Commit();
        Request := Lib.Request(Order, Number);
        Refusal("Message Type ori"::"Manufacturing.Output.Reverse", Request, 'PreconditionFailed', 1039);
        Request := Lib.Request(Order, Lib.Original(Order, "Item Ledger Entry Type"::Consumption));
        Refusal("Message Type ori"::"Manufacturing.Consumption.Reverse", Request, 'PreconditionFailed', 1033);
        Lib.Cleanup('X25REV');
        Commit();
    end;

    [Test]
    [HandlerFunctions('ConfirmNative')]
    procedure C1_BatchRollsBackAfterNativePostedEntry()
    var
        Order: Record "Production Order";
        Capacity: Record "Capacity Ledger Entry";
        Entry: Record "Item Ledger Entry";
        Fault: Codeunit "Mfg Reverse Fault ori";
        StatusLib: Codeunit "Mfg Status Test Lib ori";
        Request: JsonObject;
        Response: JsonObject;
    begin
        Lib.Seed('X25REV', false, Order);
        Lib.PostOrder(Order);
        Capacity.SetRange("Order No.", Order."No.");
        Capacity.FindFirst();
        Request := Lib.Request(Order, Lib.Original(Order, Entry."Entry Type"::Output));
        BindSubscription(Fault);
        Response := Refusal("Message Type ori"::"Manufacturing.Output.Reverse", Request, 'PreconditionFailed', 1033);
        UnbindSubscription(Fault);
        Assert.IsTrue(StatusLib.ResponseContains(Response, 'Injected reversal rollback probe'), 'Failure occurred after native correction posting.');
        Entry.Get(Lib.Original(Order, Entry."Entry Type"::Output));
        Assert.AreEqual(10, Entry."Remaining Quantity", 'Native correcting output rolled back.');
        Capacity.Get(Capacity."Entry No.");
        Assert.IsFalse(Capacity.Reversed, 'Native capacity reversal rolled back.');
        Lib.Cleanup('X25REV');
        Commit();
    end;

    [Test]
    [HandlerFunctions('ConfirmNative,MessageNative')]
    procedure AC01_IntermediateCapacityOnly()
    var
        Order: Record "Production Order";
        Capacity: Record "Capacity Ledger Entry";
        Entry: Record "Item Ledger Entry";
        Request: JsonObject;
        Entries: JsonArray;
        Response: JsonObject;
        Raw: Text;
    begin
        Lib.Seed('X25REV', false, Order);
        Lib.AddOperation(Order);
        Lib.PostOrder(Order, 3);
        Capacity.SetRange("Order No.", Order."No.");
        Capacity.SetRange("Operation No.", '10');
        Capacity.FindFirst();
        Request.Add('prodOrderNo', Order."No.");
        Entries.Add(Capacity."Entry No.");
        Request.Add('capacityLedgerEntryNos', Entries);
        Request.Add('expectedCount', 1);
        Response := Data.Invoke("Message Type ori"::"Manufacturing.Output.Reverse", Request, 1033, false);
        Response.WriteTo(Raw);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), Raw);
        Entry.Get(Lib.Original(Order, Entry."Entry Type"::Output));
        Assert.AreEqual(10, Entry.Quantity, 'Intermediate reversal leaves output quantity.');
        Capacity.Get(Capacity."Entry No.");
        Assert.IsTrue(Capacity.Reversed, 'Intermediate operation reversed.');
        Lib.Cleanup('X25REV');
        Commit();
    end;

    [Test]
    procedure AC03_AC04_ConsumptionInvalidAndConfirmation()
    var
        Order: Record "Production Order";
        Request: JsonObject;
        Entries: JsonArray;
    begin
        Lib.Seed('X25REV', false, Order);
        Lib.PostOrder(Order);
        Refusal("Message Type ori"::"Manufacturing.Consumption.Reverse", Request, 'MissingParameter', 1033);
        Request := Lib.Request(Order, Lib.Original(Order, "Item Ledger Entry Type"::Output));
        Refusal("Message Type ori"::"Manufacturing.Consumption.Reverse", Request, 'InvalidParameterFormat', 1033);
        Request := Lib.Request(Order, Lib.Original(Order, "Item Ledger Entry Type"::Consumption));
        Request.Remove('expectedCount');
        Refusal("Message Type ori"::"Manufacturing.Consumption.Reverse", Request, 'ConfirmationRequired', 1039);
        Request.Add('expectedCount', 2);
        Refusal("Message Type ori"::"Manufacturing.Consumption.Reverse", Request, 'ConfirmationMismatch', 1033);
        Request.Add('capacityLedgerEntryNos', Entries);
        Refusal("Message Type ori"::"Manufacturing.Consumption.Reverse", Request, 'UnknownParameter', 1039);
        Request := Lib.Request(Order, 2147483647);
        Refusal("Message Type ori"::"Manufacturing.Consumption.Reverse", Request, 'RecordNotFound', 1033);
        Request := Lib.Request(Order, Lib.Original(Order, "Item Ledger Entry Type"::Consumption));
        Request.Add('no', 'X25OTHER');
        Refusal("Message Type ori"::"Manufacturing.Consumption.Reverse", Request, 'ConflictingIdentifiers', 1039);
        Lib.Cleanup('X25REV');
        Commit();
    end;

    [Test]
    procedure C1_OmitCommitRefusedBeforePosting()
    var
        Order: Record "Production Order";
        Entry: Record "Item Ledger Entry";
        Request: JsonObject;
        Response: JsonObject;
        Before: Integer;
    begin
        Lib.Seed('X25REV', false, Order);
        Lib.PostOrder(Order);
        Before := Entry.Count();
        Request := Lib.Request(Order, Lib.Original(Order, Entry."Entry Type"::Output));
        Response := Data.Invoke("Message Type ori"::"Manufacturing.Output.Reverse", Request, 1033, true);
        Data.AssertRefusal(Response, 'PreconditionFailed');
        Assert.AreEqual(Before, Entry.Count(), 'Omit Commit posts nothing.');
        Request := Lib.Request(Order, Lib.Original(Order, Entry."Entry Type"::Consumption));
        Response := Data.Invoke("Message Type ori"::"Manufacturing.Consumption.Reverse", Request, 1039, true);
        Data.AssertRefusal(Response, 'PreconditionFailed');
        Assert.AreEqual(Before, Entry.Count(), 'Omit Commit posts no consumption correction.');
        Lib.Cleanup('X25REV');
        Commit();
    end;

    local procedure Refusal(Type: Enum "Message Type ori"; Request: JsonObject; Code: Text; LanguageId: Integer): JsonObject
    var
        Entry: Record "Item Ledger Entry";
        Capacity: Record "Capacity Ledger Entry";
        Response: JsonObject;
        MessageId: Guid;
        ItemCount: Integer;
        CapacityCount: Integer;
        CountsBefore: Text;
    begin
        CountsBefore := Lib.Snapshot();
        ItemCount := Entry.Count();
        CapacityCount := Capacity.Count();
        Commit();
        Response := Data.Invoke(Type, Request, LanguageId, false, MessageId);
        Data.AssertRefusal(Response, Code);
        Fixture.AssertLoggedError(MessageId, Code);
        Assert.AreEqual(ItemCount, Entry.Count(), 'Refusal creates no item entry.');
        Assert.AreEqual(CapacityCount, Capacity.Count(), 'Refusal creates no capacity entry.');
        Assert.AreEqual(CountsBefore, Lib.Snapshot(), 'All ten posting and production table counts are unchanged.');
        exit(Response);
    end;

    /// <summary>Allows the native GUI-only confirmation during AL client tests; API calls never show it.</summary>
    [ConfirmHandler]
    procedure ConfirmNative(Question: Text[1024]; var Reply: Boolean)
    begin
        Reply := true;
    end;

    /// <summary>Consumes native GUI-only success notification during AL client tests.</summary>
    [MessageHandler]
    procedure MessageNative(MessageText: Text[1024])
    begin
    end;
}
