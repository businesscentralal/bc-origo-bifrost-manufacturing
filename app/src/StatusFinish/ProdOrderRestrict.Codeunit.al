namespace Origo.Bifrost.Manufacturing;

using Microsoft.Manufacturing.Document;
using Origo.Bifrost;

/// <summary>
/// Refuses a generic Data.Records.Set of Status, Finished Date or Reopened on a production order.
/// Those fields only change through the standard status management in the dedicated types.
/// Other production order fields stay writable.
/// </summary>
codeunit 10077062 "Prod Order Restrict ori"
{
    Access = Internal;
    InherentPermissions = X;
    InherentEntitlements = X;

    var
        HintLbl: Label 'Use Manufacturing.ProductionOrder.ChangeStatus / Manufacturing.ProductionOrder.Finish', Comment = 'is-IS=Notaðu Manufacturing.ProductionOrder.ChangeStatus / Manufacturing.ProductionOrder.Finish';

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnAfterIsFieldWriteRestrictedForDataRecords, '', false, false)]
    local procedure RestrictStatusFields(TableNo: Integer; FieldNo: Integer; Force: Boolean; var IsRestricted: Boolean)
    begin
        if IsRestrictedField(TableNo, FieldNo) then
            IsRestricted := true;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnGetDedicatedMessageTypeHintForField, '', false, false)]
    local procedure HintForStatusFields(TableNo: Integer; FieldNo: Integer; var Hint: Text)
    begin
        if IsRestrictedField(TableNo, FieldNo) then
            Hint := HintLbl;
    end;

    local procedure IsRestrictedField(TableNo: Integer; FieldNo: Integer): Boolean
    var
        ProductionOrder: Record "Production Order";
    begin
        if TableNo <> Database::"Production Order" then
            exit(false);
        exit(FieldNo in [ProductionOrder.FieldNo(Status), ProductionOrder.FieldNo("Finished Date"), ProductionOrder.FieldNo(Reopened)]);
    end;
}
