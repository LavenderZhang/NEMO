///========================================================///
/// Patch Functions wrapping over FixCameraAngles function ///
///========================================================///

function FixCameraAnglesRecomm()
{
    return FixCameraAngles(" 00 00 28 42"); //little endian hex of 42.00
}

function FixCameraAnglesLess()
{
    return FixCameraAngles(" 00 00 EC 41"); //little endian hex of 29.50
}

function FixCameraAnglesFull()
{
    return FixCameraAngles(" 00 00 82 42"); //little endian hex of 65.00
}

///===========================================================================================///
/// Note - VC9+ compilers finally recognized to store float values which are used more        ///
///                than once at an offset and use FLD/FSTP/MOVSS to place those in registers. ///
///===========================================================================================///

//####################################################\\
//# Find the Camera Angle and replace with new angle #\\
//####################################################\\

function FixCameraAngles(newvalue)
{
    //Step 1.1 - Find the common pattern after the function call we need.
    var code =
        " 6A 01" //PUSH 1
    +   " 6A 5D" //PUSH 5D
    +   " EB"    //JMP SHORT addr
    ;
    var offset = Exe.FindHex(code);

    if (offset !== -1) //VC9+ clients
    {
        //Step 1.2 - Now find the function call we need (should be within 0x50 bytes before)
        code =
            " 8B CE"          //MOV ECX, ESI
        +   " E8 ?? ?? ?? ??" //CALL addr1 <- this is the one we want
        +   " ??"             //PUSH reg32_A
        +   " 8B CE"          //MOV ECX, ESI
        +   " E8 ?? ?? ?? ??" //CALL addr2
        ;

        offset = Exe.FindHex(code, offset - 0x80, offset);
        if (offset === -1)
            return "Failed in Step 1 - Function Call Missing";

        //Step 1.3 - Extract the Function Address addr1 (REAL)
        offset += Exe.GetInt32(offset + 3) + 7;

        //Step 2.1 - Find the angle value assignment in the function (should be within 0x800 bytes)
        code =
            " 74 ??"             //JZ SHORT addr
        +   " D9 05 ?? ?? ?? 00" //FLD DWORD PTR DS:[angleAddr]
        ;
        var offset2 = Exe.FindHex(code, offset, offset + 0x800);

        if (offset2 === -1)
        {
            code =
                " 74 ??"                   //JZ SHORT addr
            +   " F3 0F 10 ?? ?? ?? ?? 00" //MOVSS XMM#, DWORD PTR DS:[angleAddr]
            ;
            offset2 = Exe.FindHex(code, offset, offset + 0x800);
        }
        if (offset2 === -1)
            return "Failed in Step 2 - Angle Address missing";

        //Step 2.2 - Update offset2 to location after the angleAddr statement
        offset2 += code.byteCount() - 4;

        //Step 2.3 - Find Free Space for insertion
        var free = Exe.FindSpace(4);
        if (free === -1)
            return "Failed in Step 2 - Not enough free space";

        //Step 3.1 - Insert new angle to free space
        Exe.InsertHex(free, newvalue, 4);

        //Step 3.2 - Replace angleAddr reference with the inserted address
        Exe.ReplaceHex(offset2, Num2Hex(Exe.Real2Virl(free, DIFF)));
    }
    else //Older clients
    {
        //Step 4.1 - Find all locations where the current angle = 20.00 (0x41A0000) is assigned
        code =
            " C7 45 ?? 00 00 A0 41" //MOV DWORD PTR SS:[EBP+const1], 41A00000 ; FLOAT 20.00000
        +   " 8B"                   //MOV reg32_A, DWORD PTR DS:[reg32_B+const2]
        ;

        var offsets = Exe.FindAllHex(code);
        if (offsets.length === 0 || offsets.length > 2)
            return "Failed in Step 4 - No or Too Many matches";

        //Step 4.2 - Change the angle value for all in offsets
        for (var i = 0; i < offsets.length; i++)
        {
            Exe.ReplaceHex(offsets[i] + 3, newvalue);
        }

        //Step 5.1 - Now we need to find two stored angles -25.00000 and -65.00000 (dunno what this is for, but it was there in old patch)
        code =
            " 00 00 C8 C1" //DD FLOAT -25.00000
        +   " 00 00 82 C2" //DD FLOAT -65.00000
        ;

        offset = Exe.FindHex(code, Exe.GetRealOffset(CODE) + Exe.GetRealSize(CODE), Exe.GetSize()); //Check only after Code section
        if (offset === -1)
            return "Failed in Step 5";

        //Step 5.2 - Replace with -1.00000 and -89.00000 respectively
        code =
            " 00 00 80 BF" //DD FLOAT -1.00000
        +   " 00 00 B2 C2" //DD FLOAT -89.00000
        ;
        Exe.ReplaceHex(offset, code);
    }
    return true;
}