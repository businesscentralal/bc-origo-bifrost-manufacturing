namespace Origo.Bifrost.Manufacturing.Test;

using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Tests routing message registration and required-parameter error handling.
/// </summary>
codeunit 97606 "Mfg Routing Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    /// <summary>Returns an error response when a routing number is missing.</summary>
    [Test]
    procedure RoutingActions_MissingRoutingNo_ReturnError()
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
        for MessageTypeOrdinal := 10077050 to 10077051 do begin
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
            Assert.AreEqual('Error', ResponseToken.AsValue().AsText(), 'A missing routing number should return an error.');
            Clear(ResponseContent);
            Clear(ResponseJson);
        end;
    end;
}