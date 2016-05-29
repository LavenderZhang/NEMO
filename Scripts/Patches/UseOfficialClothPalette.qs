//#################################################################\\
//# Change the JNE after LangType comparison when loading Palette #\\
//# prefixes into Palette Table in CSession::InitJobTable         #\\
//#################################################################\\

function UseOfficialClothPalette()
{
    //Step 1.1 - Check if Custom Job patch is being used. Does not work with it
    if (GetActivePatches().indexOf(202) !== -1)
        return "Patch Cancelled - Turn off Custom Job patch first";

    //Step 1.2 - Find offset of palette prefix for Knight - Å©·ç
    var offset = Exe.FindString("\xC5\xA9\xB7\xE7", VIRTUAL); //Same value is used for job path as well as imf
    if (offset === -1)
        return "Failed in Step 1 - Palette prefix missing";

    //Step 2.1 - Find its references
    var offsets = Exe.FindAllHex("C7 ?? 38" + Num2Hex(offset));

    //Step 2.2 - Find the JNE before one of the references - only 1 will have it for sure
    var offset2 = -1;

    for (var i = 0; i < offsets.length; i++)
    {
        offset2 = Exe.FindHex("0F 85 ?? ?? 00 00", offsets[i] - 0x20, offsets[i]);
        if (offset2 !== -1)
            break;
    }

    //Step 2.3 - If no match came up then its probably a 2010 client which used function calls to get the mem location
    if (offset2 === -1)
    {
        offsets = Exe.FindAllHex("C7 00" + Num2Hex(offset) + " E8");

        //Step 2.4 - Repeat Step 2b for these offsets
        for (var i = 0; i < offsets.length; i++)
        {
            offset2 = Exe.FindHex("0F 85 ?? ?? 00 00", offsets[i] - 0x20, offsets[i]);
            if (offset2 !== -1)
                break;
        }
    }
    if (offset2 === -1)
        return "Failed in Step 2 - Prefix reference missing";

    //Step 2.5 - NOP out the JNE
    Exe.ReplaceHex(offset2, "90 90 90 90 90 90");
    return true;
}