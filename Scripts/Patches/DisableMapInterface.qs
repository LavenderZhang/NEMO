//#########################################################\\
//# Skip over all instances of World View Window creation #\\
//#########################################################\\

function DisableMapInterface()
{
    //Step 1.1 - Check if Window Manager info is available (WM.Error will be a string if not)
    if (WM.Error)
        return "Failed in Step 1 - " + WM.Error;

    //Step 1.2 - Find the creation pattern 1 - There should be exactly 2 matches (map button, shortcut)
    var code =
        " 68 8C 00 00 00"    //PUSH 8C
    +   " B9 ?? ?? ?? 00"    //MOV ECX, g_winMgr
    +   " E8 ?? ?? ?? ??"    //CALL UIWindowMgr::PrepWindow ?
    +   " 84 C0"             //TEST AL, AL
    +   " 0F 85 ?? ?? 00 00" //JNE addr
    +   " 68 8C 00 00 00"    //PUSH 8C
    +   WM.MovEcx            //MOV ECX, g_winMgr
    +   " E8"                //CALL UIWindowMgr::MakeWindow
    ;

    var offsets = Exe.FindAllHex(code);
    if (offsets.length === 0)
        return "Failed in Step 1 - No matches found";

    //Step 1.3 - Change the First PUSH to a JMP to the JNE location and change the JNE to JMP
    for (var i = 0; i < offsets.length; i++)
    {
        Exe.ReplaceHex(offsets[i], "EB 0F");
        Exe.ReplaceHex(offsets[i] + 17, "90 E9");
    }

    //Step 2.1 - Swap the JNE with a JNE SHORT and search pattern - Only for latest clients
    code = code.replace("0F 85 ?? ?? 00 00", "75 ??");

    var offsets = Exe.FindAllHex(code);

    //Step 2.2 - Repeat 1.3 for this set
    for (var i = 0; i < offsets.length; i++)
    {
        Exe.ReplaceHex(offsets[i], "EB 0F");
        Exe.ReplaceHex(offsets[i] + 17, "EB");
    }

    //Step 3.1 - Find pattern 2 - Only for latest clients (func calls functions from pattern 1)
    code =
        " 68 8C 00 00 00" //PUSH 8C
    +   " 8B ??"          //MOV ECX, reg32
    +   " E8 ?? ?? ?? FF" //CALL func ?
    +   " 5E"             //POP ESI
    ;
    var offset = Exe.FindHex(code);

    //Step 3.2 - Replace PUSH with a JMP to the POP ESI
    if (offset !== -1)
        Exe.ReplaceHex(offset, "EB 0A");

    return true;
}