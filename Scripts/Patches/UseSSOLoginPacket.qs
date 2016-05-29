//######################################################################\\
//# Change the JZ/JNE to JMP/NOP after LangType Comparison for sending #\\
//# Login Packet inside CLoginMode::OnChangeState function.            #\\
//######################################################################\\

function UseSSOLoginPacket()
{
    //Step 1.1 - Check if LangType is available (LT.Error will be a string if not)
    if (LT.Error)
        return "Failed in Step 1 - " + LT.Error;

    //Step 1.2 - Find the LangType comparison
    var code =
        " 80 3D ?? ?? ?? 00 00" //CMP BYTE PTR DS:[g_passwordencrypt], 0
    +   " 0F 85 ?? ?? 00 00"    //JNE addr1
    +   " A1" + LT.Hex          //MOV EAX, DWORD PTR DS:[g_serviceType]
    +   " ?? ??"                //TEST EAX, EAX - (some clients use CMP EAX, EBP instead)
    +   " 0F 84 ?? ?? 00 00"    //JZ addr2 -> Send SSO Packet (ID = 0x825. was 0x2B0 in Old clients)
    +   " 83 ?? 12"             //CMP EAX, 12
    +   " 0F 84 ?? ?? 00 00"    //JZ addr2 -> Send SSO Packet (ID = 0x825. was 0x2B0 in Old clients)
    ;
    var offset = Exe.FindHex(code);

    if (offset === -1)
    {
        code = code.replace("A1", "8B ??"); //Change MOV EAX to MOV reg32_A, DWORD PTR DS:[g_serviceType]
        offset = Exe.FindHex(code);
    }
    if (offset !== -1)
    {
        //Step 1.2 - Change first JZ to JMP
        Exe.ReplaceHex(offset + code.byteCount() - 15, " 90 E9");
        return true;
    }

    //Step 2.1 - Since it failed it is an old client before VC9. Find the alternate comparison pattern
    code =
        " A0 ?? ?? ?? 00"    //MOV AL, DWORD PTR DS:[g_passwordencrypt]
    +   " ?? ??"             //TEST AL, AL - (could be checked with CMP also. so using wildcard)
    +   " 0F 85 ?? ?? 00 00" //JNE addr1
    +   " A1" + LT.Hex       //MOV EAX, DWORD PTR DS:[g_serviceType]
    +   " ?? ??"             //TEST EAX, EAX - (some clients use CMP EAX, EBP instead)
    +   " 0F 85 ?? ?? 00 00" //JNE addr2 -> Send Login Packet (ID = 0x64)
    ;

    offset = Exe.FindHex(code);
    if (offset === -1)
        return "Failed in Step 1";

    //Step 2.2 - Convert the JNE addr2 to NOP
    Exe.ReplaceHex(offset + code.byteCount() - 6, "90 90 90 90 90 90");
    return true;
}