//############################################################################\\
//# Modify the Aura setting code inside CPlayer::ReLaunchBlurEffects to CALL #\\
//# custom function which sets up aura based on user specified limits        #\\
//############################################################################\\

function CustomAuraLimits()
{
    //Step 1.1 - Find the 2 value PUSHes before ReLaunchBlurEffects is called.
    var code =
        " 68 4E 01 00 00" //PUSH 14E
    +   " 6A 6D"          //PUSH 6D
    ;

    var offset = Exe.FindHex(code);
    if (offset === -1)
        return "Failed in Step 1 - Value PUSHes missing";

    //Step 1.2 - Update offset to point to the location after the PUSHes
    offset += code.byteCount();

    //Step 1.3 - Find the call below it
    code =
        " 8B ?? ?? 00 00 00" //MOV reg32_A, DWORD PTR DS:[reg32_B+const]
    +   " 8B ?? ??"          //MOV ECX, DWORD PTR DS:[reg32_A+const2]
    +   " E8 ?? ?? ?? 00"    //CALL CPlayer::ReLaunchBlurEffects
    ;

    var offset2 = Exe.FindHex(code, offset, offset + 0x100);
    if (offset2 === -1)
        return "Failed in Step 1 - ReLaunchBlurEffects call missing";

    //Step 1.4 - Update offset2 to point to the location after the CALL
    offset2 += code.byteCount();

    //Step 1.5 - Extract the REAL address of ReLaunchBlurEffects
    offset = offset2 + Exe.GetInt32(offset2 - 4);

    //Step 2.1 - Find the first JE inside the function
    offset = Exe.FindHex(" 0F 84 ?? ?? 00 00", offset, offset + 0x80);
    if (offset === -1)
        return "Failed in Step 2 - First JE missing";

    //Step 2.2 - Save the Raw location
    var cmpEnd = (offset + 6) + Exe.GetInt32(offset + 2);

    //Step 2.3 - Find PUSH 2E2 after it (only there in 2010+)
    offset = Exe.FindHex(" 68 E2 02 00 00", offset + 6, offset + 0x100);
    if (offset === -1)
        return "Failed in Step 2 - 2E2 push missing";

    //Step 2.4 - Now find the JE after it
    offset = Exe.FindHex(" 0F 84 ?? ?? 00 00", offset + 5, offset + 0x80);
    if (offset === -1)
        return "Failed in Step 2 - JE missing";

    //Step 2.5 - Save the Raw location
    var cmpBegin = (offset + 6) + Exe.GetInt32(offset + 2);

    ///---------------------------------------------------------------------
    /// Now we Check for the comparison style.
    ///   Old Clients directly compare there itself.
    ///   New Clients do it in a seperate function (by New i mean 2013+)
    ///---------------------------------------------------------------------

    if (Exe.GetUint8(cmpBegin) === 0xB9) //MOV ECX, g_session ; Old Style
    {
        var directComparison = true;

        //Step 3.1 - Extract g_session and job Id getter addresses
        var gSession = Exe.GetInt32(cmpBegin + 1);
        var jobIdFunc = Exe.Real2Virl(cmpBegin + 10, CODE) + Exe.GetInt32(cmpBegin + 6);

        //Step 3.2 - Find the Level address comparison
        code = " A1 ?? ?? ?? 00"; //MOV EAX, DWORD PTR DS:[g_level] ; EAX is later compared with 96
        offset = Exe.FindHex(code, cmpBegin, cmpBegin + 0x20);

        if (offset === -1)
        {
            code = " 81 3D ?? ?? ?? 00"; //CMP DWORD PTR DS:[g_level], 96
            offset = Exe.FindHex(code, cmpBegin, cmpBegin + 0x80);
        }
        if (offset === -1)
            return "Failed in Step 3 - Level Comparison missing";

        //Step 3.3 - Update offset to location after the instruction
        offset += code.byteCount();

        //Step 3.4 - Extract g_level address
        var gLevel = Exe.GetInt32(offset - 4);

        //Step 3.5 - Find the Aura Displayer Call (its a reg call so dunno the name of the function)
        code =
            " 6A ??" //PUSH auraconst
        +   " 6A 00" //PUSH 0
        +   " 8B CE" //MOV ECX, ESI
        +   " FF"    //CALL reg32 or CALL DWORD PTR DS:[reg32+8]
        ;
        var argPush = "6A 00";
        var offset2 = Exe.FindHex(code, offset, offset + 0x20);

        if (offset2 === -1)
        {
            code = code.replace("6A 00", "??");//swap PUSH 0 with PUSH reg32_B
            argPush = "";
            offset2 = Exe.FindHex(code, offset, offset + 0x20);
        }
        if (offset2 === -1)
            return "Failed in Step 3 - Aura Call missing";

        //Step 3.6 - Extract the PUSH reg32_B
        if (argPush === "")
            argPush = Exe.GetHex(offset2 + 2, 1);

        //Step 3.7 - Extract the aura constant
        var gAura = [Exe.GetHex(offset2 + 1, 1)];
        gAura[1] = gAura[2] = gAura[0];//Same value is used for All Auras - and therefore shows only 1 type of aura per job

        //Step 3.8 - Get the number of zero PUSHes before PUSH auraconst (it differs for some dates)
        var count = argPush.byteCount();
        argPush = Exe.GetHex(offset2 - 4 * count, 4 * count);

        if (argPush.substr(0, 3 * count) === argPush.substr(9 * count)) //First and Last is same means there are actually 4 PUSHes
            count = 4;
        else
            count = 3;

        //Step 3.9 - Setup ZeroAssign variable
        var zeroAssign =
            " EB 08"    //JMP SHORT addr  ;addr is after MOV EAX, EAX below
        +   " 8D 24 24" //LEA ESP, [ESP]  ;These are
        +   " 8D 6D 00" //LEA EBP, [EBP]  ;never
        +   " 89 C0"    //MOV EAX, EAX    ;executed
        ;
    }
    else //MOV reg16, WORD PTR DS:[g_level] ; New Style - comparisons are done inside a seperate function
    {
        var directComparison = false;

        //Step 4.1 - Extract g_level address
        var gLevel = Exe.GetInt32(cmpBegin + 3);

        //Step 4.2 - Find the comparison function call
        offset = Exe.FindHex(" E8 ?? ?? ?? FF", cmpBegin, cmpBegin + 0x30);
        if (offset === -1)
            return "Failed in Step 4 - Function call missing";

        //Step 4.3 - Go inside the function
        offset = (offset + 5) + Exe.GetInt32(offset + 1);

        //Step 4.4 - Find g_session assignment
        code =
            " E8 ?? ?? ?? ??" //CALL jobIdFunc
        +   " 50"             //PUSH EAX
        +   " B9 ?? ?? ?? 00" //MOV ECX, g_session
        +   " E8"             //CALL addr
        ;

        offset = Exe.FindHex(code, offset, offset + 0x20);
        if (offset === -1)
            return "Failed in Step 4 - g_session reference missing";

        //Step 4.5 - Extract job Id getter address (we dont need the gSession for this one)
        var jobIdFunc = Exe.Real2Virl(offset + 5, CODE) + Exe.GetInt32(offset + 1);

        //Step 4.6 - Find the Zero assignment at the end of the function
        code = " C7 86 ?? ?? 00 00 00 00 00 00"; //MOV DWORD PTR DS:[ESI + const], 0
        offset = Exe.FindHex(code, offset, offset + 0x180);

        if (offset === -1)
            return "Failed in Step 4 - Zero assignment missing";

        //Step 4.7 - Save it (only needed for new types)
        var zeroAssign = Exe.GetHex(offset, code.byteCount());

        //Step 4.8 - Setup the Aura constants and Arg count
        var count = 4;
        var gAura = [" 7D", " 93", " 92"];
    }

    //Step 5.1 - Get the input file
    var inp = MakeFile('$auraSpec', "File Input - Custom Aura Limits", "Enter the Aura Spec file", APP_PATH + "Inputs/auraSpec.txt");
    if (!inp)
        return "Patch Cancelled";

    //Step 5.2 - Load the ID and Level Limits to a table
    var idLvlTable = [];
    var tblSize = 0;
    var index = -1;
    while (!inp.IsEOF())
    {
        //Step 5.2.1 - Read a Line
        var line = inp.ReadLine().trim();
        if (line === "")
            continue;

        //Step 5.2.2 - Look for Job Id Range line with the format  "id1 - id2, id3 - id4 ...."
        if (matches = line.match(/^([\d\-,\s]+):$/))
        {
            //Step 5.2.3 - Create a New Entry in the table
            index++;
            var idSet = matches[1].split(",");
            idLvlTable[index] = {
                "idTable":"",
                "lvlTable":""
            };

            //Step 5.2.4 - Add End of Field marker for previous Entry (-1 in Int16)
            if (index > 0)
            {
                idLvlTable[index-1].lvlTable += " FF FF";
                tblSize += 2;
            }

            for (var i = 0; i < idSet.length; i++)
            {
                //Step 5.2.5 - Split and extract the IDs (if only single ID is there use it as both lower and upper)
                var limits = idSet[i].split("-");
                if (limits.length === 1)
                    limits[1] = limits[0];

                //Step 5.2.6 - Add the 2 Limits to the idTable member
                idLvlTable[index].idTable += Num2Hex(parseInt(limits[0]), 2);
                idLvlTable[index].idTable += Num2Hex(parseInt(limits[1]), 2);
                tblSize += 4;
            }

            //Step 5.2.7 - Add End of Field marker for idTable
            idLvlTable[index].idTable += " FF FF";
            tblSize += 2;
        }
        //Step 5.2.8 - Look for the line with the format "Level1 - Level2 => AuraIndex"
        else if (matches = line.match(/^([\d\-\s]+)\s*=>\s*(\d)\s*,/))
        {
            //Step 5.2.9 - Extract the two levels and the Aura Index (index to gAura array)  & add them to lvlTable
            var limits = matches[1].split("-");

            idLvlTable[index].lvlTable += Num2Hex(parseInt(limits[0]), 2);
            idLvlTable[index].lvlTable += Num2Hex(parseInt(limits[1]), 2);
            idLvlTable[index].lvlTable += gAura[parseInt(matches[2])-1];
            tblSize += 5;
        }
    }

    //Step 5.3 - Close the file
    inp.Close();

    //Step 5.4 - Add End of Field Marker for the last lvlTable
    if (index >= 0)
    {
        idLvlTable[index].lvlTable += " FF FF";
        tblSize += 2;
    }

    //Step 6.1 - Prepare code to insert (for reading the table and compare against Base level and Job ID)
    code =
        " 56"                   //PUSH ESI
    +   " 89 CE"                //MOV ESI, ECX
    +   " 52"                   //PUSH EDX
    +   " 53"                   //PUSH EBX
    +   " B9" + MakeVar(1)      //MOV ECX, g_session
    +   " E8" + MakeVar(2)      //CALL jobIdFunc
    +   " BB" + MakeVar(3)      //MOV EBX, tblAddr
    +   " 8B 0B"                //MOV ECX, DWORD PTR DS:[EBX];	addr6
    +   " 85 C9"                //TEST ECX, ECX
    +   " 74 49"                //JE SHORT addr1
    +   " 0F BF 11"             //MOVSX EDX, WORD PTR DS:[ECX];	addr5
    +   " 85 D2"                //TEST EDX, EDX
    +   " 78 15"                //JS SHORT addr2
    +   " 39 D0"                //CMP EAX, EDX
    +   " 7C 0C"                //JL SHORT addr3
    +   " 0F BF 51 02"          //MOVSX EDX, WORD PTR DS:[ECX+2]
    +   " 85 D2"                //TEST EDX,EDX
    +   " 78 09"                //JS SHORT addr2
    +   " 39 D0"                //CMP EAX,EDX
    +   " 7E 0A"                //JLE SHORT addr4
    +   " 83 C1 04"             //ADD ECX, 4;	addr3
    +   " EB E4"                //JMP SHORT addr5
    +   " 83 C3 08"             //ADD EBX, 8;	addr2
    +   " EB D9"                //JMP SHORT addr6
    +   " A1" + MakeVar(4)      //MOV EAX, DWORD PTR DS:[g_level];	addr4
    +   " 8B 4B 04"             //MOV ECX, DWORD PTR DS:[EBX+4]
    +   " 85 C9"                //TEST ECX, ECX
    +   " 74 1C"                //JE SHORT addr1
    +   " 0F BF 11"             //MOVSX EDX, WORD PTR DS:[ECX];	addr9
    +   " 85 D2"                //TEST EDX, EDX
    +   " 78 15"                //JS SHORT addr1
    +   " 39 D0"                //CMP EAX, EDX
    +   " 7C 0C"                //JL SHORT addr7
    +   " 0F BF 51 02"          //MOVSX EDX, WORD PTR DS:[ECX+2]
    +   " 85 D2"                //TEST EDX, EDX
    +   " 78 09"                //JS SHORT addr1
    +   " 39 D0"                //CMP EAX, EDX
    +   " 7E 14"                //JLE SHORT addr8
    +   " 83 C1 05"             //ADD ECX, 5;	addr7
    +   " EB E4"                //JMP SHORT addr9
    +   " 5B"                   //POP EBX; addr1
    +   " 5A"                   //POP EDX
    +   zeroAssign              //MOV DWORD PTR DS:[ESI+const], 0 (or Dummy)
    +   " 5E"                   //POP ESI
    +   " C3"                   //RETN
    +   " 90"                   //NOP
    +   " 5B"                   //POP EBX; addr8
    +   " 5A"                   //POP EDX
    +   " 6A 00".repeat(count)  //PUSH 0
                                //PUSH 0
                                //PUSH 0
                                //PUSH 0 - May or may not be there
    +   " 0F B6 49 04"          //MOVZX ECX,BYTE PTR DS:[ECX+4]; addr8
    +   " 51"                   //PUSH ECX
    +   " 6A 00"                //PUSH 0
    +   " 8B 06"                //MOV EAX,DWORD PTR DS:[ESI]
    +   " 8B CE"                //MOV ECX,ESI
    +   " FF 50 08"             //CALL DWORD PTR DS:[EAX+8]
    +   " 5E"                   //POP ESI
    +   " C3"                   //RETN
    ;
    if (!directComparison)
        code = code.replace("B9" + MakeVar(1), "90 90 90 90 90");

    //Step 6.2 - Find Free space for insertion
    var size = code.byteCount() + 8 * idLvlTable.length + 4 + tblSize;
    var free = Exe.FindSpace(size);
    if (free === -1)
        return "Failed in Step 6 - Not enough free space";

    var freeVirl = Exe.Real2Virl(free, DIFF);

    //Step 6.3 - Fill in the blanks
    code = SetValue(code, 1, gSession);
    code = SetValue(code, 2, jobIdFunc - (freeVirl + 15));
    code = SetValue(code, 3, freeVirl + code.byteCount());
    code = SetValue(code, 4, gLevel);

    //Step 6.4 - Construct the table pointers & limits to insert
    var tblAddrData = "";
    var tblData = "";
    for (var i = 0, addr = size - tblSize; i < idLvlTable.length; i++)
    {
        //Step 6.4.1 - Add the ID Table
        tblAddrData += Num2Hex(freeVirl + addr);
        tblData += idLvlTable[i].idTable;
        addr += idLvlTable[i].idTable.byteCount();

        //Step 6.4.2 - Add the Level Table
        tblAddrData += Num2Hex(freeVirl + addr);
        tblData += idLvlTable[i].lvlTable;
        addr += idLvlTable[i].lvlTable.byteCount();
    }

    //Step 9.1 - Insert the function and table data at free space
    Exe.InsertHex(free, code + tblAddrData + " 00 00 00 00" + tblData, size);

    if (directComparison)
    {
        //Step 8.2 - Since there was no existing Function CALL, We add a CALL to our function after ECX assignment
        code =
            " 8B CE"                                                       //MOV ECX, ESI
        +   " E8" + Num2Hex(freeVirl - Exe.Real2Virl(cmpBegin + 7, CODE)) //CALL func
        +   " EB" + Num2Hex(cmpEnd - (cmpBegin + 9))                       //JMP SHORT cmpEnd
        ;

        Exe.ReplaceHex(cmpBegin, code);
    }
    else
    {
        //Step 8.3 - Find the function call... again and replace it with a CALL to our Function
        offset = Exe.FindHex(" E8 ?? ?? ?? FF", cmpBegin, cmpBegin + 0x30);
        Exe.ReplaceInt32(offset + 1, freeVirl - Exe.Real2Virl(offset + 5));

        //Step 8.4 - Update offset to location after the CALL
        offset += 5;

        //Step 8.5 - Fill with NOPs till cmpEnd
        if (offset < cmpEnd)
            Exe.ReplaceHex(offset, " 90".repeat(cmpEnd - offset));
    }
    return true;
}