//##########################################################\\
//# Hijack CreateFontA function calls to change the pushed #\\
//# Font Height before Jumping to actual CreateFontA       #\\
//##########################################################\\

function ResizeFont()
{
    //Step 1.1 - Find CreateFontA function address
    var offset = Exe.FindFunction("CreateFontA", "GDI32.dll");
    if (offset === -1)
        return "Failed in Step 1 - CreateFontA not found";

    //Step 1.2 - Find its references i.e. all called locations
    var offsets = Exe.FindAllHex("FF 15" + Num2Hex(offset)); //CALL DWORD PTR DS:[<&GDI32.CreateFontA>]
    if (offsets.length === 0)
        return "Failed in Step 1 - CreateFontA calls missing";

    //Step 2.1 - Construct the Pseudo-CreateFontA function which changes the Font Height
    var code =
        MakeVar(1)                  //This will contain VIRTUAL of 4 bytes later
    +   " C7 44 24 04" + MakeVar(2) //MOV DWORD PTR SS:[ESP+4], newHeight
    +   " FF 25" + MakeVar(3)       //JMP DWORD PTR DS:[<&GDI32.CreateFontA>]
    ;
    var csize = code.byteCount();

    //Step 2.2 - Find Free space for insertion
    var free = Exe.FindSpace(csize);
    if (free === -1)
        return "Failed in Step 2 - Not enough space";

    var freeVirl = Exe.Real2Virl(free, DIFF);

    //Step 2.3 - Get the new Font height
    var newHeight = Exe.GetUserInput('$newFontHgt', I_INT8, "Number Input", "Enter the new Font Height(1-127) - snaps to closest valid value", 10, 1);
    if (newHeight === 10)
        return "Patch Cancelled - New value is same as old";

    //Step 2.4 - Fill in the Blanks
    code = SetValue(code, 1, freeVirl + 4);
    code = SetValue(code, 2, -newHeight);
    code = SetValue(code, 3, offset);

    //Step 3.1 - Insert the code at free space
    Exe.InsertHex(free, code, csize);

    for (var i = 0; i < offsets.length; i++)
    {
        //Step 3.2 - Replace CreateFontA calls with call to freeVirl
        Exe.ReplaceInt32(offsets[i] + 2, freeVirl);
    }

    //Step 3.3 - Look for any JMP to CreateFontA calls as a failsafe
    offset = Exe.FindHex("FF 25" + Num2Hex(offset));

    //Step 3.4 - Same step as 3.2
    if (offset !== -1)
        Exe.ReplaceInt32(offset + 2, freeVirl);

    return true;
}