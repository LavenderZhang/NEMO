///=========================================================///
/// Patch Functions wrapping over SkipCheaterCheck function ///
///=========================================================///

function SkipCheaterFriendCheck()
{
    return SkipCheaterCheck(0);
}

function SkipCheaterGuildCheck()
{
    return SkipCheaterCheck(1);
}

//##########################################################################\\
//# Change the JZ to JMP after CSession::IsCheatName/IsGuildCheatName call #\\
//# inside UIWindowMgr::AddWhisperChatToWhisperWnd to ignore its result    #\\
//##########################################################################\\

function SkipCheaterCheck(index)
{
    //Step 1 - Find the Comparisons after CSession::IsCheatName CALL
    var template =
        " 85 C0"                //TEST EAX, EAX
    +   " 74 ??"                //JZ SHORT addr
    +   " 6A 00"                //PUSH 0
    +   " 6A 00"                //PUSH 0
    +   " 68 FF FF 00 00"       //PUSH 0FFFF
    +   " 68" + MakeVar(1)      //PUSH msgNum
    ;
    var code =
        SetValue(template, 1, 0x395)    //msgNum = 0x395
    +   " EB ??"                        //JMP SHORT addr2
    +   " ??"                           //PUSH reg32_B
    +   " B9 ?? ?? ?? 00"               //MOV ECX, OFFSET g_session
    +   " E8 ?? ?? ?? 00"               //CALL CSession::IsGuildCheatName
    +   SetValue(template, 1, 0x397)    //msgNum = 0x397
    ;
    var offset = Exe.FindHex(code);

    if (offset === -1)
    {
        code = code.replace(/6A 00 6A 00/g, "?? ??"); //Change PUSH 0 with PUSH reg32
        offset = Exe.FindHex(code);
    }
    if (offset === -1)
        return "Failed in Step 1";

    //Step 2 - Change the relevant JZ to JMP
    if (index === 1)
        offset += code.byteCount() - template.byteCount();

    Exe.ReplaceInt8(offset + 2, 0xEB);
    return true;
}