//################################################################################################################\\
//# JMP over the original iteminfo loader Function call and instead add the call after char servername is stored #\\
//# Also modify the "main" Lua Func call routine inside the loader function to include 1 argument - server name  #\\
//################################################################################################################\\

function LoadItemInfoPerServer()
{
    //Step 1.1 - Find the pattern before Server Name is pushed to StringAllocator Function
    var code =
        " C1 ?? 05"                   //SHL EDI,5
    +   " 66 83 ?? ?? ?? ?? 00 00 03" //CMP WORD PTR DS:[ESI+EDI+1F4],3
    ;

    var offset = Exe.FindHex(code);
    if (offset === -1)
        return "Failed in Step 1 - Pattern not found";

    //Step 1.2 - Update offset to location after the CMP
    offset += code.byteCount();

    //Step 1.3 - Find the StringAllocator call after pattern
    code =
        " B9 ?? ?? ?? 00"    //MOV ECX, addr
    +   " E8 ?? ?? ?? ??"    //CALL StringAllocator
    +   " 8B ?? ?? ?? 00 00" //MOV reg32_A, DWORD PTR DS:[reg32_B + const]
    ;
    var directCall = true;
    var offset2 = Exe.FindHex(code, offset, offset + 0x40);

    if (offset2 === -1)
    {
        code = code.replace("E8", "FF 15");//CALL DWORD PTR DS:[StringAllocator]
        directCall = false;
        offset2 = Exe.FindHex(code, offset, offset + 0x40);
    }
    if (offset2 === -1)
        return "Failed in Step 1 - StringAllocator call missing";

    //Step 1.4 - Save the location where the CALL occurs
    var allocInject = offset2 + 5;

    //Step 2.1 - Find ItemInfo Error string
    offset = Exe.FindString("ItemInfo file Init", VIRTUAL);
    if (offset === -1)
        return "Failed in Step 2 - ItemInfo String missing";

    //Step 2.2 - Find its reference
    offset = Exe.FindHex("68" + Num2Hex(offset));
    if (offset === -1)
        return "Failed in Step 2 - ItemInfo String reference missing";

    //Step 2.3 - Find the ItemInfo Loader call before it
    code =
        " E8 ?? ?? ?? ??"    //CALL iteminfoPrep
    +   " 8B 0D ?? ?? ?? 00" //MOV ECX, DWORD PTR DS:[refAddr]
    +   " E8 ?? ?? ?? ??"    //CALL iteminfoLoader
    ;

    offset = Exe.FindHex(code, offset - 0x30, offset);
    if (offset === -1)
        return "Failed in Step 2 - ItemInfo Loader missing";

    //Step 2.4 - Extract the MOV ECX statement
    var refMov = Exe.GetHex(offset + 5, 6);

    //Step 2.5 - Change the MOV statement to JMP for skipping the loader
    var code2 =
        " 90 90" //NOPs
    +   " B0 01" //MOV AL, 1
    +   " EB 05" //JMP to after iteminfoLoader call
    ;

    Exe.ReplaceHex(offset + 5, code2);

    //Step 2.6 - Extract iteminfoLoader function address
    offset += code.byteCount();
    offset += Exe.GetInt32(offset - 4);
    var iiLoaderFunc = Exe.Real2Virl(offset, CODE);

    //Step 3.1 - Find "main"
    offset2 = Exe.FindString("main", VIRTUAL);
    if (offset2 === -1)
        return "Failed in Step 3 - main string missing";

    //Step 3.2 - Find its reference ("main" push to Lua stack)
    code =
        " 68" + Num2Hex(offset2) //PUSH OFFSET addr; ASCII "main"
    +   " 68 EE D8 FF FF"        //PUSH -2712
    +   " ??"                    //PUSH reg32_A
    +   " E8 ?? ?? ?? 00"        //CALL LuaFnNamePusher
    ;
    offset2 = Exe.FindHex(code, offset, offset + 0x200);

    if (offset2 === -1)
    {
        code = code.replace(" ?? E8", "FF 75 ?? E8"); //Change PUSH reg32_A => PUSH DWORD PTR SS:[EBP-x]
        offset2 = Exe.FindHex(code, offset, offset + 0x200);
    }
    if (offset2 === -1)
        return "Failed in Step 3 - main push missing";

    //Step 3.3 - Save the location where the CALL occurs
    var mainInject = offset2 + code.byteCount() - 5;

    //Step 3.4 - Find the arg count PUSHes after it
    offset = Exe.FindHex("6A 00 6A 02 6A 00", mainInject + 5, mainInject + 0x20);
    if (offset === -1)
        return "Failed in Step 3 - Arg Count Push missing";

    //Step 3.5 - Change the last PUSH 0 to PUSH 1 (since we have 1 input argument)
    Exe.ReplaceInt8(offset + 5, 1);

    //Step 4.1 - Find the location where the iteminfo copier is called
    code =
        refMov            //MOV ECX, DWORD PTR DS:[refAddr]
    +   " 68 ?? ?? ?? 00" //PUSH OFFSET iiAddr
    +   " E8 ?? ?? ?? FF" //CALL iteminfoCopier
    ;

    offset = Exe.FindHex(code);
    if (offset === -1)
        return "Failed in Step 4 - ItemInfo copy function missing";

    //Step 4.2 - Update offset to location after the MOV
    offset += refMov.byteCount();

    //Step 4.3 - Extract the PUSH statement and Copier Function address
    var iiPush = Exe.GetHex(offset, 5);
    var iiCopierFunc = Exe.Real2Virl(offset + 10, CODE) + Exe.GetInt32(offset + 6);

    //Step 5.1 - Find the 's' input Push Function call inside the LuaFn Caller
    code =
        " 8B ??"          //MOV reg32_A, DWORD PTR DS:[reg32_B]
    +   " 8B ??"          //MOV reg32_C, DWORD PTR DS:[reg32_D]
    +   " 83 ?? 04"       //ADD reg32_B, 4
    +   " ??"             //PUSH reg32_A
    +   " ??"             //PUSH reg32_C
    +   " E8 ?? ?? ?? 00" //CALL StringPusher
    +   " 83 C4 08"       //ADD ESP, 8
    ;
    offset = Exe.FindHex(code);

    if (offset === -1)
    {
        code = code.replace(" 8B ?? 8B ??", " FF ??");//Change the 2 MOVs to PUSH DWORD PTR DS:[reg32_B]
        code = code.replace(" ?? ?? E8", " FF ?? E8");//Change the 2 PUSHs to PUSH DWORD PTR DS:[reg32_D]
        offset = Exe.FindHex(code);
    }
    if (offset === -1)
        return "Failed in Step 5 - String Pusher missing";

    offset += code.byteCount() - 3;

    //Step 5.2 - Extract the Function address
    var stringPushFunc = Exe.Real2Virl(offset, CODE) + Exe.GetInt32(offset - 4);

    //Step 6.1 - Prep code to Push String after "main" push
    code =
        " E8" + MakeVar(1)    //CALL LuaFnNamePusher
    +   " 83 C4 08"           //ADD ESP, 8
    +   " FF 35" + MakeVar(2) //PUSH DWORD PTR DS:[serverAddr]
    +   " 83 EC 04"           //SUB ESP, 4
    +   " E8" + MakeVar(3)    //CALL StringPusher
    +   " E9" + MakeVar(4)    //JMP addr -> after original CALL LuaFnNamePusher
    +   " 00 00 00 00"        //<-serverAddr
    ;

    //Step 6.2 - Find Free space for insertion
    var free = Exe.FindSpace(code.byteCount());
    if (free === -1)
        return "Failed in Step 6 - Not enough space available";

    var freeVirl = Exe.Real2Virl(free, DIFF);
    var serverAddr = freeVirl + code.byteCount() - 4;

    //Step 6.3 - Fill in the blanks
    offset = Exe.Real2Virl(mainInject + 5, CODE) + Exe.GetInt32(mainInject + 1) - (freeVirl + 5);
    code = SetValue(code, 1, offset);
    code = SetValue(code, 2, serverAddr);
    code = SetValue(code, 3, stringPushFunc - (serverAddr - 5));
    code = SetValue(code, 4, Exe.Real2Virl(mainInject + 5, CODE) - serverAddr);

    //Step 6.4 - Change the LuaFnNamePusher call to a JMP to our code
    offset = freeVirl - Exe.Real2Virl(mainInject + 5, CODE);
    Exe.ReplaceHex(mainInject, "E9" + Num2Hex(offset));

    //Step 6.5 - Insert code at free space
    Exe.InsertHex(free, code, code.byteCount());

    //Step 7.1 - Prep code for calling the iteminfo loader upon server select
    code =
        " E8" + MakeVar(1)    //CALL StringAllocator - This function also does stack restore but the servername argument is not wiped off the stack
    +   " 8B 44 24 FC"        //MOV EAX, DWORD PTR SS:[ESP-4]
    +   " 3B 05" + MakeVar(2) //CMP EAX, DWORD PTR DS:[serverAddr]; need to improve this - better would be to do strcmp on the string addresses
    +   " 74 20"              //JE Skip
    +   " A3" + MakeVar(2)    //MOV DWORD PTR DS:[serverAddr], EAX
    +   refMov                //MOV ECX, DWORD PTR DS:[refAddr]
    +   " E8" + MakeVar(3)    //CALL iiLoaderFunc
    +   refMov                //MOV ECX, DWORD PTR DS:[refAddr] ;You can also add checking before this
    +   iiPush                //PUSH OFFSET iiAddr
    +   " E8" + MakeVar(4)    //CALL iiCopierFunc
    +   " E9" + MakeVar(5)    //JMP to after original function call
    ;

    if (!directCall)
        code = code.replace("E8", "FF 15");//make it CALL DWORD PTR DS:[StringAllocator]

    //Step 7.2 - Find Free space for insertion
    free = Exe.FindSpace(code.byteCount());
    if (free === -1)
        return "Failed in Step 7 - Not enough space available";

    freeVirl = Exe.Real2Virl(free, DIFF);

    //Step 7.3 - Fill in the blanks
    if (directCall)
        offset = Exe.Real2Virl(allocInject + 5, CODE) + Exe.GetInt32(allocInject + 1) - (freeVirl + 5);
    else
        offset = Exe.GetInt32(allocInject + 2);

    code = SetValue(code, 1, offset);
    code = SetValue(code, 2, serverAddr);

    offset = iiLoaderFunc - (freeVirl + code.byteCount() - (refMov.byteCount() + iiPush.byteCount() + 10));
    code = SetValue(code, 3, offset);

    offset = iiCopierFunc - (freeVirl + code.byteCount() - 5);
    code = SetValue(code, 4, offset);

    offset = Exe.Real2Virl(allocInject + 5, CODE) - (freeVirl + code.byteCount());
    code = SetValue(code, 5, offset);

    //Step 7.4 - Change the function call to a JMP to our custom code
    offset = freeVirl - Exe.Real2Virl(allocInject + 5, CODE);
    Exe.ReplaceHex(allocInject, "E9" + Num2Hex(offset));

    if (!directCall)
        Exe.ReplaceHex(allocInject + 5, "90");

    //Step 7.5 - Insert the code at free space
    Exe.InsertHex(free, code, code.byteCount());
    return true;
}

///=================================///
/// Disable for Unsupported clients ///
///=================================///
function LoadItemInfoPerServer_()
{
    return ChangeItemInfo_();//Already does the same check might as well use it
}