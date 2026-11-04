namespace Origo.Bifrost.Manufacturing;

/// <summary>Enforces the Manufacturing write role without widening native table permissions.</summary>
codeunit 10077047 "Mfg Write Check ori"
{
    Access = Internal;

    /// <summary>Refuses write messages before reading or changing manufacturing records.</summary>
    /// <param name="MessageTypeName">The public message type name.</param>
    internal procedure AssertCanWrite(MessageTypeName: Text)
    var
        Gate: Record "Mfg Write Gate ori";
        NoWritePermissionErr: Label 'You do not have permission to run the Manufacturing message type %1. Ask your administrator for the BIFROST Mfg ori or BIFROST Full ori permission set.', Comment = '%1 = message type name, is-IS=Þú hefur ekki heimild til að keyra framleiðsluskilaboðagerðina %1. Biddu kerfisstjóra um heimildasamstæðuna BIFROST Mfg ori eða BIFROST Full ori.';
    begin
        if not Gate.WritePermission() then
            Error(NoWritePermissionErr, MessageTypeName);
    end;
}
