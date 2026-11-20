namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Inventory.Costing;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Microsoft.Manufacturing.Document;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Issue 26: real stock posting, native cost parity, strict refusals and stable read results.</summary>
codeunit 97628 "Mfg Order Read Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Fixture: Codeunit "Mfg Read Fixture ori";
        Data: Codeunit "Mfg Test Data ori";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure AC01_StockTwoThenFive_ShortageThreeThenZero()
    var
        Order: Record "Production Order";
        Request: JsonObject;
        Response: JsonObject;
        LanguageId: Integer;
        Prefix: Code[10];
    begin
        Prefix := NewPrefix();
        Fixture.Seed(Prefix, Order);
        Fixture.Post(Prefix, "Item Ledger Entry Type"::"Positive Adjmt.", 2);
        Request := RequestFor(Order);
        foreach LanguageId in Languages() do begin
            Response := Data.Invoke("Message Type ori"::"Manufacturing.ComponentAvailability.Get", Request, LanguageId, false);
            AssertSuccess(Response);
            Assert.AreEqual(3, Data.NumberValue(FirstComponent(Response), 'shortage'), 'Two available, five required.');
            Assert.AreEqual(2, Data.NumberValue(FirstComponent(Response), 'inventory'), 'Real posted stock.');
        end;
        Fixture.Post(Prefix, "Item Ledger Entry Type"::"Positive Adjmt.", 3);
        foreach LanguageId in Languages() do begin
            Response := Data.Invoke("Message Type ori"::"Manufacturing.ComponentAvailability.Get", Request, LanguageId, false);
            AssertSuccess(Response);
            Assert.AreEqual(0, Data.NumberValue(FirstComponent(Response), 'shortage'), 'Replenishment removes shortage.');
        end;
    end;

    [Test]
    procedure AC02_PostFinishAdjust_StatisticsMatchesNativeCosts()
    var
        Order: Record "Production Order";
        Line: Record "Prod. Order Line";
        GLSetup: Record "General Ledger Setup";
        Cost: Codeunit "Mfg. Cost Calculation Mgt.";
        Standard: array[5] of Decimal;
        Expected: array[5] of Decimal;
        Actual: array[5] of Decimal;
        Dummy: array[5] of Decimal;
        Share: Decimal;
        Response: JsonObject;
        Prefix: Code[10];
        LanguageId: Integer;
    begin
        Prefix := NewPrefix();
        Fixture.Seed(Prefix, Order);
        Fixture.Post(Prefix, "Item Ledger Entry Type"::"Positive Adjmt.", 5);
        Fixture.Post(Prefix, "Item Ledger Entry Type"::Consumption, 5);
        Fixture.Post(Prefix, "Item Ledger Entry Type"::Output, 1);
        Fixture.FinishAndAdjust(Order);
        Line.Get(Order.Status, Order."No.", 10000);
        GLSetup.Get();
        Cost.CalcShareOfTotalCapCost(Line, Share);
        Cost.CalcProdOrderLineStdCost(Line, 1, GLSetup."Amount Rounding Precision", Standard[1], Standard[2], Standard[3], Standard[4], Standard[5]);
        Cost.CalcProdOrderLineExpCost(Line, Share, Expected[1], Expected[2], Expected[3], Expected[4], Expected[5]);
        Cost.CalcProdOrderLineActCost(Line, Actual[1], Actual[2], Actual[3], Actual[4], Actual[5], Dummy[1], Dummy[2], Dummy[3], Dummy[4], Dummy[5]);
        Assert.IsTrue(Actual[1] > 0, 'Posted consumption must produce real actual costs.');
        foreach LanguageId in Languages() do begin
            Response := Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrderStatistics.Get", RequestFor(Order), LanguageId, false);
            AssertSuccess(Response);
            AssertBlock(Response, 'standard', Standard);
            AssertBlock(Response, 'expected', Expected);
            AssertBlock(Response, 'actual', Actual);
            Assert.AreEqual('', Data.TextValue(Response, 'currencyCode'), 'LCY.');
            Assert.AreEqual(1, Data.NumberValue(Response, 'output'), 'Posted output quantity.');
            Assert.AreEqual(Cost.CalcProdOrderExpCapNeed(Order, false), Data.NumberValue(Response, 'capacityNeed'), 'No routing means zero capacity need.');
        end;
    end;

    [Test]
    procedure C1_EachRefusalHasCodeNextStepAndNoBusinessWrites()
    var
        Order: Record "Production Order";
        Other: Record "Production Order";
        Request: JsonObject;
        Kind: Enum "Message Type ori";
    begin
        Fixture.Seed(NewPrefix(), Order);
        Fixture.Seed(NewPrefix(), Other);
        foreach Kind in Kinds() do begin
            Clear(Request);
            Request.Add('status', 'Released');
            Refusal(Kind, Request, 'MissingParameter');
            Request := RequestFor(Order);
            Request.Replace('status', 'Unknown');
            Refusal(Kind, Request, 'InvalidParameterFormat');
            Request := RequestFor(Order);
            Request.Replace('no', 'X26-NOT-FOUND');
            Refusal(Kind, Request, 'RecordNotFound');
            Request := RequestFor(Order);
            Request.Add('surprise', true);
            Refusal(Kind, Request, 'UnknownParameter');
            Request := RequestFor(Order);
            Request.Add('systemId', Format(Other.SystemId, 0, 4));
            Refusal(Kind, Request, 'ConflictingIdentifiers');
            Request := RequestFor(Order);
            Request.Add('lineNo', 0);
            Refusal(Kind, Request, 'InvalidParameterFormat');
            Request.Replace('lineNo', '10000');
            Refusal(Kind, Request, 'InvalidParameterFormat');
            Request.Replace('lineNo', 20000);
            Refusal(Kind, Request, 'RecordNotFound');
            Request := RequestFor(Order);
            Request.Add('systemId', 'not-a-guid');
            Refusal(Kind, Request, 'InvalidParameterFormat');
        end;
        Order.Status := Order.Status::Finished;
        Order.Insert();
        Request := RequestFor(Order);
        Refusal("Message Type ori"::"Manufacturing.ComponentAvailability.Get", Request, 'PreconditionFailed');
    end;

    [Test]
    procedure Edge_EmptySelectionZeroStandardAndIdentifierParity()
    var
        Order: Record "Production Order";
        Item: Record Item;
        Request: JsonObject;
        Response: JsonObject;
        Token: JsonToken;
        Prefix: Code[10];
    begin
        Prefix := NewPrefix();
        Fixture.Seed(Prefix, Order);
        Request := RequestFor(Order);
        Request.Add('locationCode', '');
        Response := Data.Invoke("Message Type ori"::"Manufacturing.ComponentAvailability.Get", Request, 1033, false);
        AssertSuccess(Response);
        Response.Get('components', Token);
        Assert.AreEqual(0, Token.AsArray().Count(), 'Explicit blank location does not mean every location.');
        Item.Get(Prefix + '-P');
        Item."Single-Level Material Cost" := 0;
        Item.Modify();
        Request := RequestFor(Order);
        Request.Add('systemId', Format(Order.SystemId, 0, 4));
        Request.Add('lineNo', 10000);
        Response := Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrderStatistics.Get", Request, 1039, false);
        AssertSuccess(Response);
        Response.SelectToken('variance.percent.total', Token);
        Assert.AreEqual(0, Token.AsValue().AsDecimal(), 'Zero baseline gives zero percentage, never division by zero.');
    end;

    local procedure Refusal(Kind: Enum "Message Type ori"; Request: JsonObject; ExpectedCode: Text)
    var
        Order: Record "Production Order";
        Line: Record "Prod. Order Line";
        Component: Record "Prod. Order Component";
        Entry: Record "Item Ledger Entry";
        ValueEntry: Record "Value Entry";
        Before: array[5] of Integer;
        LanguageId: Integer;
        Response: JsonObject;
    begin
        Before[1] := Order.Count();
        Before[2] := Line.Count();
        Before[3] := Component.Count();
        Before[4] := Entry.Count();
        Before[5] := ValueEntry.Count();
        foreach LanguageId in Languages() do begin
            Response := Data.Invoke(Kind, Request, LanguageId, false);
            Data.AssertRefusal(Response, ExpectedCode);
            Assert.AreEqual(Before[1], Order.Count(), 'Order count unchanged.');
            Assert.AreEqual(Before[2], Line.Count(), 'Line count unchanged.');
            Assert.AreEqual(Before[3], Component.Count(), 'Component count unchanged.');
            Assert.AreEqual(Before[4], Entry.Count(), 'Ledger count unchanged.');
            Assert.AreEqual(Before[5], ValueEntry.Count(), 'Value entry count unchanged.');
        end;
    end;

    local procedure RequestFor(Order: Record "Production Order") Request: JsonObject
    begin
        Request.Add('no', Order."No.");
        if Order.Status = Order.Status::Finished then
            Request.Add('status', 'Finished')
        else
            Request.Add('status', 'Released');
    end;

    local procedure Languages() Result: List of [Integer]
    begin
        Result.Add(1033);
        Result.Add(1039);
    end;

    local procedure Kinds() Result: List of [Enum "Message Type ori"]
    begin
        Result.Add("Message Type ori"::"Manufacturing.ComponentAvailability.Get");
        Result.Add("Message Type ori"::"Manufacturing.ProductionOrderStatistics.Get");
    end;

    local procedure NewPrefix(): Code[10]
    begin
        exit(CopyStr('X26' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, 10));
    end;

    local procedure AssertSuccess(Response: JsonObject)
    var
        Raw: Text;
    begin
        Response.WriteTo(Raw);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), Raw);
    end;

    local procedure FirstComponent(Response: JsonObject): JsonObject
    var
        Token: JsonToken;
        Row: JsonToken;
    begin
        Response.Get('components', Token);
        Token.AsArray().Get(0, Row);
        exit(Row.AsObject());
    end;

    local procedure AssertBlock(Response: JsonObject; Name: Text; Values: array[5] of Decimal)
    var
        Token: JsonToken;
        Block: JsonObject;
    begin
        Response.Get(Name, Token);
        Block := Token.AsObject();
        Assert.AreEqual(Values[1], Data.NumberValue(Block, 'material'), Name + ': material');
        Assert.AreEqual(Values[2], Data.NumberValue(Block, 'capacity'), Name + ': capacity');
        Assert.AreEqual(Values[3], Data.NumberValue(Block, 'subcontracted'), Name + ': subcontracted');
        Assert.AreEqual(Values[4], Data.NumberValue(Block, 'capacityOverhead'), Name + ': capacity overhead');
        Assert.AreEqual(Values[5], Data.NumberValue(Block, 'manufacturingOverhead'), Name + ': manufacturing overhead');
        Assert.AreEqual(Values[1] + Values[2] + Values[3] + Values[4] + Values[5], Data.NumberValue(Block, 'total'), Name + ': total');
    end;
}
