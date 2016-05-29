 //##################################################################\\
 //# Change the filename references used for Level99 Aura effect    #\\
 //# ring_blue.tga -> aurafloat.tga , pikapika2.bmp -> auraring.bmp #\\
 //##################################################################\\

function UseCustomAuraSprites()
{
    //Step 1.1 - Find "effect\ring_blue.tga"
    var offset = Exe.FindString("effect\\ring_blue.tga", VIRTUAL, false);//false for not prefixing zero.
    if (offset === -1)
        return "Failed in Step 1 - ring_blue.tga not found";

    var rblue = Num2Hex(offset);

    //Step 1.2 - Find "effect\pikapika2.bmp"
    offset = Exe.FindString("effect\\pikapika2.bmp", VIRTUAL, false);//false for not prefixing zero.
    if (offset === -1)
        return "Failed in Step 1 - pikapika2.bmp not found";

    var ppika2 = Num2Hex(offset);

    //Step 1.3 - Prep replacement strings
    var strAF = "effect\\aurafloat.tga\x00";
    var strAR = "effect\\auraring.bmp\x00";
    var size = strAF.length + strAR.length;

    //Step 1.4 - Find Free space for insertion
    var free = Exe.FindSpace(size);
    if (free === -1)
        return "Failed in Step 1 - Not enough free space";

    var freeVirl = Exe.Real2Virl(free, DIFF);

    //Step 1.5 - Insert the strings into free space
    Exe.InsertHex(free, Ascii2Hex(strAF + strAR), size);

    //Step 1.6 - Convert the two string addresses to Little Endian format
    var offsetAF = freeVirl;
    var offsetAR = freeVirl + strAF.length;

    //Step 2.1 - Prep code to find the string references
    var template =
        " 68" + MakeVar(1) //PUSH OFFSET addr
    +   " 8B ??"           //MOV ECX, reg32_A
    +   " E8 ?? ?? ?? ??"  //CALL addr2
    +   " E9 ?? ?? ?? ??"  //JMP addr3
    ;
    var code1 = SetValue(template, 1, rblue);  //addr => ASCII "effect\ring_blue.tga"
    var code2 = SetValue(template, 1, ppika2); //addr => ASCII "effect\pikapika2.bmp"
    var c2Off = template.byteCount() + 2;

    //Step 2.2 - Find the reference of both where they are used to display the aura
    offset = Exe.FindHex(code1 + " ??" + code2);//PUSH reg32_B in between
    if (offset === -1)
    {
        offset = Exe.FindHex(code1 + " 6A 00" + code2);//PUSH 0 in between
        c2Off++;
    }
    if (offset === -1)
        return "Failed in Step 2";

    //Step 2.3 - Replace the two string addresses.
    Exe.ReplaceInt32(offset + 1, offsetAF);
    Exe.ReplaceInt32(offset + c2Off, offsetAR);

    ///===========================================///
    /// For new clients above is left unused but  ///
    /// we are still going to keep it as failsafe ///
    ///===========================================///

    //Step 3.1 - Look for the second pattern in the new clients.
    code =
        " 56"             //PUSH ESI
    +   " 8B F1"          //MOV ESI, ECX
    +   " E8 ?? ?? FF FF" //CALL addr1
    +   " 8B CE"          //MOV ECX, ESI
    +   " 5E"             //POP ESI
    +   " E9 ?? ?? FF FF" //JMP addr2
    ;

    var offsets = Exe.FindAllHex(code);
    var offsetR = -1;
    var offsetP = -1;

    //Step 3.2 - Find the pattern that calls pikapika2 effect followed by ring_blue.
    for (var i = 0; i < offsets.length; i++)
    {
        offset = offsets[i] + 8 +  Exe.GetInt32(offsets[i] + 4);
        offsetP = Exe.FindHex("68" + ppika2, offset, offset + 0x100);

        offset = offsets[i] + 16 + Exe.GetInt32(offsets[i] + 12);
        offsetR = Exe.FindHex("68" + rblue, offset, offset + 0x120);

        if (offsetP !== -1 && offsetR !== -1)
            break;
    }

    //Step 3.3 - Replace the two string addresses.
    if (offsetP !== -1 && offsetR !== -1)
    {
        Exe.ReplaceInt32(offsetR + 1, offsetAF);
        Exe.ReplaceInt32(offsetP + 1, offsetAR);
    }
    return true;
}