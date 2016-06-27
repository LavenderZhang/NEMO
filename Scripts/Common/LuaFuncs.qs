//######################################################\\
//# Get all String PUSHes, Function Addresses & global #\\
//# LuaState PUSH used in Lua Function calls          #\\
//######################################################\\

function GetLuaData()
{
    //Step 1.1 - Find "d>s"
    var offset = Exe.FindString("d>s", VIRTUAL);
    if (offset === -1)
    {
        LUA.Error = "LUA: d>s not found";
        return;
    }

    //Step 1.2 - Setup D2S member
    LUA.D2S = " 68" + Num2Hex(offset);

    //Step 1.3 - Find "d>d"
    offset = Exe.FindString("d>d", VIRTUAL);
    if (offset === -1)
    {
        LUA.Error = "LUA: d>d not found";
        return;
    }

    //Step 1.4 - Setup D2D member
    LUA.D2D = " 68" + Num2Hex(offset);

    //Step 2.1 - Find "ReqJobName"
    offset = Exe.FindString("ReqJobName", VIRTUAL);
    if (offset === -1)
    {
        LUA.Error = "LUA: ReqJobName not found";
        return;
    }

    //Step 2.2 - Setup ReqJob member
    LUA.ReqJob = " 68" + Num2Hex(offset);

    //Step 2.3 - Find the PUSH
    offset = Exe.FindHex(LUA.ReqJob);
    if (offset === -1)
    {
        LUA.Error = "LUA: ReqJobName reference missing";
        return;
    }

    //Step 2.4 - Find the ESP substraction before the reference
    var code =
        " 83 EC ??" //SUB ESP, const
    +   " 8B CC"    //MOV ECX, ESP
    ;

    var offset2 = Exe.FindHex(code, offset - 0x28, offset);
    if (offset2 === -1)
    {
        LUA.Error = "LUA: ESP allocation missing";
        return;
    }

    //Step 2.5 - Save the const to EspConst member
    LUA.EspConst = Exe.GetInt8(offset2 + 2);

    //Step 3 - Extract String Allocator function address based on the opcode following PUSH
    switch (Exe.GetUint8(offset + 5))
    {
        case 0xFF:  //CALL DWORD PTR DS:[funcAddr] ; VC9
        {
            offset += 11;
            LUA.StrAlloc = Exe.GetUint32(offset - 4);
            LUA.AllocType = 0; //function is an MSVC import
            break;
        }
        case 0xE8: //CALL funcAddr ; Older clients
        {
            offset += 10;
            LUA.StrAlloc = Exe.Real2Virl(offset, CODE) + Exe.GetInt32(offset - 4);
            LUA.AllocType = 1; //function has an argument PUSH which is a pointer
            break;
        }
        case 0xC6: //MOV BYTE PTR DS:[ECX], 0 -> VC10+ Clients
        {
            offset += 13;
            LUA.StrAlloc = Exe.Real2Virl(offset, CODE) + Exe.GetInt32(offset - 4);
            LUA.AllocType = 2; //function needs ESP, which is now ECX + 14  = 0xF and ECX + 10 = 0
            break;
        }
        default:
        {
            LUA.Error = "LUA: Unexpected Opcode after ReqJobName";
            return;
        }
    }

    //Step 3.1 - Find LuaState assignment after offset
    code = "8B ?? ?? ?? ?? 00"; //MOV reg32_A, DWORD PTR DS:[lua_state]
    offset2 = Exe.FindHex(code, offset, offset + 0x10); //VC9 - VC10

    if (offset2 === -1)
    {
        code = "FF 35 ?? ?? ?? 00"; //PUSH DWORD PTR DS:[lua_state]
        offset2 = Exe.FindHex(code, offset, offset + 0x10);//VC11
    }
    if (offset2 === -1)
    {
        code = "A1 ?? ?? ?? 00"; //MOV EAX, DWORD PTR DS:[lua_state]
        offset2 = Exe.FindHex(code, offset, offset + 0x10);//Older Clients
    }
    if (offset2 === -1)
    {
        LUA.Error = "LUA: LuaState assignment missing";
        return;
    }

    //Step 3.2 - Update offset2 to after the assignment
    offset2 += code.byteCount();

    //Step 3.3 - Setup StatePush member from the LuaState address in hex format
    LUA.StatePush = " FF 35" + Exe.GetHex(offset2 - 4, 4);

    //Step 3.4 - Find the Lua function caller after offset2
    offset = Exe.FindHex("E8 ?? ?? ?? FF", offset2, offset2 + 0x10);
    if (offset === -1)
    {
        LUA.Error = "LUA: Lua Function caller missing";
        return;
    }

    //Step 3.5 - Save the address
    LUA.FnCaller = Exe.Real2Virl(offset + 5, CODE) + Exe.GetInt32(offset + 1);
}

//######################################\\
//# Generate code to call Lua Function #\\
//######################################\\

function GenLuaCaller(start, funcName, nameOffset, argSpec, regPush)
{
    //Step 1.1 - Sanity Check. LUA hash is loaded or not
    if (LUA.Error) //Ideally it shouldnt have been called if there was error
        return false;

    //Step 1.2 - Select PUSH "d>s" or PUSH "d>d" based on argSpec
    if (argSpec === "d>s")
        var fmtPush = LUA.D2S;
    else
        var fmtPush = LUA.D2D;

    //Step 1.3 - Make code for PUSH funcName
    if (typeof(nameOffset) === "number")
        var namePush = " 68" + Num2Hex(nameOffset);
    else
        var namePush = " 68" + nameOffset;//its already in HEX

    /***** Now we construct the code *****/

    //Step 2.1 - First we create the base code (with variable for unknown parts)
    var code =
        MakeVar(1)                          //Optional Push prefix code
    +   " 6A 00"                            //PUSH 0
    +   " 54"                               //PUSH ESP
    +   regPush                             //PUSH reg32_A
    +   fmtPush                             //PUSH argSpec ; ASCII "d>s" or "d>d"
    +   " 83 EC" + Num2Hex(LUA.EspConst, 1) //SUB ESP, EspConst
    +   " 8B CC"                            //MOV ECX, ESP
    +   MakeVar(2)                          //Optional code for StrAlloc Preparation
    +   namePush                            //PUSH nameOffset; ASCII funcName
    +   MakeVar(3)                          //CALL StrAlloc or CALL DWORD PTR DS:[StrAlloc]
    +   LUA.StatePush                       //PUSH DWORD PTR DS:[LuaState]
    +   " E8" + MakeVar(4)                  //CALL FnCaller
    ;

    //Step 2.2 - Fill value for 1 (push prefix)
    if (LUA.AllocType === 1)
        code = SetValue(code, 1, " 6A" + Num2Hex(funcName.length, 1)); //PUSH length
    else
        code = SetValue(code, 1, "");

    //Step 2.3 - Fill value for 2 (StrAlloc preparation)
    if (LUA.AllocType === 1)
    {
        code = SetValue(code, 2,
            " 8D 44 24" + Num2Hex(LUA.EspConst + 16, 1) //LEA EAX, [ESP + const2]; const2 = const + 16
        +   " 50"                                   //PUSH EAX
        );
    }
    else if (LUA.AllocType === 2)
    {
        code = SetValue(code, 2,
            " C7 41 14 0F 00 00 00"         //MOV DWORD PTR DS:[ECX+14], 0F
        +   " C7 41 10 00 00 00 00"         //MOV DWORD PTR DS:[ECX+10], 0
        +   " C6 01 00"                     //MOV BYTE PTR DS:[ECX], 0
        +   " 6A" + Num2Hex(funcName.length, 1) //PUSH length
        );
    }
    else
    {
        code = SetValue(code, 2, "");
    }

    //Step 2.4 - Fill Value for 3 (StrAlloc call)
    if (LUA.AllocType === 0)
        code = SetValue(code, 3, " FF 15" + Num2Hex(LUA.StrAlloc)); //CALL DWORD PTR DS:[StrAlloc]
    else
        code = SetValue(code, 3, " E8" + Num2Hex(LUA.StrAlloc - Exe.Real2Virl(start + code.byteCount() - 10))); //CALL StrAlloc

    //Step 2.5 - Fill Value for 4 (Lua function caller)
    code = SetValue(code, 4, LUA.FnCaller - Exe.Real2Virl(start + code.byteCount()));

    //Step 2.6 - And finally append the Stack restore and Function output retrieval codes
    code +=
        " 83 C4" + Num2Hex(LUA.EspConst + 16, 1) //ADD ESP, const2
    +   " 58"                                //POP EAX
    ;
    if (LUA.AllocType === 1) //For old clients
        code += " 83 C4 04"; //ADD ESP, 4

    return code;
}

//#################################\\
//# Inject code to load Lua Files #\\
//#################################\\

function AddLuaLoaders(referFile, nameList, insertHere)
{
    //Step 1.1 - Find the referFile string
    var offset = Exe.FindString(referFile, VIRTUAL);
    if (offset === -1)
        return "ALL: Filename missing";

    //Step 1.2 - Make code for PUSH referFile
    var refHex = Num2Hex(offset);

    //Step 1.3 - Find its occurence
    offset = Exe.FindHex("68" + refHex);
    if (offset === -1)
        return "ALL: Filename reference missing";

    //Step 1.4 - Find the ECX assignment before it - We will be JMP-ing from here to our code
    var jmpHere = Exe.FindHex("8B 8E ?? ?? 00 00", offset - 10, offset);

    if (jmpHere === -1)
        jmpHere = Exe.FindHex("8B 0D ?? ?? ?? 00", offset - 10, offset);
    if (jmpHere === -1)
        return "ALL: ECX assignment missing";

    //Step 1.5 - Setup the return address - location after
    //           CALL CLua::LoadFile (well thats what we are calling it atm)
    var retnHere = Exe.Real2Virl(offset + 10);

    //Step 1.6 - Extract the Lua file loader function Address
    var fileLoader = retnHere + Exe.GetInt32(offset + 6);

    //Step 2.1 - Create template code (loads each file)
    var template =
        Exe.GetHex(jmpHere, offset - jmpHere) //Add the ECX movement and PUSHes before the Filename push
    +   " 68" + MakeVar(1)                    //PUSH filename
    +   " E8" + MakeVar(2)                    //CALL CLua::LoadFile
    ;

    var tSize = template.byteCount();

    //Step 2.2 - Join the Strings and convert to Hex
    var strCode = Ascii2Hex(nameList.join("\x00"));

    //Step 2.3 - If insertHere is not provided or is -1, then Get some free space
    var useInsert = (typeof(insertHere) === "undefined" || insertHere === -1);
    if (useInsert)
    {
        var size = tSize * (nameList.length + 1) + 8 + strCode.byteCount(); //6 in between is for the Return code and a gap

        insertHere = Exe.FindSpace(size);
        if (insertHere === -1)
            return "ALL: Not enough free space";
    }

    //Step 2.4 - Get the VIRTUAL equivalent of insertHere
    var insertVirl = Exe.Real2Virl(insertHere);

    //Step 3.1 - Create a JMP at jmpHere to insertVirl
    Exe.ReplaceHex(jmpHere, "90 E9" + Num2Hex(insertVirl - Exe.Real2Virl(jmpHere + 6, CODE)));

    //Step 3.2 - Construct the file loader code for all the files in nameList using the template
    var code = "";
    var callOffset = insertVirl + tSize;//First CALL location
    var strOffset = insertVirl + (nameList.length + 1) * tSize + 8;//Location of First string

    for (var i = 0; i < nameList.length; i++)
    {
        code += SetValue(template, 1, strOffset);
        code  = SetValue(code, 2, fileLoader - callOffset);

        strOffset += nameList[i].length + 1;//1 For NULL
        callOffset += tSize;
    }

    //Step 3.3 - Append the file loader for the referFile
    code += SetValue(template, 1, refHex);
    code  = SetValue(code, 2, fileLoader - callOffset);

    //Step 3.4 - Append the return
    code +=
        " 68" + Num2Hex(retnHere) //PUSH retnHere
    +   " C3"                     //RETN; this will make it jump to retnHere
    +   " 00 00"                  //A gap before the strings start
    ;

    //Step 3.5 - Insert the code & strCode
    if (useInsert)
        Exe.InsertHex(insertHere, code + strCode, size);
    else
        Exe.ReplaceHex(insertHere, code + strCode);

    return insertHere;
}