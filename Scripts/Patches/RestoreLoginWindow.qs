//################################################################################\\
//# Restore the original code that created the Login Window inside               #\\
//# CLoginMode::OnChangeStatefunction and add supporting Changes to make it work #\\
//################################################################################\\

function RestoreLoginWindow()
{
    //Step 1.1 - Check if we have WindowMgr details
    if (WM.Error)
        return "Failed in Step 1 - " + WM.Error;

    //Step 1.2 - Find the code where we need to make client call the login window
    var code =
        " 50"                   //PUSH EAX
    +   " E8 ?? ?? ?? FF"       //CALL g_ResMgr
    +   " 8B C8"                //MOV ECX, EAX
    +   " E8 ?? ?? ?? FF"       //CALL CResMgr::Get
    +   " 50"                   //PUSH EAX
    +   WM.MovEcx               //MOV ECX, OFFSET g_windowMgr
    +   " E8 ?? ?? ?? FF"       //CALL UIWindowMgr::SetWallpaper
    ;
    var csize = code.byteCount();

    code +=
        " 80 3D ?? ?? ?? 00 00" //CMP BYTE PTR DS:[g_Tparam], 0 <- The parameter push + call to UIWindowManager::MakeWindow originally here
    +   " 74 13"                //JZ SHORT addr1 - after the JMP
    +   " C6 ?? ?? ?? ?? 00 00" //MOV BYTE PTR DS:[g_Tparam], 0
    +   " C7 ?? ?? 04 00 00 00" //MOV DWORD PTR DS:[EBX+0C], 4 <- till here we need to overwrite
    +   " E9"                   //JMP addr2
    ;

    var offset = Exe.FindHex(code);
    if (offset === -1)
        return "Failed in Step 1";

    //Step 2.1 - Prepare the code to overwrite with - originally present in old clients
    code =
        " 6A 03"           //PUSH 3
    +   WM.MovEcx          //MOV ECX, OFFSET g_windowMgr
    +   " E8" + MakeVar(1) //CALL UIWindowMgr::MakeWindow
    +   " EB 09"           //JMP SHORT addr ; skip over to the MOV [EBX+0C], 4
    ;

    //Step 2.2 - Fill in the blank
    code = SetValue(code, 1, WM.MakeWin - Exe.Real2Virl(offset + csize + code.byteCount() - 2, CODE));

    //Step 2.3 - Overwrite with the code.
    Exe.ReplaceHex(offset + csize, code);

    ///===============================================///
    /// Now for some additional stuff to make it work ///
    ///===============================================///

    //Step 3.1 - Check if Langtype is available (LT.Error will be a string if not)
    if (LT.Error)
        return "Failed in Step 3 - " + LT.Error;

    //Step 3.2 - Look fot LangType comparisons when sending login packets inside CLoginMode::ChangeState
    code =
        " 80 3D ?? ?? ?? 00 00" //CMP BYTE PTR DS:[g_passwordencrypt], 0
    +   " 0F 85 ?? ?? 00 00"    //JNE addr1
    +   " A1" + LT.Hex          //MOV EAX, DWORD PTR DS:[g_serviceType]
    +   " ?? ??"                //TEST EAX, EAX - (some clients use CMP EAX, EBP instead)
    +   " 0F 84 ?? ?? 00 00"    //JZ addr2 -> Send SSO Packet (ID = 0x825. was 0x2B0 in Old clients)
    +   " 83 ?? 12"             //CMP EAX, 12
    +   " 0F 84 ?? ?? 00 00"    //JZ addr2 -> Send SSO Packet (ID = 0x825. was 0x2B0 in Old clients)
    ;
    offset = Exe.FindHex(code);

    if (offset === -1)
    {
        code = code.replace("A1", "8B ??"); //MOV reg32_A, DWORD PTR DS:[g_serviceType]
        offset = Exe.FindHex(code);
    }
    if (offset === -1)
        return "Failed in Step 3 - LangType comparison missing";

    //Step 3.3 - Update offset to location after the second JZ
    offset += code.byteCount();

    //Step 3.4 - Replace the first JZ with a JMP to proper location (determined by if LangType is also compared with 0C)
    //           This will force the client to always send old login packet
    if (Exe.GetUint8(offset) === 0x83 && Exe.GetInt8(offset + 2) === 0x0C)//create a JMP to location after the JZs
        var repl = "EB 18";
    else
        var repl = "EB 0F";

    Exe.ReplaceHex(offset - 0x11, repl);

    /**
    ===============================================================================================================================
    Shinryo: We need to make the client return to Login Interface when Error occurs (such as wrong password, failed to connect).
                     For this in the CModeMgr::SendMsg function, we set the return mode to 3 (Login) and pass 0x271D as idle value
                     and skip the quit operation.
    ================================================================================================================================
    First we need to find the g_modeMgr & mode setting function address. The address is kept indirectly =>
    MOV ECX, DWORD PTR DS:[Reference]
    MOV EAX, DWORD PTR DS:[ECX]
    MOV EDX, DWORD PTR DS:[EAX+18]
    now ECX + C contains g_modeMgr & EDX is the function address we need. But these 3 instructions are not always kept together
    as of recent clients.
    =================================================================================================================================
    **/

    //Step 4.1 - First we look for one location that appears always after g_modeMgr is retrieved
    code =
        " 6A 00"          //PUSH 0
    +   " 6A 00"          //PUSH 0
    +   " 6A 00"          //PUSH 0
    +   " 68 F6 00 00 00" //PUSH F6
    +   " FF"             //CALL reg32_A or CALL DWORD PTR DS:[reg32_A+const]
    ;

    offset = Exe.FindHex(code);
    if (offset === -1)
        return "Failed in Step 4 - Unable to find g_modeMgr code";

    //Step 4.2 - Find the start of the function
    code =
        " 83 3D ?? ?? ?? ?? 01" //CMP DWORD PTR DS:[addr1], 1
    +   " 75 ??"                //JNE addr2
    +   " 8B 0D"                //MOV ECX, DWORD PTR DS:[Reference]
    ;

    var offset = Exe.FindHex(code, offset - 30, offset);
    if (offset === -1)
        return "Failed in Step 4 - Start of Function missing";

    //Step 4.3 - Extract the reference and construct the code for getting g_modeMgr to ECX + C & mode setter to EDX (same as shown initially)
    var infix =
        Exe.GetHex(offset + code.byteCount() - 2, 6) //MOV ECX, DWORD PTR DS:[Reference]
    +   " 8B 01"            //MOV EAX, DWORD PTR DS:[ECX]
    +   " 8B 50 18"     //MOV EDX, DWORD PTR DS:[EAX+18]
    ;

    //Step 4.4 - Find how many PUSH 0s are there. Older clients had 4 arguments but newer ones only have 3
    var pushes = Exe.FindAllHex("6A 00", offset + code.byteCount() + 4, offset + code.byteCount() + 16);

    //Step 4.5 - Find error handler = CModeMgr::Quit
    code =
        " 8B F1"                  //MOV ESI,ECX
    +   " 8B 46 04"               //MOV EAX,DWORD PTR DS:[ESI+4]
    +   " C7 40 14 00 00 00 00"   //MOV DWORD PTR DS:[EAX+14], 0
    +   " 83 3D" + LT.Hex + " 0B" //CMP DWORD PTR DS:[g_serviceType], 0B
    +   " 75 1D"                  //JNE SHORT addr1 -> after CALL instruction below
    +   " 8B 0D ?? ?? ?? 00"      //MOV ECX,DWORD PTR DS:[g_hMainWnd]
    +   " 6A 01"                  //PUSH 1
    +   " 6A 00"                  //PUSH 0
    +   " 6A 00"                  //PUSH 0
    +   " 68 ?? ?? ?? 00"         //PUSH addr2 ; ASCII "http://www.ragnarok.co.in/index.php"
    +   " 68 ?? ?? ?? 00"         //PUSH addr3 ; ASCII "open"
    +   " 51"                     //PUSH ECX
    +   " FF 15 ?? ?? ?? 00"      //CALL DWORD PTR DS:[<&SHELL32.ShellExecuteA>]
    +   " C7 06 00 00 00 00"      //MOV DWORD PTR DS:[ESI],0 (ESI is supposed to have g_modeMgr but it doesn't always point to it, so we assign it another way)
    ;
    offset = Exe.FindHex(code);

    if (offset === -1) //For recent client g_hMainWnd is directly pushed instead of assigning to ECX first
    {
        code = code.replace(" 75 1D 8B 0D ?? ?? ?? 00", " 75 1C"); //remove the ECX assignment and fix the JNE address accordingly
        code = code.replace(" 51 FF 15 ??", " FF 35 ?? ?? ?? 00 FF 15 ??"); //replace PUSH ECX with PUSH DWORD PTR DS:[g_hMainWnd]
        offset = Exe.FindHex(code);
    }
    if (offset === -1)
        return "Failed in Step 4 - Unable to find SendMsg function";

     /**
    ==================================================================================================
     Shinryo:
     The easiest way to make client return to login would be to set [g_modeMgr] to a random value
     instead of 0, but then the client would dimmer down/flicker and appear again at login interface.
    ===================================================================================================
    **/
    //Step 4.6 - Construct the replacement code
    var replace =
        " 52"                          //PUSH EDX
    +   " 50"                          //PUSH EAX
    +   infix                          //MOV ECX,DWORD PTR DS:[Reference]
                                       //MOV EAX,DWORD PTR DS:[ECX]
                                       //MOV EDX,DWORD PTR DS:[EAX+18]
    +   " 6A 00".repeat(pushes.length) //PUSH 0 sequence
    +   " 68 1D 27 00 00"              //PUSH 271D
    +   " C7 41 0C 03 00 00 00"        //MOV DWORD PTR DS:[ECX+0C],3
    +   " FF D2"                       //CALL EDX
    +   " 58"                          //POP EAX
    +   " 5A"                          //POP EDX
    ;
    replace += " EB" + Num2Hex(code.byteCount() - replace.byteCount() - 2, 1); //Skip to the POP ESI

    //Step 4.7 - Overwrite the SendMsg function.
    Exe.ReplaceHex(offset, replace);

    ///===========================================================================///
    /// Extra for certain 2013 - 2014 clients. Need to fix a function to return 1 ///
    ///===========================================================================///

    if (Exe.GetDate() >= 20130320 && Exe.GetDate() <= 20140226)
    {
        //Step 5.1 - Find "ID"
        offset = Exe.FindString("ID", VIRTUAL);
        if (offset === -1)
            return "Failed in Step 6 - 'ID' missing";

        //Step 5.2 - Find its reference
        code =
            " 6A 01"                //PUSH 1
        +   " 6A 00"                //PUSH 0
        +   " 68" + Num2Hex(offset) //PUSH addr; "ID"
        ;

        offset = Exe.FindHex(code);
        if (offset === -1)
            return "Failed in Step 5 - 'ID' reference missing";

        //Step 5.3 - Find the new function call in 2013 clients
        code =
            " 50"             //PUSH EAX
        +   " E8 ?? ?? ?? 00" //CALL func
        +   " EB"             //JMP addr
        ;

        offset = Exe.FindHex(code, offset - 80, offset);
        if (offset === -1)
            return "Failed in Step 5 - Function not found";

        //Step 5.4 - Extract the called address
        var call = Exe.GetInt32(offset + 2) + offset + 6;

        //Step 5.5 - Sly devils have made a jump here so search for that.
        offset = Exe.FindHex("E9", call);
        if (offset === -1)
            return "Failed in Step 5 - Jump Not found";

        //Step 5.6 - Now get the jump offset
        call = offset + 5 + Exe.GetInt32(offset + 1);//Real2Virl is not needed since we are referring to same code section.

        //Step 5.7 - Search for pattern to get func call <- need to remove that call
        code =
            " 6A 13"             //PUSH 13
        +   " FF 15 ?? ?? ?? 00" //CALL DWORD PTR DS:[addr]
        +   " 25 FF 00 00 00"    //AND EAX, 000000FF
        ;

        offset = Exe.FindHex(code, call);
        if (offset === -1)
            return "Failed in Step 5 - Pattern not found";

        //Step 5.8 - This part is tricky we are going to replace the call with xor eax,eax & add esp, c for now since i dunno what its purpose was anyways. 13 is a hint
        code =
            " 31 C0"    //XOR EAX, EAX
        +   " 83 C4 0C" //ADD ESP, 0C
        +   " 90"       //NOP
        ;

        Exe.ReplaceHex(offset + 2, code);
    }
    return true;
}

///==============================================================///
/// Disable for Unneeded Clients - Only VC9+ Client dont have it ///
///==============================================================///
function RestoreLoginWindow_()
{
    return (Exe.GetDate() > 20100803);
}