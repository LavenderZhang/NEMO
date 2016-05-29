//##################################################################################\\
//# Inject code inside UIBasicInfoWnd::OnDraw function to make it also display the #\\
//# exp values like other info inside the "Basic Info" window when not minimized   #\\
//##################################################################################\\

function ShowExpNumbers() //To Do - Make color and coords configurable
{
    //Step 1.1 - Find the address of the Alt String
    var offset = Exe.FindString("Alt+V, Ctrl+V", VIRTUAL, false);
    if (offset === -1)
        return "Failed in Step 1 - String missing";

    //Step 1.2 - Find its reference inside UIBasicInfoWnd::OnCreate function
    var code =
        " 68" + Num2Hex(offset) //PUSH addr; ASCII "Alt+V, Ctrl+V"
    +   " 8B ??"                //MOV ECX, reg32_A
    +   " E8"                   //CALL func
    ;

    offset = Exe.FindHex(code);
    if (offset === -1)
        return "Failed in Step 1 - String reference missing";

    //Step 1.3 - Update offset to location after the CALL
    offset += code.byteCount() + 4;

    //Step 2.1 - Look for a double PUSH pattern (addresses of Total and Current Exp values are being sent as args to be filled)
    code =
        " 8B ?? ?? 00 00 00" //MOV ECX, DWORD PTR DS:[reg32_B + const]
    +   " 68 ?? ?? ?? 00"    //PUSH totExp
    +   " 68 ?? ?? ?? 00"    //PUSH curExp
    +   " E8"                //CALL loaderFunc
    ;

    var offset2 = Exe.FindHex(code, offset, offset + 0x300);
    if (offset2 === -1)
        return "Failed in Step 2 - Base Exp addrs missing";

    //Step 2.2 - Update offset2 to location after the CALL
    offset2 += code.byteCount() + 4;

    //Step 2.3 - Extract the PUSHed addresses (For Base Exp)
    var curExpBase = Exe.GetInt32(offset2 - 9);
    var totExpBase = Exe.GetInt32(offset2 - 14);

    //Step 2.4 - Look for the double PUSH pattern again after the first one.
    offset2 = Exe.FindHex(code, offset2, offset + 0x300);
    if (offset2 === -1)
        return "Failed in Step 2 - Job Exp addrs missing";

    //Step 2.5 - Update offset2 to location after the CALL
    offset2 += code.byteCount() + 4;

    //Step 2.6 - Extract the PUSHed addresses (For Job Exp)
    var curExpJob = Exe.GetInt32(offset2 - 09);
    var totExpJob = Exe.GetInt32(offset2 - 14);

    //Step 3.1 - Find "SP"
    offset = Exe.FindString("SP", VIRTUAL);

    //Step 3.2 - Find the pattern using the string inside OnDraw function    after which we need to inject
    code =
        " 68" + Num2Hex(offset) //PUSH addr; ASCII "SP"
    +   " 6A 41"                //PUSH 41
    +   " 6A 11"                //PUSH 11
    ;

    offset = Exe.FindHex(code);
    if (offset === -1)
        return "Failed in Step 3 - Args missing";

    //Step 3.3 - Update offset to location after PUSH 11
    offset += code.byteCount();

    //Step 3.4 - If the UIWindow::TextOutA function call comes immediately after the pattern, ECX is loaded from ESI
    //            else extract reg code from the MOV ECX, reg32 and update offset
    var rcode = " CE";//for MOV ECX, ESI

    if (Exe.GetUint8(offset) !== 0xE8) //MOV ECX, reg32 comes in between
    {
        rcode = Exe.GetHex(offset + 1, 1);
        offset += 2;
    }
    if (Exe.GetUint8(offset) !== 0xE8)
        return "Failed in Step 3 - Call missing";

    //Step 3.5 - Extract UIWindow::TextOutA address and address where the CALL is made
    var uiTextOut = Exe.Real2Virl(offset+5, CODE) + Exe.GetInt32(offset+1);
    var injectAddr = offset;

    //Step 3.6 - Check if Extra PUSH 0 is there (only for clients > 20140116)
    var extraPush = "";
    if (Exe.GetDate() > 20140116)
        extraPush = " 6A 00";

    //Step 4.1 - Prep the template code that we use for both type of exp
    var template =
        " A1" + MakeVar(1)    //MOV EAX, DWORD PTR DS:[totExp*]
    +   " 8B 0D" + MakeVar(2) //MOV ECX, DWORD PTR DS:[curExp*]
    +   " 09 C1"              //OR ECX, EAX
    +   " 74 JJ"              //JE SHORT addr
    +   " 50"                 //PUSH EAX
    +   " A1" + MakeVar(2)    //MOV EAX, DWORD PTR DS:[curExp*]
    +   " 50"                 //PUSH EAX
    +   " 68" + MakeVar(3)    //PUSH addr; ASCII "%d / %d"
    +   " 8D 44 24 0C"        //LEA EAX, [ESP + 0C]
    +   " 50"                 //PUSH EAX
    +   " FF 15" + MakeVar(4) //CALL DWORD PTR DS:[<&MSVCR#.sprintf>]
    +   " 83 C4 10"           //ADD ESP, 10
    +   " 89 E0"              //MOV EAX, ESP
    +   extraPush             //PUSH 0     ; Arg8 = Only for new clients
    +   " 6A 00"              //PUSH 0     ; Arg7 = Color
    +   " 6A 0D"              //PUSH 0D    ; Arg6 = Font Height
    +   " 6A 01"              //PUSH 1     ; Arg5 = Font Index
    +   " 6A 00"              //PUSH 0     ; Arg4 = Char count (0 => calculate string size)
    +   " 50"                 //PUSH addr  ; Arg3 = String i.e. output from sprintf above
    +   " 6A YC"              //PUSH y     ; Arg2 = y Coord
    +   " 6A XC"              //PUSH x     ; Arg1 = x Coord
    +   " 8B" + rcode         //MOV ECX, reg32_A
    +   " E8" + MakeVar(5)    //CALL UIWindow::TextOutA ; stdcall => No Stack restore required
    ;

    //Step 4.2 - Fill in common values
    var printFunc = Exe.FindFunction("sprintf");

    if (printFunc === -1)
        printFunc = Exe.FindFunction("wsprintfA");

    if (printFunc === -1)
        return "Failed in Step 4 - No print functions found";

    template = SetValue(template, 3, Exe.FindString("%d / %d", VIRTUAL, false));
    template = SetValue(template, 4, printFunc);
    template = template.replace(" XC", " 56");//Common X Coordinate
    template = template.replace(" JJ", Num2Hex(template.byteCount() - 15, 1));

    //Step 4.3 - Prep code we are going to insert
    code =
        " E8" + MakeVar(0)  //CALL UIWindow::TextOutA
    +   " 50"               //PUSH EAX
    +   " 83 EC 20"         //SUB ESP, 20
    +   template            //for Base Exp
    +   template            //for Job Exp
    +   " 83 C4 20"         //ADD ESP, 20
    +   " 58"               //POP EAX
    +   " E9" + MakeVar(6)  //JMP retAddr = injectAddr + 5
    ;

    //Step 4.4 - Find Free space for insertion
    var size = code.byteCount();
    var free = Exe.FindSpace(size);
    if (free === -1)
        return "Failed in Step 4 - Not enough free space";

    var freeVirl = Exe.Real2Virl(free, DIFF);

    //Step 4.5 - Fill in the remaining blanks
    code = SetValue(code, 0, uiTextOut - (freeVirl + 5));

    code = SetValue(code, 1, totExpBase);
    code = SetValue(code, 2, curExpBase, 2); //Change in two places
    code = SetValue(code, 1, totExpJob);
    code = SetValue(code, 2, curExpJob, 2); //Change in two places

    code = code.replace("YC", "4E");
    code = code.replace("YC", "68");

    code = SetValue(code, 5, uiTextOut - (freeVirl + 9 + template.byteCount()));//5 for call, 1 for PUSH EAX and 3 for SUB ESP
    code = SetValue(code, 5, uiTextOut - (freeVirl + 9 + template.byteCount() * 2));//5 for call, 1 for PUSH EAX and 3 for SUB ESP

    code = SetValue(code, 6, Exe.Real2Virl(injectAddr + 5, CODE) - (freeVirl + size));

    //Step 5.1 - Insert the new code at free space
    Exe.InsertHex(free, code, size);

    //Step 5.2 - Replace the CALL at injectAddr with a JMP to our new code.
    Exe.ReplaceHex(injectAddr, "E9" + Num2Hex(freeVirl - Exe.Real2Virl(injectAddr + 5)));
    return true;
}