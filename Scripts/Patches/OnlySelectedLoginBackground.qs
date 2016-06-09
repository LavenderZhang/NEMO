///===============================================================///
/// Patch Functions wrapping over OnlySelectedBackground function ///
///===============================================================///

function OnlyFirstLoginBackground() //Change 2 to 1
{
    return OnlySelectedBackground("2", "");
}

function OnlySecondLoginBackground() //Change 1 to 2
{
    return OnlySelectedBackground("", "2");
}

//################################################################################\\
//# Change one of the Login Background format strings (str1) to the other (str2) #\\
//################################################################################\\

function OnlySelectedBackground(str1, str2)
{
    //Step 1.1 - Prepare Strings to Find and Replace using suffixes str1 and str2 respectively
    var src = "\xC0\xAF\xC0\xFA\xC0\xCE\xC5\xCD\xC6\xE4\xC0\xCC\xBD\xBA\\T" + str1 + "_\xB9\xE8\xB0\xE6" + "%d-%d.bmp";
    if (str1 === "")
        src += "\x00";

    var tgt = str2 + "_\xB9\xE8\xB0\xE6" + "%d-%d.bmp" + "\x00"; //Directory prefix is same so we don't need it while replacing

    //Step 1.2 - Find string => src
    var offset = Exe.FindString(src, REAL, false);
    if (offset === -1)
        return "Failed in Step 1";

    //Step 2 - Replace after the dir prefix (16 bytes later) with the 2nd string => tgt
    Exe.ReplaceString(offset + 16, tgt);

    return true;
}