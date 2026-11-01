namespace Origo.Bifrost.Manufacturing;

using Origo.Bifrost.Foundation;
using Microsoft.Manufacturing.ProductionBOM;
using Microsoft.Manufacturing.Routing;

/// <summary>
/// Restricts generic writes to the Status field of Production BOMs and Routings.
/// </summary>
codeunit 10077091 "BOM Routing Restrict ori"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Message Argument ori", 'OnAfterIsFieldWriteRestrictedForDataRecords', '', false, false)]
    local procedure RestrictStatusWrites(TableNo: Integer; FieldNo: Integer; var IsRestricted: Boolean)
    begin
        if IsRestricted then
            exit;

        if (TableNo = Database::"Production BOM Header") or (TableNo = Database::"Production BOM Version") then
            if FieldNo = 45 then // Status field in both tables
                IsRestricted := true;

        if (TableNo = Database::"Routing Header") or (TableNo = Database::"Routing Version") then
            if FieldNo = 20 then // Status field in both tables
                IsRestricted := true;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Message Argument ori", 'OnGetDedicatedMessageTypeHintForField', '', false, false)]
    local procedure GiveDedicatedTypeHint(TableNo: Integer; FieldNo: Integer; var Hint: Text)
    var
        UseDedicatedTypeTxt: Label 'Use Manufacturing.ProductionBOM.SetStatus / Manufacturing.Routing.SetStatus', Locked = true;
    begin
        if Hint <> '' then
            exit;

        if (TableNo = Database::"Production BOM Header") or (TableNo = Database::"Production BOM Version") then
            if FieldNo = 45 then
                Hint := UseDedicatedTypeTxt;

        if (TableNo = Database::"Routing Header") or (TableNo = Database::"Routing Version") then
            if FieldNo = 20 then
                Hint := UseDedicatedTypeTxt;
    end;
}
