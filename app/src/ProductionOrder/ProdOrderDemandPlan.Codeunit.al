namespace Origo.Bifrost.Manufacturing;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;
using Microsoft.Manufacturing.Document;
using Microsoft.Manufacturing.ProductionBOM;
using Microsoft.Manufacturing.Routing;
using Microsoft.Sales.Document;
using Origo.Bifrost;

/// <summary>
/// Reads a CreateFromDemand request and decides, without writing, which sales lines get a production order.
/// Also counts the orders for Foundation's confirmation gate.
/// </summary>
codeunit 10077084 "Prod Order Demand Plan ori" implements "Msg Confirm ori"
{
    Access = Internal;

    var
        AllowedKeysTxt: Label 'sourceType|sourceNo|sourceSystemId|lineNos|status|orderType|expectedCount', Locked = true;

    /// <summary>Counts the production orders the request would create; refusals are left to the execution step.</summary>
    procedure GetConfirmCount(var Argument: Record "Message Argument ori"; var Count: Integer; var Summary: Text): Boolean
    var
        SalesHeader: Record "Sales Header";
        TempEligible: Record "Sales Line" temporary;
        Skipped: JsonArray;
        OrderType: Enum "Create Production Order Type";
        NewStatus: Enum "Production Order Status";
        SummaryLbl: Label '%1 production order(s) for sales order %2', Comment = '%1 = order count, %2 = sales order number, is-IS=%1 framleiðslupöntun/-pantanir fyrir sölupöntun %2';
    begin
        // Foundation returns the refusal written here when this answers false, so the same checks as execution apply.
        if not Prepare(Argument, SalesHeader, TempEligible, Skipped, OrderType, NewStatus) then
            exit(false);
        Count := CountOrders(TempEligible, OrderType);
        Summary := StrSubstNo(SummaryLbl, Count, SalesHeader."No.");
        exit(true);
    end;

    /// <summary>Checks permissions and the request; responds the refusal and returns false when nothing may be created.</summary>
    internal procedure Prepare(var Argument: Record "Message Argument ori"; var SalesHeader: Record "Sales Header"; var TempEligible: Record "Sales Line" temporary; var Skipped: JsonArray; var OrderType: Enum "Create Production Order Type"; var NewStatus: Enum "Production Order Status"): Boolean
    var
        Gate: Record "Mfg Write Gate ori";
        PostingGate: Codeunit "Mfg Posting Gate ori";
        DeniedLbl: Label 'Manufacturing write permission is required to create production orders.', Comment = 'is-IS=Skrifheimild framleiðslu er áskilin til að stofna framleiðslupantanir.';
        DeniedNextLbl: Label 'Ask an administrator to assign BIFROST Mfg ori or BIFROST Full ori.', Comment = 'is-IS=Biddu stjórnanda um að úthluta BIFROST Mfg ori eða BIFROST Full ori.';
    begin
        if not Gate.WritePermission() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, DeniedLbl, '', '', 'BIFROST Mfg ori', DeniedNextLbl);
            exit(false);
        end;
        if not BuildPlan(Argument, SalesHeader, TempEligible, Skipped, OrderType, NewStatus) then
            exit(false);
        if NewStatus = NewStatus::Released then
            exit(PostingGate.AssertCanPost(Argument));
        exit(true);
    end;

    /// <summary>Returns the number of production orders a plan creates.</summary>
    internal procedure CountOrders(var TempEligible: Record "Sales Line" temporary; OrderType: Enum "Create Production Order Type"): Integer
    begin
        if TempEligible.IsEmpty() then
            exit(0);
        if OrderType = OrderType::ProjectOrder then
            exit(1);
        exit(TempEligible.Count());
    end;

    /// <summary>Validates the request and fills the eligible lines and the skipped list; returns false after a refusal.</summary>
    internal procedure BuildPlan(var Argument: Record "Message Argument ori"; var SalesHeader: Record "Sales Header"; var TempEligible: Record "Sales Line" temporary; var Skipped: JsonArray; var OrderType: Enum "Create Production Order Type"; var NewStatus: Enum "Production Order Status"): Boolean
    var
        Reader: Codeunit "Mfg Prod Order Request ori";
        Request: JsonObject;
        LineNos: List of [Integer];
    begin
        Request := Argument.GetRequestJson();
        Reader.CheckKeys(AllowedKeysTxt, Request, Argument);
        ReadSourceType(Request, Argument);
        ReadStatus(Request, NewStatus, Argument);
        ReadOrderType(Request, OrderType, Argument);
        ReadLineNos(Request, OrderType, LineNos, Argument);
        if not FindSalesOrder(Request, SalesHeader, Argument) then
            exit(false);
        if Reader.RespondIfErrors(Argument) then
            exit(false);
        if not CheckReleased(SalesHeader, Argument) then
            exit(false);
        if not CollectLines(SalesHeader, LineNos, OrderType, TempEligible, Skipped, Argument) then
            exit(false);
        exit(true);
    end;

    local procedure ReadSourceType(Request: JsonObject; var Argument: Record "Message Argument ori")
    var
        Reader: Codeunit "Mfg Prod Order Request ori";
        SourceType: Text;
        SourceTypeLbl: Label 'sourceType must be salesOrder. Production orders for project demand are not created by this operation.', Comment = 'is-IS=sourceType verður að vera salesOrder. Þessi aðgerð stofnar ekki framleiðslupantanir fyrir verkefnaþörf.';
        SourceTypeNextLbl: Label 'Send sourceType salesOrder with the number of a released sales order.', Comment = 'is-IS=Sendu sourceType salesOrder með númeri útgefinnar sölupöntunar.';
    begin
        SourceType := Reader.ReadText(Request, 'sourceType', true, 20, Argument);
        if (SourceType <> '') and (SourceType <> 'salesOrder') then
            Argument.AddError("Bifrost Error Code ori"::InvalidParameter, SourceTypeLbl, 'sourceType', SourceType, 'salesOrder', SourceTypeNextLbl);
    end;

    local procedure ReadStatus(Request: JsonObject; var NewStatus: Enum "Production Order Status"; var Argument: Record "Message Argument ori")
    var
        Reader: Codeunit "Mfg Prod Order Request ori";
        StatusText: Text;
        StatusLbl: Label 'status must be Planned, FirmPlanned or Released.', Comment = 'is-IS=status verður að vera Planned, FirmPlanned eða Released.';
        StatusNextLbl: Label 'Send status Planned, FirmPlanned or Released, or omit it for FirmPlanned.', Comment = 'is-IS=Sendu status Planned, FirmPlanned eða Released, eða slepptu því fyrir FirmPlanned.';
    begin
        NewStatus := NewStatus::"Firm Planned";
        if not Request.Contains('status') then
            exit;
        StatusText := Reader.ReadText(Request, 'status', true, 20, Argument);
        case StatusText of
            'Planned':
                NewStatus := NewStatus::Planned;
            'FirmPlanned':
                NewStatus := NewStatus::"Firm Planned";
            'Released':
                NewStatus := NewStatus::Released;
            else
                if StatusText <> '' then
                        Argument.AddError("Bifrost Error Code ori"::InvalidParameter, StatusLbl, 'status', StatusText, 'Planned|FirmPlanned|Released', StatusNextLbl);
        end;
    end;

    local procedure ReadOrderType(Request: JsonObject; var OrderType: Enum "Create Production Order Type"; var Argument: Record "Message Argument ori")
    var
        Reader: Codeunit "Mfg Prod Order Request ori";
        OrderTypeText: Text;
        OrderTypeLbl: Label 'orderType must be ItemOrder or ProjectOrder.', Comment = 'is-IS=orderType verður að vera ItemOrder eða ProjectOrder.';
        OrderTypeNextLbl: Label 'Send ItemOrder for one order per sales line or ProjectOrder for one order for the whole sales order.', Comment = 'is-IS=Sendu ItemOrder fyrir eina pöntun á hverja sölulínu eða ProjectOrder fyrir eina pöntun fyrir alla sölupöntunina.';
    begin
        OrderType := OrderType::ItemOrder;
        if not Request.Contains('orderType') then
            exit;
        OrderTypeText := Reader.ReadText(Request, 'orderType', true, 20, Argument);
        case OrderTypeText of
            'ItemOrder':
                OrderType := OrderType::ItemOrder;
            'ProjectOrder':
                OrderType := OrderType::ProjectOrder;
            else
                if OrderTypeText <> '' then
                        Argument.AddError("Bifrost Error Code ori"::InvalidParameter, OrderTypeLbl, 'orderType', OrderTypeText, 'ItemOrder|ProjectOrder', OrderTypeNextLbl);
        end;
    end;

    local procedure ReadLineNos(Request: JsonObject; OrderType: Enum "Create Production Order Type"; var LineNos: List of [Integer]; var Argument: Record "Message Argument ori")
    var
        Reader: Codeunit "Mfg Prod Order Request ori";
        Token: JsonToken;
        Element: JsonToken;
        Raw: Text;
        LineNo: Integer;
        ProjectLbl: Label 'lineNos cannot be combined with orderType ProjectOrder; one order covers every line Business Central offers.', Comment = 'is-IS=Ekki er hægt að nota lineNos með orderType ProjectOrder; ein pöntun nær yfir allar línur sem Business Central býður.';
        ProjectNextLbl: Label 'Omit lineNos, or use orderType ItemOrder to choose lines.', Comment = 'is-IS=Slepptu lineNos, eða notaðu orderType ItemOrder til að velja línur.';
    begin
        if not Request.Get('lineNos', Token) then
            exit;
        if not Token.IsArray() then begin
            Reader.BadFormat('lineNos', Argument);
            exit;
        end;
        foreach Element in Token.AsArray() do begin
            Element.WriteTo(Raw);
            if not Element.IsValue() or (CopyStr(Raw, 1, 1) = '"') or not Evaluate(LineNo, Raw, 9) then begin
                Reader.BadFormat('lineNos', Argument);
                exit;
            end;
            if not LineNos.Contains(LineNo) then
                LineNos.Add(LineNo);
        end;
        if LineNos.Count() = 0 then
            Reader.Missing('lineNos', Argument);
        if OrderType = OrderType::ProjectOrder then
            Argument.AddError("Bifrost Error Code ori"::InvalidParameter, ProjectLbl, 'lineNos', '', '', ProjectNextLbl);
    end;

    local procedure FindSalesOrder(Request: JsonObject; var SalesHeader: Record "Sales Header"; var Argument: Record "Message Argument ori"): Boolean
    var
        BySystemId: Record "Sales Header";
        Reader: Codeunit "Mfg Prod Order Request ori";
        SourceNo: Text;
        SystemIdText: Text;
        SystemId: Guid;
        HasNo: Boolean;
        HasSystemId: Boolean;
        NotFoundLbl: Label 'Sales order %1 was not found.', Comment = '%1 = sales order number or SystemId, is-IS=Sölupöntun %1 fannst ekki.';
        NotFoundNextLbl: Label 'Read the sales orders with Data.Records.Get and send the number or SystemId of an existing sales order.', Comment = 'is-IS=Lestu sölupantanirnar með Data.Records.Get og sendu númer eða SystemId sölupöntunar sem er til.';
        ConflictLbl: Label 'sourceNo %1 and sourceSystemId %2 name different sales orders.', Comment = '%1 = sales order number, %2 = SystemId, is-IS=sourceNo %1 og sourceSystemId %2 vísa á mismunandi sölupantanir.';
        ConflictNextLbl: Label 'Send identifiers of the same sales order, or only one of them.', Comment = 'is-IS=Sendu auðkenni sömu sölupöntunar, eða aðeins annað þeirra.';
    begin
        SalesHeader.SetLoadFields("Document Type", "No.", Status);
        BySystemId.SetLoadFields("Document Type", "No.", Status);
        HasNo := Request.Contains('sourceNo');
        HasSystemId := Request.Contains('sourceSystemId');
        if HasNo then
            SourceNo := Reader.ReadText(Request, 'sourceNo', true, 20, Argument);
        if HasSystemId then
            SystemIdText := Reader.ReadText(Request, 'sourceSystemId', true, 38, Argument);
        if not HasNo and not HasSystemId then
            Reader.Missing('sourceNo', Argument);
        if HasSystemId and (SystemIdText <> '') then
            if not Evaluate(SystemId, SystemIdText) then
                Reader.BadFormat('sourceSystemId', Argument);
        if Argument.HasCollectedErrors() then
            exit(true);
        if HasNo then
            if not SalesHeader.Get(SalesHeader."Document Type"::Order, SourceNo) then begin
                Refuse("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundLbl, SourceNo), 'sourceNo', SourceNo, NotFoundNextLbl, Argument);
                exit(false);
            end;
        if not HasSystemId then
            exit(true);
        if not BySystemId.GetBySystemId(SystemId) or (BySystemId."Document Type" <> BySystemId."Document Type"::Order) then begin
            Refuse("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundLbl, SystemIdText), 'sourceSystemId', SystemIdText, NotFoundNextLbl, Argument);
            exit(false);
        end;
        if HasNo and (BySystemId."No." <> SalesHeader."No.") then begin
            Refuse("Bifrost Error Code ori"::ConflictingIdentifiers, StrSubstNo(ConflictLbl, SourceNo, SystemIdText), 'sourceSystemId', SystemIdText, ConflictNextLbl, Argument);
            exit(false);
        end;
        SalesHeader := BySystemId;
        exit(true);
    end;

    local procedure CheckReleased(SalesHeader: Record "Sales Header"; var Argument: Record "Message Argument ori"): Boolean
    var
        NotReleasedLbl: Label 'Sales order %1 is not released. Nothing was changed.', Comment = '%1 = sales order number, is-IS=Sölupöntun %1 er ekki útgefin. Engu var breytt.';
        NotReleasedNextLbl: Label 'Release the sales order first, then send the same request again.', Comment = 'is-IS=Gefðu sölupöntunina út fyrst og sendu síðan sömu beiðni aftur.';
    begin
        if SalesHeader.Status = SalesHeader.Status::Released then
            exit(true);
        Refuse("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NotReleasedLbl, SalesHeader."No."), 'sourceNo', SalesHeader."No.", NotReleasedNextLbl, Argument);
        exit(false);
    end;

    local procedure CollectLines(SalesHeader: Record "Sales Header"; LineNos: List of [Integer]; OrderType: Enum "Create Production Order Type"; var TempEligible: Record "Sales Line" temporary; var Skipped: JsonArray; var Argument: Record "Message Argument ori"): Boolean
    var
        SalesLine: Record "Sales Line";
        LineNo: Integer;
        Reason: Text;
        NextStep: Text;
        Blocking: Boolean;
        LineMissingLbl: Label 'Sales order %1 has no line %2.', Comment = '%1 = sales order number, %2 = line number, is-IS=Sölupöntun %1 hefur enga línu %2.';
        LineMissingNextLbl: Label 'Read the sales lines with Data.Records.Get and send existing line numbers.', Comment = 'is-IS=Lestu sölulínurnar með Data.Records.Get og sendu línunúmer sem eru til.';
        WholeOrderLbl: Label 'Sales order %1 line %2 cannot be part of one order for the whole sales order: %3. Nothing was changed.', Comment = '%1 = sales order number, %2 = line number, %3 = reason, is-IS=Lína %2 í sölupöntun %1 getur ekki verið hluti af einni pöntun fyrir alla sölupöntunina: %3. Engu var breytt.';
        NothingLbl: Label 'No line of sales order %1 needs a production order. Nothing was changed.', Comment = '%1 = sales order number, is-IS=Engin lína í sölupöntun %1 þarfnast framleiðslupöntunar. Engu var breytt.';
        NothingNextLbl: Label 'Lines need an item replenished by production order, a certified production BOM and routing, a shipment date and an unreserved outstanding quantity.', Comment = 'is-IS=Línur þurfa vöru sem er endurnýjuð með framleiðslupöntun, vottaða uppskrift og leið, afhendingardagsetningu og óframtekið útistandandi magn.';
    begin
        TempEligible.Reset();
        TempEligible.DeleteAll();
        foreach LineNo in LineNos do
            if not SalesLine.Get(SalesHeader."Document Type", SalesHeader."No.", LineNo) then begin
                Refuse("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(LineMissingLbl, SalesHeader."No.", LineNo), 'lineNos', Format(LineNo, 0, 9), LineMissingNextLbl, Argument);
                exit(false);
            end;
        SalesLine.Reset();
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        if SalesLine.FindSet() then
            repeat
                if (LineNos.Count() = 0) or LineNos.Contains(SalesLine."Line No.") then
                    if (SalesLine.Type = SalesLine.Type::Item) and (SalesLine."No." <> '') then begin
                        if CheckLine(SalesLine, Reason, NextStep, Blocking) then begin
                            TempEligible := SalesLine;
                            TempEligible.Insert();
                        end else begin
                            if Blocking and (OrderType = OrderType::ProjectOrder) then begin
                                Refuse("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(WholeOrderLbl, SalesHeader."No.", SalesLine."Line No.", Reason), 'sourceNo', SalesHeader."No.", NextStep, Argument);
                                exit(false);
                            end;
                            Skipped.Add(SkippedEntry(SalesLine, Reason, NextStep));
                        end;
                    end else
                        if LineNos.Count() <> 0 then
                            Skipped.Add(SkippedEntry(SalesLine, NotItemReason(), NotItemNextStep()));
            until SalesLine.Next() = 0;
        if TempEligible.IsEmpty() then begin
            Refuse("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NothingLbl, SalesHeader."No."), 'sourceNo', SalesHeader."No.", NothingNextLbl, Argument);
            exit(false);
        end;
        exit(true);
    end;

    /// <summary>Applies the Business Central eligibility rules for one item line; Blocking marks reasons Business Central itself would fail on.</summary>
    local procedure CheckLine(var SalesLine: Record "Sales Line"; var Reason: Text; var NextStep: Text; var Blocking: Boolean): Boolean
    var
        Item: Record Item;
        Sku: Record "Stockkeeping Unit";
        BomHeader: Record "Production BOM Header";
        RoutingHeader: Record "Routing Header";
        Replenishment: Enum "Replenishment System";
        BomNo: Code[20];
        RoutingNo: Code[20];
        SuppliedLbl: Label 'alreadySupplied: the outstanding quantity is already reserved', Comment = 'is-IS=alreadySupplied: útistandandi magn er þegar frátekið';
        SuppliedNextLbl: Label 'Nothing to do; read the reservations with the inventory reservation operations if needed.', Comment = 'is-IS=Ekkert þarf að gera; lestu fráteknar færslur með birgðafrátektaraðgerðum ef þarf.';
        NotMfgLbl: Label 'notManufactured: the item is not replenished by production order', Comment = 'is-IS=notManufactured: varan er ekki endurnýjuð með framleiðslupöntun';
        NotMfgNextLbl: Label 'Supply the line by purchase or transfer, or set the item replenishment system to production order.', Comment = 'is-IS=Útvegaðu línuna með innkaupum eða millifærslu, eða stilltu endurnýjunarkerfi vörunnar á framleiðslupöntun.';
        BlockedLbl: Label 'itemBlocked: the item is blocked or blocked for production output', Comment = 'is-IS=itemBlocked: varan er lokuð eða lokuð fyrir framleiðsluafköst';
        BlockedNextLbl: Label 'Unblock the item, then send the request again.', Comment = 'is-IS=Opnaðu fyrir vöruna og sendu síðan beiðnina aftur.';
        BomLbl: Label 'bomNotCertified: production BOM %1 is not certified', Comment = '%1 = BOM number, is-IS=bomNotCertified: uppskrift %1 er ekki vottuð';
        BomNextLbl: Label 'Certify the production BOM with Manufacturing.ProductionBOM.SetStatus, then send the request again.', Comment = 'is-IS=Vottaðu uppskriftina með Manufacturing.ProductionBOM.SetStatus og sendu síðan beiðnina aftur.';
        RoutingLbl: Label 'routingNotCertified: routing %1 is not certified', Comment = '%1 = routing number, is-IS=routingNotCertified: leið %1 er ekki vottuð';
        RoutingNextLbl: Label 'Certify the routing with Manufacturing.Routing.SetStatus, then send the request again.', Comment = 'is-IS=Vottaðu leiðina með Manufacturing.Routing.SetStatus og sendu síðan beiðnina aftur.';
        DateLbl: Label 'missingShipmentDate: the line has no shipment date', Comment = 'is-IS=missingShipmentDate: línan hefur enga afhendingardagsetningu';
        DateNextLbl: Label 'Set a shipment date on the sales line, then send the request again.', Comment = 'is-IS=Settu afhendingardagsetningu á sölulínuna og sendu síðan beiðnina aftur.';
    begin
        Blocking := false;
        SalesLine.CalcFields("Reserved Qty. (Base)");
        if SalesLine."Outstanding Qty. (Base)" - SalesLine."Reserved Qty. (Base)" <= 0 then
            exit(Fail(SuppliedLbl, SuppliedNextLbl, Reason, NextStep));
        Item.SetLoadFields("No.", Blocked, "Production Blocked", "Replenishment System", "Production BOM No.", "Routing No.");
        if not Item.Get(SalesLine."No.") then
            exit(Fail(NotMfgLbl, NotMfgNextLbl, Reason, NextStep));
        Replenishment := Item."Replenishment System";
        BomNo := Item."Production BOM No.";
        RoutingNo := Item."Routing No.";
        Sku.SetLoadFields("Replenishment System", "Production BOM No.", "Routing No.");
        if Sku.Get(SalesLine."Location Code", SalesLine."No.", SalesLine."Variant Code") then begin
            Replenishment := Sku."Replenishment System";
            if Sku."Production BOM No." <> '' then
                BomNo := Sku."Production BOM No.";
            if Sku."Routing No." <> '' then
                RoutingNo := Sku."Routing No.";
        end;
        if Replenishment <> Replenishment::"Prod. Order" then
            exit(Fail(NotMfgLbl, NotMfgNextLbl, Reason, NextStep));
        Blocking := true;
        if Item.Blocked or (Item."Production Blocked" = Item."Production Blocked"::Output) then
            exit(Fail(BlockedLbl, BlockedNextLbl, Reason, NextStep));
        if BomNo <> '' then begin
            BomHeader.SetLoadFields(Status);
            if BomHeader.Get(BomNo) then
                if BomHeader.Status <> BomHeader.Status::Certified then
                    exit(Fail(StrSubstNo(BomLbl, BomNo), BomNextLbl, Reason, NextStep));
        end;
        if RoutingNo <> '' then begin
            RoutingHeader.SetLoadFields(Status);
            if RoutingHeader.Get(RoutingNo) then
                if RoutingHeader.Status <> RoutingHeader.Status::Certified then
                    exit(Fail(StrSubstNo(RoutingLbl, RoutingNo), RoutingNextLbl, Reason, NextStep));
        end;
        if SalesLine."Shipment Date" = 0D then
            exit(Fail(DateLbl, DateNextLbl, Reason, NextStep));
        Blocking := false;
        exit(true);
    end;

    local procedure Fail(NewReason: Text; NewNextStep: Text; var Reason: Text; var NextStep: Text): Boolean
    begin
        Reason := NewReason;
        NextStep := NewNextStep;
        exit(false);
    end;

    local procedure NotItemReason(): Text
    var
        NotItemLbl: Label 'notAnItem: only item lines can be supplied by a production order', Comment = 'is-IS=notAnItem: aðeins vörulínur geta fengið framleiðslupöntun';
    begin
        exit(NotItemLbl);
    end;

    local procedure NotItemNextStep(): Text
    var
        NotItemNextLbl: Label 'Leave the line out of lineNos.', Comment = 'is-IS=Slepptu línunni úr lineNos.';
    begin
        exit(NotItemNextLbl);
    end;

    local procedure SkippedEntry(SalesLine: Record "Sales Line"; Reason: Text; NextStep: Text): JsonObject
    var
        Entry: JsonObject;
    begin
        Entry.Add('salesLineNo', SalesLine."Line No.");
        Entry.Add('itemNo', SalesLine."No.");
        Entry.Add('reasonCode', Reason.Split(':').Get(1));
        Entry.Add('reason', Reason);
        Entry.Add('nextStep', NextStep);
        exit(Entry);
    end;

    local procedure Refuse(Code: Enum "Bifrost Error Code ori"; Message: Text; FieldName: Text; Value: Text; NextStep: Text; var Argument: Record "Message Argument ori")
    begin
        Argument.RespondWithError(Code, Message, FieldName, Value, '', NextStep);
    end;

}
