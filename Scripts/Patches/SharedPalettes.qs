///=======================================================///
/// Patch Functions wrapping over SharedPalettes function ///
///=======================================================///

function SharedBodyPalettesV1()
{
    // "个\%s_%s_%d.pal" => "个\body%.s_%s_%d.pal"

    return SharedPalettes("\xB8\xF6\\", "\xB8\xF6\\body%.s_%s_%d.pal\x00"); //%.s is required. Skips jobname
}

function SharedBodyPalettesV2()
{
    // "个\%s_%s_%d.pal" => "个\body%.s%.s_%d.pal"

    return SharedPalettes("\xB8\xF6\\", "\xB8\xF6\\body%.s%.s_%d.pal\x00"); //%.s is required. Skips jobname & gender
}

function SharedHeadPalettesV1()
{
    // "赣府\赣府%s_%s_%d.pal" => "赣府\head%.s_%s_%d.pal"

    return SharedPalettes("\xB8\xD3\xB8\xAE\\\xB8\xD3\xB8\xAE", "\xB8\xD3\xB8\xAE\\head%.s_%s_%d.pal\x00");// %.s is required. Skips jobname
}

function SharedHeadPalettesV2()
{
    // "赣府\赣府%s_%s_%d.pal" => "赣府\head%.s%.s_%d.pal"

    return SharedPalettes("\xB8\xD3\xB8\xAE\\\xB8\xD3\xB8\xAE", "\xB8\xD3\xB8\xAE\\head%.s%.s_%d.pal\x00");// %.s is required. Skips jobname & gender
}

//############################################################################\\
//# Change the format string used in CSession::GetBodyPaletteName (for Body) #\\
//# or CSession::GetHeadPaletteName (for Head) to skip some arguments        #\\
//############################################################################\\

function SharedPalettes(prefix, newString)
{
    //Step 1.1 - Find original Format String
    var offset = Exe.FindString(prefix + "%s%s_%d.pal", VIRTUAL);//<prefix>%s%s_%d.pal - Old Format

    if (offset === -1)
        offset = Exe.FindString(prefix + "%s_%s_%d.pal", VIRTUAL);//<prefix>%s_%s_%d.pal - New Format

    if (offset === -1)
        return "Failed in Step 1 - Format String missing";

    //Step 1.2 - Find its reference
    offset = Exe.FindHex("68" + Num2Hex(offset));
    if (offset === -1)
        return "Failed in Step 1 - Format String reference missing";

    //Step 2.1 - Find Free space for insertion - Original address don't have enough space for some scenarios.
    var free = Exe.FindSpace(newString.length);
    if (free === -1)
        return "Failed in Step 2 - Not enough free space";

    //Step 2.2 - Insert the new format string at free space
    Exe.InsertString(free, newString, newString.length);

    //Step 3 - Replace reference with new one's address
    Exe.ReplaceInt32(offset + 1, Exe.Real2Virl(free, DIFF));
    return true;
}