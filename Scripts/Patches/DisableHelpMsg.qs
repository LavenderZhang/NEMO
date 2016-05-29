//########################################################\\
//# Change the JNE after LT.Hex comparison to JMP in the #\\
//# On Login callback which skips loading HelpMsgStr     #\\
//########################################################\\

function DisableHelpMsg() //Some Pre-2010 client doesnt have this PUSHes or HelpMsgStr reference.
{
    //Step 1.1 - Find the Unique PUSHes after the comparison . This is same for all clients
    var code =
        " 6A 0E" //PUSH 0E
    +   " 6A 2A" //PUSH 2A
    ;
    var offset = Exe.FindHex(code);

    if (offset === -1)
    {
        code = code.replace("6A 2A", "8B 01 6A 2A"); //Insert a MOV EAX, DWORD PTR DS:[ECX] after PUSH 0E
        offset = Exe.FindHex(code);
    }
    if (offset === -1)
        return "Failed in Step 1 - Signature PUSHes missing";

    //Step 1.2 - Check if LangType is available (LT.Error will be a string if not)
    if (LT.Error)
        return "Failed in Step 1 - " + LT.Error;

    //Step 1.3 - Now find the LangType comparison before it
    code =
        LT.Hex //CMP DWORD PTR DS:[g_serviceType], reg32_A
    +   " 75"  //JNE addr
    ;
    offset2 = Exe.FindHex(code, offset - 0x20, offset);

    if (offset2 === -1)
    {
        code = code.replace(/ 75$/, " 00 75");//directly compared to 0
        offset2 = Exe.FindHex(code, offset - 0x20, offset);
    }
    if (offset2 === -1)
        return "Failed in Step 1 - Comparison not found";

    //Step 2 - Replace JNE with JMP
    Exe.ReplaceInt8(offset2 + code.byteCount() - 1, 0xEB);
    return true;
}