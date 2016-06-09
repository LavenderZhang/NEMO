//################################################################\\
//# Find the 1rag1 comparison and change the JNZ after it to JMP #\\
//################################################################\\

function Disable1rag1Params()
{
    //Step 1.1 - Find "1rag1"
    var offset = Exe.FindString("1rag1", VIRTUAL);
    if (offset === -1)
        return "Failed in Step 1 - 1rag1 not found";

    //Step 1.2 - Find its reference
    var code =
        " 68" + Num2Hex(offset) //PUSH OFFSET addr ; ASCII "1rag1"
    +   " ??"                   //PUSH reg32_A
    +   " FF ??"                //CALL ESI ; strstr function compares reg32_A with "1rag1"
    +   " 83 C4 08"             //ADD ESP, 8
    +   " 85 ??"                //TEST EAX, EAX
    +   " 75"                   //JNZ SHORT addr2
    ;
    var offset = Exe.FindHex(code);

    if (offset === -1)
    {
        code = code.replace("FF ?? 83 C4", "E8 ?? ?? ?? ?? 83 C4"); //Direct call instead of CALL reg32
        offset = Exe.FindHex(code);
    }
    if (offset === -1)
        return "Failed in Step 1 - 1rag1 reference missing";

    //Step 2 - Replace JNZ/JNE with JMP
    Exe.ReplaceInt8(offset + code.byteCount() - 1, 0xEB);
    return true;
}