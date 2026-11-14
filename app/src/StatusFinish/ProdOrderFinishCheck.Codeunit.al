namespace Origo.Bifrost.Manufacturing;

using Microsoft.Manufacturing.Setup;
using Microsoft.Manufacturing.Document;
using Microsoft.Purchases.Document;
using Microsoft.Warehouse.Activity;
using Origo.Bifrost;

/// <summary>
/// Computes the findings Business Central evaluates before it finishes a production order,
/// without asking any question. Finish refuses on these findings; CheckFinish reports them.
/// </summary>
codeunit 10077060 "Prod Order Finish Check ori"
{
    Access = Internal;

    var
        NotFoundLbl: Label 'The production order was not found.', Comment = 'is-IS=Framleiðslupöntunin fannst ekki.';
        LookupNextLbl: Label 'Read production orders with Data.Records.Get and send a valid no or systemId.', Comment = 'is-IS=Lestu framleiðslupantanir með Data.Records.Get og sendu gilt no eða systemId.';
        AmbiguousLbl: Label 'Production order number %1 exists with more than one status.', Comment = '%1 = order number, is-IS=Framleiðslupöntunarnúmer %1 er til með fleiri en einni stöðu.';
        AmbiguousNextLbl: Label 'Send productionOrderStatus or systemId.', Comment = 'is-IS=Sendu productionOrderStatus eða systemId.';
        ConflictLbl: Label 'The identifiers do not identify the same production order.', Comment = 'is-IS=Auðkennin vísa ekki á sömu framleiðslupöntun.';
        ConflictNextLbl: Label 'Send identifiers belonging to the same production order and status.', Comment = 'is-IS=Sendu auðkenni sem tilheyra sömu framleiðslupöntun og stöðu.';
        StatusLbl: Label 'productionOrderStatus must be Simulated, Planned, FirmPlanned, Released or Finished.', Comment = 'is-IS=productionOrderStatus verður að vera Simulated, Planned, FirmPlanned, Released eða Finished.';
        StatusNextLbl: Label 'Send a status name from the contract or omit productionOrderStatus.', Comment = 'is-IS=Sendu stöðuheiti úr samningnum eða slepptu productionOrderStatus.';
        NotReleasedLbl: Label 'Production order %1 is %2. Only a Released order can be finished.', Comment = '%1 = order number, %2 = status, is-IS=Framleiðslupöntun %1 er %2. Aðeins útgefinni pöntun er hægt að ljúka.';
        MissingOutputLbl: Label 'Production order %1 still has output missing. Nothing was changed.', Comment = '%1 = order number, is-IS=Framleiðslupöntun %1 vantar enn afköst. Engu var breytt.';
        MissingOutputNextLbl: Label 'Post the output, or send acceptMissingOutput = true to finish anyway.', Comment = 'is-IS=Bókaðu afköstin eða sendu acceptMissingOutput = true til að ljúka samt.';
        MissingConsumptionLbl: Label 'Production order %1 still has consumption missing. Nothing was changed.', Comment = '%1 = order number, is-IS=Framleiðslupöntun %1 vantar enn notkun. Engu var breytt.';
        MissingConsumptionNextLbl: Label 'Post the consumption, or send acceptMissingConsumption = true to finish anyway.', Comment = 'is-IS=Bókaðu notkunina eða sendu acceptMissingConsumption = true til að ljúka samt.';
        NoOutputLbl: Label 'Production order %1 cannot be finished. It has consumption or capacity posted with no output.', Comment = '%1 = order number, is-IS=Ekki er hægt að ljúka framleiðslupöntun %1. Hún hefur notkun eða afkastagetu bókaða án afkasta.';
        NoOutputNextLbl: Label 'Post the output, or send finishWithoutOutput = true to finish without output.', Comment = 'is-IS=Bókaðu afköstin eða sendu finishWithoutOutput = true til að ljúka án afkasta.';
        SubcontractLbl: Label 'Production order %1 cannot be finished as there is an outstanding purchase order for it.', Comment = '%1 = order number, is-IS=Ekki er hægt að ljúka framleiðslupöntun %1 þar sem útistandandi innkaupapöntun er til fyrir hana.';
        SubcontractNextLbl: Label 'Receive or delete the subcontract purchase order first.', Comment = 'is-IS=Móttaktu eða eyddu verktakainnkaupapöntuninni fyrst.';
        PickLbl: Label 'Production order %1 cannot be finished as there is an outstanding warehouse pick for its components.', Comment = '%1 = order number, is-IS=Ekki er hægt að ljúka framleiðslupöntun %1 þar sem útistandandi vöruhúsatínsla er til fyrir íhluti hennar.';
        PickNextLbl: Label 'Register or delete the outstanding pick first.', Comment = 'is-IS=Skráðu eða eyddu útistandandi tínslunni fyrst.';

    /// <summary>Resolves the order by no, systemId and an optional status of any value.</summary>
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
            if not TryStatus(StatusText, OrderStatus) then
                Argument.AddError("Bifrost Error Code ori"::InvalidParameter, StatusLbl, 'productionOrderStatus', StatusText, '', StatusNextLbl);
        if Reader.RespondIfErrors(Argument) then
            exit(false);
        ProductionOrder.SetLoadFields(Status, "No.", "Source No.", Quantity, "Due Date", "Finished Date");
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

    /// <summary>Maps an invariant status name to the enum value.</summary>
    internal procedure TryStatus(StatusText: Text; var OrderStatus: Enum "Production Order Status"): Boolean
    begin
        case StatusText of
            'Simulated':
                OrderStatus := OrderStatus::Simulated;
            'Planned':
                OrderStatus := OrderStatus::Planned;
            'FirmPlanned':
                OrderStatus := OrderStatus::"Firm Planned";
            'Released':
                OrderStatus := OrderStatus::Released;
            'Finished':
                OrderStatus := OrderStatus::Finished;
            else
                exit(false);
        end;
        exit(true);
    end;

    /// <summary>
    /// Collects blockers and warnings. Blockers are objects {code, message, nextStep, lineNo?, itemNo?};
    /// warnings are objects {kind, message, nextStep}. FinishWithoutOutput removes the no-output blocker.
    /// </summary>
    internal procedure CollectFindings(ProductionOrder: Record "Production Order"; FinishWithoutOutput: Boolean; var Blockers: JsonArray; var Warnings: JsonArray)
    var
        ProdOrderLine: Record "Prod. Order Line";
        StatusMgt: Codeunit "Prod. Order Status Management";
        Lookup: Codeunit "Mfg Prod Order Lookup ori";
        MissingOutput: Boolean;
        MissingConsumption: Boolean;
        NoOutputLineNo: Integer;
    begin
        Clear(Blockers);
        Clear(Warnings);
        NoOutputLineNo := 0;
        if ProductionOrder.Status <> ProductionOrder.Status::Released then begin
            Blockers.Add(Finding('NotReleased', StrSubstNo(NotReleasedLbl, ProductionOrder."No.", Lookup.StatusName(ProductionOrder.Status)), '', 0, ''));
            exit;
        end;
        if HasOutstandingSubcontract(ProductionOrder) then
            Blockers.Add(Finding('OutstandingSubcontractOrder', StrSubstNo(SubcontractLbl, ProductionOrder."No."), SubcontractNextLbl, 0, ''));
        if HasOutstandingPick(ProductionOrder) then
            Blockers.Add(Finding('OutstandingPick', StrSubstNo(PickLbl, ProductionOrder."No."), PickNextLbl, 0, ''));
        ProdOrderLine.SetLoadFields(Status, "Prod. Order No.", "Line No.", "Item No.", "Remaining Quantity", "Routing No.", "Routing Reference No.");
        ProdOrderLine.SetRange(Status, ProductionOrder.Status);
        ProdOrderLine.SetRange("Prod. Order No.", ProductionOrder."No.");
        if ProdOrderLine.FindSet() then
            repeat
                if (NoOutputLineNo = 0) and not FinishWithoutOutput then
                    if not StatusMgt.OutputExists(ProdOrderLine) then
                        if StatusMgt.MatrOrCapConsumpExists(ProdOrderLine) then begin
                            NoOutputLineNo := ProdOrderLine."Line No.";
                            Blockers.Add(Finding('ConsumptionWithoutOutput', StrSubstNo(NoOutputLbl, ProductionOrder."No."), NoOutputNextLbl, ProdOrderLine."Line No.", ProdOrderLine."Item No."));
                        end;
                if not MissingOutput then
                    MissingOutput := LineHasMissingOutput(ProdOrderLine);
                if not MissingConsumption then
                    MissingConsumption := LineHasMissingConsumption(ProdOrderLine);
            until ProdOrderLine.Next() = 0;
        if MissingOutput then
            Warnings.Add(Warning('missingOutput', StrSubstNo(MissingOutputLbl, ProductionOrder."No."), MissingOutputNextLbl));
        if MissingConsumption then
            Warnings.Add(Warning('missingConsumption', StrSubstNo(MissingConsumptionLbl, ProductionOrder."No."), MissingConsumptionNextLbl));
    end;

    /// <summary>Lists the order lines with finished and remaining quantities.</summary>
    internal procedure GetLines(ProductionOrder: Record "Production Order"; IncludeRemaining: Boolean): JsonArray
    var
        ProdOrderLine: Record "Prod. Order Line";
        Line: JsonObject;
        Lines: JsonArray;
    begin
        ProdOrderLine.SetLoadFields(Status, "Prod. Order No.", "Line No.", "Item No.", Quantity, "Finished Quantity", "Remaining Quantity");
        ProdOrderLine.SetRange(Status, ProductionOrder.Status);
        ProdOrderLine.SetRange("Prod. Order No.", ProductionOrder."No.");
        if ProdOrderLine.FindSet() then
            repeat
                Clear(Line);
                Line.Add('lineNo', ProdOrderLine."Line No.");
                Line.Add('itemNo', ProdOrderLine."Item No.");
                Line.Add('quantity', ProdOrderLine.Quantity);
                Line.Add('finishedQuantity', ProdOrderLine."Finished Quantity");
                if IncludeRemaining then
                    Line.Add('remainingQuantity', ProdOrderLine."Remaining Quantity");
                Lines.Add(Line);
            until ProdOrderLine.Next() = 0;
        exit(Lines);
    end;

    /// <summary>Lists the order components with expected and remaining quantities and flushing method.</summary>
    internal procedure GetComponents(ProductionOrder: Record "Production Order"): JsonArray
    var
        Component: Record "Prod. Order Component";
        Entry: JsonObject;
        Components: JsonArray;
    begin
        Component.SetLoadFields(Status, "Prod. Order No.", "Prod. Order Line No.", "Line No.", "Item No.", "Expected Quantity", "Remaining Quantity", "Flushing Method");
        Component.SetRange(Status, ProductionOrder.Status);
        Component.SetRange("Prod. Order No.", ProductionOrder."No.");
        if Component.FindSet() then
            repeat
                Clear(Entry);
                Entry.Add('prodOrderLineNo', Component."Prod. Order Line No.");
                Entry.Add('lineNo', Component."Line No.");
                Entry.Add('itemNo', Component."Item No.");
                Entry.Add('expectedQuantity', Component."Expected Quantity");
                Entry.Add('remainingQuantity', Component."Remaining Quantity");
                Entry.Add('flushingMethod', FlushingName(Component."Flushing Method"));
                Components.Add(Entry);
            until Component.Next() = 0;
        exit(Components);
    end;

    /// <summary>Returns true when the warnings contain the given kind.</summary>
    internal procedure HasWarning(Warnings: JsonArray; Kind: Text): Boolean
    var
        Token: JsonToken;
        KindToken: JsonToken;
    begin
        foreach Token in Warnings do
            if Token.AsObject().Get('kind', KindToken) then
                if KindToken.AsValue().AsText() = Kind then
                    exit(true);
        exit(false);
    end;

    local procedure LineHasMissingOutput(ProdOrderLine: Record "Prod. Order Line"): Boolean
    var
        RoutingLine: Record "Prod. Order Routing Line";
    begin
        if ProdOrderLine."Remaining Quantity" <= 0 then
            exit(false);
        RoutingLine.SetLoadFields(Status, "Prod. Order No.", "Routing Reference No.", "Routing No.", "Next Operation No.", "Flushing Method");
        RoutingLine.SetRange(Status, ProdOrderLine.Status);
        RoutingLine.SetRange("Prod. Order No.", ProdOrderLine."Prod. Order No.");
        RoutingLine.SetRange("Routing Reference No.", ProdOrderLine."Routing Reference No.");
        RoutingLine.SetRange("Routing No.", ProdOrderLine."Routing No.");
        RoutingLine.SetRange("Next Operation No.", '');
        if not RoutingLine.FindFirst() then
            exit(true);
        // A backward-flushed last operation posts the output when the order is finished.
        exit(RoutingLine."Flushing Method" <> RoutingLine."Flushing Method"::Backward);
    end;

    local procedure LineHasMissingConsumption(ProdOrderLine: Record "Prod. Order Line"): Boolean
    var
        Component: Record "Prod. Order Component";
    begin
        Component.SetLoadFields(Status, "Prod. Order No.", "Prod. Order Line No.", "Remaining Quantity", "Flushing Method", "Routing Link Code");
        Component.SetRange(Status, ProdOrderLine.Status);
        Component.SetRange("Prod. Order No.", ProdOrderLine."Prod. Order No.");
        Component.SetRange("Prod. Order Line No.", ProdOrderLine."Line No.");
        Component.SetFilter("Remaining Quantity", '<>0');
        if Component.FindSet() then
            repeat
                if not IsFlushedAtFinish(ProdOrderLine, Component) then
                    exit(true);
            until Component.Next() = 0;
        exit(false);
    end;

    /// <summary>
    /// Backward-flushed components are consumed when the order is finished. As in Business Central, a component with a
    /// routing link code is only flushed backward when its linked routing operation exists and also flushes backward
    /// (BC RtngWillFlushComp returns false when no operation matches the link).
    /// </summary>
    local procedure IsFlushedAtFinish(ProdOrderLine: Record "Prod. Order Line"; Component: Record "Prod. Order Component"): Boolean
    var
        RoutingLine: Record "Prod. Order Routing Line";
    begin
        if not (Component."Flushing Method" in [Component."Flushing Method"::Backward, Component."Flushing Method"::"Pick + Backward"]) then
            exit(false);
        if Component."Routing Link Code" = '' then
            exit(true);
        RoutingLine.SetLoadFields(Status, "Prod. Order No.", "Routing Reference No.", "Routing No.", "Routing Link Code", "Flushing Method");
        RoutingLine.SetRange(Status, ProdOrderLine.Status);
        RoutingLine.SetRange("Prod. Order No.", ProdOrderLine."Prod. Order No.");
        RoutingLine.SetRange("Routing Reference No.", ProdOrderLine."Routing Reference No.");
        RoutingLine.SetRange("Routing No.", ProdOrderLine."Routing No.");
        RoutingLine.SetRange("Routing Link Code", Component."Routing Link Code");
        if not RoutingLine.FindFirst() then
            exit(false);
        exit(RoutingLine."Flushing Method" = RoutingLine."Flushing Method"::Backward);
    end;

    local procedure HasOutstandingSubcontract(ProductionOrder: Record "Production Order"): Boolean
    var
        PurchaseLine: Record "Purchase Line";
    begin
        PurchaseLine.SetRange("Document Type", PurchaseLine."Document Type"::Order);
        PurchaseLine.SetRange(Type, PurchaseLine.Type::Item);
        PurchaseLine.SetRange("Prod. Order No.", ProductionOrder."No.");
        PurchaseLine.SetFilter("Outstanding Quantity", '<>0');
        exit(not PurchaseLine.IsEmpty());
    end;

    local procedure HasOutstandingPick(ProductionOrder: Record "Production Order"): Boolean
    var
        ActivityLine: Record "Warehouse Activity Line";
        Component: Record "Prod. Order Component";
    begin
        ActivityLine.SetRange("Source Type", Database::"Prod. Order Component");
        ActivityLine.SetRange("Source Subtype", ProductionOrder.Status.AsInteger());
        ActivityLine.SetRange("Source No.", ProductionOrder."No.");
        ActivityLine.SetRange("Activity Type", ActivityLine."Activity Type"::Pick);
        if not ActivityLine.IsEmpty() then
            exit(true);
        ActivityLine.SetRange("Activity Type", ActivityLine."Activity Type"::"Invt. Pick");
        if not ActivityLine.IsEmpty() then
            exit(true);
        Component.SetRange(Status, ProductionOrder.Status);
        Component.SetRange("Prod. Order No.", ProductionOrder."No.");
        Component.SetFilter("Pick Qty. (Base)", '<>0');
        exit(not Component.IsEmpty());
    end;

    local procedure Finding(Code: Text; Message: Text; NextStep: Text; LineNo: Integer; ItemNo: Code[20]): JsonObject
    var
        Result: JsonObject;
    begin
        Result.Add('code', Code);
        Result.Add('message', Message);
        if NextStep <> '' then
            Result.Add('nextStep', NextStep);
        if LineNo <> 0 then
            Result.Add('lineNo', LineNo);
        if ItemNo <> '' then
            Result.Add('itemNo', ItemNo);
        exit(Result);
    end;

    local procedure Warning(Kind: Text; Message: Text; NextStep: Text): JsonObject
    var
        Result: JsonObject;
    begin
        Result.Add('kind', Kind);
        Result.Add('message', Message);
        Result.Add('nextStep', NextStep);
        exit(Result);
    end;

    local procedure FlushingName(Method: Enum "Flushing Method"): Text
    begin
        // Invariant enum names without spaces, for example Pick + Backward becomes PickBackward.
        exit(Method.Names().Get(Method.Ordinals().IndexOf(Method.AsInteger())).Replace(' ', '').Replace('+', ''));
    end;
}
