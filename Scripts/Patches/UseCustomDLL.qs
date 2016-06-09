//#####################################################\\
//# Create a new import table containing the existing #\\
//# table and the specified DLL + functions.          #\\
//#####################################################\\

delete Import_Info;//Removing any stray values before Patches are selected
var dllFP = false;

function UseCustomDLL()
{
    //Step 1.1 - Flag for "Disable HShield" patch is ON
    var hasHShield = (GetActivePatches().indexOf(15) !== -1);

    //Step 1.2 - Loop through the table and extract to dirData.
    //           if HShield patch is enabled then skip aossdk entry will be skipped then extracting
    var offset = Exe.GetDirOffset(1);
    var curValue;
    var finalValue = " 00".repeat(20);
    var lastDLL = "";
    var dirData = "";

    for ( ; (curValue = Exe.GetHex(offset, 20)) !== finalValue; offset += 20)
    {
        //Step 1.2.1 - Get the DLL Name for the import entry
        var offset2 = Exe.Virl2Real(Exe.GetInt32(offset + 12) + Exe.GetImgBase());
        var curDLL = Exe.GetString(offset2);//exe.fetch(offset2, offset3 - offset2);

        //Step 1.2.2 - Make sure there is no duplicate
        //if (curDLL === lastDLL) continue;

        //Step 1.2.3 - Skip aossdk if HShield is Disabled
        if (hasHShield && curDLL === "aossdk.dll")
            continue;

        //Step 1.2.4 - Add to dirData and set lastDLL to curDLL
        dirData += curValue;
        lastDLL = curDLL;
    }

    //Step 2.1 - Get the list file containing the dlls and functions to add
    if (!dllFP)
        dllFP = MakeFile('$customDLL', "File Input - Use Custom DLL", "Enter the DLL info file", APP_PATH + "Inputs/dlls.txt");

    if (!dllFP)
        return "Patch Cancelled";

    //Step 2.2 - Read the file and store the dll names and function names into arrays
    var dllNames = [];
    var fnNames = [];
    var dptr = -1;
    while (!dllFP.IsEOF())
    {
        var line = dllFP.ReadLine().trim();
        if (line === "" || line.indexOf("//") == 0)
            continue;

        if (line.length > 4 && (line.indexOf(".dll") - line.length) == -4)
        {
            dptr++;
            dllNames.push({"offset":0, "value":line});
            fnNames[dptr] = [];
        }
        else
            fnNames[dptr].push({"offset":0, "value":line});
    }
    dllFP.Close();

    //Step 3.1 - Construct the String set (all the names) with the stored data
    var dirSize = dirData.byteCount();//Holds the size of Import Directory Table and IAT values
    var strData = "";
    var strSize = 0;//Holds the size of dll names and function names

    for (var i = 0; i < dllNames.length; i++)
    {
        var name = dllNames[i].value;
        dllNames[i].offset = strSize;
        strData = strData + Ascii2Hex(name) + " 00";
        strSize = strSize + name.length + 1;//Space for name
        dirSize = dirSize + 20; //IDIR Entry Size

        for (var j = 0; j < fnNames[i].length; j++)
        {
            var name = fnNames[i][j].value;

            if (name.charAt(0) === ':') //By Ordinal
            {
                fnNames[i][j].offset = 0x80000000 | parseInt(name.substr(1));
            }
            else //By Name
            {
                fnNames[i][j].offset = strSize;
                strData = strData + Num2Hex(j, 2) + Ascii2Hex(name) +   " 00";
                strSize = strSize + 2 + name.length + 1;//Space for name

                if (name.length % 2 != 0) //Even the Odds xD
                {
                    strData = strData + " 00";
                    strSize++;
                }
            }
            dirSize += 4; //Thunk Value VIRTUALs & Ordinals
        }
        dirSize += 4; //Last Value is 00 00 00 00 after Thunks
    }
    dirSize += 20; //Accomodate for IAT End Entry

    //Step 3.2 - Find Free space for insertion
    var free = Exe.FindSpace(strSize + dirSize);
    if (free === -1)
        return "Failed in Step 3 - Not enough free space";

    //Step 3.3 - Construct the new Import table
    var baseAddr = Exe.Real2Virl(free, DIFF) - Exe.GetImgBase();
    var prefix = " 00".repeat(12);
    var dirEntryData = "";
    var dirTableData = "";

    var dptr = 0;
    for (var i = 0; i < dllNames.length; i++)
    {
        if (fnNames[i].length == 0) continue;
        dirTableData = dirTableData + prefix + Num2Hex(baseAddr + dllNames[i].offset) + Num2Hex(baseAddr + strSize + dptr);

        for (var j = 0; j < fnNames[i].length; j++)
        {
            if ((fnNames[i][j].offset & 0x80000000) === 0)
                dirEntryData = dirEntryData + Num2Hex(baseAddr + fnNames[i][j].offset);
            else
                dirEntryData = dirEntryData + Num2Hex(fnNames[i][j].offset);

            dptr += 4;
        }
        dirEntryData = dirEntryData + " 00 00 00 00";
        dptr += 4;
    }
    dirTableData = dirData + dirTableData + finalValue;

    //Step 4.1 - Insert the new table and strings at free space
    Exe.InsertHex(free, strData + dirEntryData + dirTableData, strSize + dirSize);

    //Step 4.2 - Change the PE Table Import Data Directory Address
    var peOffset = Exe.GetPE();
    Exe.ReplaceInt32(peOffset + 0x18 + 0x60 + 0x8, baseAddr + strSize + dirEntryData.byteCount() );
    Exe.ReplaceInt32(peOffset + 0x18 + 0x60 + 0xC, dirTableData.byteCount() - 20);

    //Step 4 - Hint for HShield Patch to not conflict with this one.
    Import_Info =
    {
        "offset":free,
        "valuePre":strData + dirEntryData,
        "valueSuf":dirTableData,
        "tblAddr":baseAddr + strSize + dirEntryData.byteCount(),
        "tblSize":dirTableData.byteCount() - 20
    };

    return true;
}

//#############################################################\\
//# Rerun the DisableHShield function if the HShield patch is #\\
//# selected so that it doesnt accomodate for Custom DLL      #\\
//#############################################################\\

function _UseCustomDLL()
{
    if (GetActivePatches().indexOf(15) !== -1)
    {
        Exe.SetActivePatch(15);
        Exe.ClearPatch(15);
        DisableHShield();
    }
    dllFP = false;
}