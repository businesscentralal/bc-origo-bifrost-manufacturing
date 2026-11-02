namespace Origo.Bifrost.Manufacturing.Test;

using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>
/// Contract chapters for the two status message types.
/// Manufacturing.ProductionOrder.Refresh is not named: that type is issue 5 and is not in this app yet.
/// </summary>
codeunit 97663 "BOM Routing Contract Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure AC14_BothTypes_DeclareTheRequiredChapters()
    begin
        AssertContract(Enum::"Message Type ori"::"Manufacturing.ProductionBOM.SetStatus");
        AssertContract(Enum::"Message Type ori"::"Manufacturing.Routing.SetStatus");
    end;

    [Test]
    procedure AC15_CatalogueTextsMatchTheStory()
    var
        Bom: Interface "Msg Interface ori";
        Routing: Interface "Msg Interface ori";
    begin
        Bom := Enum::"Message Type ori"::"Manufacturing.ProductionBOM.SetStatus";
        Routing := Enum::"Message Type ori"::"Manufacturing.Routing.SetStatus";
        Assert.AreEqual('Certifies a production BOM or one of its versions, or sets it back to Under Development, with the standard Business Central checks.', Bom.GetDescription(), 'BOM description');
        Assert.AreEqual('Certifies a routing or one of its versions, or sets it back to Under Development, with the standard Business Central checks.', Routing.GetDescription(), 'routing description');
    end;

    local procedure AssertContract(MessageType: Enum "Message Type ori")
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Contract: JsonObject;
        Effect: JsonObject;
        Notes: Text;
        ErrorsText: Text;
        ParametersText: Text;
        EffectToken: JsonToken;
    begin
        Assert.IsTrue(ContractMgt.GetContract(MessageType, Contract), 'contract');
        Assert.IsTrue(Contract.Contains('envelope'), 'envelope');
        Assert.IsTrue(Contract.Contains('target'), 'target');
        Assert.IsTrue(Contract.Contains('parameters'), 'parameters');
        Assert.IsTrue(Contract.Contains('response'), 'response');
        Assert.IsTrue(Contract.Contains('errors'), 'errors');
        Assert.IsTrue(Contract.Contains('effect'), 'effect');
        Assert.IsTrue(Contract.Contains('related'), 'related');
        Assert.IsTrue(Contract.Contains('workflow'), 'workflow');
        Assert.IsTrue(Contract.Contains('examples'), 'examples');
        Assert.IsTrue(Contract.Contains('overview'), 'overview');
        Assert.IsTrue(Contract.Contains('notes'), 'notes');
        Assert.IsTrue(Contract.Contains('metering'), 'metering');

        Contract.WriteTo(ParametersText);
        Assert.IsTrue(ParametersText.Contains('"no"'), 'parameter no');
        Assert.IsTrue(ParametersText.Contains('versionCode'), 'parameter versionCode');
        Assert.IsTrue(ParametersText.Contains('status'), 'parameter status');
        Assert.IsTrue(ParametersText.Contains('Retryable'), 'Retryable');
        Assert.IsTrue(ParametersText.Contains('Data.Records.Get'), 'related get');
        Assert.IsTrue(ParametersText.Contains('Data.Records.Set'), 'related set');
        Assert.IsFalse(ParametersText.Contains('Manufacturing.ProductionOrder.Refresh'), 'refresh is not declared');

        Contract.Get('effect', EffectToken);
        Effect := EffectToken.AsObject();
        Assert.AreEqual('write', ReadText(Effect, 'effect'), 'effect');
        Assert.AreEqual(true, ReadBoolean(Effect, 'idempotent'), 'idempotent');
        Assert.AreEqual('BIFROST Mfg ori', ReadText(Effect, 'permissionSet'), 'permissionSet');

        Notes := ReadText(Contract, 'notes');
        Assert.IsTrue(Notes.Contains('without a screen'), 'notes explain Closed');
        ErrorsText := ParametersText;
        Assert.IsTrue(ErrorsText.Contains('PreconditionFailed'), 'PreconditionFailed is declared');
    end;

    local procedure ReadText(Object: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        Object.Get(PropertyName, Token);
        exit(Token.AsValue().AsText());
    end;

    local procedure ReadBoolean(Object: JsonObject; PropertyName: Text): Boolean
    var
        Token: JsonToken;
    begin
        Object.Get(PropertyName, Token);
        exit(Token.AsValue().AsBoolean());
    end;
}
