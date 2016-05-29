//###############################################################\\
//# Fixup all the LangType comparison Jumps in Mailbox function #\\
//###############################################################\\

function EnableMailBox()
{
    //Step 1.1 - Prep codes for finding short jumps
    var code    =
        " 74 ??"    //JE SHORT addr1 (prev statement is either TEST EAX, EAX or CMP EAX, r32 => both instructions use 2 bytes)
    +   " 83 F8 08" //CMP EAX,08
    +   " 74 ??"    //JE SHORT addr1
    +   " 83 F8 09" //CMP EAX,09
    +   " 74 ??"    //JE SHORT addr1
    ;

    var pat1 = " 8B 8E ?? 00 00 00"; //MOV ECX, DWORD PTR DS:[ESI+const]
    var pat2 = " BB 01 00 00 00"; //MOV EBX,1

    //Step 1.2 - Find all occurences of 1st LangType comparison pattern in the mailbox function
    var offsets = Exe.FindAllHex(code + pat1);
    if (offsets.length !== 3)
        return "Failed in Step 1 - First pattern not found";

    //Step 1.3 - Change the first JE to JMP
    for (var i = 0; i < 3; i++)
    {
        Exe.ReplaceHex(offsets[i] - 2, " EB 0C");
    }

    //Step 1.4 - Find occurence of 2nd LT.Hex comparison in the mailbox function
    var offset = Exe.FindHex(code + pat2);
    if (offset === -1)
        return "Failed in Step 1 - Second pattern not found";

    //Step 1.5 - Change the first JE to JMP
    Exe.ReplaceHex(offset - 2, " EB 0C");

    //Step 2.1 - Check if LangType is available (LT.Error will be a string if not)
    if (LT.Error)
        return "Failed in Step 2 - " + LT.Error;

    //Step 2.2 - Prep codes for finding Long jumps
    code =
        " 0F 84 ?? ?? 00 00" //JE addr1 (prev statement is either TEST EAX, EAX or CMP EAX, r32 => both instructions use 2 bytes)
    +   " 83 F8 08"          //CMP EAX,08
    +   " 0F 84 ?? ?? 00 00" //JE addr1
    +   " 83 F8 09"          //CMP EAX,09
    +   " 0F 84 ?? ?? 00 00" //JE addr1
    ;

    pat1 = " A1" + LT.Hex + " ?? ??" ; //MOV EAX, DS:[g_serviceType];

    //Step 2.2 - Find all occurences of the pattern - 3 or 4 would be there
    offsets = Exe.FindAllHex(pat1 + code);

    if (offsets.length < 3 || offsets.length > 4)
        return "Failed in Step 2 - LT.Hex comparisons missing";

    for (var i = 0; i < offsets.length; i++)
    {
        Exe.ReplaceHex(offsets[i] + 5, " EB 18");
    }

    //Step 3 - If the count is 3 then there is an additional JE we missed
    if (offsets.length === 3)
    {
        var pat2 = " 6A 23"; //PUSH 23

        var offset = Exe.FindHex(code + pat2);
        if (offset === -1)
            return "Failed in Step 3";

        Exe.ReplaceHex(offset - 2, " EB 18");
    }
    return true;
}

///================================================///
/// Disable Patch for Unsupported/Unneeded clients ///
///================================================///
function EnableMailBox_()
{
    return (Exe.GetDate() >= 20130320 || Exe.GetDate() <= 20140800);
}