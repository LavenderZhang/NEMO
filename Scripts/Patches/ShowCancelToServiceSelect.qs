//######################################################\\
//# Modify the Coordinates of Login and Cancel buttons #\\
//# to show both of them in Login Screen.              #\\
//######################################################\\

function ShowCancelToServiceSelect()
{
    //Step 1.1 - Find "btn_intro_b"
    var offset = Exe.FindString("btn_intro_b", VIRTUAL);
    if (offset === -1)
        return "Failed in Step 1 - btn_intro_b missing";

    //Step 1.2 - Find its reference (inside UILoginWnd::OnCreate)
    var code = Num2Hex(offset) + " C7";

    offset = Exe.FindHex(code);
    if (offset === -1)
        return "Failed in Step 1 - btn_intro_b reference missing";

    //Step 1.3 - Update offset to the MOV instruction after it
    offset += code.byteCount();

    //Step 2.1 - Find the x-coord of login button (btn_connect)
    if (EBP_TYPE)
        code = "C7 45 ?? BD 00 00 00"; //MOV DWORD PTR SS:[EBP-x], 0BD
    else
        code = "C7 44 24 ?? BD 00 00 00"; //MOV DWORD PTR SS:[ESP+x], 0BD

    var offset2 = Exe.FindHex(code, offset, offset + 0x40);

    if (offset2 === -1) //x > 0x7F
    {
        if (EBP_TYPE)
            code = "C7 85 ?? FF FF FF BD 00 00 00"; //MOV DWORD PTR SS:[EBP-x], 0BD
        else
            code = "C7 84 24 ?? FF FF FF BD 00 00 00"; //MOV DWORD PTR SS:[ESP+x], 0BD

        offset2 = Exe.FindHex(code, offset, offset + 0x40);
    }
    if (offset2 === -1)
        return "Failed in Step 2 - login coordinate missing";

    //Step 2.2 - Save the location after the X-Coord assignment
    offset = offset2 + code.byteCount();

    //Step 2.3 - Change 0xBD to 0x90 (its not a NOP xD)
    Exe.ReplaceInt32(offset - 4, 0x90);

    //Step 3.1 - Find the x-coord of cancel button after login coord.
    code = code.replace("BD 00", "B2 01"); //swap 0BD with 1B2

    offset = Exe.FindHex(code, offset, offset + 0x30);
    if (offset === -1)
        return "Failed in Step 2 - cancel coordinate missing";

    //Step 3.2 - Update offset to location after the MOV instruction
    offset += code.byteCount();

    //Step 2.4 - Change 0x1B2 to 0xBD
    Exe.ReplaceInt32(offset - 4, 0xBD);
    return true;
}

///==============================================================================///
/// Disable for Unneeded Clients - Only Certain Client onwards shows Exit button ///
///==============================================================================///
function ShowCancelToServiceSelect_()
{
    return (Exe.GetDate() > 20100803);
}