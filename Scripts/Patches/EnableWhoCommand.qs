//#########################################################################\\
//# Change the JE/JNE after LangType comparison inside CGameMode::SendMsg #\\
//# function for /who command and inside CGameMode::Zc_User_Count         #\\
//#########################################################################\\

function EnableWhoCommand()
{
    //Step 1.1 - Check if Langtype is available (LT.Error will be a string if not)
    if (LT.Error)
        return "Failed in Step 1 - " + LT.Error;

    //Step 1.2 - Find LangType comparison
    var code =
        " A1" + LT.Hex     //MOV EAX,DWORD PTR DS:[g_serviceType]
    +   " 83 F8 03"          //CMP EAX,3
    +   " 0F 84 ?? ?? 00 00" //JE addr
    +   " 83 F8 08"          //CMP EAX,8
    +   " 0F 84 ?? ?? 00 00" //JE addr
    +   " 83 F8 09"          //CMP EAX,9
    +   " 0F 84 ?? ?? 00 00" //JE addr
    +   " 8D"                //LEA ECX,[ESP+x]
    ;
    var offset = Exe.FindHex(code);

    if (offset === -1)
    {
        code = code.replace("?? 00 00 8D", "?? 00 00 B8"); //Change LEA to MOV EAX
        offset = Exe.FindHex(code);
    }
    if (offset === -1)
        return "Failed in Step 1 - LangType comparison missing";

    //Step 1.3 - Replace the First JE with JMP to LEA
    Exe.ReplaceHex(offset + 5, "90 EB 18");

    //Step 2.1 - Find PUSH 0B2 followed by CALL MsgStr - Common pattern inside Zc_User_Count
    code =
        " 68 B2 00 00 00" //PUSH 0B2
    +   " E8 ?? ?? ?? ??" //CALL MsgStr
    +   " 83 C4 04"       //ADD ESP, 4
    ;

    offset = Exe.FindHex(code);
    if (offset === -1)
        return "Failed in Step 2 - MsgStr call missing";

    //Step 2.2 - Find the JNE after LangType comparison before it (closer to start of Zc_User_Count)
    code =
        " 75 ??"          //JNE SHORT addr
    +   " A1 ?? ?? ?? 00" //MOV EAX, DWORD PTR DS:[refAddr]
    +   " 50"             //PUSH EAX
    +   " E8 ?? ?? ?? FF" //CALL IsGravityAid
    +   " 83 C4 04"       //ADD ESP, 4
    +   " 84 C0"          //TEST AL, AL
    +   " 75"             //JNE SHORT addr
    ;
    var offset2 = Exe.FindHex(code, offset - 0x60, offset);

    if (offset2 === -1)
    {
        code = code.replace(" A1 ?? ?? ?? 00 50", " FF 35 ?? ?? ?? 00"); //Change MOV EAX to PUSH DWORD PTR DS:[refAddr]
        offset2 = Exe.FindHex(code, offset - 0x60, offset);
    }
    if (offset2 === -1)
        return "Failed in Step 2 - LangType comparison missing";

    //Step 2.3 - Replace First JNE with JMP
    Exe.ReplaceInt8(offset2, 0xEB);
    return true;
}