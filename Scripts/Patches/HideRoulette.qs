//##########################################################################\\
//# Make client skip over the Roulette Icon UIWindow creation (ID = 0x11D) #\\
//##########################################################################\\

function HideRoulette()
{
    //Step 1.1 - Check if Window Manager info is available (WM.Error will be a string if not)
    if (WM.Error)
        return "Failed in Step 1 - " + WM.Error;

    //Step 1.2 - Find the UIWindow creation before Roulette (which is always present - 0xB5)
    var code =
        " 74 0F"          //JE SHORT addr
    +   " 68 B5 00 00 00" //PUSH 0B5
    +   WM.MovEcx         //MOV ECX, OFFSET g_windowMgr
    +   " E8"             //CALL UIWindowMgr::MakeWindow
    ;

    var offset = Exe.FindHex(code);
    if (offset === -1)
        return "Failed in Step 1 - Reference Code missing";

    //Step 1.3 - Update offset to location after CALL
    offset += code.byteCount() + 4;

    //Step 2.1 - Check if the Succeding operation is Roulette UIWindow creation or not
    if (Exe.GetInt32(offset + 1) !== 0x11D)
        return "Patch Cancelled - Roulette is already hidden";

    //Step 2.2 - If yes JMP over it
    Exe.ReplaceHex(offset, "EB 0D"); //Skip over rest of the PUSH followed by ECX assignment and Function call
}

///======================================================///
/// Disable for Unsupported Clients - Check for Icon bmp ///
///======================================================///
function HideRoulette_()
{
    return (Exe.FindString("\xC0\xAF\xC0\xFA\xC0\xCE\xC5\xCD\xC6\xE4\xC0\xCC\xBD\xBA\\basic_interface\\roullette\\RoulletteIcon.bmp", REAL) !== -1);
}