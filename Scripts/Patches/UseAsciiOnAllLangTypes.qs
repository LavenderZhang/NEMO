//################################################################################\\
//# Change the JNZ after LT.Hex comparison inside CSession::IsOnlyEnglish to NOP #\\
//################################################################################\\

function UseAsciiOnAllLangTypes()
{
    //Step 1 - Find the comparison. JNZ is the very next instruction
    var code =
        " F6 04 ?? 80" //TEST BYTE PTR DS:[reg32_A + reg32_B], 80
    +   " 75"          //JNZ SHORT addr
    ;
    var offset = Exe.FindHex(code);
    if (offset === -1)
        return "Failed in Step 1";

    //Step 2 - NOP out the JNZ
    Exe.ReplaceHex(offset + 4, "90 90");
    return true;
}