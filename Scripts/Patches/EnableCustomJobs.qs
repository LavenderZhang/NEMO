//#####################################################################\\
//# Change the Hardcoded loading of Job tables (name, path prefix,    #\\
//# hand prefix, palette prefix and imf prefix) to use Lua functions. #\\
//#                                                                   #\\
//# Also modify the sprite size checker and Cash Mount retrieval      #\\
//# codes to use Lua Functions.                                       #\\
//#####################################################################\\

MaxJob = 4400;
function EnableCustomJobs() //Pre-VC9 Client support not completed
{
    /***** Find all the inject locations *****/

    //Step 1.1 - Get address of reference strings . (Pattern for Archer seems to be stable across clients hence we will use it)
    var refPath = Exe.FindString("\xB1\xC3\xBC\xF6", VIRTUAL); // ±Ã¼ö for Archer. Same value is used for palette as well as imf
    if (refPath === -1)
        return "Failed in Step 1 - Path prefix missing";

    var refHand = Exe.FindString("\xB1\xC3\xBC\xF6\\\xB1\xC3\xBC\xF6", VIRTUAL); // ±Ã¼ö\±Ã¼ö for Archer
    if (refHand === -1)
        return "Failed in Step 1 - Hand prefix missing";

    var refName = Exe.FindString("Acolyte", VIRTUAL);//We use Acolyte here because Archer has a MOV ECX, OFFSET statement before it in Older clients
    if (refName === -1)
        return "Failed in Step 1 - Name prefix missing";

    //Step 1.2 - Find all references of refPath
    var hooks = Exe.FindAllHex("C7 ?? 0C" + Num2Hex(refPath));
    var assigner; //std::vector[] function used in Older clients

    if (hooks.length === 2)
    {
        //Step 1.3 - Look for old style assignment following a call to std::vector[] - For Older clients
        var offset = Exe.FindHex("C7 00" + Num2Hex(refPath) + " E8");
        if (offset === -1)
            return "Failed in Step 1 - Palette reference is missing";

        //Step 1.4 - Extract the function address (REAL)
        assigner = (offset + 11) + Exe.GetInt32(offset + 7);

        //Step 1.5 - Hook Location will be 4 bytes before at PUSH 4
        hooks[2] = offset - 4;

        //Step 1.6 - Little trick to change the PUSH 3 to PUSH 0 so that EAX will point to the first location like we need
        offset = Exe.FindHex("6A 03", hooks[2] - 0x12, hooks[2]);
        Exe.ReplaceInt8(offset + 1, 0);
    }
    if (hooks.length !== 3)
        return "Failed in Step 1 - Prefix reference missing or extra";

    //Step 1.7 - Find reference of refHand
    var offset = Exe.FindHex("C7 ?? 0C" + Num2Hex(refHand));
    if (offset === -1)
        return "Failed in Step 1 - Hand reference missing";

    hooks[3] = offset;

    //Step 1.8 - Find reference of refName
    offset = Exe.FindHex("C7 ?? 10" + Num2Hex(refName));
    if (offset === -1)
        return "Failed in Step 1 - Name reference missing";

    hooks[4] = offset;

    /***** Extract/Calculate all the required info for all the locations *****/

    //Step 2.1 - Check if LangType is available (LT.Error will be a string if not)
    if (LT.Error)
        return "Failed in Step 2 - " + LT.Error;

    var details = [];
    var curRegs = [];
    for (var i = 0; i < hooks.length; i++)
    {
        //Step 2.2 - Extract the reference Register (usually ESI), reference Offset and current Register for all hooks from the instruction before each
        //             MOV curReg, DWORD PTR DS:[refReg + refOff]
        //           curReg can also be extracted from code at hook location

        if (Exe.GetInt8(hooks[i] - 2) === 0) //refOff != 0
        {
            var modrm  = Exe.GetInt8(hooks[i] - 5);
            var refOff = Exe.GetInt32(hooks[i] - 4);
        }
        else if (Exe.GetInt8(hooks[i]) === 0x6A) //Older client
        {
            var modrm  = 0x6;//so that refReg will be ESI and curReg will be EAX
            var refOff = 0;
        }
        else //refOff = 0
        {
            var modrm  = Exe.GetInt8(hooks[i] - 1);
            var refOff = 0;
        }
        var refReg = modrm & 0x7;
        curRegs[i] = (modrm & 0x38) >> 3;

        //Step 2.3 - Find Location after the Table assignments which is the location to jump to after lua based loading
        //           Also extract all non-table related instuctions in between
        details[i] = ExtractTillEnd(hooks[i], refReg, refOff, curRegs[i], CheckEoT, assigner);
    }

    /***** Add Function Names & Table Loaders *****/

    //Step 3 - Insert Lua Function Names into client (Since we wont be using the hardcoded JobNames we will overwrite suitable ones)
    var Funcs = [];

    Funcs[0]  = OverwriteString("Professor",     "ReqPCPath");
    Funcs[1]  = OverwriteString("Blacksmith",    "MapPCPath\x00");
    Funcs[2]  = OverwriteString("Swordman",      "ReqPCImf");
    Funcs[3]  = OverwriteString("Assassin",      "MapPCImf");
    Funcs[4]  = OverwriteString("Magician",      "ReqPCPal");
    Funcs[5]  = OverwriteString("Crusader",      "MapPCPal");
    Funcs[6]  = OverwriteString("Swordman High", "ReqPCHandPath");
    Funcs[7]  = OverwriteString("Magician High", "MapPCHandPath");
    Funcs[8]  = OverwriteString("White Smith_W", "ReqPCJobName_M");
    Funcs[9]  = OverwriteString("High Wizard_W", "MapPCJobName_M");
    Funcs[10] = OverwriteString("High Priest_W", "ReqPCJobName_F");
    Funcs[11] = OverwriteString("Lord Knight_W", "MapPCJobName_F");
    Funcs[12] = OverwriteString("Alchemist",     "GetHalter");
    Funcs[13] = OverwriteString("Acolyte",       "IsDwarf");

    //Step 4.1 - Write the Loader into client for Path, Imf, Weapon and Palette
    WriteLoader(hooks[0], curRegs[0], "PCPath"    , Funcs[0], Funcs[1], details[0].EndOff, details[0].Code);
    WriteLoader(hooks[1], curRegs[1], "PCImf"     , Funcs[2], Funcs[3], details[1].EndOff, details[1].Code);
    WriteLoader(hooks[2], curRegs[2], "PCPal"     , Funcs[4], Funcs[5], details[2].EndOff, details[2].Code);
    WriteLoader(hooks[3], curRegs[3], "PCHandPath", Funcs[6], Funcs[7], details[3].EndOff, details[3].Code);

    //Step 4.2 - For Jobname we will simply add the extracted code and jmp to endOff instead of loading now
    //           to avoid repetitive loading (happens again when gender is checked)
    var code =
        details[4].Code
    +   " E9";

    code += Num2Hex(details[4].EndOff - (hooks[4] + code.byteCount() + 4));
    Exe.ReplaceHex(hooks[4], code);

    //Step 4.3 - Update hook location to address after the JMP
    hooks[4] += code.byteCount();

    /***** Find Gender based Name assignment & Extract/Calculate all info *****/

    //Step 5.1 - Find "TaeKwon Girl"
    offset = Exe.FindString("TaeKwon Girl", VIRTUAL);
    if (offset === -1)
        return "Failed in Step 5 - 'TaeKwon Girl' missing";

    //Step 5.2 - Find its reference - this is where we will jump out and start loading the table
    code =
        " 85 C0"                               //TEST EAX, EAX
    +   " 75 ??"                               //JNZ SHORT addr -> TaeKwon Boy assignment
    +   " A1 ?? ?? ?? 00"                      //MOV EAX, DWORD PTR DS:[g_jobName]
    +   " C7 ?? 38 3F 00 00" + Num2Hex(offset) //MOV DWORD PTR DS:[EAX+3F38], OFFSET addr; ASCII "TaeKwon Girl"
    ;
    var gJobName = 5;
    var offset2 = Exe.FindHex(code);//VC9 Clients

    if (offset2 === -1)
    {
        code = code.replace("A1", "8B ??");//Change EAX to reg32_A
        gJobName = 6;
        offset2 = Exe.FindHex(code); //Older clients
    }
    if (offset2 === -1)
    {
        code =
            " 85 C0"                //TEST EAX, EAX
        +   " A1 ?? ?? ?? 00"       //MOV EAX, DWORD PTR DS:[g_jobName]
        +   " ??" + Num2Hex(offset) //MOV reg32_A, OFFSET addr; ASCII "TaeKwon Girl"
        ;
        gJobName = 3;
        offset2 = Exe.FindHex(code); //Latest Clients
    }
    if (offset2 === -1)
        return "Failed in Step 5 - 'TaeKwon Girl' reference missing";

    //Step 5.3 - Extract the g_jobName address
    gJobName = Exe.GetInt32(offset2 + gJobName);

    //Step 5.4 - Look for the LT.Hex comparison before offset2 (in fact the JNZ should jump to a call after which we do the above TEST)
    //           Steps 5d and 5e are also done in TranslateClient but we will keep it anyways as a failsafe
    code =
        " 83 3D" + LT.Hex + " 00" //CMP DWORD PTR DS:[g_serviceType], 00
    +   " B9 ?? ?? ?? 00"         //MOV ECX, OFFSET g_session
    +   " 75"                     //JNE SHORT addr -> CALL CSession::GetSex
    ;
    offset = Exe.FindHex(code, offset2 - 0x80, offset2);

    if (offset === -1)
    {
        code =
            " A1" + LT.Hex    //MOV EAX, DWORD PTR DS:[g_serviceType]
        +   " B9 ?? ?? ?? 00" //MOV ECX, OFFSET g_session
        +   " 85 C0"          //TEST EAX, EAX
        +   " 75"             //JNE SHORT addr -> CALL CSession::GetSex
        ;
        offset = Exe.FindHex(code, offset2 - 0x80, offset2);
    }
    if (offset === -1)
        return "Failed in Step 5 - LT.Hex comparison missing";

    //Step 5.5 - Change the JNE to JMP
    Exe.ReplaceInt8(offset + code.byteCount() - 1, 0xEB)

    offset = offset2;

    //Step 5.6 - Find the LangType comparison with 0C, 5 & 6 after offset
    code =
        " 83 F8 0C" //CMP EAX, 0C
    +   " 74 0E"    //JE SHORT addr
    +   " 83 F8 05" //CMP EAX, 5
    +   " 74 09"    //JE SHORT addr
    +   " 83 F8 06" //CMP EAX, 6
    +   " 0F 85"    //JNE addr2
    ;

    offset2 = Exe.FindHex(code, offset + 0x10, offset + 0x100);
    if (offset2 === -1)
        return "Failed in Step 5 - 2nd LT.Hex comparison missing";

    //Step 5.7 - Extract any Register Pushes before the Comparison - This is needed since they are restored at the end of the function
    var push1 = Exe.GetUint8(offset2 - 1);
    if (push1 < 0x50 || push1 > 0x57)
        push1 = 0x90;

    var push2 = Exe.GetUint8(offset2 - 2);
    if (push2 < 0x50 || push2 > 0x57)
        push2 = 0x90;

    if (push2 === 0x90 && push1 === 0x90) //Recent client does PUSH ESI somewhat earlier hence we dont detect any
        push1 = 0x56;

    offset2 += code.byteCount();
    offset2 += 4 + Exe.GetInt32(offset2);

    //Step 5.8 - Change the CMP to NOP and JNE to JMP as shown below at The JNE address
    //A1 <LT.Hex> ; MOV EAX, DWORD PTR DS:[g_serviceType]
    //83 F8 0A        => push2 push1 90
    //0F 85 addr    => 90 E9 addr
    Exe.ReplaceHex(offset2, Num2Hex(push2, 1) + Num2Hex(push1, 1) +  "90 90 E9");

    //Step 5.8 - Point offset2 to the MOV EAX before the CMP
    offset2 -= 5;

    /***** Add Job Name Loaders *****/

    //Step 6.1 - Build the gender test
    code =
        " 85 C0"              //TEST EAX, EAX
    +   " 0F 85" + MakeVar(1) //JNE addr1 -> Male Job Name Loading
    ;
    var csize = code.byteCount();

    //Step 6.2 - Write the Female Job Name Loader below
    csize += WriteLoader(offset + csize, gJobName, "PCJobName_F", Funcs[10], Funcs[11], offset2, "").byteCount();

    //Step 6.3 - Write the Male Job Name Loader below
    WriteLoader(offset + csize, gJobName, "PCJobName_M", Funcs[8], Funcs[9], offset2, "");

    //Step 6.4 - Replace the variable in code (since we know where addr1 is now)
    code = SetValue(code, 1, csize - code.byteCount());

    //Step 6.5 - Add it to client
    Exe.ReplaceHex(offset, code);

    /***** Inject Lua file loading *****/

    var retVal = AddLuaLoaders(
        "Lua Files\\DataInfo\\NPCIdentity",
        [
            "Lua Files\\Admin\\PCIds",
            "Lua Files\\Admin\\PCPaths",
            "Lua Files\\Admin\\PCImfs",
            "Lua Files\\Admin\\PCHands",
            "Lua Files\\Admin\\PCPals",
            "Lua Files\\Admin\\PCNames",
            "Lua Files\\Admin\\PCFuncs"
        ],
        hooks[4]
    );
    if (typeof(retVal) === "string")
        return "Failed in Step 6 - " + retVal;

    /***** Special Mod 1 : Cash Mount *****/

    //Step 7.1 - Find the function where the Cash Mount Job ID is assigned
    code =
        " 83 F8 19"       //CMP EAX, 19
    +   " 75 ??"          //JNE SHORT addr -> next CMP
    +   " B8 12 10 00 00" //MOV EAX, 1012
    ;
    offset = Exe.FindHex(code);

    if (offset !== -1)
    {
        //Step 7.2 - Build the replacement code using GetHalter Lua function
        code =
            " 52" //PUSH EDX
        + GenLuaCaller(offset + 1, "GetHalter", Funcs[12], "d>d", " 50")
        +   " 5A" //POP EDX
        ;

        if (EBP_TYPE)
            code += " 5D";  //POP EBP

        code += " C2 04 00"; //RETN 4

        //Step 7.3 - Replace at offset
        Exe.ReplaceHex(offset, code);
    }

    /***** Special Mod 2 : Baby Jobs (Shrinking/Dwarfing) *****/

    //Step 8.1 - Find Function where Baby Jobs are checked (missing in old client)
    if (EBP_TYPE)
    {
        code = " 8B ?? 08";    //MOV reg32_A, DWORD PTR SS:[EBP+8]
        csize = 3;
    }
    else
    {
        code = " 8B ?? 24 04"; //MOV reg32_A, DWORD PTR SS:[ESP+4]
        csize = 4;
    }

    code +=
        " 3D B7 0F 00 00" //CMP EAX, 0FB7
    +   " 7C ??"          //JL SHORT addr -> next CMP chain
    +   " 3D BD 0F 00 00" //CMP EAX, 0FBD
    ;
    offset2 = " 50"; //Don't mind the var name
    offset = Exe.FindHex(code);

    if (offset === -1)
    {
        code = code.replace(/ 3D/g, " 81 ??");//Change EAX with reg32_A
        offset2 = "";
        offset = Exe.FindHex(code);
    }
    if (offset !== -1)
    {
        offset += csize;
        //Step 8.2 - Get the PUSH register in case it is not EAX
        if (offset2 === "")
            offset2 = Num2Hex(0x50 + (Exe.GetInt8(offset + 1) & 0x7), 1);

        //Step 8.3 - Build the replacement code using IsDwarf Lua function
        code =
            " 52" //PUSH EDX
        + GenLuaCaller(offset + 1, "IsDwarf", Funcs[13], "d>d", offset2)
        +   " 5A" //POP EDX
        ;

        if (EBP_TYPE)
            code += " 5D";         //POP EBP

        code += " C2 04 00"; //RETN 4

        //Step 8.4 - Replace at offset
        Exe.ReplaceHex(offset, code);
    }
    return true;
}

//#######################################################\\
//# Check whether End of Table has been reached at the  #\\
//# supplied offset. Used as argument to ExtractTillEnd #\\
//#######################################################\\

function CheckEoT(hash, offset, assigner)
{
    //SUB reg32_A, reg32_B
    //SAR reg32_A, 2
    if (hash.OpCode === 0x2B && Exe.GetUint8(offset + 2) === 0xC1 && Exe.GetUint8(offset + 4) === 0x02 )
        return true;

    //PUSH 524C
    if (hash.OpCode === 0x68 && Exe.GetInt32(offset + 1) === 0x524C)
        return true;

    //PUSH EAX
    //PUSH 2 or PUSH 5
    if (hash.OpCode === 0x50 && hash.ModRM === 0x6A && (Exe.GetInt8(offset + 2) === 0x02 || Exe.GetInt8(offset + 2) === 0x05))
        return true;

    //CALL func; where func !== assigner
    if (hash.OpCode === 0xE8 && (assigner === -1 || hash.TgtImm !== (assigner - (offset + 5))) )
        return true;

    //MOV EAX, DWORD PTR DS:[EDI+4]
    if (hash.OpCode === 0x8B && hash.ModRM === 0x47 && hash.TgtImm === 0x4)//Hope this doesnt conflict any point later
        return true;

    //CALL DWORD PTR DS:[addr]
    if (hash.OpCode === 0xFF && hash.ModRM === 0x15)//Hope this doesnt conflict with any other client
        return true;

    //OR reg32_A, FFFFFFFF
    if (hash.OpCode === 0x83 && (hash.ModRM & 0xF8) === 0xC8 && Exe.GetUint8(offset + 2) === 0xFF)
        return true;

    //MOV EDI, EDI
    if (hash.OpCode === 0x8B && hash.ModRM === 0xFF)
        return true;

    //MOV EDI, 2D - deprecated since MOV EDI, EDI doesn't leave out any stray assignments
    //if (hash.OpCode === 0xBF && Exe.GetInt32(offset + 1) === 0x2D)
    //    return true;

    return false;
}

//##################################################################################\\
//# Find address of srcString, overwrite it with tgtString and return it (VIRTUAL) #\\
//##################################################################################\\

function OverwriteString(srcString, tgtString)
{
    //Step 1 - Find address
    var offset = Exe.FindString(srcString, REAL);

    //Step 2.1 - Overwrite it
    Exe.ReplaceString(offset, tgtString);

    //Step 2.2 - Return the VA of offset
    return Exe.Real2Virl(offset, DATA);
}

//###############################################################\\
//# Overwrite code at hook with Lua function based table loader #\\
//###############################################################\\

function WriteLoader(hookLoc, curReg, suffix, reqAddr, mapAddr, jmpLoc, extraData)
{
    //Step 1 - Setup all arrays we will be using
    var prefixes = [];  //Two prefixes for two range of Jobs
    var templates = []; //Two templates one for Req functions and other for Map functions
    var fnNames = ["Req" + suffix, "Map" + suffix]; // - do -
    var fnAddrs = [reqAddr, mapAddr]; // - do -
    var argFormats = ["d>s", "d>d"]; // - do -

    prefixes[0] =
        " 33 FF"                    //XOR EDI, EDI
    +   " BB 2C 00 00 00" //MOV EBX, 2C
    ;

    if (suffix.indexOf("Name") !== -1)
    {
        prefixes[1] =
            " 90"                   //NOP
        +   " BF A1 0F 00 00"       //MOV EDI, 0xFA1;//4001
        +   " BB" + Num2Hex(MaxJob) //MOV EBX, MaxJob
        ;
    }
    else
    {
        prefixes[1] =
            " 90"                          //NOP
        +   " BF 33 00 00 00"              //MOV EDI, 0x33;//4001 - 3950
        +   " BB" + Num2Hex(MaxJob - 3950) //MOV EBX, MaxJob-3950
        ;
    }
    templates[0] =
        MakeVar(1)     //code for PrepVars
    +   MakeVar(2)     //code for GenCaller
    +   " 85 C0"       //TEST EAX, EAX
    +   " 74 12"       //JE SHORT addr2
    +   " 8A 08"       //MOV CL, BYTE PTR DS:[EAX]
    +   " 84 C9"       //TEST CL, CL
    +   " 74 07"       //JE SHORT addr
    +   " 8B 4C 24 20" //MOV ECX, DWORD PTR SS:[ESP+20]
    +   " 89 04 B9"    //MOV DWORD PTR DS:[EDI*4+ECX], EAX
    +   " 47"          //INC EDI; addr
    +   " 39 DF"       //CMP EDI,EBX
    +   " 7E XX"       //JLE SHORT addr2; to start of generate
    ;
    templates[1] =
        MakeVar(1)     //code for PrepVars
    +   MakeVar(2)     //code for GenCaller
    +   " 85 C0"       //TEST EAX,EAX
    +   " 78 0A"       //JS SHORT addr
    +   " 8B 4C 24 20" //MOV ECX, DWORD PTR SS:[ESP+20]
    +   " 8B 04 81"    //MOV EAX, DWORD PTR DS:[EAX*4+ECX]
    +   " 89 04 B9"    //MOV DWORD PTR DS:[EDI*4+ECX], EAX
    +   " 47"          //INC EDI; addr
    +   " 39 DF"       //CMP EDI, EBX
    +   " 7E XX"       //JLE SHORT addr2; to start of generate
    ;

    //Step 2.1 - Push the register containing first element and save all registers
    if (curReg > 7)
        var code = " FF 35" + Num2Hex(curReg); //PUSH OFFSET curReg
    else
        var code = Num2Hex(0x50 + curReg, 1);//PUSH reg32_A; reg32_A points to the location of first element of the tablell

    code += " 60";                                                        //PUSHAD

    //Step 2.2 - Now for each template fill in the blanks with corresponding prefix and GenLuaCaller code
    for (var i = 0; i < templates.length; i++)
    {
        for (var j = 0; j < prefixes.length; j++)
        {
            var coff = code.byteCount() + prefixes[j].byteCount(); //relative offset from hookLoc

            code += templates[i];

            code = SetValue(code, 1, prefixes[j]); //Change PrepVars to the actual prefix
            code = SetValue(code, 2, GenLuaCaller(hookLoc + coff, fnNames[i], fnAddrs[i], argFormats[i], " 57")); //Change GenCaller with generated code
            code = code.replace(" XX", Num2Hex(coff - code.byteCount(), 1));//Change XX to the actual JLE distance
        }
    }

    //Step 2.3 - Add the finishing touches.
    //           Restore registers, Add the extracted code, Jump to jmpLoc or RETN
    code +=
        " 61"       //POPAD
    +   " 83 C4 04" //ADD ESP, 4
    +   extraData
    ;

    if (jmpLoc !== -1)
        code += " E9" + Num2Hex(jmpLoc - (hookLoc + code.byteCount() + 5)); //JMP jmpLoc
    else
        code += " C3"; //RETN

    Exe.ReplaceHex(hookLoc, code);
    return code;
}