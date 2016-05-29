//###################################################################################\\
//# Modify the Siege mode & BG mode check Jumps to Display Emblem when either is ON #\\
//###################################################################################\\

function EnableEmblemForBG()
{
    //Step 1.1 - Look for the Mode checking pattern
    var code =
        " B9 ?? ?? ?? 00" //MOV ECX, OFFSET g_session
    +   " E8 ?? ?? ?? 00" //CALL CSession::IsSiegeMode
    +   " 85 C0"          //TEST EAX, EAX
    +   " 74 ??"          //JZ SHORT addr
    +   " B9 ?? ?? ?? 00" //MOV ECX, OFFSET g_session
    +   " E8 ?? ?? ?? 00" //CALL CSession::IsBgMode
    +   " 85 C0"          //TEST EAX, EAX
    +   " 75 ??"          //JNZ SHORT addr ;?? at the end is needed
    ;
    
    var offset = Exe.FindHex(code);
    if (offset === -1)
        return "Failed in Step 1";
 
    //Step 1.2 - Calculate the code size & its half (will point to the second MOV ECX when added to offset)
    var csize = code.byteCount();
    var hsize = csize/2;
    
    //Step 2.1 - Change the first JZ to JNZ and addr to location after the code
    Exe.ReplaceHex(offset + hsize - 2, "75" + Num2Hex(hsize, 1));
    
    //Step 2.2 - Change the second JNZ to JZ
    Exe.ReplaceInt8(offset + csize - 2, 0x74);
    return true;
}
