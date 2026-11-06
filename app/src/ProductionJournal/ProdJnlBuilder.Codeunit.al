namespace Origo.Bifrost.Manufacturing;

using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Manufacturing.Document;
using Microsoft.Manufacturing.Journal;
using Microsoft.Manufacturing.Setup;

/// <summary>
/// Builds the production journal of one order with Business Central's own Production Journal Mgt,
/// applies the caller's lines, removes empty lines and describes the result as JSON.
/// Every call that builds lines runs inside a Codeunit.Run boundary and leaves no line behind.
/// </summary>
codeunit 10077076 "Prod Jnl Builder ori"
{
    Access = Internal;

    var
        NotProposedLbl: Label 'Line %1 is not in the production journal proposal of order %2. Only lines that Manufacturing.ProductionJournal.Get proposes can be posted.', Comment = '%1 = line description, %2 = order number, is-IS=Línan %1 er ekki í tillögu framleiðslubókar pöntunar %2. Aðeins línur sem Manufacturing.ProductionJournal.Get leggur til er hægt að bóka.';

    /// <summary>Deletes earlier lines of the order, then creates the proposal with Production Journal Mgt.</summary>
    internal procedure Build(ProductionOrder: Record "Production Order"; LineNo: Integer)
    var
        ProdJnlMgt: Codeunit "Production Journal Mgt";
        Events: Codeunit "Prod Jnl Events ori";
        Template: Code[10];
        Batch: Code[10];
    begin
        ProdJnlMgt.SetTemplateAndBatchName();
        ProdJnlMgt.GetJnlTemplateAndBatchName(Template, Batch);
        Events.SetBatch(Template, Batch);
        ProdJnlMgt.InitSetupValues();
        DeleteLines(ProductionOrder."No.");
        ProdJnlMgt.CreateJnlLines(ProductionOrder, LineNo);
    end;

    /// <summary>Deletes every journal line of the order in the current batch.</summary>
    internal procedure DeleteLines(OrderNo: Code[20])
    var
        ItemJnlLine: Record "Item Journal Line";
    begin
        SetFilters(ItemJnlLine, OrderNo);
        ItemJnlLine.DeleteAll();
    end;

    /// <summary>Sets the batch and order filters on a journal line record.</summary>
    internal procedure SetFilters(var ItemJnlLine: Record "Item Journal Line"; OrderNo: Code[20])
    var
        Events: Codeunit "Prod Jnl Events ori";
        Template: Code[10];
        Batch: Code[10];
    begin
        Events.GetBatch(Template, Batch);
        ItemJnlLine.SetRange("Journal Template Name", Template);
        ItemJnlLine.SetRange("Journal Batch Name", Batch);
        ItemJnlLine.SetRange("Order Type", ItemJnlLine."Order Type"::Production);
        ItemJnlLine.SetRange("Order No.", OrderNo);
    end;

    /// <summary>Removes lines the request does not list, applies the listed values and removes what is empty.</summary>
    internal procedure ApplyLines(OrderNo: Code[20]; Lines: JsonArray)
    var
        ItemJnlLine: Record "Item Journal Line";
        Listed: Dictionary of [Integer, Boolean];
        Line: JsonObject;
        Token: JsonToken;
        Index: Integer;
        Matched: Boolean;
    begin
        SetFilters(ItemJnlLine, OrderNo);
        if ItemJnlLine.FindSet() then
            repeat
                Matched := false;
                for Index := 0 to Lines.Count() - 1 do begin
                    Lines.Get(Index, Token);
                    Line := Token.AsObject();
                    if Matches(ItemJnlLine, Line) then begin
                        ApplyLine(ItemJnlLine, Line);
                        Listed.Set(Index, true);
                        Matched := true;
                    end;
                end;
                if not Matched then
                    ItemJnlLine.Delete();
            until ItemJnlLine.Next() = 0;
        for Index := 0 to Lines.Count() - 1 do
            if not Listed.ContainsKey(Index) then begin
                Lines.Get(Index, Token);
                Line := Token.AsObject();
                Error(NotProposedLbl, DescribeLine(Line), OrderNo);
            end;
    end;

    local procedure Matches(ItemJnlLine: Record "Item Journal Line"; Line: JsonObject): Boolean
    begin
        if TextOf(Line, 'kind') = 'output' then
            exit((ItemJnlLine."Entry Type" = ItemJnlLine."Entry Type"::Output) and
                (ItemJnlLine."Order Line No." = IntOf(Line, 'lineNo')) and
                (ItemJnlLine."Operation No." = CopyStr(TextOf(Line, 'operationNo'), 1, MaxStrLen(ItemJnlLine."Operation No."))));
        exit((ItemJnlLine."Entry Type" = ItemJnlLine."Entry Type"::Consumption) and
            (ItemJnlLine."Order Line No." = IntOf(Line, 'lineNo')) and
            (ItemJnlLine."Prod. Order Comp. Line No." = IntOf(Line, 'componentLineNo')));
    end;

    local procedure ApplyLine(var ItemJnlLine: Record "Item Journal Line"; Line: JsonObject)
    begin
        if TextOf(Line, 'kind') = 'output' then begin
            ItemJnlLine.Validate("Setup Time", DecOf(Line, 'setupTime'));
            ItemJnlLine.Validate("Run Time", DecOf(Line, 'runTime'));
            ItemJnlLine.Validate("Output Quantity", DecOf(Line, 'outputQuantity'));
            ItemJnlLine.Validate("Scrap Quantity", DecOf(Line, 'scrapQuantity'));
            ItemJnlLine.Validate(Finished, BoolOf(Line, 'finished'));
        end else
            ItemJnlLine.Validate(Quantity, DecOf(Line, 'quantity'));
        ItemJnlLine.Modify(true);
    end;

    local procedure DescribeLine(Line: JsonObject): Text
    begin
        if TextOf(Line, 'kind') = 'output' then
            exit('output ' + Format(IntOf(Line, 'lineNo')) + '/' + TextOf(Line, 'operationNo'));
        exit('consumption ' + Format(IntOf(Line, 'lineNo')) + '/' + Format(IntOf(Line, 'componentLineNo')));
    end;

    /// <summary>Deletes lines with no quantity and no time, as the standard posting would skip them.</summary>
    internal procedure DeleteEmptyLines(OrderNo: Code[20])
    var
        ItemJnlLine: Record "Item Journal Line";
    begin
        SetFilters(ItemJnlLine, OrderNo);
        if ItemJnlLine.FindSet() then
            repeat
                if IsEmpty(ItemJnlLine) then
                    ItemJnlLine.Delete();
            until ItemJnlLine.Next() = 0;
    end;

    /// <summary>Removes the output or consumption lines the request did not include.</summary>
    internal procedure DeleteExcluded(OrderNo: Code[20]; IncludeOutput: Boolean; IncludeConsumption: Boolean)
    var
        ItemJnlLine: Record "Item Journal Line";
    begin
        SetFilters(ItemJnlLine, OrderNo);
        if not IncludeOutput then begin
            ItemJnlLine.SetRange("Entry Type", ItemJnlLine."Entry Type"::Output);
            ItemJnlLine.DeleteAll();
        end;
        ItemJnlLine.SetRange("Entry Type");
        if not IncludeConsumption then begin
            ItemJnlLine.SetRange("Entry Type", ItemJnlLine."Entry Type"::Consumption);
            ItemJnlLine.DeleteAll();
        end;
    end;

    /// <summary>Counts the lines that would post.</summary>
    internal procedure CountLines(OrderNo: Code[20]): Integer
    var
        ItemJnlLine: Record "Item Journal Line";
        Total: Integer;
    begin
        SetFilters(ItemJnlLine, OrderNo);
        if ItemJnlLine.FindSet() then
            repeat
                if not IsEmpty(ItemJnlLine) then
                    Total += 1;
            until ItemJnlLine.Next() = 0;
        exit(Total);
    end;

    local procedure IsEmpty(ItemJnlLine: Record "Item Journal Line"): Boolean
    begin
        if ItemJnlLine."Entry Type" = ItemJnlLine."Entry Type"::Output then
            exit((ItemJnlLine."Output Quantity" = 0) and (ItemJnlLine."Scrap Quantity" = 0) and (ItemJnlLine."Setup Time" = 0) and (ItemJnlLine."Run Time" = 0));
        exit(ItemJnlLine.Quantity = 0);
    end;

    /// <summary>Describes the journal lines of the order: outputLines, consumptionLines and proposedLines.</summary>
    internal procedure Describe(ProductionOrder: Record "Production Order"; var Result: JsonObject)
    var
        ItemJnlLine: Record "Item Journal Line";
        OutputLines: JsonArray;
        ConsumptionLines: JsonArray;
        ProposedLines: JsonArray;
    begin
        SetFilters(ItemJnlLine, ProductionOrder."No.");
        ItemJnlLine.SetCurrentKey("Journal Template Name", "Journal Batch Name", "Line No.");
        if ItemJnlLine.FindSet() then
            repeat
                if ItemJnlLine."Entry Type" = ItemJnlLine."Entry Type"::Output then
                    AddOutput(ProductionOrder, ItemJnlLine, OutputLines, ProposedLines)
                else
                    AddConsumption(ProductionOrder, ItemJnlLine, ConsumptionLines, ProposedLines);
            until ItemJnlLine.Next() = 0;
        Result.Add('outputLines', OutputLines);
        Result.Add('consumptionLines', ConsumptionLines);
        Result.Add('proposedLines', ProposedLines);
    end;

    local procedure AddOutput(ProductionOrder: Record "Production Order"; ItemJnlLine: Record "Item Journal Line"; var OutputLines: JsonArray; var ProposedLines: JsonArray)
    var
        ProdOrderLine: Record "Prod. Order Line";
        RoutingLine: Record "Prod. Order Routing Line";
        Output: JsonObject;
        Proposed: JsonObject;
    begin
        ProdOrderLine.Get(ProductionOrder.Status, ProductionOrder."No.", ItemJnlLine."Order Line No.");
        Output.Add('lineNo', ItemJnlLine."Order Line No.");
        Output.Add('itemNo', ItemJnlLine."Item No.");
        Output.Add('operationNo', ItemJnlLine."Operation No.");
        RoutingLine.SetRange(Status, ProductionOrder.Status);
        RoutingLine.SetRange("Prod. Order No.", ProductionOrder."No.");
        RoutingLine.SetRange("Routing Reference No.", ItemJnlLine."Order Line No.");
        RoutingLine.SetRange("Operation No.", ItemJnlLine."Operation No.");
        if RoutingLine.FindFirst() then
            Output.Add('flushingMethod', FlushingName(RoutingLine."Flushing Method"))
        else
            Output.Add('flushingMethod', '');
        Output.Add('expectedQuantity', ProdOrderLine.Quantity);
        Output.Add('finishedQuantity', ProdOrderLine."Finished Quantity");
        Output.Add('remainingQuantity', ProdOrderLine."Remaining Quantity");
        Output.Add('outputQuantity', ItemJnlLine."Output Quantity");
        Output.Add('scrapQuantity', ItemJnlLine."Scrap Quantity");
        Output.Add('setupTime', ItemJnlLine."Setup Time");
        Output.Add('runTime', ItemJnlLine."Run Time");
        Output.Add('finished', ItemJnlLine.Finished);
        OutputLines.Add(Output);
        Proposed.Add('kind', 'output');
        Proposed.Add('lineNo', ItemJnlLine."Order Line No.");
        Proposed.Add('operationNo', ItemJnlLine."Operation No.");
        Proposed.Add('outputQuantity', ItemJnlLine."Output Quantity");
        Proposed.Add('scrapQuantity', ItemJnlLine."Scrap Quantity");
        Proposed.Add('setupTime', ItemJnlLine."Setup Time");
        Proposed.Add('runTime', ItemJnlLine."Run Time");
        Proposed.Add('finished', ItemJnlLine.Finished);
        ProposedLines.Add(Proposed);
    end;

    local procedure AddConsumption(ProductionOrder: Record "Production Order"; ItemJnlLine: Record "Item Journal Line"; var ConsumptionLines: JsonArray; var ProposedLines: JsonArray)
    var
        Component: Record "Prod. Order Component";
        Consumption: JsonObject;
        Proposed: JsonObject;
    begin
        Component.Get(ProductionOrder.Status, ProductionOrder."No.", ItemJnlLine."Order Line No.", ItemJnlLine."Prod. Order Comp. Line No.");
        Consumption.Add('lineNo', ItemJnlLine."Order Line No.");
        Consumption.Add('componentLineNo', ItemJnlLine."Prod. Order Comp. Line No.");
        Consumption.Add('itemNo', ItemJnlLine."Item No.");
        Consumption.Add('expectedQuantity', Component."Expected Quantity");
        Consumption.Add('remainingQuantity', Component."Remaining Quantity");
        Consumption.Add('quantity', ItemJnlLine.Quantity);
        Consumption.Add('flushingMethod', FlushingName(Component."Flushing Method"));
        Consumption.Add('locationCode', ItemJnlLine."Location Code");
        Consumption.Add('binCode', ItemJnlLine."Bin Code");
        Consumption.Add('quantityPicked', Component."Qty. Picked");
        ConsumptionLines.Add(Consumption);
        Proposed.Add('kind', 'consumption');
        Proposed.Add('lineNo', ItemJnlLine."Order Line No.");
        Proposed.Add('componentLineNo', ItemJnlLine."Prod. Order Comp. Line No.");
        Proposed.Add('quantity', ItemJnlLine.Quantity);
        ProposedLines.Add(Proposed);
    end;

    local procedure FlushingName(Method: Enum "Flushing Method"): Text
    begin
        if Method.AsInteger() = 0 then
            exit('Manual');
        case Method of
            Method::Forward:
                exit('Forward');
            Method::Backward:
                exit('Backward');
            Method::"Pick + Forward":
                exit('PickForward');
            Method::"Pick + Backward":
                exit('PickBackward');
            Method::"Pick + Manual":
                exit('PickManual');
        end;
        exit(Format(Method, 0, 9));
    end;

    local procedure TextOf(Line: JsonObject; KeyName: Text): Text
    var
        Token: JsonToken;
    begin
        if Line.Get(KeyName, Token) then
            if Token.IsValue() then
                exit(Token.AsValue().AsText());
        exit('');
    end;

    local procedure IntOf(Line: JsonObject; KeyName: Text): Integer
    var
        Token: JsonToken;
    begin
        if Line.Get(KeyName, Token) then
            if Token.IsValue() then
                exit(Token.AsValue().AsInteger());
        exit(0);
    end;

    local procedure DecOf(Line: JsonObject; KeyName: Text): Decimal
    var
        Token: JsonToken;
    begin
        if Line.Get(KeyName, Token) then
            if Token.IsValue() then
                exit(Token.AsValue().AsDecimal());
        exit(0);
    end;

    local procedure BoolOf(Line: JsonObject; KeyName: Text): Boolean
    var
        Token: JsonToken;
    begin
        if Line.Get(KeyName, Token) then
            if Token.IsValue() then
                exit(Token.AsValue().AsBoolean());
        exit(false);
    end;
}
