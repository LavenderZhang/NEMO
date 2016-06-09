//#####################################################################\\
//# Switch "Ragnarok" reference with address of User specified Window #\\
//# Title which will be that of unused URL string that is overwritten #\\
//#####################################################################\\

function CustomWindowTitle()
{
    //Step 1.1 - Find the offset of the URL to overwrite (since its not even used)
    var strOff = Exe.FindString("http://ro.hangame.com/login/loginstep.asp?prevURL=/NHNCommon/NHN/Memberjoin.asp", REAL);
    if (strOff === -1)
        return "Failed in Step 1";

    //Step 1.2 - Find "Ragnarok"
    var offset = Exe.FindString("Ragnarok", VIRTUAL);
    if (offset === -1)
        return "Failed in Step 1 - Original title missing";

    //Step 1.3 - Find its reference
    var code = "C7 05 ?? ?? ?? 00" + Num2Hex(offset); //MOV DWORD PTR DS:[g_title], OFFSET addr; ASCII "Ragnarok"
    offset = Exe.FindHex(code);
    if (offset === -1)
        return "Failed in Step 1 - Title reference missing";

    //Step 1.4 - Update offset to the g_title portion of the instruction
    offset += code.byteCount() - 4;

    //Step 2.1 - Get the new Title from User
    var title = Exe.GetUserInput('$customWindowTitle', I_STRING, "String Input - maximum 60 characters", "Enter the new window Title", "Ragnarok", 1, 60);//60 is the length of the URL
    if (!title)
        return "Patch Cancelled";
    
    if (title === "Ragnarok\0")
        return "Patch Cancelled - New Title is same as old";

    //Step 2.2 - Overwrite URL with the new Title
    Exe.ReplaceString(strOff, '$customWindowTitle');

    //Step 2.3 - Replace the original reference with the URL offset.
    Exe.ReplaceInt32(offset, Exe.Real2Virl(strOff, DATA));
    return true;
}