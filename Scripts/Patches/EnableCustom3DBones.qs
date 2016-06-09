//############################################################\\
//# Modify the comparisons in C3dGrannyBoneRes::GetAnimation #\\
//# to always use gr2 from 3dmob_bone folder                 #\\
//############################################################\\

function EnableCustom3DBones()
{
    //Step 1.1 - Find the sprintf control string for 3d mob bones
    var offset = Exe.FindString("model\\3dmob_bone\\%d_%s.gr2", VIRTUAL);
    if (offset === -1)
        return "Failed in Step 1 - String not found";

    //Step 1.2 - Find its reference which is inside C3dGrannyBoneRes::GetAnimation
    var offset2 = Exe.FindHex("68" + Num2Hex(offset));
    if (offset2 === -1)
        return "Failed in Step 1 - String reference missing";

    //Step 2.1 - Find Limiting CMP instruction within this function before the reference (should be within 0x80 bytes)
    var code =
        " C6 05 ?? ?? ?? 00 00" //MOV BYTE PTR DS:[addr], 0
    +   " 83 FE 09"             //CMP ESI, 9
    ;
    offset = Exe.FindHex(code, offset2 - 0x80, offset2);

    if (offset === -1)
    {
        code = code.replace("09", "0A"); //Change the 09h to 0Ah for VC6 clients
        offset = Exe.FindHex(code, offset2 - 0x80, offset2);
    }
    if (offset === -1)
        return "Failed in Step 2 - Comparison missing";

    //Step 2.2 - Update offset to location after CMP
    offset += code.byteCount();

    //Step 2.3 - Find the Index test after ID Comparison (should be within 0x20 bytes)
    code =
        " 85 FF" //TEST EDI, EDI
    +   " 75 27" //JNE SHORT addr
    ;
    offset2 = Exe.FindHex(code, offset, offset + 0x20);

    if (offset2 === -1)
    {
        code = code.replace("27", "28"); //VC10 and older has 28 instead of 27
        offset2 = Exe.FindHex(code, offset, offset + 0x20);
    }
    if (offset2 === -1)
        return "Failed in Step 2 - Index Test missing";

    //Step 3.1 - NOP out the TEST & Modify the short JNE to JMP at offset2
    Exe.ReplaceHex(offset2, "90 90 EB");

    //Step 3.2 - Modify the JA/JGE instruction at offset to just skip the Jump.
    switch (Exe.GetUint8(offset))
    {
        case 0x77:
        case 0x7D: // Short JA/JGE
        {
            Exe.ReplaceHex(offset, "90 90");
            break;
        }
        case 0x0F: // Long JA/JGE
        {
            Exe.ReplaceHex(offset, "EB 04");
            break;
        }
        default:
        {
            return "Failed in Step 3";
        }
    }

    //Step 4.1 - Find the annoying warning
    offset = Exe.FindString("too many vertex granny model!", VIRTUAL);

    //Step 4.2 - Find its reference + the function CALL after
    if (offset !== -1)
        offset = Exe.FindHex("68" + Num2Hex(offset) + " E8");

    //Step 4.3 - NOP out the CALL
    if (offset !== -1)
        Exe.ReplaceHex(offset + 5, "90 90 90 90 90");

    return true;
}