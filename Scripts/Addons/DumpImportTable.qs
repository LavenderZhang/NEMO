//##############################################################################\\
//# Dump the Entire Import Table Hierarchy in the loaded client to a text file #\\
//##############################################################################\\

function DumpImportTable()
{
	//Step 1.1 - Get the Import Data Directory Offset
	var offset = Exe.GetDirOffset(1);

	//Step 1.2 - Open text file for writing
	Fp = new File();
	if (!Fp.Open(APP_PATH + "Outputs/importTable_Dump_" + Exe.GetDate() + ".txt", 'w'))
		throw "Error: Unable to create text file in Output folder";

	//Step 2.1 - Write the import address to file
	Fp.WriteLine("IMPORT TABLE (REAL) = 0x" + Num2Hex(offset, 4, true));

	for ( ;true; offset += 20)
    {
		//Step 2.2 - Iterate through each IMAGE_IMPORT_DESCRIPTOR
		var ilt     = Exe.GetInt32(offset); //Lookup Table address
		var ts      = Exe.GetInt32(offset + 4);//TimeStamp
		var fchain  = Exe.GetInt32(offset + 8);//Forwarder Chain
		var nameRva = Exe.GetInt32(offset + 12);//DLL Name address
		var iatRva  = Exe.GetInt32(offset + 16);//Import Address Table <- points to the First Thunk

		//Step 2.3 - Check if reached end - DLL name offset would be zero
		if (nameRva <= 0)
            break;

		//Step 2.4 - Write the Descriptor Info to file
		Fp.WriteLine(
            "Lookup Table = 0x" + Num2Hex(ilt, 4, true)
        +   ", TimeStamp = " + ts
        +   ", Forwarder = " + fchain
        +   ", Name = " + Exe.GetString(Exe.Virl2Real(nameRva + Exe.GetImgBase()))
        +   ", Import Address Table = 0x" + Num2Hex(iatRva + Exe.GetImgBase(), 4, true)
        );

		//Step 2.5 - Get the Raw offset of First Thunk
		var offset2 = Exe.Virl2Real(iatRva + Exe.GetImgBase());

		for ( ;true; offset2 += 4)
        {
            //Step 2.6 - Iterate through each IMAGE_THUNK_DATA
            var funcData = Exe.GetInt32(offset2);//Ordinal Number or Offset of Function Name

            //Step 2.5 - Check which type it is accordingly Write out the info to file
            if (funcData === 0) //End of Functions
            {
                Fp.WriteLine("");
                break;
            }
            else if (funcData > 0) //First Bit (Sign) shows whether this functions is imported by Name (0) or Ordinal (1)
            {
                funcData = funcData & 0x7FFFFFFF;//Address pointing to IMAGE_IMPORT_BY_NAME struct (First 2 bytes is Hint, remaining is the Function Name)
                var offset3 = Exe.Virl2Real(funcData + Exe.GetImgBase());
                Fp.WriteLine(
                    "  Thunk Address (VIRTUAL) = 0x" + Num2Hex(Exe.Real2Virl(offset2), 4, true)
                +   ", Thunk Address(REAL) = 0x" + Num2Hex(offset2, 4, true)
                +   ", Function Hint = 0x" + Exe.GetHex(offset3, 2).replace(/ /g, "")
                +   ", Function Name = " + Exe.GetString(offset3 + 2)
                );
            }
            else
            {
                funcData = funcData & 0xFFFF;
                Fp.WriteLine(
                    "  Thunk Address (VIRTUAL) = 0x" + Num2Hex(Exe.Real2Virl(offset2), 4, true)
                +   ", Thunk Address(REAL) = 0x" + Num2Hex(offset2, 4, true)
                +   ", Function Ordinal = " + funcData
                );
            }
		}
	}
	Fp.Close();

	return "Import Table has been dumped to Output folder";
}