///============================================================///
/// Patch Functions wrapping over DisableSkillChatter function ///
///============================================================///

function DisableBAFrostJoke()
{
    return DisableSkillChatter("BA_frostjoke.txt");
}

function DisableDCScream()
{
    return DisableSkillChatter("DC_scream.txt");
}

//##########################################\\
//# Zero out the txt file strings used in  #\\
//# random Chat skills - Frost Joke/Scream #\\
//##########################################\\

function DisableSkillChatter(suffix)
{
    //Step 1.1 - Find the 1st text file offset
    var offset = Exe.FindString("english\\" + suffix, REAL);
    if (offset === -1)
        return "Failed in Step 1";

    //Step 1.2 - Zero it out
    Exe.ReplaceInt8(offset, 0);

    //Step 2.1 - Find the 2nd one
    offset = Exe.FindString(suffix, REAL);
    if (offset === -1)
        return "Failed in Step 2";

    //Step 2.2 - Zero it out
    Exe.ReplaceInt8(offset, 0);
    return true;
}