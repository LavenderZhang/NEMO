//#############################################################\\
//# NOP out the Conditional Jump inside CGameMode::Initialize #\\
//# that prevents the Tip Window being created on startup     #\\
//#############################################################\\

function EnableTipOnStartup()
{
    //Step 1.1 - Find "ISVOODOO" (Registry Key)
    var offset = Exe.FindString("ISVOODOO", VIRTUAL);
    if (offset === -1)
        return "Failed in Step 1 - Reg key missing";

    //Step 1.2 - Find its reference
    var code =
        " 68" + Num2Hex(offset) //PUSH OFFSET addr; ASCII "ISVOODOO"
    +   " ??"                   //PUSH reg32_A
    +   " FF D6"                //CALL ESI
    ;
    offset = Exe.FindHex(code); //Till VC11 this is the pattern

    if (offset === -1) //VC11
    {
        code = code.replace(" ??",   //substitute PUSH reg32_A with
            " FF 75 ??"              //PUSH DWORD PTR SS:[LOCAL.z]
        +   " C7 45 ?? 04 00 00 00"  //MOV DWORD PTR SS:[LOCAL.y], 4
        +   " C7 45 ?? 04 00 00 00"  //MOV DWORD PTR SS:[LOCAL.x], 4
        );
        offset = Exe.FindHex(code);
    }
    if (offset === -1)
        return "Failed in Step 1 - Key reference missing";

    //Step 1.3 - Update offset to location after the code
    offset += code.byteCount();

    //Step 1.4 - Look for PUSH g_showTipAtStartup after offset (should be within 0x10 bytes)
    offset = Exe.FindHex("68 ?? ?? ?? 00", offset, offset + 0x10);
    if (offset === -1)
        return "Failed in Step 1 - g_showTipAtStartup missing";

    //Step 1.5 - Extract the address in hex
    var gStartup = Exe.GetHex(offset + 1, 4);

    //Step 2.1 - Look for g_showTipAtStartup comparison after which the Tip Window is created (inside CGameMode::Initialize)
    code =
        " 39 ?? ?? ?? ?? 00" //CMP DWORD PTR DS:[refAddr], reg32_A
    +   " 75 ??"             //JNE SHORT addr
    +   " A1" + gStartup     //MOV EAX, DWORD PTR DS:[g_showTipAtStartup]
    ;
    offset = Exe.FindHex(code); //Old client (VC6)
    var jneLoc = 6;//changes for VC11

    if (offset === -1)
    {
        code = code.replace("A1", "89 ?? ?? ?? ?? 00 39 ??");//Substitute MOV EAX with MOV DWORD PTR DS:[refAddr], reg32_B & CMP DWORD PTR DS:[g_showTipAtStartup], reg32_A
        offset = Exe.FindHex(code); //VC9
    }
    if (offset === -1)
    {
        code = code.replace("89 ?? ?? ?? ?? 00", "C7 05 ?? ?? ?? 00 01 00 00 00");//Change reg32_B with 0x01
        offset = Exe.FindHex(code); //VC10
    }
    if (offset === -1)
    {
        code =
            " 83 3D ?? ?? ?? 00 00" //CMP DWORD PTR DS:[refAddr], 0
        +   " 75 ??"                //JNE SHORT addr
        +   " 83 3D" + gStartup     //CMP DWORD PTR DS:[g_showTipAtStartup], 0
        ;
        offset = Exe.FindHex(code);//VC11
        jneLoc = 7;
    }
    if (offset === -1)
        return "Failed in Step 2 - Comparison missing";

    //Step 2.2 - NOP out the JNE
    Exe.ReplaceHex(offset + jneLoc, "90 90");
    return true;
}