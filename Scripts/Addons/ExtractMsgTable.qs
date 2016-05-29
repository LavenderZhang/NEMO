//###################################################################################################
//# Extract the Hardcoded Msgstringtable in the loaded client translated using the reference tables #
//###################################################################################################

function ExtractMsgTable()
{
	//Step 1.1 - Find "msgStringTable.txt"
	var offset = Exe.FindString("msgStringTable.txt", VIRTUAL);
	if (offset === -1)
		throw "Error: msgStringTable.txt missing";

	//Step 1.2 - Find its reference
	offset = Exe.FindHex("68" + Num2Hex(offset) + " 68");
	if (offset === -1)
		throw "Error: msgStringTable.txt reference missing";

	//Step 1.3 - Find the msgstring push after it
	code =
        " 73 05"                //JAE SHORT addr1 -> after JMP below
	+   " 8B ?? ??"             //MOV reg32_A, DWORD PTR DS:[reg32_B*4 + reg32_C]
	+   " EB ??"                //JMP SHORT addr2
	+   " 8B ?? ?? ?? ?? ?? 00" //MOV reg32_D, DWORD PTR DS:[reg32_B*8 + tblAddr]
	;
	var offset2 = Exe.FindHex(code, offset + 10, offset + 80);

	if (offset2 === -1) //Newest Clients
    {
		code = code.replace("?? 8B ??", "?? FF ??");//Change MOV reg32_D with PUSH
		offset2 = Exe.FindHex(code, offset + 10, offset + 80);
	}
	if (offset2 === -1) //Old clients
    {
		code =
            " 33 F6"          //XOR ESI, ESI
		+   " ?? ?? ?? ?? 00" //MOV reg32_A, tblAddr
		;
		offset2 = Exe.FindHex(code, offset + 10, offset + 30);

		if (offset2 != -1 && (Exe.GetInt8(offset2 + 2) & 0xB8) != 0xB8) //Checking the opcode is within 0xB8-0xBF
        {
            offset2 = -1;
		}
	}
	if (offset2 === -1)
		throw "Error: msgString LUT missing";

	//Step 1.4 - Extract the tblAddr
	offset = Exe.Virl2Real(Exe.GetInt32(offset2 + code.byteCount() - 4)) - 4;

	//Step 2.1 - Read the reference strings from file (Korean original in hex format)
	var refList = [];
	var msgStr = "";

	var Fp = new File();
	Fp.Open(APP_PATH + "Inputs/msgStringRef.txt", 'r');
	while (!Fp.IsEOF())
    {
		var parts = Fp.ReadLine().split('#');
		for (var i = 1; i <= parts.length; i++)
        {
            msgStr += parts[i - 1].replace(/\\r/g, " 0D").replace(/\\n/g, " 0A");
            if (i < parts.length)
            {
                refList.push(Hex2Ascii(msgStr));
                msgStr = "";
            }
		}
	}
	Fp.Close();

	//Step 2.2 - Read the translated strings from file (English regular text)
	msgStr = "";
	var index = 0;
	var engMap = {};

	Fp.Open(APP_PATH + "Inputs/msgStringEng.txt", 'r');
	while (!Fp.IsEOF())
    {
		var parts = Fp.ReadLine().split('#');
		for (var i = 1; i <= parts.length; i++)
        {
            msgStr += parts[i-1];
            if (i < parts.length)
            {
                engMap[refList[index]] = msgStr;
                msgStr = "";
                index++;
            }
		}
	}
	Fp.Close();

	//Step 3 - Loop through the table inside the client - Each Entry
	var done = false;
	var id = 0;

	Fp.Open(APP_PATH + "Outputs/msgstringtable_" + Exe.GetDate() + ".txt", 'w');
	while (!done)
    {
		if (Exe.GetInt32(offset) === id)
        {
            //Step 3.1 - Get the string for the current id
			var strOffset = Exe.Virl2Real(Exe.GetInt32(offset + 4));
            msgStr = Exe.GetString(strOffset);

            //Step 3.2 - Map the Korean string to English
            if (engMap[msgStr])
                Fp.WriteLine(engMap[msgStr] + "#");
            else
                Fp.WriteLine(msgStr + "#");

			offset += 8;
			id++;
		}
		else
        {
			done = true;
		}
	}
	Fp.Close();

	return "Msgstringtable has been Extracted to Output folder";
}