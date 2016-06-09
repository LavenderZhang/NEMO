//#######################################################################################\\
//# Fix up all HackShield related functions/function calls and remove aossdk.dll import #\\
//#######################################################################################\\

delete Import_Info; //Removing any stray values before Patches are selected

function DisableHShield()
{
    //Step 1.1 - Find "webclinic.ahnlab.com"
    var offset = Exe.FindString("webclinic.ahnlab.com", VIRTUAL);
    if (offset === -1)
        return "Failed in Step 1 - webclinic address missing";

    //Step 1.2 - Find its reference
    offset = Exe.FindHex("68" + Num2Hex(offset)); //PUSH OFFSET addr; ASCII "webclinic.ahnlab.com"
    if (offset === -1)
        return "Failed in Step 1 - webclinic reference missing";

    //Step 1.3 - Find the JZ before the RETN that points to the PUSH
    var code =
        " 74 ??" //JZ addr2 -> PUSH OFFSET addr; ASCII "webclinic.ahnlab.com"
    +   " 33 C0" //XOR EAX, EAX
    ;

    offset = Exe.FindHex(code, offset - 0x10, offset);
    if (offset === -1)
        return "Failed in Step 1 - JZ not found";

    //Step 1.4 - Replace the JZ + XOR with XOR + INC of EAX to return 1 without initializing AhnLab
    Exe.ReplaceHex(offset, "33 C0 40 90");

    //Step 2.1 - Find Failure message - this is there in newer clients (maybe all ragexe too?)
    offset = Exe.FindString("CHackShieldMgr::Monitoring() failed", VIRTUAL);

    if (offset !== -1)
    {
        //Step 2.2 - Find reference to Failure message
        offset = Exe.FindHex("68" + Num2Hex(offset) + " FF 15");

        //Step 2.3 - Find Pattern before the referenced location within 0x40 bytes
        if (offset !== -1)
        {
            code =
                " E8 ?? ?? ?? ??" //CALL func1
            +   " 84 C0"          //TEST AL, AL
            +   " 74 16"          //JZ SHORT addr1
            +   " 8B ??"          //MOV ECX, ESI
            +   " E8"             //CALL func2
            ;
            offset = Exe.FindHex(code, offset - 0x40, offset);
        }
        //Step 2.4 - Replace the First call with code to return 1 and cleanup stack
        if (offset !== -1)
        {
            code =
                " 90"    //NOP
            +   " B0 01" //MOV AL, 1
            +   " 5E"    //POP ESI
            +   " C3"    //RETN
            ;
            Exe.ReplaceHex(offset, code);
        }
    }

    ///===================================================================///
    /// Now for a failsafe to avoid calls just in case - for VC9+ clients ///
    ///===================================================================///

    //Step 3.1 - Find "ERROR"
    offset = Exe.FindString("ERROR", VIRTUAL);
    if (offset === -1)
        return "Failed in Step 3 - ERROR string missing";

    //Step 3.2 - Find address of MessageBoxA function
    var offset2 = Exe.FindFunction("MessageBoxA", "USER32.dll");
    if (offset2 === -1)
        return "Failed in Step 3 - MessageBoxA not found";

    //Step 3.3 - Find ERROR reference followed by MessageBoxA call
    code =
        " 68" + Num2Hex(offset)     //PUSH OFFSET addr; ASCII "ERROR"
    +   " ??"                       //PUSH reg32_A
    +   " ??"                       //PUSH reg32_B
    +   " FF 15" + Num2Hex(offset2) //CALL DWORD PTR DS:[<&USER32.MessageBoxA>]
    ;
    offset = Exe.FindHex(code);

    if (offset === -1)
    {
        code = code.replace(" ?? ?? FF 15", " ?? 6A 00 FF 15"); //Change PUSH reg32_B with PUSH 0
        offset = Exe.FindHex(code);
    }
    if (offset !== -1)
    {
        //Step 3.3 - Find the JNE after it that skips the HShield calls
        code =
            " 80 3D ?? ?? ?? 00 00" //CMP BYTE PTR DS:[addr1], 0
        +   " 75"                   //JNE SHORT addr2
        ;
        offset2 = Exe.FindHex(code, offset, offset + 0x80);

        if (offset2 === -1)
        {
            code =
                " 39 ?? ?? ?? ?? 00" //CMP DWORD PTR DS:[addr1], reg32_A
            +   " 75"                //JNE SHORT addr2
            ;
            offset2 = Exe.FindHex(code, offset, offset + 0x80);
        }

        //Step 3.4 - Replace JNE with JMP to always skip
        if (offset2 !== -1)
            Exe.ReplaceInt8(offset2 + code.byteCount() - 1, 0xEB);//change JNE to JMP
    }

    //Step 3.5 - Skip remaining stuff as Custom DLL cannot be added for newest unpacked clients
    if (Exe.GetDate() > 20140700)
        return true;

    ///======================================///
    /// Now we will remove aossdk.dll Import ///
    ///======================================///

    //Step 4.1 - Find "aossdk.dll"
    var aOffset = Exe.FindString("aossdk.dll", VIRTUAL, false);
    if (aOffset === -1)
        return "Failed in Step 4";

    //Step 4.2 - Construct the Image Descriptor Pattern (Relative Virl Address prefixed by 8 zeros)
    aOffset = " 00".repeat(8) + Num2Hex(aOffset - Exe.GetImgBase());

    //Step 4.3 - Check for Use Custom DLL patch - needed since it modifies the import table location
    var hasCustomDLL = (GetActivePatches().indexOf(211) !== -1);

    if (hasCustomDLL && typeof(Import_Info) !== "undefined")
    {
        //Step 4.4 - If it is used, it means the table has been shifted and all related data is available in Import_Info.
        //           First we will remove the aossdk import entry from the table saved in Import_Info
        var tblData = Import_Info.valueSuf;
        var newTblData = "";

        for (var i = 0; i < tblData.length; i += 20*3)
        {
            var curValue = tblData.substr(i, 20*3);
            if (curValue.indexOf(aOffset) === 3*4)
                continue;//Skip aossdk import rest all are copied

            newTblData = newTblData + curValue;
        }
        if (newTblData !== tblData)
        {
            //Step 4.5 - If the removal was not already done then Empty the Custom DLL patch and make the changes here instead.
            Exe.ClearPatch(211);

            var PEoffset = Exe.GetPE();
            Exe.InsertHex(Import_Info.offset, Import_Info.valuePre + newTblData, (Import_Info.valuePre + newTblData).byteCount());
            Exe.ReplaceInt32(PEoffset + 0x18 + 0x60 + 0x8, Import_Info.tblAddr);
            Exe.ReplaceInt32(PEoffset + 0x18 + 0x60 + 0xC, Import_Info.tblSize);
        }
    }
    else
    {
        //Step 4.6 - If Custom DLL is not present then we need to traverse the Import table and remove the aossdk entry.
        //                    First we get the Import Table address and prep variables
        var dirOffset = Exe.GetDirOffset(1);
        var finalValue = " 00".repeat(20);
        var curValue;
        var lastDLL = "";//
        code = "";//will contain the import table

        for (offset = dirOffset; (curValue = Exe.GetHex(offset, 20)) !== finalValue; offset += 20)
        {
            //Step 4.5 - Get the DLL Name for the import entry
            offset2 = Exe.Virl2Real(Exe.GetInt32(offset + 12) + Exe.GetImgBase());
            var curDLL = Exe.GetString(offset2);

            //Step 4.6 - Make sure its not a duplicate or aossdk.dll
            if (lastDLL === curDLL || curDLL === "aossdk.dll") continue;

            //Step 4.7 - Add the entry to code and save current DLL to compare next iteration
            code += curValue;
            lastDLL = curDLL;
        }
        code += finalValue;

        //Step 4.8 - Overwrite import table with the one we got
        Exe.ReplaceHex(dirOffset, code);
    }
    return true;
}

///============================///
/// Disable Unsupported client ///
///============================///
function DisableHShield_()
{
    return (Exe.FindString("aossdk.dll", REAL) !== -1);
}

//##############################################################\\
//# Rerun the UseCustomDLL function if the Custom DLL patch is #\\
//# selected so that it doesnt accomodate for HShield patch    #\\
//##############################################################\\

function _DisableHShield()
{
    if (GetActivePatches().indexOf(211) !== -1)
    {
        Exe.ClearPatch(211);
        Exe.SetActivePatch(211);
        UseCustomDLL();
    }
}