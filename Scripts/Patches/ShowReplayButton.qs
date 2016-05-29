//###################################################################################\\
//# Change the coordinates of selectserver and replay buttons. Also modify the      #\\
//# ShowMsg function for Replay List box to make it return to Select Service window #\\
//###################################################################################\\

function ShowReplayButton()
{
    //Step 1 - Move Select Server Button to visible area
    var result = __FixupButton("replay_interface\\btn_selectserver_b", " C7", " 89");
    if (typeof(result) === "string")
        return "Failed in Step 1." + result;

    //Step 2 - Move Replay Button to visible area
    result = __FixupButton("replay_interface\\btn_replay_b", " E8", " E8");
    if (typeof(result) === "string")
        return "Failed in Step 2." + result;

    //Step 3.1 - Service and Server select both use the same Window.
    //           So look for the mode comparison to distinguish
    var code =
        " 83 78 04 1E" //CMP DWORD PTR DS:[EAX+4], 1E
    +   " 75"          //JNE SHORT addr
    ;
    var offset = Exe.FindHex(code, result, result + 0x40);
    if (offset === -1)
        return "Failed in Step 3.1 - Mode comparison missing";

    //Step 3.2 - Change the value to Mode 6 (Server Select)
    Exe.ReplaceInt8(offset + 3, 0x06);

    //Step 3.3 - Find the ShowMsg case
    code =
        " 6A 00"          //PUSH 0
    +   " 6A 00"          //PUSH 0
    +   " 6A 00"          //PUSH 0
    +   " 68 29 27 00 00" //PUSH 2729
    ;

    offset = Exe.FindHex(code);
    if (offset === -1)
        return "Failed in Step 3 - Select Server case missing";

    //Step 3.4 - Update offset to location after last PUSH
    offset += code.byteCount();

    //Step 3.5 - Find the Replay Mode Enable bit setting
    code =
        " C6 40 ?? 01"          //MOV BYTE PTR DS:[EAX + const], 1
    +   " C7 ?? 0C 1B 00 00 00" //MOV DWORD PTR DS:[reg32_A + 0C], 1B
    ;

    var offset2 = Exe.FindHex(code);
    if (offset2 === -1)
        return "Failed in Step 3 - Replay mode setter missing";

    //Step 3.6 - Get the Function address before the setter & the mover
    var func = Exe.Real2Virl(offset2, CODE) + Exe.GetInt32(offset2 - 4);
    var mover = Exe.GetHex(offset2, 4).replace("01", "00");

    //Step 4.1 - Prep code to disable the Replay Mode and send 2722 instead of 2729
    code =
        " 60"              //PUSHAD
    +   " E8" + MakeVar(1) //CALL func
    +   mover              //MOV BYTE PTR DS:[EAX + const], 1
    +   " 61"              //POPAD
    +   " 68 22 27 00 00"  //PUSH 2722
    +   " E9" + MakeVar(2) //JMP retn
    ;

    //Step 4.2 - Find Free space for insertion
    var free = Exe.FindSpace(code.byteCount());
    if (free === -1)
        return "Failed in Step 4 - Not enough free space";

    var freeVirl = Exe.Real2Virl(free, DIFF);

    //Step 4.3 - Fill in the blanks
    code = SetValue(code, 1, func - (freeVirl + 6));
    code = SetValue(code, 2, Exe.Real2Virl(offset, CODE) - (freeVirl + code.byteCount()));

    //Step 4.4 - Insert the code at free space
    Exe.InsertHex(free, code, code.byteCount());

    //Step 4.5 - Create a JMP to our code from ShowMsg
    Exe.ReplaceHex(offset - 5, "E9" + Num2Hex(freeVirl - Exe.Real2Virl(offset, CODE)));
    return true;
}

//######################################################################\\
//# Helper Function for Fixing the coordinates of the specified button #\\
//######################################################################\\

function __FixupButton(btnImg, suffix, suffix2)
{
    //Step .0 - Find the Button Image address
    var offset = Exe.FindString(btnImg, VIRTUAL, false);
    if (offset === -1)
        return "0 - Button String missing";

    //Step .1 - Find its reference inside the UI*Wnd::OnCreate function
    var code = Num2Hex(offset);
    offset = Exe.FindHex(code + " C7");

    if (offset === -1)
        offset = Exe.FindHex(code + " 89");

    if (offset === -1)
        return "1 - OnCreate function missing";

    offset += 5;

    //Step .2 - Find the coordinate assignment for the Cancel/Exit button
    var offset2 = Exe.FindHex("EA 00 00 00", offset, offset + 0x50);
    if (offset2 === -1)
        return "2 - 2nd Button asssignment missing";

    //Step .3 - Find the coordinate assignment for the button we need
    var code =
        " 89 ?? 24 ??" //MOV DWORD PTR SS:[ESP + x], reg32_A ; x-coord
    +   " 89 ?? 24 ??" //MOV DWORD PTR SS:[ESP + y], reg32_A ; y-coord
    ;                  //followed by suffix which would be either CALL addr or MOV DWORD PTR SS:[ESP+const], 0

    var type = 1; //VC9
    var jmpAddr = Exe.FindHex(code + suffix, offset2, offset2 + 0x50);

    if (jmpAddr === -1)
    {
        type = 2;//VC10
        code = code.replace(/89 .. 24/g, "89 ??");//change ESP + to EBP -
        jmpAddr = Exe.FindHex(code + suffix, offset2, offset2 + 0x50);
    }
    if (jmpAddr === -1)
    {
        type = 3; //VC11
        code = code.replace(/89 .. ../g, "C7 45 ?? 9C FF FF FF");//change ESI to -64
        jmpAddr = Exe.FindHex(code + suffix2, offset2, offset2 + 0x50);
    }
    if (jmpAddr === -1)
        return "3 - Coordinate assignment missing";

    //Step .3b - Save the location after the match
    var retAddr = jmpAddr + code.byteCount();

    //Step .4a - Prep code to replace/insert
    switch (type)
    {
        case 1:
        {
            offset2 = Exe.GetInt8(jmpAddr + 3);
            code =
                " C7 44 24" + Num2Hex(offset2, 1) + " 04 00 00 00" //MOV DWORD PTR DS:[ESP + x], 4
            +   " 89 44 24" + Num2Hex(offset2 + 4, 1)              //MOV DWORD PTR DS:[ESP + y], EAX
            +   " E9" + MakeVar(1)                                 //JMP retAddr
            ;
            break;
        }
        case 2:
        {
            offset2 = Exe.GetInt8(jmpAddr + 2);
            code =
                " 50"                                             //PUSH EAX ; needed since we lost the y-coord we need to retrieve it from the OK button
            +   " 8B 45" + Num2Hex(offset2 - 20, 1)               //MOV EAX, DWORD PTR DS:[EBP - yOk]
            +   " C7 45" + Num2Hex(offset2, 1) +   " 04 00 00 00" //MOV DWORD PTR DS:[EBP - x], 4
            +   " 89 45" + Num2Hex(offset2 + 4, 1)                //MOV DWORD PTR DS:[EBP - y], EAX
            +   " 58"                                             //POP EAX
            +   " E9" + MakeVar(1)                                //JMP retAddr
            ;
            break;
        }
        case 3:
        {
            code =
                " 04 00 00 00"                        //MOV DWORD PTR DS:[EBP - x], 4
            +   " 89 45" + Exe.GetHex(retAddr - 5, 1) //MOV DWORD PTR DS:[EBP - y], EAX
            +   " 90 90 90 90"                        //NOP x4
            ;
            break;
        }
    }

    //Step .4b - For VC11 we can simply replace at appropriate area after the match
    var size = code.byteCount();
    if (type === 3) //VC11
    {
        Exe.ReplaceHex(retAddr - size, code);
    }
    else //VC9 & VC10
    {
        //Step .5a - For previous client there is not enough space so we find free space for our code
        var free = Exe.FindSpace(size);
        if (free === -1)
            return "5 - Not enough free space";

        //Step .5b - Fill in the blanks
        code = SetValue(code, 1, Exe.Real2Virl(retAddr, CODE) - Exe.Real2Virl(free + size, DIFF));

        //Step .5c - Insert the code at free space
        Exe.InsertHex(free, code, size);

        //Step .5d - Create a JMP to our code at jmpAddr
        Exe.ReplaceHex(jmpAddr, "E9" + Num2Hex(Exe.Real2Virl(free, DIFF) - Exe.Real2Virl(jmpAddr + 5, CODE)));
    }
    return jmpAddr;//We return the address since we need it for the Mode comparison
}

///=====================================================================///
/// Disable for Unneeded Clients - Only Clients with the string need it ///
///=====================================================================///
function ShowReplayButton_()
{
    return (Exe.FindString("replay_interface\\btn_replay_b", REAL, false) !== -1);
}