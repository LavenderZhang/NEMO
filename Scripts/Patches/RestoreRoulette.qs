//############################################################\\
//# Restore the Roulette Icon UIWindow creation (ID = 0x11D) #\\
//############################################################\\

function RestoreRoulette()
{
    //Step 1.1 - Check if Window Manager info is available
    if (WM.Error)
        return "Failed in Step 1 - " + WM.Error;

    //Step 1.2 - Find the location where the roulette icon was supposed to be created
    code =
        " 74 0F"          //JE addr; skips to location after the call for creating vend search window below
    +   " 68 B5 00 00 00" //PUSH 0B5
    +   WM.MovEcx         //MOV ECX, OFFSET g_windowMgr
    +   " E8"             //CALL UIWindowMgr::MakeWindow
    ;

    var offset = Exe.FindHex(code);
    if (offset === -1)
        return "Failed in Step 2";

    //Step 1.3 - Set offset2 to location after the CALL
    var offset2 = offset + code.byteCount() + 4;

    //Step 1.4 - Get mode constant based on client date.
    if (Exe.GetDate() > 20150800)
        var mode = 0x10C;
    else
        var mode = 0x11D;

    //Step 1.5 - Check if the roulette icon is already created (check for PUSH mode after the CALL)
    if (Exe.GetInt32(offset2 + 1) === mode)
        return "Patch Cancelled - Roulette is already enabled";

    //Step 2.1 - Prep insert code (starting portion is same as above hence we dont repeat it)
    code +=
        MakeVar(1)         //CALL UIWindowMgr::MakeWindow ; E8 opcode is already there
    +   " 68" + MakeVar(2) //PUSH mode
    +   WM.MovEcx          //MOV ECX, OFFSET g_windowMgr
    +   " E8" + MakeVar(3) //CALL UIWindowMgr::MakeWindow
    +   " E9" + MakeVar(4) //JMP offset2; jump back to offset2
    ;

    //Step 2.2 - Find Free space for insertion
    var free = Exe.FindSpace(code.byteCount());
    if (free === -1)
        return "Failed in Step 3 - Not enough free space";

    var refAddr = Exe.Real2Virl(free + (offset2 - offset), DIFF);

    //Step 2.3 - Fill in the blanks.
    code = SetValue(code, 1, WM.MakeWin - (refAddr));
    code = SetValue(code, 2, mode);
    code = SetValue(code, 3, WM.MakeWin - (refAddr + 15));// (PUSH + MOV + CALL)
    code = SetValue(code, 4, Exe.Real2Virl(offset2, CODE) - (refAddr + 20));// (PUSH + MOV + CALL + JMP)

    //Step 3 - Insert the code at free space and create the JMP to it.
    Exe.InsertHex(free, code, code.byteCount());
    Exe.ReplaceHex(offset, "E9" + Num2Hex(Exe.Real2Virl(free, DIFF) - Exe.Real2Virl(offset + 5, CODE)));

    return true;
}

///======================================================///
/// Disable for Unsupported Clients - Check for Icon bmp ///
///======================================================///
function RestoreRoulette_()
{
    return (Exe.FindString("\xC0\xAF\xC0\xFA\xC0\xCE\xC5\xCD\xC6\xE4\xC0\xCC\xBD\xBA\\basic_interface\\roullette\\RoulletteIcon.bmp", REAL) !== -1);
}