//##################################################################################\\
//# Change the Style parameter used for CreateWindowExA call to include WS_SYSMENU #\\
//##################################################################################\\

function EnableTitleBarMenu()
{
    //Step 1.1 - Find the function's address
    var offset = Exe.FindFunction("CreateWindowExA", "USER32.dll");
    if (offset === -1)
        return "Failed in Step 1 - CreateWindowExA not found";

    //Step 1.2 - Find the Style pushes
    var offsets = Exe.FindAllHex("68 00 00 C2 02"); //PUSH 2C200000 - Style
    if (offsets.length === 0)
        return "Failed in Step 1 - Style not found";

    //Step 1.3 - Find which one precedes Function call
    var code = "FF 15" + Num2Hex(offset); //CALL DWORD PTR DS:[<&USER32.CreateWindowExA>]

    for (var i = 0; i < offsets.length; i++)
    {
        offset = Exe.FindHex(code, offsets[i] + 8, offsets[i] + 29); //5 + 3 for minimum operand pushes, 5 + 18 for maximum operand pushes + 6 for function call
        if (offset !== -1)
        {
            offset = offsets[i];//Get the corresponding Style push offset
            break;
        }
    }
    if (offset === -1)
        return "Failed in Step 1 - Function call not found";

    //Step 2 - Change 0x02C2 => 0x02C2 | WS_SYSMENU = 0x02CA
    Exe.ReplaceInt8(offset + 3, 0xCA);
    return true;
}