//###############################\\
//# Zero out Gravity Logo Image #\\
//###############################\\

function RemoveGravityLogo()
{
    //Step 1.1 - Find the image suffix
    var offset = Exe.FindString("\\T_R%d.tga", REAL, false);
    if (offset === -1)
        return "Failed in Step 1";

    //Step 1.2 - Replace with NULL
    Exe.ReplaceInt8(offset + 1, 0);
    return true;
}