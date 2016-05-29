//##############################################################\\
//# Disable the CGameMode::m_lastLockOnPcGid assignment inside #\\
//# CGameMode::ProcessPcPick to ignore shift right click       #\\
//##############################################################\\

function DisableAutofollow()
{
    //Step 1 - Find the assignment statement
    var code =
        " 6A 01"             //PUSH 1
    +   " 6A 1A"             //PUSH 1A
    +   " 8B CE"             //MOV ECX, ESI
    +   " FF ??"             //CALL reg32_A
    +   " 8B ?? ?? ?? 00 00" //MOV reg32_B, DWORD PTR DS:[reg32_C+const]
    +   " A3 ?? ?? ?? 00"    //MOV DWORD PTR DS:[CGameMode::m_lastLockOnPcGid], EAX ;in this instance reg32_B = EAX
    ;
    var offsets = Exe.FindAllHex(code);

    if (offsets.length === 0)
    {
        code = code.replace("FF ??", "FF ?? ??"); //Change CALL reg32_A to CALL DWORD PTR DS:[reg32_C + x]
        offsets = Exe.FindAllHex(code);
    }
    if (offsets.length === 0)
    {
        code = code.replace(" A3", " 89 ??"); //Change EAX to reg32_D
        offsets = Exe.FindAllHex(code);
    }
    if (offsets.length === 0)
        return "Failed in Step 1";

    //Step 2 - NOP out the assignment for the correct match (pattern might match more than one location)
    for (var i = 0; i < offsets.length; i++)
    {
        var offset = offsets[i] + code.byteCount() - 4;
        var opcode = Exe.GetUint8(offset);
        if (opcode === 0xA3) //MOV from EAX
        {
            Exe.ReplaceHex(offset - 1, "90 90 90 90 90");
            break;
        }
        else if (opcode & 0xC7 === 0x5) //MOV from other registers (mode bits should be 0 & r/m bits should be 5)
        {
            Exe.ReplaceHex(offset - 2, "90 90 90 90 90 90");
            break;
        }
    }
    return true;
}