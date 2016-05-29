//###########################################\\
//# Disable hard-coded hair style table and #\\
//# generate hair style IDs ad-hoc instead  #\\
//###########################################\\

function Enable64kHairstyle()
{
    //Step 1.1 - Find the Format String "인간족\머리통\%s\%s_%s.%s"
    var code = "\xC0\xCE\xB0\xA3\xC1\xB7\\\xB8\xD3\xB8\xAE\xC5\xEB\\%s\\%s_%s.%s";
    var doramOn = false;
    var offset = Exe.FindString(code, REAL);

    if (offset === -1) //Doram Client
    {
        code = "\\\xB8\xD3\xB8\xAE\xC5\xEB\\%s\\%s_%s.%s"; // "\머리통\%s\%s_%s.%s"
        doramOn = true;
        offset = Exe.FindString(code, REAL);
    }
    if (offset === -1)
        return "Failed in Step 1 - String not found";

    //Step 1.2 - Change the 2nd %s to %u
    Exe.ReplaceInt8(offset + code.length - 7, 0x75);

    //Step 1.3 - Find the string reference
    offset = Exe.FindHex("68" + Num2Hex(Exe.Real2Virl(offset, DATA)));
    if (offset === -1)
        return "Failed in Step 1 - String reference missing";
    //Step 2.1 - Move offset to previous instruction which should be an LEA reg, [ESP+x] or LEA reg, [EBP-x]
    if (EBP_TYPE)
        offset = offset - 3;
    else
        offset = offset - 4;

    if (Exe.GetUint8(offset) !== 0x8D) // x > 0x7F => accomodating for the extra 3 bytes of x
        offset = offset - 3;

    if (Exe.GetUint8(offset) !== 0x8D)
        return "Failed in Step 2 - Unknown instruction before reference";

    //Step 2.2 - Extract the register code used in the second last PUSH reg32 before the LEA instruction (0x8D)
    var regNum = Exe.GetUint8(offset - 2) - 0x50;
    if (regNum < 0 || regNum > 7)
        return "Failed in Step 2 - Missing Reg PUSH";

    if (EBP_TYPE)
        regc = Num2Hex(0x45 | (regNum << 3), 1);
    else
        regc = Num2Hex(0x44 | (regNum << 3), 1);

    //Step 2.3 - Look for the location where it is assigned. Dont remove the ?? at the end, the code size is used later.
    if (EBP_TYPE) //VC9-VC10
    {
        code =
            " 83 7D ?? 10"       //CMP DWORD PTR SS:[EBP-y], 10 ; y is unknown
        +   " 8B" + regc + " ??" //MOV reg32, DWORD PTR SS:[EBP-z] ; z = y+5*4
        +   " 73 03"             //JAE SHORT addr ; after LEA below
        +   " 8D" + regc + " ??" //LEA reg32, [EBP-z]
        ;
    }
    else
    {
        code =
            " 83 7C 24 ?? 10"       //CMP DWORD PTR SS:[ESP+y], 10 ; y is unknown
        +   " 8B" + regc + " 24 ??" //MOV reg32, DWORD PTR SS:[ESP+z] ; z = y+5*4
        +   " 73 04"                //JAE SHORT addr ; after LEA below
        +   " 8D" + regc + " 24 ??" //LEA reg32, [ESP+z]
        ;
    }
    var offset2 = Exe.FindHex(code, offset - 0x50, offset);

    if (offset2 === -1) //VC11
    {
        if (EBP_TYPE)
        {
            code =
                " 83 7D ?? 10"          //CMP DWORD PTR SS:[EBP-y], 10 ; y is unknown
            +   " 8D" + regc + " ??"    //LEA reg32, [EBP-z] ; z = y+5*4
            +   " 0F 43" + regc + " ??" //CMOVAE reg32, DWORD PTR SS:[EBP-z]
            ;
        }
        else
        {
            code =
                " 83 7C 24 ?? 10"          //CMP DWORD PTR SS:[ESP+y], 10 ; y is unknown
            +   " 8D" + regc + " 24 ??"    //LEA reg32, [ESP+z] ; z = y+5*4
            +   " 0F 43" + regc + " 24 ??" //CMOVAE reg32, DWORD PTR SS:[ESP+z]
            ;
        }
        offset2 = Exe.FindHex(code, offset - 0x50, offset);
    }
    if (offset2 === -1)
        return "Failed in Step 2 - Register assignment missing";

    //Step 2.4 - Save the offset2 and code size (We need to NOP out the excess)
    var assignOffset = offset2;
    var csize = code.byteCount();

    //Step 3.1 - Find the start of the function (has a common signature like many others)
    code =
        " 6A FF"             //PUSH -1
    +   " 68 ?? ?? ?? 00"    //PUSH value
    +   " 64 A1 00 00 00 00" //MOV EAX, FS:[0]
    +   " 50"                //PUSH EAX
    +   " 83 EC"             //SUB ESP, const
    ;
    offset = Exe.FindHex(code, offset2 - 0x1B0, offset2);

    if (offset === -1) //const is > 0x7F
    {
        code = code.replace(" 83", " 81");
        offset = Exe.FindHex(code, offset2 - 0x280, offset2);
    }
    if (offset === -1)
        return "Failed in Step 3 - Function start missing";

    //Step 3.2 - Update offset to location after SUB ESP, const
    offset += code.byteCount();

    //Step 3.3 - Get the Stack offset w.r.t. ESP/EBP for Arg.5
    var arg5Dist = 5*4; //for the 5 PUSHes of the arguments

    if (EBP_TYPE)
    {
        arg5Dist += 4; //Account for the PUSH EBP in the beginning
    }
    else
    {
        arg5Dist += 7*4;//Account for PUSH -1, PUSH addr and 5 reg32 PUSHes

        if (Exe.GetUint8(offset - 2) === 0x81) // Add the const from SUB ESP, const
            arg5Dist += Exe.GetInt32(offset);
        else
            arg5Dist += Exe.GetInt8(offset);

        //Step 3.4 - Account for an extra PUSH instruction (security related) in VC9 clients
        code =
            " A1 ?? ?? ?? 00" //MOV EAX, DWORD PTR DS:[__security_cookie];
        +   " 33 C4"          //XOR EAX, ESP
        +   " 50"             //PUSH EAX
        ;
        if (Exe.FindHex(code, offset + 0x4, offset + 0x20) !== -1)
            arg5Dist += 4;
    }

    //Step 3.5 - Prep code to change assignment (hairstyle index instead of the string)
    if (EBP_TYPE)
        code = " 8B" + regc + Num2Hex(arg5Dist, 1); //MOV reg32_A, DWORD PTR SS:[EBP + arg5Dist]; ARG.5
    else if (arg5Dist > 0x7F)
        code = " 8B" + Num2Hex(0x84 | (regNum << 3), 1) +   " 24" + Num2Hex(arg5Dist); //MOV reg32_A, DWORD PTR SS:[ESP + arg5Dist]; ARG.5
    else
        code = " 8B" + regc +   " 24" + Num2Hex(arg5Dist, 1); //MOV reg32_A, DWORD PTR SS:[ESP + arg5Dist]; ARG.5

    code += " 8B" + Num2Hex((regNum << 3) | regNum, 1); //MOV reg32_A, DWORD PTR DS:[reg32_A]
    code += " 90".repeat(csize - code.byteCount()); //Fill rest with NOPs

    //Step 3.6 - Replace the original at assignOffset
    Exe.ReplaceHex(assignOffset, code);

    //Step 4.1 - Find the string table fetchers
    code =
        " 8B ?? ?? ?? ?? 00" //MOV reg32_A, DWORD PTR DS:[addr]
    +   " 8B ?? 00"          //MOV reg32_B, DWORD PTR DS:[EBP]
    +   " 8B 14"             //MOV EDX, DWORD PTR DS:[reg32_B * 4 + reg32_A]
    ;
    var offsets = Exe.FindAllHex(code, offset, assignOffset);

    if (offsets.length === 0)
    {
        code =
            " 8B ??"             //MOV reg32_B, DWORD PTR DS:[reg32_C]
        +   " 8B ?? ?? ?? ?? 00" //MOV reg32_A, DWORD PTR DS:[addr]
        +   " 8B 14"             //MOV EDX, DWORD PTR DS:[reg32_B * 4 + reg32_A]
        ;
        offsets = Exe.FindAllHex(code, offset, assignOffset);
    }
    if (offsets.length === 0)
    {
        code = code.replace("8B ?? ??", "A1 ??"); //reg32_A is EAX
        offsets = Exe.FindAllHex(code, offset, assignOffset);
    }
    if (offsets.length === 0)
        return "Failed in Step 4 - Table fetchers missing";

    //Step 4.2 - Remove the reg32_B * 4 from all the matches
    for (var i = 0; i < offsets.length; i++)
    {
        offset2 = offsets[i] + code.byteCount();
        Exe.ReplaceInt16(offset2 - 1, 0x9010 + (Exe.GetInt8(offset2) & 0x7));
    }

    //Step 5.1 - Find the Hairstyle limiting comparison within the function
    code =
        " 7C 05"    //JL SHORT addr1; skips the next two instructions
    +   " 83 ?? ??" //CMP reg32_A, const; const = max hairstyle ID
    +   " 7E ??"    //JLE SHORT addr2; skip the next assignment - ?? should be 06 or 07
    +   " C7"       //MOV DWORD PTR DS:[reg32_B], 0D
    ;
    offset2 = Exe.FindHex(code, offset + 4, offset + 0x50);//VC9 - VC10

    if (offset2 === -1)
    {
        code = code.replace("7C", "78"); //changing JL to JS
        offset2 = Exe.FindHex(code, offset + 4, offset + 0x50);//VC11
    }
    if (offset2 === -1 && doramOn) //For Doram Client, its farther away since there are extra checks for Job ID within Doram Range or Human Range
    {
        offset2 = Exe.FindHex(code, offset + 0x100, offset + 0x200);
    }
    if (offset2 === -1)
        return "Failed in Step 5 - Limit checker missing";

    //Step 5.2 - Update offset2 to the location of MOV DWORD
    offset2 += code.byteCount();

    //Step 5.3 - Change the JLE to JMP
    Exe.ReplaceInt8(offset2 - 3, 0xEB);

    //Step 5.4 - Change 0D to 02 in MOV instruction
    code = Exe.GetUint8(offset2);
    if (code === 0x04 || code > 0x07)
        Exe.ReplaceInt8(offset2 + 2, 0x02);
    else
        Exe.ReplaceInt8(offset2 + 1, 0x02);

    //Remove the && 0 to enable for Doram
    if (doramOn && 0) //Repeat 5a & 5b for Doram race which appears before offset2.
    {
        //Step 6.1 - Find the Hairstyle limiting comparison within the function for Doram race
        code =
            " 7C 05"    //JL SHORT addr1; skips the next two instructions
        +   " 83 ?? ??" //CMP reg32_A, const; const = max hairstyle ID
        +   " 7C ??"    //JLE SHORT addr2; skip the next assignment - ?? should be 06 or 07
        +   " C7"       //MOV DWORD PTR DS:[reg32_B], 06
        ;

        offset = Exe.FindHex(code, offset2 - 0x75, offset2 - 0x10);
        if (offset === -1)
            return "Failed in Step 6 - Doram Limit Checker missing";

        //Step 6.2 - Update offset to location of MOV DWORD
        offset += code.byteCount();

        //Step 6.3 - Change the JLE to JMP
        Exe.ReplaceInt8(offset - 3, 0xEB);

        //Step 6.4 - Change 0D to 02 in MOV instruction
        code = Exe.GetUint8(offset);
        if (code === 0x04 || code > 0x07)
            Exe.ReplaceInt8(offset + 2, 0x02);
        else
            Exe.ReplaceInt8(offset + 1, 0x02);
    }
    return true;
}

///=================================///
/// Disable for Unsupported Clients ///
///=================================///
function Enable64kHairstyle_()
{
    return (Exe.GetDate() > 20111102);
}