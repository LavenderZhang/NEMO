/**
NOTES
If you enable this feature, you will need to create an INI file in the format below

--------[ Example of INI file ]---------
[data]
0=bdata.grf
1=adata.grf
2=sdata.grf
3=data.grf
.
.
9=something.grf
----------------------------------------

For the first version of the patch you can specify the name of the file and it is expected to be in your client folder.
For the embedded version, you need to have made the file beforehand and specify its path to the patch to load it.

You can only load up to 10 total grf files with this option (0-9).
The read priority is 0 first to 9 last.
If you only have say 3 GRF files then you only need to use the first 3 keys i.e. 0, 1, and 2
**/

///==================================================///
/// Patch Functions wrapping over MultiGRFs function ///
///==================================================///
function EnableMultipleGRFsV1()
{
    return MultiGRFs(1);
}

function EnableMultipleGRFsV2()
{
    return MultiGRFs(2);
}

//###############################################################\\
//# Override data.grf loading with a custom function which      #\\
//# loads the grf names required in order specified by INI file #\\
//# version = 1 - INI is read live inside client                #\\
//# version = 2 - INI is read by patch and grf names are embed  #\\
//###############################################################\\

function MultiGRFs(version)
{
    //Step 1.1 - Find "data.grf"
    var grf = Num2Hex(Exe.FindString("data.grf", VIRTUAL));

    //Step 1.2 - Find its reference
    var code =
        " 68" + grf       //PUSH OFFSET addr1; "data.grf"
    +   " B9 ?? ?? ?? 00" //MOV ECX, OFFSET g_fileMgr
    ;

    var offset = Exe.FindHex(code);
    if (offset === -1)
        return "Failed in Step 1";

    //Step 1.3 - Extract the g_FileMgr assignment
    var setECX = Exe.GetHex(offset + 5, 5);

    //Step 2.1 - Find the AddPak call after the push
    code =
        " E8 ?? ?? ?? ??"    //CALL CFileMgr::AddPak()
    +   " 8B ?? ?? ?? ?? 00" //MOV reg32, DWORD PTR DS:[addr1]
    +   " A1 ?? ?? ?? 00"    //MOV EAX, DWORD PTR DS:[addr2]
    ;

    var fnOffset = Exe.FindHex(code, offset + 10, offset + 40);
    if (fnOffset === -1) //VC9 Client
    {
        code =
            " E8 ?? ?? ?? ??" //CALL CFileMgr::AddPak()
        +   " A1 ?? ?? ?? 00" //MOV EAX, DWORD PTR DS:[addr2]
        ;
        fnOffset = Exe.FindHex(code, offset + 10, offset + 40);
    }
    if (fnOffset === -1) //Older Clients
    {
        code =
            " E8 ?? ?? ?? ??" //CALL CFileMgr::AddPak()
        +   " BF ?? ?? ?? 00" //MOV EDI, OFFSET addr2
        ;
        fnOffset = Exe.FindHex(code, offset + 10, offset + 40);
    }
    if (fnOffset === -1)
        return "Failed in Step 2";

    //Step 2.3 - Extract AddPak function address
    var AddPak = Exe.Real2Virl(fnOffset + 5, CODE) + Exe.GetInt32(fnOffset + 1);

    //Step 3.1 - Little trick to avoid changing 10 bytes (change the PUSH to MOV ECX, offset)
    Exe.ReplaceInt8(offset, 0xB9);

    //Step 3.2 - Call the Helper Function according to version
    if (version === 1)
        var result = EMG_V1(grf, setECX, fnOffset, AddPak);
    else
        var result = EMG_V2(grf, setECX, fnOffset, AddPak);

    //Step 3.3 - Report any errors
    if (typeof(result) === "string")
        return result;

    //Step 4 - Find "rdata.grf" (if present zero it out)
    offset = Exe.FindString("rdata.grf", REAL);
    if (offset !== -1)
        Exe.ReplaceInt8(offset, 0);

    return true;
}

function EMG_V1(grf, setECX, fnOffset, AddPak)
{
    //Step 3.1 - Prep code for reading INI file and loading GRFs
    var code =
        " C8 80 00 00"        //ENTER 80, 0
    +   " 60"                 //PUSHAD
    +   " 68" + MakeVar(1)    //PUSH addr1 ; ASCII "KERNEL32"
    +   " FF 15" + MakeVar(2) //CALL DWORD PTR DS:[<&KERNEL32.GetModuleHandleA>]
    +   " 85 C0"              //TEST EAX, EAX
    +   " 74 23"              //JZ SHORT addr2
    +   " 8B 3D" + MakeVar(3) //MOV EDI,DWORD PTR DS:[<&KERNEL32.GetProcAddress>]
    +   " 68" + MakeVar(4)    //PUSH addr3 ; ASCII "GetPrivateProfileStringA"
    +   " 89 C3"              //MOV EBX, EAX
    +   " 50"                 //PUSH EAX ; hModule
    +   " FF D7"              //CALL EDI ; GetProcAddress()
    +   " 85 C0"              //TEST EAX, EAX
    +   " 74 0F"              //JZ SHORT addr2
    +   " 89 45 F6"           //MOV DWORD PTR SS:[EBP-0A], EAX
    +   " 68" + MakeVar(5)    //PUSH addr4 ; ASCII "WritePrivateProfileStringA"
    +   " 89 D8"              //MOV EAX, EBX
    +   " 50"                 //PUSH EAX ; hModule
    +   " FF D7"              //CALL EDI ; GetProcAddress()
    +   " 85 C0"              //TEST EAX, EAX
    +   " 74 6E"              //JZ SHORT loc_735E71
    +   " 89 45 FA"           //MOV DWORD PTR SS:[EBP-6], EAX
    +   " 31 D2"              //XOR EDX, EDX
    +   " 66 C7 45 FE 39 00"  //MOV WORD PTR SS:[EBP-2], 39 ; char 9
    +   " 52"                 //PUSH EDX
    +   " 68" + MakeVar(6)    //PUSH addr5 ; INI filename
    +   " 6A 74"              //PUSH 74
    +   " 8D 5D 81"           //LEA EBX, [EBP-7F]
    +   " 53"                 //PUSH EBX
    +   " 8D 45 FE"           //LEA EAX, [EBP-2]
    +   " 50"                 //PUSH EAX
    +   " 50"                 //PUSH EAX
    +   " 68" + MakeVar(7)    //PUSH addr6 ; ASCII "Data"
    +   " FF 55 F6"           //CALL DWORD PTR SS:[EBP-0A]
    +   " 8D 4D FE"           //LEA ECX, [EBP-2]
    +   " 66 8B 09"           //MOV CX, WORD PTR DS:[ECX]
    +   " 8D 5D 81"           //LEA EBX, [EBP-7F]
    +   " 66 3B 0B"           //CMP CX, WORD PTR DS:[EBX]
    +   " 5A"                 //POP EDX
    +   " 74 0E"              //JZ SHORT addr7
    +   " 52"                 //PUSH EDX
    +   " 53"                 //PUSH EBX
    +     setECX              //MOV ECX, g_fileMgr
    +   " E8" + MakeVar(8)    //CALL CFileMgr::AddPak()
    +   " 5A"                 //POP EDX
    +   " 42"                 //INC EDX
    +   " FE 4D FE"           //DEC BYTE PTR SS:[EBP-2]
    +   " 80 7D FE 30"        //CMP BYTE PTR SS:[EBP-2], 30
    +   " 73 C1"              //JNB SHORT addr8
    +   " 85 D2"              //TEST EDX, EDX
    +   " 75 20"              //JNZ SHORT addr9
    +   " 68" + MakeVar(6)    //PUSH addr5 ; INI filename
    +   " 68" + grf           //PUSH grf ; "data.grf"
    +   " 66 C7 45 FE 32 00"  //MOV DWORD PTR SS:[EBP-2], 32
    +   " 8D 45 FE"           //LEA EAX, [EBP-2]
    +   " 50"                 //PUSH EAX
    +   " 68" + MakeVar(7)    //PUSH addr6 ; ASCII "Data"
    +   " FF 55 FA"           //CALL DWORD PTR SS:[EBP-6]
    +   " 85 C0"              //TEST EAX, EAX
    +   " 75 97"              //JNZ SHORT
    +   " 61"                 //POPAD
    +   " C9"                 //LEAVE
    +   " C3 00"              //RETN and a gap before strings begin
    ;

    //Step 4 - Get the INI file name from user
    var iniFile = Exe.GetUserInput('$dataINI', I_STRING, "String Input", "Enter the name of the INI file", "DATA.INI", 1, 20);
    if (!iniFile)
        return "Patch Cancelled";

    iniFile = ".\\" + iniFile;

    //Step 5.1 - Put all the strings in an array (we need their individual lengths later)
    var strings = ["KERNEL32", "GetPrivateProfileStringA", "WritePrivateProfileStringA", "Data", iniFile];

    //Step 5.2 - Join the strings with NULL in between and convert to Hex
    var strCode = Ascii2Hex(strings.join("\x00"));
    
    //Step 5.3 - Find Free space for insertion
    var size = code.byteCount() + strCode.byteCount();
    var free = Exe.FindSpace(size);
    if (free === -1)
        return "Failed in Step 5 - Not enough free space";

    var freeVirl = Exe.Real2Virl(free, DIFF);
    
    //Step 5.4 - Create a call to the free space that was found before
    Exe.ReplaceInt32(fnOffset + 1, freeVirl - Exe.Real2Virl(fnOffset + 5, CODE));

    //Step 5.5 - Fill in the Blanks
    code = SetValue(code, 2, Exe.FindFunction("GetModuleHandleA", "KERNEL32.dll"));
    code = SetValue(code, 3, Exe.FindFunction("GetProcAddress", "KERNEL32.dll"));
    
    var memPosition = freeVirl + code.byteCount();
    code = SetValue(code, 1, memPosition);//KERNEL32

    memPosition = memPosition + strings[0].length + 1;//1 for null
    code = SetValue(code, 4, memPosition);//GetPrivateProfileStringA

    memPosition = memPosition + strings[1].length + 1;//1 for null
    code = SetValue(code, 5, memPosition);//WritePrivateProfileStringA

    memPosition = memPosition + strings[2].length + 1;//1 for null
    code = SetValue(code, 7, memPosition, 2);//Data - Change in two places

    memPosition = memPosition + strings[3].length + 1;//1 for null
    code = SetValue(code, 6, memPosition, 2);//INI file - Change in two places

    code = SetValue(code, 8, (AddPak - (freeVirl + 115) - 5));//AddPak function

    //Step 5.7 - Insert everything at free space
    Exe.InsertHex(free, code + strCode, size);
}

function EMG_V2(grf, setECX, fnOffset, AddPak)
{
    //Step 3.1 - Get the INI file from user to read
    var Fp = MakeFile('$inpMultGRF', "File Input - Enable Multiple GRF", "Enter your INI file", APP_PATH);
    if (!Fp)
        return "Patch Cancelled";

    //Step 3.2 - Read the GRF filenames from the INI into an array
    var temp = [];
    while (!Fp.IsEOF())
    {
        var line = Fp.ReadLine().trim();
        var matches = line.match(/^(\d)=(.*)/);
        if (!matches)
            continue;

        var index = matches[1];
        var value = matches[2].trim();
        temp[index] = value;
    }
    Fp.Close();

    //Step 3.4 - Account for empty file (atleast data.grf should be there)
    if (temp.length === 0)
        temp[0] = "data.grf";

    //Step 3.5 - Remove empty indices
    var grfNames = [];
    for (var i = 0; i < temp.length; i++)
    {
        if (temp[i])
            grfNames.push(temp[i]);
    }

    //Step 4.1 - Prep code for GRF loading
    var template =
        " 68" + MakeVar(1) //PUSH OFFSET addr; GRF name
    +   setECX             //MOV ECX, OFFSET g_fileMgr
    +   " E8" + MakeVar(2) //CALL CFileMgr::AddPak()
    ;
    var unitSize = template.byteCount();

    //Step 4.2 - Join the strings with NULL in between and convert to Hex
    var strCode = Ascii2Hex(grfNames.join("\x00"));

    //Step 4.3 - Find Free space for insertion
    var size = grfNames.length * unitSize + 2 + strCode.byteCount();
    var free = Exe.FindSpace(size);
    if (free === -1)
        return "Failed in Step 4 - Not enough free space";

    var freeVirl = Exe.Real2Virl(free, DIFF);

    //Step 4.4 - Starting offsets to use in SetValue
    var offset = freeVirl + grfNames.length * unitSize + 2;//Offset of String
    var diff = AddPak - offset + 2; //Called Location = after the last template

    //Step 4.5 - Create the full code from template for each grf & add strings
    var code = "";
    for (var j = 0; j < grfNames.length; j++)
    {
        code = SetValues(template, [1, 2], [offset, diff]) + code;
        offset += grfNames[j].length + 1; //Extra 1 for NULL byte
        diff += unitSize;
    }
    code += " C3 00";//RETN and 1 extra NULL

    //Step 5.1 - Create a call to the free space that was found before.
    Exe.ReplaceInt32(fnOffset + 1, freeVirl - Exe.Real2Virl(fnOffset + 5, CODE));

    //Step 5.2 - Insert everything at free space
    Exe.InsertHex(free, code + strCode, size);
}