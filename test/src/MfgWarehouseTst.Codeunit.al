namespace Origo.Bifrost.Manufacturing.Test;

using Origo.Bifrost;
using System.TestLibraries.Security.AccessControl;
using System.TestLibraries.Utilities;

/// <summary>
/// Tests production warehouse action registration and missing-order errors.
/// </summary>
codeunit 97612 "Mfg Warehouse Tst ori"
{
    Subtype = Test;
    TestPermissions = Restrictive;

    var
        Assert: Codeunit "Library Assert";
        LowerPermissions: Codeunit "Library - Lower Permissions";

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
        InitializePermissions();
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
            Assert.IsTrue(ResponseJson.Get('code', ResponseToken), 'The refusal must include a stable error code.');
            Assert.AreEqual('MissingParameter', ResponseToken.AsValue().AsText(), 'Expected the precise missing-parameter code.');
            Clear(ResponseContent);
            Clear(ResponseJson);
        end;
    end;
    local procedure InitializePermissions()
    begin
        LowerPermissions.SetOutsideO365Scope();
        LowerPermissions.SetExactPermissionSet('D365 BUS PREMIUM');
        LowerPermissions.AddPermissionSet('BIFROST Full ori');
    end;
}
