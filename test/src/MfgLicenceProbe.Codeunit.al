namespace Origo.Bifrost.Manufacturing.Test;

using Origo.Bifrost;

/// <summary>Invokes Create in a newly created ordinary company without accepting EULA or activating a trial.</summary>
codeunit 97611 "Mfg Licence Probe Tst ori"
{
    TableNo = "Mfg Licence Result Tst ori";

    trigger OnRun()
    var
        Data: Codeunit "Mfg Test Data ori";
        Request: JsonObject;
        ResponseJson: JsonObject;
        ResultText: Text;
        Output: OutStream;
    begin
        Request.Add('sourceNo', 'X-NOT-NEEDED');
        Request.Add('quantity', 1);
        ResponseJson := Data.Invoke("Message Type ori"::"Manufacturing.ProductionOrder.Create", Request, 1033, false);
        ResponseJson.WriteTo(ResultText);
        Rec.Get(Rec.Id);
        Rec.Response.CreateOutStream(Output, TextEncoding::UTF8);
        Output.WriteText(ResultText);
        Rec.Completed := true;
        Rec.Modify();
    end;
}
