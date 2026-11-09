namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Finance.GeneralLedger.Ledger;
using Microsoft.Foundation.NoSeries;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Manufacturing.Capacity;
using Microsoft.Manufacturing.Document;
using Microsoft.Manufacturing.Routing;
using Microsoft.Manufacturing.Journal;
using Microsoft.Manufacturing.ProductionBOM;
using Microsoft.Manufacturing.Setup;
using Microsoft.Manufacturing.WorkCenter;
using Origo.Bifrost;
using System.TestLibraries.Security.AccessControl;
using System.TestLibraries.Utilities;

/// <summary>Story #7 AC03 (parity with Production Journal Mgt), AC13 (preview entry count), AC14 (posting token) and AC18 (Icelandic texts per type).</summary>
codeunit 97648 "Prod Jnl Gap Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Data: Codeunit "Mfg Test Data ori";
        Lib: Codeunit "Prod Jnl Test Lib ori";
        StatusLib: Codeunit "Mfg Status Test Lib ori";
        Assert: Codeunit "Library Assert";
        LowerPermissions: Codeunit "Library - Lower Permissions";

    [Test]
    procedure Scenario_AC18_FinishedBooleans_AreAcceptedInBothLanguages()
    var
        Item: Record Item;
        Order: Record "Production Order";
        Extra: JsonObject;
        Response: JsonObject;
        FinishedToken: JsonToken;
        LanguageId: Integer;
        LanguageIndex: Integer;
        ValueIndex: Integer;
    begin
        Lib.PrepareReleased(Item, Order);
        StatusLib.SetConfirmRequired(true);
        Commit();
        for LanguageIndex := 1 to 2 do begin
            LanguageId := 1033;
            if LanguageIndex = 2 then
                LanguageId := 1039;
            for ValueIndex := 0 to 1 do begin
                if ValueIndex = 0 then
                    FinishedToken.ReadFrom('false')
                else
                    FinishedToken.ReadFrom('true');
                Extra := OutputWithFinished(FinishedToken);
                Response := Lib.Call("Message Type ori"::"Manufacturing.ProductionJournal.PreviewPost", Order, Extra, LanguageId);
                Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'JSON true and false preview in both languages.');
                Response := Lib.Call("Message Type ori"::"Manufacturing.ProductionJournal.Post", Order, Extra, LanguageId);
                Data.AssertRefusal(Response, 'ConfirmationRequired');
                Assert.AreEqual(0, Lib.JournalLines(Order."No."), 'Preview and confirmation refusal leave no journal lines.');
                Assert.AreEqual(0, Lib.Entries(Order."No.", "Item Ledger Entry Type"::Output), 'Confirmation refusal posts no output.');
            end;
        end;
        Lib.Cleanup(Item."No.");
    end;

    [Test]
    procedure Scenario_AC10_AC18_FinishedRejectsNonBooleanJsonWithoutPosting()
    var
        Item: Record Item;
        Order: Record "Production Order";
        Extra: JsonObject;
        Response: JsonObject;
        FinishedToken: JsonToken;
        RawValues: List of [Text];
        Raw: Text;
    begin
        Lib.PrepareReleased(Item, Order);
        RawValues.Add('0');
        RawValues.Add('1');
        RawValues.Add('"true"');
        RawValues.Add('null');
        RawValues.Add('{}');
        RawValues.Add('[]');
        foreach Raw in RawValues do begin
            FinishedToken.ReadFrom(Raw);
            Extra := OutputWithFinished(FinishedToken);
            Response := Lib.Call("Message Type ori"::"Manufacturing.ProductionJournal.PreviewPost", Order, Extra, 1039);
            Data.AssertRefusal(Response, 'InvalidParameterFormat');
            Assert.AreEqual('lines[0].finished', Data.TextValue(Response, 'parameter'), 'The boolean refusal names the line field.');
            Assert.IsTrue(StatusLib.ResponseContains(Response, 'rökgildi'), 'The refusal is translated and names a boolean.');
            Response := Lib.Call("Message Type ori"::"Manufacturing.ProductionJournal.Post", Order, Extra, 1039);
            Data.AssertRefusal(Response, 'InvalidParameterFormat');
            Assert.AreEqual(0, Lib.JournalLines(Order."No."), 'Invalid values leave no journal lines.');
            Assert.AreEqual(0, Lib.Entries(Order."No.", "Item Ledger Entry Type"::Output), 'Invalid values post no output.');
        end;
        Lib.Cleanup(Item."No.");
    end;

    local procedure OutputWithFinished(FinishedToken: JsonToken): JsonObject
    var
        Extra: JsonObject;
        Line: JsonObject;
        Lines: JsonArray;
    begin
        Line.Add('kind', 'output');
        Line.Add('lineNo', 10000);
        Line.Add('operationNo', '10');
        Line.Add('outputQuantity', 5);
        Line.Add('finished', FinishedToken);
        Lines.Add(Line);
        Extra.Add('lines', Lines);
        exit(Extra);
    end;

    [Test]
    procedure Scenario_AC03_Parity_Manual_Backward_PickManual_RoutingLink()
    var
        Item: Record Item;
        Order: Record "Production Order";
        Manual: Enum "Flushing Method";
    begin
        Evaluate(Manual, 'Manual');
        Lib.PrepareReleased(Item, Order);
        AssertParity(Order, Manual, false);
        AssertParity(Order, "Flushing Method"::Backward, false);
        AssertParity(Order, "Flushing Method"::"Pick + Manual", false);
        AssertParity(Order, Manual, true);
        Lib.Cleanup(Item."No.");
    end;

    [Test]
    procedure Scenario_AC13_Preview_EntryCount_Equals_Post()
    var
        Item: Record Item;
        Order: Record "Production Order";
        SequenceNoMgt: Codeunit "Sequence No. Mgt.";
        Extra: JsonObject;
        PreviewResponse: JsonObject;
        PostResponse: JsonObject;
        PreviewCount: Decimal;
        ActualCount: Integer;
        ItemSequenceBefore: Integer;
        GLSequenceBefore: Integer;
    begin
        Lib.PrepareReleased(Item, Order);
        StatusLib.SetConfirmRequired(false);
        Commit();
        SequenceNoMgt.ValidateSeqNo(Database::"Item Ledger Entry");
        SequenceNoMgt.ValidateSeqNo(Database::"G/L Entry");
        ItemSequenceBefore := SequenceNoMgt.GetCurrentSeqNo(Database::"Item Ledger Entry");
        GLSequenceBefore := SequenceNoMgt.GetCurrentSeqNo(Database::"G/L Entry");
        Commit();
        Extra.Add('consumptionBasis', 'ExpectedOutput');
        PreviewResponse := Lib.Call("Message Type ori"::"Manufacturing.ProductionJournal.PreviewPost", Order, Extra, 1033);
        Assert.AreEqual('Success', Data.TextValue(PreviewResponse, 'status'), 'Preview succeeds.');
        Assert.AreEqual(ItemSequenceBefore, SequenceNoMgt.GetCurrentSeqNo(Database::"Item Ledger Entry"), 'Preview must not consume the next Item Ledger entry number.');
        Assert.AreEqual(GLSequenceBefore, SequenceNoMgt.GetCurrentSeqNo(Database::"G/L Entry"), 'Preview must not consume the next G/L entry number.');
        PreviewCount := Data.NumberValue(PreviewResponse, 'entryCount');
        Assert.IsTrue(PreviewCount > 0, 'Preview reports entries.');
        Assert.IsTrue(Data.NumberValue(PreviewResponse, 'glEntryCount') > 0, 'The fixture must exercise G/L posting and sequence protection.');
        Assert.AreEqual(0, Lib.JournalLines(Order."No."), 'Preview leaves no journal line.');
        PostResponse := Lib.Call("Message Type ori"::"Manufacturing.ProductionJournal.Post", Order, Extra, 1033);
        Assert.AreEqual('Success', Data.TextValue(PostResponse, 'status'), 'Post succeeds.');
        ActualCount := PostedEntryCount(Order."No.");
        Assert.AreEqual(ActualCount, PreviewCount, 'Preview entryCount equals the entries Post created.');
        Lib.Cleanup(Item."No.");
    end;

    [Test]
    procedure Scenario_AC14_WithoutPostingToken_PostHiddenDenied_ReadTypesAvailable()
    var
        Item: Record Item;
        Order: Record "Production Order";
        Discovery: Interface "Msg Interface ori";
        PostEnabled: Boolean;
        GetEnabled: Boolean;
        PreviewEnabled: Boolean;
        Extra: JsonObject;
        PostResponse: JsonObject;
        GetResponse: JsonObject;
        PreviewResponse: JsonObject;
        ResponseText: Text;
    begin
        Lib.PrepareReleased(Item, Order);
        StatusLib.SetConfirmRequired(false);
        Commit();
        LowerPermissions.SetExactPermissionSet('BIFROST Full ori');
        AddNativePermissions();
        Discovery := "Message Type ori"::"Manufacturing.ProductionJournal.Post";
        PostEnabled := Discovery.IsEnabled();
        Discovery := "Message Type ori"::"Manufacturing.ProductionJournal.Get";
        GetEnabled := Discovery.IsEnabled();
        Discovery := "Message Type ori"::"Manufacturing.ProductionJournal.PreviewPost";
        PreviewEnabled := Discovery.IsEnabled();
        PostResponse := Lib.Call("Message Type ori"::"Manufacturing.ProductionJournal.Post", Order, Extra, 1033);
        GetResponse := Lib.Call("Message Type ori"::"Manufacturing.ProductionJournal.Get", Order, Extra, 1033);
        PreviewResponse := Lib.Call("Message Type ori"::"Manufacturing.ProductionJournal.PreviewPost", Order, Extra, 1033);
        LowerPermissions.SetOutsideO365Scope();

        Assert.IsFalse(PostEnabled, 'Post is hidden without BIFROST MfgPost ori.');
        Assert.IsTrue(GetEnabled, 'Get stays listed.');
        Assert.IsTrue(PreviewEnabled, 'PreviewPost stays listed.');
        PostResponse.WriteTo(ResponseText);
        Assert.AreEqual('Error', Data.TextValue(PostResponse, 'status'), 'Direct Post is refused: ' + ResponseText);
        Assert.IsTrue(ResponseText.Contains('PermissionDenied'), 'PermissionDenied: ' + ResponseText);
        Assert.IsTrue(ResponseText.Contains('BIFROST MfgPost ori'), 'Refusal names the set: ' + ResponseText);
        Assert.AreEqual('Success', Data.TextValue(GetResponse, 'status'), 'Get works without the token.');
        PreviewResponse.WriteTo(ResponseText);
        Assert.AreEqual('Success', Data.TextValue(PreviewResponse, 'status'), 'PreviewPost works without the token: ' + ResponseText);
        Assert.AreEqual(0, Lib.Entries(Order."No.", "Item Ledger Entry Type"::Output), 'The denied Post posted nothing.');
        Lib.Cleanup(Item."No.");
    end;

    [Test]
    procedure Scenario_AC18_Refusals_AnswerInIcelandic_PerType()
    var
        Item: Record Item;
        Order: Record "Production Order";
        Extra: JsonObject;
        Response: JsonObject;
    begin
        StatusLib.PrepareOrder(Item, Order, Order.Status::"Firm Planned");
        Response := Lib.Call("Message Type ori"::"Manufacturing.ProductionJournal.PreviewPost", Order, Extra, 1039);
        Data.AssertRefusal(Response, 'PreconditionFailed');
        Assert.IsTrue(StatusLib.ResponseContains(Response, 'Framleiðslubók er aðeins til fyrir útgefna pöntun.'), 'PreviewPost Icelandic refusal text.');
        Response := Lib.Call("Message Type ori"::"Manufacturing.ProductionJournal.Post", Order, Extra, 1039);
        Data.AssertRefusal(Response, 'PreconditionFailed');
        Assert.IsTrue(StatusLib.ResponseContains(Response, 'Framleiðslubók er aðeins til fyrir útgefna pöntun.'), 'Post Icelandic refusal text.');
        Lib.Cleanup(Item."No.");
    end;

    local procedure AssertParity(Order: Record "Production Order"; Method: Enum "Flushing Method"; WithRoutingLink: Boolean)
    var
        Component: Record "Prod. Order Component";
        RoutingLine: Record "Prod. Order Routing Line";
        RoutingLink: Record "Routing Link";
        JnlLine: Record "Item Journal Line";
        Mgt: Codeunit "Production Journal Mgt";
        Extra: JsonObject;
        Response: JsonObject;
        Template: Code[10];
        Batch: Code[10];
        GetConsumption: Decimal;
        GetOutput: Decimal;
        BcConsumption: Decimal;
        BcOutput: Decimal;
        Context: Text;
    begin
        Context := Format(Method) + ' routingLink=' + Format(WithRoutingLink);
        Component.SetRange(Status, Order.Status);
        Component.SetRange("Prod. Order No.", Order."No.");
        Component.FindFirst();
        Component."Flushing Method" := Method;
        if WithRoutingLink then begin
            if not RoutingLink.Get('MFG7RL') then begin
                RoutingLink.Code := 'MFG7RL';
                RoutingLink.Insert();
            end;
            RoutingLine.SetRange(Status, Order.Status);
            RoutingLine.SetRange("Prod. Order No.", Order."No.");
            RoutingLine.FindFirst();
            RoutingLine."Routing Link Code" := RoutingLink.Code;
            RoutingLine.Modify();
            Component."Routing Link Code" := RoutingLink.Code;
        end;
        Component.Modify();
        Commit();

        Extra.Add('consumptionBasis', 'ExpectedOutput');
        Response := Lib.Call("Message Type ori"::"Manufacturing.ProductionJournal.Get", Order, Extra, 1033);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Get succeeds: ' + Context);
        GetConsumption := SumArray(StatusLib.ArrayValue(Response, 'consumptionLines'), 'quantity');
        GetOutput := SumArray(StatusLib.ArrayValue(Response, 'outputLines'), 'outputQuantity');

        Mgt.SetTemplateAndBatchName();
        Mgt.GetJnlTemplateAndBatchName(Template, Batch);
        Mgt.InitSetupValues();
        JnlLine.SetRange("Journal Template Name", Template);
        JnlLine.SetRange("Journal Batch Name", Batch);
        JnlLine.SetRange("Order Type", JnlLine."Order Type"::Production);
        JnlLine.SetRange("Order No.", Order."No.");
        JnlLine.DeleteAll();
        Mgt.CreateJnlLines(Order, 0);
        if JnlLine.FindSet() then
            repeat
                if JnlLine."Entry Type" = JnlLine."Entry Type"::Consumption then
                    BcConsumption += JnlLine.Quantity
                else
                    BcOutput += JnlLine."Output Quantity";
            until JnlLine.Next() = 0;
        JnlLine.DeleteAll();
        Commit();

        Assert.AreEqual(BcConsumption, GetConsumption, 'Consumption quantity equals Production Journal Mgt: ' + Context);
        Assert.AreEqual(BcOutput, GetOutput, 'Output quantity equals Production Journal Mgt: ' + Context);
    end;

    local procedure SumArray(Lines: JsonArray; KeyName: Text): Decimal
    var
        Token: JsonToken;
        ValueToken: JsonToken;
        Total: Decimal;
    begin
        foreach Token in Lines do
            if Token.AsObject().Get(KeyName, ValueToken) then
                Total += ValueToken.AsValue().AsDecimal();
        exit(Total);
    end;

    local procedure PostedEntryCount(OrderNo: Code[20]): Integer
    var
        ItemEntry: Record "Item Ledger Entry";
        ValueEntry: Record "Value Entry";
        CapacityEntry: Record "Capacity Ledger Entry";
        GLEntry: Record "G/L Entry";
    begin
        ItemEntry.SetRange("Order Type", ItemEntry."Order Type"::Production);
        ItemEntry.SetRange("Order No.", OrderNo);
        ValueEntry.SetRange("Order Type", ValueEntry."Order Type"::Production);
        ValueEntry.SetRange("Order No.", OrderNo);
        CapacityEntry.SetRange("Order Type", CapacityEntry."Order Type"::Production);
        CapacityEntry.SetRange("Order No.", OrderNo);
        GLEntry.SetRange("Document No.", OrderNo);
        exit(ItemEntry.Count() + ValueEntry.Count() + CapacityEntry.Count() + GLEntry.Count());
    end;

    local procedure AddNativePermissions()
    begin
        LowerPermissions.AddPermissionSet('D365 BASIC');
        LowerPermissions.AddPermissionSet('D365PREM MFG, EDIT');
        LowerPermissions.AddPermissionSet('D365 JOURNALS, EDIT');
        LowerPermissions.AddPermissionSet('D365 BUS FULL ACCESS');
        LowerPermissions.AddPermissionSet('Mfg NoPost Tst ori');
    end;
}
