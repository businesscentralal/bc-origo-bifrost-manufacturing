namespace Origo.Bifrost.Manufacturing;

using Microsoft.Manufacturing.Document;
using Microsoft.Manufacturing.Setup;
using Origo.Bifrost;

/// <summary>Reads and validates the request of the three production journal types and hands it to the boundary.</summary>
codeunit 10077080 "Prod Jnl Request ori"
{
    Access = Internal;

    var
        LineIndexLbl: Label 'lines[%1]', Locked = true;
        LinePrefixLbl: Label 'lines[%1].', Locked = true;
        NotReleasedLbl: Label 'Production order %1 is %2. The production journal is only available for a Released order.', Comment = '%1 = order number, %2 = status, is-IS=Framleiðslupöntun %1 er %2. Framleiðslubók er aðeins til fyrir útgefna pöntun.';
        PlannedNextLbl: Label 'Change the status to Released with Manufacturing.ProductionOrder.ChangeStatus.', Comment = 'is-IS=Breyttu stöðunni í útgefna með Manufacturing.ProductionOrder.ChangeStatus.';
        ClosedNextLbl: Label 'A finished order is closed; its journal cannot be used.', Comment = 'is-IS=Lokin pöntun er lokuð; ekki er hægt að nota framleiðslubók hennar.';
        NoLineLbl: Label 'Production order %1 has no line %2.', Comment = '%1 = order number, %2 = line number, is-IS=Framleiðslupöntun %1 hefur ekki línu %2.';
        LineNextLbl: Label 'Read the lines with Manufacturing.ProductionJournal.Get.', Comment = 'is-IS=Lestu línurnar með Manufacturing.ProductionJournal.Get.';
        BasisLbl: Label 'consumptionBasis must be ActualOutput or ExpectedOutput.', Comment = 'is-IS=consumptionBasis verður að vera ActualOutput eða ExpectedOutput.';
        BasisNextLbl: Label 'Send ActualOutput or ExpectedOutput, or omit consumptionBasis to use Manufacturing Setup.', Comment = 'is-IS=Sendu ActualOutput eða ExpectedOutput, eða slepptu consumptionBasis til að nota Manufacturing Setup.';
        IncludeLbl: Label 'include must be an array containing output and/or consumption.', Comment = 'is-IS=include verður að vera fylki sem inniheldur output og/eða consumption.';
        IncludeNextLbl: Label 'Send ["output","consumption"] or a subset.', Comment = 'is-IS=Sendu ["output","consumption"] eða hluta þess.';
        DateLbl: Label 'postingDate must be a date in the format yyyy-mm-dd.', Comment = 'is-IS=postingDate verður að vera dagsetning á sniðinu yyyy-mm-dd.';
        DateNextLbl: Label 'Send an ISO date or omit postingDate to use the work date.', Comment = 'is-IS=Sendu ISO-dagsetningu eða slepptu postingDate til að nota vinnudagsetningu.';
        LinesLbl: Label 'lines must be an array of objects.', Comment = 'is-IS=lines verður að vera fylki af hlutum.';
        LinesNextLbl: Label 'Send lines in the shape that Manufacturing.ProductionJournal.Get returns as proposedLines.', Comment = 'is-IS=Sendu línur á sniðinu sem Manufacturing.ProductionJournal.Get skilar sem proposedLines.';
        KindLbl: Label 'kind must be output or consumption.', Comment = 'is-IS=kind verður að vera output eða consumption.';
        NegativeLbl: Label 'Quantity must be 0 or more.', Comment = 'is-IS=Magn verður að vera 0 eða meira.';
        NumberLbl: Label '%1 must be a number.', Comment = '%1 = parameter, is-IS=%1 verður að vera tala.';
        OperationLbl: Label 'Operation %1 is not on production order %2.', Comment = '%1 = operation number, %2 = order number, is-IS=Aðgerð %1 er ekki á framleiðslupöntun %2.';
        OperationNextLbl: Label 'Read the operations with Manufacturing.ProductionJournal.Get.', Comment = 'is-IS=Lestu aðgerðirnar með Manufacturing.ProductionJournal.Get.';
        ComponentLbl: Label 'Component line %1 is not on production order %2.', Comment = '%1 = component line number, %2 = order number, is-IS=Íhlutalína %1 er ekki á framleiðslupöntun %2.';
        MissingLbl: Label '%1 is required.', Comment = '%1 = parameter, is-IS=%1 er áskilið.';
        UnknownLbl: Label 'Unknown parameter %1.', Comment = '%1 = parameter, is-IS=Óþekkt færibreyta %1.';
        UnknownNextLbl: Label 'Remove the unknown parameter and use the documented parameters.', Comment = 'is-IS=Fjarlægðu óþekktu færibreytuna og notaðu skjalfestar færibreytur.';

    /// <summary>Validates the request and stores it for the boundary. Mode: 0 Get, 1 PreviewPost, 2 Post. Returns false after a response.</summary>
    internal procedure Read(var Argument: Record "Message Argument ori"; Mode: Integer; var ProductionOrder: Record "Production Order"): Boolean
    var
        ProdOrderLine: Record "Prod. Order Line";
        Reader: Codeunit "Mfg Prod Order Request ori";
        FinishCheck: Codeunit "Prod Order Finish Check ori";
        Events: Codeunit "Prod Jnl Events ori";
        Request: JsonObject;
        Token: JsonToken;
        Allowed: Text;
        Raw: Text;
        PostingDate: Date;
        HasDate: Boolean;
        HasBasis: Boolean;
        Basis: Integer;
        LineNo: Integer;
        IncludeOutput: Boolean;
        IncludeConsumption: Boolean;
        Checked: JsonArray;
    begin
        Request := Argument.GetRequestJson();
        Allowed := 'no|systemId|productionOrderStatus|lineNo|postingDate|consumptionBasis|include';
        if Mode >= 1 then
            Allowed += '|lines';
        if Mode = 2 then
            Allowed += '|expectedCount';
        Reader.CheckKeys(Allowed, Request, Argument);
        if not FinishCheck.FindOrder(Argument, ProductionOrder) then
            exit(false);
        if ProductionOrder.Status <> ProductionOrder.Status::Released then begin
            if ProductionOrder.Status = ProductionOrder.Status::Finished then
                Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NotReleasedLbl, ProductionOrder."No.", Format(ProductionOrder.Status)), 'productionOrderStatus', Format(ProductionOrder.Status, 0, 9), 'Released', ClosedNextLbl)
            else
                Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NotReleasedLbl, ProductionOrder."No.", Format(ProductionOrder.Status)), 'productionOrderStatus', Format(ProductionOrder.Status, 0, 9), 'Released', PlannedNextLbl);
            exit(false);
        end;
        IncludeOutput := true;
        IncludeConsumption := true;
        if Request.Get('lineNo', Token) then begin
            Token.WriteTo(Raw);
            if not Token.IsValue() or (CopyStr(Raw, 1, 1) = '"') or not Evaluate(LineNo, Raw, 9) then
                Reader.BadFormat('lineNo', Argument)
            else
                if not ProdOrderLine.Get(ProductionOrder.Status, ProductionOrder."No.", LineNo) then
                    Argument.AddError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(NoLineLbl, ProductionOrder."No.", LineNo), 'lineNo', Raw, '', LineNextLbl);
        end;
        if Request.Get('postingDate', Token) then begin
            Token.WriteTo(Raw);
            Raw := DelChr(Raw, '=', '"');
            if Evaluate(PostingDate, Raw, 9) and (PostingDate <> 0D) and (Format(PostingDate, 0, 9) = Raw) then
                HasDate := true
            else
                Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, DateLbl, 'postingDate', Raw, '', DateNextLbl);
        end;
        if Request.Get('consumptionBasis', Token) then begin
            Token.WriteTo(Raw);
            Raw := DelChr(Raw, '=', '"');
            HasBasis := true;
            case Raw of
                'ActualOutput':
                    Basis := 0;
                'ExpectedOutput':
                    Basis := 1;
                else
                    HasBasis := false;
            end;
            if not HasBasis then
                Argument.AddError("Bifrost Error Code ori"::InvalidParameter, BasisLbl, 'consumptionBasis', Raw, 'ActualOutput|ExpectedOutput', BasisNextLbl);
        end;
        if Request.Get('include', Token) then
            ReadInclude(Token, IncludeOutput, IncludeConsumption, Argument);
        if Request.Get('lines', Token) then
            if not Token.IsArray() then
                Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, LinesLbl, 'lines', '', '', LinesNextLbl)
            else
                ValidateLines(Token.AsArray(), ProductionOrder, Checked, Argument);
        if Reader.RespondIfErrors(Argument) then
            exit(false);
        Events.SetRequest(Mode, ProductionOrder."No.", LineNo, HasDate, PostingDate, HasBasis, Basis, IncludeOutput, IncludeConsumption);
        if Request.Contains('lines') then
            Events.SetLines(Checked);
        exit(true);
    end;

    local procedure ReadInclude(Token: JsonToken; var IncludeOutput: Boolean; var IncludeConsumption: Boolean; var Argument: Record "Message Argument ori")
    var
        Entry: JsonToken;
        Value: Text;
    begin
        IncludeOutput := false;
        IncludeConsumption := false;
        if not Token.IsArray() then begin
            Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, IncludeLbl, 'include', '', '', IncludeNextLbl);
            exit;
        end;
        foreach Entry in Token.AsArray() do begin
            Value := '';
            if Entry.IsValue() then
                Value := Entry.AsValue().AsText();
            case Value of
                'output':
                    IncludeOutput := true;
                'consumption':
                    IncludeConsumption := true;
                else
                    Argument.AddError("Bifrost Error Code ori"::InvalidParameter, IncludeLbl, 'include', Value, 'output|consumption', IncludeNextLbl);
            end;
        end;
    end;

    local procedure ValidateLines(Lines: JsonArray; ProductionOrder: Record "Production Order"; var Checked: JsonArray; var Argument: Record "Message Argument ori")
    var
        Token: JsonToken;
        Line: JsonObject;
        Index: Integer;
    begin
        for Index := 0 to Lines.Count() - 1 do begin
            Lines.Get(Index, Token);
            if not Token.IsObject() then
                Argument.AddError("Bifrost Error Code ori"::InvalidLine, LinesLbl, StrSubstNo(LineIndexLbl, Index), '', '', LinesNextLbl)
            else begin
                Line := Token.AsObject();
                ValidateLine(Line, Index, ProductionOrder, Argument);
                Checked.Add(Line);
            end;
        end;
    end;

    local procedure ValidateLine(Line: JsonObject; Index: Integer; ProductionOrder: Record "Production Order"; var Argument: Record "Message Argument ori")
    var
        RoutingLine: Record "Prod. Order Routing Line";
        Component: Record "Prod. Order Component";
        Token: JsonToken;
        Kind: Text;
        Prefix: Text;
        Allowed: Text;
        KeyName: Text;
        LineNo: Integer;
        Number: Integer;
        Operation: Text;
    begin
        Prefix := StrSubstNo(LinePrefixLbl, Index);
        if Line.Get('kind', Token) and Token.IsValue() then
            Kind := Token.AsValue().AsText();
        case Kind of
            'output':
                Allowed := 'kind|lineNo|operationNo|outputQuantity|scrapQuantity|setupTime|runTime|finished';
            'consumption':
                Allowed := 'kind|lineNo|componentLineNo|quantity';
            else begin
                Argument.AddError("Bifrost Error Code ori"::InvalidLine, KindLbl, Prefix + 'kind', Kind, 'output|consumption', LinesNextLbl);
                exit;
            end;
        end;
        foreach KeyName in Line.Keys() do
            if not Allowed.Split('|').Contains(KeyName) then
                Argument.AddError("Bifrost Error Code ori"::UnknownParameter, StrSubstNo(UnknownLbl, Prefix + KeyName), Prefix + KeyName, '', '', UnknownNextLbl);
        if not ReadInteger(Line, 'lineNo', LineNo) then begin
            Argument.AddError("Bifrost Error Code ori"::InvalidLine, StrSubstNo(MissingLbl, Prefix + 'lineNo'), Prefix + 'lineNo', '', '', LinesNextLbl);
            exit;
        end;
        if Kind = 'output' then begin
            if Line.Get('operationNo', Token) and Token.IsValue() then
                Operation := Token.AsValue().AsText();
            if Operation = '' then
                Argument.AddError("Bifrost Error Code ori"::InvalidLine, StrSubstNo(MissingLbl, Prefix + 'operationNo'), Prefix + 'operationNo', '', '', LinesNextLbl)
            else begin
                RoutingLine.SetRange(Status, ProductionOrder.Status);
                RoutingLine.SetRange("Prod. Order No.", ProductionOrder."No.");
                RoutingLine.SetRange("Routing Reference No.", LineNo);
                RoutingLine.SetRange("Operation No.", Operation);
                if RoutingLine.IsEmpty() then
                    Argument.AddError("Bifrost Error Code ori"::InvalidLine, StrSubstNo(OperationLbl, Operation, ProductionOrder."No."), Prefix + 'operationNo', Operation, '', OperationNextLbl);
            end;
            CheckNumber(Line, 'outputQuantity', Prefix, Argument);
            CheckNumber(Line, 'scrapQuantity', Prefix, Argument);
            CheckNumber(Line, 'setupTime', Prefix, Argument);
            CheckNumber(Line, 'runTime', Prefix, Argument);
            if Line.Get('finished', Token) then
                if not Token.IsValue() or not (Format(Token.AsValue().AsBoolean()) in ['Yes', 'No']) then
                    Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(NumberLbl, Prefix + 'finished'), Prefix + 'finished', '', '', LinesNextLbl);
        end else begin
            if not ReadInteger(Line, 'componentLineNo', Number) then
                Argument.AddError("Bifrost Error Code ori"::InvalidLine, StrSubstNo(MissingLbl, Prefix + 'componentLineNo'), Prefix + 'componentLineNo', '', '', LinesNextLbl)
            else
                if not Component.Get(ProductionOrder.Status, ProductionOrder."No.", LineNo, Number) then
                    Argument.AddError("Bifrost Error Code ori"::InvalidLine, StrSubstNo(ComponentLbl, Number, ProductionOrder."No."), Prefix + 'componentLineNo', Format(Number), '', LineNextLbl);
            CheckNumber(Line, 'quantity', Prefix, Argument);
        end;
    end;

    local procedure ReadInteger(Line: JsonObject; KeyName: Text; var Number: Integer): Boolean
    var
        Token: JsonToken;
        Raw: Text;
    begin
        if not Line.Get(KeyName, Token) then
            exit(false);
        Token.WriteTo(Raw);
        exit(Token.IsValue() and (CopyStr(Raw, 1, 1) <> '"') and Evaluate(Number, Raw, 9));
    end;

    local procedure CheckNumber(Line: JsonObject; KeyName: Text; Prefix: Text; var Argument: Record "Message Argument ori")
    var
        Token: JsonToken;
        Raw: Text;
        Value: Decimal;
    begin
        if not Line.Get(KeyName, Token) then
            exit;
        Token.WriteTo(Raw);
        if not Token.IsValue() or (CopyStr(Raw, 1, 1) = '"') or not Evaluate(Value, Raw, 9) then begin
            Argument.AddError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(NumberLbl, Prefix + KeyName), Prefix + KeyName, Raw, '', LinesNextLbl);
            exit;
        end;
        if Value < 0 then
            Argument.AddError("Bifrost Error Code ori"::InvalidParameter, NegativeLbl, Prefix + KeyName, Raw, '', LinesNextLbl);
    end;
}
