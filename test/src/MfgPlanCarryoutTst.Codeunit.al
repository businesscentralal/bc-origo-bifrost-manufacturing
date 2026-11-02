namespace Origo.Bifrost.Manufacturing.Test;

using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Tests production planning carry-out validation through Foundation's dispatcher.
/// </summary>
codeunit 97610 "Mfg Plan Carryout Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    /// <summary>Returns an error response when the worksheet template is missing.</summary>
    [Test]
    procedure CarryOutProduction_MissingTemplate_ReturnsError()
    var
        Dispatcher: Codeunit "Dispatcher ori";
        MessageType: Enum "Message Type ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        ResponseJson: JsonObject;
        ResponseToken: JsonToken;
        ResponseText: Text;
        ResponseContentType: Text[100];
    begin
        RequestContent.AddText('{}');
        MessageType := MessageType::"Manufacturing.Planning.CarryOutProduction";

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
        Assert.AreEqual('Error', ResponseToken.AsValue().AsText(), 'A missing worksheet template should return an error.');
    end;
}