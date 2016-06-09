//########################################################\\
//# Change the Flag Emote callers for Ctrl+1 - Ctrl+9 in #\\
//# function called from UIWindowMgr::ProcessPushButton  #\\
//########################################################\\

function EnableFlagEmotes() //The function is not present in pre-2010 clients
{
    //Step 1.1 - Find the switch case selector for all the flag Emote callers
    var code =
        " 05 2E FF FF FF"    //ADD EAX,-D2
    +   " 83 F8 08"          //CMP EAX, 08
    +   " 0F 87 ?? ?? 00 00" //JA addr -> skip showing emotes
    +   " FF 24 85"          //JMP DWORD PTR DS:[EAX*4+refAddr]
    ;
    var offset = Exe.FindHex(code);

    if (offset === -1)
    {
        code = code.replace("05 2E FF FF FF", "83 C0 ??"); //change ADD EAX, -D2 to ADD EAX, -54
        offset = Exe.FindHex(code);
    }
    if (offset === -1)
        return "Failed in Step 1 - switch not found";

    //Step 1.2 - Extract the refAddr
    var refAddr = Exe.Virl2Real(Exe.GetInt32(offset + code.byteCount()));

    //Step 2.1 - Get Input file containing the list of Flag Emotes per key
    var Fp = MakeFile('$inpFlag', "File Input - Enable Flag Emoticons", "Enter the Flags list file", APP_PATH + "Inputs/flags.txt");
    if (!Fp)
        return "Patch Cancelled";

    //Step 2.2 - Open the file and read all the entries into an array
    var consts = [];
    while (!Fp.IsEOF())
    {
        var line = Fp.ReadLine().trim();
        var matches = line.match(/(\d)\s*=\s*(\d+)/);
        if (!matches)
            continue;

        var key = parseInt(matches[1]);
        var val = parseInt(matches[2]);
        consts[key] = val;
    }
    //Step 2.3 - Close the file
    Fp.Close();

    //Step 3.1 - Check if LangType is available (LT.Error will be a string if not)
    if (LT.Error)
        return "Failed in Step 3 - " + LT.Error;

    //Step 3.2 - Prep code that is part of each case (common portions that we need)
    code =
        " A1" + LT.Hex //MOV EAX, DS:[g_servicetype]
    +   " 85 C0"       //TEST EAX, EAX
    ;                  //JZ SHORT addr or JZ addr

    var code2 =
        " 6A 00" //PUSH 0
    +   " 6A 00" //PUSH 0
    +   " 6A ??" //PUSH emoteConstant
    +   " 6A 1F" //PUSH 1F
    +   " FF"    //CALL EDX or CALL DWORD PTR DS:[EAX+const]
    ;

    for (var i = 1; i < 10; i++)
    {
        //Step 3.3 - Get the starting address of the case
        var offset = Exe.Virl2Real(Exe.GetInt32(refAddr + (i - 1)*4));

        //Step 3.4 - Find the first code. Ideally it would be at offset itself unless something changed
        offset = Exe.FindHex(code, offset);
        if (offset === -1)
            return "Failed in Step 3 - First part missing : " + i;

        //Step 3.5 - Update offset to location after TEST (which should be a JZ)
        offset += code.byteCount();

        //Step 3.6 - Change the JZ to JMP & Goto the JMPed address
        if (Exe.GetInt8(offset) === 0x0F) //Long JZ
        {
            Exe.ReplaceHex(offset, " 90 E9");
            offset += Exe.GetInt32(offset + 2) + 6;
        }
        else //Short JZ
        {
            Exe.ReplaceInt8(offset, 0xEB);
            offset += Exe.GetInt8(offset + 1) + 2;
        }

        if (consts[i])
        {
            //Step 3.7 - Find the second code.
            offset = Exe.FindHex(code2, offset);
            if (offset === -1)
                return "Failed in Step 3 - Second part missing : " + i;

            //Step 3.8 - Replace the emoteConstant with the one we read from input file.
            Exe.ReplaceHex(offset + code2.byteCount() - 4, consts[i].toString(16));
        }
    }
    return true;
}