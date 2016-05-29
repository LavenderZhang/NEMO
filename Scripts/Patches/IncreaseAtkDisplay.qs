//##############################################################################\\
//# Modify the stack allocation and code to account for 10 digits instead of 6 #\\
//# in CGameActor::Am_Make_Number. To avoid redundannt code we will use loop   #\\
//##############################################################################\\

function IncreaseAtkDisplay()
{
    //Step 1.1 - Find the location where 999999 is checked
    var code =
        " 81 ?? 3F 42 0F 00" //CMP reg32_A, 0F423F ; 999999 = 0x0F423F
    +   " 7E 07"             //JLE SHORT addr1
    +   " ?? 3F 42 0F 00"    //MOV reg32_A, 0F423F
    ;
    var refOffset = Exe.FindHex(code);

    if (refOffset === -1)
    {
        code = code.replace("7E", "?? 7E");//Insert Byte before JLE to represent PUSH reg32
        refOffset = Exe.FindHex(code);
    }
    if (refOffset === -1)
        return "Failed in Step 1 - 999999 comparison missing";

    //Step 1.2 - Find the start of the Function
    code =
        " 6A FF"             //PUSH -1
    +   " 68 ?? ?? ?? 00"    //PUSH addr1
    +   " 64 A1 00 00 00 00" //MOV EAX, DWORD PTR FS:[0]
    +   " 50"                //PUSH EAX
    +   " 83 EC"             //SUB ESP, const1
    ;
    var offset = Exe.FindHex(code, refOffset - 0x40, refOffset);

    if (offset === -1)
    {
        code = code.replace("50", "50 64 89 25 00 00 00 00"); //Insert MOV DWORD PTR FS:[0], ESP after PUSH EAX
        offset = Exe.FindHex(code, refOffset - 0x40, refOffset);
    }
    if (offset === -1)
        return "Failed in Step 1 - Function start missing";

    //Step 1.3 - Update offset to location after SUB ESP, const1
    offset += code.byteCount();

    //Step 1.4 - Update the stack allocation to hold 4 more nibbles (each digit requires 4 bits) => decrease by 16
    __OffsetStack(offset, 1);

    //Step 2.1 - Find Location where the digit counter starts
    if (EBP_TYPE)
        code = "C7 45 ?? 01 00 00 00"; //MOV DWORD PTR SS:[EBP-x], 1
    else
        code = "C7 44 24 ?? 01 00 00 00"; //MOV DWORD PTR SS:[ESP+x], 1

    offset = Exe.FindHex(code, refOffset + 0x10, refOffset + 0x28);

    if (offset === -1)
    {
        code =
            " 7E 07"          //JLE SHORT addr
        +   " ?? 06 00 00 00" //MOV reg32_B, 6
        +   " EB"             //JMP SHORT addr2
        ;
        offset = Exe.FindHex(code, refOffset + 0x10, refOffset + 0x28);
    }
    if (offset === -1)
        return "Failed in Step 2 - Digit Counter missing";

    //Step 2.2.1 - Extract the stack offset from the instruction if it is a stack assignment
    if (Exe.GetUint8(offset) === 0xC7)
    {
        var offByte = Exe.GetInt8(offset + code.byteCount() - 5);
    }
    else
    {
        //Step 2.2.2 - If its a register assignment extract the register and see if it assigns to stack later
        var offByte = Exe.GetUint8(offset + 2) - 0xB8;

        code = (offByte << 3) | 0x44;//modrm for MOV
        if (EBP_TYPE)
            code = "89" + Num2Hex(code + 1, 1) + " ?? 8D"; //MOV DWORD PTR SS:[EBP-x], reg32_B . followed by LEA
        else
            code = "89" + Num2Hex(code, 1) + " 24 ?? 8D";  //MOV DWORD PTR SS:[ESP+x], reg32_B . followed by LEA

        var offset2 = Exe.FindHex(code, offset, offset + 0x80);

        if (offset2 === -1)
            offByte = " 89" + Num2Hex(0xF0 | offByte, 1); //MOV reg32_B, ESI ; because ESI will be holding the digit count finally
        else
            offByte = Exe.GetInt8(offset2 + code.byteCount() - 2);
    }

    //Step 2.3 - Find Location where the digit extraction starts
    offset = Exe.FindHex("B8 67 66 66 66", offset);//MOV EAX, 66666667
    if (offset === -1)
        return "Failed in Step 2 - Digit Extractor missing";

    //Step 2.4 - Find the first digit movement to allocated stack after it
    if (EBP_TYPE)
        code = "89 ?? ??"; //MOV DWORD PTR SS:[EBP-x], reg32_A
    else
        code = "89 ?? 24 ??"; //MOV DWORD PTR SS:[ESP+x], reg32_A

    var offset2 = Exe.FindHex(code + " 8B", offset + 0x5, offset + 0x28);//MOV instruction following assignment - VC9+ clients

    if (offset2 === -1)
        offset2 = Exe.FindHex(code + " F7", offset + 0x5, offset + 0x28);//IMUL instruction following assignment - Older clients

    if (offset2 === -1)
        return "Failed in Step 2 - Digit movement missing";

    //Step 2.5 - Update offset to location after last instruction in code
    offset2 += code.byteCount();

    //Step 2.6 - Extract the stack offset for the first digit (all the succeeding ones will be in increasing order from this one).
    var offByte2 = Exe.GetInt8(offset2 - 1);

    //Step 2.7 - Find the g_modeMgr assignment
    offset = Exe.FindHex("B9 ?? ?? ?? 00", offset2);//MOV ECX, g_modeMgr
    if (offset === -1)
        return "Failed in Step 2 - g_modeMgr assignment missing";

    //Step 2.8 - Extract the assignment
    var movECX = Exe.GetHex(offset, 5);

    //Step 2.9 - Now find the CModeMgr::GetGameMode call after it - this is where we need to Jump to after digit count and extraction
    offset = Exe.FindHex("E8 ?? ?? ?? FF", offset + 5);//CALL CModeMgr::GetGameMode
    if (offset === -1)
        return "Failed in Step 2 - GetGameMode call missing";

    //Step 3.1 - Adjust the extracted stack offsets based on FPO
    if (EBP_TYPE)
    {
        if (typeof(offByte) === "number" && offByte < offByte2) //Location is above digit set in stack (offByte and offByte2 are negative)
            offByte -= 16;

        offByte2 -= 16;//Lowest digit is at 4 locations later.
    }
    else
    {
        if (typeof(offByte) === "number" && offByte >= (offByte2 + 4*6)) //Location is below digit set in stack
            offByte += 16;
    }

    //Step 3.2 - Prep code to replace at refOffset - new digit splitter and counter combined
    code =
        " 89" + Num2Hex(0xC1 + ((Exe.GetInt8(refOffset + 1) & 0x7) << 3), 1) //MOV ECX, reg32_A
    +   " BE" + Num2Hex(offByte2)       //MOV ESI, offByte2
    +   " B8 67 66 66 66"               //MOV EAX,66666667
    +   " F7 E9"                        //IMUL ECX
    +   " C1 FA 02"                     //SAR EDX,2
    +   " 8D 04 92"                     //LEA EAX,[EDX*4+EDX]
    +   " D1 E0"                        //SHL EAX,1
    +   " 29 C1"                        //SUB ECX,EAX
    +   MakeVar(1)                      //Frame Pointer Specific MOV (extracted digit) to Stack
    +   " 83 C6 04"                     //ADD ESI,4
    +   " 89 D1"                        //MOV ECX,EDX
    +   " 85 C9"                        //TEST ECX,ECX
    +   " 75 E2"                        //JNE SHORT addr1 -> MOV EAX, 66666667
    +   " 83 EE" + Num2Hex(offByte2, 1) //SUB ESI, offByte2
    +   " C1 FE 02"                     //SAR ESI, 2
    +   MakeVar(2)                      //Frame Pointer Specific MOV (digit count) for VC9+ clients
    +   movECX                          //MOV ECX, g_modeMgr
    +   " E9" + MakeVar(3)              //JMP offset
    ;

    //Step 3.3 - Fill in the blanks
    if (EBP_TYPE)
    {
        code = SetValue(code, 1, " 89 4C 35 00"); //MOV DWORD PTR SS:[ESI+EBP],ECX

        if (typeof(offByte) === "number")
            code = SetValue(code, 2, " 89 75" + Num2Hex(offByte, 1)); //MOV DWORD PTR SS:[EBP-offByte], ESI
        else
            code = SetValue(code, 2, offByte); //MOV reg32_B, ESI
    }
    else
    {
        code = SetValue(code, 1, " 89 0C 34 90"); //MOV DWORD PTR SS:[ESI+ESP],ECX ; followed by NOP to fit 4 byte
        code = SetValue(code, 2, " 89 74 24" + Num2Hex(offByte, 1)); //MOV DWORD PTR SS:[ESP+offByte], ESI
    }
    code = SetValue(code, 3, offset - (refOffset + code.byteCount()));

    //Step 3.4 - Replace code at refOffset
    Exe.ReplaceHex(refOffset, code);

    //Step 4.1 - Find the end of the function
    if (EBP_TYPE)
        code = "8B E5 5D"; //MOV ESP, EBP and POP EBP
    else
        code = "83 C4 ??"; //ADD ESP, const

    code += " C2 10 00";//RETN 10

    var offset3 = Exe.FindHex(code, offset, offset + 0x200);
    if (offset3 === -1)
        return "Failed in Step 4 - Function end missing";

    offset2 = offset + 5;
    if (EBP_TYPE)
        var soff = 16;
    else
        var soff = 4*6;

    while (offset2 < offset3)
    {
        //Step 4.2 - Get the instruction details at current offset
        var instr = GetInstruction(offset2);

        //Step 4.4 - Change stack offsets for relevant locations
        switch (instr.OpCode)
        {
            case 0x89:
            case 0x8B:
            case 0x8D:
            case 0xC7:
            case 0x3B:
            case 0xFF:
            case 0x83:
            {
                if (instr.OpCode === 0xFF && !EBP_TYPE && instr.RegD === 2)
                    soff = 6*4;

                if (EBP_TYPE && instr.Mode === 1)
                {
                    if (instr.RMem === 5 && Exe.GetInt8(offset2 + 2) <= (offByte2 + soff) )
                    {
                        __OffsetStack(offset2 + 2);
                    }
                    else if (instr.RMem === 4 && (Exe.GetInt8(offset2 + 2) & 0x7) === 5 && Exe.GetInt8(offset2 + 3) <= (offByte2 + soff))
                    {
                        __OffsetStack(offset2 + 3);
                    }
                }
                else if (!EBP_TYPE && instr.Mode === 1 && instr.RMem === 4 && (Exe.GetInt8(offset2 + 2) & 0x7) === 4 && Exe.GetInt8(offset2 + 3) >= (offByte2 + soff) )
                {
                    __OffsetStack(offset2 + 3, 1);
                }
                break;
            }
            case 0x68:
            case 0x6A:
            {
                if (!EBP_TYPE)
                    soff += 4;

                break;
            }
            case 0xE8:
            {
                if (!EBP_TYPE)
                    soff = 6*4;

                break;
            }
        }

        //Step 4.5 - Update offset2
        offset2 = instr.NextLoc;
    }

    if (EBP_TYPE)
    {
        if (typeof(offByte) === "number")//Only saw it in VC10+ clients
        {
            //Step 5.1 - Look for MOV instruction to stack that occurs before refOffset
            offset = Exe.FindHex("89 ?? ?? 81", refOffset - 6, refOffset);//MOV DWORD PTR SS:[EBP-x], reg32_A followed by the comparson

            if (offset === -1)
                offset = Exe.FindHex("89 ?? ?? 8B", refOffset-6, refOffset);//MOV DWORD PTR SS:[EBP-x], reg32_A followed by another MOV

            if (offset === -1)
                return "Failed in Step 2 - MOV missing";

            //Step 5.2 - Update the stack offset
            __OffsetStack(offset + 2);
        }
    }
    else
    {
        //Step 5.3 - Update the stack offset at offset3 + 2 (change x in ADD ESP, x)
        __OffsetStack(offset3 + 2, 1);

        //Step 5.4 - Look for LEA instruction before refOffset (FPO client). ESP+x will be before the space allocated for digits
        offset = Exe.FindHex("8D ?? 24", refOffset - 0x28, refOffset);//LEA EAX, [ESP+x]
        if (offset === -1)
            return "Failed in Step 2 - LEA missing";

        //Step 5.5 - Update the stack offset
        __OffsetStack(offset + 3, 1);

        //Step 5.6 - Look for MOV ECX, DWORD PTR SS:[ARG.2] before refOffset. ARG.2 is now 0x10 bytes farther
        offset = Exe.FindHex("8B ?? 24", refOffset - 8, refOffset);
        if (offset === -1)
            return "Failed in Step 2 - ARG.2 assignment missing";

        //Step 5.7 - Update the stack offset
        __OffsetStack(offset + 3, 1);
    }
    return true;
}

//################################################\\
//# Add/Sub stack offset value at location by 16 #\\
//################################################\\

function __OffsetStack(loc, sign)
{
    if (typeof(sign) === "undefined")
        sign = -1;

    Exe.ReplaceInt8(loc, Exe.GetInt8(loc) + sign * 16);
}
