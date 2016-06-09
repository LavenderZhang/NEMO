//######################################################################\\
//# Modify the comparisons in cases for Hair Style and Color arrows in #\\
//# UIMakeCharWnd::SendMsg and also update the scrollbar length        #\\
//######################################################################\\

function IncreaseHairLimits() //To Do - Doram client is different need to explore
{
    //Step 1.1 - Find the reference PUSH 2714 before the switch cases for the arrows
    var refOffset = Exe.FindAllHex("68 14 27 00 00");
    if (refOffset.length === 0)
        return "Failed in Step 1 - PUSH missing";

    refOffset = refOffset[refOffset.length-1];//Assumption : The last one is the one we need. Previously there was only one match but recent clients have 2

    //Step 1.2 -    Find the Comparison for Hair Color after it
    var code =
        " 8B 8B ?? ?? 00 00" //MOV ECX, DWORD PTR DS:[EBX + hCPtr]
    +   " 41"                //INC ECX
    +   " 8B C1"             //MOV EAX, ECX
    +   " 89 8B ?? ?? 00 00" //MOV DWORD PTR DS:[EBX + hCPtr], ECX
    +   " 83 F8 08"          //CMP EAX, 8
    +   " 7E 06"             //JLE SHORT addr
    +   " 89 BB ?? ?? 00 00" //MOV DWORD PTR DS:[EBX + hCPtr], EDI
    ;
    var type = 1;//VC6
    var cmpLoc = 15;
    var offset = Exe.FindHex(code, refOffset + 0x60, refOffset + 0x220);

    if (offset === -1)
    {
        code =
            " FF 83 ?? ?? 00 00"             //INC DWORD PTR DS:[EBX + hCPtr]
        +   " 83 BB ?? ?? 00 00 08"          //CMP DWORD PTR DS:[EBX + hCPtr], 8
        +   " 7E 0A"                         //JLE SHORT addr
        +   " C7 83 ?? ?? 00 00 00 00 00 00" //MOV DWORD PTR DS:[EBX + hCPtr], 0
        ;
        type = 2;//VC9 - Style 1
        cmpLoc = 6;
        offset = Exe.FindHex(code, refOffset + 0x160, refOffset + 0x1C0);
    }
    if (offset === -1)
    {
        code =
            " BB 01 00 00 00"       //MOV EBX, 1
        +   " 01 9D ?? ?? 00 00"    //ADD DWORD PTR SS:[EBP + hCPtr], EBX
        +   " 83 BD ?? ?? 00 00 08" //CMP DWORD PTR SS:[EBP + hCPtr], 8
        +   " 7E 06"                //JLE SHORT addr
        +   " 89 BD ?? ?? 00 00"    //MOV DWORD PTR SS:[EBP + hCPtr], EDI
        ;
        type = 3;//VC9 - Style 2
        cmpLoc = 11;
        offset = Exe.FindHex(code, refOffset + 0x160, refOffset + 0x1C0);
    }
    if (offset === -1)
    {
        code =
            " 83 BB ?? ?? 00 00 00"          //CMP DWORD PTR DS:[EBX + hCPtr], 0
        +   " 7D 0A"                         //JGE SHORT addr
        +   " C7 83 ?? ?? 00 00 00 00 00 00" //MOV DWORD PTR DS:[EBX + hCPtr], 0
        +   " B8 07 00 00 00"                //MOV EAX, 7 ; addr
        +   " 39 83 ?? ?? 00 00"             //CMP DWORD PTR DS:[EBX + hCPtr], EAX
        +   " 7E 06"                         //JLE SHORT addr2
        +   " 89 83 ?? ?? 00 00"             //MOV DWORD PTR DS:[EBX + hCPtr], EAX
        ;
        type = 4;//VC9 & VC10 - New Make Char Style. Both color and style have scrollbars with a common case for switch
        cmpLoc = 0;
        offset = Exe.FindHex(code, refOffset + 0x300, refOffset + 0x3C0);
    }
    if (offset === -1)
    {
        code =
            " 89 ?? ?? ?? 00 00"             //MOV DWORD PTR DS:[EBX + hCPtr], reg32_A
        +   " 85 C0"                         //TEST EAX,EAX
        +   " 79 0C"                         //JNS SHORT addr
        +   " C7 83 ?? ?? 00 00 00 00 00 00" //MOV DWORD PTR DS:[EBX + hCPtr], 0
        +   " EB 0F"                         //JMP SHORT addr2
        +   " 83 F8 08"                      //CMP EAX, 8 ; addr
        +   " 7E 0A"                         //JLE SHORT addr2
        +   " C7 83 ?? ?? 00 00 08 00 00 00" //MOV DWORD PTR DS:[EBX + hCPtr], 8
        ;
        type = 5;//VC11 & VC10 (March 2014 onwards)
        cmpLoc = 6;
        offset = Exe.FindHex(code, refOffset + 0x300, refOffset + 0x3C0);
    }
    if (offset === -1)
        return "Failed in Step 1 - HairColor comparison missing";

    //Step 1.3 - Extract the EBX/EBP offset refering to Hair color index, Hair color limit and save the comparison location
    var hCPtr = Exe.GetHex(offset + 2, 4);
    var hCBegin = offset + cmpLoc;
    var hCEnd = offset + code.byteCount();

    if (type === 4)
        var hCLimit = 7;
    else
        var hCLimit = 8;

    //Step 2.1 - Prep code for Hair style comparison
    switch (type)
    {
        case 1://VC6
        {
            var code2 =
                " 66 FF 8B ?? 00 00 00"       //DEC WORD PTR DS:[EBX + hSPtr]
            +   " 66 39 BB ?? 00 00 00"       //CMP WORD PTR DS:[EBX + hSPtr], DI
            +   " 75 09"                      //JNE SHORT addr
            +   " 66 C7 83 ?? 00 00 00 17 00" //MOV WORD PTR DS:[EBX + hSPtr], 17
            ;
            var code3 =
                " 66 FF 83 ?? 00 00 00"       //INC WORD PTR DS:[EBX + hSPtr]
            +   " 66 8B 83 ?? 00 00 00"       //MOV AX, WORD PTR DS:[EBX + hSPtr]
            +   " 66 3D 18 00"                //CMP AX, 18
            +   " 75 09"                      //JNE SHORT addr2
            +   " 66 C7 83 ?? 00 00 00 01 00" //MOV WORD PTR DS:[EBX + hSPtr], 1
            ;
            cmpLoc = 7;
            break;
        }
        case 2://VC9 Style 1
        {
            var code2 =
                " 66 FF 8B ?? 00 00 00" //DEC WORD PTR DS:[EBX + hSPtr]
            +   " 0F B7 83 ?? 00 00 00" //MOVZX EAX, WORD PTR DS:[EBX + hSPtr]
            +   " 33 C9"                //XOR ECX, ECX
            +   " 66 3B C8"             //CMP CX, AX
            +   " 75 0C"                //JNE SHORT addr
            +   " BA 17 00 00 00"       //MOV EDX, 17
            +   " 66 89 93 ?? 00 00 00" //MOV WORD PTR DS:[EBX + hSPtr], DX
            ;
            var code3 =
                " 66 FF 83 ?? 00 00 00" //INC WORD PTR DS:[EBX + hSPtr]
            +   " 0F B7 83 ?? 00 00 00" //MOVZX EAX, WORD PTR DS:[EBX + hSPtr]
            +   " B9 18 00 00 00"       //MOV ECX, 18
            +   " 66 3B C8"             //CMP CX, AX
            +   " 75 0C"                //JNE SHORT addr2
            +   " BA 01 00 00 00"       //MOV EDX, 1
            +   " 66 89 93 ?? 00 00 00" //MOV WORD PTR DS:[EBX + hSPtr], DX
            ;
            cmpLoc = 7;
            break;
        }
        case 3://VC9 Style 2
        {
            var code2 =
                " 66 01 B5 ?? 00 00 00" //ADD WORD PTR SS:[EBP + hSPtr], SI ; ESI is ORed to -1 in prev statement
            +   " 0F B7 85 ?? 00 00 00" //MOVZX EAX, WORD PTR SS:[EBP + hSPtr]
            +   " 33 C9"                //XOR ECX, ECX
            +   " 66 3B C8"             //CMP CX, AX
            +   " 75 0C"                //JNE SHORT addr
            +   " BA 17 00 00 00"       //MOV EDX, 17
            +   " 66 89 95 ?? 00 00 00" //MOV WORD PTR SS:[EBP + hSPtr], DX
            ;
            var code3 =
                " 66 FF 85 ?? 00 00 00" //INC WORD PTR DS:[EBP + hSPtr]
            +   " 0F B7 85 ?? 00 00 00" //MOVZX EAX, WORD PTR DS:[EBP + hSPtr]
            +   " B9 18 00 00 00"       //MOV ECX, 18
            +   " 66 3B C8"             //CMP CX, AX
            +   " 75 0C"                //JNE SHORT addr2
            +   " BA 01 00 00 00"       //MOV EDX, 1
            +   " 66 89 95 ?? 00 00 00" //MOV WORD PTR DS:[EBP + hSPtr], DX
            ;
            cmpLoc = 7;
            break;
        }
        case 4:
        {
            if (Exe.GetDate() < 20130605) //VC9
            {
                var code2 = " 83 BB ?? ?? 00 00 00"; //CMP DWORD PTR DS:[EBX + hSPtr], 0
                cmpLoc = 0;
            }
            else //VC10
            {
                var code2 =
                    " 89 93 ?? ?? 00 00" //MOV DWORD PTR DS:[EBX + hSPtr], EDX
                +   " 85 D2"             //TEST EDX, EDX
                ;
                cmpLoc = 6;
            }
            code2 +=
                " 7D 0A"                         //JGE SHORT addr
            +   " C7 83 ?? ?? 00 00 00 00 00 00" //MOV DWORD PTR DS:[EBX + hSPtr], 0
            +   " B8 16 00 00 00"                //MOV EAX, 16 ; addr
            +   " 39 83 ?? ?? 00 00"             //CMP DWORD PTR DS:[EBX + hSPtr], EAX
            +   " 7E 06"                         //JLE SHORT addr2
            +   " 89 83 ?? ?? 00 00"             //MOV DWORD PTR DS:[EBX + hSPtr], EAX
            ;
            break;
        }
        case 5://VC11 & VC10 Style 2
        {
            var code2 =
                " 89 ?? ?? ?? 00 00"             //MOV DWORD PTR DS:[EBX + hSPtr], reg32_A
            +   " 85 C0"                         //TEST EAX,EAX
            +   " 79 0C"                         //JNS SHORT addr
            +   " C7 83 ?? ?? 00 00 00 00 00 00" //MOV DWORD PTR DS:[EBX + hSPtr], 0
            +   " EB 0F"                         //JMP SHORT addr2
            +   " 83 F8 16"                      //CMP EAX, 16 ; addr
            +   " 7E 0A"                         //JLE SHORT addr2
            +   " C7 83 ?? ?? 00 00 16 00 00 00" //MOV DWORD PTR DS:[EBX + hSPtr], 16
            ;
            cmpLoc = 6;
            break;
        }
    }

    //Step 2.2 - Find the Hair Style comparison
    offset = Exe.FindHex(code2, hCBegin - 0x300, hCBegin);

    if (offset === -1)
        offset = Exe.FindHex(code2, hCEnd, hCEnd + 0x200);

    if (offset === -1)
        return "Failed in Step 2 - HairStyle comparison missing";

    //Step 2.3 - Extract the EBX/EBP offset refering to Hair style index, Hair style limit addon and save the comparison location
    var hSPtr = Exe.GetHex(offset + 2, 4);
    var hSBegin = offset + cmpLoc;
    var hSEnd = offset + code2.byteCount();

    if (type < 4) //For old Make char window the values were in the range (0x01 - 0x17) instead of (0x00 - 0x16)
        var hSAddon = 1;
    else
        var hSAddon = 0;

    //Step 2.4 - Find the second comparison for Pre-VC9 clients (Left and Right arrows have seperate cases)
    if (typeof(code3) === "string")
    {
        offset = Exe.FindHex(code3, hSEnd + 0x50, hSEnd + 0x400);
        if (offset === -1)
            return "Failed in Step 2 - 2nd HairStyle comparison missing";

        var hSBegin2 = offset + cmpLoc;
        var hSEnd2 = offset + code3.byteCount();
    }

    //Step 3.1 - Get new Hair color limit from user
    var hCNewLimit = Exe.GetUserInput('$hairColorLimit', I_INT16, "Number Input", "Enter new hair color limit", hCLimit, hCLimit, 1000);//Sane Limit of 1000

    //Step 3.2 - Get new Hair style limit from user
    var hSNewLimit = Exe.GetUserInput('$hairStyleLimit', I_INT16, "Number Input", "Enter new hair style limit", 0x16, 0x16, 1000);//Sane Limit of 1000

    //Step 3.3 - Check if both limits are unchanged by user
    if (hCNewLimit === hCLimit && hSNewLimit === 0x16)
        return "Patch Cancelled - No limits changed";

    //Step 3.4 - Extract the Register code (for VC9 clients with new make char window Ref Register is EBP)
    if (type === 3)
        var rcode = 5;//EBP
    else
        var rcode = 3;//EBX

    if (hCNewLimit !== hCLimit)
    {
        //Step 4.1 - Prep & Inject new Hair Color comparison
        var free = __InjectComparison(rcode, hCPtr, 0, hCNewLimit, 4);
        if (free === -1)
            return "Failed in Step 4 - Not enough free space";

        //Step 4.2 - Put a JMP at Original Hair Color comparison & a CALL before the End of comparison
        __JumpPlusCall(hCBegin, hCEnd, free);

        //Step 4.3 - Fixup the Scrollbar for Hair Color
        if (__UpdateScrollBar(hCLimit, hCNewLimit) === -2)
            return "Failed in Step 4 - Not enough free space(2)";
    }
    if (hSNewLimit !== 0x16)
    {
        //Step 5.1 - Prep & Inject mew Hair Style comparison
        var free = __InjectComparison(rcode, hSPtr, hSAddon, hSNewLimit + hSAddon, (type < 4) ? 2 : 4);
        if (free === -1)
            return "Failed in Step 5 - Not enough free space";

        //Step 5.2 - Put a JMP at Original Hair Style comparison & a CALL before the End of comparison
        __JumpPlusCall(hSBegin, hSEnd, free);

        //Step 5.3 - Put a JMP at Second Hair Style comparison & a CALL before the End of the comparison
        if (typeof(hSBegin2) !== "undefined")
            __JumpPlusCall(hSBegin2, hSEnd2, free);

        //Step 5.4 - Fixup the Scrollbar for Hair Style
        if (__UpdateScrollBar(0x16, hSNewLimit) === -2)
            return "Failed in Step 4 - Not enough free space(2)";
    }
    return true;
}

function __InjectComparison(rcode, ptr, min, limit, opsize)
{
    //Step 1.1 - Prep code for New comparison
    if (opsize === 2)
        var pre = " 66";
    else
        var pre = "";

    var code =
        pre + " 83" + Num2Hex(0xB8 + rcode, 1) + ptr + Num2Hex(min, 1)      //CMP (D)WORD PTR DS:[reg32_A + hCPtr], 0
    +   " 7D 0A"                                                            //JGE SHORT addr
    +   pre + " C7" + Num2Hex(0x80 + rcode, 1) + ptr + Num2Hex(min, opsize) //MOV (D)WORD PTR DS:[reg32_A + hCPtr], 0
    +   " 90"                                                               //NOP
    ;

    if (limit > 0x7F)
        code += pre + " 81" + Num2Hex(0xB8 + rcode, 1) + ptr + Num2Hex(limit, opsize);//CMP (D)WORD PTR DS:[reg32_A + hCPtr], hCNewLimit
    else
        code += pre + " 83" + Num2Hex(0xB8 + rcode, 1) + ptr + Num2Hex(limit, 1);     //CMP (D)WORD PTR DS:[reg32_A + hCPtr], hCNewLimit

    code +=
        " 7E 0A"                                                              //JLE SHORT addr2
    +   pre + " C7" + Num2Hex(0x80 + rcode, 1) + ptr + Num2Hex(limit, opsize) //MOV (D)WORD PTR DS:[reg32_A + hCPtr], hCNewLimit
    +   " 90"                                                                 //NOP
    +   " C3"                                                                 //RETN
    ;

    //Step 1.2 - Find Free space for insertion
    var free = Exe.FindSpace(code.byteCount());

    //Step 1.3 - Insert the code in free space
    if (free !== -1)
        Exe.InsertHex(free, code, code.byteCount());

    return free;
}

function __JumpPlusCall(begin, end, func) //func is REAL address
{
    //Step 1 - Create the JMP SHORT
    code = "EB" + Num2Hex((end - 5) - (begin + 2), 1);
    Exe.ReplaceHex(begin, code);

    //Step 2 - Next CALL the Comparison function
    code = "E8" + Num2Hex(Exe.Real2Virl(func) - Exe.Real2Virl(end));
    Exe.ReplaceHex(end - 5, code);
}

function __UpdateScrollBar(oldLimit, newLimit)
{
    //Step 1.1 - Find the Scrollbar create CALLs
    code =
        " 6A" + Num2Hex(oldLimit + 1, 1) //PUSH oldLimit+1
    +   " 6A 01"                         //PUSH 1
    +   " 6A" + Num2Hex(oldLimit, 1)     //PUSH oldLimit
    +   " E8"                            //CALL UIScrollBar::Create?
    ;

    var offsets = Exe.FindAllHex(code);
    if (offsets.length === 0)
        return -1;

    //Step 1.2 - Extract the create function address
    var csize = code.byteCount();
    var func = Exe.Real2Virl(offsets[0] + csize + 4, CODE) + Exe.GetInt32(offsets[0] + csize);

    //Step 2.1 - Prep code to call the function with updated limit as arguments
    if (newLimit > 0x7E)
        code = " 68" + Num2Hex(newLimit + 1);
    else
        code = " 6A" + Num2Hex(newLimit + 1, 1);

    code += " 6A 01";

    if (newLimit > 0x7F)
        code += " 68" + Num2Hex(newLimit);
    else
        code += " 6A" + Num2Hex(newLimit, 1);

    code +=
        " E8" + MakeVar(1)
    +   " C3"
    ;

    //Step 2.2 - Find Free space for insertion
    var free = Exe.FindSpace(code.byteCount());
    if (free === -1)
        return -2;

    var freeVirl = Exe.Real2Virl(free, DIFF);

    //Step 2.3 - Fill in the blanks
    code = SetValue(code, 1, func - (freeVirl + code.byteCount() - 1));

    //Step 3.1 - Insert the code at free space
    Exe.InsertHex(free, code, code.byteCount());

    //Step 3.2 - Create a NOP sequence + CALL to the above at each of the matches
    for (var i = 0; i < offsets.length; i++)
    {
        Exe.ReplaceHex(offsets[i], " 90".repeat(csize - 1));
        Exe.ReplaceInt32(offsets[i] + csize, freeVirl - Exe.Real2Virl(offsets[i] + csize + 4, CODE));
    }
    return 0;
}