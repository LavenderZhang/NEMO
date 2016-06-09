//##################################################################################\\
//# Modify the JPEG_CORE_PROPERTIES structure assignment inside CRenderer::SaveJPG #\\
//# function to set jquality member to user specified value.                       #\\
//##################################################################################\\

function IncreaseScreenshotQuality()
{
    //Step 1 - Find the JPEG_CORE_PROPERTIES member assignments (DIBChannels & DIBColor)
    if (EBP_TYPE)
        var prefix = " C7 85 ?? ?? FF FF"; //MOV DWORD PTR SS:[EBP-x], const
    else
        var prefix = " C7 44 24 ??"; //MOV DWORD PTR SS:[ESP+x], const

    var code =
        prefix + " 03 00 00 00" //const = 3; DIBChannels
    +   prefix + " 02 00 00 00" //const = 2; DIBColor
    ;
    var offset = Exe.FindHex(code);

    if (offset === -1)
    {
        if (EBP_TYPE)
            code = code.replace(/ 85 ?? ?? FF FF/g, " 45 ??");
        else
            code = code.replace(/ 44 24 ??/g, " 84 24 ?? ?? 00 00");

        offset = Exe.FindHex(code);
    }
    if (offset === -1)
        return "Failed in Step 1";

    var csize = code.byteCount() / 2;//Length of 1 assignment

    //Step 2.1 - Get new quality value from user
    var newValue = Exe.GetUserInput('$uQuality', I_INT8, "Number Input", "Enter the new quality factor (0-100)", 50, 0, 100);
    if (newValue === 50)
        return "Patch Cancelled - New value is same as old";

    //Step 2.2 - Get the jquality offset = DIBChannels + 60
    if (EBP_TYPE)
        var offset2 = offset + 2;
    else
        var offset2 = offset + 3;

    if ((Exe.GetUint8(offset + 1) & 0x80) !== 0) //Whether the stack offset is 4 byte or 1 byte
        offset2 = Exe.GetInt32(offset2) + 60;
    else
        offset2 = Exe.GetInt8(offset2) + 60;

    //Step 2.3 - Prep code to change DIBChannels member assignment to jquality member assignment.
    //                    By default DIBChannels is 3 and DIBColor is 2 already, so overwriting their assignments doesnt matter
    if (offset2 < -128 || offset2 > 127) //offset2 is 4 byte
    {
        if (EBP_TYPE)
            code = "C7 85" + Num2Hex(offset2) + Num2Hex(newValue); //MOV DWORD PTR SS:[EBP+offset2], newValue ;offset2 is negative
        else
            code = "C7 84 24" + Num2Hex(offset2) + Num2Hex(newValue); //MOV DWORD PTR SS:[ESP+offset2], newValue
    }
    else //offset2 is 1 byte
    {
        if (EBP_TYPE)
            code = "C7 45" + Num2Hex(offset2, 1) + Num2Hex(newValue); //MOV DWORD PTR SS:[EBP+offset2], newValue ;offset2 is negative
        else
            code = "C7 44 24" + Num2Hex(offset2, 1) + Num2Hex(newValue); //MOV DWORD PTR SS:[ESP+offset2], newValue
    }

    //Step 3.1 - Add NOPs to fill any excess/less bytes remaining
    if (code.byteCount() < csize)
        code += " 90".repeat(csize - code.byteCount());
    else if (code.byteCount() > csize)
        code += " 90".repeat(csize * 2 - code.byteCount());

    //Step 3.2 - Now write into client.
    Exe.ReplaceHex(offset, code);
    return true;
}