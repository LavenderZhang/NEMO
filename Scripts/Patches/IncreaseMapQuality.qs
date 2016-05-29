//###############################################################################################\\
//# Change the pf argument to CTexMgr::CreateTexture to increase the color depth used to 32 bit #\\
//###############################################################################################\\

function IncreaseMapQuality()
{
    //Step 1.1 - Find the CreateTexture call
    var code =
        " 51"             //PUSH ECX ; imgData
    +   " 68 00 01 00 00" //PUSH 100 ; h = 256
    +   " 68 00 01 00 00" //PUSH 100 ; w = 256
    +   " B9 ?? ?? ?? 00" //MOV ECX, OFFSET g_texMgr
    +   " E8"             //CALL CTexMgr::CreateTexture
    ;
    var offset = Exe.FindHex(code);

    if (offset === -1)
    {
        code = code.replace("51", "50");//PUSH EAX ; imgData
        offset = Exe.FindHex(code);
    }
    if (offset === -1)
        return "Failed in Step 1 - CreateTexture call missing";

    //Step 1.2 - Find the pf argument push before it.
    if (Exe.GetInt8(offset - 1) === 0x01) //PUSH 1 is right before PUSH E*X
    {
        offset--;
    }
    else
    {
        offset = Exe.FindHex("6A 01", offset - 10, offset);//PUSH 1
        if (offset === -1)
            return "Failed in Step 1 - pf push missing";

        offset++;
    }

    //Step 2 - Change PUSH 1 to PUSH 4
    Exe.ReplaceInt8(offset, 0x04);
    return true;
}