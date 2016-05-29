//###################################################\\
//# Modify the Serial Display function to reset EAX #\\
//# and thereby skip showing the serial number      #\\
//###################################################\\

function RemoveSerialDisplay()
{
    //Step 1.1 - Prep comparison code
    var code1 =
        " 83 C0 ??"          //ADD EAX, const1
    +   " 3B 41 ??"          //CMP EAX, DWORD PTR DS:[EAX+const2]
    +   " 0F 8C ?? 00 00 00" //JL addr
    +   " 56"                //PUSH ESI
    ;
    var code2 = " 6A 00";    //PUSH 0

    //Step 1.2 - Find the code
    var offset = Exe.FindHex(code1 + " 57" + code2); //New Client

    if (offset === -1)
        offset = Exe.FindHex(code1 + code2); //Older client
    if (offset === -1)
        return "Failed in Step 1";

    //Step 2 - Overwrite ADD and CMP statements with code for setting EAX = 0.
    //         Since EAX is 0, the JL will always Jump
    code1 =
        " 90"       // NOP
    +   " 31 C0"    // XOR EAX, EAX
    +   " 83 F8 01" // CMP EAX, 1
    ;
    Exe.ReplaceHex(offset, code1);
    return true;
}

///=================================///
/// Disable for Unsupported Clients ///
///=================================///
function RemoveSerialDisplay_()
{
    return (Exe.GetDate() > 20101116);
}