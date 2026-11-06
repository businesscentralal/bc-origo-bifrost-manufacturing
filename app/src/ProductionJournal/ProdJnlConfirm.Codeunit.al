namespace Origo.Bifrost.Manufacturing;

using Origo.Bifrost;

/// <summary>Counts the non-empty production journal lines that Post is about to post.</summary>
codeunit 10077079 "Prod Jnl Confirm ori" implements "Msg Confirm ori"
{
    Access = Internal;

    /// <summary>
    /// Returns the number of non-empty journal lines and a localized summary. Foundation calls this from
    /// the posting boundary after the lines have been built, so the count is the count that posts.
    /// </summary>
    procedure GetConfirmCount(var Argument: Record "Message Argument ori"; var Count: Integer; var Summary: Text): Boolean
    var
        Builder: Codeunit "Prod Jnl Builder ori";
        Events: Codeunit "Prod Jnl Events ori";
        Lines: JsonArray;
        OrderNo: Code[20];
        Mode: Integer;
        LineNo: Integer;
        IncludeOutput: Boolean;
        IncludeConsumption: Boolean;
        HasLines: Boolean;
        SummaryLbl: Label '%1 journal lines for production order %2', Comment = '%1 = line count, %2 = order number, is-IS=%1 línur í framleiðslubók fyrir framleiðslupöntun %2';
    begin
        Events.GetRequest(Mode, OrderNo, LineNo, IncludeOutput, IncludeConsumption, HasLines, Lines);
        Count := Builder.CountLines(OrderNo);
        Summary := StrSubstNo(SummaryLbl, Count, OrderNo);
        exit(true);
    end;
}
