namespace Origo.Bifrost.Manufacturing.Test;

using Microsoft.Inventory.Item;
using Microsoft.Manufacturing.Document;
using Origo.Bifrost;
using System.Diagnostics;
using System.TestLibraries.Utilities;

/// <summary>Shared helpers for the status change, finish and finish check tests.</summary>
codeunit 97629 "Mfg Status Test Lib ori"
{
    var
        Data: Codeunit "Mfg Test Data ori";
        Assert: Codeunit "Library Assert";

    /// <summary>Creates an owned manufactured item and a refreshed order in the given status.</summary>
    procedure PrepareOrder(var Item: Record Item; var Order: Record "Production Order"; Status: Enum "Production Order Status")
    begin
        Data.SetupNumbering(false);
        Data.CreateManufacturedItem(Item);
        Data.CreateOrder(Order, Item, Status);
    end;

    /// <summary>Sets the company's Require Irreversible Confirm setting (Foundation Setup field 36).</summary>
    procedure SetConfirmRequired(Required: Boolean)
    var
        Setup: RecordRef;
        RequiredField: FieldRef;
    begin
        Setup.Open(Database::"Setup ori");
        if not Setup.FindFirst() then begin
            Setup.Init();
            Setup.Insert();
        end;
        RequiredField := Setup.Field(36);
        RequiredField.Value := Required;
        Setup.Modify();
        Setup.Close();
    end;

    /// <summary>Builds an identity request by SystemId.</summary>
    procedure IdRequest(Order: Record "Production Order"): JsonObject
    var
        Request: JsonObject;
    begin
        Request.Add('systemId', Format(Order.SystemId, 0, 4));
        exit(Request);
    end;

    /// <summary>Calls ChangeStatus by SystemId.</summary>
    procedure ChangeStatus(Order: Record "Production Order"; NewStatus: Text; ExpectedCount: Integer; LanguageId: Integer): JsonObject
    var
        Request: JsonObject;
    begin
        Request := IdRequest(Order);
        Request.Add('newStatus', NewStatus);
        if ExpectedCount >= 0 then
            Request.Add('expectedCount', ExpectedCount);
        exit(Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.ChangeStatus", Request, LanguageId, false));
    end;

    /// <summary>Calls Finish with a prepared request.</summary>
    procedure Finish(Request: JsonObject; LanguageId: Integer): JsonObject
    begin
        exit(Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Finish", Request, LanguageId, false));
    end;

    /// <summary>Calls CheckFinish by SystemId.</summary>
    procedure CheckFinish(Order: Record "Production Order"; LanguageId: Integer): JsonObject
    begin
        exit(Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.CheckFinish", IdRequest(Order), LanguageId, false));
    end;

    /// <summary>Reads the order after a status change by its new SystemId.</summary>
    procedure ReadBack(Response: JsonObject; var Order: Record "Production Order")
    var
        Id: Guid;
    begin
        Evaluate(Id, Data.TextValue(Response, 'systemId'));
        Assert.IsTrue(Order.GetBySystemId(Id), 'The new SystemId identifies the order.');
    end;

    /// <summary>Counts rows of the order's children in its status.</summary>
    procedure CountChildren(Order: Record "Production Order"; var Lines: Integer; var Routings: Integer; var Components: Integer)
    var
        Line: Record "Prod. Order Line";
        Routing: Record "Prod. Order Routing Line";
        Component: Record "Prod. Order Component";
    begin
        Line.SetRange(Status, Order.Status);
        Line.SetRange("Prod. Order No.", Order."No.");
        Lines := Line.Count();
        Routing.SetRange(Status, Order.Status);
        Routing.SetRange("Prod. Order No.", Order."No.");
        Routings := Routing.Count();
        Component.SetRange(Status, Order.Status);
        Component.SetRange("Prod. Order No.", Order."No.");
        Components := Component.Count();
    end;

    /// <summary>Returns the response's first-level array.</summary>
    procedure ArrayValue(Response: JsonObject; Name: Text): JsonArray
    var
        Token: JsonToken;
    begin
        Assert.IsTrue(Response.Get(Name, Token), 'Missing response key: ' + Name);
        exit(Token.AsArray());
    end;

    /// <summary>Returns true when a response text contains the value anywhere.</summary>
    procedure ResponseContains(Response: JsonObject; Value: Text): Boolean
    var
        ResponseText: Text;
    begin
        Response.WriteTo(ResponseText);
        exit(ResponseText.Contains(Value));
    end;

    /// <summary>Deletes the owned orders of every status for the item.</summary>
    procedure Cleanup(ItemNo: Code[20])
    var
        Order: Record "Production Order";
        Line: Record "Prod. Order Line";
        Routing: Record "Prod. Order Routing Line";
        Component: Record "Prod. Order Component";
    begin
        Order.SetRange("Source Type", Order."Source Type"::Item);
        Order.SetRange("Source No.", ItemNo);
        if Order.FindSet() then
            repeat
                Line.SetRange(Status, Order.Status);
                Line.SetRange("Prod. Order No.", Order."No.");
                Line.DeleteAll(false);
                Routing.SetRange(Status, Order.Status);
                Routing.SetRange("Prod. Order No.", Order."No.");
                Routing.DeleteAll(false);
                Component.SetRange(Status, Order.Status);
                Component.SetRange("Prod. Order No.", Order."No.");
                Component.DeleteAll(false);
            until Order.Next() = 0;
        Order.DeleteAll(false);
        Commit();
    end;

    /// <summary>Writes one Production Order field through Data.Records.Set, with the change log the generic write requires.</summary>
    procedure SetOrderField(SystemId: Guid; FieldName: Text; FieldValue: Text) Response: JsonObject
    var
        ChangeLogSetup: Record "Change Log Setup";
        PreviousSetup: Record "Change Log Setup";
        ChangeLogTable: Record "Change Log Setup (Table)";
        PreviousTable: Record "Change Log Setup (Table)";
        Request: JsonObject;
        RecordJson: JsonObject;
        FieldsJson: JsonObject;
        DataJson: JsonArray;
        HadSetup: Boolean;
        HadTable: Boolean;
    begin
        HadSetup := ChangeLogSetup.Get();
        PreviousSetup := ChangeLogSetup;
        if not HadSetup then
            ChangeLogSetup.Insert();
        ChangeLogSetup."Change Log Activated" := true;
        ChangeLogSetup.Modify();
        HadTable := ChangeLogTable.Get(Database::"Production Order");
        PreviousTable := ChangeLogTable;
        if not HadTable then begin
            ChangeLogTable.Init();
            ChangeLogTable."Table No." := Database::"Production Order";
            ChangeLogTable.Insert();
        end;
        ChangeLogTable."Log Modification" := ChangeLogTable."Log Modification"::"All Fields";
        ChangeLogTable.Modify();
        FieldsJson.Add(FieldName, FieldValue);
        RecordJson.Add('id', Format(SystemId, 0, 4));
        RecordJson.Add('fields', FieldsJson);
        DataJson.Add(RecordJson);
        Request.Add('tableName', 'Production Order');
        Request.Add('data', DataJson);
        Response := Data.Invoke("Message Type ori"::"Data.Records.Set", Request, GlobalLanguage(), true);
        if HadTable then begin
            ChangeLogTable := PreviousTable;
            ChangeLogTable.Modify();
        end else
            ChangeLogTable.Delete();
        if HadSetup then begin
            ChangeLogSetup := PreviousSetup;
            ChangeLogSetup.Modify();
        end else
            ChangeLogSetup.Delete();
    end;

    /// <summary>Reads one Production Order page through Data.Records.Get.</summary>
    procedure GetOrders() Response: JsonObject
    var
        Request: JsonObject;
    begin
        Request.Add('tableName', 'Production Order');
        Request.Add('take', 1);
        Response := Data.Invoke("Message Type ori"::"Data.Records.Get", Request, GlobalLanguage(), true);
    end;
}
