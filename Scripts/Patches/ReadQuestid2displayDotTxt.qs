//#########################################################################\\
//# NOP out the JNE after LangType Comparison (but before PUSH 0 and      #\\
//# PUSH 'questID2display.txt') in ITEM_INFO::InitItemInfoTables function #\\
//#########################################################################\\

function ReadQuestid2displayDotTxt()
{
    //Step 1.1 - Find "questID2display.txt"
    var offset = Exe.FindString("questID2display.txt", VIRTUAL);
    if (offset === -1)
        return "Failed in Step 1 - questID2display not found";

    //Step 1.2 - Find its reference
    var code =
        " 6A 00"                //PUSH 0
    +   " 68" + Num2Hex(offset) //PUSH addr2 ; "questID2display.txt"
    ;
    offset = Exe.FindHex(code);//VC9+ Clients

    if (offset === -1)
    {
        code = code.replace(" 00", " 00 8D ?? ??");//Insert LEA reg32, [LOCAL.x] after PUSH 0 for Older Clients
        offset = Exe.FindHex(code);
    }
    if (offset === -1)
        return "Failed in Step 1";

    //Step 2 - Replace JNE before PUSH 0 with NOP (for long JNE, byte at offset - 1 will be 0)
    if (Exe.GetInt8(offset - 1) === 0)
        Exe.ReplaceHex(offset - 6, " 90 90 90 90 90 90");
    else
        Exe.ReplaceHex(offset - 2, " 90 90");

    return true;
}