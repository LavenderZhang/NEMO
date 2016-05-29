//#####################################\\
//# Set g_hideAccountList always to 1 #\\
//#####################################\\

function SkipServiceSelect()
{
    //Step 1 - Find "passwordencrypt"
    var offset = Exe.FindString("passwordencrypt", VIRTUAL);
    if (offset === -1)
        return "Failed in Step 1";

    //Step 2.1 - Find its reference (g_hideAccountList is assigned just above it)
    var code =
        " 74 07"                //JZ SHORT addr - skip the below code
    +   " C6 05 ?? ?? ?? ?? 01" //MOV BYTE PTR DS:[g_hideAccountList], 1
    +   " 68" + Num2Hex(offset) //PUSH offset ; "passwordencrypt"
    ;
    var repl = " 90 90"; //NOP out JZ
    var offset2 = Exe.FindHex(code);

    if (offset2 === -1)
    {
        code =
            " 0F 45 ??"             //CMOVNZ reg32_A, reg32_B
        +   " 88 ?? ?? ?? ?? ??"    //MOV BYTE PTR DS:[g_hideAccountList], reg8_A
        +   " 68" + Num2Hex(offset) //PUSH offset ; "passwordencrypt"
        ;
        repl = " 90 8B"; //change CMOVNZ to MOV
        offset2 = Exe.FindHex(code);
    }
    if (offset2 === -1)
        return "Failed in Step 2";

    //Step 2.2 - Change conditional instruction to permanent setting
    Exe.ReplaceHex(offset2, repl);
    return true;
}