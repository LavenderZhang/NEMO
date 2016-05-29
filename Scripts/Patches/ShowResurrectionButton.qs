//###################################################################################\\
//# Modify the CGameMode::HaveSiegfriedItem function to ignore map type comparisons #\\
//###################################################################################\\

function ShowResurrectionButton() //To do - When on PVP/GVG map the second time u die, the char gets warped to save point anyways.
{
    //Step 1.1 - Find the "Token of Siegfried" itemid PUSH in CGameMode::HaveSiegfriedItem function.
    var offset = Exe.FindHex("68 C5 1D 00 00"); //PUSH 1D5C
    if (offset === -1)
        return "Failed in Step 1";

    //Step 1.2 - Update offset to location after the PUSH, MOV ECX and CALL . Any other statements in between can vary
    offset += 15;

    //Step 2.1 - Find the triple comparisons after the PUSH (unknown param, PVP, GVG)
    var code =
        " 8B 48 ??" //MOV ECX, DWORD PTR DS:[EAX+const]
    +   " 85 C9"    //TEST ECX, ECX
    +   " 75 ??"    //JNE SHORT addr
    ;
    var type = 1;//VC6 style
    var offset2 = Exe.FindHex(code.repeat(3), offset, offset + 0x40);

    if (offset2 === -1)
    {
        code =
            " 83 78 ?? 00" //CMP DWORD PTR DS:[EAX+const], 0
        +   " 75 ??"             //JNE SHORT addr
        ;
        type = 2;//VC9 & VC11 style
        offset2 = Exe.FindHex(code.repeat(3), offset, offset + 0x40);
    }
    if (offset2 === -1)
    {
        code =
            " 39 58 ??"          //CMP DWORD PTR DS:[EAX+const], reg32
        +   " 0F 85 ?? 00 00 00" //JNE addr
        ;
        type = 3;//VC10 style
        offset2 = Exe.FindHex(code.repeat(3), offset, offset + 0x40);
    }
    if (offset2 === -1)
        return "Failed in Step 2 - No comparisons matched";

    //Step 2.2 - Skip over the 3 comparisons using a short JMP
    Exe.ReplaceHex(offset2, "EB" + Num2Hex(3 * code.byteCount() - 2, 1));
    return true;
}