//#########################################################################################\\
//# Change the JNZ to JMP after CFile::Open result TEST inside CPaletteRes::Load function #\\
//#########################################################################################\\

function IgnoreMissingPaletteError()
{
    //Step 1.1 - Find the Error message string's offset
    var offset = Exe.FindString("CPaletteRes :: Cannot find File : ", VIRTUAL);
    if (offset === -1)
        return "Failed in Step 1 - Error Message not found";

    //Step 1.2 - Find its reference
    var code =
        " 68" + Num2Hex(offset) //PUSH OFFSET addr; ASCII "CPaletteRes :: Cannot find File : "
    +   " 8D"                   //LEA ECX, [LOCAL.x]
    ;
    offset2 = Exe.FindHex(code);

    if (offset2 === -1)
    {
        code = "BF" + Num2Hex(offset); //MOV EDI, OFFSET addr; ASCII "CPaletteRes :: Cannot find File : "
        offset2 = Exe.FindHex(code);
    }
    if (offset2 === -1)
        return "Failed in Step 1 - Message Reference missing";

    //Step 1.3 - Now Find the call to CFile::Open and its result comparison
    code =
        " E8 ?? ?? ?? 00"    //CALL CFile::Open
    +   " 84 C0"             //TEST AL, AL
    +   " 0F 85 ?? ?? 00 00" //JNZ addr
    ;

    offset = Exe.FindHex(code, offset2 - 0x100, offset2);
    if (offset === -1)
        return "Failed in Step 1 - Function call missing";

    //Step 2 - Replace JNZ with NOP + JMP
    Exe.ReplaceHex(offset + code.byteCount() - 6, "90 E9");
    return true;
}