//########################################################\\
//# Change the JE after comparison of g_useEffect with 0 #\\
//# to JMP in Hallucination Effect maker function        #\\
//########################################################\\

function DisableHallucinationWavyScreen() //Missing Comparison in pre-2010 clients
{
    //Step 1.1 - Find "xmas_fild01.rsw"
    var offset = Exe.FindString("xmas_fild01.rsw", VIRTUAL);
    if (offset === -1)
        return "Failed in Step 1 - xmas_fild01 not found";

    //Step 1.2 - Find its references. Preceding the one inside CGameMode::Initialize
    //           one of them is an assignment to g_useEffect

    var offsets = Exe.FindAllHex("B8" + Num2Hex(offset)); //MOV EAX, OFFSET addr; ASCII "xmas_fild01.rsw"
    if (offsets.length === 0)
        return "Failed in Step 1 - xmas_fild01 references missing";

    //Step 1.3 - Look for the correct location inside CGameMode::Initialize in offsets[]
    var code = " 89 ?? ?? ?? ?? 00"; //MOV DWORD PTR DS:[g_useEffect], reg32_A

    for (var i = 0; i < offsets.length; i++)
    {
        offset = Exe.FindHex(code, offsets[i] - 8, offsets[i]);
        if (offset !== -1 && (Exe.GetUint8(offset + 1) & 0xC7) === 0x5)
            break;
        else
            offset = -1;
    }
    if (offset === -1)
        return "Failed in Step 1 - no references matched";

    //Step 1.4 - Extract g_useEffect
    var gUseEffect = Exe.GetHex(offset + 2, 4);

    //Step 2.1 - Find the Comparison we need
    code =
        " 8B ??"                      //MOV ECX, reg32
    +   " E8 ?? ?? ?? ??"             //CALL addr1
    +   " 83 3D" + gUseEffect + " 00" //CMP DWORD PTR DS:[g_useEffect], 0
    +   " 0F 84"                      //JE addr2
    ;
    offset = Exe.FindHex(code);

    if (offset === -1)
    {
        code = code.replace("83 3D" + gUseEffect + " 00", "A1" + gUseEffect + " 85 C0");//Change CMP with MOV EAX, DS:[g_useEffect] followed by TEST EAX, EAX
        offset = Exe.FindHex(code);
    }
    if (offset === -1)
        return "Failed in Step 2";

    //Step 2.2 - Replace the JE with NOP + JMP
    Exe.ReplaceHex(offset + code.byteCount() - 2, "90 E9");
    return true;
}

///==============================///
/// Disable for Unsupported date ///
///==============================///
function DisableHallucinationWavyScreen_()
{
    return (Exe.GetDate() <= 20120516);//New client uses Inverted Screen effect. Havent figured out where it is
}