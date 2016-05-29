//#########################################################\\
//# Change the JE/JNE to JMP after LT.Hex Comparisons in  #\\
//# Char Deletion function and the one which shows MsgBox #\\
//#########################################################\\

function DeleteCharWithEmail()
{
    //Step 1.1 - Check if LT.Hex is available (LT.Error will be a string if not)
    if (LT.Error)
        return "Failed in Step 1 - " + LT.Error;

    //Step 1.2 - Find the LangType comparison in Char Delete function (name not known right now)
    var code =
        " A1" + LT.Hex //MOV EAX, DWORD PTR DS:[g_serviceType]
    +   " 83 C4 08"    //ADD ESP,8
    +   " 83 F8 0A"    //CMP EAX,0A
    +   " 74"          //JE SHORT addr -> do the one for Email
    ;

    var offset = Exe.FindHex(code);
    if (offset === -1)
        return "Failed in Step 1 - Comparison missing";

    //Step 1.2 - Change the JE to JMP
    Exe.ReplaceInt8(offset + code.byteCount() - 1, 0xEB);

    //Step 2.1 - Find the LT.Hex comparison for MsgBox String
    code =
        " 6A 00"          //PUSH 0
    +   " 75 07"          //JNE SHORT addr -> PUSH 12B
    +   " 68 ?? ?? 00 00" //PUSH 717 or 718 or 12E - the MsgString ID changes between clients
    +   " EB 05"          //JMP SHORT addr2 -> CALL MsgStr
    ;

    offset = Exe.FindHex(code);
    if (offset === -1)
        return "Failed in Step 2 - Comparison missing";

    //Step 2.2 - Change JNE to JMP
    Exe.ReplaceInt8(offset + 2, 0xEB);
    return true;
}