namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Manufacturing.Document;
using Origo.Bifrost;
using System.TestLibraries.Security.AccessControl;
using System.TestLibraries.Utilities;

/// <summary>Regression coverage for production action identity, validation, permissions and transaction refusals.</summary>
codeunit 97613 "Mfg Action Guard Tst ori"
{
    Subtype = Test;
    TestPermissions = Restrictive;

    var
        Assert: Codeunit "Library Assert";
        Lib: Codeunit "BOM Routing Test Lib ori";
        LowerPermissions: Codeunit "Library - Lower Permissions";

    /// <summary>Never selects an arbitrary active order when the number is ambiguous.</summary>
    [Test]
    procedure ChangeStatus_AmbiguousNumber_Refused()
    var
        Order: Record "Production Order";
        Request: JsonObject;
        Response: JsonObject;
        OrderNo: Code[20];
    begin
        OrderNo := NewNo();
        CreateOrder(Order, OrderNo, Order.Status::Planned);
        CreateOrder(Order, OrderNo, Order.Status::Released);
        Commit();
        Request.Add('productionOrderNo', OrderNo);
        Request.Add('newStatus', 'Firm Planned');
        Response := Lib.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.ChangeStatus", Request, true);
        Assert.IsTrue(Order.Get(Order.Status::Planned, OrderNo), 'Planned source retained.');
        Assert.IsTrue(Order.Get(Order.Status::Released, OrderNo), 'Released source retained.');
        DeleteOrders(OrderNo);
        Lib.AssertRefusal(Response, 'PreconditionFailed', 'productionOrderNo');
    end;

    /// <summary>A finished order is never selected for refresh.</summary>
    [Test]
    procedure Refresh_FinishedOnly_NotFound()
    var
        Order: Record "Production Order";
        Request: JsonObject;
        Response: JsonObject;
        OrderNo: Code[20];
    begin
        OrderNo := NewNo();
        CreateOrder(Order, OrderNo, Order.Status::Finished);
        Commit();
        Request.Add('productionOrderNo', OrderNo);
        Response := Lib.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Refresh", Request, true);
        Assert.IsTrue(Order.Get(Order.Status::Finished, OrderNo), 'Finished order retained.');
        DeleteOrders(OrderNo);
        Lib.AssertRefusal(Response, 'RecordNotFound', 'productionOrderNo');
    end;

    /// <summary>All four report/status actions refuse Omit Commit on an existing active target.</summary>
    [Test]
    procedure ProductionActions_OmitCommit_NoMutation()
    var
        Order: Record "Production Order";
        Request: JsonObject;
        Response: JsonObject;
        OrderNo: Code[20];
        Ordinal: Integer;
    begin
        OrderNo := NewNo();
        CreateOrder(Order, OrderNo, Order.Status::"Firm Planned");
        Commit();
        for Ordinal := 10077040 to 10077043 do begin
            Clear(Request);
            Request.Add('productionOrderNo', OrderNo);
            if Ordinal = 10077042 then
                Request.Add('newStatus', 'Released');
            Response := Lib.Invoke("Message Type ori".FromInteger(Ordinal), Request, true);
            Lib.AssertRefusal(Response, 'PreconditionFailed', 'omitCommit');
            Assert.IsTrue(Order.Get(Order.Status::"Firm Planned", OrderNo), 'Source must remain at original status.');
        end;
        DeleteOrders(OrderNo);
    end;

    /// <summary>Rejects invalid JSON values and length overflow with stable codes.</summary>
    [Test]
    procedure ProductionActions_InvalidTypes_Refused()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        Request.Add('productionOrderNo', 123);
        Response := Lib.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Refresh", Request, true);
        Lib.AssertRefusal(Response, 'InvalidParameterFormat', 'productionOrderNo');
        Request.Replace('productionOrderNo', 'X123456789012345678901');
        Response := Lib.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Refresh", Request, true);
        Lib.AssertRefusal(Response, 'InvalidParameterFormat', 'productionOrderNo');
        Request.Replace('productionOrderNo', 'XMFG11-MISSING');
        Request.Add('multipleLevels', 'true');
        Response := Lib.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.UpdateCost", Request, true);
        Lib.AssertRefusal(Response, 'InvalidParameterFormat', 'multipleLevels');
    end;

    /// <summary>Unknown keys cannot silently change a write request.</summary>
    [Test]
    procedure Actions_UnknownKey_Refused()
    var
        Request: JsonObject;
        Response: JsonObject;
        Ordinal: Integer;
    begin
        Request.Add('unexpected', true);
        for Ordinal := 10077040 to 10077047 do begin
            Response := Lib.Invoke("Message Type ori".FromInteger(Ordinal), Request, true);
            Lib.AssertRefusal(Response, 'UnknownParameter', 'unexpected');
        end;
        for Ordinal := 10077057 to 10077058 do begin
            Response := Lib.Invoke("Message Type ori".FromInteger(Ordinal), Request, true);
            Lib.AssertRefusal(Response, 'UnknownParameter', 'unexpected');
        end;
    end;

    /// <summary>A purchase ledger entry cannot be reversed by a production operation.</summary>
    [Test]
    procedure Reverse_NonProductionEntry_Refused()
    var
        Entry: Record "Item Ledger Entry";
        Request: JsonObject;
        Response: JsonObject;
    begin
        Entry.LockTable();
        if Entry.FindLast() then;
        Entry."Entry No." += 1;
        Entry.Init();
        Entry."Entry Type" := Entry."Entry Type"::Purchase;
        Entry."Document No." := NewNo();
        Entry.Insert(false);
        Commit();
        Request.Add('ledgerType', 'Item');
        Request.Add('entryNo', Entry."Entry No.");
        Response := Lib.Invoke("Message Type ori"::"Manufacturing.Journal.ReversePosting", Request, true);
        Assert.IsTrue(Entry.Get(Entry."Entry No."), 'Entry retained.');
        Assert.IsFalse(Entry.Correction, 'Entry not reversed.');
        Entry.Delete(false);
        Commit();
        Lib.AssertRefusal(Response, 'PreconditionFailed', 'entryNo');
    end;

    /// <summary>A previously corrected production entry cannot be reversed twice.</summary>
    [Test]
    procedure Reverse_CorrectedProductionEntry_Refused()
    var
        Entry: Record "Item Ledger Entry";
        Request: JsonObject;
        Response: JsonObject;
    begin
        Entry.LockTable();
        if Entry.FindLast() then;
        Entry."Entry No." += 1;
        Entry.Init();
        Entry."Entry Type" := Entry."Entry Type"::Output;
        Entry."Order Type" := Entry."Order Type"::Production;
        Entry."Order No." := NewNo();
        Entry.Correction := true;
        Entry.Insert(false);
        Commit();
        Request.Add('ledgerType', 'Item');
        Request.Add('entryNo', Entry."Entry No.");
        Response := Lib.Invoke("Message Type ori"::"Manufacturing.Journal.ReversePosting", Request, true);
        Entry.Delete(false);
        Commit();
        Lib.AssertRefusal(Response, 'PreconditionFailed', 'entryNo');
    end;

    /// <summary>The journal handler rechecks that a template belongs to manufacturing.</summary>
    [Test]
    procedure Journal_NonProductionTemplate_Refused()
    var
        JournalTemplate: Record "Item Journal Template";
        Request: JsonObject;
        Response: JsonObject;
        Ordinal: Integer;
    begin
        JournalTemplate.Name := CopyStr(NewNo(), 1, MaxStrLen(JournalTemplate.Name));
        JournalTemplate.Type := JournalTemplate.Type::Item;
        JournalTemplate.Insert(false);
        Commit();
        Request.Add('journalTemplateName', JournalTemplate.Name);
        Request.Add('journalBatchName', 'XNO-BATCH');
        for Ordinal := 10077044 to 10077045 do begin
            Response := Lib.Invoke("Message Type ori".FromInteger(Ordinal), Request, true);
            Lib.AssertRefusal(Response, 'PreconditionFailed', 'journalTemplateName');
        end;
        JournalTemplate.Delete(false);
        Commit();
    end;

    /// <summary>Full Bifrost access does not elevate the caller's manufacturing table permissions.</summary>
    [Test]
    procedure FullRole_WithoutProductionTables_Refused()
    var
        Request: JsonObject;
        Response: JsonObject;
    begin
        Request.Add('productionOrderNo', 'XMFG11-MISSING');
        LowerPermissions.SetOutsideO365Scope();
        LowerPermissions.SetExactPermissionSet('BIFROST Full ori');
        Response := Lib.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Refresh", Request, true);
        LowerPermissions.SetOutsideO365Scope();
        Lib.AssertRefusal(Response, 'PermissionDenied', 'permission');
    end;

    /// <summary>The Read role has no execute permission for any new write implementation.</summary>
    [Test]
    procedure ReadRole_CannotRunProductionActions()
    var
        Request: JsonObject;
        Response: JsonObject;
        ErrorText: Text;
        Ordinal: Integer;
    begin
        for Ordinal := 10077040 to 10077047 do begin
            LowerPermissions.SetOutsideO365Scope();
            LowerPermissions.SetExactPermissionSet('BIFROST Read ori');
            asserterror Response := Lib.Invoke("Message Type ori".FromInteger(Ordinal), Request, false);
            ErrorText := LowerCase(GetLastErrorText());
            LowerPermissions.SetOutsideO365Scope();
            Assert.IsTrue(ErrorText.Contains('permission') or ErrorText.Contains('heimild'), ErrorText);
        end;
    end;

    local procedure NewNo(): Code[20]
    begin
        exit(CopyStr('XM11' + DelChr(Format(CreateGuid(), 0, 4), '=', '{}-'), 1, 20));
    end;

    local procedure CreateOrder(var Order: Record "Production Order"; OrderNo: Code[20]; Status: Enum "Production Order Status")
    begin
        Clear(Order);
        Order.Status := Status;
        Order."No." := OrderNo;
        Order.Description := OrderNo;
        Order.Insert(false);
    end;

    local procedure DeleteOrders(OrderNo: Code[20])
    var
        Order: Record "Production Order";
    begin
        Order.SetRange("No.", OrderNo);
        Order.DeleteAll(false);
        Assert.IsTrue(Order.IsEmpty(), 'No owned order fixture remains.');
        Commit();
    end;
}
