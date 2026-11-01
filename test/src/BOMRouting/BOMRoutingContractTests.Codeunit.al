namespace Origo.Bifrost.Manufacturing.Test;

using Origo.Bifrost.Foundation;
using System.TestLibraries.Utilities;

codeunit 97663 "BOM Routing Contract Tests ori"
{
    Subtype = Test;

    var
        LibraryAssert: Codeunit "Library Assert";

    [Test]
    procedure ProdBOMSetStatusContractHasRequiredParts()
    var
        MsgDiscovery: Codeunit "Msg Discovery ori";
        Domain: Codeunit "Msg Contract Domain ori";
        Entity: Codeunit "Msg Contract Entity ori";
        ActionDef: Codeunit "Msg Contract Action ori";
        Contract: Codeunit "Msg Contract ori";
    begin
        MsgDiscovery.LoadDiscoveryData();
        Domain := MsgDiscovery.GetDomain('Manufacturing');
        Entity := Domain.GetEntity('ProductionBOM');
        ActionDef := Entity.GetAction('SetStatus');
        Contract := ActionDef.GetContract();

        LibraryAssert.AreEqual('Manufacturing.ProductionBOM.SetStatus', Contract.GetMessageType(), 'Message Type');
        LibraryAssert.IsTrue(Contract.GetOverview() <> '', 'Overview');
        LibraryAssert.AreEqual('write', Contract.GetEffect(), 'Effect');
        LibraryAssert.IsTrue(Contract.IsIdempotent(), 'Idempotent');
        LibraryAssert.IsTrue(Contract.GetParameters().Count > 0, 'Parameters');
        LibraryAssert.IsTrue(Contract.GetResponseFields().Count > 0, 'Response Fields');
        LibraryAssert.IsTrue(Contract.GetErrors().Count > 0, 'Errors');
        LibraryAssert.IsTrue(Contract.GetExamples().Count > 0, 'Examples');
    end;

    [Test]
    procedure RoutingSetStatusContractHasRequiredParts()
    var
        MsgDiscovery: Codeunit "Msg Discovery ori";
        Domain: Codeunit "Msg Contract Domain ori";
        Entity: Codeunit "Msg Contract Entity ori";
        ActionDef: Codeunit "Msg Contract Action ori";
        Contract: Codeunit "Msg Contract ori";
    begin
        MsgDiscovery.LoadDiscoveryData();
        Domain := MsgDiscovery.GetDomain('Manufacturing');
        Entity := Domain.GetEntity('Routing');
        ActionDef := Entity.GetAction('SetStatus');
        Contract := ActionDef.GetContract();

        LibraryAssert.AreEqual('Manufacturing.Routing.SetStatus', Contract.GetMessageType(), 'Message Type');
        LibraryAssert.IsTrue(Contract.GetOverview() <> '', 'Overview');
        LibraryAssert.AreEqual('write', Contract.GetEffect(), 'Effect');
        LibraryAssert.IsTrue(Contract.IsIdempotent(), 'Idempotent');
        LibraryAssert.IsTrue(Contract.GetParameters().Count > 0, 'Parameters');
        LibraryAssert.IsTrue(Contract.GetResponseFields().Count > 0, 'Response Fields');
        LibraryAssert.IsTrue(Contract.GetErrors().Count > 0, 'Errors');
        LibraryAssert.IsTrue(Contract.GetExamples().Count > 0, 'Examples');
    end;
}
