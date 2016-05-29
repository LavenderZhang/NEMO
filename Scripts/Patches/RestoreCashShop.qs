//############################################################\\
//# Restore the Cash Shop Icon UIWindow creation (ID = 0xBE) #\\
//############################################################\\

function RestoreCashShop()
{
    //Step 1.1 - Check if Window Manager info is available
    if (WM.Error)
        return "Failed in Step 1 - " + WM.Error;

    //Step 1.2 - Find the location where the cash shop icon was supposed to be created
    code =
        " 75 0F"          //JNE addr; skips to location after the call for creating another icon
    +   " 68 9F 00 00 00" //PUSH 09F
    +   WM.MovEcx         //MOV ECX, OFFSET g_windowMgr
    +   " E8"             //CALL UIWindowMgr::MakeWindow
    ;

    offset = Exe.FindHex(code);
    if (offset === -1)
        return "Failed in Step 2";

    //Step 1.3 - Set offset2 to location after the CALL
    var offset2 = offset + code.byteCount() + 4;

    //Step 1.4 - Check if the cash shop Icon is being created before offset
    if (Exe.FindHex("68 BE 00 00 00" + WM.MovEcx, "", offset - 0x30, offset) !== -1)
        return "Patch Cancelled - Icon is already there";

    //Step 2.1 - Prep insert code (starting portion is same as above hence we dont repeat it)
    code +=
        MakeVar(1)         //CALL UIWindowMgr::MakeWindow ; E8 opcode is already there
    +   " 68 BE 00 00 00"  //PUSH 0BE
    +   WM.MovEcx          //MOV ECX, OFFSET g_windowMgr
    +   " E8" + MakeVar(2) //CALL UIWindowMgr::MakeWindow
    +   " E9" + MakeVar(3) //JMP offset2; jump back to offset2
    ;

    //Step 2.2 - Find Free space for insertion
    var free = Exe.FindSpace(code.byteCount());
    if (free === -1)
        return "Failed in Step 3 - Not enough free space";

    var refAddr = Exe.Real2Virl(free + (offset2 - offset), DIFF);

    //Step 2.3 - Fill in the blanks.
    code = SetValue(code, 1, WM.MakeWin - (refAddr));
    code = SetValue(code, 2, WM.MakeWin - (refAddr + 15)); // (PUSH + MOV + CALL)
    code = SetValue(code, 3, Exe.Real2Virl(offset2, CODE) - (refAddr + 20)); // (PUSH + MOV + CALL + JMP)

    //Step 3 - Insert the code at free space and create the JMP to it.
    Exe.InsertHex(free, code, code.byteCount());
    Exe.ReplaceHex(offset, "E9" + Num2Hex(Exe.Real2Virl(free, DIFF) - Exe.Real2Virl(offset + 5, CODE)));

    return true;
}

///======================================================///
/// Disable for Unsupported Clients - Check for Icon bmp ///
///======================================================///
function RestoreCashShop_()
{
    return (Exe.FindString("NC_CashShop", REAL) !== -1);
}