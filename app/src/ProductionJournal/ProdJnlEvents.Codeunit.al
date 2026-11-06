namespace Origo.Bifrost.Manufacturing;

using Microsoft.Manufacturing.Journal;

/// <summary>
/// Carries the validated request from an Impl codeunit to its Codeunit.Run boundary and the result back,
/// and sets the posting date and consumption basis that Production Journal Mgt keeps private.
/// </summary>
codeunit 10077078 "Prod Jnl Events ori"
{
    Access = Internal;
    SingleInstance = true;

    var
        Active: Boolean;
        InBoundaryValue: Boolean;
        HasDate: Boolean;
        DateValue: Date;
        HasBasis: Boolean;
        BasisValue: Integer;
        UsedBasis: Integer;
        UsedDate: Date;
        ModeValue: Integer;
        OrderNoValue: Code[20];
        LineNoValue: Integer;
        IncludeOutputValue: Boolean;
        IncludeConsumptionValue: Boolean;
        LinesValue: JsonArray;
        HasLinesValue: Boolean;
        ResultValue: JsonObject;
        CompletedValue: Boolean;
        NothingValue: Boolean;
        TemplateValue: Code[10];
        BatchValue: Code[10];
        PreviewLinesValue: Integer;

    /// <summary>Stores the validated request. Mode: 0 Get, 1 PreviewPost, 2 Post.</summary>
    internal procedure SetRequest(Mode: Integer; OrderNo: Code[20]; LineNo: Integer; NewHasDate: Boolean; NewDate: Date; NewHasBasis: Boolean; NewBasis: Integer; IncludeOutput: Boolean; IncludeConsumption: Boolean)
    begin
        Clear(ResultValue);
        Clear(LinesValue);
        HasLinesValue := false;
        CompletedValue := false;
        NothingValue := false;
        Active := true;
        ModeValue := Mode;
        OrderNoValue := OrderNo;
        LineNoValue := LineNo;
        HasDate := NewHasDate;
        DateValue := NewDate;
        HasBasis := NewHasBasis;
        BasisValue := NewBasis;
        IncludeOutputValue := IncludeOutput;
        IncludeConsumptionValue := IncludeConsumption;
    end;

    /// <summary>Stores the validated lines of the request.</summary>
    internal procedure SetLines(Lines: JsonArray)
    begin
        LinesValue := Lines;
        HasLinesValue := true;
    end;

    /// <summary>Returns the stored request.</summary>
    internal procedure GetRequest(var Mode: Integer; var OrderNo: Code[20]; var LineNo: Integer; var IncludeOutput: Boolean; var IncludeConsumption: Boolean; var HasLines: Boolean; var Lines: JsonArray)
    begin
        Mode := ModeValue;
        OrderNo := OrderNoValue;
        LineNo := LineNoValue;
        IncludeOutput := IncludeOutputValue;
        IncludeConsumption := IncludeConsumptionValue;
        HasLines := HasLinesValue;
        Lines := LinesValue;
    end;

    /// <summary>Stores the journal batch the boundary built in.</summary>
    internal procedure SetBatch(Template: Code[10]; Batch: Code[10])
    begin
        TemplateValue := Template;
        BatchValue := Batch;
    end;

    /// <summary>Returns the journal batch the boundary built in.</summary>
    internal procedure GetBatch(var Template: Code[10]; var Batch: Code[10])
    begin
        Template := TemplateValue;
        Batch := BatchValue;
    end;

    /// <summary>Stores the result and marks the boundary as completed.</summary>
    internal procedure SetResult(Result: JsonObject)
    begin
        ResultValue := Result;
        CompletedValue := true;
    end;

    /// <summary>Marks that the journal had nothing left to post.</summary>
    internal procedure SetNothingToPost()
    begin
        NothingValue := true;
        CompletedValue := true;
    end;

    /// <summary>Returns the outcome of the boundary.</summary>
    internal procedure GetOutcome(var Result: JsonObject; var NothingToPost: Boolean): Boolean
    begin
        Result := ResultValue;
        NothingToPost := NothingValue;
        exit(CompletedValue);
    end;

    /// <summary>Returns the posting date and consumption basis (0 actual, 1 expected) that the journal was built with.</summary>
    internal procedure GetUsedSetup(var PostingDate: Date; var Basis: Integer)
    begin
        PostingDate := UsedDate;
        Basis := UsedBasis;
    end;

    /// <summary>Marks that the posting boundary has built the journal lines.</summary>
    internal procedure SetInBoundary(IsInside: Boolean)
    begin
        InBoundaryValue := IsInside;
    end;

    /// <summary>True while the journal lines of the request exist in the current transaction.</summary>
    internal procedure InBoundary(): Boolean
    begin
        exit(InBoundaryValue);
    end;

    /// <summary>Switches the mode of the stored request (3 counts the lines that would post).</summary>
    internal procedure SetMode(Mode: Integer)
    begin
        ModeValue := Mode;
        CompletedValue := false;
    end;

    /// <summary>Stores the number of lines that the preview covers.</summary>
    internal procedure SetPreviewLines(LinesToPost: Integer)
    begin
        PreviewLinesValue := LinesToPost;
    end;

    /// <summary>Returns the number of lines the preview covered.</summary>
    internal procedure GetPreviewLines(): Integer
    begin
        exit(PreviewLinesValue);
    end;

    /// <summary>Ends the request.</summary>
    internal procedure EndRequest()
    begin
        Active := false;
        InBoundaryValue := false;
        HasDate := false;
        HasBasis := false;
        HasLinesValue := false;
        CompletedValue := false;
        NothingValue := false;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Production Journal Mgt", OnAfterInitSetupValues, '', false, false)]
    local procedure SetDateAndBasis(var PostingDate: Date; var CalcBasedOn: Option "Actual Output","Expected Output")
    begin
        if not Active then
            exit;
        if HasDate then
            PostingDate := DateValue;
        if HasBasis then
            CalcBasedOn := BasisValue;
        UsedDate := PostingDate;
        UsedBasis := CalcBasedOn;
    end;
}
