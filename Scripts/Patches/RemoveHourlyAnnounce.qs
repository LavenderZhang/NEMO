//##########################################################\\
//# Change the JNE and JLE to JMP after Hourly Comparisons #\\
//# inside CRenderer::DrawAgeRate & PlayTime functions     #\\
//##########################################################\\

function RemoveHourlyAnnounce() //PlayTime comparison is not there in Pre-2010 clients
{
    //Step 1.1 - Find the comparison for Game Grade
    var code =
        " 75 ??"          //JNE SHORT addr1
    +   " 66 8B 44 24 ??" //MOV AX, WORD PTR SS:[ESP+x]
    +   " 66 85 C0"       //TEST AX, AX
    +   " 75"             //JNE SHORT addr2
    ;
    if (EBP_TYPE)
        code = code.replace("44 24", "45"); //change ESP+x to EBP-y

    var offset = Exe.FindHex(code);//VC9+ Clients

    if (offset === -1)
    {
        code = code.replace("66", "");//Change MOV AX to MOV EAX and thereby WORD PTR becomes DWORD PTR
        offset = Exe.FindHex(code);//Older clients and some new clients
    }
    if (offset === -1)
        return "Failed in Step 1";

    //Step 1.2 - Change JNE to JMP
    Exe.ReplaceInt8(offset, 0xEB);

    //Step 2.1 - Find Time divider before the PlayTime Reminder comparison
    code =
        " B8 B1 7C 21 95" //MOV EAX, 95217CB1
    +   " F7 E1"          //MUL ECX
    ;

    var offsets = Exe.FindAllHex(code);
    if (offsets.length === 0)
        return "Failed in Step 2 - Magic Divisor not found";

    for (var i = 0; i < offsets.length; i++)
    {
        //Step 2.2 - Find the JLE after each (below the TEST/CMP instruction)
        offset = Exe.FindHex("0F 8E ?? ?? 00 00", offsets[i] + 7, offsets[i] + 30);//JLE addr

        //Step 2.3 - Change to NOP + JMP
        if (offset !== -1)
            Exe.ReplaceHex(offset, " 90 E9");

        /*
        offset = Exe.FindHex(" 0F 85 ?? ?? 00 00", offsets[i] + 7, offsets[i] + 30);//JNE addr
        if (offset === -1)
            return "Failed in Step 2 - Iteration No." + i;
        */
    }
    return true;
}