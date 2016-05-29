//#############################################################\\
//# Modify the Cancel Button Case in UISelectCharWnd::SendMsg #\\
//# to disconnect and show the Login Window                   #\\
//#############################################################\\

function CancelToLoginWindow()
{
    //Step 1.1 - Sanity Check. Make Sure Restore Login Window is enabled.
    if (GetActivePatches().indexOf(40) === -1)
        return "Patch Cancelled - Restore Login Window patch is necessary but not enabled";

    //Step 1.2 - Find the case branch that occurs before the Cancel Button case.
    //           The pattern will match multiple locations of which 1 (or recently 2) is the one we need
    var code =
        " 8D ?? ?? ?? ?? ?? 00" //LEA reg32_B, [reg32_A*8 + refAddr]
    +   " ??"                   //PUSH reg32_B
    +   " 68 37 03 00 00"       //PUSH 337
    +   " E8"                   //CALL addr
    ;
    var offsets = Exe.FindAllHex(code);
    if (offsets.length === 0)
        return "Failed in Step 1 - Reference case missing";

    var csize = code.byteCount() + 4;

    /***** Get all required common data *****/

    //Step 2.1 - Find CConnection::Disconnect & CRagConnection::instanceR calls
    code =
        " 83 C4 08"       //ADD ESP, 8
    +   " E8 ?? ?? ?? 00" //CALL CRagConnection::instanceR
    +   " 8B C8"          //MOV ECX, EAX
    +   " E8 ?? ?? ?? 00" //CALL CConnection::Disconnect
    +   " B9 ?? ?? ?? 00" //MOV ECX, OFFSET addr
    ;
    var offset = Exe.FindHex(code);

    if (offset === -1)
    {
        code = code.replace(/ E8 ?? ?? ?? 00/g, " E8 ?? ?? ?? FF");
        offset = Exe.FindHex(code);
    }
    if (offset === -1)
        return "Failed in Step 2 - connection functions missing";

    //Step 2.2 - Extract the REAL addresses. Not much point in converting to VIRTUAL (same section -_-)
    var crag = (offset + 08) + Exe.GetInt32(offset + 04);
    var ccon = (offset + 15) + Exe.GetInt32(offset + 11);

    //Step 2.3 - Find 메시지 => Korean version of "Message"
    offset = Exe.FindString("\xB8\xDE\xBD\xC3\xC1\xF6", VIRTUAL);
    if (offset === -1)
        return "Failed in Step 2 - Message not found";

    //Step 2.4 - Prep Cancel case pattern to look for
    var canceller =
        " 68" + Num2Hex(offset) //PUSH addr ; "메시지"
    +   " ??"                   //PUSH reg32_A ; contains 0
    +   " ??"                   //PUSH reg32_A
    +   " 6A 01"                //PUSH 1
    +   " 6A 02"                //PUSH 2
    +   " 6A 11"                //PUSH 11
    ;
    var cansize = canceller.byteCount();
    var matchcount = 0;

    for (var i = 0; i < offsets.length; i++)
    {
        /***** First we find all required addresses *****/

        //Step 3.1 - Find the cancel case after offsets[i] using the 'canceller' pattern
        //           We are looking for the msgBox creator that shows the quit message
        offsets[i] += csize;
        offset = Exe.FindHex(canceller, offsets[i], offsets[i] + 0x80);

        if (offset === -1)
        {
            var zeroPush = " 6A 00";
            offset = Exe.FindHex(canceller.replace("?? ??", "6A 00 6A 00"), offsets[i], offsets[i] + 0x80);
        }
        else
        {
            var zeroPush = Exe.GetHex(offset + 5, 1);
        }
        if (offset === -1)
            continue;

        //Step 3.2 - Check for PUSH 118 before offset (only 2013+ clients have that for msgBox creation)
        if (Exe.GetHex(offset - 5, 5) === " 68 18 01 00 00")
            offset -= 7;

        //Step 3.3 - Find the end point of the msgBox call.
        //           There will be a comparison for the return code
        code =
            " 3D ?? 00 00 00"    //CMP EAX, const
        +   " 0F 85 ?? ?? 00 00" //JNE addr; skip quitting.
        ;
        var offset2 = Exe.FindHex(code, offset + cansize, offset + cansize + 40);

        if (offset2 === -1)
        {
            code = code.replace("3D ?? 00 00 00", "83 F8 ??");
            offset2 = Exe.FindHex(code, offset + cansize, offset + cansize + 40);
        }
        if (offset2 === -1)
            continue;

        //Step 3.4 - Update offset to location after the JNE
        offset2 += code.byteCount();

        //Step 3.5 - Lastly we find PUSH 2 below offset2 which serves as argument to the register call (CALL reg32 / CALL DWORD PTR DS:[reg32+18]) - Window Maker?.
        //           What we need to do is to substitute the 2 with 2723 for it to show Login Window instead of quitting.
        code =
            zeroPush.repeat(3) //PUSH reg32 x3 or PUSH 0 x3
        +   " 6A 02"           //PUSH 2
        ;

        var offset3 = Exe.FindHex(code, offset2, offset2 + 0x20);
        if (offset3 === -1)
            continue;

        //Step 3.6 - Update offset to location of PUSH 2
        offset3 += code.byteCount() - 2;

        /***** Now to construct the replace code *****/

        //Step 4.1 - First Disconnect from Char Server
        code =
            " E8" + MakeVar(1) //CALL CRagConnection::instanceR
        +   " 8B C8"           //MOV ECX, EAX
        +   " E8" + MakeVar(2) //CALL CConnection::disconnect
        ;

        //Step 4.2 - Extract and paste all the code between offset2 and offset3 to prep the register call (Window Maker)
        code += Exe.GetHex(offset2, offset3 - offset2);

        //Step 4.3 - PUSH 2723 and go to the location after the original PUSH 2 => offset3 + 2
        code +=
            " 68 23 27 00 00" //PUSH 2723
        +   " EB XX"          //JMP addr; after PUSH 2.
        ;

        //Step 4.4 - Fill in the blanks
        code = SetValue(code, 1, crag - (offset + 05));
        code = SetValue(code, 2, ccon - (offset + 12));
        code = code.replace(" XX", Num2Hex((offset3 + 2) - (offset + code.byteCount()), 1));

        //Step 4.5 - Replace with prepared code
        Exe.ReplaceHex(offset, code);

        matchcount++;
    }

    if (matchcount === 0)
        return "Failed in Step 3 - No references matched";

    return true;
}

///==========================================================================///
/// Disable for Unneeded Clients - Only Certain Client onwards tries to quit ///
///==========================================================================///
function CancelToLoginWindow_()
{
    return (Exe.GetDate() > 20100803);
}