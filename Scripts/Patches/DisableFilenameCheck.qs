//##############################################################\\
//# Change the JNZ inside WinMain (or function called from it) #\\
//# to JMP which will skip showing the "Invalid Exe" Message   #\\
//##############################################################\\

function DisableFilenameCheck()
{
    //Step 1 - Find the Comparison pattern
    var code =
        " 84 C0"          //TEST AL, AL
    +   " 74 07"          //JZ SHORT addr1
    +   " E8 ?? ?? FF FF" //CALL SearchProcessIn9X
    +   " EB 05"          //JMP SHORT addr2
    +   " E8 ?? ?? FF FF" //CALL SearchProcessInNT <= addr1
    +   " 84 C0"          //TEST AL, AL <= addr2
    +   " 75"             //JNZ addr3
    ;
    var offset = Exe.FindHex(code);

    if (offset === -1)
    {
        code = code.replace("EB 05", "EB 0A BE 01 00 00 00"); //Insert MOV ESI, 1 in between JMP and CALL SearchProcessInNT . Correct for addr2
        code = code.replace("74 07", "74 0C");//Correct for addr1
        Exe.FindHex(code);
    }
    if (offset === -1)
        return "Failed in Step 1";

    //Step 2 - Replace JNZ/JNE to JMP
    Exe.ReplaceInt8(offset + code.byteCount() - 1, 0xEB);
    return true;
}