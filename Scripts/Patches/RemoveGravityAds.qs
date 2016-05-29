//##################################\\
//# Zero out all Gravity Ad Images #\\
//##################################\\

function RemoveGravityAds()
{
    //Step 1.1 - Find 1st Pic suffix => "\T_중력성인.tga"
    var offset = Exe.FindString("\\T_\xC1\xDF\xB7\xC2\xBC\xBA\xC0\xCE.tga", REAL, false);
    if (offset === -1)
        return "Failed in Step 1";

    //Step 1.2 - Replace with NULL
    Exe.ReplaceInt8(offset + 1, 0);

    //Step 2.1 - Find 2nd Pic suffix => "\T_GameGrade.tga"
    offset = Exe.FindString("\\T_GameGrade.tga", REAL, false);
    if (offset === -1)
        return "Failed in Step 2";

    //Step 2.2 - Replace with NULL
    Exe.ReplaceInt8(offset + 1, 0);

    //Step 3.1 - Find Last Pic suffix => "\T_테입%d.tga"
    offset = Exe.FindString("\\T_\xC5\xD7\xC0\xD4%d.tga", REAL, false);
    if (offset === -1)
        return "Failed in Step 3";

    //Step 3.2 - Replace with NULL
    Exe.ReplaceInt8(offset + 1, 0);
    return true;
}