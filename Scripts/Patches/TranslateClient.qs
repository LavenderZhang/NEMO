//##################################################################\\
//# Translate Korean strings to user specified strings both loaded #\\
//# from TranslateClient.txt . Also fixes Taekwon branch Job names #\\
//##################################################################\\

function TranslateClient()
{
    //Step 1 - Open the text file for reading
    var f = new File();
    if (!f.Open(APP_PATH + "patches/TranslateClient.txt", 'r'))
        return "Failed in Step 1 - Unable to open Translation file";

    var offset = -1;
    var msg = "";
    var failmsgs = [];//Array to store all Failure messages

    //Step 2 - Loop through the text file, get the respective strings & do findString + replace
    while (!f.IsEOF())
    {
        //Step 2.1 - Get Current Line
        var line = f.ReadLine().trim();

        //Step 2.2 - Check for Valid Line (<prefix>:string)
        var matches = line.match(/^([MFR]):(.*)/);
        if (!matches)
            continue;

        var key = matches[1];
        var str = matches[2].trim();

        //Step 2.3 - Check if the string is not empty
        if (str.length == 0)
            continue;

        //Step 2.4 - Check for Quotes (F & R keys need quotes for ASCII String else it is considered as Hex String)
        var isHex = true;
        if (matches = str.match(/'(.*)'/))
        {
            isHex = false;
            str = matches[1];
        }

        //Step 2.5 - Check the key and do appropriate actions
        switch (key)
        {
            case 'M': //Failure message string
            {
                msg = str;
                break;
            }
            case 'F': //Search String
            {
                if (!isHex)
                    str = Ascii2Hex(str);//We need it as hex since str can have Extra NULLs at the end

                offset = Exe.FindHex("00" + str + " 00", Exe.GetRealOffset(DATA), Exe.GetRealOffset(DATA) + Exe.GetRealSize(DATA));
                if (offset === -1)
                    failmsgs.push(msg); //No Match = Collect Failure message
                else
                    offset++;

                break;
            }
            case 'R': //Replace String
            {
                if (offset !== -1)
                {
                    if (isHex)
                        Exe.ReplaceHex(offset, str + " 00");
                    else
                        Exe.ReplaceString(offset, str + "\x00");
                    offset = -1;
                }
                break;
            }
        }
    }
    f.Close();

    //Step 3 - Dump all the Failure messages collected to FailedTranslations.txt
    if (failmsgs.length != 0)
    {
        var outfile = new File();
        if (outfile.Open(APP_PATH + "FailedTranslations.txt", 'w'))
        {
            for (var i = 0; i < failmsgs.length; i++)
            {
                outfile.WriteLine(failmsgs[i]);
            }
        }
        outfile.Close();
    }

    ///==================================///
    /// Now for the TaeKwon Job name fix ///
    ///==================================///

    //Step 4.1 - Check if LangType is available (LT.Error will be a string if not)
    if (LT.Error)
        return "Failed in Step 4 - " + LT.Error;

    //Step 4.2 - Find the LangType Check
    var code =
        " 83 3D" + LT.Hex + " 00" //CMP DWORD PTR DS:[g_serviceType], 0
    +   " B9 ?? ?? ?? 00"         //MOV ECX, addr1
    +   " 75"                     //JNZ SHORT addr2
    ;
    offset = Exe.FindHex(code);//VC9+ Clients

    if (offset === -1)
    {
        code =
            LT.Hex            //MOV reg32_A, DWORD PTR DS:[g_serviceType] ; Usually reg32_A is EAX
        +   " B9 ?? ?? ?? 00" //MOV ECX, addr1
        +   " 85 ??"          //TEST reg32_A, reg32_A
        +   " 75"             //JNZ SHORT addr2
        ;
        offset = Exe.FindHex(code);//Older Clients
    }
    if (offset === -1)
        return "Failed in Step 4 - Translate Taekwon Job";

    //Step 4.2 - Change the JNZ to JMP so that Korean names never get assigned.
    Exe.ReplaceInt8(offset + code.byteCount() - 1, 0xEB);
    return true;
}