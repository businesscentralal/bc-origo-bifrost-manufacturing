namespace Origo.Bifrost.Manufacturing;

using Microsoft.Manufacturing.Document;
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
        ProductionOrder: Record "Production Order";
        Request: Codeunit "Prod Jnl Request ori";
        Builder: Codeunit "Prod Jnl Builder ori";
        Events: Codeunit "Prod Jnl Events ori";
        Lines: JsonArray;
        Result: JsonObject;
        Token: JsonToken;
        NothingToPost: Boolean;
        OrderNo: Code[20];
        Mode: Integer;
        LineNo: Integer;
        IncludeOutput: Boolean;
        IncludeConsumption: Boolean;
        HasLines: Boolean;
        SummaryLbl: Label '%1 journal lines for production order %2', Comment = '%1 = line count, %2 = order number, is-IS=%1 línur í framleiðslubók fyrir framleiðslupöntun %2';
    begin
        if Events.InBoundary() then begin
            Events.GetRequest(Mode, OrderNo, LineNo, IncludeOutput, IncludeConsumption, HasLines, Lines);
            Count := Builder.CountLines(OrderNo);
        end else begin
            // Foundation asks before the Impl runs: build, count and roll back in a boundary of its own.
            if not Request.Read(Argument, 2, ProductionOrder) then
                exit(false);
            Events.GetRequest(Mode, OrderNo, LineNo, IncludeOutput, IncludeConsumption, HasLines, Lines);
            Events.SetMode(3);
            if Codeunit.Run(Codeunit::"Prod Jnl Post Proc ori", Argument) then;
            if not Events.GetOutcome(Result, NothingToPost) then
                exit(false);
            if Result.Get('count', Token) then
                Count := Token.AsValue().AsInteger();
            Events.SetInBoundary(false);
        end;
        Summary := StrSubstNo(SummaryLbl, Count, OrderNo);
        exit(true);
    end;
}
