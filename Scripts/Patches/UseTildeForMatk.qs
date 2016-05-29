//##################################################\\
//# Replace the Format string used for Matk values #\\
//# with the one using tilde symbol                #\\
//##################################################\\

function UseTildeForMatk()
{
    //Step 1.1 - Find the original format string
    var offset = Exe.FindString("%d + %d", VIRTUAL);
    if (offset === -1)
        return "Failed in Step 1 - Format string missing";

    //Step 1.2 - Find all its references (there should be exactly 5 matches)
    var offsets = Exe.FindAllHex("68" + Num2Hex(offset));
    if (offsets.length !== 5)
        return "Failed in Step 1 - Not enough matches";

    //Step 2.1 - Find the format string to replace with
    offset = Exe.FindString("%d ~ %d", VIRTUAL);
    if (offset === -1)
    {
        //Step 2.2 - If not present, Find Free Space for insertion
        offset = Exe.FindSpace(8);//Size of the above
        if (offset === -1)
            return "Failed in Step 2 - Not enough free space";

        //Step 2.3 - Insert the string in free space
        Exe.InsertString(offset, "%d ~ %d", 8);

        //Step 2.4 - Get its Virl Address
        offset = Exe.Real2Virl(offset, DIFF);
    }

    //Step 3 - Replace the format string at the 2nd matched location out of the 5
    Exe.ReplaceInt32(offsets[1] + 1, offset);
    return true;
}