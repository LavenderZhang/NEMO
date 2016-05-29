//##################################################################\\
//# Change the JNE after accountID comparison against GM ID to JMP #\\
//# inside CPc::SetSprNameList and CPc::SetActNameList functions   #\\
//##################################################################\\

function RemoveGMSprite()
{
    //Step 1.1 - Find the location where both functions are called
    var code =
        " 68 ?? ?? ?? 00" //PUSH OFFSET addr; actName
    +   " 6A 05"          //PUSH 5; layer
    +   " 8B ??"          //MOV ECX, reg32_A
    +   " E8 ?? ?? FF FF" //CALL CPc::SetActNameList
    ;
    var len = code.byteCount();

    code += code; //PUSH OFFSET addr; sprName
                  //PUSH 5; layer
                  //MOV ECX, reg32_A
                  //CALL CPc::SetSprNameList

    var offset = Exe.FindHex(code);
    if (offset === -1)
    {
        code = code.replace(" 8B ??", ""); //Remove the first MOV ECX, reg32_A . It might have been assigned earlier
        offset = Exe.FindHex(code);
    }
    if (offset === -1)
        return "Failed in Step 1";

    //Step 1.2 - Update offset to location of PUSH sprName
    offset += code.byteCount() - len;

    //Step 1.3 - Extract the Function addresses (REAL)
    var funcs = [];
    funcs[0] = offset + Exe.GetInt32(offset - 4);             //CPc::SetActNameList REAL address
    funcs[1] = offset + len + Exe.GetInt32(offset + len - 4); //CPc::SetSprNameList REAL address

    //Step 2.1 - Prep code to look for IsNameYellow function call
    code =
        " E8 ?? ?? ?? ??" //CALL IsNameYellow; Compares accountID against GM IDs
    +   " 83 C4 04"       //ADD ESP, 4
    +   " 84 C0"          //TEST AL, AL
    +   " 0F 84"          //JNE addr2
    ;

    for (var i = 0; i < funcs.length; i++)
    {
        //Step 2.2 - Find the Call
        offset = Exe.FindHex(code, funcs[i]);
        if (offset === -1)
            return "Failed in Step 2 - Iteration No." + i;

        //Step 2.3 - Replace JNE with NOP + JMP
        Exe.ReplaceHex(offset + code.byteCount() - 2, "90 E9");
    }
    return true;
}