//#########################################################\\
//# Change all JE/JNE to JMP after LangType comparisons   #\\
//# inside CLoginMode::CheckExeHashFromAccServer function #\\
//#########################################################\\

function ForceSendClientHash()
{
    //Step 1.1 - Check if Langtype is available (LT.Error will be a string if not)
    if (LT.Error)
        return "Failed in Step 1 - " + LT.Error;

    //Step 1.2 - Find the 1st Langtype comparison
    var code =
        " 8B ??" + LT.Hex //MOV reg32,DWORD PTR DS:[g_serviceType]
    +   " 33 C0"            //XOR EAX, EAX
    +   " 83 ?? 06"         //CMP reg32, 6
    +   " 74"               //JE SHORT addr -> (to MOV EAX, 1)
    ;

    var offset = Exe.FindHex(code);
    if (offset === -1)
        return "Failed in Step 1";

    //Step 1.3 - Update offset to the location after JE
    offset += code.byteCount() + 1;

    //Step 1.2 - Replace JE with JMP
    Exe.ReplaceInt8(offset - 2, 0xEB);

    //Step 1.3 - Update offset to the JE-ed location.
    offset += Exe.GetInt8(offset - 1);

    //Step 2.1 - Find the 2nd comparison
    code =
        " 85 C0"    //TEST EAX, EAX
    +   " 75 ??"    //JNE SHORT addr1
    +   " A1"       //MOV EAX, DWORD PTR DS:[addr2]
    ;

    offset = Exe.FindHex(code, offset);
    if (offset === -1)
        return "Failed in Step 2";

    //Step 2.2 - Update offset to the location after JNE
    offset += code.byteCount() - 1;

    //Step 2.3 - Replace JNE with JMP
    Exe.ReplaceInt8(offset - 2, 0xEB);

    //Step 2.4 - Update offset to JNE-ed location
    offset += Exe.GetInt8(offset - 1);

    //Step 3.1 - Find the last comparison
    code =
        " 83 F8 06"    //CMP EAX, 6
    +   " 75"          //JNE SHORT addr3
    ;

    offset = Exe.FindHex(code, offset);
    if (offset === -1)
        return "Failed in Step 3";

    //Step 3.2 - Update offset to location of JNE
    offset += code.byteCount() - 1;

    //Step 3.3 - Replace JNE with JMP
    Exe.ReplaceInt8(offset, 0xEB);
    return true;
}