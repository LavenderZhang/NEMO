//####################################################\\
//# Make client Ignore the character check result of #\\
//# space in Guild names inside CGameMode::SendMsg   #\\
//####################################################\\

function AllowSpaceInGuildName()
{
    //Step 1.1 - Find the comparison code
    var code =
        " 6A 20"    //PUSH 20
    +   " ??"       //PUSH reg32_B
    +   " FF ??"    //CALL reg32_A; MSVCR#.strchr
    +   " 83 C4 08" //ADD ESP, 8
    +   " 85 C0"    //TEST EAX, EAX
    ;

    var offset = Exe.FindHex(code);
    if (offset === -1)
        return "Failed in Step 1";

    //Step 1.2 - Update offset to location after TEST
    offset += code.byteCount();

    //Step 2 - Overwrite Conditional Jump after TEST. Skip JNEs and change JZ to JMP
    code = "";
    switch (Exe.GetUint8(offset))
    {
        case 0x74:
        {
            code = "EB"; //Change JE SHORT to JMP SHORT
            break;
        }
        case 0x75:
        {
            code = "90 90"; //NOPs
            break;
        }
        case 0x0F:
        {
            switch(Exe.GetUint8(offset+1))
            {
                case 0x84:
                {
                    code = "90 E9"; //JE to JMP
                    break;
                }
                case 0x85:
                {
                    code = "EB 04"; //JNZ to JMP 4 bytes later. alternative to NOP
                    break;
                }
            }
        }
    }
    if (code === "")
        return "Failed in Step 2 - No JMP formats follow code";

    Exe.ReplaceHex(offset, code);
    return true;
}

///==============================///
/// Disable for Unsupported date ///
///==============================///
function AllowSpaceInGuildName_()
{
    return (Exe.GetDate() >= 20120207);
}