namespace Origo.Bifrost.Manufacturing.Test;

using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Tests journal message registration and required-parameter error handling.
/// </summary>
codeunit 97604 "Mfg Journal Tst ori"
{
    Subtype = Test;
    TestPermissions = Restrictive;

    var
        Assert: Codeunit "Library Assert";

    /// <summary>Returns an error response when the journal template name is missing.</summary>
    [Test]
    procedure JournalActions_MissingTemplate_ReturnError()
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        ResponseJson: JsonObject;
        ResponseToken: JsonToken;
        MessageType: Enum "Message Type ori";
        ResponseText: Text;
        ResponseContentType: Text[100];
        MessageTypeOrdinal: Integer;
    begin
        RequestContent.AddText('{}');
        for MessageTypeOrdinal := 10077044 to 10077046 do begin
            MessageType := Enum::"Message Type ori".FromInteger(MessageTypeOrdinal);

            Dispatcher.Execute(
                MessageType,
                Enum::"Message Version ori"::"1.0",
                '',
                'test',
                'text/json',
                RequestContent,
                ResponseContent,
                ResponseContentType);

            ResponseContent.GetSubText(ResponseText, 1, 2048);
            ResponseJson.ReadFrom(ResponseText);
            Assert.IsTrue(ResponseJson.Get('status', ResponseToken), 'The response should include a status.');
            Assert.AreEqual('Error', ResponseToken.AsValue().AsText(), 'A missing journal template should return an error.');
            Assert.IsTrue(ResponseJson.Get('code', ResponseToken), 'The refusal must include a stable error code.');
            Assert.AreEqual('MissingParameter', ResponseToken.AsValue().AsText(), 'Expected the precise missing-parameter code.');
            Clear(ResponseContent);
            Clear(ResponseJson);
        end;
    end;

    /// <summary>Returns an error response when a production ledger entry number is missing.</summary>
    [Test]
    procedure ReversePosting_MissingEntryNo_ReturnsError()
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        ResponseJson: JsonObject;
        ResponseToken: JsonToken;
        MessageType: Enum "Message Type ori";
        ResponseText: Text;
        ResponseContentType: Text[100];
    begin
        RequestContent.AddText('{"ledgerType":"Item"}');
        MessageType := MessageType::"Manufacturing.Journal.ReversePosting";

        Dispatcher.Execute(
            MessageType,
            Enum::"Message Version ori"::"1.0",
            '',
            'test',
            'text/json',
            RequestContent,
            ResponseContent,
            ResponseContentType);

        ResponseContent.GetSubText(ResponseText, 1, 2048);
        ResponseJson.ReadFrom(ResponseText);
        Assert.IsTrue(ResponseJson.Get('status', ResponseToken), 'The response should include a status.');
        Assert.AreEqual('Error', ResponseToken.AsValue().AsText(), 'A missing entry number should return an error.');
            Assert.IsTrue(ResponseJson.Get('code', ResponseToken), 'The refusal must include a stable error code.');
            Assert.AreEqual('MissingParameter', ResponseToken.AsValue().AsText(), 'Expected the precise missing-parameter code.');
    end;
}