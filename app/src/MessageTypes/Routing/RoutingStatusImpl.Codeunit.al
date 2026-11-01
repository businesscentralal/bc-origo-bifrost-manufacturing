namespace Origo.Bifrost.Manufacturing;

using Origo.Bifrost.Foundation;
using Microsoft.Manufacturing.Routing;
using Microsoft.Inventory.Item;

/// <summary>
/// Implements Manufacturing.Routing.SetStatus.
/// </summary>
codeunit 10077089 "Routing Status Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    var
        MsgContract: Codeunit "Msg Contract ori";
        NoSupportedStatusErr: Label 'Status %1 is not supported. Send Certified or UnderDevelopment.', Comment = 'is-IS="Staða %1 er ekki studd. Sendu Certified eða UnderDevelopment."', Locked = false;
        NoSupportedStatusNextStepTxt: Label 'Closing asks a question that cannot be answered without a screen, so Business Central would silently keep the old status.', Comment = 'is-IS="Lokun spyr spurningar sem ekki er hægt að svara án skjás, þannig að Business Central héldi gömlu stöðunni án athugasemdar."', Locked = false;
        VersionNotFoundErr: Label 'Version %1 of %2 %3 was not found.', Comment = 'is-IS="Útgáfa %1 af %2 %3 fannst ekki."', Locked = false;
        VersionNotFoundNextStepTxt: Label 'Read the versions with Data.Records.Get.', Comment = 'is-IS="Lestu útgáfurnar með Data.Records.Get."', Locked = false;
        CheckFailedNextStepTxt: Label 'Correct the lines with Data.Records.Set and send the same request again.', Comment = 'is-IS="Lagfærðu línurnar með Data.Records.Set og sendu sömu beiðni aftur."', Locked = false;
        UnchangedTxt: Label '%1 %2 already has status %3. Nothing was changed.', Comment = 'is-IS="%1 %2 er þegar með stöðuna %3. Engu var breytt."', Locked = false;

    trigger OnRun()
    begin
        ExecuteBifrostTask(Rec);
    end;

    local procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        RoutingHeader: Record "Routing Header";
        RoutingVersion: Record "Routing Version";
        RoutingStatusProc: Codeunit "Routing Status Proc ori";
        BOMRoutingContext: Codeunit "BOM Routing Context ori";
        Item: Record Item;
        RoutingNo: Code[20];
        VersionCode: Code[20];
        RequestedStatusTxt: Text;
        RequestedStatus: Enum "Routing Status";
        PreviousStatusTxt: Text;
        PreviousStatus: Enum "Routing Status";
        IsVersion: Boolean;
    begin
        Argument.AssertIsLicensed();
        Argument.AssertVersion1();

        RoutingNo := CopyStr(Argument.GetStringParameter('no', true), 1, MaxStrLen(RoutingNo));
        RequestedStatusTxt := Argument.GetStringParameter('status', true);
        if Argument.HasParameter('versionCode') then begin
            VersionCode := CopyStr(Argument.GetStringParameter('versionCode', false), 1, MaxStrLen(VersionCode));
            IsVersion := true;
        end;

        Argument.RejectUnknownParameters();
        if Argument.HasErrors() then begin
            Argument.RespondWithErrors();
            exit;
        end;

        if (RequestedStatusTxt = 'Certified') then
            RequestedStatus := RequestedStatus::Certified
        else if (RequestedStatusTxt = 'UnderDevelopment') then
            RequestedStatus := RequestedStatus::"Under Development"
        else begin
            Argument.AddError('InvalidParameter', StrSubstNo(NoSupportedStatusErr, RequestedStatusTxt), 'status', NoSupportedStatusNextStepTxt);
            Argument.RespondWithErrors();
            exit;
        end;

        RoutingHeader.SetLoadFields(Status);
        if not RoutingHeader.Get(RoutingNo) then begin
            Argument.AddError('RecordNotFound', Argument.GetRecordNotFoundMessage(Database::"Routing Header", RoutingNo), 'no', Argument.GetRecordNotFoundNextStep());
            Argument.RespondWithErrors();
            exit;
        end;

        if IsVersion then begin
            RoutingVersion.SetLoadFields(Status);
            if not RoutingVersion.Get(RoutingNo, VersionCode) then begin
                Argument.AddError('RecordNotFound', StrSubstNo(VersionNotFoundErr, VersionCode, RoutingHeader.TableCaption(), RoutingNo), 'versionCode', VersionNotFoundNextStepTxt);
                Argument.RespondWithErrors();
                exit;
            end;
            PreviousStatus := RoutingVersion.Status;
        end else
            PreviousStatus := RoutingHeader.Status;

        if PreviousStatus = PreviousStatus::"Under Development" then
            PreviousStatusTxt := 'UnderDevelopment'
        else if PreviousStatus = PreviousStatus::Certified then
            PreviousStatusTxt := 'Certified'
        else if PreviousStatus = PreviousStatus::Closed then
            PreviousStatusTxt := 'Closed'
        else
            PreviousStatusTxt := 'New';

        if PreviousStatus = RequestedStatus then begin
            Argument.SetResponseField('no', RoutingNo);
            if IsVersion then
                Argument.SetResponseField('versionCode', VersionCode)
            else
                Argument.SetResponseField('versionCode', '');
            Argument.SetResponseField('previousStatus', PreviousStatusTxt);
            Argument.SetResponseField('status', RequestedStatusTxt);
            Argument.SetResponseField('changed', false);
            if not IsVersion then begin
                Item.SetRange("Routing No.", RoutingNo);
                Argument.SetResponseField('usedOnItems', Item.Count());
            end;
            Argument.RespondWithSuccess(StrSubstNo(UnchangedTxt, RoutingHeader.TableCaption(), RoutingNo, RequestedStatusTxt));
            exit;
        end;

        RoutingStatusProc.SetParameters(RequestedStatus, VersionCode, IsVersion);
        
        BOMRoutingContext.SetInsideBifrostCall(true);
        if not RoutingStatusProc.Run(RoutingHeader) then begin
            BOMRoutingContext.SetInsideBifrostCall(false);
            Argument.AddError('BusinessCentralError', GetLastErrorText(), '', CheckFailedNextStepTxt);
            Argument.RespondWithErrors();
            exit;
        end;
        BOMRoutingContext.SetInsideBifrostCall(false);

        Argument.SetResponseField('no', RoutingNo);
        if IsVersion then
            Argument.SetResponseField('versionCode', VersionCode)
        else
            Argument.SetResponseField('versionCode', '');
        Argument.SetResponseField('previousStatus', PreviousStatusTxt);
        Argument.SetResponseField('status', RequestedStatusTxt);
        Argument.SetResponseField('changed', true);

        if not IsVersion then begin
            Item.SetRange("Routing No.", RoutingNo);
            Argument.SetResponseField('usedOnItems', Item.Count());
        end;

        Argument.RespondWithSuccess();
    end;

    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Routing Header");
    end;

    procedure GetContract(): Codeunit "Msg Contract ori"
    var
        ActionDef: Codeunit "Msg Contract Action ori";
    begin
        if MsgContract.IsInitialized() then
            exit(MsgContract);
        ActionDef.Load(Enum::"Message Type ori"::"Manufacturing.Routing.SetStatus");
        MsgContract := ActionDef.GetContract();
        exit(MsgContract);
    end;
}
