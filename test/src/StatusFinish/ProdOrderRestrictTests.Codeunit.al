namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Inventory.Item;
using Microsoft.Manufacturing.Document;
using System.TestLibraries.Utilities;

/// <summary>Story #6 AC14: generic writes of the status fields are refused with a hint; other fields stay writable.</summary>
codeunit 97625 "Prod Order Restrict Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Data: Codeunit "Mfg Test Data ori";
        Lib: Codeunit "Mfg Status Test Lib ori";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure Scenario_AC14_StatusFields_RefusedWithHint_DueDateWritable()
    var
        Item: Record Item;
        Order: Record "Production Order";
        Response: JsonObject;
        FieldName: Text;
        Names: List of [Text];
        NewDueDate: Date;
    begin
        Lib.PrepareOrder(Item, Order, Order.Status::Planned);
        Commit();
        Names.Add('Status');
        Names.Add('FinishedDate');
        Names.Add('Reopened');
        foreach FieldName in Names do begin
            Response := Lib.SetOrderField(Order.SystemId, FieldName, FieldValue(FieldName));
            Assert.AreEqual('Error', Data.TextValue(Response, 'status'), 'Generic write of ' + FieldName + ' is refused.');
            Assert.IsTrue(Lib.ResponseContains(Response, 'Manufacturing.ProductionOrder.ChangeStatus'), 'The hint names ChangeStatus for ' + FieldName);
            Assert.IsTrue(Lib.ResponseContains(Response, 'Manufacturing.ProductionOrder.Finish'), 'The hint names Finish for ' + FieldName);
        end;
        Order.Get(Order.Status, Order."No.");
        Assert.AreEqual(Order.Status::Planned, Order.Status, 'Status unchanged.');
        NewDueDate := CalcDate('<+7D>', Order."Due Date");
        Response := Lib.SetOrderField(Order.SystemId, 'DueDate', Format(NewDueDate, 0, 9));
        Assert.AreEqual('Success', Data.TextValue(Response, 'status'), 'Due Date stays writable.');
        Assert.AreEqual('Success', Data.TextValue(Lib.GetOrders(), 'status'), 'Reads stay allowed.');
        Lib.Cleanup(Item."No.");
    end;

    local procedure FieldValue(FieldName: Text): Text
    begin
        case FieldName of
            'Status':
                exit('Released');
            'FinishedDate':
                exit(Format(WorkDate(), 0, 9));
        end;
        exit('true');
    end;
}
