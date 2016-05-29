//###################################################################\\
//# Hijack Quest_function lua file loading to load lua files        #\\
//# specified in the input file first before loading Quest_function #\\
//###################################################################\\

function LoadCustomQuestLua()
{
    //Step 1 - Check if Quest_function is being loaded (same check as below but adding again just for safety)
    var prefix = "lua files\\quest\\";
    if (Exe.FindString(prefix + "Quest_function", REAL) === -1)
        return "Failed in Step 1 - Quest_function not found";

    //Step 2.1 - Get the list file
    var inFile = Exe.GetUserInput("$inpQuest", I_FILE, 'File Input - Load Custom Quest Lua', 'Enter the Lua list file', APP_PATH);
    if (!inFile)
        return "Patch Cancelled";

    //Step 2.2 - Get the filenames from the list file
    var files = [];
    var ssize = 0;

    var Fp = new File();
    Fp.Open(inFile);

    while (!Fp.IsEOF())
    {
        var line = Fp.ReadLine().trim();
        if (line.charAt(0) !== "/" && line.charAt(1) !== "/")
        {
            files.push(prefix + line);
            ssize += prefix.length + line.length + 1;
        }
    }
    Fp.Close();

    if (files.length > 0)
    {
        //Step 3 - Inject the files
        var retVal = AddLuaLoaders(prefix + "Quest_function", files);
        if (typeof(retVal) === "string")
            return "Failed in Step 3 - " + retVal;
    }
    return true;
}

///================================================================///
/// Disable for Unsupported client - Quest_function not even there ///
///================================================================///
function LoadCustomQuestLua_()
{
    return (Exe.FindString("lua files\\quest\\Quest_function", REAL) !== -1);
}