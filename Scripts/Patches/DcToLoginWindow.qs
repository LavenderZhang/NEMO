//#############################################################################\\
//# Change the PUSHed argument & mode value to Mode Setting calls after       #\\
//# disconnection to make it return to login window instead of exiting client #\\
//#############################################################################\\

function DcToLoginWindow()
{
    //Step 1.1 - Sanity Check. Make Sure Restore Login Window is enabled.
    if (GetActivePatches().indexOf(40) === -1)
        return "Patch Cancelled - Restore Login Window patch is necessary but not enabled";

    //Step 1.2 - Find the MsgString ID references of "Sorry the character you are trying to use is banned for testing connection." - common in Login/Char & Map server DC
    var code = "68 35 06 00 00"; //PUSH 635

    var offsets = Exe.FindAllHex(code);
    if (offsets.length !== 2) //1 for Login/Char & 1 for Map
        return "Failed in Part 1 - MsgString ID missing";

    //Step 1.3  - Update both offsets to location after the PUSH
    offsets[0] += 5;
    offsets[1] += 5;

    /******* First we will work on DC during Login/Char Selection screens ********/

    //Step 2.1 - Find the format string
    var offset = Exe.FindString("%s(%d)", VIRTUAL);
    if (offset === -1)
        return "Failed in Part 2 - Format string missing";

    //Step 2.2 - Find its reference after the MsgString ID PUSH
    offset = Exe.FindHex("68" + Num2Hex(offset), offsets[1], offsets[1] + 0x120);
    if (offset === -1)
        return "Failed in Part 2 - Format reference missing";

    //Step 2.3 - Find the Mode refAddr movement after it. We will inject a Jump to our code here.
    code =
        " E8 ?? ?? ?? FF"    //CALL addr
    +   " 8B 0D ?? ?? ?? 00" //MOV ECX, DWORD PTR DS:[refAddr]
    ;

    offset = Exe.FindHex(code, offset + 0x5, offset + 0x80);
    if (offset === -1)
        return "Failed in Part 2 - Reference Address missing";

    //Step 2.4 - Update offset to MOV ECX location
    offset += 5;

    //Step 2.5 - Extract the ECX assignment which we will need twice later on.
    var movEcx = Exe.GetHex(offset, 6);

    //Step 2.6 - Find the Mode Changer CALL after offset
    code =
        " 6A 02" //PUSH 2
    +   " FF D0" //CALL EAX
    ;
    var offset2 = Exe.FindHex(code, offset + 0x6, offset + 0x20);

    if (offset2 === -1)
    {
        code = code.replace("D0", "50 18"); //Change CALL EAX to CALL DWORD PTR DS:[EAX+18]
        offset2 = Exe.FindHex(code, offset + 0x6, offset + 0x20);
    }
    if (offset2 === -1)
        return "Failed in Part 2 - Mode Changer call missing";

    //Step 2.7 - Get the number of PUSH 0 . We need to push the same number in our code
    var zeroPushes = Exe.FindAllHex("6A 00", offset + 6, offset2);
    if (zeroPushes.length === 0)
        return "Failed in Part 2 - Zero Pushes not found";

    //Step 2.8 - Set offset2 to after the CALL. which is the address we need to return to after Mode Changer call
    offset2 += code.byteCount();

    //Step 3.1 - Prep our code (same as what was there but arg1 will be 271D and [this + 3] is assigned 3 before the call)
    code =
        movEcx                                        //MOV ECX, DWORD PTR DS:[refAddr]
    +   " 8B 01"                                      //MOV EAX, DWORD PTR DS:[ECX]
    +   " 6A 00".repeat(zeroPushes.length)            //PUSH 0 - n times
    +   " 68 1D 27 00 00"                             //PUSH 271D
    +   " C7 41 0C 03 00 00 00"                       //MOV DWORD PTR DS:[ECX+0C],3
    +   " 68" + Num2Hex(Exe.Real2Virl(offset2, CODE)) //PUSH offset2
    +   " FF 60 18"                                   //JMP DWORD PTR DS:[EAX+18]
    ;

    //Step 3.2 - Find Free space for insertion
    var free = Exe.FindSpace(code.byteCount());
    if (free === -1)
        return "Failed in Part 3 - Not enough free space";

    //Step 3.3 - Insert code at free space
    Exe.InsertHex(free, code, code.byteCount());

    //Step 3.4 - Change the MOV ECX to a JMP to above code
    Exe.ReplaceHex(offset, "90 E9" + Num2Hex(Exe.Real2Virl(free, DIFF) - Exe.Real2Virl(offset + 6, CODE)));

    /******* Next we will work on DC during Gameplay *******/

    //Step 4.1 - Check if there is a short Jump after the MsgString ID PUSH . If its there go to the address
    if (Exe.GetUint8(offsets[0]) === 0xEB)
    {
        offset = offsets[0] + 2 + Exe.GetInt8(offsets[0] + 1);
    }
    else
    {
        //Step 4.2 - If not look for a Long Jump after the PUSH
        offset = Exe.FindHex("E9 ?? ?? 00 00", offsets[0], offsets[0] + 0x100);
        if (offset === -1)
            return "Failed in Part 4 - JMP to Mode call missing";

        //Step 4.3 - Goto the JMP address
        offset += 5 + Exe.GetInt32(offset + 1);
    }

    //Step 4.4 - Look for the ErrorMsg (Error Message Window displayer function) CALL after the offset
    code =
        " B9 ?? ?? ?? 00" //MOV ECX, OFFSET g_windowMgr
    +   " E8 ?? ?? ?? FF" //CALL UIWindowMgr::ErrorMsg
    ;

    offset = Exe.FindHex(code, offset, offset + 0x100);
    if (offset === -1)
        return "Failed in Part 4 - ErrorMsg call missing";

    //Step 4.5 - Set offset to location after the CALL
    offset += code.byteCount();
    //return "" + Num2Hex(Exe.Real2Virl(offset), 4, true);
    //Step 4.6 - Now look for the Mode Changer CALL after <offset>
    code =
        " 6A 02"    //PUSH 2
    +   " 8B CF"    //MOV ECX, EDI
    +   " FF 50 18" //CALL DWORD PTR DS:[EAX+18]
    ;
    offset2 = Exe.FindHex(code, offset, offset + 0x20);

    if (offset2 === -1)
    {
        code = code.replace("50 18", "D0"); //Change CALL DWORD PTR DS:[EAX+18] to CALL EAX
        offset2 = Exe.FindHex(code, offset, offset + 0x20);
    }
    if (offset2 === -1)
    {
        code = code.replace("8B CF", "8B CD"); //Change EDI to EBP in ECX assignment
        offset2 = Exe.FindHex(code, offset, offset + 0x20);
    }
    if (offset2 === -1)
    {
        code = code.replace("D0", "D2").replace(" 8B CD", ""); //Change CALL EAX to CALL EDX and remove the ECX assignment
        offset2 = Exe.FindHex(code, offset, offset + 0x20);
    }
    if (offset2 === -1)
        return "Failed in Part 4 - Mode Call missing";

    //Step 4.7 - Set offset2 to after the CALL. This is the Return address
    offset2 += code.byteCount();

    //Step 5.1 - Prep code for insertion . Like Before we have done few changes
    //                 (arg1 is 8D and ECX is loaded from refAddr instead of depending on some local - value will be same either way)
    code =
        movEcx                                        //MOV ECX, DWORD PTR DS:[refAddr]
    +   " 8B 01"                                      //MOV EAX, DWORD PTR DS:[ECX]
    +   " 6A 00".repeat(zeroPushes.length)            //PUSH 0 - n times
    +   " 68 8D 00 00 00"                             //PUSH 8D
    +   " 68" + Num2Hex(Exe.Real2Virl(offset2, CODE)) //PUSH offset2
    +   " FF 60 18"                                   //JMP DWORD PTR DS:[EAX+18]
    ;

    //Step 5.2 - Find Free space for insertion
    free = Exe.FindSpace(code.byteCount());
    if (free === -1)
        return "Failed in Part 5 - Not enough free space";

    //Step 5.3 - Insert the code at free space
    Exe.InsertHex(free, code, code.byteCount());

    //Step 5.4 - Replace the code at offset with JMP to our code.
    Exe.ReplaceHex(offset, "E9" + Num2Hex(Exe.Real2Virl(free, DIFF) - Exe.Real2Virl(offset + 5, CODE)));
    return true;
}

///==========================================================================///
/// Disable for Unneeded Clients - Only Certain Client onwards tries to quit ///
///==========================================================================///
function DcToLoginWindow_()
{
    return (Exe.GetDate() > 20100730);
}