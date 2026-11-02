namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Foundation.NoSeries;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Planning;
using Microsoft.Manufacturing.Document;
using Microsoft.Manufacturing.Setup;
using Origo.Bifrost;
using System.TestLibraries.Security.AccessControl;
using System.TestLibraries.Utilities;

/// <summary>Exercises the public dispatcher against self-created production orders and verifies resulting records.</summary>
codeunit 97614 "Mfg Lifecycle Tst ori"
{
    Subtype = Test;
    TestPermissions = Restrictive;

    var
        Assert: Codeunit "Library Assert";
        Lib: Codeunit "BOM Routing Test Lib ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";

    /// <summary>Refresh must create an actual production line, not merely return Success.</summary>
    [Test]
    procedure Refresh_CreatesProductionLine()
    var
        Order: Record "Production Order";
        Line: Record "Prod. Order Line";
        Request: JsonObject;
        Response: JsonObject;
        OrderNo: Code[20];
    begin
        OrderNo := NewNo();
        CreateOrder(Order, OrderNo);
        Commit();
        Request.Add('productionOrderNo', OrderNo);
        Response := Lib.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Refresh", Request, false);
        Lib.AssertSuccess(Response);
        Line.SetRange(Status, Order.Status);
        Line.SetRange("Prod. Order No.", OrderNo);
        Assert.AreEqual(1, Line.Count(), 'Refresh created one line for the self-created item.');
        Line.FindFirst();
        Assert.AreEqual(Order."Source No.", Line."Item No.", 'Refreshed item identity.');
        Assert.AreEqual(2, Line.Quantity, 'Refreshed quantity.');
        Cleanup(OrderNo);
    end;

    /// <summary>Full plus standard business permissions succeeds without SUPER and moves the fetched order.</summary>
    [Test]
    procedure ChangeStatus_FullRole_MovesActualOrder()
    var
        Order: Record "Production Order";
        Setup: Record "Manufacturing Setup";
        SavedSetup: Record "Manufacturing Setup";
        Series: Record "No. Series";
        Request: JsonObject;
        Response: JsonObject;
        OrderNo: Code[20];
    begin
        OrderNo := NewNo();
        CreateOrder(Order, OrderNo);
        Setup.Get();
        SavedSetup := Setup;
        Series.Code := OrderNo;
        Series."Manual Nos." := true;
        Series.Insert(false);
        Setup."Firm Planned Order Nos." := Series.Code;
        Setup."Released Order Nos." := Series.Code;
        Setup.Modify(false);
        Commit();
        Request.Add('productionOrderNo', OrderNo);
        Request.Add('newStatus', 'Released');
        LowerPermissions.SetOutsideO365Scope();
        LowerPermissions.SetExactPermissionSet('D365 BUS PREMIUM');
        LowerPermissions.AddPermissionSet('BIFROST Full ori');
        Response := Lib.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.ChangeStatus", Request, false);
        LowerPermissions.SetOutsideO365Scope();
        Setup.Get();
        Setup."Firm Planned Order Nos." := SavedSetup."Firm Planned Order Nos.";
        Setup."Released Order Nos." := SavedSetup."Released Order Nos.";
        Setup.Modify(false);
        Series.Delete(false);
        Commit();
        Lib.AssertSuccess(Response);
        Assert.AreEqual(OrderNo, Lib.GetText(Response, 'productionOrderNo'), 'Response identifies resulting order.');
        Assert.IsFalse(Order.Get(Order.Status::"Firm Planned", OrderNo), 'Original composite key removed.');
        Assert.IsTrue(Order.Get(Order.Status::Released, OrderNo), 'Loaded order moved to Released.');
        Cleanup(OrderNo);
    end;

    /// <summary>Replanning and cost calculation preserve the selected item and quantity.</summary>
    [Test]
    procedure ReplanAndCost_ExistingOrder_Succeed()
    var
        Order: Record "Production Order";
        Line: Record "Prod. Order Line";
        Request: JsonObject;
        Response: JsonObject;
        OrderNo: Code[20];
    begin
        OrderNo := NewNo();
        CreateOrder(Order, OrderNo);
        Commit();
        Request.Add('productionOrderNo', OrderNo);
        Lib.AssertSuccess(Lib.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Refresh", Request, false));
        Response := Lib.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Replan", Request, false);
        Lib.AssertSuccess(Response);
        Response := Lib.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.UpdateCost", Request, false);
        Lib.AssertSuccess(Response);
        Line.SetRange(Status, Order.Status);
        Line.SetRange("Prod. Order No.", OrderNo);
        Assert.AreEqual(1, Line.Count(), 'Replan and cost retain the selected line.');
        Line.FindFirst();
        Assert.AreEqual(2, Line.Quantity, 'Quantity is retained.');
        Cleanup(OrderNo);
    end;

    local procedure NewNo(): Code[20]
    begin
        exit(CopyStr('XM11' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, 20));
    end;

    local procedure CreateOrder(var Order: Record "Production Order"; OrderNo: Code[20])
    begin
        Lib.CreateItem(OrderNo, '', '');
        Order.Init();
        Order.Status := Order.Status::"Firm Planned";
        Order."No." := OrderNo;
        Order.Insert(false);
        Order.SetHideValidationDialog(true);
        Order.Validate("Source Type", Order."Source Type"::Item);
        Order.Validate("Source No.", OrderNo);
        Order.Validate(Quantity, 2);
        Order.Validate("Due Date", WorkDate());
        Order.Modify(true);
    end;

    local procedure Cleanup(OrderNo: Code[20])
    var
        Order: Record "Production Order";
        Line: Record "Prod. Order Line";
        Component: Record "Prod. Order Component";
        RoutingLine: Record "Prod. Order Routing Line";
        Item: Record Item;
        ItemUom: Record "Item Unit of Measure";
        PlanningAssignment: Record "Planning Assignment";
    begin
        Component.SetRange("Prod. Order No.", OrderNo);
        Component.DeleteAll(false);
        RoutingLine.SetRange("Prod. Order No.", OrderNo);
        RoutingLine.DeleteAll(false);
        Line.SetRange("Prod. Order No.", OrderNo);
        Line.DeleteAll(false);
        Order.SetRange("No.", OrderNo);
        Order.DeleteAll(false);
        ItemUom.SetRange("Item No.", OrderNo);
        ItemUom.DeleteAll(false);
        PlanningAssignment.SetRange("Item No.", OrderNo);
        PlanningAssignment.DeleteAll(false);
        Item.Get(OrderNo);
        Item.Delete(false);
        Assert.IsTrue(Order.IsEmpty() and Line.IsEmpty() and Component.IsEmpty() and RoutingLine.IsEmpty() and ItemUom.IsEmpty() and PlanningAssignment.IsEmpty(), 'Owned lifecycle fixture cleanup.');
        Commit();
    end;
}
