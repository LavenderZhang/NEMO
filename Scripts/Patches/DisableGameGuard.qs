//#########################################################\\
//# Skip the call to ProcessFindHack function and the     #\\
//# Conditional Jump after it. Also ignore nProtect tests #\\
//#########################################################\\

function DisableGameGuard()
{
    //Step 1.1 - Find the Error String
    var offset = Exe.FindString("GameGuard Error: %lu", VIRTUAL);
    if (offset === -1)
        return "Failed in Step 1 - GameGuard String missing";

    //Step 1.2 - Find its Reference
    offset = Exe.FindHex("68" + Num2Hex(offset));
    if (offset === -1)
        return "Failed in Step 1 - GG String Reference missing";

    //Step 1.3 - Find the starting point of function containing the Reference i.e. ProcessFindHack
    var code =
        " 55"    //PUSH EBP
    +   " 8B EC" //MOV EBP, ESP
    +   " 6A FF" //PUSH -1
    +   " 68"    //PUSH value
    ;

    offset = Exe.FindHex(code, offset - 0x160, offset);
    if (offset === -1)
        return "Failed in Step 1 - ProcessFindHack Function missing";

    offset = Exe.Real2Virl(offset, CODE);

    //Step 2.1 - Find pattern matching ProcessFindHack call
    code =
        " E8 ?? ?? 00 00" //CALL ProcessFindHack
    +   " 84 C0"          //TEST AL, AL
    +   " 74 04"          //JE SHORT addr
    +   " C6 ?? ?? 01"    //MOV BYTE PTR DS:[reg32+byte], 1; addr2
    ;

    var offsets = Exe.FindAllHex(code);
    if (offsets.length === 0)
        return "Failed in Step 2 - No Calls found matching ProcessFindHack";

    //Step 2.2 - Replace the CALL with a JMP skipping the CALL, TEST and JE
    code = "EB 07 90 90 90"; //JMP addr2

    for (var i = 0; i < offsets.length; i++)
    {
        var offset2 = Exe.Real2Virl(offsets[i] + 5, CODE) + Exe.GetInt32(offsets[i] + 1);
        if (offset2 === offset)
        {
            Exe.ReplaceHex(offsets[i], code);
            break;
        }
    }
    if (offset2 !== offset)
        return "Failed in Step 2 - No Matched calls are to ProcessFindHack";

    //Step 3.1 - Find address of nProtect string
    offset = Exe.FindString("nProtect GameGuard", VIRTUAL);
    if (offset === -1)
        return "Failed in Step 3 - nProtect string missing";

    //Step 3.2 - Find its references
    code =
        " 68" + Num2Hex(offset) //PUSH addr; ASCII "nProtect GameGuard"
    +   " 50"                   //PUSH EAX
    +   " FF 35"                //PUSH DWORD PTR DS:[addr2]
    ;

    offsets = Exe.FindAllHex(code);
    if (offsets.length === 0)
        return "Failed in Step 3 - nProtect references missing";

    //Step 4.1 - Find the short JE before each reference
    code =
        " 84 C0"          //TEST AL, AL
    +   " 74 ??"          //JE SHORT addr
    +   " E8 ?? ?? ?? FF" //CALL addr2
    +   " 8B C8"          //MOV ECX, EAX
    +   " E8"             //CALL addr3
    ;

    for (var i = 0; i < offsets.length; i++)
    {
        offset = Exe.FindHex(code, offsets[i] - 0x50, offsets[i]);

        //Step 4.2 - Replace JE with JMP
        if (offset !== -1)
            Exe.ReplaceInt8(offset + 2, 0xEB);
    }
    return true;
}

///============================///
/// Disable Unsupported client ///
///============================///
function DisableGameGuard_()
{
    return (Exe.FindString("GameGuard Error: %lu", REAL) !== -1);
}