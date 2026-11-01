namespace Origo.Bifrost.Manufacturing;

using Microsoft.Manufacturing.Document;
using Origo.Bifrost;

/// <summary>Resolves production order identity without choosing an arbitrary status or truncating a key.</summary>
codeunit 10077044 "Mfg Prod Order Lookup ori"
{
    Access = Internal;

    var
        NotFoundLbl: Label 'The production order was not found.', Comment = 'is-IS=Framleiðslupöntunin fannst ekki.';
        LookupNextLbl: Label 'Read production orders with Data.Records.Get and send a valid no or systemId.', Comment = 'is-IS=Lestu framleiðslupantanir með Data.Records.Get og sendu gilt no eða systemId.';
        AmbiguousLbl: Label 'Production order number %1 exists with more than one status.', Comment = '%1 = order number, is-IS=Framleiðslupöntunarnúmer %1 er til með fleiri en einni stöðu.';
        AmbiguousNextLbl: Label 'Send productionOrderStatus or systemId.', Comment = 'is-IS=Sendu productionOrderStatus eða systemId.';
        ConflictLbl: Label 'The identifiers do not identify the same production order.', Comment = 'is-IS=Auðkennin vísa ekki á sömu framleiðslupöntun.';
        ConflictNextLbl: Label 'Send identifiers belonging to the same production order and status.', Comment = 'is-IS=Sendu auðkenni sem tilheyra sömu framleiðslupöntun og stöðu.';
        StatusLbl: Label 'productionOrderStatus must be Simulated, Planned or FirmPlanned.', Comment = 'is-IS=productionOrderStatus verður að vera Simulated, Planned eða FirmPlanned.';
        StatusNextLbl: Label 'Use a planning status or omit productionOrderStatus and identify the order by systemId.', Comment = 'is-IS=Notaðu áætlunarstöðu eða slepptu productionOrderStatus og auðkenndu pöntunina með systemId.';

    /// <summary>Resolves all supplied identifiers and an optional planning status; reports structured errors.</summary>
    internal procedure FindOrder(var Argument: Record "Message Argument ori"; var ProductionOrder: Record "Production Order"): Boolean
    var
        Reader: Codeunit "Mfg Prod Order Request ori";
        Request: JsonObject;
        Number: Text;
        IdText: Text;
        StatusText: Text;
        Id: Guid;
        OrderStatus: Enum "Production Order Status";
    begin
        Request := Argument.GetRequestJson();
        Number := Reader.ReadText(Request, 'no', false, 20, Argument);
        IdText := Reader.ReadText(Request, 'systemId', false, 50, Argument);
        StatusText := Reader.ReadText(Request, 'productionOrderStatus', false, 20, Argument);
        if (Number = '') and (IdText = '') then
            Reader.Missing('no/systemId', Argument);
        if IdText <> '' then
            if not Evaluate(Id, IdText) or IsNullGuid(Id) then
                Reader.BadFormat('systemId', Argument);
        if StatusText <> '' then
            case StatusText of
                'Simulated':
                    OrderStatus := OrderStatus::Simulated;
                'Planned':
                    OrderStatus := OrderStatus::Planned;
                'FirmPlanned':
                    OrderStatus := OrderStatus::"Firm Planned";
                else
                    Argument.AddError("Bifrost Error Code ori"::InvalidParameter, StatusLbl, 'productionOrderStatus', StatusText, '', StatusNextLbl);
            end;
        if Reader.RespondIfErrors(Argument) then
            exit(false);
        ProductionOrder.SetLoadFields(Status, "No.", "Source No.", Quantity, "Due Date", "Starting Date", "Ending Date");
        if IdText <> '' then begin
            if not ProductionOrder.GetBySystemId(Id) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, NotFoundLbl, 'systemId', IdText, '', LookupNextLbl);
                exit(false);
            end;
            if ((Number <> '') and (ProductionOrder."No." <> UpperCase(Number))) or
               ((StatusText <> '') and (ProductionOrder.Status <> OrderStatus))
            then begin
                Argument.RespondWithError("Bifrost Error Code ori"::ConflictingIdentifiers, ConflictLbl, 'no/systemId', '', '', ConflictNextLbl);
                exit(false);
            end;
            exit(true);
        end;
        ProductionOrder.SetRange("No.", Number);
        if StatusText <> '' then
            ProductionOrder.SetRange(Status, OrderStatus);
        if ProductionOrder.IsEmpty() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, NotFoundLbl, 'no', Number, '', LookupNextLbl);
            exit(false);
        end;
        if ProductionOrder.Count() > 1 then begin
            Argument.RespondWithError("Bifrost Error Code ori"::AmbiguousRecord, StrSubstNo(AmbiguousLbl, Number), 'no', Number, '', AmbiguousNextLbl);
            exit(false);
        end;
        ProductionOrder.FindFirst();
        exit(true);
    end;

    /// <summary>Returns invariant external status names; never serializes a localized enum caption.</summary>
    internal procedure StatusName(OrderStatus: Enum "Production Order Status"): Text
    begin
        case OrderStatus of
            OrderStatus::Simulated:
                exit('Simulated');
            OrderStatus::Planned:
                exit('Planned');
            OrderStatus::"Firm Planned":
                exit('FirmPlanned');
            OrderStatus::Released:
                exit('Released');
            OrderStatus::Finished:
                exit('Finished');
        end;
        exit('');
    end;
}
