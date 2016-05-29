//#########################################################################\\
//# Overwrite all entries in the Font Name Array with user specified name #\\
//#########################################################################\\

function UseCustomFont()
{
    //Step 1.1 - Find "Gulim" - Korean language font which serves as the first entry of the array
    var gulOffset = Exe.FindString("Gulim", VIRTUAL, false);
    if (gulOffset === -1)
        return "Failed in Step 1 - Gulim not found";

    //Step 1.2 - Find its reference - Usually it is within .data section (but just in case we will look at all offsets after CODE section)
    var offset = Exe.FindHex(Num2Hex(gulOffset), Exe.GetRealOffset(CODE) + Exe.GetRealSize(CODE), Exe.GetSize());
    if (offset === -1)
        return "Failed in Step 1 - Gulim reference not found";

    //Step 2.1 - Get the Font name from user
    var newFont = Exe.GetUserInput("$newFont", I_FONT, 'Font input', 'Select the new Font Family', "Arial");
    if (!newFont)
        return "Patch Cancelled";

    //Step 2.2 - Get its address if its already existing
    var free = Exe.FindString(newFont, REAL);

    //Step 2.3 - Otherwise Insert the font in the xdiff section
    if (free === -1)
    {
        free = Exe.FindSpace(newFont.length + 1);
        if (free === -1)
            return "Failed in Step 2 - Not enough free space";

        Exe.InsertString(free, "$newFont", newFont.length + 1);
    }

    var freeVirl = Exe.Real2Virl(free, DIFF);

    //Step 3 - Overwrite all entries with the custom font address
    gulOffset &= 0xFFF00000;
    do
    {
        Exe.ReplaceInt32(offset, freeVirl);
        offset += 4;
    } while((Exe.GetInt32(offset) & gulOffset) === gulOffset);

    /*==================================================================
    NOTE: this might not be entirely fool-proof, but we cannot depend
                on the fact the array ends with 0x00000081 (CHARSET_HANGUL).
                It can change in any client.
    ==================================================================*/

    return true;
}