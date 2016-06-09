///==========================================================///
/// Patch Functions wrapping over ChangeWalkToDelay function ///
///==========================================================///

function DisableWalkToDelay()
{
    return ChangeWalkToDelay(0);
}

function SetWalkToDelay()
{
    return ChangeWalkToDelay(Exe.GetUserInput('$walkDelay', I_INT16, "Number Input", "Enter the new walk delay(0 - 1000) - snaps to closest valid value", 40, 0, 1000));
}

//#################################################################
//# Find the walk delay and replace it with the value specified.  #
//#################################################################

function ChangeWalkToDelay(value)
{
    //Step 1 - Find the delay addition
    var code =
        " 81 C1 58 02 00 00" //ADD ECX,00000258 ; 600ms
    +   " 3B C1"             //CMP EAX,ECX
    ;

    var offset = Exe.FindHex(code);
    if (offset === -1)
        return "Failed in Step 1 - Walk Delay Code not found.";

    //Step 2 - Replace the value
    Exe.ReplaceInt32(offset + 2, value);
    return true;
}