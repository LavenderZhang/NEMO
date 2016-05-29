//#####################################################################\\
//# Replace guild chat color inside CGameMode::Zc_guild_chat function #\\
//#####################################################################\\

function ChatColorGuild()
{
    //Step 1 - Find location where the original color is pushed
    var code =
        " 6A 04"          //PUSH 4
    +   " 68 B4 FF B4 00" //PUSH B4,FF,B4 (Light Green)
    ;
    var offset = Exe.FindHex(code);

    if (offset ===  -1)
    {
        code = code.replace("6A 04", "6A 04 8D ?? ?? ?? FF FF");//LEA reg32_A, [EBP-x] comes in between the two instructions
        offset = Exe.FindHex(code);
    }

    if (offset === -1)
        return "Failed in Step 1";

    //Step 2.1 - Get new color from user
    var color = Exe.GetUserInput("$guildChatColor", I_COLOR, "Guild Chat", "Select the new color", 0x00B4FFB4);
    if (color === 0x00B4FFB4)
        return "Patch Cancelled - New Color is same as old";

    //Step 2.2 - Replace with new color
    Exe.ReplaceString(offset + code.byteCount() - 4, "$guildChatColor");

    return true;
}

//####################################################################################\\
//# Replace all the colors assigned for GM inside CGameMode::Zc_Notify_Chat function #\\
//####################################################################################\\

function ChatColorGM()
{
    //Step 1.1 - Find FF, 8D, 1D (Orange) PUSH done for langtype 11
    var offset1 = Exe.FindHex("68 FF 8D 1D 00");
    if (offset1 === -1)
        return "Failed in Step 1 - Orange color not found";

    //Step 1.2 - Find FF, FF, 00 (Cyan) PUSH in the vicinity of Orange
    var offset2 = Exe.FindHex("68 FF FF 00 00", offset1 - 0x30, offset1 + 0x30);
    if (offset2 === -1)
        return "Failed in Step 1 - Cyan not found";

    //Step 1.3 - Find 00, FF, FF (Yellow) PUSH in the vicinity of Orange
    var offset3 = Exe.FindHex("68 00 FF FF 00", offset1 - 0x30, offset1 + 0x30);
    if (offset3 === -1)
        return "Failed in Step 1 - Yellow not found";

    //Step 2.1 - Get the new color from user
    var color = Exe.GetUserInput("$gmChatColor", I_COLOR, "GM Chat", "Select the new color", 0x0000FFFF);
    if (color === 0x0000FFFF)
        return "Patch Cancelled - New Color is same as old";

    //Step 2.2 - Replace all the colors with new color
    Exe.ReplaceString(offset1 + 1, "$gmChatColor");
    Exe.ReplaceString(offset2 + 1, "$gmChatColor");
    Exe.ReplaceString(offset3 + 1, "$gmChatColor");

    return true;
}

//##########################################################################################\\
//# Replace Chat color assigned for Player inside CGameMode::Zc_Notify_PlayerChat function #\\
//##########################################################################################\\

function ChatColorPlayerSelf() //Pattern not checked for Pre-2010 client
{
    //Step 1.1 - Find locations of PUSH 00,78,00 (Dark Green)
    var offsets = Exe.FindAllHex(" 68 00 78 00 00");
    if (offsets.length === 0)
        return "Failed in Step 1 - Dark Green missing";

    //Step 1.2 - Find the Green color push within the vicinity of one of the offsets
    for (var i = 0; i < offsets.length; i++)
    {
        var offset = Exe.FindHex(" 68 00 FF 00 00", offsets[i] + 5, offsets[i] + 40);
        if (offset !== -1)
            break;
    }
    if (offset === -1)
        return "Failed in Step 1 - Green not found";

    //Step 2.1 - Get the new color from user
    var color = Exe.GetUserInput("$yourChatColor", I_COLOR, "My Chat", "Select the new color", 0x0000FF00);
    if (color === 0x0000FF00)
        return "Patch Cancelled - New Color is same as old";

    //Step 2.2 - Replace with new color
    Exe.ReplaceString(offset + 1, "$yourChatColor");

    return true;
}

//###########################################################################\\
//# Replace Chat color assigned for Player inside CGameMode::Zc_Notify_Chat #\\
//# function for received messages                                          #\\
//###########################################################################\\

function ChatColorPlayerOther()
{
    //Step 1 - Find location where the original color is pushed
    var code =
        " 6A 01"           //PUSH 1
    +   " 68 FF FF FF 00"  //PUSH FF,FF,FF (White)
    ;

    var offset = Exe.FindHex(code);
    if (offset === -1)
        return "Failed in Step 1";

    //Step 2.1 - Get the new color from user
    var color = Exe.GetUserInput("$otherChatColor", I_COLOR, "Other Player Chat", "Select the new color", 0x00FFFFFF);
    if (color === 0x00FFFFFF)
        return "Patch Cancelled - New Color is same as old";

    //Step 2.1 - Replace with new color
    Exe.ReplaceString(offset + code.byteCount() - 4, "$otherChatColor");;

    return true;
}

//##########################################################################################\\
//# Replace Chat color assigned for Player inside CGameMode::Zc_Notify_Chat_Party function #\\
//##########################################################################################\\

function ChatColorPartySelf()
{
    //Step 1 - Find the area where color is pushed
    var code =
        " 6A 03"          //PUSH 3
    +   " 68 FF C8 00 00" //PUSH FF,C8,00 (Yellowish Brown)
    ;
    var offset = Exe.FindHex(code);

    if (offset === -1)
    {
        code = code.replace("6A 03", "6A 03 8D ?? ?? ?? FF FF"); //LEA reg32_A, [EBP-x] comes in between the two instructions
        offset = Exe.FindHex(code);
    }

    if (offset === -1)
        return "Failed in Step 1";

    //Step 2.1 - Get the new color from user
    var color = Exe.GetUserInput("$yourpartyChatColor", I_COLOR, "My Party Chat", "Select the new color", 0x0000C8FF);
    if (color === 0x0000C8FF)
        return "Patch Cancelled - New Color is same as old";

    //Step 2.2 - Replace with new color
    Exe.ReplaceString(offset + code.byteCount() - 4, "$yourpartyChatColor");;

    return true;
}

//#################################################################################\\
//# Replace Chat color assigned for Player inside CGameMode::Zc_Notify_Chat_Party #\\
//# function for Other Members' messages                                          #\\
//#################################################################################\\

function ChatColorPartyOther()
{
    //Step 1a - Find the area where color is pushed
    var code =
        " 6A 03"          //PUSH 3 ; old clients have an extra instruction after this one
    +   " 68 FF C8 C8 00" //PUSH FF,C8,C8 (Light Pink)
    ;
    var offset = Exe.FindHex(code);

    if (offset === -1)
    {
        code = code.replace("6A 03", "6A 03 8D ?? ?? ?? FF FF"); //LEA reg32_A, [EBP-x] comes in between the two instructions
        offset = Exe.FindHex(code);
    }

    if (offset === -1)
        return "Failed in Step 1";

    //Step 2.1 - Get the new color from user
    var color = Exe.GetUserInput("$otherpartyChatColor", I_COLOR, "Other Party Member Chat", "Select the new Color", 0x00C8C8FF);
    if (color === 0x00C8C8FF)
        return "Patch Cancelled - New Color is same as old";

    //Step 2.2 - Replace with new color
    Exe.ReplaceString(offset + code.byteCount() - 4, "$otherpartyChatColor");;

    return true;
}

//ChatColorMain - original implementation is identical ChatColorGM hence not added.