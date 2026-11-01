namespace Origo.Bifrost.Manufacturing;

using Origo.Bifrost.Foundation;

/// <summary>
/// Provides documentation contracts for Manufacturing.ProductionBOM.SetStatus and Manufacturing.Routing.SetStatus.
/// </summary>
codeunit 10077086 "Mfg BOMRtg Contract ori"
{
    Access = Internal;
    SingleInstance = true;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Msg Discovery ori", 'OnDiscoverMessageContracts', '', false, false)]
    local procedure AddContracts(var MsgDiscovery: Codeunit "Msg Discovery ori")
    begin
        AddProdBOMSetStatusContract(MsgDiscovery);
        AddRoutingSetStatusContract(MsgDiscovery);
    end;

    local procedure AddProdBOMSetStatusContract(var MsgDiscovery: Codeunit "Msg Discovery ori")
    var
        MessageType: Enum "Message Type ori";
        Domain: Codeunit "Msg Contract Domain ori";
        Entity: Codeunit "Msg Contract Entity ori";
        ActionDef: Codeunit "Msg Contract Action ori";
        Contract: Codeunit "Msg Contract ori";
    begin
        MessageType := Enum::"Message Type ori"::"Manufacturing.ProductionBOM.SetStatus";
        Domain := MsgDiscovery.GetDomain('Manufacturing');
        Entity := Domain.GetEntity('ProductionBOM');
        ActionDef := Entity.AddAction('SetStatus', MessageType);
        
        Contract := ActionDef.GetContract();
        Contract.SetOverview('Certifies a production BOM or one of its versions, or sets it back to Under Development, with the standard Business Central checks.');
        Contract.SetIcelandicOverview('Staðfestir framleiðsluefnislista eða útgáfu hans, eða setur hann aftur í þróun, með venjulegum athugunum Business Central.');

        Contract.AddEffect('write');
        Contract.SetIdempotent(true);
        Contract.SetPermissionSet('BIFROST Mfg ori');
        Contract.AddPrecondition('The BOM or version must exist.');
        Contract.AddNote('Closing a BOM (status `Closed` or `New`) is not supported. Closing asks a question that cannot be answered without a screen, so Business Central would silently keep the old status.');

        Contract.AddParameter('no', 'string', true, 'The production BOM number.');
        Contract.AddParameter('versionCode', 'string', false, 'The version code to change. If omitted, the BOM header status is changed.');
        Contract.AddParameter('status', 'string', true, 'The new status. Allowed values: `Certified` or `UnderDevelopment`.');

        Contract.AddResponseField('no', 'string', 'The production BOM number.');
        Contract.AddResponseField('versionCode', 'string', 'The version code changed, or empty if the header was changed.');
        Contract.AddResponseField('previousStatus', 'string', 'The status before the change.');
        Contract.AddResponseField('status', 'string', 'The status after the change.');
        Contract.AddResponseField('changed', 'boolean', 'True if the status was changed, false if it already had the requested status.');
        Contract.AddResponseField('lowLevelCode', 'integer', 'The calculated low-level code (when the header status is changed).');
        Contract.AddResponseField('usedOnItems', 'integer', 'The number of items using this production BOM (when the header status is changed).');

        Contract.AddError('MissingParameter');
        Contract.AddError('InvalidParameter');
        Contract.AddError('RecordNotFound');
        Contract.AddError('MultipleErrors');
        Contract.AddError('UnknownParameter');
        Contract.AddError('BusinessCentralError');
        Contract.AddError('Retryable');

        Contract.AddRelatedMessageType(Enum::"Message Type ori"::"Data.Records.Set", 'To edit the BOM lines when Under Development.');

        Contract.AddExample('Certify a BOM header',
            '{"no": "BOM001", "status": "Certified"}',
            '{"no": "BOM001", "versionCode": "", "previousStatus": "Under Development", "status": "Certified", "changed": true, "lowLevelCode": 1, "usedOnItems": 0}');
            
        Contract.AddExample('Set a version to under development',
            '{"no": "BOM001", "versionCode": "V1", "status": "UnderDevelopment"}',
            '{"no": "BOM001", "versionCode": "V1", "previousStatus": "Certified", "status": "Under Development", "changed": true}');
    end;

    local procedure AddRoutingSetStatusContract(var MsgDiscovery: Codeunit "Msg Discovery ori")
    var
        MessageType: Enum "Message Type ori";
        Domain: Codeunit "Msg Contract Domain ori";
        Entity: Codeunit "Msg Contract Entity ori";
        ActionDef: Codeunit "Msg Contract Action ori";
        Contract: Codeunit "Msg Contract ori";
    begin
        MessageType := Enum::"Message Type ori"::"Manufacturing.Routing.SetStatus";
        Domain := MsgDiscovery.GetDomain('Manufacturing');
        Entity := Domain.GetEntity('Routing');
        ActionDef := Entity.AddAction('SetStatus', MessageType);
        
        Contract := ActionDef.GetContract();
        Contract.SetOverview('Certifies a routing or one of its versions, or sets it back to Under Development, with the standard Business Central checks.');
        Contract.SetIcelandicOverview('Staðfestir vinnsluleið eða útgáfu hennar, eða setur hana aftur í þróun, með venjulegum athugunum Business Central.');

        Contract.AddEffect('write');
        Contract.SetIdempotent(true);
        Contract.SetPermissionSet('BIFROST Mfg ori');
        Contract.AddPrecondition('The routing or version must exist.');
        Contract.AddNote('Closing a routing (status `Closed` or `New`) is not supported. Closing asks a question that cannot be answered without a screen, so Business Central would silently keep the old status.');

        Contract.AddParameter('no', 'string', true, 'The routing number.');
        Contract.AddParameter('versionCode', 'string', false, 'The version code to change. If omitted, the routing header status is changed.');
        Contract.AddParameter('status', 'string', true, 'The new status. Allowed values: `Certified` or `UnderDevelopment`.');

        Contract.AddResponseField('no', 'string', 'The routing number.');
        Contract.AddResponseField('versionCode', 'string', 'The version code changed, or empty if the header was changed.');
        Contract.AddResponseField('previousStatus', 'string', 'The status before the change.');
        Contract.AddResponseField('status', 'string', 'The status after the change.');
        Contract.AddResponseField('changed', 'boolean', 'True if the status was changed, false if it already had the requested status.');
        Contract.AddResponseField('usedOnItems', 'integer', 'The number of items using this routing (when the header status is changed).');

        Contract.AddError('MissingParameter');
        Contract.AddError('InvalidParameter');
        Contract.AddError('RecordNotFound');
        Contract.AddError('MultipleErrors');
        Contract.AddError('UnknownParameter');
        Contract.AddError('BusinessCentralError');
        Contract.AddError('Retryable');

        Contract.AddRelatedMessageType(Enum::"Message Type ori"::"Data.Records.Set", 'To edit the routing lines when Under Development.');

        Contract.AddExample('Certify a routing header',
            '{"no": "RTG001", "status": "Certified"}',
            '{"no": "RTG001", "versionCode": "", "previousStatus": "Under Development", "status": "Certified", "changed": true, "usedOnItems": 0}');
            
        Contract.AddExample('Set a version to under development',
            '{"no": "RTG001", "versionCode": "V1", "status": "UnderDevelopment"}',
            '{"no": "RTG001", "versionCode": "V1", "previousStatus": "Certified", "status": "Under Development", "changed": true}');
    end;
}
