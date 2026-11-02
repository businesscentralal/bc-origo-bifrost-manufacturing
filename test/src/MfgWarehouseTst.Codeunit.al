namespace Origo.Bifrost.Manufacturing.Test;

using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Tests production warehouse action registration and missing-order errors.
/// </summary>
codeunit 97612 "Mfg Warehouse Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    /// <summary>Returns an error response when a released production order is missing.</summary>
    [Test]
    procedure WarehouseActions_MissingOrder_ReturnError()
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
        for MessageTypeOrdinal := 10077057 to 10077058 do begin
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
            Assert.AreEqual('Error', ResponseToken.AsValue().AsText(), 'A missing production order should return an error.');
            Clear(ResponseContent);
            Clear(ResponseJson);
        end;
    end;
}