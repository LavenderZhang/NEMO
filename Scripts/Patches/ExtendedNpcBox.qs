//#################################################################################################\\
//# Modify the stack allocation in CGameMode::Zc_Say_Dialog from 2052 to the user specified value #\\
//#################################################################################################\\

function ExtendNpcBox()
{
    //Step 1.1 - Find "|%02x"
    var offset = Exe.FindString("|%02x", VIRTUAL);
    if (offset === -1)
        return "Failed in Step 1 - Format string missing";

    //Step 1.2 - Find its references
    var offsets = Exe.FindAllHex("68" + Num2Hex(offset));
    if (offsets.length === 0)
        return "Failed in Step 1 - String reference missing";

    //Step 1.3 - Find the Stack allocation address => SUB ESP, 804+x . Only 1 of the offsets matches
    for (var i = 0; i < offsets.length; i++)
    {
        offset = Exe.FindHex("81 EC ?? 08 00 00", offsets[i] - 0x80, offsets[i]);
        if (offset !== -1)
            break;
    }
    if (offset === -1)
        return "Failed in Step 1 - Function not found";

    //Step 1.4 - Extract the x in SUB ESP, x
    var stackSub = Exe.GetInt32(offset + 2);

    //Step 1.5 - Find the End of the Function.
    if (EBP_TYPE)
    {
        code =
            " 8B E5"    //MOV ESP, EBP
        +   " 5D"       //POP EBP
        +   " C2 04 00" //RETN 4
        ;
    }
    else
    {
        code =
            " 81 C4" + Num2Hex(stackSub) //ADD ESP, 804+x
        +   " C2 04 00"                  //RETN 4
        ;
    }
    var offset2 = Exe.FindHex(code, offsets[i] + 5, offset + 0x200); //i is from the for loop
    if (offset2 === -1)
        return "Failed in Step 1 - Function end missing";

    //Step 2.1 - Get new value from user
    var value = Exe.GetUserInput('$npcBoxLength', I_INT32, "Number Input", "Enter new NPC Dialog box length (2052 - 4096)", 0x804, 0x804, 0x1000);
    if (value === 0x804)
        return "Patch Cancelled - New value is same as old";

    //Step 2.2 - Change the Stack Allocation with new values
    Exe.ReplaceInt32(offset + 2, value + stackSub - 0x804);//Change x in SUB ESP, x
    if (!EBP_TYPE)
        Exe.ReplaceInt32(offset2 + 2, value + stackSub - 0x804);//Change x in ADD ESP, x

    if (EBP_TYPE)
    {
        //Step 2.3 - Update all EBP-x+i Stack references, for now we are limiting i to (0 - 3)
        for (var i = 0; i <= 3; i++)
        {
            code = Num2Hex(i - stackSub);//-x+i
            offsets = Exe.FindAllHex(code, offset + 6, offset2);

            for (var j = 0; j < offsets.length; j++)
            {
                Exe.ReplaceInt32(offsets[j], i - value);
            }
        }
    }
    else
    {
        //Step 2.4 - Update all ESP+i Stack references, where i is in (0x804 - 0x820)
        for (var i = 0x804; i <= 0x820; i += 4)
        {
            offsets = Exe.FindAllHex(Num2Hex(i), offset + 6, offset2);
            for (var j = 0; j < offsets.length; j++)
            {
                Exe.ReplaceInt32(offsets[j], value + i - 0x804);
            }
        }
    }
    return true;
}