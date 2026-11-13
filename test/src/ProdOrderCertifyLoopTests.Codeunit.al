namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Inventory.Item;
using Microsoft.Manufacturing.Document;
using Microsoft.Manufacturing.ProductionBOM;
using Microsoft.Manufacturing.Routing;
using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Story #8 AC13: the certification loop. A Planned order whose BOM and routing are Under Development cannot be refreshed;
/// both SetStatus types certify them; Refresh then succeeds. Everything goes through the public dispatcher.
/// </summary>
codeunit 97680 "Prod Order Certify Loop ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Data: Codeunit "Mfg Test Data ori";
        Lib: Codeunit "BOM Routing Test Lib ori";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Scenario_AC13_RefreshRefusesThenSucceedsAfterCertify_1033()
    begin
        RunLoop(1033);
    end;

    [Test]
    procedure Scenario_AC13_RefreshRefusesThenSucceedsAfterCertify_1039()
    begin
        RunLoop(1039);
    end;

    [Test]
    procedure Scenario_AC13_RoutingOnlyUnderDevelopment_RefreshRefuses()
    var
        Item: Record Item;
        Order: Record "Production Order";
        Routing: Record "Routing Header";
        Line: Record "Prod. Order Line";
    begin
        // Edge: the BOM stays certified, only the routing is Under Development: Refresh still refuses and leaves no line.
        Prepare(Item, Order);
        Routing.Get(Item."Routing No.");
        Routing.Validate(Status, Routing.Status::"Under Development");
        Routing.Modify(true);
        Commit();

        Data.AssertRefusal(Refresh(Order, 1033), 'BusinessCentralError');

        Line.SetRange(Status, Order.Status);
        Line.SetRange("Prod. Order No.", Order."No.");
        Assert.IsTrue(Line.IsEmpty(), 'A refused refresh leaves no line.');
        Data.CleanupOrders(Item."No.");
    end;

    local procedure RunLoop(LanguageId: Integer)
    var
        Item: Record Item;
        Order: Record "Production Order";
        Bom: Record "Production BOM Header";
        Routing: Record "Routing Header";
        Line: Record "Prod. Order Line";
        Response: JsonObject;
        PreviousLanguage: Integer;
    begin
        Prepare(Item, Order);
        Bom.Get(Item."Production BOM No.");
        Bom.Validate(Status, Bom.Status::"Under Development");
        Bom.Modify(true);
        Routing.Get(Item."Routing No.");
        Routing.Validate(Status, Routing.Status::"Under Development");
        Routing.Modify(true);
        Commit();

        // [WHEN] Refresh runs while BOM and routing are Under Development, then it is refused and nothing is calculated
        Data.AssertRefusal(Refresh(Order, LanguageId), 'BusinessCentralError');
        Line.SetRange(Status, Order.Status);
        Line.SetRange("Prod. Order No.", Order."No.");
        Assert.IsTrue(Line.IsEmpty(), 'The refused refresh leaves no line.');

        // [WHEN] Both are certified through the SetStatus message types
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);
        Response := Lib.SetBomStatus(Bom."No.", '', 'Certified', false);
        Lib.AssertSuccess(Response);
        Response := Lib.SetRoutingStatus(Routing."No.", '', 'Certified', false);
        Lib.AssertSuccess(Response);
        GlobalLanguage(PreviousLanguage);
        Bom.Get(Bom."No.");
        Routing.Get(Routing."No.");
        Assert.AreEqual(Bom.Status::Certified, Bom.Status, 'BOM certified.');
        Assert.AreEqual(Routing.Status::Certified, Routing.Status, 'Routing certified.');
        Commit();

        // [THEN] Refresh succeeds and calculates lines, routing and components
        Response := Refresh(Order, LanguageId);
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Refresh succeeds after certification.');
        Assert.AreEqual(1, Line.Count(), 'The manufactured-item line is created.');
        Assert.IsTrue(Data.NumberValue(Response, 'routingLineCount') > 0, 'Routing rows are calculated.');
        Assert.IsTrue(Data.NumberValue(Response, 'componentCount') > 0, 'Component rows are calculated.');
        Data.CleanupOrders(Item."No.");
    end;

    local procedure Prepare(var Item: Record Item; var Order: Record "Production Order")
    begin
        Data.SetupNumbering(false);
        Data.CreateManufacturedItem(Item);
        Data.CreateOrder(Order, Item, Order.Status::Planned);
    end;

    local procedure Refresh(Order: Record "Production Order"; LanguageId: Integer): JsonObject
    var
        Request: JsonObject;
    begin
        Request.Add('systemId', Format(Order.SystemId, 0, 4));
        Request.Add('direction', 'Backward');
        Request.Add('calculateLines', true);
        Request.Add('calculateRoutings', true);
        Request.Add('calculateComponents', true);
        exit(Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Refresh", Request, LanguageId, false));
    end;
}
