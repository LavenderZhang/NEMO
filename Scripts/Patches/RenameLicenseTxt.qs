//#########################################################\\
//# Change the "..\\licence.txt" reference to custom file #\\
//# specified by user and Update "No EULA " reference     #\\
//#########################################################\\

function RenameLicenseTxt()
{
    //Step 1.1 - Find licence.txt string
    var offset = Exe.FindString("..\\licence.txt", VIRTUAL);
    if (offset === -1)
        return "Failed in Step 1 - File string missing";

    //Step 1.2 - Find its reference
    offset = Exe.FindHex("C7 05 ?? ?? ?? 00" + Num2Hex(offset)); //MOV DWORD PTR DS:[g_licence], stringAddr
    if (offset === -1)
        return "Failed in Step 1 - String reference missing";

    //Step 2.1 - Get new Filename from user
    var txtFile = Exe.GetUserInput('$licenseTXT', I_STRING, "String Input", "Enter the name of the Txt file", "..\\licence.txt", 1, 20);
    if (!txtFile)
        return "Patch Cancelled";

    if (txtFile === "..\\licence.txt\0")
        return "Patch Cancelled - New Name is same as Old Name";

    //Step 2.2 - Find Free space for insertion
    var free = Exe.FindSpace(txtFile.length);
    if (free === -1)
        return "Failed in Step 2 - Not enough free space";

    //Step 2.3 - Insert the new name at free space
    Exe.InsertString(free, '$licenseTXT', txtFile.length);

    //Step 2.4 - Update the reference to point to new name
    Exe.ReplaceInt32(offset + 6, Exe.Real2Virl(free, DIFF));

    //Step 3.1 - Find the Error string address
    offset = Exe.FindString("No EULA text file. (licence.txt)", VIRTUAL);
    if (offset === -1)
        return "Failed in Step 3 - Error string missing";

    //Step 3.2 - Make the new string using the new licence filename
    txtFile = "No EULA text file. (" + txtFile.replace("..\\", "") + ")";

    //Step 3.3 - Find Free space for insertion
    free = Exe.FindSpace(txtFile.length);
    if (free === -1)
        return "Failed in Step 3 - Not enough free space";

    //Step 3.4 - Insert the Error string at free space
    Exe.InsertString(free, txtFile, txtFile.length);

    //Step 3.5 - Update all the Error string references
    var prefixes = ["6A 20 68", "BE", "BF"];
    var freeVirl = Exe.Real2Virl(free, DIFF);

    for (var i = 0; i < prefixes.length; i++)
    {
        var offsets = Exe.FindAllHex(prefixes[i] + Num2Hex(offset));
        for (var j = 0; j < offsets.length; j++)
        {
            Exe.ReplaceInt32(offsets[j] + prefixes[i].byteCount(), freeVirl);
        }
    }
    return true;
}