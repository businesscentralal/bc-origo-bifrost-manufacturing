namespace Origo.Bifrost.Manufacturing.Test;

using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Tests calendar recalculation dispatch and missing-input responses.
/// </summary>
codeunit 97607 "Mfg Calendar Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    /// <summary>Returns an error response when calendar recalculation inputs are missing.</summary>
    [Test]
    procedure Recalculate_MissingCapacityType_ReturnsError()
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        MessageType: Enum "Message Type ori";
        ResponseJson: JsonObject;
        ResponseToken: JsonToken;
        ResponseText: Text;
        ResponseContentType: Text[100];
    begin
        RequestContent.AddText('{}');
        MessageType := MessageType::"Manufacturing.Calendar.Recalculate";

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
        Assert.AreEqual('Error', ResponseToken.AsValue().AsText(), 'Missing capacity type should return an error.');
    end;
}