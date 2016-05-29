//###############################################################################\\
//# Change the Hardcoded loading & retrieval of Shield prefix to Lua based code #\\
//###############################################################################\\

MaxShield = 10;
function EnableCustomShields() //Pre-VC9 Client support not completed
{
    /***** Find first inject & return locations - table loading area *****/

    //Step 1.1 - Find "_가드" (Guard's suffix)
    var offset = Exe.FindString("_\xB0\xA1\xB5\xE5", VIRTUAL);
    if (offset === -1)
        return "Failed in Step 1 - Guard not found";

    //Step 1.2 - Find where it is loaded to table which is the inject location
    var code = "C7 ?? 04" + Num2Hex(offset); //MOV DWORD PTR DS:[reg32_A + 4], OFFSET <guard suffix>
    var type = 2;
    var hookReq = Exe.FindHex(code);//VC9+ Clients

    if (hookReq === -1)
    {
        code =
            " 6A 03" //PUSH 3
        +   " 8B ??" //MOV ECX, reg32_A
        +   " C7 00" //MOV DWORD PTR DS:[EAX], OFFSET <guard suffix>
        +   Num2Hex(offset)
        ;
        type = 1;
        hookReq = Exe.FindHex(code);
    }
    if (hookReq === -1)
        return "Failed in Step 1 - Guard reference missing";

    //Step 1.3 - Extract the register that points to the location to store the suffix.
    if (type === 1)
        var regPush = " 83 E8 04 50";//SUB EAX, 4 and PUSH EAX
    else
        var regPush = Exe.GetHex(hookReq + 1, 1).replace("4", "5");//PUSH reg32_A

    //Step 1.4 - Find "_버클러" (Buckler's suffix)
    offset = Exe.FindString("_\xB9\xF6\xC5\xAC\xB7\xAF", VIRTUAL);
    if (offset === -1)
        return "Failed in Step 1 - Buckler not found";

    //Step 1.5 - Find where its loaded to table.
    if (type === 1)
        code = "C7 00" + Num2Hex(offset); //MOV DWORD PTR DS:[EAX], OFFSET <buckler suffix>
    else
        code = "C7 ?? 08" + Num2Hex(offset); //MOV DWORD PTR DS:[reg32_A + 8], OFFSET <buckler suffix>

    offset = Exe.FindHex(code, hookReq, hookReq + 0x38);
    if (offset === -1)
        return "Failed in Step 1 - Buckler reference missing";

    //Step 1.6 - Return address is after code.
    var retReq = offset + code.byteCount();

    //Step 2.1 - Find Free space for insertion considering maximum code size possible
    var funcName = "ReqShieldName\x00";
    var free = Exe.FindSpace(funcName.length + 0xB + 0x3D + 0x12);
    if (free === -1)
        return "Failed in Part 2 - Not enough free space";

    //Step 2.2 - Construct code.
    code =
        Ascii2Hex(funcName)
    +   " 60"                      //PUSHAD
    +   " BF 01 00 00 00"          //MOV EDI, 1
    +   " BB" + Num2Hex(MaxShield) //MOV EBX, finalValue
    ;
    code += GenLuaCaller(free + code.byteCount(), funcName, Exe.Real2Virl(free, DIFF), "d>s", " 57");
    code +=
        " 8A 08"       //MOV CL, BYTE PTR DS:[EAX]
    +   " 84 C9"       //TEST CL, CL
    +   " 74 07"       //JE SHORT addr
    +   " 8B 4C 24 20" //MOV ECX, DWORD PTR SS:[ESP+20]
    +   " 89 04 B9"    //MOV DWORD PTR DS:[EDI*4+ECX],EAX
    +   " 47"          //INC EDI; addr
    +   " 39 DF"       //CMP EDI,EBX
    +   " 7E"          //JLE SHORT addr2; to start of generate
    ;
    code += Num2Hex(funcName.length + 0xB - (code.byteCount() + 1), 1);
    code +=
        " 61"          //POPAD
    +   " 83 C4 04"    //ADD ESP, 4
    +   " E9"          //JMP retReq
    ;
    code += Num2Hex(Exe.Real2Virl(retReq, CODE) - Exe.Real2Virl(free + code.byteCount() + 4, DIFF));

    //Step 2.3 - Insert the code into free space
    Exe.InsertHex(free, code, code.byteCount());

    //Step 2.4 - Create regPush & JMP at hookReq to the code
    code = regPush + " E9" + Num2Hex(Exe.Real2Virl(free + funcName.length, DIFF) - Exe.Real2Virl(hookReq + code.byteCount() + 4, CODE));
    Exe.ReplaceHex(hookReq, code);

    /***** Inject Lua file loading *****/

    var retVal = AddLuaLoaders(
        "Lua Files\\DataInfo\\jobName",
        [
            "Lua Files\\DataInfo\\ShieldTable",
            "Lua Files\\DataInfo\\ShieldTable_F"
        ]
    );
    if (typeof(retVal) === "string")
        return "Failed in Step 2 - " + retVal;

    /***** Find second inject location - CSession::GetShieldType *****/

    //Step 3.1 - Find location where the GetShieldType is called - there are multiple matches but all of them are same
    code =
        " 3D D0 07 00 00" //CMP EAX, 7D0
    +   " 7E ??"          //JLE SHORT addr1
    +   " 50"             //PUSH EAX
    +   " B9 ?? ?? ?? 00" //MOV ECX, g_session; Note: this is the reference value for all the tables
    +   " E8"             //CALL CSession::GetShieldType
    ;

    var offsets = Exe.FindAllHex(code);
    if (offsets.length === 0)
        return "Failed in Step 3 - GetShieldType call missing";

    //Step 3.2 - Find call to CSession::GetWeaponType before one of the locations.
    for (var i = 0; i < offsets.length; i++)
    {
        offset = Exe.FindHex("E8 ?? ?? ?? ?? 85 C0", offsets[i] - 0x40, offsets[i]);//CALL CSession::GetWeaponType followed by TEST EAX, EAX

        if (offset === -1)
            offset = Exe.FindHex("E8 ?? ?? ?? ?? 33 ?? 85 C0", offsets[i] - 0x40, offsets[i]);//XOR reg32_A, reg32_A added before TEST

        if (offset !== -1)
            break;
    }
    if (offset === -1)
        return "Failed in Step 3 - GetWeaponType call missing";

    //Step 3.3 - Change the CALL to following so that GetShieldType is always called
    //    NOP
    //    POP EAX
    //    OR EAX, -1
    Exe.ReplaceHex(offset, "90 58 83 C8 FF");

    //Step 3.4 - Extract REAL address of GetShieldType function
    offset = offsets[0] + code.byteCount();
    var hookMap = offset + 4 + Exe.GetInt32(offset);

    //Step 4.1 - Find Free space for insertion considering max size
    funcName = "GetShieldID\x00";
    free = Exe.FindSpace(funcName.length + 0x5 + 0x3D + 0x4);
    if (free === -1)
        return "Failed in Part 4 - Not enough free space";

    //Step 4.2 - Construct code
    code =
        Ascii2Hex(funcName)
    +   " 52"               //PUSH EDX
    +   " 8B 54 24 08"      //MOV EDX, DWORD PTR SS:[ESP+8]
    ;
    code += GenLuaCaller(free + code.byteCount(), funcName, Exe.Real2Virl(free, DIFF), "d>d", " 52");
    code +=
        " 5A"            //POP EDX
    +   " C2 04 00"      //RETN 4
    ;
    //Step 4.3 - Insert the code into free space
    Exe.InsertHex(free, code, code.byteCount());

    //Step 4.4 - Create a JMP at hookMap to the code
    Exe.ReplaceHex(hookMap, "E9" + Num2Hex(Exe.Real2Virl(free + funcName.length, DIFF) - Exe.Real2Virl(hookMap + 5, CODE)));

    //Step 5.1 - Find PUSH 5 before hookReq and replace with MaxShield if its there
    code =
        " 50"    //PUSH EAX
    +   " 6A 05" //PUSH 5
    +   " 8B"    //MOV ECX, reg32_A
    ;
    offset = Exe.FindHex(code, hookReq - 0x30, hookReq);

    if (offset !== -1)
    {
        Exe.ReplaceHex(offset + 2, Num2Hex(MaxShield, 1));
    }
    else {
        //Step 5.2 - Find Register assignment to 5 and replace with MaxShield
        code =
            " 05 00 00 00" //MOV reg32_A, 5
        +   " 2B"          //SUB reg32_A, reg32_B
        ;

        offset = Exe.FindHex(code, hookReq - 0x60, hookReq);
        if (offset === -1)
            return "Failed in Step 5 - No Allocator PUSHes found";

        Exe.ReplaceHex(offset, Num2Hex(MaxShield));

        //Step 5.3 - Find EAX comparison with 5 before assignment and replace with MaxShield
        code =
            " 83 F8 05" //CMP EAX, 5
        +   " 73"       //JAE SHORT addr
        ;

        offset = Exe.FindHex(code, offset - 0x10, offset);
        if (offset === -1)
            return "Failed in Step 5 - Comparison Missing";

        Exe.ReplaceHex(offset + 2, Num2Hex(MaxShield, 1));
    }
    return true;
}