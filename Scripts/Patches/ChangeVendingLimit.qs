//########################################################\\
//# Modify the constant used in Comparison inside the    #\\
//# vending related function (dont have name for it atm) #\\
//########################################################\\

function ChangeVendingLimit()
{
    //Step 1.1 - Find "1,000,000,000"
    var offset = Exe.FindString("1,000,000,000", VIRTUAL);
    if (offset === -1)
        return "Failed in Step 1 - OneB string missing";

    var oneB = Exe.Virl2Real(offset, DATA);//Needed later to change the string

    //Step 1.2 - Find its reference
    var offset = Exe.FindHex("68" + Num2Hex(offset));
    if (offset === -1)
        return "Failed in Step 1 - OneB reference missing";

    //Step 1.3 - Find the comparison with 1B or 1B+1 before it
    var code =
        " 00 CA 9A 3B" //CMP reg32_A, 3B9ACA00 (1B in hex)
    +   " 7E"          //JLE SHORT addr
    ;
    var newStyle = true;
    var offset2 = Exe.FindHex(code, offset - 0x10, offset);

    if (offset2 === -1)
    {
        code =
            " 01 CA 9A 3B" //CMP reg32_A, 3B9ACA01 (1B+1 in hex)
        +   " 7C"          //JL SHORT addr
        ;
        newStyle = false;
        offset2 = Exe.FindHex(code, offset - 0x10, offset);
    }
    if (offset2 === -1)
        return "Failed in Step 1 - Comparison missing";

    //Step 2.1 - Find the MsgString call to 0 zeny message
    code =
        " 6A 01"          //PUSH 1
    +   " 6A 02"          //PUSH 2
    +   " 68 5C 02 00 00" //PUSH 25C ;Line no. 605
    ;
    offset = Exe.FindHex(code);
    if (offset === -1)
        return "Failed in Step 2 - MsgBox call missing";

    //Step 2.2 - Find the comparison before it
    if (newStyle)
    {
        code =
            " 00 CA 9A 3B" //CMP reg32_A, 3B9ACA00 (1B in hex)
        +   " 7E"          //JLE SHORT addr
        ;
    }
    else
    {
        code =
            " 01 CA 9A 3B" //CMP reg32_A, 3B9ACA01 (1B+1 in hex)
        +   " 7D"          //JGE SHORT addr
        ;
    }
    var offset1 = Exe.FindHex(code, offset - 0x80, offset);

    if (offset1 === -1 && newStyle)
    {
        code = code.replace("7E", "76");//Recent clients use JBE instead of JLE
        offset1 = Exe.FindHex(code, offset - 0x80, offset);
    }
    if (offset1 === -1)
        return "Failed in Step 2 - Comparison missing";

    //Step 2.3 - Find the Extra comparison for oldstyle clients
    if (!newStyle)
    {
        code = code.replace("7D", "75");//JNE instead of JGE
        offset = Exe.FindHex(code, offset - 0x60, offset);
        if (offset === -1)
            return "Failed in Step 2 - Extra Comparison missing";

        //Step 2.4 - Change the JNE to JMP
        Exe.ReplaceInt8(offset + 4, 0xEB);
    }

    //Step 3.1 - Get the new value from user
    var newValue = Exe.GetUserInput("$vendingLimit", I_INT32, "Number Input", "Enter new Vending Limit (0 - 2,147,483,647):", 1000000000);
    if (newValue === 1000000000)
        return "Patch Cancelled - Vending Limit not changed";

    //Step 3.2 - Replace the 1B string
    var str = newValue.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",") + '\0'; //Adding Commas every 3 digits like the original
    Exe.ReplaceString(oneB, str);

    //Step 3.3 - Replace the compared value
    if (!newStyle)
        newValue++;

    Exe.ReplaceInt32(offset1, newValue);
    Exe.ReplaceInt32(offset2, newValue);
    return true;
}

//===================================================================//
// Disable for Unneeded Clients - Only 2013+ Clients have this check //
//===================================================================//
function ChangeVendingLimit_()
{
    return (Exe.FindString("1,000,000,000", REAL) !== -1);
}