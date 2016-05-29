//#############################################################\\
//# Generate Curiosity's Map Effect Plugin for loaded client  #\\
//# using the template DLL (rdll2.asi) along with header file #\\
//#############################################################\\

function GenMapEffectPlugin()
{
	//Step 1 - Open the Template file (making sure it exists before anything else)
	var Fp = new File();
	if (!Fp.Open(APP_PATH + "Inputs/rdll2.asi", 'rb'))
		throw "Error: Base File - rdll2.asi is missing from Input folder";

	//Step 2.1 - Find "xmas_fild01.rsw"
	var offset = Exe.FindString("xmas_fild01.rsw", VIRTUAL);
	if (offset === -1)
		throw "Error: xmas_fild01 missing";

	//Step 2.2 - Find the CGameMode_Initialize_EntryPtr using the offset
	offset = Exe.FindHex(Num2Hex(offset) + " 8A");
	if (offset === -1)
		throw "Error: xmas_fild01 reference missing";

	//Step 2.3 - Save the EntryPtr address.
	var CI_Entry = offset - 1;

	//Step 3.1 - Look for g_Weather assignment before EntryPtr
	var code =
		" B9 ?? ?? ?? 00" //MOV ECX, g_Weather
    +   " E8"             //CALL CWeather::ScriptProcess
    ;

	offset = Exe.FindHex(code, CI_Entry - 0x10, CI_Entry);
	if (offset === -1)
		throw "Error: g_Weather assignment missing";

	//Step 3.2 - Save the g_Weather address
	var gWeather = Exe.GetHex(offset + 1, 4);

	//Step 4.1 - Look for the ending pattern after CI_Entry to get CGameMode_Initialize_RetPtr
	code =
		" 74 0A"         //JE SHORT addr -> after the call. this address is RetPtr
	+   " B9" + gWeather //MOV ECX, g_Weather
	+   " E8"            //CALL CWeather::LaunchPokJuk
		;
	offset = Exe.FindHex(code, CI_Entry + 1);
	if (offset === -1)
		throw "Error: CI_Return missing";

	//Step 4.2 - Save RetPtr.
	var CI_Return = offset + code.byteCount() + 4;

	//Step 4.3 - Save CWeather::LaunchPokJuk address (VIRTUAL)
	var CW_LPokJuk = Num2Hex(Exe.Real2Virl(CI_Return) + Exe.GetInt32(CI_Return - 4));

	//Step 5.1 - Find "yuno.rsw"
	var offset2 = Exe.FindString("yuno.rsw", VIRTUAL);
	if (offset2 === -1)
		throw "Error: yuno.rsw missing";

	//Step 5.2 - Find its reference between CI_Entry & CI_Return
	offset = Exe.FindHex( Num2Hex(offset2) + " 8A", CI_Entry+1, CI_Return);
	if (offset === -1)
		throw "Error: yuno.rsw reference missing";

	//Step 5.3 - Find the JZ below it which leads to calling LaunchCloud
	offset = Exe.FindHex("0F 84 ?? ?? 00 00", offset + 5);
	if (offset === -1)
		throw "Error: LaunchCloud JZ missing";

	offset += 6 + Exe.GetInt32(offset + 2);

	//Step 5.4 - Go Inside and extract g_useEffect
	if (Exe.GetUint8(offset) === 0xA1)
		var gUseEffect = Exe.GetHex(offset + 1, 4);
	else
		var gUseEffect = Exe.GetHex(offset + 2, 4);

	//Step 5.5 - Now look for LaunchCloud call after it
	code =
		" B9" + gWeather //MOV ECX, g_Weather
	+   " E8"            //CALL CWeather::LaunchCloud
	;

	offset = Exe.FindHex(code, offset);
	if (offset === -1)
		throw "Error: LaunchCloud call missing";

	offset += code.byteCount();

	//Step 5.6 - Save CWeather::LaunchCloud address (VIRTUAL)
	var CW_LCloud = Num2Hex(Exe.Real2Virl(offset + 4) + Exe.GetInt32(offset));

	//Step 6.1 - Find the 2nd reference to yuno.rsw - which will be at CGameMode_OnInit_EntryPtr
    code = "B8" + Num2Hex(offset2);
	offset = Exe.FindHex(code, 0, CI_Entry-1);

	if (offset === -1)
		offset = Exe.FindHex(code, CI_Return+1);
	if (offset === -1)
		throw "Error: 2nd yuno.rsw reference missing";

	//Step 6.2 - Save the EntryPtr
	var CO_Entry = offset;

	//Step 7.1 - Find the closest JZ after CO_Entry. It jumps to a g_renderer assignment
	offset = Exe.FindHex("0F 84 ?? ?? 00 00", CO_Entry + 1);
	if (offset === -1)
		throw "Error: JZ after CO_Entry missing";

	offset += 7 + Exe.GetInt32(offset + 2);//1 to skip the first opcode byte

	if (Exe.GetUint8(offset - 1) !== 0xA1)
		offset++;//extra 1 to skip the second opcode byte

	//Step 7.2 - Save g_renderer & the g_renderer->ClearColor offset
	var gRenderer = Exe.GetHex(offset, 4);
	var gR_clrColor = Exe.GetHex(offset + 6, 1);

	//Step 7.3 - Find pattern after offset that JMPs to CGameMode_OnInit_RetPtr
	code =
		gRenderer                               //MOV reg32_A, DWORD PTR DS:[g_renderer]
    +   " C7 ??" + gR_clrColor + " 33 00 33 FF" //MOV DWORD PTR DS:[reg32_A+const], FF330033
    +   " EB"                                   //JMP SHORT addr -> jumps to RetPtr
    ;

	offset = Exe.FindHex(code, offset+11);
	if (offset === -1)
		throw "Error: CO_Return missing";

	offset += code.byteCount();
	offset += 1 + Exe.GetInt8(offset) ;

	//Step 7.4 - Check if its really after the last map - new clients have more
	var opcode = Exe.GetUint8(offset)
	if (opcode != 0xA1 && (opcode !== 0x8B || (Exe.GetInt8(offset + 1) & 0xC7) !== 5)) //not MOV EAX, [addr] or MOV reg32_A, [addr]
    {
		code =
            gRenderer               //MOV reg32_A, g_renderer
        +   " C7 ??" + gR_clrColor  //MOV DWORD PTR DS:[reg32_A+const], colorvalue
		;
		offset = Exe.FindHex(code, offset + 1, offset + 0x100);
		if (offset === -1)
            throw "Error: CO_Return missing 2";

		offset += 4 + code.byteCount();
	}

	//Step 7.5 - Save the RetPtr
	var CO_Return = offset;

	//Step 8.1 - Find CWeather::LaunchNight function. It always has the same code
	offset = Exe.FindHex("C6 01 01 C3"); //MOV BYTE PTR DS:[ECX],1 and RETN
	if (offset === -1)
		throw "Error: LaunchNight missing";

	//Step 8.2 - Save CWeather::LaunchNight address (VIRTUAL)
	var CW_LNight = Num2Hex(Exe.Real2Virl(offset));

	//Step 9.1 - Find CWeather::LaunchSnow function call. should be after xmas.rsw is PUSHed
	code =
        " 74 07"          //JZ SHORT addr1 -> Skip LaunchSnow and call StopSnow instead
	+   " E8 ?? ?? ?? ??" //CALL CWeather::LaunchSnow
	+   " EB 05"          //JMP SHORT addr2 -> Skip StopSnow call
	+   " E8"             //CALL CWeather::StopSnow
	;
	offset = Exe.FindHex(code, CI_Entry);
	if (offset === -1)
		throw "Error: LaunchSnow call missing";

	//Step 9.2 - Save CWeather::LaunchSnow address (VIRTUAL)
	var CW_LSnow = Num2Hex(Exe.Real2Virl(offset + 7) + Exe.GetInt32(offset + 3));

	//Step 10.1 - Find the PUSH 14D (followed by MOV) inside CWeather::LaunchMaple
	offset = Exe.FindHex("68 4D 01 00 00 89");
	if (offset === -1)
		throw "Error: LaunchMaple missing";

	//Step 10.2 - Find the start of the function
	code =
        " 83 EC 0C" //SUB ESP, 0C
    +   " 56"       //PUSH ESI
    +   " 8B F1"    //MOV ESI, ECX
    ;
	offset2 = Exe.FindHex("55 8B EC" + code, offset - 0x60, offset);

	if (offset2 === -1)
		offset2 = Exe.FindHex(code, offset - 0x60, offset);

	if (offset2 === -1)
		throw "Error: LaunchMaple start missing";

	//Step 10.3 - Save CWeather::LaunchMaple address (VIRTUAL)
	var CW_LMaple = Num2Hex(Exe.Real2Virl(offset2));

	//Step 11.1 - Find the PUSH A3 (followed by MOV) inside CWeather::LaunchSakura
	offset = Exe.FindHex("68 A3 00 00 00 89");
	if (offset === -1)
		throw "Error: LaunchSakura missing";

	//Step 11.2 - Find the start of the function
	offset2 = Exe.FindHex("55 8B EC" + code, offset - 0x60, offset);

	if (offset2 === -1)
		offset2 = Exe.FindHex(code, offset - 0x60, offset);

	if (offset2 === -1)
		throw "Error: LaunchSakura start missing";

	//Step 11.3 - Save CWeather::LaunchSakura address (VIRTUAL)
	var CW_LSakura = Num2Hex(Exe.Real2Virl(offset2));

	//Step 12.1 - Read the input dll file
	var dll = Fp.ReadHex(0);
	Fp.Close();

	//Step 12.2 - Fill in the values
	dll = dll.replace(/ C1 C1 C1 C1/i, gWeather);
	dll = dll.replace(/ C2 C2 C2 C2/i, gRenderer);
	dll = dll.replace(/ C3 C3 C3 C3/i, gUseEffect);

	code =
		CW_LCloud
    +   CW_LSnow
    +   CW_LMaple
    +   CW_LSakura
    +   CW_LPokJuk
    +   CW_LNight
    ;
	dll = dll.replace(/ C4 C4 C4 C4 C4 C4 C4 C4 C4 C4 C4 C4 C4 C4 C4 C4 C4 C4 C4 C4 C4 C4 C4 C4/i, code);

	dll = dll.replace(/ C5 C5 C5 C5/i, Num2Hex(Exe.Real2Virl(CI_Entry)));
	dll = dll.replace(/ C6 C6 C6 C6/i, Num2Hex(Exe.Real2Virl(CO_Entry)));
	dll = dll.replace(/ C7 C7 C7 C7/i, Num2Hex(Exe.Real2Virl(CI_Return)));
	dll = dll.replace(/ C8 C8 C8 C8/i, Num2Hex(Exe.Real2Virl(CO_Return)));

	dll = dll.replace(/ 6C 5D C3/i, gR_clrColor + " 5D C3");

	//Step 12.3 - Write to output dll file.
	Fp.Open(APP_PATH + "Outputs/rdll2_" + Exe.GetDate() + ".asi", 'wb');
	Fp.WriteHex(0, dll);
	Fp.Close();

	//Step 12.4 - Also write out the values to header file (client.h)
	Fp.Open(APP_PATH + "Outputs/client_" + Exe.GetDate() + ".h", 'w');
	Fp.WriteLine("#include <WTypes.h>");
	Fp.WriteLine("\n// Client Date : " + Exe.GetDate());
	Fp.WriteLine("\n// Client offsets - some are #define because they were appearing in multiple locations unnecessarily");
	Fp.WriteLine("#define G_WEATHER 0x" + gWeather.le2be() + ";");
	Fp.WriteLine("#define G_RENDERER 0x" + gRenderer.le2be() + ";");
	Fp.WriteLine("#define G_USEEFFECT 0x" + gUseEffect.le2be() + ";");
	Fp.WriteLine("\nDWORD CWeather_EffectId2LaunchFuncAddr[] = {\n\tNULL, //CEFFECT_NONE");
	Fp.WriteLine("\t0x" + CW_LCloud.le2be() + ", // CEFFECT_SKY -> void CWeather::LaunchCloud(CWeather this<ecx>, char param)");
	Fp.WriteLine("\t0x" + CW_LSnow.le2be() + ", // CEFFECT_SNOW -> void CWeather::LaunchSnow(CWeather this<ecx>)");
	Fp.WriteLine("\t0x" + CW_LMaple.le2be() + ", // CEFFECT_MAPLE -> void CWeather::LaunchMaple(CWeather this<ecx>)");
	Fp.WriteLine("\t0x" + CW_LSakura.le2be() + ", // CEFFECT_SAKURA -> void CWeather::LaunchSakura(CWeather this<ecx>)");
	Fp.WriteLine("\t0x" + CW_LPokJuk.le2be() + ", // CEFFECT_POKJUK -> void CWeather::LaunchPokJuk(CWeather this<ecx>)");
	Fp.WriteLine("\t0x" + CW_LNight.le2be() + ", // CEFFECT_NIGHT -> void CWeather::LaunchNight(CWeather this<ecx>)");
	Fp.WriteLine("};\n");

	Fp.WriteLine("#define CGameMode_Initialize_EntryPtr (void*)0x" + Num2Hex(Exe.Real2Virl(CI_Entry ), 4, true) + ";");
	Fp.WriteLine("#define CGameMode_OnInit_EntryPtr (void*)0x"     + Num2Hex(Exe.Real2Virl(CO_Entry ), 4, true) + ";");
	Fp.WriteLine("void* CGameMode_Initialize_RetPtr = (void*)0x"   + Num2Hex(Exe.Real2Virl(CI_Return), 4, true) + ";");
	Fp.WriteLine("void* CGameMode_OnInit_RetPtr = (void*)0x"       + Num2Hex(Exe.Real2Virl(CO_Return), 4, true) + ";");

	Fp.WriteLine("\r\n#define GR_CLEAR " + (parseInt(gR_clrColor, 16)/4) + ";");
	Fp.Close();

	return "MapEffect plugin for the loaded client has been generated in Output folder";
}