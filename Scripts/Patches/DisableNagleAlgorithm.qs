//############################################################################\\
//# Replace all WS2_32.socket() calls with new code that sets up TCP_NODELAY #\\
//############################################################################\\

function DisableNagleAlgorithm()
{
    //Step 1 - Construct the new Function to override with
    var code =
        MakeVar(0)                          //Address to be used in CALL DWORD PTR and JMP DWORD PTR replacements
    +   " 55"                               //PUSH EBP <- Actual start of function
    +   " 8B EC"                            //MOV EBP,ESP
    +   " 83 EC 0C"                         //SUB ESP,0C
    +   " C7 45 F8 01 00 00 00"             //MOV DWORD PTR SS:[EBP-8],1
    +   " 8B 45 10"                         //MOV EAX,DWORD PTR SS:[EBP+10]
    +   " 50"                               //PUSH EAX
    +   " 8B 4D 0C"                         //MOV ECX,DWORD PTR SS:[EBP+0C]
    +   " 51"                               //PUSH ECX
    +   " 8B 55 08"                         //MOV EDX,DWORD PTR SS:[EBP+8]
    +   " 52"                               //PUSH EDX
    +   " FF 15" + MakeVar(1)               //CALL DWORD PTR DS:[<&WS2_32.#23>] ; WS2_32.socket()
    +   " 89 45 FC"                         //MOV DWORD PTR SS:[EBP-4],EAX
    +   " 83 7D FC FF"                      //CMP DWORD PTR SS:[EBP-4],-1
    +   " 74 3C"                            //JE SHORT addr1
    +   " E8 0B 00 00 00"                   //JMP &PUSH ; A little trick to PUSH the following string to stack directly
    +   " 73 65 74 73 6F 63 6B 6F 70 74 00" //DB "setsockopt\x00"
    +   " 68" + MakeVar(2)                  //PUSH OFFSET addr2; ASCII "ws2_32.dll"
    +   " FF 15" + MakeVar(3)               //CALL DWORD PTR DS:[<&KERNEL32.GetModuleHandleA>]
    +   " 50"                               //PUSH EAX
    +   " FF 15" + MakeVar(4)               //CALL DWORD PTR DS:[<&KERNEL32.GetProcAddress>]
    +   " 89 45 F4"                         //MOV DWORD PTR SS:[EBP-0C],EAX
    +   " 83 7D F4 00"                      //CMP DWORD PTR SS:[EBP-0C],0
    +   " 74 11"                            //JE SHORT addr1
    +   " 6A 04"                            //PUSH 4
    +   " 8D 45 F8"                         //LEA EAX,[EBP-8]
    +   " 50"                               //PUSH EAX
    +   " 6A 01"                            //PUSH 1
    +   " 6A 06"                            //PUSH 6
    +   " 8B 4D FC"                         //MOV ECX,DWORD PTR SS:[EBP-4]
    +   " 51"                               //PUSH ECX
    +   " FF 55 F4"                         //CALL DWORD PTR SS:[EBP-0C]
    +   " 8B 45 FC"                         //MOV EAX,DWORD PTR SS:[EBP-4]; addr1
    +   " 8B E5"                            //MOV ESP,EBP
    +   " 5D"                               //POP EBP
    +   " C2 0C 00"                         //RETN 0C
    ;
    var size = code.byteCount();

    //Step 2.1 - Find Free Space for insertion
    var free = Exe.FindSpace(size);
    if (free === -1)
        return "Failed in Step 2 - Not enough free space";

    var freeVirl = Exe.Real2Virl(free, DIFF);

    //Step 2.2 - Find address of ws2_32.socket (#23 when imported by ordinal)
    var sockFunc = Exe.FindFunction("socket", "ws2_32.dll", 23);
    if (sockFunc === -1)
        return "Failed in Step 2 - socket function missing";

    //Step 2.3 - Fill in the blanks
    code = SetValue(code, 0, freeVirl + 4);//Actual Function address
    code = SetValue(code, 1, sockFunc);
    code = SetValue(code, 2, Exe.FindString("ws2_32.dll", VIRTUAL));
    code = SetValue(code, 3, Exe.FindFunction("GetModuleHandleA", "KERNEL32.dll"));
    code = SetValue(code, 4, Exe.FindFunction("GetProcAddress", "KERNEL32.dll"));

    //Step 2.4 - Insert the code to free space
    Exe.InsertHex(free, code, size);

    //Step 3.1 - Find all JMP DWORD PTR to ws2_32.socket function
    var offsets = Exe.FindAllHex("FF 25" + Num2Hex(sockFunc));

    //Step 3.2 - Replace the address with our function.
    for (var i = 0; i < offsets.length; i++)
    {
        Exe.ReplaceInt32(offsets[i] + 2, freeVirl);
    }

    //Step 3.3 - Find all CALL DWORD PTR to ws2_32.socket function
    offsets = Exe.FindAllHex("FF 15" + Num2Hex(sockFunc));

    //Step 3.4 - Replace the address with our function.
    for (var i = 0; i < offsets.length; i++)
    {
        Exe.ReplaceInt32(offsets[i] + 2, freeVirl);
    }
    return true;
}