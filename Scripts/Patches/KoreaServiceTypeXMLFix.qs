//################################################################################\\
//# Fix the switch and JMP in InitClientInfo and InitDefaultClientInfo functions #\\
//# to make sure both SelectKoreaClientInfo and SelectClientInfo are called.     #\\
//################################################################################\\

function KoreaServiceTypeXMLFix()
{
    //Step 1.1 - Find offset of error string.
    var offset = Exe.FindString("Unknown ServiceType !!!", VIRTUAL);
    if (offset === -1)
        return "Failed in Step 1 - Error String missing";

    //Step 1.2 - Find all its references
    var offsets = Exe.FindAllHex("68" + Num2Hex(offset));
    if (offsets.length === 0)
        return "Failed in Step 1 - No references found";

    for (var i = 0; i < offsets.length; i++)
    {
        //Step 2.1 - Find the Select calls before each PUSH
        var code =
            " FF 24 ?? ?? ?? ?? 00" //JMP DWORD PTR DS:[reg32_A*4 + refAddr]
        +   " E8 ?? ?? ?? ??"       //CALL SelectKoreaClientInfo
        +   " E9 ?? ?? ?? ??"       //JMP addr2 -> Skip calling SelectClientInfo
        +   " 6A 00"                //PUSH 0
        +   " E8"                   //CALL SelectClientInfo
        ;
        var repl = " 90 90 90 90 90";
        offset = Exe.FindHex(code, offsets[i] - 0x30, offsets[i]);

        if (offset === -1)
        {
            code = code.replace(" E9 ?? ?? ?? ??", " EB ??");//Change JMP addr2 to JMP SHORT addr2
            repl = " 90 90";//Since JMP is short, Only 2 NOPs are needed
            offset = Exe.FindHex(code, offsets[i] - 0x30, offsets[i]);
        }
        if (offset === -1)
            return "Failed in Step 2 - Calls missing for iteration no." + i;

        //Step 2.2 - Replace the JMP skipping SelectClientInfo
        Exe.ReplaceHex(offset + 12, repl);//12 = 7 from JMP DWORD PTR and 5 from CALL SelectKoreaClientInfo

        //Step 2.3 - Extract the refAddr
        offset = Exe.Virl2Real(Exe.GetInt32(offset + 3));

        //Step 2.4 - Replace refAddr + 4 with the contents from refAddr, so that all valid langtypes will use same case as 0 i.e. Korea
        code = Exe.GetHex(offset, 4);
        Exe.ReplaceHex(offset + 4, code);
    }
    return true;
}

/*
 Note:
-------
 Gravity has their clientinfo hardcoded and seperated the initialization, screw "em.. :(
 SelectKoreaClientInfo() has for example global variables like g_extended_slot set
 which aren"t set by SelectClientInfo(). Just call both functions will fix this as the
 changes from SelectKoreaClientInfo() will persist and overwritten by SelectClientInfo().
*/