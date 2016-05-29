//################################################\\
//# Make the function which loads the EffectTool #\\
//# lua files skip the Jump for specific maps    #\\
//################################################\\

function EnableEffectForAllMaps()
{
    //Step 1.1 - Find Lua file prefix string
    var offset = Exe.FindString("Lua Files\\EffectTool\\", VIRTUAL);
    if (offset === -1)
        return "Failed in Step 1 - String missing";

    //Step 1.2 - Find its reference
    offset = Exe.FindHex("68" + Num2Hex(offset));//PUSH addr
    if (offset === -1)
        return "Failed in Step 1 - String Reference missing";

    //Step 2.1 - Find the JE before the PUSH
    offset = Exe.FindHex("0F 84 ?? ?? 00 00", offset - 0x20, offset);
    if (offset === -1)
        return "Failed in Step 2 - Jump missing";

    //Step 2.2 - Replace with a JMP that skips over the 6 bytes (2 gone for the code itself hence 04)
    Exe.ReplaceHex(offset, "EB 04");
    return true;
}