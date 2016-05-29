//######################################################################\\
//# Divert connect() call in CConnection::Connect() function to save   #\\
//# the first IP used and use it for any following connection attempts #\\
//######################################################################\\

function EnableProxySupport()
{
    //Step 1.1 - Find the String's address.
    var offset = Exe.FindString("Failed to setup select mode", VIRTUAL);
    if (offset === -1)
        return "Failed in Step 1 - setup string not found";

    //Step 1.2 - Find the string's referenced location (which is only inside CConnection::Connect)
    offset = Exe.FindHex("68" + Num2Hex(offset));
    if (offset === -1)
        return "Failed in Step 1 - setup string reference missing";

    //Step 2.1 - Find connect call (Indirect call pattern should be within 0x50 bytes before offset)    - VC9 onwards
    var code =
        " FF 15 ?? ?? ?? ??" //CALL DWORD PTR DS:[<&WS2_32.connect>]
    +   " 83 F8 FF"          //CMP EAX,-1
    +   " 75 ??"             //JNZ SHORT addr
    +   " 8B ?? ?? ?? ?? ??" //MOV EDI,DWORD PTR DS:[<&WS2_32.WSAGetLastError>]
    +   " FF ??"             //CALL EDI
    +   " 3D 33 27 00 00"    //CMP EAX, 2733h
    ;
    var offset2 = Exe.FindHex(code, offset - 0x50, offset);

    if (offset2 === -1)
    {
        //Step 2.2 - Find connect call (Direct call pattern should be within 0x90 bytes before offset) - Older clients
        code =
            " E8 ?? ?? ?? ??" //CALL <&WS2_32.connect>
        +   " 83 F8 FF"       //CMP EAX,-1
        +   " 75 ??"          //JNZ SHORT addr
        +   " E8 ?? ?? ?? ??" //CALL <&WS2_32.WSAGetLastError>
        +   " 3D 33 27 00 00" //CMP EAX, 2733h
        ;

        offset2 = Exe.FindHex(code, offset - 0x90, offset);
        if (offset2 === -1)
            return "Failed in Step 2"; //Both patterns failed

        var bIndirectCALL = false;
    }
    else
    {
        var bIndirectCALL = true;
        Exe.ReplaceHex(offset2, " 90 E8"); //Replace with direct call opcode (address will be changed afterwards)
        offset2++;
    }

    //Step 2.3 - Get the address pointing to ws2_32.connect
    var connAddr = Exe.GetInt32(offset2 + 1);
    if (!bIndirectCALL)
        connAddr += Exe.Real2Virl(offset2 + 5, CODE);

    //Step 3.1 - Create the IP Saving code (g_saveIP will be filled later. for now we use filler)
    code =
        " A1" + MakeVar(1) //MOV EAX, DWORD PTR DS:[g_saveIP]
    +   " 85 C0"           //TEST EAX, EAX
    +   " 75 08"           //JNZ SHORT addr
    +   " 8B 46 0C"        //MOV EAX, DWORD PTR DS:[ESI+C]
    +   " A3" + MakeVar(1) //MOV DWORD PTR DS:[g_saveIP], EAX
    +   " 89 46 0C"        //MOV DWORD PTR DS:[ESI+C], EAX <- addr
    ;

    if (bIndirectCALL)
        code += " FF 25" + Num2Hex(connAddr); //JMP DWORD PTR DS:[<&WS2_32.connect>]
    else
        code += " E9" + MakeVar(2); //JMP <&WS2_32.connect>; will be filled later

    var csize = code.byteCount();

    //Step 3.2 - Find Free Space for insertion
    var free = Exe.FindSpace(0x4 + csize); //First 4 bytes are for g_saveIP
    if (free === -1)
        return "Failed in Step 3 - Not enough free space";

    var freeVirl = Exe.Real2Virl(free, DIFF);

    //Step 3.3 - Set g_saveIP
    code = SetValue(code, 1, freeVirl, 2); //Change in two places

    //Step 3.4 - Set connect address for Direct call - need relative offset
    if (!bIndirectCALL)
        code = SetValue(code, 2, connAddr - (freeVirl + csize)); //Get Offset relative to JMP

    //Step 4.1 - Redirect connect call to our code.
    Exe.ReplaceInt32(offset2 + 1, freeVirl + 4 - Exe.Real2Virl(offset2 + 5, CODE));

    //Step 4.2 - Insert the code to the free space
    Exe.InsertHex(free, "00 00 00 00" + code, 4 + csize); //4 NULLs for g_saveIP filler

    return true;
}