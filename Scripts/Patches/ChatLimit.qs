///==================================================///
/// Patch Functions wrapping over ChatLimit function ///
///==================================================///

// Changes the JL/JLE to JMP //
function RemoveChatLimit()
{
    return ChatLimit(0);
}

// Changes the compared value from 2 to user specified value - 1 //
function AllowChatFlood()
{
    return ChatLimit(1);
}

//##########################################################\\
//# Change the comparison in the ::IsSameSentence function #\\
//# or Convert the Conditional Jump after it to a JMP      #\\
//##########################################################\\

function ChatLimit(option)
{
    //Step 1.1 - Check if Langtype is available (LT.Error will be a string if not)
    if (LT.Error)
        return "Failed in Step 1 - " + LT.Error;

    //Step 1.2 - Prep the Langtype comparison pattern (changes for various client dates because of FPO changes)
    var code =
        " 83 3D" + LT.Hex + " 0A" //CMP DWORD PTR DS:[g_serviceType], 0A
    +   " 74 ??"                    //JE SHORT addr
    ;

    if (EBP_TYPE)
        code += " 83 7D 08 02";       //CMP DWORD PTR SS:[EBP-8], 02
    else
        code += " 83 7C 24 04 02";    //CMP DWORD PTR SS:[ESP+4], 02

    code += " 7C";                  //JL SHORT addr

    var isLong = false;

    //Step 1.3 - Now Search for the pattern chosen inside ::IsSameSentence
    var offset = Exe.FindHex(code);
    if (offset === -1)
    {
        code = code.replace(" 0A 74 ?? 83", " 0A 0F 84 ?? 00 00 00 83" );//Relative offset of the JE is > 7F but < FF. Hence changing to long
        code = code.replaceAt(/ 7C$/, " 0F 8C");//same reason as ??ove for JL

        isLong = true;
        offset = Exe.FindHex(code);
    }
    if (offset === -1)
        return "Failed in Step 1 - Pattern not found";

    //Step 1.4 - Update offset to the position of 02 from the pattern
    offset += code.byteCount() - 2; //Position of 02

    if (isLong)
        offset--; //JL is two byte hence 02 is at one more byte before

    if (option === 1) //Change compared value
    {
        //Step 2.1 - Get new value from user
        var flood = Exe.GetUserInput('$allowChatFlood', I_INT8, "Number Input", "Enter new chat limit (0-127, default is 2):", 2);//Default Limits are 0 and 127 hence no need to specify
        if (flood === 2)
            return "Patch Cancelled - New value is same as old";

        //Step 2.2 - Replace 02 with new value
        Exe.ReplaceInt8(offset, flood);
    }
    else //Change the Jump
    {
        //Step 2.3 - Replace JL with JMP
        if (isLong)
            Exe.ReplaceHex(offset + 1, "90 E9");
        else
            Exe.ReplaceInt8(offset + 1, 0xEB);
    }
    return true;
}