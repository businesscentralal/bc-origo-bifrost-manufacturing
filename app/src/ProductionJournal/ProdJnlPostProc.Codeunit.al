namespace Origo.Bifrost.Manufacturing;

using Microsoft.Finance.GeneralLedger.Preview;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Posting;
using Microsoft.Manufacturing.Capacity;
using Microsoft.Manufacturing.Document;
using Origo.Bifrost;

/// <summary>
/// The Codeunit.Run boundary of the production journal types. Get and PreviewPost always end in an error
/// that rolls the journal lines back; Post commits only when Business Central's posting succeeded.
/// </summary>
codeunit 10077075 "Prod Jnl Post Proc ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";
    EventSubscriberInstance = Manual;

    trigger OnRun()
    var
        ProductionOrder: Record "Production Order";
        Builder: Codeunit "Prod Jnl Builder ori";
        Events: Codeunit "Prod Jnl Events ori";
        Lines: JsonArray;
        CountResult: JsonObject;
        OrderNo: Code[20];
        Mode: Integer;
        LineNo: Integer;
        IncludeOutput: Boolean;
        IncludeConsumption: Boolean;
        HasLines: Boolean;
    begin
        Events.GetRequest(Mode, OrderNo, LineNo, IncludeOutput, IncludeConsumption, HasLines, Lines);
        ProductionOrder.Get(ProductionOrder.Status::Released, OrderNo);
        Builder.Build(ProductionOrder, LineNo);
        Builder.DeleteExcluded(OrderNo, IncludeOutput, IncludeConsumption);
        if HasLines then
            Builder.ApplyLines(OrderNo, Lines);
        Events.SetInBoundary(true);
        case Mode of
            0:
                begin
                    GetProposal(ProductionOrder);
                    Error('');
                end;
            1:
                begin
                    Builder.DeleteEmptyLines(OrderNo);
                    PreviewLines(OrderNo);
                    Error('');
                end;
            2:
                PostLines(Rec, ProductionOrder);
            3:
                begin
                    Builder.DeleteEmptyLines(OrderNo);
                    CountResult.Add('count', Builder.CountLines(OrderNo));
                    Events.SetResult(CountResult);
                    Error('');
                end;
        end;
    end;

    local procedure GetProposal(ProductionOrder: Record "Production Order")
    var
        Builder: Codeunit "Prod Jnl Builder ori";
        Lookup: Codeunit "Mfg Prod Order Lookup ori";
        Events: Codeunit "Prod Jnl Events ori";
        Result: JsonObject;
        PostingDate: Date;
        Basis: Integer;
    begin
        Events.GetUsedSetup(PostingDate, Basis);
        Result.Add('no', ProductionOrder."No.");
        Result.Add('productionOrderStatus', Lookup.StatusName(ProductionOrder.Status));
        Result.Add('postingDate', Format(PostingDate, 0, 9));
        Result.Add('consumptionBasis', BasisName(Basis));
        Builder.Describe(ProductionOrder, Result);
        Events.SetResult(Result);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Gen. Jnl.-Post Preview", OnRunPreview, '', false, false)]
    local procedure RunPreview(var Result: Boolean; Subscriber: Variant; RecVar: Variant)
    var
        TempArgument: Record "Message Argument ori";
        Process: Codeunit "Prod Jnl Post Proc ori";
    begin
        TempArgument := RecVar;
        Process := Subscriber;
        Result := Process.Run(TempArgument);
    end;

    local procedure PreviewLines(OrderNo: Code[20])
    var
        ItemJnlLine: Record "Item Journal Line";
        Builder: Codeunit "Prod Jnl Builder ori";
        Events: Codeunit "Prod Jnl Events ori";
        ItemJnlPost: Codeunit "Item Jnl.-Post";
        LinesToPost: Integer;
    begin
        LinesToPost := Builder.CountLines(OrderNo);
        if LinesToPost = 0 then begin
            Events.SetNothingToPost();
            exit;
        end;
        Events.SetPreviewLines(LinesToPost);
        Builder.SetFilters(ItemJnlLine, OrderNo);
        ItemJnlLine.FindFirst();
        // The standard preview engine has already bound its entry handler. Item Jnl.-Post
        // enables sequence preview mode and raises the standard preview rollback error.
        ItemJnlPost.SetPreviewMode(true);
        ItemJnlPost.Run(ItemJnlLine);
    end;

    local procedure PostLines(var Argument: Record "Message Argument ori"; ProductionOrder: Record "Production Order")
    var
        ItemJnlLine: Record "Item Journal Line";
        ItemRegister: Record "Item Register";
        ProdOrderLine: Record "Prod. Order Line";
        Builder: Codeunit "Prod Jnl Builder ori";
        Events: Codeunit "Prod Jnl Events ori";
        ConfirmGate: Codeunit "Confirm Gate ori";
        Lookup: Codeunit "Mfg Prod Order Lookup ori";
        Result: JsonObject;
        Lines: JsonArray;
        OrderLine: JsonObject;
        FinishedBefore: Dictionary of [Integer, Decimal];
        PostedLines: Integer;
        RegisterBefore: Integer;
        LedgerBefore: Integer;
        CapacityBefore: Integer;
        ScrapPosted: Decimal;
        PostingDate: Date;
        Basis: Integer;
    begin
        Builder.DeleteEmptyLines(ProductionOrder."No.");
        PostedLines := Builder.CountLines(ProductionOrder."No.");
        if PostedLines = 0 then begin
            Builder.DeleteLines(ProductionOrder."No.");
            Events.SetNothingToPost();
            exit;
        end;
        if not ConfirmGate.Check(Argument, Argument.Type) then begin
            Builder.DeleteLines(ProductionOrder."No.");
            exit;
        end;
        ScrapPosted := ScrapOf(ProductionOrder."No.", Builder);
        ProdOrderLine.SetRange(Status, ProductionOrder.Status);
        ProdOrderLine.SetRange("Prod. Order No.", ProductionOrder."No.");
        if ProdOrderLine.FindSet() then
            repeat
                FinishedBefore.Add(ProdOrderLine."Line No.", ProdOrderLine."Finished Quantity");
            until ProdOrderLine.Next() = 0;
        if ItemRegister.FindLast() then
            RegisterBefore := ItemRegister."No.";
        LedgerBefore := LastLedgerEntry();
        CapacityBefore := LastCapacityEntry();
        Builder.SetFilters(ItemJnlLine, ProductionOrder."No.");
        ItemJnlLine.FindFirst();
        // Called without a Boolean return so that a posting error rolls back the lines built in this call.
        Codeunit.Run(Codeunit::"Item Jnl.-Post Batch", ItemJnlLine);
        Events.GetUsedSetup(PostingDate, Basis);
        Result.Add('no', ProductionOrder."No.");
        Result.Add('productionOrderStatus', Lookup.StatusName(ProductionOrder.Status));
        Result.Add('postingDate', Format(PostingDate, 0, 9));
        Result.Add('postedLines', PostedLines);
        AddCounts(Result, ProductionOrder."No.", RegisterBefore, LedgerBefore, CapacityBefore, ScrapPosted);
        ProdOrderLine.Reset();
        ProdOrderLine.SetRange(Status, ProductionOrder.Status);
        ProdOrderLine.SetRange("Prod. Order No.", ProductionOrder."No.");
        if ProdOrderLine.FindSet() then
            repeat
                Clear(OrderLine);
                OrderLine.Add('lineNo', ProdOrderLine."Line No.");
                OrderLine.Add('quantity', ProdOrderLine."Finished Quantity" - FinishedBefore.Get(ProdOrderLine."Line No."));
                OrderLine.Add('finishedQuantity', ProdOrderLine."Finished Quantity");
                OrderLine.Add('remainingQuantity', ProdOrderLine."Remaining Quantity");
                Lines.Add(OrderLine);
            until ProdOrderLine.Next() = 0;
        Result.Add('lines', Lines);
        Events.SetResult(Result);
    end;

    local procedure AddCounts(var Result: JsonObject; OrderNo: Code[20]; RegisterBefore: Integer; LedgerBefore: Integer; CapacityBefore: Integer; ScrapPosted: Decimal)
    var
        ItemRegister: Record "Item Register";
        LedgerEntry: Record "Item Ledger Entry";
        CapacityEntry: Record "Capacity Ledger Entry";
        OutputPosted: Decimal;
        ConsumptionLines: Integer;
    begin
        LedgerEntry.SetRange("Order Type", LedgerEntry."Order Type"::Production);
        LedgerEntry.SetRange("Order No.", OrderNo);
        LedgerEntry.SetFilter("Entry No.", '>%1', LedgerBefore);
        if LedgerEntry.FindSet() then
            repeat
                if LedgerEntry."Entry Type" = LedgerEntry."Entry Type"::Output then
                    OutputPosted += LedgerEntry.Quantity;
                if LedgerEntry."Entry Type" = LedgerEntry."Entry Type"::Consumption then
                    ConsumptionLines += 1;
            until LedgerEntry.Next() = 0;
        CapacityEntry.SetRange("Order Type", CapacityEntry."Order Type"::Production);
        CapacityEntry.SetRange("Order No.", OrderNo);
        CapacityEntry.SetFilter("Entry No.", '>%1', CapacityBefore);
        Result.Add('outputQuantityPosted', OutputPosted);
        Result.Add('scrapQuantityPosted', ScrapPosted);
        Result.Add('consumptionLinesPosted', ConsumptionLines);
        Result.Add('capacityEntriesPosted', CapacityEntry.Count());
        ItemRegister.SetFilter("No.", '>%1', RegisterBefore);
        if ItemRegister.FindLast() then begin
            Result.Add('itemRegisterNo', ItemRegister."No.");
            Result.Add('itemRegisterId', Format(ItemRegister.SystemId, 0, 4));
            Result.Add('fromEntryNo', ItemRegister."From Entry No.");
            Result.Add('toEntryNo', ItemRegister."To Entry No.");
        end;
    end;

    local procedure ScrapOf(OrderNo: Code[20]; Builder: Codeunit "Prod Jnl Builder ori") Scrap: Decimal
    var
        ItemJnlLine: Record "Item Journal Line";
    begin
        Builder.SetFilters(ItemJnlLine, OrderNo);
        ItemJnlLine.SetRange("Entry Type", ItemJnlLine."Entry Type"::Output);
        if ItemJnlLine.FindSet() then
            repeat
                Scrap += ItemJnlLine."Scrap Quantity";
            until ItemJnlLine.Next() = 0;
    end;

    local procedure LastLedgerEntry(): Integer
    var
        LedgerEntry: Record "Item Ledger Entry";
    begin
        if LedgerEntry.FindLast() then
            exit(LedgerEntry."Entry No.");
    end;

    local procedure LastCapacityEntry(): Integer
    var
        CapacityEntry: Record "Capacity Ledger Entry";
    begin
        if CapacityEntry.FindLast() then
            exit(CapacityEntry."Entry No.");
    end;

    /// <summary>Maps the consumption basis option to its invariant name.</summary>
    internal procedure BasisName(Basis: Integer): Text
    begin
        if Basis = 1 then
            exit('ExpectedOutput');
        exit('ActualOutput');
    end;
}
