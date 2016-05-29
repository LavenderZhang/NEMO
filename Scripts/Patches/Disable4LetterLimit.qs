///============================================================///
/// Patch Functions wrapping over Disable4LetterLimit function ///
///============================================================///

function Disable4LetterCharnameLimit()
{
    return Disable4LetterLimit(0);
}

function Disable4LetterPasswordLimit()
{
    return Disable4LetterLimit(1);
}

function Disable4LetterUsernameLimit()
{
    return Disable4LetterLimit(2);
}

//##################################################################\\
//# Find the Comparisons of UserName/Password/CharName size with 4 #\\
//# and replace it with 0 so any non-empty string is valid         #\\
//##################################################################\\

function Disable4LetterLimit(index) //Some old clients dont have the ID Check
{
    //Step 1.1 - Find all Text Size comparisons with 4 chars.
    var code =
        " E8 ?? ?? ?? FF" //CALL UIEditCtrl::GetTextSize
    +   " 83 F8 04"       //CMP EAX, 4
    +   " 7C"             //JL SHORT addr
    ;
    var offsets = Exe.FindAllHex(code);

    code = code.replace("7C", "0F 8C ?? ?? 00 00"); //JL addr
    offsets = offsets.concat(Exe.FindAllHex(code));

    if (offsets.length < 3)
        return "Failed in Step 1 - Not enough matches found";

    //Step 1.2 - Find which of the offsets belong to Password & ID Check
    code =
        " E8 ?? ?? ?? FF" //CALL UIEditCtrl::GetTextSize
    +   " 83 F8 04"       //CMP EAX, 4
    ;
    var csize = code.byteCount();

    for (var idp = 0; idp < offsets.length; idp++)
    {
        var offset2 = Exe.FindHex(code, offsets[idp] + csize, offsets[idp] + csize + 30 + csize);
        if (offset2 !== -1)
            break;
    }
    if (offset2 === -1)
        return "Failed in Step 1 - ID+Pass check not found";

    //Step 2 - Replace 4 with 0 in CMP EAX,4 in appropriate offsets
    switch (index)
    {
        case 0:
        {
            //Step 2.1 - For Index 0 i.e. Char Name, all offsets other than offset2 and offsets[idp] will get the replace
            for (var i = 0; i < offsets.length; i++)
            {
                if (i === idp || offsets[i] === offset2)
                    continue;

                Exe.ReplaceInt8(offsets[i] + csize - 1, 0);
            }
            break;
        }
        case 1:
        {
            //Step 2.2 - For Index 1 i.e. Password, offsets[idp] get the replace
            Exe.ReplaceInt8(offsets[idp] + csize - 1, 0);
            break;
        }
        case 2:
        {
            //Step 2.3 - For Index 2, i.e. ID, offset2 get the replace
            Exe.ReplaceInt8(offset2 + csize - 1, 0);
            break;
        }
    }
    return true;
}