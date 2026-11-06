namespace Origo.Bifrost.Manufacturing;

using Origo.Bifrost;

/// <summary>Checks the BIFROST MfgPost ori posting token without reading business data.</summary>
codeunit 10077053 "Mfg Posting Gate ori"
{
    Access = Internal;

    var
        DeniedLbl: Label 'Posting denied: missing ''BIFROST MfgPost ori'' permission set.', Comment = 'is-IS=Bókun hafnað: vantar heimildasettið ''BIFROST MfgPost ori''.';
        DeniedNextLbl: Label 'Ask an administrator to assign the BIFROST MfgPost ori permission set.', Comment = 'is-IS=Biddu stjórnanda um að úthluta heimildasettinu BIFROST MfgPost ori.';

    /// <summary>Returns true when the caller holds write permission on the posting token.</summary>
    internal procedure HasPostingPermission(): Boolean
    var
        Token: RecordRef;
        HasPermission: Boolean;
    begin
        Token.Open(Database::"Mfg Posting ori");
        HasPermission := Token.WritePermission();
        Token.Close();
        exit(HasPermission);
    end;

    /// <summary>Answers PermissionDenied naming the posting set; returns false when the caller may not post.</summary>
    internal procedure AssertCanPost(var Argument: Record "Message Argument ori"): Boolean
    begin
        if HasPostingPermission() then
            exit(true);
        Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, DeniedLbl, '', '', 'BIFROST MfgPost ori', DeniedNextLbl);
        exit(false);
    end;
}
