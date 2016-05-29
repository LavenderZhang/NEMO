//#################################################################################\\
//# Change the JNE to NOPs after LangType comparison in EOT font Checker function #\\
//#################################################################################\\

function EnableOfficialCustomFonts() //Comparison is not there in Pre-2010 Clients
{
    //Step 1 - Find the JNE (Comparison pattern changes from client to client, but the JNE and CALL doesn't)
    var code =
        " 0F 85 AE 00 00 00" //JNE addr - Skips .eot loading
    +   " E8 ?? ?? ?? FF"    //CALL func
    ;

    var offset = Exe.FindHex(code);
    if (offset === -1)
        return "Failed in Step 1";

    //Step 2 - Replace JNE instruction with NOPs
    Exe.ReplaceHex(offset, "90 90 90 90 90 90");
    return true;
}