//##########################################################################\\
//# Change the Limit used for allocating and loading Headgear Prefix table #\\
//##########################################################################\\

function IncreaseViewID()
{
    //Step 1.1 - Find "ReqAccName"
    var offset = Exe.FindString("ReqAccName", VIRTUAL);
    if (offset === -1)
        return "Failed in Step 1 - ReqAccName missing";

    //Step 1.2 - Find where it is PUSHed - only 1 match would occur
    offset = Exe.FindHex("68" + Num2Hex(offset));
    if (offset === -1)
        return "Failed in Step 1 - ReqAccName reference missing";

    //Step 1.3 - Get the current limit in the client - may need update in future
    if (Exe.GetDate() > 20130000)//increased for newer clients.
        var oldValue = 2000;
    else
        var oldValue = 1000;

    //Step 2.1 - Get the new limit from user
    var newValue = Exe.GetUserInput("$newValue", I_INT32, "Number input", "Enter the new Max Headgear View ID", oldValue, oldValue, 32000);//32000 could prove fatal.
    if (newValue === oldValue)
        return "Patch Cancelled - New value is same as old";

    //Step 2.2 - Find all occurrences of the old limit with the user specified value
    var offsets = Exe.FindAllHex(Num2Hex(oldValue), offset - 0xA0, offset + 0x50);
    if (offsets.length === 0)
        return "Failed in Step 2 - No match found";

    if (offsets.length > 3)
        return "Failed in Step 2 - Extra matches found";

    //Step 2.3 - Replace old with new for all
    for (var i = 0; i < offsets.length; i++)
    {
        Exe.ReplaceString(offsets[i], "$newValue");
    }
    return true;
}

///=============================///
/// Disable Unsupported Clients ///
///=============================///
function IncreaseViewID_()
{
    return (Exe.FindString("ReqAccName", REAL) !== -1);
}