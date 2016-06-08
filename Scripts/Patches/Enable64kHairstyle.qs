//###########################################\\
//# Disable hard-coded hair style table and #\\
//# generate hair style IDs ad-hoc instead  #\\
//###########################################\\

function Enable64kHairstyle()
{
    //Step 1.1 - Find the format Strings
    var formats = [
        "\xB8\xD3\xB8\xAE\\\xB8\xD3\xB8\xAE%s_%s_%d.pal",                                         //Head Palette
        "\xC0\xCE\xB0\xA3\xC1\xB7\\\xB8\xD3\xB8\xAE\xC5\xEB\\%s\\%s_%s.%s",                       //Hairstyle sprite & act
        "\xBE\xC7\xBC\xBC\xBB\xE7\xB8\xAE\\%s\\%s_\xB9\xE8\xC6\xB2\xBF\xC2\xB6\xF3\xC0\xCE%s.%s", //Unknown but depends on hairstyle number
        "\xBE\xC7\xBC\xBC\xBB\xE7\xB8\xAE\\%s\\%s%s.%s",                                          //Unknown2 but depends on hairstyle number
    ];

    var strOffs = [];
    for (var i = 0; i < formats.length; i++)
    {
        strOffs[i] = Exe.FindString(formats[i], REAL);
        if (strOffs[i] === -1 && i == 1)
        {
            formats[i] = "\\\xB8\xD3\xB8\xAE\xC5\xEB\\%s\\%s_%s.%s";
            strOffs[i] = Exe.FindString(formats[i], REAL);
        }
        if (strOffs[i] === -1)
            break;
    }
    if (i !== formats.length)
        return "Failed in Step 1 - One of the formats is missing";

    //Step 1.2 - Replace %s with %u in relevant positions
    Exe.ReplaceInt8(strOffs[0] + 10, 0x75); //1st one
    Exe.ReplaceInt8(strOffs[1] + formats[1].length - 7, 0x75);//2nd one
    Exe.ReplaceInt8(strOffs[2] + 10, 0x75); //1st one
    Exe.ReplaceInt8(strOffs[2] + 13, 0x75); //2nd one
    Exe.ReplaceInt8(strOffs[3] + 10, 0x75); //1st one
    Exe.ReplaceInt8(strOffs[3] + 13, 0x75); //2nd one

    //Step 1.3 - Find their references (PUSHes)
    for (var i = 0; i < strOffs.length; i++)
    {
        strOffs[i] = Exe.FindHex("68" + Num2Hex(Exe.Real2Virl(strOffs[i])));
        if (strOffs[i] === -1)
            break;
    }
    if (i !== strOffs.length)
        return "Failed in Step 1 - One or more references missing";

    //Step 2.1 - Find the code which utilizes the two table addresses (tblAddr1 & tblAddr2)
    var code =
        " 8B ?? ?? ?? ?? 00" //MOV reg32_A, DWORD PTR DS:[tblAddr1]
    +   " EB 0A"             //JMP SHORT addr
    +   " ?? ??"             //CMP reg32_B, reg32_C or TEST reg32_B, reg32_B
    +   " 75 ??"             //JNE SHORT addr2
    +   " 8B ?? ?? ?? ?? 00" //MOV reg32_A, DWORD PTR DS:[tblAddr2]
    +   " 8B 45 00"          //MOV reg32_D, DWORD PTR SS:[EBP] <= addr
    +   " 8B"                //MOV reg32_E, DWORD PTR DS:[reg32_D*4 + reg32_A]
    ;
    var type = 1;
    var offset = Exe.FindHex(code, strOffs[1] - 0xA0, strOffs[1] - 0x70); //VC9 pattern

    if (offset === -1)
    {
        code =
            " 8B ?? ?? ?? ?? 00" //MOV reg32_A, DWORD PTR DS:[refAddr]
        +   " 8B ?? ??"          //MOV reg32_E, DWORD PTR DS:[reg32_D*4 + reg32_A]
        +   " 8B"                //MOV reg32_D, reg32_E
        ;
        type = 2;
        offset = Exe.FindHex(code, strOffs[1] - 0xC0, strOffs[1] - 0x90); //VC10 pattern
    }
    if (offset === -1)
    {
        code = code.replace("8B ??", "A1"); //reg32_A is EAX
        code = code.replace("?? 8B", "?? 80");//Change the last MOV to CMP BYTE PTR DS:[reg32_E], 0
        type = 3;
        offset = Exe.FindHex(code, strOffs[1] - 0xD0, strOffs[1] - 0x90); //VC11 pattern
    }
    if (offset === -1)
        return "Failed in Step 2 - Table access code missing";

    //Step 2.2 - Extract the table Addresses
    if (type === 1)
    {
        var tblAddr1 = Exe.GetHex(offset + 02, 4);
        var tblAddr2 = Exe.GetHex(offset + 14, 4);
    }
    else
    {
        var offset2 = Exe.FindHex(code, offset + code.byteCount(), strOffs[1] - 0x90);
        if (offset2 === -1)
            return "Failed in Step 2 - Second RefAddr missing";

        if (type === 2)
        {
            var tblAddr1 = Exe.GetHex(offset + 2, 4);
            var tblAddr2 = Exe.GetHex(offset2 + 2, 4);
        }
        else
        {
            var tblAddr1 = Exe.GetHex(offset + 1, 4);
            var tblAddr2 = Exe.GetHex(offset2 + 1, 4);
        }
    }

    //Step 2.3 - Find space for inserting 4 bytes (to serve as saveAddr)
    var free = Exe.FindSpace(4);
    if (free === -1)
        return "Failed in Step 2 - Not enough free space";

    //Step 2.4 - Do a zero insert so it is locked by the patch
    Exe.InsertHex(free, "00 00 00 00", 4);

    //Step 2.5 - Save the address
    var saveAddr = Num2Hex(Exe.Real2Virl(free));

    //Step 2.6 - Find all the references to tblAddr2 (tblAddr1 reference is above it)
    code =
        tblAddr2 //MOV reg32_A, DWORD PTR DS:[tblAddr2]
    +   " 8B"    //MOV reg32_E, DWORD PTR DS:[reg32_D*4 + reg32_A] or MOV reg32_D, SS:[LOCAL.x]
    ;

    var offsets = Exe.FindAllHex(code);
    if (offsets.length !== 3)
        return "Failed in Step 2 - Extra/Less matches found";

    for (var i = 0; i < 3; i++)
    {
        //Step 3.1 - Fix the Lookup for tblAddr2
        var instr = {"Prefix": ""};
        var result = __FixLookup(offsets[i], saveAddr, instr);
        if (typeof(result) === "string")
            return "Failed in Step 3.1 (" + i + ") - " + result;

        //Step 3.2 - Find the tblAddr1 reference before tblAddr2
        offset = Exe.FindHex(tblAddr1 + " 8B", offsets[i] - 0x40, offsets[i] - 2);
        if (offset === -1)
            offset = Exe.FindHex(tblAddr1 + " EB", offsets[i] - 0x40, offsets[i] - 2);//only for VC9
        else
            instr = {"Prefix": ""};

        if (offset === -1)
            return "Failed in Step 3.2 (" + i + ") - First table reference missing";

        //Step 3.3 - Repeat 3.1 for tblAddr1
        result = __FixLookup(offset, saveAddr, instr);
        if (typeof(result) === "string")
            return "Failed in Step 3.3 (" + i + ") - " + result;
    }
    for (var i = 0; i < 3; i++)
    {
        //Step 4.1 - Find the CALL after PUSH OFFSET
        offset = Exe.FindHex("E8", strOffs[i] + 5, strOffs[i] + 15);
        if (offset === -1)
            return "Failed in Step 4.1 - " + i + " : CALL missing after reference";

        var afterCall = Exe.Real2Virl(offset + 5);

        //Step 4.2 - Prep Function code for changing the Arguments
        code =
            " 50"              //PUSH EAX
        +   " A1" + saveAddr   //MOV EAX, DWORD PTR DS:[saveAddr]
        +   " 89 44 24 10"     //MOV DWORD PTR SS:[ESP+x], EAX ; x is 14 or
        +   " 89 44 24 14"     //MOV DWORD PTR SS:[ESP+y], EAX ; y is 18
        +   " 58"              //POP EAX
        +   " E9" + MakeVar(1) //JMP origFunc
        ;

        //Step 4.3 - Remove unnecessary MOVs
        if (i === 1)
            code = code.replace(" 89 44 24 10", "");

        if (i === 0)
            code = code.replace(" 89 44 24 14", "");

        var csize = code.byteCount();

        //Step 4.4 - Find free space for insertion
        free = Exe.FindSpace(csize);
        if (free === -1)
            return "Failed in Step 4.4 - " + i + " : Not enough free space";

        var freeVirl = Exe.Real2Virl(free);

        //Step 4.5 - Fill in the blanks
        code = SetValue(code, 1, afterCall + Exe.GetInt32(offset + 1) - (freeVirl + csize));

        //Step 4.6 - Insert the code at free space
        Exe.InsertHex(free, code, csize);

        //Step 4.7 - Update the CALL
        Exe.ReplaceInt32(offset + 1, freeVirl - afterCall);
    }

    //Step 5.1 - Find the Limiting comparison for hairstyle spr+act
    if (type === 1)
    {
        code =
            " 3B ??"                //CMP reg32_A, reg32_B
        +   " 8B ??"                //MOV reg32_C, reg32_D
        +   " 89 ?? 24 ??"          //MOV DWORD PTR SS:[LOCAL.x], reg32_E
        +   " 7C 05"                //JL SHORT addr
        +   " 83 ?? 1B"             //CMP reg32_A, 1B
        +   " 7E 07"                //JLE SHORT addr2
        +   " C7 45 00 0D 00 00 00" //MOV DWORD PTR SS:[EBP], 0D ; addr
        ;
        var pos = code.byteCount() - 9;
    }
    else if (type === 2)
    {
        code =
            " 3B ??"             //CMP reg32_A, reg32_B
        +   " 7C 05"             //JL SHORT addr
        +   " 83 ?? 1D"          //CMP reg32_A, 1D
        +   " 7E 06"             //JLE SHORT addr2
        +   " C7 ?? 0D 00 00 00" //MOV DWORD PTR DS:[reg32_C], 0D ; addr
        ;
        var pos = code.byteCount() - 8;
    }
    else
    {
        code =
            " 85 ??"             //TEST reg32_A, reg32_A
        +   " 78 05"             //JS SHORT addr
        +   " 83 F8 1D"          //CMP reg32_A, 1D
        +   " 7E 06"             //JLE SHORT addr2
        +   " C7 ?? 0D 00 00 00" //MOV DWORD PTR DS:[reg32_C], 0D ; addr
        ;
        var pos = code.byteCount() - 8;
    }
    offset = Exe.FindHex(code, strOffs[1] - 0x400, strOffs[1]);
    if (offset === -1)
        return "Failed in Step 5 - First comparison missing";

    //Step 5.2 - Change the JLE to JMP
    Exe.ReplaceInt8(offset + pos, 0xEB);

    //Step 5.3 - Find the Limiting comparison for the unknown stuff
    code =
        " B9 00 00 00" //CMP reg32_A, 0B9
    +   " 75 ??"       //JNE SHORT addr
    +   " 83 ?? 1B"    //CMP DWORD PTR DS:[reg32_B], 1B
    +   " 7E"          //JLE SHORT addr
    ;
    offset = Exe.FindHex(code, strOffs[2] - 0x400, strOffs[2]); //VC9 and early VC10

    if (offset === -1)
    {
        code =
            " B9 00 00 00" //CMP DWORD PTR SS:[LOCAL.x], 0B9
        +   " 75 ??"       //JNE SHORT addr
        +   " 83 7D ?? 10" //CMP DWORD PTR SS:[LOCAL.y], 10
        +   " 72"          //JB SHORT addr
        ;
        offset = Exe.FindHex(code, strOffs[2] - 0x400, strOffs[2]); //VC11 and late VC10
    }
    if (offset === -1)
        return "Failed in Step 5 - Second comparison missing";

    //Step 5.4 - Change the JLE/JB to JMP
    Exe.ReplaceInt8(offset + code.byteCount() - 1, 0xEB);
    return true;
}

function __FixLookup(offset, saveAddr, instr)
{
    //Step .1 - Check if reg32_A is EAX (for EAX opcode is A1 otherwise opcode is 8B modrm)
    if (Exe.GetUint8(offset - 1) === 0xA1)
    {
        offset--;
        var movSize = 5;
    }
    else
    {
        offset -= 2;
        var movSize = 6;
    }

    //Step .2 - Save VIRTUAL location after MOV
    var offVirl = Exe.Real2Virl(offset + movSize);

    //Step .3 - If instruction is not provided extract from location after MOV
    if (typeof(instr.OpCode) === "undefined")
    {
        var hash = GetInstruction(offset + movSize);
        hash.Prefix = "";
    }
    else
    {
        var hash = instr;
    }

    //Step .4 - If instruction is not a lookup (if not save it as a prefix)
    var prefix = hash.Prefix;
    if (hash.Mode !== 0 || hash.RMem !== 4)
    {
        prefix = Exe.GetHex(offset + movSize, hash.Size);
        hash = GetInstruction(offset + movSize + hash.Size);
    }

    //Step .5 - Check if the instruction is a lookup ( MOV reg32_E, DWORD PTR DS:[reg32_D*4 + reg32_A] )
    if (hash.OpCode !== 0x8B || hash.SIB === -1 || hash.Scale !== 4)
        return "Unknown opcode";

    //Step .6 - Prep function code for saving the hairstyle to saveAddr
    var code =
        prefix                      //MOV instruction if any in between the tblAddr assignment and table lookup
    +   " 89 XX" + saveAddr         //MOV DWORD PTR DS:[saveAddr], reg32_D
    +   Exe.GetHex(offset, movSize) //MOV DWORD PTR reg32_A, DS:[tblAddr]
    +   " E9" + MakeVar(1)          //JMP addr;
    ;
    var csize = code.byteCount();

    //Step .7 - Find space for insertion
    var free = Exe.FindSpace(csize);
    if (free === -1)
        return "Not enough free space";

    var freeVirl = Exe.Real2Virl(free);

    //Step .8 - Fill in the blanks
    code = code.replace(" XX", Num2Hex(0x05 | (hash.Index << 3), 1));
    code = SetValue(code, 1, offVirl - (freeVirl + csize));

    //Step .9 - Insert code into free space
    Exe.InsertHex(free, code, csize);

    //Step .10 - Prep code to the CALL the function and remove reg32_D*4 in the original lookup
    code = " E9" + MakeVar(1);

    if (Exe.GetUint8(offset + movSize) === 0x8B)
    {
        if (prefix !== "")
            code += " 90".repeat(prefix.byteCount());

        code +=
            " 8B" + Num2Hex((hash.ModRM & 0xF8) | hash.Base, 1)
        +   " 90"
        ;
    }
    if (Exe.GetUint8(offset) === 0x8B)
        code = " 90" + code;

    code = SetValue(code, 1, freeVirl - offVirl);

    //Step .11 - Replace it at offset
    Exe.ReplaceHex(offset, code);

    //Step .12 - Save relevant fields to 'instr'
    instr.OpCode  = hash.OpCode;
    instr.ModRM   = hash.ModRM;
    instr.SIB     = hash.SIB;

    instr.Mode    = hash.Mode;
    instr.RMem    = hash.RMem;

    instr.Scale   = hash.Scale;
    instr.Index   = hash.Index;
    instr.Base    = hash.Base;

    instr.Size    = hash.Size;
    instr.NextLoc = hash.NextLoc;
    instr.Prefix  = prefix;
    return true;
}

///=================================///
/// Disable for Unsupported Clients ///
///=================================///
function Enable64kHairstyle_()
{
    return (Exe.GetDate() > 20111102);
}