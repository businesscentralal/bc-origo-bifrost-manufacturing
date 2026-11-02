namespace Origo.Bifrost.Manufacturing.Test;

using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Tests production BOM message registration and required-parameter error handling.
/// </summary>
codeunit 97605 "Mfg BOM Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    /// <summary>Returns an error response when a BOM number is missing.</summary>
    [Test]
    procedure BOMActions_MissingProductionBOM_ReturnsError()
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
        for MessageTypeOrdinal := 10077048 to 10077049 do begin
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
            Assert.AreEqual('Error', ResponseToken.AsValue().AsText(), 'A missing BOM number should return an error.');
            Clear(ResponseContent);
            Clear(ResponseJson);
        end;
    end;
}