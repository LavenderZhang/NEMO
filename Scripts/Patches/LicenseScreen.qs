//##################################################\\
//# Change the Conditional Jump in License screen  #\\
//# displayer case of switch to JMP inside WinMain #\\
//##################################################\\

function ShowLicenseScreen()
{
    //Step 1.1 - Find guildflag90_1 string
    var offset = Exe.FindString("model\\3dmob\\guildflag90_1.gr2", VIRTUAL);
    if (offset === -1)
        return "Failed in Step 1 - Guild String missing";

    //Step 1.2 - Find its reference (which will come right before the conditional jump)
    var code =
        " 6A 05"                //PUSH 5
    +   " 68" + Num2Hex(offset) //PUSH addr; ASCII "model\3dmob\guildflag90_1.gr2"
    ;

    offset = Exe.FindHex(code);
    if (offset === -1)
        return "Failed in Step 1 - String Reference missing";

    //Step 1.3 - Update offset to location after the 2nd PUSH
    offset += code.byteCount();

    //Step 2.1 - Find the conditional jump after the reference.
    code =
        " 83 F8 04"     //CMP EAX, 4
    +   " 74 ??"        //JE SHORT addr
    +   " 83 F8 08"     //CMP EAX, 8
    +   " 74 ??"        //JE SHORT addr
    +   " 83 F8 09"     //CMP EAX, 9
    +   " 74 ??"        //JE SHORT addr
    +   " 83 F8 06"     //CMP EAX, 6
    +   " 75"           //JNE SHORT addr2
    ;

    offset = Exe.FindHex(code, offset, offset + 0x60);
    if (offset === -1)
        return "Failed in Step 2 - LangType comparison missing";

    //Step 2.2 - Change the first JE to JMP
    Exe.ReplaceInt8(offset + 3, 0xEB);
    return true;
}

//#########################################################\\
//# Modify the switch inside CLoginMode::OnChangeState to #\\
//# skip transfering to License Screen creation code      #\\
//#########################################################\\

function SkipLicenseScreen()
{
    //Step 1.1 - Find "btn_disagree"
    var offset = Exe.FindString("btn_disagree", VIRTUAL);
    if (offset === -1)
        return "Failed in Step 1 - Unable to find btn_disagree";

    //Step 1.2 - Find it's reference. Interestingly it is only PUSHed once
    offset = Exe.FindHex("68" + Num2Hex(offset));
    if (offset === -1)
        return "Failed in Step 1 - Unable to find reference to btn_disagree";

    //Step 2.1 - Find the Switch Case JMPer within 0x200 bytes before the PUSH
    offset = Exe.FindHex("FF 24 85 ?? ?? ?? 00", offset - 0x200, offset);//JMP DWORD PTR DS:[EAX*4 + jmpTable]
    if (offset === -1)
        return "Failed in Step 2 - Unable to find the switch";

    //Step 2.2 - Extract the jmpTable
    var jmpTable = Exe.Virl2Real(Exe.GetInt32(offset + 3));//We need the raw address

    //Step 2.3 - Extract the 3rd Entry in the jumptable => Case 2. Case 0 and Case 1 are related to License Screen
    var third = Exe.GetInt32(jmpTable + 8);

    //Step 3 - Replace the 1st and 2nd entries with the third. i.e. Case 0 and 1 will now use Case 2
    Exe.ReplaceInt32(jmpTable, third);
    Exe.ReplaceInt32(jmpTable + 4, third);

    return true;
}