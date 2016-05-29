//#################################################################################\\
//# Make the code inside CLoginMode::OnChangeState which sends 0x2B0 use Original #\\
//# Password (which is the Arg.1 of Encryptor) instead of Encrypted Password      #\\
//#################################################################################\\

function DisableLoginEncryption()
{
    //Step 1 - Find Encryptor function call.
    var code =
        " E8 ?? ?? ?? FF" //CALL Encryptor (preceded by PUSH reg32_A)
    +   " B9 06 00 00 00" //MOV ECX,6
    +   " 8D"             //LEA reg32_B, [EBP-x]
    ;

    var offset = Exe.FindHex(code);
    if (offset === -1)
        return "Failed in Step 1 - Encryptor call missing";

    //Step 2.1 - Extract the register PUSHed - Arg.1 which contains the Original Password
    var regPush = Exe.GetUint8(offset - 1) - 0x50;

    //Step 2.2 - Change the LEA to LEA reg32_B, [reg32_A]
    offset += code.byteCount();
    code =
        Num2Hex((Exe.GetUint8(offset) & 0x38) | regPush, 1) //LEA reg32_B, [reg32_A]
    +   " 90 90 90 90" //NOPs
    ;

    Exe.ReplaceHex(offset, code);
    return true;
}

///=================================///
/// Disable for Unsupported Clients ///
///=================================///
function DisableLoginEncryption_()
{
    return (Exe.GetDate() < 20100803);
}