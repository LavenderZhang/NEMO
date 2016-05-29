///===================================================///
/// Patch Functions wrapping over HideButton function ///
///===================================================///

function HideNavButton()
{
    return HideButton(
        ["navigation_interface\\btn_Navigation", "RO_menu_icon\\navigation"],
        ["\x00", "\x00"]
    );
}

function HideBgButton()
{
    return HideButton(
        ["basic_interface\\btn_battle_field", "RO_menu_icon\\battle"],
        ["\x00", "\x00"]
    );
}

function HideBankButton()
{
    return HideButton(
        ["basic_interface\\btn_bank", "RO_menu_icon\\bank"],
        ["\x00", "\x00"]
    );
}

function HideBooking()
{
    return HideButton(
        ["basic_interface\\booking", "RO_menu_icon\\booking"],
        ["\x00", "\x00"]
    );
}

function HideRodex()
{
    return HideButton("RO_menu_icon\\mail", "\x00");
}

function HideAchieve()
{
    return HideButton("RO_menu_icon\\achievement", "\x00");
}

function HideRecButton()
{
    return HideButton(
        ["replay_interface\\rec", "RO_menu_icon\\rec"],
        ["\x00", "\x00"]
    );
}

///====================================================///
/// Patch Functions wrapping over HideButton2 function ///
///====================================================///

function HideMapButton()
{
    return HideButton2("map");
}

function HideQuest()
{
    return HideButton2("quest");
}

//#################################################\\
//# Find the first match amongst the src prefixes #\\
//# and replace it with corresponding tgt prefix  #\\
//#################################################\\

function HideButton(src, tgt)
{
    //Step 1.1 - Ensure both are lists/arrays
    if (typeof(src) === "string")
        src = [src];

    if (typeof(tgt) === "string")
        tgt = [tgt];

    //Step 1.2 - Loop through and find first match
    var offset = -1;
    for (var i = 0; i < src.length; i++)
    {
        offset = Exe.FindString(src[i], REAL, false);
        if (offset !== -1)
            break;
    }
    if (offset === -1)
        return "Failed in Step 1";

    //Step 2 - Replace with corresponding value in tgt
    Exe.ReplaceString(offset, tgt[i]);
    return true;
}

//##########################################################\\
//# Find the prefix assignment inside UIBasicWnd::OnCreate #\\
//# and assign address of NULL after the prefix instead    #\\
//##########################################################\\

function HideButton2(prefix)
{
    //Step 1.1 - Find the reference prefix "skill" (needed since some prefixes are matching multiple areas)
    var refAddr = Exe.FindString("skill", VIRTUAL);
    if (refAddr === -1)
        return "Failed in Step 1 - info missing";

    //Step 1.2 - Find the prefix string
    var strAddr = Exe.FindString(prefix, VIRTUAL);
    if (strAddr === -1)
        return "Failed in Step 1 - Prefix missing";

    //Step 2.1 - Find assignment of "skill" inside UIBasicWnd::OnCreate
    var suffix = " C7";
    var offset = Exe.FindHex(Num2Hex(refAddr) + suffix);

    if (offset === -1)
    {
        suffix = " 8D";
        offset = Exe.FindHex(Num2Hex(refAddr) + suffix);
    }
    if (offset === -1)
        return "Failed in Step 2 - info assignment missing";

    //Step 2.2 - Find the assignment of prefix after "skill" assignment
    offset = Exe.FindHex(Num2Hex(strAddr) + suffix, offset + 5, offset + 0x50);
    if (offset === -1)
        return "Failed in Step 2 - Prefix assignment missing";

    //Step 2.3 - Update the address to point to NULL
    Exe.ReplaceInt32(offset, strAddr + prefix.length);
    return true;
}

///========================================================///
/// Disable for Unsupported Clients - Check for Button bmp ///
///========================================================///

function HideRodex_()
{
    return (Exe.FindString("\xC0\xAF\xC0\xFA\xC0\xCE\xC5\xCD\xC6\xE4\xC0\xCC\xBD\xBA\\RO_menu_icon\\mail", REAL) !== -1);
}

function HideAchieve_()
{
    return (Exe.FindString("\xC0\xAF\xC0\xFA\xC0\xCE\xC5\xCD\xC6\xE4\xC0\xCC\xBD\xBA\\RO_menu_icon\\achievement", REAL) !== -1);
}
