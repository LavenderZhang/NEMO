//###################################################\\
//# Change JNE to JMP after the LangType comparison #\\
//# in the Monster talk loader function             #\\
//###################################################\\

function EnableMonsterTables() //Comparison is different for pre-2010 clients.
{
    //Step 1.1 - Check if LangType is available (LT.Error will be a string if not)
    if (LT.Error)
        return "Failed in Step 1 - " + LT.Error;

    //Step 1.2 - Find the Comparison - Hint: Case 2723 of switch and it appears before PUSH "uae\"
    var code =
        LT.Hex               //MOV reg32_A, DWORD PTR DS:[g_serviceType]
    +   " 83 C4 04"          //ADD ESP, 4
    +   " 83 ?? 13"          //CMP reg32_A, 13
    +   " 0F 85 ?? ?? 00 00" //JNE addr
    ;

    var offset = Exe.FindHex(code);
    if (offset === -1)
        return "Failed in Step 1 -    Comparison not found";

    //Step 2 - Swap JNE with NOP + JMP
    Exe.ReplaceHex(offset + code.byteCount() - 6, "90 E9");
    return true;
}