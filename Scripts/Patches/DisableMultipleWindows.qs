//####################################################################\\
//# Check for Existing Multiple Window Checker and enforce Disabling #\\
//# If not present, insert custom code to do the check + disable     #\\
//####################################################################\\

function DisableMultipleWindows()
{
    //Step 1.1 - Find Address of ole32.CoInitialize function
    var offset = Exe.FindFunction("CoInitialize", "ole32.dll");
    if (offset === -1)
        return "Failed in Step 1 - CoInitialize not found";

    //Step 1.2 - Find where it is called from.
    var code =
        " E8 ?? ?? ?? FF"          //CALL ResetTimer
    +   " ??"                      //PUSH reg32
    +   " FF 15" + Num2Hex(offset) //CALL DWORD PTR DS:[<&ole32.CoInitialize>]
    ;
    offset = Exe.FindHex(code);

    if (offset === -1)
    {
        code = code.replace("FF ??", "FF 6A 00");//Change PUSH reg32 with PUSH 0
        offset = Exe.FindHex(code);
    }
    if (offset === -1)
        return "Failed in Step 1 - CoInitialize call missing";

    //Step 1.3 - If the MOV EAX statement follows the CoInitialize call then it is the old client where Multiple client check is there,
    //           Replace the statement with MOV EAX, 00FFFFFF
    if (Exe.GetUint8(offset + code.byteCount()) === 0xA1)
    {
        Exe.ReplaceHex(offset + code.byteCount(), "B8 FF FF FF 00");
        return true;
    }

    /**==================================================================================
       Now since the MOV was not found we can assume the Multiple Client check is removed
       Hence we will put our own Checker code                                                                                            //
       ==================================================================================**/

    //Step 2.1 - Extract the ResetTimer function address (called before CoInitialize)
    offset += 5;
    var resetTimer = Exe.GetInt32(offset-4) + Exe.Real2Virl(offset, CODE);

    //Step 2.2 - Prepare code for mutex windows
    code =
        " E8" + MakeVar(0)               //CALL ResetTimer
    +   " 56"                            //PUSH ESI
    +   " 33 F6"                         //XOR ESI,ESI
    +   " 68" + MakeVar(1)               //PUSH addr ; "KERNEL32"
    +   " FF 15" + MakeVar(2)            //CALL DWORD PTR DS:[<&KERNEL32.GetModuleHandleA>]
    +   " E8 0D 00 00 00"                //PUSH &JMP
    +   Ascii2Hex("CreateMutexA\x00")    //DB "CreateMutexA", 0
    +   " 50"                            //PUSH EAX
    +   " FF 15" + MakeVar(3)            //CALL DWORD PTR DS:[<&KERNEL32.GetProcAddress>]
    +   " E8 0F 00 00 00"                //PUSH &JMP
    +   Ascii2Hex("Global\\Surface\x00") //DB "Global\Surface",0
    +   " 56"                            //PUSH ESI
    +   " 56"                            //PUSH ESI
    +   " FF D0"                         //CALL EAX
    +   " 85 C0"                         //TEST EAX,EAX
    +   " 74 0F"                         //JE addr1 -> ExitProcess call below
    +   " 56"                            //PUSH ESI
    +   " 50"                            //PUSH EAX
    +   " FF 15" + MakeVar(4)            //CALL DWORD PTR DS:[<&KERNEL32.WaitForSingleObject>]
    +   " 3D 02 01 00 00"                //CMP EAX, 258    ; WAIT_TIMEOUT
    +   " 75 26"                         //JNZ addr2 -> POP ESI below
    +   " 68" + MakeVar(1)               //PUSH addr ; "KERNEL32"
    +   " FF 15" + MakeVar(2)            //CALL DWORD PTR DS:[<&KERNEL32.GetModuleHandleA>]
    +   " E8 0C 00 00 00"                //PUSH &JMP
    +   Ascii2Hex("ExitProcess\x00")     //DB "ExitProcess", 0
    +   " 50"                            //PUSH EAX
    +   " FF 15" + MakeVar(3)            //CALL DWORD PTR DS:[<&KERNEL32.GetProcAddress>]
    +   " 56"                            //PUSH ESI
    +   " FF D0"                         //CALL EAX
    +   " 5E"                            //POP ESI ; addr2
    +   " 68" + MakeVar(5)               //PUSH AfterStolenCall ; little trick to make calculation easier
    +   " C3"                            //RETN
    +   Ascii2Hex("KERNEL32\x00")        //DB "KERNEL32", 0 ; string to use in GetModuleHandleA
    ;
    var csize = code.byteCount();

    //Step 2.3 - Find Free space for insertion
    var free = Exe.FindSpace(csize);
    if (free === -1)
        return "Failed in Step 2 - Not enough free space";

    //Step 2.4 - Replace the resetTimer call with our code
    Exe.ReplaceHex(offset - 5, "E9" + Num2Hex(Exe.Real2Virl(free, DIFF) - Exe.Real2Virl(offset, CODE)));

    //Step 2.5 - Fill in the blanks
    code = SetValue(code, 0, resetTimer - Exe.Real2Virl(free + 5, DIFF));
    code = SetValue(code, 1, Exe.Real2Virl(free + csize - 9, DIFF), 2); //Change in two Places
    code = SetValue(code, 2, Exe.FindFunction("GetModuleHandleA",    "KERNEL32.dll"), 2); //Change in two Places
    code = SetValue(code, 3, Exe.FindFunction("GetProcAddress",      "KERNEL32.dll"), 2); //Change in two Places
    code = SetValue(code, 4, Exe.FindFunction("WaitForSingleObject", "KERNEL32.dll"));
    code = SetValue(code, 5, Exe.Real2Virl(offset, CODE));

    //Step 2.6 - Insert the code at free space
    Exe.InsertHex(free, code, csize);
    return true;
}