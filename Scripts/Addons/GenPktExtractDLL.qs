//#################################################################################\\
//# Generate Packet Length Extractor DLL for loaded client using the template DLL #\\
//# (ws2_pe.dll). Along with the Packet Keys for new clients                      #\\
//#################################################################################\\

function GenPktExtractDLL() //Planning to shift this into PEEK instead of here . To Do - Really Old clients have some variations in some of the patterns
{
	//Step 1.1 - Find the GetPacketSize function call
	var code =
		" E8 ?? ?? ?? ??" //CALL CRagConnection::GetPacketSize
	+   " 50"             //PUSH EAX
	+   " E8 ?? ?? ?? ??" //CALL CRagConnection::instanceR
	+   " 8B C8"          //MOV ECX, EAX
	+   " E8 ?? ?? ?? ??" //CALL CRagConnection::SendPacket
	+   " 6A 01"          //PUSH 1
	+   " E8"             //CALL CConnection::SetBlock
	;

	var offset = Exe.FindHex(code);
	if (offset === -1)
		throw "SendPacket not found";

	//Step 1.2 - Look for packet key pushes before it. if not present look for the combo function that both encrypts and retrieves the packet keys
	code =
        " 8B 0D ?? ?? ?? 00" //MOV ECX, DWORD PTR DS:[addr1]
	+   " 68 ?? ?? ?? ??"    //PUSH key3
	+   " 68 ?? ?? ?? ??"    //PUSH key2
	+   " 68 ?? ?? ?? ??"    //PUSH key1
	+   " E8"                //CALL encryptor
	;
	var offset2 = Exe.FindHex(code, offset - 0x100, offset);
	var KeyFetcher = 0;

	if (offset2 === -1)
    {
		code =
            " 8B 0D ?? ?? ?? 00" //MOV ecx, DS:[ADDR1] dont care what
        +   " 6A 01"             //PUSH 1
        +   " E8"                //CALL combofunction - encryptor and key fetcher combined.
        ;
		offset2 = Exe.FindHex(code, offset - 0x100, offset);
		KeyFetcher = -1;
	}	
	if (offset2 !== -1 && KeyFetcher === -1)
    {
		offset2 += code.byteCount();
		KeyFetcher = Exe.Real2Virl(offset2 + 4) + Exe.GetInt32(offset2);
	}

	//Step 1.3 - Go Inside the function
	offset += 5 + Exe.GetInt32(offset + 1);

	//Step 1.4 - Look for g_PacketLenMap reference and the pktLen function call following it
	code =
        " B9 ?? ?? ?? 00" //MOV ECX, g_PacketLenMap
	+   " E8 ?? ?? ?? ??" //CALL addr; gets the address pointing to the packet followed by len
	+   " 8B ?? 04"       //MOV reg32_A, [EAX+4]
	;

	offset = Exe.FindHex(code, offset, offset + 0x60);
	if (offset === -1)
		throw "g_PacketLenMap not found";

	//Step 1.5 - Extract the g_PacketLenMap assignment
	var gPacketLenMap = Exe.GetHex(offset, 5);

	//Step 2.1 - Go inside the pktLen function following the assignment
	offset += 10 + Exe.GetInt32(offset + 6);

	//Step 2.2 - Look for the pattern that checks the length with -1
	code =
		" 8B ?? ??" //MOV reg32_A, DWORD DS:[reg32_B+lenOff]; lenOff = pktOff+4
	+   " 83 ?? FF" //CMP reg32_A, -1
	+   " 75 ??"    //JNE addr
	+   " 8B"       //MOV reg32_A, DWORD DS:[reg32_B+lenOff+4]
	;

	offset2 = Exe.FindHex(code, offset, offset + 0x60);
	if (offset2 === -1)
		throw "PktOff not found";

	//Step 2.3 - Extract the displacement - 4 which will be PktOff
	var PktOff = Exe.GetInt8(offset2 + 2) - 4;

	//Step 3.1 - Find the InitPacketMap function using g_PacketLenMap extracted
	code =
		gPacketLenMap
	+   " E8 ?? ?? ?? ??" //CALL CRagConnection::InitPacketMap
	+   " 68 ?? ?? ?? 00" //PUSH addr1
	+   " E8 ?? ?? ?? ??" //CALL addr2
	+   " 59"             //POP ECX
	+   " C3"             //RETN
	;

	offset = Exe.FindHex(code);
	if (offset === -1)
		throw "InitPacketMap not found";

	//Step 3.2 - Save the address after the call which will serve as the ExitAddr
	var ExitAddr = Exe.Real2Virl(offset + 15);

	//Step 3.3 - Go Inside InitPacketMap
	offset += 10 + Exe.GetInt32(offset + 6);

	//Step 3.4 - Look for InitPacketLenWithClient call
	code =
		" 8B CE"          //MOV ECX, ESI
	+   " E8 ?? ?? ?? ??" //CALL InitPacketLenWithClient
	+   " C7"             //MOV DWORD PTR SS:[LOCAL.x], -1
	;
	offset = Exe.FindHex(code, offset, offset + 0x140);
	if (offset === -1)
		throw "InitPacketLenWithClient not found";

	//Step 3.5 - Go Inside InitPacketLenWithClient
	offset += 7 + Exe.GetInt32(offset + 3);

	//Step 4.1 - Now comes the tricky part. We need to get all the functions called till a repeat is found.
	//          Last unrepeated call is the std::map function we need
	var funcs = [];
	while(1)
    {
		offset = Exe.FindHex("E8 ?? ?? FF FF", offset + 1);//CALL std::map
		if (offset === -1)
            break;

		var func = (offset + 5) + Exe.GetInt32(offset + 1);
		if (funcs.indexOf(func) !== -1)
            break;

		funcs.push(func);
	}

	if (offset === -1 || funcs.length === 0)
		throw "std::map not found";

	//Step 4.2 - Go Inside std::map
	offset = funcs[funcs.length-1];

	//Step 4.3 - Look for all calls to std::_tree (should be either 1 or 2 calls)
	//          The called Locations serve as our Hook Addresses
	code =
		" E8 ?? ?? FF FF" //CALL std::_tree
	+   " 8B ??"          //MOV reg32_A, [EAX]
	+   " 8B"             //MOV EAX, DWORD PTR SS:[ARG.1]
	;

	var HookAddrs = Exe.FindAllHex(code, offset, offset + 0x100);
	if (HookAddrs.length < 1 || HookAddrs.length > 2)
		throw "std::_tree call count is different";

	//Step 5.1 - Get the DLL file
	var Fp = new File();
	if (!Fp.Open(APP_PATH + "Inputs/ws2_pe.dll", 'rb'))
		throw "Base File - ws2_pe.dll is missing from Input folder";

	//Step 5.2 - Read the entire contents
	var dllHex = Fp.ReadHex(0);
	Fp.Close();

	//Step 5.3 - Replace the Filename template
	dllHex = dllHex.replace(" 64".repeat(8), Ascii2Hex("" + Exe.GetDate()));//FileName

	//Step 5.4 - Replace all the addresses and PktOff
	code =
		Num2Hex(PktOff)
	+   Num2Hex(ExitAddr)
	+   Num2Hex(Exe.Real2Virl(HookAddrs[0]))
    ;

	if (HookAddrs.length === 1)
		code += " 00 00 00 00";
	else
		code += Num2Hex(Exe.Real2Virl(HookAddrs[1]));

	code += Num2Hex(KeyFetcher);

	dllHex = dllHex.replace(/ 01 FF 00 FF 02 FF 00 FF 03 FF 00 FF 04 FF 00 FF 05 FF 00 FF/i, code);

	//Step 5.5 - Write out the filled up contents
	if (!Fp.Open(APP_PATH + "Outputs/ws2_pe_" + Exe.GetDate() + ".dll", 'wb'))
		throw "Unable to create output file";

	Fp.WriteHex(0, dllHex);
	Fp.Close();

	return "DLL has been generated - Dont forget to rename it.";
}

//==================================================================================//
// How to use - client in hex editor and replace all occurances of ws2_32 to ws2_pe //
//              copy the generated dll to Client area and rename it to ws2_pe.dll   //
//              Run the client. It will Extract the packets and auto-close.         //
//==================================================================================//