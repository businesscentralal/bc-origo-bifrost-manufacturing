namespace Origo.Bifrost.Manufacturing.Test;

using System.Environment;
using System.TestLibraries.Utilities;

/// <summary>Verifies consent refusal in a real ordinary company, with no licence, trial or EULA writes.</summary>
codeunit 97613 "Mfg Licence Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;
    RequiredTestIsolation = Disabled;

    [Test]
    procedure Scenario_AC15_NewOrdinaryCompany_RequiresEula()
    var
        Company: Record Company;
        Result: Record "Mfg Licence Result Tst ori";
        Assert: Codeunit "Library Assert";
        ResponseText: Text;
        CompanyName: Text[30];
        SessionId: Integer;
        Attempts: Integer;
        Finished: Boolean;
        Started: Boolean;
        Input: InStream;
    begin
        // Story #5 AC15: actual ordinary company, not a spoofed platform flag or mutated consent setup.
        CompanyName := CopyStr('X-MFG-' + DelChr(Format(CreateGuid(), 0, 4), '=', '-'), 1, 30);
        Company.Init();
        Company.Name := CompanyName;
        Company.Insert(true);
        Result.Id := CreateGuid();
        Result.Insert();
        Commit();
        Started := StartSession(SessionId, Codeunit::"Mfg Licence Probe Tst ori", CompanyName, Result);
        if Started then
            repeat
                Sleep(500);
                Result.Get(Result.Id);
                Finished := Result.Completed;
                Attempts += 1;
            until Finished or (Attempts >= 120);
        if Started and not Finished then
            StopSession(SessionId);
        if Finished then begin
            Result.CalcFields(Response);
            Result.Response.CreateInStream(Input, TextEncoding::UTF8);
            Input.ReadText(ResponseText);
        end;
        Result.Delete();
        Company.Get(CompanyName);
        Company.Delete();
        Commit();
        Assert.IsTrue(Started and Finished, 'Owned licence probe must finish and return a response.');
        Assert.IsTrue(ResponseText.Contains('EULA_REQUIRED'), 'An ordinary new company must refuse consent before item validation: ' + ResponseText);
    end;
}
