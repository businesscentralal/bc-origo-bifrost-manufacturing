namespace Origo.Bifrost.Manufacturing.Test;

using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Tests calendar absence message validation through the Foundation dispatcher.
/// </summary>
codeunit 97608 "Mfg Absence Tst ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    /// <summary>Returns an error response when absence capacity type is missing.</summary>
    [Test]
    procedure UpdateAbsence_MissingCapacityType_ReturnsError()
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
        MessageType := MessageType::"Manufacturing.Calendar.UpdateAbsence";

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

    /// <summary>Returns an error response when absence capacity type is missing for removal.</summary>
    [Test]
    procedure RemoveAbsence_MissingCapacityType_ReturnsError()
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
        RequestContent.AddText('{}');
        MessageType := Enum::"Message Type ori".FromInteger(10077059);

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