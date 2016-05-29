//####################################################\\
//# Modify CView::SetQuakeInfo and CView::SetQuake   #\\
//# functions to return without assigning any values #\\
//####################################################\\

function DisableQuakeEffect()
{
    //Step 1.1 - Find ".BMP"
    var offset = Exe.FindString(".BMP", VIRTUAL);
    if (offset === -1)
        return "Failed in Step 1 - BMP not found";

    //Step 1.2 - Find its reference
    var code =
        " 68" + Num2Hex(offset) //PUSH OFFSET addr; ASCII ".BMP"
    +   " 8B"                   //MOV ECX, reg32_A
    ;

    offset = Exe.FindHex(code);
    if (offset === -1)
        return "Failed in Step 1 - BMP reference missing";

    //Step 2.1 - Find the SetQuakeInfo call (should be within 0x80 bytes before offset)
    code =
        " E8 ?? ?? ?? ??" //CALL CView::SetQuakeInfo
    +   " 33 C0"          //XOR EAX, EAX
    +   " E9 ?? ?? 00 00" //JMP addr
    ;
    var offset2 = Exe.FindHex(code, offset - 0x80, offset);

    if (offset2 === -1)
    {
        code = code.replace("33 C0 E9 ?? ?? 00 00", "?? ?? 33 C0"); //Change XOR & JMP => POP reg32 x2 & XOR
        offset2 = Exe.FindHex(code, offset - 0x100, offset);
    }
    if (offset2 === -1)
        return "Failed in Step 2 - SetQuakeInfo call missing";

    //Step 2.2 - Extract the Real Address of SetQuakeInfo
    offset2 += Exe.GetInt32(offset2 + 1) + 5;

    //Step 2.3 - Replace the start with RETN 0C
    Exe.ReplaceHex(offset2, "C2 0C 00");

    //Step 3.1 - Find the SetQuake call (should be within 0xA0 bytes before offset)
    code =
        " 6A 01"          //PUSH 1
    +   " E8 ?? ?? ?? ??" //CALL CView::SetQuake
    +   " 33 C0"          //XOR EAX, EAX
    +   " E9 ?? ?? 00 00" //JMP addr
    ;
    offset2 = Exe.FindHex(code, offset - 0xA0, offset);

    if (offset2 === -1)
    {
        code = code.replace("33 C0 E9 ?? ?? 00 00", "?? ?? 33 C0"); //Change XOR & JMP => POP reg32 x2 & XOR
        offset2 = Exe.FindHex(code, offset - 0x120, offset);
    }
    if (offset2 === -1)
        return "Failed in Step 3 - SetQuake call missing";

    //Step 3.2 - Extract the Raw Address of SetQuake
    offset2 += Exe.GetInt32(offset2 + 3) + 7;

    //Step 3.3 - Replace the start with RETN 14
    Exe.ReplaceHex(offset2, "C2 14 00");
    return true;
}