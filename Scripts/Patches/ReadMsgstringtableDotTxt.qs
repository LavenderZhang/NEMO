//#########################################################################\\
//# Change the JNZ after LangType check in InitMsgStrings function to JMP #\\
//#########################################################################\\

function ReadMsgstringtableDotTxt()
{
    //Step 1.1 - Check if Langtype is available (LT.Error will be a string if not)
    if (LT.Error)
        return "Failed in Step 1 - " + LT.Error;

    //Step 1.2 - Find the comparison which is at the start of the function
    var code =
        " 83 3D" + LT.Hex + " 00" //CMP DWORD PTR DS:[g_serviceType], 0
    +   " 56"                     //PUSH ESI
    +   " 75"                     //JNZ SHORT addr -> continue with msgStringTable.txt loading
    ;
    var offset = Exe.FindHex(code); //VC9+ Clients

    if (offset === -1)
    {
        code =
            " A1" + LT.Hex //MOV EAX, DWORD PTR DS:[g_serviceType]
        +   " 56"          //PUSH ESI
        +   " 85 C0"       //TEST EAX, EAX
        +   " 75"          //JNZ SHORT addr -> continue with msgStringTable.txt loading
        ;
        offset = Exe.FindHex(code);//Older Clients
    }
    if (offset === -1)
        return "Failed in Step 1";

    //Step 2 - Change JNZ to JMP
    Exe.ReplaceInt8(offset + code.byteCount() - 1, 0xEB);
    return true;
}