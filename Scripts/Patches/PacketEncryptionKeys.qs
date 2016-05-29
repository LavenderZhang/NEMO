///=============================================================///
/// Patch Functions wrapping over PacketEncryptionKeys function ///
///=============================================================///

function PacketFirstKeyEncryption()
{
    return PacketEncryptionKeys("$firstkey", 0);
}

function PacketSecondKeyEncryption()
{
    return PacketEncryptionKeys("$secondkey", 1);
}

function PacketThirdKeyEncryption()
{
    return PacketEncryptionKeys("$thirdkey", 2);
}

//#############################################################################################\\
//# Get the Packet Key Info for loaded client and according to what type of function is used, #\\
//# Replace Packet PUSH Reference or Hijack the Obfuscate2 function to use our code.          #\\
//#############################################################################################\\

PEncKeys = [];//Initialize array to blank before Packet Key Patches are selected. Only needed for Obfuscate2
delete PEncInsert;//Removing any stray values before Packet Key Patches are selected. Only needed for Obfuscate2
delete PEncActive;

function PacketEncryptionKeys(varName, index)
{
    //Step 1.1 - Sanity Check. Check if Packet Encryption is Disabled.
    if (GetActivePatches().indexOf(61) !== -1)
        return "Patch Cancelled - Disable Packet Encryption is ON";

    //Step 1.2 - Check if Packet Key Info is available
    if (PK.Error)
        return "Failed in Step 1 - " + PK.Error;

    //Step 1.3 - Get new Key from user.
    var oldKey = Num2Hex(PK.Keys[index], 4, true);
    var newKey = Exe.GetUserInput(varName, I_HEX, "Hex input", "Enter the new key", oldKey, 4);//4 is used for the mask as well
    if (!newKey)
        return "Patch Cancelled";

    if (newKey === oldKey)
        return "Patch Cancelled - Key not changed";

    if (PK.Type === 0)//Packet Key PUSHed as arguments
    {
        //Step 2.1 - Find all packet Key PUSHes
        var code =
            " 68" + Num2Hex(PK.Keys[2]) //PUSH key3
        +   " 68" + Num2Hex(PK.Keys[1]) //PUSH key2
        +   " 68" + Num2Hex(PK.Keys[0]) //PUSH key1
        +   " E8"                       //CALL CRagConnection::Obfuscate
        ;

        var offsets = Exe.FindAllHex(code);
        if (offsets.length === 0)//Not supposed to happen
            return "Failed in Step 2";

        //Step 2.2 - Replace the PUSHed argument for the index in all of them
        for ( var i = 0; i < offsets.length; i++)
        {
            Exe.ReplaceString(offsets[i] + code.byteCount() - (index + 1) * 5, varName);
        }
    }
    else {
        ///--- Code Preparation ---///
        code = "";

        //Step 3.1 - Fill PEncKeys with existing values if it is empty
        if (PEncKeys.length === 0)
        {
            PEncKeys = PK.Keys;
        }

        //Step 3.2 - Now set the index of PEncKeys with new value
        PEncKeys[index] = parseInt(newKey, 16);

        //Step 3.3 - Prep the stack restore + RETN suffix
        if (EBP_TYPE)
            var suffix = " 5D";
        else
            var suffix = "";

        suffix += " C2 04 00"; //RETN 4

        //Step 3.4 - First add encryption & zero assigner codes for Type 2 (function is Virlized so we need to write the entire function not just part of it)
        if (PK.Type === 2)
        {
            if (EBP_TYPE)
                code += " 8B 45 08";    //MOV EAX, DWORD PTR SS:[EBP+8]
            else
                code += " 8B 44 24 04"; //MOV EAX, DWORD PTR SS:[ESP+4]

            code +=
                " 85 C0"          //TEST EAX,EAX
            +   " 75 19"          //JNE SHORT addr1
            +   " 8B 41 08"       //MOV EAX,DWORD PTR DS:[ECX+8]
            +   " 0F AF 41 04"    //IMUL EAX,DWORD PTR DS:[ECX+4]
            +   " 03 41 0C"       //ADD EAX,DWORD PTR DS:[ECX+0C]
            +   " 89 41 04"       //MOV DWORD PTR DS:[ECX+4],EAX
            +   " C1 E8 10"       //SHR EAX,10
            +   " 25 FF 7F 00 00" //AND EAX,00007FFF
            +   suffix
            +   " 83 F8 01"       //CMP EAX,1 <= addr1
            +   " 74 0F"          //JE SHORT addr2 ; addr2 is after the RETN 4 below
            +   " 31 C0"          //XOR EAX,EAX
            +   " 89 41 04"       //MOV DWORD PTR DS:[ECX+4],EAX
            +   " 89 41 08"       //MOV DWORD PTR DS:[ECX+8],EAX
            +   " 89 41 0C"       //MOV DWORD PTR DS:[ECX+0C],EAX
            +   suffix
            ;

            if (suffix.byteCount() !== 4) //adjust the JE & JNE
            {
                code = code.replace(" 75 19", "75 18").replace(" 74 0F", " 74 0E");
            }
        }

        //Step 3.5 - Add the code for assigning the Initial Keys
        code +=
            " C7 41 04" + Num2Hex(PEncKeys[0]) //MOV DWORD PTR DS:[ECX+4], key1
        +   " C7 41 08" + Num2Hex(PEncKeys[1]) //MOV DWORD PTR DS:[ECX+8], key2
        +   " C7 41 0C" + Num2Hex(PEncKeys[2]) //MOV DWORD PTR DS:[ECX+C], key3
        +   " 33 C0"                           //XOR EAX, EAX
        +   suffix
        ;

        //Step 4.1 - Check if PEncInsert is already defined. If it is we need to empty the other Patches.
        if (typeof(PEncInsert) !== "undefined")
        {
            for (var i = 0; i < 3; i++)
            {
                if (i === index)
                    continue;

                Exe.ClearPatch(92 + i);
            }
        }

        //Step 4.2 - Find Free space for insertion
        var csize = code.byteCount();
        var free = Exe.FindSpace(csize);
        if (free === -1)
            return "Failed in Step 4 - Not Enough Free Space";

        PEncInsert = Exe.Real2Virl(free, DIFF);

        //Step 4.3 - Insert the code at free space
        Exe.InsertHex(free, code, csize);

        //Step 4.4 - Hijack PK.OvrAddr to jmp to PEncInsert
        code = "E9" + Num2Hex(PEncInsert - Exe.Real2Virl(PK.OvrAddr + 5)); //JMP PEncInsert
        Exe.ReplaceHex(PK.OvrAddr, code);

        //Step 4.5 - Set PEncActive to index indicating this one has the changes
        PEncActive = index;
    }
    return true;
}

///================================================================///
/// Patch Destructor Functions wrapping over _PacketEncryptionKeys ///
///================================================================///

function _PacketFirstKeyEncryption()
{
    return _PacketEncryptionKeys(0);
}

function _PacketSecondKeyEncryption()
{
    return _PacketEncryptionKeys(1);
}

function _PacketThirdKeyEncryption()
{
    return _PacketEncryptionKeys(2);
}

//################################################################\\
//# Move the insert operation to any of the other active patches #\\
//################################################################\\

function _PacketEncryptionKeys(index) {

    //Step 1.1 - Check if PEncInsert is defined. Remaining steps are needed only if it is
    if (typeof(PEncInsert) === "undefined")
        return;

    //Step 1.2 - Assign PEncActive to an active Packet Key Patch that is not associated with index
    if (PEncActive === index)
    {
        var patches = GetActivePatches();
        for (var i = 0; i < 3; i++)
        {
            if (patches.indexOf(92 + i) !== -1)
            {
                PEncActive = i;
                break;
            }
        }
    }

    //Step 1.3 - Clear Everything if no other patch is active
    if (PEncActive === index)
    {
        delete PEncActive;
        delete PEncInsert;
        PEncKeys = [];
        return false;
    }

    //Step 1.4 - Set Current Patch so the insert will be assigned to it
    Exe.SetActivePatch(92 + PEncActive);
    Exe.ClearPatch(92 + PEncActive);

    //Step 2.2 - Change the Packet Key referred by index to the original one.
    PEncKeys[index] = PK.Keys[index];

    //Step 2.3 - Prep Code to insert
    var code =
        " C7 41 04" + Num2Hex(PEncKeys[0]) //MOV DWORD PTR DS:[ECX+4], key1
    +   " C7 41 08" + Num2Hex(PEncKeys[1]) //MOV DWORD PTR DS:[ECX+8], key2
    +   " C7 41 0C" + Num2Hex(PEncKeys[2]) //MOV DWORD PTR DS:[ECX+C], key3
    +   " 33 C0"                           //XOR EAX, EAX
    ;

    if (EBP_TYPE)
        code += "5D";    //POP EBP

    code += " C2 04 00"; //RETN 4

    var csize = code.byteCount();

    //Srep 2d - Insert the code
    Exe.InsertHex(Exe.Virl2Real(PEncInsert), code, csize);

    //Step 2.5 - Hijack PK.OvrAddr to jmp to PEncInsert
    code = "E9" + Num2Hex(PEncInsert - Exe.Real2Virl(PK.OvrAddr + 5));//JMP PEncInsert
    Exe.ReplaceHex(PK.OvrAddr, code);

    return true;
}