//#####################################################################################################\\
//# Skip the LangType checks inside UILoginWnd::OnCreate and always makes the registration page open  #\\
//# inside UILoginWnd::SendMsg. Also modifies the CModeMgr::Quit CALL to actually close the client.   #\\
//#####################################################################################################\\

function ShowRegisterButton()
{
    //Step 1.1 - Find the alternate URL string
    var offset = Exe.FindString("http://ro.hangame.com/login/loginstep.asp?prevURL=/NHNCommon/NHN/Memberjoin.asp", VIRTUAL);
    if (offset === -1)
        return "Failed in Step 1 - String missing";

    //Step 1.2 - Find its reference inside UILoginWnd::SendMsg
    offset = Exe.FindHex("68" + Num2Hex(offset));
    if (offset === -1)
        return "Failed in Step 1 - String reference missing";

    //Step 2.1 - Check if LangType is available (LT.Error will be a string if not)
    if (LT.Error)
        return "Failed in Step 2 - " + LT.Error;

    //Step 2.2 - Look for the LT.Hex comparison before the URL reference
    var code =
        " 83 3D" + LT.Hex + " 00" //CMP DWORD PTR DS:[g_serviceType], 0
    +   " 75 ??"                  //JNE SHORT addr
    ;

    var codeSuffix =
        " 83 3D ?? ?? ?? 00 01" //CMP DWORD PTR DS:[g_isGravityID], 1
    +   " 75"                   //JNE SHORT addr
    ;
    var type = 1;

    var offset2 = Exe.FindHex(code + codeSuffix, offset - 0x30, offset);
    if (offset2 === -1)
    {
        code =
            " A1" + LT.Hex       //MOV EAX, DWORD PTR DS:[g_serviceType]
        +   " 85 C0"             //TEST EAX, EAX
        +   " 0F 85 ?? 00 00 00" //JNE addr
        ;
        type = 2;
        offset2 = Exe.FindHex(code + codeSuffix, offset - 0x30, offset);
    }
    if (offset2 === -1)
        return "Failed in Step 2 - LT.Hex comparison missing";

    //Step 2.3 - Update offset to location after first JNE
    offset2 += code.byteCount();

    //Step 2.4 - Change the first JNE to JMP and goto the Jumped address
    if (type == 1)
    {
        Exe.ReplaceInt8(offset2 - 2, 0xEB);
        offset2 += Exe.GetInt8(offset2 - 1);
    }
    else {
        Exe.ReplaceHex(offset2 - 6, "90 E9");
        offset2 += Exe.GetInt32(offset2 - 4);
    }

    //Step 3.1 - Add 10 to Skip over MOV ECX, OFFSET g_modeMgr and CALL CModeMgr::Quit
    offset2 += 10;

    //Step 3.2 - Prep new code (original CModeMgr::Quit will get overwritten by RestoreLoginWindow so create a new function with the essentials)
    code =
        " 8B 41 04"             //MOV EAX,DWORD PTR DS:[ECX+4]
    +   " C7 40 14 00 00 00 00" //MOV DWORD PTR DS:[EAX+14], 0
    +   " C7 01 00 00 00 00"    //MOV DWORD PTR DS:[ECX],0
    +   " C3"                   //RETN

    //Step 3.3 - Find Free space for insertion
    var free = Exe.FindSpace(code.byteCount());
    if (free === -1)
        return "Failed in Step 3 - Not enough free space";

    //Step 3.4 - Insert the code at free space
    Exe.InsertHex(free, code, code.byteCount());

    //Step 3.5 - Change the CModeMgr::Quit CALL with a CALL to our function
    Exe.ReplaceInt32(offset2 - 4, Exe.Real2Virl(free, DIFF) - Exe.Real2Virl(offset2, CODE));

    //Step 4.1 - Find the prefix string for the button (pressed state)
    offset = Exe.FindString("btn_request_b", VIRTUAL);
    if (offset === -1)
        return "Failed in Step 4 - Button prefix missing";

    //Step 4.2 - Find its reference
    offset = Exe.FindHex(Num2Hex(offset) + " C7");
    if (offset === -1)
        return "Failed in Step 4 - Prefix reference missing";

    //Step 4.3 - Look for the LangType comparison after the reference
    code =
        " 83 ?? 03"    //CMP reg32, 03 ; 03 is for register button
    +   " 75 25"       //JNE SHORT addr
    +   " A1" + LT.Hex //MOV EAX, DWORD PTR DS:[g_serviceType]
    ;

    offset2 = Exe.FindHex(code, offset + 0xA0, offset + 0x100);
    if (offset2 === -1)
        return "Failed in Step 4 - LT.Hex comparison missing";

    //Step 4.4 - Change the JNE to JMP. This way no LT.Hex check occurs for any buttons
    Exe.ReplaceInt8(offset2 + 3, 0xEB);

    return true;
}