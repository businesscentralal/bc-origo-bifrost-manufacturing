namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Microsoft.Manufacturing.Document;
using Microsoft.Manufacturing.ProductionBOM;
using Microsoft.Manufacturing.Routing;
using Microsoft.Manufacturing.Setup;
using Microsoft.Manufacturing.WorkCenter;
using System.TestLibraries.Utilities;

/// <summary>Owned MCP fixtures for the Finish/Post amendment paths: an item without routing and an item whose component has an unmatched routing link. Seeded and removed through native BC validation, without touching consent or write guards.</summary>
codeunit 97618 "Mfg MCP Amend Fixture Tst ori"
{
    var
        Assert: Codeunit "Library Assert";
        NoRoutingItemNoTok: Label 'X-M6-MCP-NR', Locked = true;
        LinkItemNoTok: Label 'X-M6-MCP-LK', Locked = true;
        LinkCodeTok: Label 'X-M6LK', Locked = true;

    trigger OnRun()
    begin
        Seed();
    end;

    /// <summary>Creates X-M6-MCP-NR (certified BOM, backward component, no routing) and X-M6-MCP-LK (routing operation 10 and backward component BOM line both carry routing link X-M6LK).</summary>
    procedure Seed()
    var
        Item: Record Item;
        Bom: Record "Production BOM Header";
        BomLine: Record "Production BOM Line";
        RoutingLink: Record "Routing Link";
        Data: Codeunit "Mfg Test Data ori";
        JournalLib: Codeunit "Prod Jnl Test Lib ori";
        Manufacturing: Codeunit "Library - Manufacturing";
        RoutingNo: Code[20];
    begin
        if Item.Get(NoRoutingItemNoTok) or Item.Get(LinkItemNoTok) then
            Error('Owned amendment fixtures already exist. Run the cleanup action first.');
        JournalLib.FillPostingAccounts();
        Data.SetupNumbering(true);

        Data.CreateManufacturedItem(Item);
        RoutingNo := Item."Routing No.";
        Item.Validate("Routing No.", '');
        Item.Modify(true);
        DeleteRouting(RoutingNo);
        Item.Rename(NoRoutingItemNoTok);
        SetComponentsBackward(Item."Production BOM No.");

        Data.CreateManufacturedItem(Item);
        Item.Rename(LinkItemNoTok);
        SetComponentsBackward(Item."Production BOM No.");
        RoutingLink.Init();
        RoutingLink.Code := LinkCodeTok;
        RoutingLink.Insert(true);
        // BC certifies a BOM, and Refresh calculates components, only when the BOM line link matches an operation of the routing.
        // The mismatch is therefore made on the released order afterwards: clear the link of its production order routing line in the Web Client.
        SetOperationLink(Item."Routing No.", RoutingLink.Code);
        Bom.Get(Item."Production BOM No.");
        Manufacturing.UpdateProductionBOMStatus(Bom, Bom.Status::"Under Development");
        BomLine.SetRange("Production BOM No.", Bom."No.");
        BomLine.SetRange(Type, BomLine.Type::Item);
        BomLine.FindFirst();
        BomLine.Validate("Routing Link Code", RoutingLink.Code);
        BomLine.Modify(true);
        Manufacturing.UpdateProductionBOMStatus(Bom, Bom.Status::Certified);
        Commit();
    end;

    /// <summary>Removes the two owned items with their orders, BOMs, routings, work centers, component items and routing link. An item that already has posted ledger entries (BC cannot delete it) is blocked and renamed instead; asserts that no fixture key remains.</summary>
    procedure Cleanup()
    var
        Data: Codeunit "Mfg Test Data ori";
        ItemNo: Text;
    begin
        foreach ItemNo in ListOf() do
            if ItemExists(CopyStr(ItemNo, 1, 20)) then begin
                Data.CleanupOrders(CopyStr(ItemNo, 1, 20));
                DeleteFinishedOrderChildren(CopyStr(ItemNo, 1, 20));
                if HasLedgerEntries(CopyStr(ItemNo, 1, 20)) then
                    RetireItem(CopyStr(ItemNo, 1, 20))
                else
                    DeleteItemTree(CopyStr(ItemNo, 1, 20));
            end;
        DeleteLink();
        Commit();
        Assert.IsFalse(ItemExists(NoRoutingItemNoTok), 'No-routing fixture item removed.');
        Assert.IsFalse(ItemExists(LinkItemNoTok), 'Routing-link fixture item removed.');
    end;

    local procedure SetOperationLink(RoutingNo: Code[20]; LinkCode: Code[10])
    var
        Routing: Record "Routing Header";
        RoutingLine: Record "Routing Line";
        Manufacturing: Codeunit "Library - Manufacturing";
    begin
        Routing.Get(RoutingNo);
        Manufacturing.UpdateRoutingStatus(Routing, Routing.Status::"Under Development");
        RoutingLine.SetRange("Routing No.", RoutingNo);
        RoutingLine.FindFirst();
        RoutingLine.Validate("Routing Link Code", LinkCode);
        RoutingLine.Modify(true);
        Manufacturing.UpdateRoutingStatus(Routing, Routing.Status::Certified);
    end;

    /// <summary>Finished orders are deleted without cascade by the shared helper; remove their lines, routing and components so the work center and items are free.</summary>
    local procedure DeleteFinishedOrderChildren(ItemNo: Code[20])
    var
        ProdOrderLine: Record "Prod. Order Line";
        ProdOrderRoutingLine: Record "Prod. Order Routing Line";
        ProdOrderComponent: Record "Prod. Order Component";
    begin
        ProdOrderLine.SetRange("Item No.", ItemNo);
        if ProdOrderLine.FindSet() then
            repeat
                ProdOrderRoutingLine.SetRange(Status, ProdOrderLine.Status);
                ProdOrderRoutingLine.SetRange("Prod. Order No.", ProdOrderLine."Prod. Order No.");
                ProdOrderRoutingLine.DeleteAll(false);
                ProdOrderComponent.SetRange(Status, ProdOrderLine.Status);
                ProdOrderComponent.SetRange("Prod. Order No.", ProdOrderLine."Prod. Order No.");
                ProdOrderComponent.DeleteAll(false);
            until ProdOrderLine.Next() = 0;
        ProdOrderLine.DeleteAll(false);
    end;

    /// <summary>Posted output cannot be deleted in Business Central: block the item and free the fixture key for the next seed.</summary>
    local procedure RetireItem(ItemNo: Code[20])
    var
        Item: Record Item;
    begin
        Item.Get(ItemNo);
        Item.Validate(Blocked, true);
        Item.Modify(true);
        Item.Rename(CopyStr('X-OLD-' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, MaxStrLen(Item."No.")));
    end;

    local procedure HasLedgerEntries(ItemNo: Code[20]): Boolean
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
    begin
        ItemLedgerEntry.SetRange("Item No.", ItemNo);
        exit(not ItemLedgerEntry.IsEmpty());
    end;

    local procedure ListOf() Result: List of [Text]
    begin
        Result.Add(NoRoutingItemNoTok);
        Result.Add(LinkItemNoTok);
    end;

    local procedure ItemExists(No: Code[20]): Boolean
    var
        Item: Record Item;
    begin
        exit(Item.Get(No));
    end;

    local procedure SetComponentsBackward(BomNo: Code[20])
    var
        BomLine: Record "Production BOM Line";
        ComponentItem: Record Item;
    begin
        BomLine.SetRange("Production BOM No.", BomNo);
        BomLine.SetRange(Type, BomLine.Type::Item);
        BomLine.FindSet();
        repeat
            ComponentItem.Get(BomLine."No.");
            ComponentItem.Validate("Flushing Method", ComponentItem."Flushing Method"::Backward);
            ComponentItem.Modify(true);
        until BomLine.Next() = 0;
    end;

    local procedure DeleteItemTree(ItemNo: Code[20])
    var
        Item: Record Item;
        Bom: Record "Production BOM Header";
        BomLine: Record "Production BOM Line";
        ComponentItem: Record Item;
        Manufacturing: Codeunit "Library - Manufacturing";
        Components: List of [Code[20]];
        ComponentNo: Code[20];
        BomNo: Code[20];
        RoutingNo: Code[20];
    begin
        Item.Get(ItemNo);
        BomNo := Item."Production BOM No.";
        RoutingNo := Item."Routing No.";
        Item.Validate("Production BOM No.", '');
        Item.Validate("Routing No.", '');
        Item.Modify(true);
        Item.Delete(true);

        if BomNo <> '' then begin
            BomLine.SetRange("Production BOM No.", BomNo);
            BomLine.SetRange(Type, BomLine.Type::Item);
            if BomLine.FindSet() then
                repeat
                    Components.Add(BomLine."No.");
                until BomLine.Next() = 0;
            if Bom.Get(BomNo) then begin
                if Bom.Status = Bom.Status::Certified then
                    Manufacturing.UpdateProductionBOMStatus(Bom, Bom.Status::"Under Development");
                Bom.Delete(true);
            end;
        end;
        DeleteRouting(RoutingNo);
        foreach ComponentNo in Components do
            if ComponentItem.Get(ComponentNo) then
                ComponentItem.Delete(true);
    end;

    local procedure DeleteRouting(RoutingNo: Code[20])
    var
        Routing: Record "Routing Header";
        RoutingLine: Record "Routing Line";
        Center: Record "Work Center";
        Manufacturing: Codeunit "Library - Manufacturing";
        Centers: List of [Code[20]];
        CenterNo: Code[20];
    begin
        if RoutingNo = '' then
            exit;
        if not Routing.Get(RoutingNo) then
            exit;
        if Routing.Status = Routing.Status::Certified then
            Manufacturing.UpdateRoutingStatus(Routing, Routing.Status::"Under Development");
        RoutingLine.SetRange("Routing No.", RoutingNo);
        if RoutingLine.FindSet() then
            repeat
                if not Centers.Contains(RoutingLine."No.") then
                    Centers.Add(RoutingLine."No.");
            until RoutingLine.Next() = 0;
        Routing.Delete(true);
        foreach CenterNo in Centers do
            if Center.Get(CenterNo) then
                Center.Delete(true);
    end;

    local procedure DeleteLink()
    var
        RoutingLink: Record "Routing Link";
    begin
        if RoutingLink.Get(LinkCodeTok) then
            RoutingLink.Delete(true);
    end;
}
