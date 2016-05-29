//####################################################################################\\
//# Hijack the MsgStr function call inside the Booking OnCreate function which loads #\\
//# comboboxes for testing the ID against our list and skip iteration if present     #\\
//####################################################################################\\

function RemoveJobsFromBooking()
{
    //Step 1.1 - Find the MsgStr call used for Job Name loading.
    var code =
        " 8D ?? 5D 06 00 00" //LEA reg32_A, [reg32_B + 65D]
    +   " 03 ??"             //ADD reg32_B, reg32_C
    +   " 89 ?? ??"          //MOV DWORD PTR SS:[EBP-const1], reg32_A
    +   " 89 ?? ??"          //MOV DWORD PTR SS:[EBP-const2], reg32_B
    +   " 8B ?? ??"          //MOV EAX, DWORD PTR SS:[EBP-const1]
    +   " 50"                //PUSH EAX
    +   " E8"                //CALL MsgStr
    ;
    var type = 1; //VC6
    var offset = Exe.FindHex(code);

    if (offset === -1)
    {
        code =
            " 8D 49 00"          //LEA ECX, [ECX]
        +   " 8D ?? 5D 06 00 00" //LEA reg32_A, [reg32_B + 65D]
        +   " ??"                //PUSH reg32_A
        +   " E8"                //CALL MsgStr
        ;
        type = 2; //VC9 & VC11
        offset = Exe.FindHex(code);
    }
    if (offset === -1)
    {
        code =
            " 8B ?? ??"          //MOV reg32_A, DWORD PTR SS:[EBP-const]
        +   " 81 ?? 5D 06 00 00" //ADD reg32_A, 65D
        +   " ??"                //PUSH reg32_A
        +   " E8"                //CALL MsgStr
        ;
        type = 3; //VC10
        offset = Exe.FindHex(code);
    }
    if (offset === -1)
        return "Failed in Step 1 - Start of Loop missing";

    //Step 1.2 - Update offset to location of CALL
    offset += code.byteCount();

    //Step 1.3 - Extract the MsgStr address
    var MsgStr = Exe.Real2Virl(offset + 4, CODE) + Exe.GetInt32(offset);

    //Step 1.4 - Get Pattern for finding end of the loop (We need to RETN to location before Loop counter increment which is what jmpOff is for)
    switch (type)
    {
        case 1:
        {
            code =
                " 83 C4 04"          //ADD ESP, 4
            +   " 8B ?? ??"          //MOV reg32_A, DWORD PTR SS:[EBP-const1]
            +   " 8B ?? ??"          //MOV reg32_B, DWORD PTR SS:[EBP-const2]
            +   " ??"                //INC reg32_A
            +   " ??"                //INC reg32_B
            +   " 89 ?? ??"          //MOV DWORD PTR SS:[EBP-const3],reg32_C
            +   " 89 ?? ??"          //MOV DWORD PTR SS:[EBP-const4],reg32_C
            +   " 89 ?? ??"          //MOV DWORD PTR SS:[EBP-const5],reg32_C
            +   " 89 ?? ??"          //MOV DWORD PTR SS:[EBP-const1],reg32_A
            +   " 89 ?? ??"          //MOV DWORD PTR SS:[EBP-const2],reg32_B
            +   " 0F 85 ?? FF FF FF" //JNZ addr
            ;
            var jmpOff = 3;
            break;
        }
        case 2:
        {
            if (Exe.GetDate() < 20140000) //VC9
            {
                code =
                    " FF 15 ?? ?? ?? 00" //CALL DWORD PTR DS:[<&MSVCP#.$basic*>]
                +   " ??"                //INC reg32_A
                +   " 83 6C 24 ?? 01"    //SUB DWORD PTR SS:[ESP+const], 1
                +   " 75"                //JNZ SHORT addr
                ;
                var jmpOff = 6;
            }
            else //VC11
            {
                code =
                    " 83 C4 04"             //ADD ESP, 4
                +   " ??"                   //INC reg32_A
                +   " C7 45 ?? 0F 00 00 00" //MOV DWORD PTR SS:[EBP-const1], 0F
                +   " C7 45 ?? 00 00 00 00" //MOV DWORD PTR SS:[EBP-const2], 0
                +   " C6 45 ?? 00"          //MOV BYTE PTR SS:[EBP-const3], 0
                +   " ??"                   //DEC reg32_B
                +   " 0F 85 ?? FF FF FF"    //JNZ addr
                ;
                var jmpOff = 3;
            }
            break;
        }
        case 3: //VC10
        {
            code =
                " ?? 01 00 00 00"       //MOV reg32_A, 1
            +   " 01 ?? ??"             //ADD DWORD PTR SS:[EBP-const1], reg32_A
            +   " 29 ?? ??"             //SUB DWORD PTR SS:[EBP-const2], reg32_A
            +   " C7 45 ?? ?? 00 00 00" //MOV DWORD PTR SS:[EBP-const3], 0F
            +   " 89 ?? ??"             //MOV DWORD PTR SS:[EBP-const4], reg32_B
            +   " 88 ?? ??"             //MOV BYTE PTR SS:[EBP-const5], reg8_B
            +   " 75"                   //JNZ SHORT addr
            ;
            var jmpOff = 0;
            break;
        }
    }

    //Step 1.5 - Find the pattern
    var retnHere = Exe.FindHex(code, offset + 5, offset + 0x100);
    if (retnHere === -1)
        return "Failed in Step 1b - Loop End missing";

    //Step 1.6 - Get VIRTUAL of location to RETN to.
    retnHere = Exe.Real2Virl(retnHere + jmpOff);

    //Step 2.1 - Get the Skip List file from User
    var inpFile = Exe.GetUserInput("$bookingList", I_FILE, "File Input - Remove Jobs From Booking", "Enter the Booking Skip List file", APP_PATH + "Inputs/bookingSkipList.txt");
    if (!inpFile)
        return "Patch Cancelled";

    var Fp = new File();
    Fp.Open(inpFile, 'r');

    //Step 2.2 - Extract all the IDs from List file to an Array
    var idSet = [];
    while (!Fp.IsEOF())
    {
        var line = Fp.ReadLine().trim();
        if (line.match(/^\d+/))
        {
            var id = parseInt(line);
            if (id < 0x65D)
                continue;

            idSet.push(Num2Hex(id, 2));
        }
    }
    Fp.Close();

    //Step 2.3 - Add NULL at end of the Array
    idSet.push(" 00 00");

    //Step 3.1 - Prep code for our function to check the ID
    code =
        " 50"              //PUSH EAX
    +   " 51"              //PUSH ECX
    +   " 52"              //PUSH EDX
    +   " 8B 44 24 10"     //MOV EAX, DWORD PTR SS:[ESP+10]; Arg0
    +   " 40"              //INC EAX ; Needed because the ids start from 0
    +   " B9" + MakeVar(1) //MOV ECX, listaddr
    +   " 0F B7 11"        //MOVZX EDX, WORD PTR DS:[ECX] ; addr3
    +   " 85 D2"           //TEST EDX, EDX
    +   " 74 08"           //JE SHORT addr1
    +   " 39 D0"           //CMP EAX, EDX
    +   " 74 0C"           //JE SHORT addr2
    +   " 41"              //INC ECX
    +   " 41"              //INC ECX
    +   " EB F1"           //JMP SHORT addr3
    +   " 5A"              //POP EDX
    +   " 59"              //POP ECX
    +   " 58"              //POP EAX
    +   " E9" + MakeVar(2) //JMP MsgStr
    +   " 5A"              //POP EDX
    +   " 59"              //POP ECX
    +   " 58"              //POP EAX
    +   " 83 C4 08"        //ADD ESP, 8
    +   " 68" + MakeVar(3) //PUSH retnHere
    +   " C3"              //RETN
    ;

    //Step 3.2 - Find Free space for insertion of the IDs and the Function
    var size = idSet.length * 2 + code.byteCount();
    var free = Exe.FindSpace(size);
    if (free === -1)
        return "Failed in Step 3 - Not enough free space"

    var freeVirl = Exe.Real2Virl(free, DIFF);

    //Step 3.3 - Fill in the blanks
    code = SetValue(code, 1, freeVirl);
    code = SetValue(code, 2, MsgStr - (freeVirl + size - 12));
    code = SetValue(code, 3, retnHere);

    //Step 4.1 - Insert the data and function in free space
    Exe.InsertHex(free, idSet.join("") + code, size);

    //Step 4.2 - Change the MsgStr CALL with a CALL to our function.
    Exe.ReplaceInt32(offset, (freeVirl + idSet.length * 2) - Exe.Real2Virl(offset + 4, CODE));
    return true;
}