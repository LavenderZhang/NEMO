//###########################################################################\\
//# Change JNZ to JMP after LT.Hex comparison inside DataTxtDecode function #\\
//###########################################################################\\

function UsePlainTextDescriptions()
{
    //Step 1.1 - Check if LangType is available (LT.Error will be a string if not)
    if (LT.Error)
        return "Failed in Step 1 - " + LT.Error;

    //Step 1.2 - Find the LangType comparison in the DataTxtDecode function
    var code =
        " 83 3D" + LT.Hex + " 00" //CMP DWORD PTR DS:[g_serviceType], 0
    +   " 75 ??"                  //JNZ SHORT addr
    +   " 56"                     //PUSH ESI
    +   " 57"                     //PUSH EDI
    ;
    var repLoc = 7;//Position of JNZ relative to offset
    var offset = Exe.FindHex(code);//VC9+ Clients

    if (offset === -1)
    {
        code = code.replace("75 ?? 56 57", "75 ?? 57"); //remove PUSH ESI
        offset = Exe.FindHex(code);//Latest Clients
    }
    if (offset === -1)
    {
        code =
            " A1" + LT.Hex //MOV EAX, DWORD PTR DS:[g_serviceType]
        +   " 56"          //PUSH ESI
        +   " 85 C0"       //TEST EAX, EAX
        +   " 57"          //PUSH EDI
        +   " 75"          //JNZ SHORT addr
        ;
        repLoc = code.byteCount() - 1;
        offset = Exe.FindHex(code);//Older Clients
    }
    if (offset === -1)
        return "Failed in Step 1 - LangType Comparison missing";

    //Step 2 - Change JNE/JNZ to JMP
    Exe.ReplaceInt8(offset + repLoc, 0xEB);
    return true;
}