//######################################################################\\
//# Modify the Exp Bar Displayer code inside UIBasicInfoWnd::NewHeight #\\
//# to display Job & Base Exp Bars based on user specified limits      #\\
//######################################################################\\

function CustomExpBarLimits()
{
    //Step 1.1 - Find the reference PUSHes (coord PUSHes ?)
    var code =
        " 6A 4E"          //PUSH 4E
    +   " 68 38 FF FF FF" //PUSH -0C8
    ;

    var refOffsets = Exe.FindAllHex(code);
    if (refOffsets.length === 0)
        return "Failed in Step 1 - Reference PUSHes missing";

    //Step 1.2 - Find the Job ID getter before the first reference
    code =
        " B9 ?? ?? ?? 00" //MOV ECX, OFFSET g_session
    +   " E8 ?? ?? ?? 00" //CALL CSession::jobIdFunc
    +   " 50"             //PUSH EAX
    +   " B9 ?? ?? ?? 00" //MOV ECX, OFFSET g_session
    +   " E8 ?? ?? ?? 00" //CALL CSession::isThirdJob
    ;

    var suffix =
        " 85 C0"          //TEST EAX, EAX
    +   " A1 ?? ?? ?? 00" //MOV EAX, DWORD PTR DS:[g_level]
    +   " BF 63 00 00 00" //MOV EDI, 63
    ;
    var type = 1;//VC6 style
    var offset = Exe.FindHex(code + suffix, refOffsets[0] - 0x120, refOffsets[0]);

    if (offset === -1)
    {
        suffix =
            " 8B 8E ?? 00 00 00" //MOV ECX, DWORD PTR DS:[ESI+const]
        +   " BF 63 00 00 00"    //MOV EDI, 63
        +   " 85 C0"             //TEST EAX, EAX
        ;
        type = 2;//VC9 style 1
        offset = Exe.FindHex(code + suffix, refOffsets[0] - 0x120, refOffsets[0]);
    }
    if (offset === -1)
    {
        suffix = suffix.replace(" 8B 8E ?? 00 00 00", "");
        type = 3;//VC9 style 2
        offset = Exe.FindHex(code + suffix, refOffsets[0] - 0x120, refOffsets[0]);
    }
    if (offset === -1)
        return "Failed in Step 1 - Comparison setup missing";

    //Step 1.3 - Extract g_session, jobIdFunc and save the offset to baseBegin variable
    var gSession = Exe.GetInt32(offset + 1);
    var jobIdFunc = Exe.Real2Virl(offset + 10, CODE) + Exe.GetInt32(offset + 6);
    var baseBegin = offset;

    offset += code.byteCount() + suffix.byteCount();

    //Step 1.4 - Extract the base level comparison (for VC9+ clients we need to find the comparison after offset)
    if (type === 1)
    {
        var gLevel = Exe.GetInt32(offset - 9);
    }
    else
    {
        var code2 = " 81 3D ?? ?? ?? 00 ?? 00 00 00"; //CMP DWORD PTR DS:[g_level], value
        var offset2 = Exe.FindHex(code2, offset, refOffsets[0]);

        if (offset2 === -1)
        {
            code2 =
                " 39 3D ?? ?? ?? 00" //CMP DWORD PTR DS:[g_level], EDI
            +   " 75"                //JE SHORT addr
            ;
            offset2 = Exe.FindHex(code2, offset, refOffsets[0]);
        }
        if (offset2 === -1)
            return "Failed in Step 1 - First comparison missing";

        var gLevel = Exe.GetInt32(offset2 + 2);
    }

    //Step 2.1 - Find the ESI+const movement to ECX between baseBegin and first reference offset
    offset = Exe.FindHex("8B 8E ?? 00 00 00", baseBegin, refOffsets[0]);//MOV ECX, DWORD PTR DS:[ESI+const]
    if (offset === -1)
        return "Failed in Step 2 - First ESI Offset missing";

    //Step 2.2 - Extract the gNoBase and calculate other two
    var gNoBase = Exe.GetInt32(offset + 2);
    var gNoJob = gNoBase + 4;
    var gBarOn = gNoBase + 8;

    //Step 2.3 - Extract ESI offset and baseEnd
    if (Exe.GetUint8(refOffsets[1] + 8) >= 0xD0)
    {
        var funcOff = Exe.GetInt8(refOffsets[1] - 1);
        var baseEnd = (refOffsets[1] + 11) + Exe.GetInt8(refOffsets[1] + 10);
    }
    else
    {
        var funcOff = Exe.GetInt8(refOffsets[1] + 9);
        var baseEnd = (refOffsets[1] + 12) + Exe.GetInt8(refOffsets[1] + 11);
    }

    //Step 2.4 - jobBegin is same as baseEnd
    var jobBegin = baseEnd;

    //Step 3.1 - Find the PUSHes for Job Exp bar
    code =
        " 6A 58"          //PUSH 58
    +   " 68 38 FF FF FF" //PUSH -0C8
    ;

    var refOffsets2 = Exe.FindAllHex(code, jobBegin, jobBegin + 0x120);
    if (refOffsets2.length === 0)
        return "Failed in Step 3 - 2nd Reference PUSHes missing";

    //Step 3.2 - Find jobEnd (JMP after the last PUSH will lead to jobEnd)
    offset = refOffsets2[refOffsets2.length - 1] + code.byteCount();

    if (Exe.GetUint8(offset) === 0xEB)
        offset = (offset + 2) + Exe.GetInt8(offset + 1);

    if (Exe.GetUint8(offset + 1) >= 0xD0) //FF D0 (CALL reg) or FF 5# 1# CALL DWORD PTR DS:[reg + 1#]
        var jobEnd = offset + 2;
    else
        var jobEnd = offset + 3;

    //Step 3.3 - Find g_jobLevel reference between the 2nd reference set
    code = "83 3D ?? ?? ?? 00 0A"; //CMP DWORD PTR DS:[g_jobLevel], 0A

    offset = Exe.FindHex(code, refOffsets2[0], refOffsets2[refOffsets2.length - 1]);
    if (offset === -1)
        return "Failed in Step 3 - g_jobLevel reference missing";

    //Step 3.4 - Extract g_jobLevel
    var gJobLevel = Exe.GetInt32(offset + 2);

    //Step 4.1 - Get the input file
    var inpFile = Exe.GetUserInput("$expBarSpec", I_FILE, "File Input - Custom Exp Bar Limits", "Enter the Exp Bar Spec file", APP_PATH + "Inputs/expBarSpec.txt");
    if (!inpFile)
        return "Patch Cancelled";

    //Step 4.2 - Extract table from the file
    var idLvlTable = [];
    var tblSize = 0;
    var index = -1;

    var Fp = new File();
    Fp.Open(inpFile, 'r');

    while (!Fp.IsEOF())
    {
        var line = Fp.ReadLine().trim();
        if (!line)
            continue;

        var matches;
        if (matches = line.match(/^([\d\-,\s]+):$/))
        {
            index++;
            var idSet = matches[1].split(",");
            idLvlTable[index] =
            {
                "idTable": "",
                "lvlTable": [" FF 00", " FF 00"]
            };

            for (var i = 0; i < idSet.length; i++)
            {
                var limits = idSet[i].split("-");
                if (limits.length === 1)
                    limits[1] = limits[0];

                idLvlTable[index].idTable += Num2Hex(parseInt(limits[0]), 2)
                idLvlTable[index].idTable += Num2Hex(parseInt(limits[1]), 2);
                tblSize += 4;
            }

            idLvlTable[index].idTable += " FF FF";
            tblSize += 2;
        }
        else if (matches = line.match(/^([bj])\s*=>\s*(\d+)\s*,/))
        {
            var limit = Num2Hex(parseInt(matches[2]), 2);

            if (matches[1] === "b") {
                idLvlTable[index].lvlTable[0] = limit;
            }
            else {
                idLvlTable[index].lvlTable[1] = limit;
            }
        }
    }
    Fp.Close();

    //Step 5.1 - Prep code to replace at baseBegin
    code =
        " 52"                  //PUSH EDX
    +   " 53"                  //PUSH EBX
    +   " B9" + MakeVar(1)     //MOV ECX, g_session
    +   " E8" + MakeVar(2)     //CALL CSession::jobIdFunc
    +   " BB" + MakeVar(3)     //MOV EBX, tblAddr
    +   " 8B 0B"               //MOV ECX, DWORD PTR DS:[EBX];	addr6
    +   " 85 C9"               //TEST ECX, ECX
    +   " 74 26"               //JE SHORT addr1
    +   " 0F BF 11"            //MOVSX EDX, WORD PTR DS:[ECX];	addr5
    +   " 85 D2"               //TEST EDX, EDX
    +   " 78 15"               //JS SHORT addr2
    +   " 39 D0"               //CMP EAX, EDX
    +   " 7C 0C"               //JL SHORT addr3
    +   " 0F BF 51 02"         //MOVSX EDX, WORD PTR DS:[ECX+2]
    +   " 85 D2"               //TEST EDX, EDX
    +   " 78 09"               //JS SHORT addr2
    +   " 39 D0"               //CMP EAX, EDX
    +   " 7E 0A"               //JLE SHORT addr4
    +   " 83 C1 04"            //ADD ECX, 4;	addr3
    +   " EB E4"               //JMP SHORT addr5
    +   " 83 C3 08"            //ADD EBX, 8;	addr2
    +   " EB D9"               //JMP SHORT addr6
    +   " 8D 7B 04"            //LEA EDI, [EBX+4]; addr4
    +   " EB 05"               //JMP SHORT addr7
    +   " BF" + MakeVar(4)     //MOV EDI, OFFSET defAddr; addr1
    +   " 5B"                  //POP EBX; addr7
    +   " 5A"                  //POP EDX
    +   " 0F B7 07"            //MOVZX EAX, WORD PTR DS:[EDI]
    +   " 39 05" + MakeVar(5)  //CMP DWORD PTR DS:[g_level], EAX
    +   " 8B 8E" + MakeVar(6)  //MOV ECX, DWORD PTR DS:[ESI + gNoBase]
    +   " 7C 09"               //JL SHORT addr8
    +   " 6A 4E"               //PUSH 4E
    +   " 68 38 FF FF FF"      //PUSH -0C8
    +   " EB 0C"               //JMP SHORT addr9
    +   " 8B 86" + MakeVar(7)  //MOV EAX, DWORD PTR DS:[ESI + gBarOn]; addr8
    +   " 83 C0 4C"            //ADD EAX, 4C
    +   " 50"                  //PUSH EAX
    +   " 6A 55"               //PUSH 55
    +   " 8B 01"               //MOV EAX, DWORD PTR DS:[ECX]; addr9
    +   " FF 50 XX"            //CALL DWORD PTR DS:[EAX + funcOff]
    +   " 0F B7 47 02"         //MOVZX EAX, WORD PTR DS:[EDI+2]
    +   " 39 05" + MakeVar(8)  //CMP DWORD PTR DS:[g_jobLevel], EAX
    +   " 8B 8E" + MakeVar(9)  //MOV ECX, DWORD PTR DS:[ESI + gNoJob]
    +   " 7C 09"               //JL SHORT addr10
    +   " 6A 58"               //PUSH 58
    +   " 68 38 FF FF FF"      //PUSH -0C8
    +   " EB 0C"               //JMP SHORT addr11
    +   " 8B 86" + MakeVar(7)  //MOV EAX, DWORD PTR DS:[ESI + gBarOn]; addr10
    +   " 83 C0 58"            //ADD EAX, 58
    +   " 50"                  //PUSH EAX
    +   " 6A 55"               //PUSH 55
    +   " 8B 01"               //MOV EAX, DWORD PTR DS:[ECX]; addr11
    +   " FF 50 XX"            //CALL DWORD PTR DS:[EAX + funcOff]
    +   " E9" + MakeVar(10)    //JMP jobEnd
    ;

    //Step 5.2 - Find Free space for insertion of table
    var free = Exe.FindSpace(tblSize);
    if (free === -1)
        return "Failed in Step 5 - Not enough free space";

    //Step 5.3 - Setup tblAddr
    var freeRva = Exe.Real2Virl(free, DIFF);
    var tblAddr = baseBegin + code.byteCount() + 4;

    //Step 5.4 - Fill in the blanks
    code = code.replace(/ XX/g, Num2Hex(funcOff, 1));

    code = SetValue(code, 1, gSession);
    code = SetValue(code, 2, jobIdFunc - Exe.Real2Virl(baseBegin + 12));

    code = SetValue(code, 3, Exe.Real2Virl(tblAddr));
    code = SetValue(code, 4, Exe.Real2Virl(tblAddr - 4));//defAddr = tblAddr - 4

    code = SetValue(code, 5, gLevel);
    code = SetValue(code, 6, gNoBase);
    code = SetValue(code, 7, gBarOn, 2); //Change in two places
    code = SetValue(code, 8, gJobLevel);
    code = SetValue(code, 9, gNoJob);

    code = SetValue(code, 10, jobEnd - (baseBegin + code.byteCount()));

    //Step 6.1 - Construct the table pointers & limits to insert
    var tblAddrData = "";
    var tblData = "";

    for (var i = 0, addr = 0; i < idLvlTable.length; i++)
    {
        tblAddrData += Num2Hex(freeRva + addr);
        tblData += idLvlTable[i].idTable;
        addr += idLvlTable[i].idTable.byteCount();

        tblAddrData += idLvlTable[i].lvlTable.join("");
    }

    //Step 6.2 - Replace the function at baseBegin
    Exe.ReplaceHex(baseBegin, code + " FF 00 FF 00" + tblAddrData);

    //Step 6.3 - Insert the table at free space.
    Exe.InsertHex(free, tblData, tblSize);
    return true;
}