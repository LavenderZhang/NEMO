//#####################################################################\\
//# Modify ErrorMsg function to return without showing the MessageBox #\\
//#####################################################################\\

function IgnoreResourceErrors()
{
    //Step 1 - Find the ErrorMsg(msg) function - New Client has different pattern
    var code =
        " E8 ?? ?? ?? FF"    //CALL GDIFlip
    +   " 8B 44 24 04"       //MOV EAX, DWORD PTR SS:[ESP+4]
    +   " 8B 0D ?? ?? ?? 00" //MOV ECX, DWORD PTR DS:[g_hMainWnd]
    +   " 6A 00"             //PUSH 0
    ;

    if (EBP_TYPE)
        code = code.replace("44 24 04", "45 08"); //Change ESP+4 to EBP-8

    var offset = Exe.FindHex(code);
    if (offset === -1) //New Client - direct PUSHes ugh
    {
        code =
            " E8 ?? ?? ?? FF" //CALL GDIFlip
        +   " 6A 00"          //PUSH 0
        +   " 68 ?? ?? ?? 00" //PUSH OFFSET addr; ASCII "Error"
        +   " FF 75 08"       //PUSH DWORD PTR SS:[EBP+8]
        ;
        offset = Exe.FindHex(code);
    }
    if (offset === -1)
        return "Failed in Step 1";

    //Step 2 - Replace with XOR EAX, EAX followed by RETN . If Frame Pointer is present then a POP EBP comes before RETN
    if (EBP_TYPE)
        Exe.ReplaceHex(offset + 5, " 33 C0 5D C3");
    else
        Exe.ReplaceHex(offset + 5, " 33 C0 C3 90");

    return true;
}