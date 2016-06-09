//###################################################################################################\\
//# Change the failure return value in the function looking for '@' in Chat text to 1 (making a     #\\
//# false positive) For old clients, we need to hijack a CALL inside UIWindowMgr::ProcessPushButton #\\
//###################################################################################################\\

function FixChatAt()
{
    //Step 1.1 - Find the JZ after '@' Comparison
    var code =
        " 74 04"       //JZ SHORT addr -> POP EDI below
    +   " C6 ?? ?? 00" //MOV BYTE PTR DS:[reg32_A+const], 0 ; <- this is the value we need to change
    +   " 5F"          //POP EDI
    +   " 5E"          //POP ESI
    ;
    var offset = Exe.FindHex(code);

    if (offset !== -1)
    {   //VC9+ Clients
        //==============================================//
        // Note: The above will be followed by MOV AL,1 //
        //             and POP EBP/EBX statements       //
        //==============================================//

        //Step 1.2 - Change 0 to 1
        Exe.ReplaceHex(offset + 5, "01");
    }
    else
    {   //Older clients

        //Step 2.1 - Find the call inside UIWindowMgr::ProcessPushButton
        code =
            " 8B CE"             //MOV ECX, ESI
        +   " E8 ?? ?? 00 00"    //CALL func <- this is what we need to hijack
        +   " 84 C0"             //TEST AL, AL
        +   " 74 ??"             //JZ SHORT addr
        +   " 8B ?? ?? ?? 00 00" //MOV reg32_A, DWORD PTR DS:[ESI+const]
        ;

        offset = Exe.FindHex(code);
        if (offset === -1)
            return "Failed in Step 2 - Function call missing";

        //Step 2.2 - Extract the called address (VIRTUAL).
        var func = Exe.Real2Virl(offset + 7, CODE) + Exe.GetInt32(offset + 3);

        //Step 3.1 - Construct our function.
        code =
            " 60"                 //PUSHAD
        +   " 0F B6 41 2C"        //MOVZX EAX,BYTE PTR DS:[ECX+2C]
        +   " 85 C0"              //TEST EAX,EAX
        +   " 74 1C"              //JE SHORT addr
        +   " 8B 35" + MakeVar(1) //MOV ESI, DWORD PTR DS:[<&USER32.GetAsyncKeyState>]
        +   " 6A 12"              //PUSH 12 ;       VirtualKey = VK_ALT
        +   " FF D6"              //CALL ESI;       [<&USER32.GetAsyncKeyState>]
        +   " 85 C0"              //TEST EAX,EAX
        +   " 74 0E"              //JE SHORT addr
        +   " 6A 11"              //PUSH 11;        VirtualKey = VK_CONTROL
        +   " FF D6"              //CALL ESI;       [<&USER32.GetAsyncKeyState>]
        +   " 85 C0"              //TEST EAX,EAX
        +   " 74 06"              //JE SHORT addr
        +   " 61"                 //POPAD
        +   " 33 C0"              //XOR EAX,EAX
        +   " C2 04 00"           //RETN 4
        +   " 61"                 //POPAD <- addr
        +   " 68" + MakeVar(2)    //PUSH func
        +   " C3"                 //RETN; Alternative to "JMP func" with no relative offset calculation needed
        ;
        var csize = code.byteCount();

        //Step 3.2 - Find Free space for insertion
        var free = Exe.FindSpace(csize);
        if (free === -1)
            return "Failed in Step 3 - Not enough free space";

        //Step 4.1 - Fill in the blanks
        code = SetValue(code, 1, Exe.FindFunction("GetAsyncKeyState", "USER32.dll"));
        code = SetValue(code, 2, func);

        //Step 4.2 - Change called address from func to our function.
        Exe.ReplaceInt32(offset + 3, Exe.Real2Virl(free, DIFF) - Exe.Real2Virl(offset + 7));

        //Step 4.3 - Insert our function at free space
        Exe.InsertHex(free, code, csize);
    }
    return true;
}