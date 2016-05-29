//##########################################################################\\
//# Make client skip over the Cash Shop Icon UIWindow creation (ID = 0xBE) #\\
//##########################################################################\\

function HideCashShop()
{
    //Step 1.1 - Check if Window Manager info is available (WM.Error will be a string if not)
    if (WM.Error)
        return "Failed in Step 1 - " + WM.Error;

    //Step 1.2 - Find the UIWindow creation for Cash Shop - 0xBE
    var code =
        " 68 BE 00 00 00" //PUSH 0BE
    +   WM.MovEcx         //MOV ECX, OFFSET g_windowMgr
    +   " E8"             //CALL UIWindowMgr::MakeWindow
    ;

    var offset = Exe.FindHex(code);
    if (offset === -1)
        return "Patch Cancelled - Cash Shop already hidden";

    //Step 2 - If found then JMP over it
    Exe.ReplaceHex(offset, "EB 0D");
}

///======================================================///
/// Disable for Unsupported Clients - Check for Icon bmp ///
///======================================================///
function HideCashShop_()
{
    return (Exe.FindString("NC_CashShop", REAL) !== -1);
}