//####################################################################\\
//# Make the client call our DNS resolution function before          #\\
//# g_accountAddr is accessed. Function replaces g_accountAddr value #\\
//####################################################################\\

function EnableDNSSupport()
{
    //Step 1.1 - Find the common IP address across all clients
    var offset = Exe.FindString("211.172.247.115", VIRTUAL);
    if (offset === -1)
        return "Failed in Step 1 - IP not found";

    //Step 1.2 - Find the g_accountAddr assignment to the IP
    var code = "C7 05 ?? ?? ?? 00" + Num2Hex(offset); //MOV DWORD PTR DS:[g_accountAddr], OFFSET addr; ASCII '211.172.247.115'

    offset = Exe.FindHex(code);
    if (offset === -1)
        return "Failed in Step 1 - g_accountAddr assignment missing";

    //Step 1.3 - Extract g_accountAddr
    var gAccountAddr = Exe.GetHex(offset + 2, 4);

    //Step 2.1 - Find the code to hook our function to
    code =
        " E8 ?? ?? ?? FF"    //CALL g_resMgr
    +   " 8B C8"             //MOV ECX,EAX
    +   " E8 ?? ?? ?? FF"    //CALL CResMgr::Get
    +   " 50"                //PUSH EAX
    +   " B9 ?? ?? ?? 00"    //MOV ECX,OFFSET g_windowMgr
    +   " E8 ?? ?? ?? FF"    //CALL UIWindowMgr::SetWallpaper
    +   " A1" + gAccountAddr //MOV EAX,DWORD PTR DS:[g_accountAddr]
    ;
    offset = Exe.FindHex(code);

    if (offset === -1)
    {
        code = code.replace("A1" + gAccountAddr, "8B ??" + gAccountAddr);//Change MOV EAX with MOV reg32_B
        offset = Exe.FindHex(code);
    }
    if (offset === -1)
        return "Failed in Step 2";

    //Step 2.2 - Extract g_resMgr
    var gResMgr = Exe.Real2Virl(offset + 5) + Exe.GetInt32(offset + 1);

    //Step 3.1 - Construct our function
    var dnscode =
        " E8" + MakeVar(1)                 //CALL g_ResMgr ; call the actual function that was supposed to be run
    +   " 60"                              //PUSHAD
    +   " 8B 35" + MakeVar(2)              //MOV ESI,DWORD PTR DS:[g_accountAddr]
    +   " 56"                              //PUSH ESI
    +   " FF 15" + MakeVar(3)              //CALL DWORD PTR DS:[<&WS2_32.#52>] ; WS2_32.gethostbyname()
    +   " 8B 48 0C"                        //MOV ECX,DWORD PTR DS:[EAX+0C]
    +   " 8B 11"                           //MOV EDX,DWORD PTR DS:[ECX]
    +   " 89 D0"                           //MOV EAX,EDX
    +   " 0F B6 48 03"                     //MOVZX ECX,BYTE PTR DS:[EAX+3]
    +   " 51"                              //PUSH ECX
    +   " 0F B6 48 02"                     //MOVZX ECX,BYTE PTR DS:[EAX+2]
    +   " 51"                              //PUSH ECX
    +   " 0F B6 48 01"                     //MOVZX ECX,BYTE PTR DS:[EAX+1]
    +   " 51"                              //PUSH ECX
    +   " 0F B6 08"                        //MOVZX ECX,BYTE PTR DS:[EAX]
    +   " 51"                              //PUSH ECX
    +   " 68" + MakeVar(4)                 //PUSH OFFSET addr1 ; ASCII "%d.%d.%d.%d"
    +   " 68" + MakeVar(5)                 //PUSH OFFSET addr2 ; location is at the end of the code with Initial value "127.0.0.1"
    +   " FF 15" + MakeVar(6)              //CALL DWORD PTR DS:[<&USER32.wsprintfA>]
    +   " 83 C4 18"                        //ADD ESP,18
    +   " C7 05" + MakeVar(2) + MakeVar(5) //MOV DWORD PTR DS:[g_accountAddr], addr2 ; Replace g_accountAddr current value with its ip address
    +   " 61"                              //POPAD
    +   " C3"                              //RETN
    +   " 00"                              //Just a gap in between
    +   Ascii2Hex("127.0.0.1")             //addr2 ; Putting enough space for 4*3 digits  + 3 Dots + 1 NULL at the end
    +   " 00".repeat(7)
    ;

    //Step 3.2 - Calculate free space that the code will need.
    var size = dnscode.byteCount();

    //Step 3.3 - Find Free space for insertion
    var free = Exe.FindSpace(size);
    if (free === -1)
        return "Failed in Step 3 - Not enough free space";

    //Step 4.1 - Create a call to our function at CALL g_ResMgr
    Exe.ReplaceHex(offset + 1, Num2Hex(Exe.Real2Virl(free, DIFF) - Exe.Real2Virl(offset+5)));

    //Step 4.2 - Find gethostbyname function address (#52 when imported by ordinal)
    var uGethostbyname = Exe.FindFunction("gethostbyname", "ws2_32.dll", 52);//By Ordinal
    if (uGethostbyname === -1)
        return "Failed in Step 4 - gethostbyname not found";

    //Step 4.3 - Find the IP address format string
    var ipFormat = Exe.FindString("%d.%d.%d.%d", VIRTUAL);
    if (ipFormat === -1)
        return "Failed in Step 4 - IP string missing";

    //Step 4.4 - Adjust g_resMgr relative to function
    gResMgr = gResMgr - Exe.Real2Virl(free + 5, DIFF);

    //Step 4.5 - addr2 value
    offset = Exe.Real2Virl(free + size - (3*1 + 4*3 + 1), DIFF);//3 Dots, 4x3 digits, NULL

    //Step 4.7 - Fill in the blanks
    dnscode = SetValue(dnscode, 1, gResMgr);
    dnscode = SetValue(dnscode, 2, gAccountAddr, 2); //Change in two places
    dnscode = SetValue(dnscode, 3, uGethostbyname);
    dnscode = SetValue(dnscode, 4, ipFormat);
    dnscode = SetValue(dnscode, 5, offset, 2); //Change in two places
    dnscode = SetValue(dnscode, 6, Exe.FindFunction("wsprintfA", "USER32.dll"));

    //Step 5 - Insert the code at free space
    Exe.InsertHex(free, dnscode, size);
    return true;
}