//######################################################################\\
//# Change the iteminfo.lub reference to custom file specified by user #\\
//######################################################################\\

function ChangeItemInfo()
{
    //Step 1.1 - Check if the client is Renewal (iteminfo file name is "System/iteminfo_Sak.lub" for Renewal clients)
    if (IsRenewal())
        var iiName = "System/iteminfo_Sak.lub";
    else
        var iiName = "System/iteminfo.lub";

    //Step 1.2 - Find offset of the original string
    var offset = Exe.FindString(iiName, VIRTUAL);
    if (offset === -1)
        return "Failed in Step 1 - iteminfo file name not found";

    //Step 1.2 - Find its reference
    offset = Exe.FindHex("68" + Num2Hex(offset));
    if (offset === -1)
        return "Failed in Step 1 - iteminfo reference not found";

    //Step 2.1 - Get the new filename from user
    var myfile = Exe.GetUserInput('$newItemInfo', I_STRING, "String input - maximum 28 characters including folder name/", "Enter the new ItemInfo path (should be relative to RO folder)", iiName, 1, 28);
    if (!myfile)
        return "Patch Cancelled";
    
    if (myfile === iiName + '\0')
        return "Patch Cancelled - New value is same as old";

    //Step 2.2 - Find Free space for insertion
    var free = Exe.FindSpace(myfile.length);
    if (free === -1)
        return "Failed in Step 2 - Not enough free space";

    //Step 3.1 - Insert the new name into the free space
    Exe.InsertString(free, '$newItemInfo', myfile.length);

    //Step 3.2 - Update the iteminfo reference
    Exe.ReplaceInt32(offset + 1, Exe.Real2Virl(free, DIFF));
    return true;
}

///=================================///
/// Disable for Unsupported clients ///
///=================================///
function ChangeItemInfo_()
{
    if (IsRenewal())
            var iiName = "System/iteminfo_Sak.lub";
    else
            var iiName = "System/iteminfo.lub";
    return (Exe.FindString(iiName, REAL) !== -1);
}