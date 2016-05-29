//##############################################################################\\
//# Change all JZ/JNZ/CMOVNZ after g_readFolderFirst comparison to NOP/JMP/MOV #\\
//# (Also sets g_readFolderFirst to 1 in the process as failsafe).             #\\
//##############################################################################\\

function ReadDataFolderFirst()
{
    //Step 1.1 - Find "loading"
    var offset = Exe.FindString("loading", VIRTUAL);
    if (offset === -1)
        return "Failed in Step 1 - loading not found";

    //Step 1.2 - Find its reference (g_readFolderFirst is assigned just above it)
    var code =
        " 74 07"                //JZ SHORT addr - skip the MOV below
    +   " C6 05 ?? ?? ?? ?? 01" //MOV BYTE PTR DS:[g_readFolderFirst], 1
    +   " 68" + Num2Hex(offset) //PUSH offset ; ASCII "loading"
    ;
    var repl = "90 90";//Change JZ SHORT to NOPs
    var gloc = 4; //relative position from offset2 where g_readFolderFirst is
    var offset2 = Exe.FindHex(code);

    if (offset2 === -1)
    {
        code =
            " 0F 45 ??"             //CMOVNZ reg32_A, reg32_B
        +   " 88 ?? ?? ?? ?? ??"    //MOV BYTE PTR DS:[g_readFolderFirst], reg8_A
        +   " 68" + Num2Hex(offset) //PUSH offset ; ASCII "loading"
        ;
        repl = "90 8B";//change CMOVNZ to NOP + MOV
        gloc = 5;
        offset2 = Exe.FindHex(code);
    }
    if (offset2 === -1)
        return "Failed in Step 1 - loading reference missing";

    //Step 1.3 - Change conditional instruction to permanent setting - as a failsafe
    Exe.ReplaceHex(offset2, repl);

    ///===================================================================///
    /// Client also compares g_readFolderFirst even before it is assigned ///
    /// sometimes hence we also fix up the comparisons.                   ///
    ///===================================================================///

    //Step 2.1 - Extract g_readFolderFirst
    var gReadFolderFirst = Exe.GetHex(offset2 + gloc, 4);

    //Step 2.2 - Look for Comparison Pattern 1 - VC9+ Clients
    var offsets = Exe.FindAllHex("80 3D" + gReadFolderFirst + " 00"); //CMP DWORD PTR DS:[g_readFolderFirst], 0

    if (offsets.length !== 0)
    {
        for (var i = 0; i < offsets.length; i++)
        {
            //Step 2.3 - Find the JZ SHORT below each Comparison
            offset = Exe.FindHex("74 ?? E8", offsets[i] + 0x7, offsets[i] + 0x20);//JZ SHORT addr followed by a CALL
            if (offset === -1)
                return "Failed in Step 2 - Iteration No." + i;

            //Step 2.4 - NOP out the JZ
            Exe.ReplaceHex(offset, "90 90");
        }
        return true;
    }

    //Step 3.1 - Look for Comparison Pattern 2 - Older clients
    offsets = Exe.FindAllHex("A0" + gReadFolderFirst); //MOV AL, DWORD PTR DS:[g_readFolderFirst]
    if (offsets.length === 0)
        return "Failed in Step 3 - No Comparisons found";

    for (var i = 0; i < offsets.length; i++)
    {
        //Step 4.2 - Find the JZ below each Comparison
        offset = Exe.FindHex("0F 84 ?? ?? 00 00", offsets[i] + 0x5, offsets[i] + 0x20);//JZ addr
        if (offset === -1)
            return "Failed in Step 3 - Iteration No." + i;

        //Step 4.3 - Replace with 6 NOPs
        Exe.ReplaceHex(offset, "90 90 90 90 90 90");
    }
    return true;
}