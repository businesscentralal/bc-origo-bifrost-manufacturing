namespace Origo.Bifrost.Manufacturing;

using Microsoft.Manufacturing.ProductionBOM;
using Microsoft.Manufacturing.Routing;
using Origo.Bifrost;

/// <summary>
/// Refuses a generic Data.Records.Set of Status on a production BOM, a production BOM version,
/// a routing or a routing version. A generic write of Closed would ask a question and then
/// silently keep the old status, and a generic Certified would skip the version commit rule.
/// The dedicated message types run the standard checks and suppress that commit.
/// </summary>
codeunit 10077091 "BOM Routing Restrict ori"
{
    Access = Internal;
    InherentPermissions = X;
    InherentEntitlements = X;

    var
        BomHintLbl: Label 'Use Manufacturing.ProductionBOM.SetStatus', Comment = 'is-IS=Notaðu Manufacturing.ProductionBOM.SetStatus';
        RoutingHintLbl: Label 'Use Manufacturing.Routing.SetStatus', Comment = 'is-IS=Notaðu Manufacturing.Routing.SetStatus';

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnAfterIsFieldWriteRestrictedForDataRecords, '', false, false)]
    local procedure RestrictStatus(TableNo: Integer; FieldNo: Integer; Force: Boolean; var IsRestricted: Boolean)
    begin
        // A forced generic write does not reopen Status. Certification goes through the dedicated type.
        if IsStatusField(TableNo, FieldNo) then
            IsRestricted := true;
        if Force and IsStatusField(TableNo, FieldNo) then
            IsRestricted := true;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Message Argument ori", OnGetDedicatedMessageTypeHintForField, '', false, false)]
    local procedure HintForStatus(TableNo: Integer; FieldNo: Integer; var Hint: Text)
    begin
        if not IsStatusField(TableNo, FieldNo) then
            exit;
        if IsProductionBomTable(TableNo) then
            Hint := BomHintLbl
        else
            Hint := RoutingHintLbl;
    end;

    local procedure IsStatusField(TableNo: Integer; FieldNo: Integer): Boolean
    var
        ProdBomHeader: Record "Production BOM Header";
        ProdBomVersion: Record "Production BOM Version";
        RoutingHeader: Record "Routing Header";
        RoutingVersion: Record "Routing Version";
    begin
        case TableNo of
            Database::"Production BOM Header":
                exit(FieldNo = ProdBomHeader.FieldNo(Status));
            Database::"Production BOM Version":
                exit(FieldNo = ProdBomVersion.FieldNo(Status));
            Database::"Routing Header":
                exit(FieldNo = RoutingHeader.FieldNo(Status));
            Database::"Routing Version":
                exit(FieldNo = RoutingVersion.FieldNo(Status));
        end;
        exit(false);
    end;

    local procedure IsProductionBomTable(TableNo: Integer): Boolean
    begin
        exit(TableNo in [Database::"Production BOM Header", Database::"Production BOM Version"]);
    end;
}
