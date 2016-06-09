//##########################################################\\
//# Change the Hardcoded table loading of Homunculus names #\\
//# to Lua based loading using "ReqJobName" function.      #\\
//##########################################################\\

MaxHomun = 7000;
function EnableCustomHomunculus() //Work In Progress?
{
    //Step 1.1 - Find "LIF"
    var offset = Exe.FindString("LIF", VIRTUAL);
    if (offset === -1)
        return "Failed in Step 1 - LIF not found";

    //Step 1.2 - Find its reference - This is where all the homunculus names are loaded into the table.
    var code = "C7 ?? C4 5D 00 00" + Num2Hex(offset); //MOV DWORD PTR DS:[reg32_A+5DC4], OFFSET addr; ASCII "LIF"

    var hookLoc = Exe.FindHex(code);
    if (hookLoc === -1)
        return "Failed in Step 1 - homun code not found";

    //Step 1.3 - Check if LangType is available (LT.Error will be a string if not)
    if (LT.Error)
        return "Failed in Step 1 - " + LT.Error;

    //Step 2.1 - Extract reference Register, reference Offset and current Register from the instruction before hookLoc
    //           MOV curReg, DWORD PTR DS:[refReg + refOff]
    if (Exe.GetInt8(hookLoc - 2) === 0) //refOff != 0
    {
        var modrm = Exe.GetInt8(hookLoc - 5);
        var refOff = Exe.GetInt32(hookLoc - 4);
    }
    else //refOff == 0
    {
        var modrm = Exe.GetInt8(hookLoc - 1);
        var refOff = 0;
    }
    var refReg = modrm & 0x7;
    var curReg = (modrm & 0x38) >> 3;

    //Step 2.2 - Find Location after the Table assignments which is the location to jump to after lua based loading
    //           Also extract all non-table related instuctions in between
    var details = ExtractTillEnd(hookLoc + code.byteCount(), refReg, refOff, curReg, CheckHomunEoT);

    //Step 2.3 - Find "ReqJobName"
    //Get the current lua caller code for Job Name i.e. ReqJobName calls
    offset = Exe.FindString("ReqJobName", VIRTUAL);
    if (offset === -1)
        return "Failed in Step 2 - ReqJobName not found";

    //Step 3.1 - Construct the code to replace with
    code =
        Num2Hex(0x50 + curReg, 1) //PUSH curReg
    +   " 60"                     //PUSHAD
    +   " BF 71 17 00 00"         //MOV EDI, 1771
    +   " BB" + Num2Hex(MaxHomun) //MOV EBX, MaxHomun
    ;
    var csize = code.byteCount();

    code += GenLuaCaller(hookLoc + csize, "RegJobName", offset, "d>s", " 57");
    code +=
        " 8A 08"       //MOV CL, BYTE PTR DS:[EAX]
    +   " 84 C9"       //TEST CL, CL
    +   " 74 07"       //JE SHORT addr
    +   " 8B 4C 24 20" //MOV ECX, DWORD PTR SS:[ESP+20]
    +   " 89 04 B9"    //MOV DWORD PTR DS:[EDI*4+ECX], EAX
    +   " 47"          //INC EDI; addr
    +   " 39 DF"       //CMP EDI,EBX
    +   " 7E"          //JLE SHORT addr2; to start of GenLuaCaller code
    ;
    code += Num2Hex(csize - (code.byteCount() + 1), 1);
    code +=
        " 61"          //POPAD
    +   " 83 C4 04"    //ADD ESP, 4
    +   details.Code
    ;
    code += " E9" + Num2Hex(details.EndOff - (hookLoc + code.byteCount() + 5));

    //Step 3.2 - Replace at hookLoc
    Exe.ReplaceHex(hookLoc, code);

    //Step 4.1 - Find the homun limiter code for right click menu.
    code =
        " 05 8F E8 FF FF" //SUB EAX, 1771
    +   " B9 33 00 00 00" //MOV ECX, 33
    ;

    offset = Exe.FindHex(code);
    if (offset !== -1)
    {
        //Step 4.2 - Replace the 33 with MaxHomun - 6001
        Exe.ReplaceInt32(offset + 6, MaxHomun - 6001);
        return true;
    }

    //Step 4.3 - Find the limiter for Older clients
    code =
        " 3D 70 17 00 00" //CMP EAX, 1770
    +   " 7E 10"          //JLE SHORT addr
    +   " 3D A5 17 00 00" //CMP EAX, 17A5
    ;

    offset = Exe.FindHex(code);
    if (offset === -1)
        return "Failed in Step 4";

    //Step 4.4 - Replace 17A5 with MaxHomun
    Exe.ReplaceInt32(offset + code.byteCount() - 4, MaxHomun);
    return true;
}

//######################################################################\\
//# Check whether End of Homunculus Table assignments has been reached #\\
//# at the supplied offset. Used as argument to ExtractTillEnd         #\\
//######################################################################\\

function CheckHomunEoT(hash, offset)
{
    //SUB reg32_A, reg32_B
    //SAR reg32_A, 2
    if (hash.OpCode === 0x2B && Exe.GetUint8(offset + 2) === 0xC1 && Exe.GetUint8(offset + 4) === 0x02)
        return true;

    //TEST reg32_A, reg32_A
    //JZ SHORT addr
    if (hash.Opcode === 0x85 && Exe.GetUint8(offset + 2) === 0x74)
        return true;

    return false;
}