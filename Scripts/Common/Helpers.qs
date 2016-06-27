//#######################################################\\
//# Get the filename from user and create a File object #\\
//# (text mode) using the name.                         #\\
//#######################################################\\

function MakeFile(varName, title, msg, defName)
{
    var inpFile = Exe.GetUserInput(varName, I_FILE, title, msg, defName);
    if (!inpFile)
        return false;
    
    var f = new File();
    f.Open(inpFile, 'r');
    
    return f;
}

//###################################################\\
//# Make a Filler String for use in Insert Codes.   #\\
//# Pattern: ?? ?? ?? ## where ## is a Uint8 in Hex #\\
//###################################################\\

function MakeVar(index)
{
    var prefix = " ?? ?? ?? ";
    if (index < 16);
        prefix += '0';

    return (prefix + index.toString(16).toUpperCase());
}

//###################################################################################\\
//# Substitute the Filler String generated from MakeVar with actual value provided. #\\
//# value is expected to be a LE Hex string. if its a number it is converted to LE. #\\
//###################################################################################\\

function SetValue(code, index, value, count)
{
    if (typeof(value) == "number")
        value = Num2Hex(value);

    if (typeof(count) !== "number")
        count = 1;

    var pattern = MakeVar(index);
    for ( ;count > 0 && code.indexOf(pattern) >= 0; count--)
    {
        code = code.replace(pattern, value);
    }
    return code;
}

//##################################################################################\\
//# Same as above but does multiple variable substitutions instead of just one var #\\
//##################################################################################\\

function SetValues(code, indexList, valueList, count)
{
    for (var i = 0; i < indexList.length; i++)
    {
        code = SetValue(code, indexList[i], valueList[i], count);
    }
    return code;
}

//####################################################\\
//# Extract the g_serviceType address from Client in #\\
//# Little Endian Format into Input Hash Array       #\\
//####################################################\\

function GetLangType(hash)
{
    //Step 1.1 - Find the string "america"
    var offset = Exe.FindString("america", VIRTUAL);
    if (offset === -1)
    {
        hash.Error = "String 'america' missing";
        return;
    }

    //Step 1.2 - Find its reference
    offset = Exe.FindHex("68" + Num2Hex(offset)); //PUSH OFFSET addr; ASCII "america"
    if (offset === -1)
    {
        hash.Error = "String reference missing";
        return;
    }

    //Step 2.1 - Look for the g_serviceType assignment to 1 after the PUSH. Langtype value
    //           overrides Service settings hence they use the same variable i.e. g_serviceType
    offset = Exe.FindHex("C7 05 ?? ?? ?? 00 01 00 00 00", offset + 5);
    if (offset === -1)
    {
        hash.Error = "g_serviceType assignment missing";
        return;
    }

    //Step 2.2 - Extract and return
    hash.Error = false;
    hash.Value = Exe.GetUint32(offset + 2);
    hash.Hex = Num2Hex(hash.Value);
}

//###########################################################\\
//# Returns true if Frame Pointer is used inside Functions. #\\
//# i.e. Stack is referenced w.r.t. EBP instead of ESP      #\\
//###########################################################\\

function HasFramePointer()
{
    //Fastest way to check - First 3 bytes of CODE Section would be PUSH EBP and MOV EBP, ESP
    return (Exe.GetHex(Exe.GetRealOffset(CODE), 3) === " 55 8B EC");
}

//#######################################################################\\
//# Extract g_windowMgr assignment & address of UIWindowMgr::MakeWindow #\\
//# function into Input Hash array                                      #\\
//#######################################################################\\

function GetWinMgrData(hash)
{
    //Step 1.1 - Find offset of NUMACCOUNT
    var offset = Exe.FindString("NUMACCOUNT", VIRTUAL);
    if (offset === -1)
    {
        hash.Error = "NUMACCOUNT missing";
        return;
    }

    //Step 1b - Find its reference which comes after a Window Manager call
    var code =
        " B9 ?? ?? ?? 00"       //MOV ECX, OFFSET g_windowMgr
    +   " E8 ?? ?? ?? FF"       //CALL UIWindowMgr::MakeWindow
    +   " 6A 00"                //PUSH 0
    +   " 6A 00"                //PUSH 0
    +   " 68" + Num2Hex(offset) //PUSH addr; ASCII "NUMACCOUNT"
    ;

    offset = Exe.FindHex(code);
    if (offset === -1)
    {
        hash.Error = "NUMACCOUNT reference missing";
    }
    else
    {
        hash.MovEcx = Exe.GetHex(offset, 5);
        hash.MakeWin = Exe.GetInt32(offset + 6) + Exe.Real2Virl(offset + 10, CODE);
        hash.Error = false;
    }
}

//##################################################\\
//# Check whether client is Renewal or Main client #\\
//##################################################\\

function IsRenewal()
{
    return (Exe.FindString("rdata.grf", REAL) !== -1);
}

//########################################################################
//# Extract the 3 Packet Keys used for Header Obfuscation/Encryption and #
//# address of the function that assigns them into ECX+4, ECX+8, ECX+0C  #
//# In case the keys are unobtainable then we use clientdate - keys map. #
//########################################################################

function GetPacketKeyData(hash)
{
    //Step 1.1 - Find "PACKET_CZ_ENTER"
    var offset = Exe.FindString("PACKET_CZ_ENTER", VIRTUAL);

    //Step 1.2 - Find its reference
    if (offset !== -1)
        offset = Exe.FindHex("68" + Num2Hex(offset));

    if (offset === -1)
    {   //For recent clients this is no longer present.
        //Step 1.3 - Look for the reference pattern usually present after PACKET_CZ_ENTER push if it was there.
        var template =
            " E8 ?? ?? ?? ??"   //MOV CRagConnection::instanceR
        +   " 8B C8"            //MOV ECX, EAX
        +   " E8 ?? ?? ?? ??"   //CALL func
        ;

        var code =
            template    //func = CRagConnection::GetPacketSize
        +   " 50"       //MOV ECX, EAX
        +   template    //func = CRagConnection::SendPacket
        +   " 6A 01"    //PUSH 1
        +   template    //func = CConnection::SetBlock
        +   " 6A 06"    //PUSH 6
        ;
        offset = Exe.FindHex(code);
    }

    if (offset === -1)
    {
        hash.Error = "PK: Failed to find any reference locations";
        return;
    }

    //Step 2.1 - Look for Type 0 Pattern (Keys pushed to function)
    var code =
        " 8B 0D ?? ?? ?? 00" //MOV ECX, DWORD PTR DS:[refAddr]
    +   " 68 ?? ?? ?? ??"    //PUSH key3
    +   " 68 ?? ?? ?? ??"    //PUSH key2
    +   " 68 ?? ?? ?? ??"    //PUSH key1
    +   " E8"                //CALL CRagConnection::Obfuscate ; We will call it this for the time being
    ;

    var offset2 = Exe.FindHex(code, offset - 0x100, offset);
    if (offset2 !== -1)
    {
        //Step 2.2 - Since it matched set the Type & save the ECX assignment,
        hash.Type = 0;
        hash.MovEcx = Exe.GetHex(offset2, 6);

        //Step 2.3 - Update offset2 to location where CALL is made
        offset2 += code.byteCount();

        //Step 2.4 - Save the function address and the keys
        hash.Error = false;
        hash.KeyAssigner = Exe.Real2Virl(offset2 + 4) + Exe.GetInt32(offset2);
        hash.Keys[0] = Exe.GetInt32(offset2 - 05);
        hash.Keys[1] = Exe.GetInt32(offset2 - 10);
        hash.Keys[2] = Exe.GetInt32(offset2 - 15);
        return;
    }

    //Step 3.1 - Look for Type 1 pattern - Combined function with Mode pushed as argument
    code =
        " 8B 0D ?? ?? ?? 00" //MOV ECX, DWORD PTR DS:[refAddr]
    +   " 6A 01"             //PUSH 1
    +   " E8"                //CALL CRagConnection::Obfuscate2
    ;

    offset2 = Exe.FindHex(code, offset - 0x100, offset);
    if (offset2 == -1)
        return "PK: Failed to find Encryption call";

    //Step 3.2 - Save the ECX assignment
    hash.MovEcx = Exe.GetHex(offset2, 6);

    //Step 3.3 - Update offset2 to location where CALL is made
    offset2 += code.byteCount();

    //Step 3.4 - Save the function address and the keys
    hash.KeyAssigner = Exe.Real2Virl(offset2 + 4) + Exe.GetInt32(offset2);

    //Step 3.5 - Update offset to the Real value of KeyAssigner
    offset = Exe.Virl2Real(hash.KeyAssigner);

    //Step 3.6 - Go Inside and look for Base Key assignments
    var prefix =
        " 83 F8 01" //CMP EAX,1
    +   " 75 ??"    //JNE short
    ;
    code =
        prefix
    +   " C7 41 ?? ?? ?? ?? ??"  //MOV DWORD PTR DS:[ECX+x], <Key 1> ; Keys may not be assigned in order - depends on x, y and z values
    +   " C7 41 ?? ?? ?? ?? ??"  //MOV DWORD PTR DS:[ECX+y], <Key 2>
    +   " C7 41 ?? ?? ?? ?? ??"  //MOV DWORD PTR DS:[ECX+z], <Key 3>
    ;
    offset2 = Exe.FindHex(code, offset, offset + 0x50);

    if (offset2 !== -1)
    {   //Function is not virtualized or have shared keys
        //Step 3.6 - Update offset2 to location of first MOV
        offset2 += prefix.byteCount();

        //Step 3.7 - Save the keys and set the Type to 1
        hash.Error = false;
        hash.Type = 2;
        hash.Keys[Exe.GetInt8(offset2 + 02)/4 - 1] = Exe.GetInt32(offset2 + 3);
        hash.Keys[Exe.GetInt8(offset2 + 09)/4 - 1] = Exe.GetInt32(offset2 + 10);
        hash.Keys[Exe.GetInt8(offset2 + 16)/4 - 1] = Exe.GetInt32(offset2 + 17);
        hash.OvrAddr = offset2;//Offset where the assignment occurs
        return;
    }

    //Step 4.1 - Look for Shared Key pattern (still Type 1)
    code =
        prefix
    +   " B8 ?? ?? ?? ??" // MOV EAX, Shared Key
    +   " 89 41 ??"       // MOV DWORD PTR DS:[ECX+x], EAX
    +   " 89 41 ??"       // MOV DWORD PTR DS:[ECX+y], EAX
    +   " C7 41"          // MOV DWORD PTR DS:[ECX+z], Unique Key
    ;
    offset2 = Exe.FindHex(code, offset, offset + 0x50);

    if (offset2 !== -1)
    {   //Function is not virtualized but have shared keys
        //Step 4.2 - Update offset2 to location of first MOV
        offset2 += prefix.byteCount();

        //Step 4.3 - Extract all the keys and set the Type
        hash.Error = false;
        hash.Type = 1;
        hash.Keys[Exe.GetInt8(offset2 + 07)/4 - 1]  = Exe.GetInt32(offset2 + 01);
        hash.Keys[Exe.GetInt8(offset2 + 10)/4 - 1]  = Exe.GetInt32(offset2 + 01);
        hash.Keys[Exe.GetInt8(offset2 + 13)/4 - 1]  = Exe.GetInt32(offset2 + 14);
        hash.OvrAddr = offset2; //Offset where the assignment occurs
        return;
    }

    //Step 5.1 - Set the Type to 2 since nothing matched (therefore Function is virtualized)
    hash.Type = 2;
    var keyStr = [];

    //Step 5.2 - Open the Map file from Inputs folder
    var Fp = new File();
    if (!Fp.Open(APP_PATH + "Inputs/PacketKeyMap.txt", 'r'))
    {
        hash.Error = "PK: Unable to open Map file";
        return;
    }

    //Step 5.3 - Iterate through file until we get the line for this client's date
    var cdate = Exe.GetDate();
    while (!Fp.IsEOF())
    {
        //Step 5.3.1 - Get the next line and check for minimum length
        var line = Fp.ReadLine().trim();
        if (line.length < 16)
            continue;

        //Step 5.3.2 - Check for the client date
        if (line.indexOf(cdate) === 0)
        {
            //Step 5.3.3 - Check for the keys and save to keyStr if valid keys are present
            var matches = line.match(/=\s*([0-9A-Fa-f]{1,6})\s*,\s*([0-9A-Fa-f]{1,6})\s*,\s*([0-9A-Fa-f]{1,6})\s*/);
            if (matches)
            {
                keyStr.push(matches[1]);
                keyStr.push(matches[2]);
                keyStr.push(matches[3]);
            }
            break;
        }
    }
    //Step 5.4 - Close the map file
    Fp.Close();

    //Step 5.5 - Check for keys in keyStr array and convert to integers. Also assign the OvrAddr value
    if (keyStr.length === 3)
    {
        hash.Error = false;
        hash.Keys[0] = parseInt(keyStr[0], 16);
        hash.Keys[1] = parseInt(keyStr[1], 16);
        hash.Keys[2] = parseInt(keyStr[2], 16);
        hash.OvrAddr = Exe.Virl2Real(hash.KeyAssigner);
        if (HasFramePointer())
            hash.OvrAddr += 3;
    }
    else
    {
        hash.Error = "PK: No patterns matched (even in Map file)";
    }
}

//####################################################################\\
//# Extract the details of a instruction at the offset inside Client #\\
//####################################################################\\

function GetInstruction(offset)
{
    var instr =
    {
        "OpCode" : Exe.GetUint8(offset),
        "OpCode2": -1,
        "ModRM"  : Exe.GetUint8(offset + 1),
        "SIB"    : -1,

        "Mode"   : -1,
        "RegD"   : -1,
        "RMem"   : -1,

        "Scale"  : -1,
        "Index"  : -1,
        "Base"   : -1,

        "SrcImm" : -1,
        "TgtImm" : -1,

        "Size"   : -1,
        "NextLoc": -1
    };

    if (instr.OpCode === 0x0F)
    {
        instr.OpCode2 = instr.ModRM;
        instr.ModRM = Exe.GetUint8(offset + 2);
    }

    instr.Mode = (instr.ModRM >> 6) & 0x3;
    instr.RegD = (instr.ModRM >> 3) & 0x7;
    instr.RMem = (instr.ModRM) & 0x7;

    for (var i = 0; i < OpCodeSizeMap.length; i += 2)
    {
        if (OpCodeSizeMap[i].indexOf(instr.OpCode) !== -1)
        {
            instr.Size = OpCodeSizeMap[i+1];
            break;
        }
    }

    if (instr.Size === -1)
    {
        instr.Size = 2;
        if (instr.RMem === 0x4 && instr.Mode !== 0x3) //SIB mode
        {
            instr.SIB = Exe.GetUint8(offset + instr.Size);
            instr.Size++;

            instr.Scale = Math.pow(2, (instr.SIB >> 6) & 0x3);
            instr.Index = (instr.SIB >> 3) & 0x7;
            instr.Base  = (instr.SIB) & 0x7;
        }
        if (instr.Mode === 0x1)
        {
            instr.TgtImm = Exe.GetInt8(offset + instr.Size);
            instr.Size++;
        }
        else if (instr.Mode === 0x2 || (instr.Mode === 0x0 && (instr.RMem === 0x5 || instr.RMem === 0x4)))
        {
            instr.TgtImm = Exe.GetInt32(offset + instr.Size);
            instr.Size += 4;
        }

        if (instr.OpCode2 !== -1)
            instr.Size++;
    }

    switch (instr.OpCode)
    {
        case 0xEB:
        case 0x70:
        case 0x71:
        case 0x72:
        case 0x73:
        case 0x74:
        case 0x75:
        case 0x76:
        case 0x77:
        case 0x78:
        case 0x79:
        case 0x7A:
        case 0x7B:
        case 0x7C:
        case 0x7D:
        case 0x7E:
        case 0x7F: //All SHORT jumps
        {
            instr.TgtImm = Exe.GetInt8(offset + 1);
            break;
        }

        case 0xE8:
        case 0xE9: //Long Jump
        {
            instr.TgtImm = Exe.GetInt32(offset + 1);
            break;
        }

        case 0x0F: //Two Byte Opcode
        {
            if (instr.OpCode2 >= 0x80 && instr.OpCode2 <= 0x8F)
            {
                instr.TgtImm = Exe.GetInt32(offset + 2);
                instr.Size = 6;
            }
            break;
        }

        case 0x69:
        case 0x81:
        case 0xC7: //Imm32 Source
        {
            instr.SrcImm = Exe.GetInt32(offset + instr.Size);
            instr.Size += 4;
            break;
        }

        case 0x6B:
        case 0xC0:
        case 0xC1:
        case 0xC6:
        case 0x80:
        case 0x82:
        case 0x83: //Imm8 Source
        {
            instr.SrcImm = Exe.GetInt8(offset + instr.Size);
            instr.Size++;
            break;
        }
    }

    instr.NextLoc = offset + instr.Size;
    return instr;
}

//###########################################################################\\
//# Find the endpoint of table initializations and extract all instructions #\\
//# that are not part of the initializations but still mixed inside -       #\\
//# Currently used for Custom Jobs and Custom Homunculus Patches            #\\
//###########################################################################\\

function ExtractTillEnd(offset, refReg, refOff, tgtReg, endCheck, skipFunc)
{
    //Step 1.1 - Assign Initial values
    var done = false;
    var extract = "";
    var regAssigns = ["", "", "", "", "", "", "", ""];

    //Step 1.2 - If skipFunc is not assigned a value set it to -1
    if (typeof(skipFunc) === "undefined")
        skipFunc = -1;

    while (!done) //only exits at the end of initializations
    {
        //Step 2.1 - Get the Instruction details at current offset
        var instr = GetInstruction(offset);

        //Step 2.2 - Check if the offset & instruction is a match for the last one expected
        done = endCheck(instr, offset, skipFunc);
        if (done)
            continue;

        //Step 3.1 - Parse the opcode and determine whether or not to extract the instruction code
        var skip = false;
        switch (instr.OpCode)
        {
            case 0x8B: //MOV code
            {
                //Step 3.1.1 - Don't check if there is a target register already set
                if (tgtReg !== -1)
                    break;

                skip = true;

                //Step 3.1.2 - Extract target register if the instruction has one of the patterns below other wise dont skip the instruction
                if ((refOff !== 0 && instr.TgtImm === refOff) || //MOV reg32_A, DWORD PTR DS:[reg32_B + refOff]; reg32_B is set by refReg
                    (instr.Mode === 0 && instr.RMem === refReg))  //MOV reg32_A, DWORD PTR DS:[reg32_B]
                    tgtReg = instr.RegD;
                else
                    skip = false;

                break;
            }
            case 0xC7: //MOV DWORD PTR DS:[reg32_A + const], OFFSET addr
            case 0x89: //MOV DWORD PTR DS:[reg32_A + const], reg32_C
            {
                //Step 3.1.3 - If the previous target register serves as the source here unset it
                if (tgtReg !== -1 && instr.RMem === tgtReg && instr.Mode !== 3)
                {
                    tgtReg = -1;
                    skip = true;
                }

                //Step 3.1.4 - Remove unnecessary assignments to regAssigns
                if (skip && regAssigns[instr.RegD] !== "" && instr.OpCode === 0x89)
                {
                    extract = extract.replace(regAssigns[instr.RegD], "");
                    regAssigns[instr.RegD] = "";
                }
                break;
            }

            case 0xB8:
            case 0xB9:
            case 0xBA:
            case 0xBB:
            case 0xBC:
            case 0xBD:
            case 0xBE:
            case 0xBF: //MOV reg32, OFFSET addr; No need to skip but do save for comparison later
            {
                //Step 3.1.5 - Save the Register value assignment to regAssigns
                regAssigns[instr.OpCode - 0xB8] = Exe.GetHex(offset, instr.Size);
                break;
            }

            case 0x0F: //Conditional JMP
            {
                //debugger;
                //Step 3.1.6 - Skip if its a JMP (0F also has other instructions duh!) & update the NextLoc to the Jump target
                skip = (instr.OpCode2 >= 0x80 && instr.OpCode2 <= 0x8F);
                if (skip)
                    instr.NextLoc += instr.TgtImm;

                break;
            }

            case 0xE9:
            case 0xEB:
            case 0x70:
            case 0x71:
            case 0x72:
            case 0x73:
            case 0x74:
            case 0x75:
            case 0x76:
            case 0x77:
            case 0x78:
            case 0x79:
            case 0x7A:
            case 0x7B:
            case 0x7C:
            case 0x7D:
            case 0x7E:
            case 0x7F: //JMP & all SHORT jumps
            {
                //Step 3.1.7 - Skip by default and update the NextLoc to jump target
                skip = true;
                instr.NextLoc += instr.TgtImm;
                break;
            }

            case 0x83: //CMP DWORD PTR DS:[g_serviceType], value
            {
                //Step 3.1.8 - Skip only if its a CMP and compared address is LangType (g_serviceType)
                skip = (instr.ModRM === 0x3D && instr.TgtImm === LT.Value);
                break;
            }

            case 0x39: //CMP DWORD PTR DS:[g_serviceType], reg32
            {
                //Step 3.1.9 - Similar to 3.1.8
                skip = (instr.Mode === 0 && instr.RMem === 5 && instr.TgtImm === LT.Value);
                break;
            }

            case 0x6A: //PUSH byte
            case 0x68: //PUSH dword
            {
                //Step 3.1.10 - skip if its an argument to a CALL skipFunc
                //                PUSH arg
                //                MOV ECX, ESI
                //                MOV DWORD PTR DS:[EAX], OFFSET; for previous (optional)
                //                CALL skipFunc
                if (skipFunc === -1)
                    break;

                var offset2 = instr.NextLoc + 7;

                if (Exe.GetUint8(instr.NextLoc + 2) === 0xC7)
                    offset2 += 6;

                skip = (Exe.GetUint8(offset2 - 5) === 0xE8 && Exe.GetInt32(offset2 - 4) === (skipFunc - offset2));
                if (skip)
                {
                    instr.NextLoc = offset2;
                    tgtReg = 0;//EAX
                }
                break;
            }

            case 0xE8: //CALL
            {
                //Step 3.1.11 - Skip if the Function === skipFunc & substitute with Stack restoration
                if (skipFunc === -1)
                break;

                if (instr.TgtImm === (skipFunc - instr.NextLoc)) //CALL skipFunc
                {
                    skip = true;
                    extract += " 83 C4 04";//ADD ESP, 4; Restoring stack
                    tgtReg = 0;//EAX
                }
            }
        }

        //Step 3.2 - Extract the instruction code if skip boolean is not enabled
        if (!skip)
            extract += Exe.GetHex(offset, instr.Size);

        //Step 3.3 - Update offset to next location
        offset = instr.NextLoc;
    }

    //Step 4 - Return the Ending offset and the Extracted code
    return {"EndOff": offset, "Code": extract};
}

//#############################################################\\
//#                                                           #\\
//#############################################################\\

function LoadSkillTypeLua(id, offset)
{
    if (SKL.Prefix === "")
    {
        SKL.Prefix = "Lua Files\\SkillInfo";
        if (Exe.GetDate() >= 20100817)
            SKL.Prefix += "z";
    }
    
    if (!SKL.PatchID)
    {
        SKL.Offset = AddLuaLoaders(
            SKL.Prefix + "\\SkillInfo_F",
            [
                SKL.Prefix + "\\SkillType",
                SKL.Prefix + "\\SkillType_F"
            ],
            offset
        );
        if (typeof(SKL.Offset) === "string")//Error was returned
        {
            SKL.Error = SKL.Offset;
            SKL.Offset = -1;
        }
        else
        {
            SKL.Error = false;
            SKL.PatchID = id;
        }
    }
}