//#########################################################################################\\
//# Zero out 'manner.txt' to prevent any reference bad words from loading to compare with #\\
//#########################################################################################\\

function DisableSwearFilter()
{
    //Step 1 - Find "manner.txt"
    var offset = Exe.FindString("manner.txt", REAL);
    if (offset === -1)
        return "Failed in Step 1";

    //Step 2 - Replace with Zero
    Exe.ReplaceInt8(offset, 0);
    return true;
}