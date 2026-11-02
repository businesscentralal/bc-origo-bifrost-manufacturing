namespace Origo.Bifrost.Manufacturing.Test;

using Origo.Bifrost;
using System.TestLibraries.Security.AccessControl;
using System.TestLibraries.Utilities;

/// <summary>
/// Tests production order refresh dispatch and its invalid-order response.
/// </summary>
codeunit 97603 "Mfg Refresh Order Tst ori"
{
    Subtype = Test;
    TestPermissions = Restrictive;

    var
        Assert: Codeunit "Library Assert";
        LowerPermissions: Codeunit "Library - Lower Permissions";

    /// <summary>Returns an error response when the requested production order does not exist.</summary>
    [Test]
    procedure Refresh_UnknownOrder_ReturnsError()
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
        InitializePermissions();
        RequestContent.AddText('{"productionOrderNo":"X-MISSING"}');
        MessageType := Enum::"Message Type ori".FromInteger(10077040);

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
        Assert.AreEqual('Error', ResponseToken.AsValue().AsText(), 'An unknown production order should return an error.');
        Assert.IsTrue(ResponseJson.Get('code', ResponseToken), 'The refusal must include a stable error code.');
        Assert.AreEqual('RecordNotFound', ResponseToken.AsValue().AsText(), 'Expected the precise missing-record code.');
    end;

    /// <summary>Returns an error response when no production order number is supplied.</summary>
    [Test]
    procedure Refresh_MissingOrderNumber_ReturnsError()
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
        InitializePermissions();
        RequestContent.AddText('{}');
        MessageType := Enum::"Message Type ori".FromInteger(10077040);

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
        Assert.AreEqual('Error', ResponseToken.AsValue().AsText(), 'A missing production order number should return an error.');
        Assert.IsTrue(ResponseJson.Get('code', ResponseToken), 'The refusal must include a stable error code.');
        Assert.AreEqual('MissingParameter', ResponseToken.AsValue().AsText(), 'Expected the precise missing-parameter code.');
    end;

    /// <summary>Returns an error response when the requested production order cannot be replanned.</summary>
    [Test]
    procedure Replan_UnknownOrder_ReturnsError()
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
        InitializePermissions();
        RequestContent.AddText('{"productionOrderNo":"X-MISSING"}');
        MessageType := Enum::"Message Type ori".FromInteger(10077041);

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
        Assert.AreEqual('Error', ResponseToken.AsValue().AsText(), 'An unknown production order should return an error.');
        Assert.IsTrue(ResponseJson.Get('code', ResponseToken), 'The refusal must include a stable error code.');
        Assert.AreEqual('RecordNotFound', ResponseToken.AsValue().AsText(), 'Expected the precise missing-record code.');
    end;

    /// <summary>Returns an error response when the requested production order cannot have its cost updated.</summary>
    [Test]
    procedure UpdateCost_UnknownOrder_ReturnsError()
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
        InitializePermissions();
        RequestContent.AddText('{"productionOrderNo":"X-MISSING"}');
        MessageType := Enum::"Message Type ori".FromInteger(10077043);

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
        Assert.AreEqual('Error', ResponseToken.AsValue().AsText(), 'An unknown production order should return an error.');
        Assert.IsTrue(ResponseJson.Get('code', ResponseToken), 'The refusal must include a stable error code.');
        Assert.AreEqual('RecordNotFound', ResponseToken.AsValue().AsText(), 'Expected the precise missing-record code.');
    end;

    /// <summary>Exposes descriptions and request contracts for all production-order message types.</summary>
    [Test]
    procedure ProductionOrderMessageTypes_HaveDescriptionsAndContracts()
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        MessageTypeInterface: Interface "Msg Interface ori";
        MessageType: Enum "Message Type ori";
        Contract: JsonObject;
        MessageTypeOrdinal: Integer;
    begin
        InitializePermissions();
        for MessageTypeOrdinal := 10077040 to 10077043 do begin
            MessageType := Enum::"Message Type ori".FromInteger(MessageTypeOrdinal);
            MessageTypeInterface := MessageType;

            Assert.IsTrue(MessageTypeInterface.IsEnabled(), 'Every production-order message type should be enabled.');
            Assert.IsTrue(StrLen(MessageTypeInterface.GetDescription()) > 20, 'Every production-order message type should have a useful description.');

            Clear(Contract);
            ContractMgt.GetContract(MessageType, Contract);
            Assert.IsTrue(Contract.Contains('envelope'), 'Every operation should describe its request envelope.');
            Assert.IsTrue(Contract.Contains('parameters'), 'Every operation should describe its parameters.');
            Assert.IsTrue(Contract.Contains('response'), 'Every operation should describe its response.');
        end;
    end;
    local procedure InitializePermissions()
    begin
        LowerPermissions.SetOutsideO365Scope();
        LowerPermissions.SetExactPermissionSet('D365 BUS PREMIUM');
        LowerPermissions.AddPermissionSet('BIFROST Full ori');
    end;
}
