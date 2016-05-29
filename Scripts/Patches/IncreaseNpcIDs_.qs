//################################################################\\
//# Add an extra loop for loading NPC names using ReqJobName Lua #\\
//# function between user specified limits                       #\\
//################################################################\\

function IncreaseNpcIDs()
{
    //Step 1.1 - Find "ReqJobName"
    var offset = Exe.FindString("ReqJobName", VIRTUAL);
    if (offset === -1)
        return "Failed in Step 1 - ReqJobName not found";

    //Step 1.2 - Find its references
    var offsets = Exe.FindAllHex("68" + Num2Hex(offset));
    if (offsets.length < 3)
        return "Failed in Step 1 - Some ReqJobName references missing";

    //Step 2.1 - Look for 0x190 assignment - we will jump from here
    var code = "BE 90 01 00 00";
    offset = Exe.FindHex(code, offsets[0], offsets[1]);

    if (offset === -1)
    {
        code = code.replace(" BE", " BF")
        offset = Exe.FindHex(code, offsets[0], offsets[1]);
    }
    if (offset === -1)
        return "Failed in Step 2 - 0x190 assignment missing";

    //Step 2.2 - Look for 0x3E9 assignment - needed to extract the loop code
    var offset2 = Exe.FindHex(code.replace("90 01", "E9 03"), offsets[1], offsets[2]);
    if (offset2 === -1)
        return "Failed in Step 2 - 0x3E9 assignment missing";

    //Step 3.1 - Prep code to insert
    code =
        Exe.GetHex(offset, offset2 - offset) //The Loop code
    +   code                                 //MOV reg32, 190
    +   " E9" + MakeVar(1)                   //JMP retAddr ; retAddr = offset + 5
    ;
    var size = code.byteCount();

    //Step 3.2 - Find Free space for insertion
    var free = Exe.FindSpace(size);
    if (free === -1)
        return "Failed in Step 3 - Not enough free space";

    //Step 3.3 - Get the starting and ending IDs for the Loop from user
    var lowerLimit = Exe.GetUserInput("$npcLower", I_DWORD, "Number input - Increase Npc IDs", "Enter Lower Limit of Npc IDs", 10000, 10000, 20000);
    var upperLimit = Exe.GetUserInput("$npcUpper", I_DWORD, "Number input - Increase Npc IDs", "Enter Upper Limit of Npc IDs", 11000, 10000, 20000);

    if (upperLimit === lowerLimit)
        return "Patch Cancelled - Lower and Upper Limits are same";

    //Step 4.1 - Update the limits & Direct Function CALL offsets
    code = code.replace(/ 90 01 00 00/i, Num2Hex(lowerLimit));
    code = code.replace(/ E8 03 00 00 7C/i, Num2Hex(upperLimit) +   " 7C");

    var diff = Exe.Real2Virl(free, DIFF) - Exe.Real2Virl(offset + 5, CODE);
    var start = 0;
    while (start >= 0)
    {
        var index = code.substr(start).search(/ E8 .. .. .. FF/i);
        if (index === -1)
        {
            start = -1;
        }
        else
        {
            start += index + 3;
            var fnOff = Hex2Num(code.substr(start, 12));
            code = code.substr(0, start) + Num2Hex(fnOff - (diff + 5)) + code.substr(start + 12);
            start += 12;
        }
    }

    //Step 4.2 - Fill in the blanks
    code = SetValue(code, 1, -(diff + size));

    //Step 4.3 - Insert the code at free space.
    Exe.InsertHex(free, code, size);

    //Step 4.4 - Change the original MOV to a JMP to our code.
    Exe.ReplaceHex(offset, "E9" + Num2Hex(diff));
    return true;
}