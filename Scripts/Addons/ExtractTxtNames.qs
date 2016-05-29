//########################################################
//# Extract all .txt filenames used in the loaded client #
//########################################################

function ExtractTxtNames()
{
	//Step 1 - Find all strings ending in .txt
	var offsets = Exe.FindAllHex("2E 74 78 74 00", Exe.GetRealOffset(DATA), Exe.GetRealOffset(DATA) + Exe.GetRealSize(DATA));
	if (offsets.length === 0)
		throw "Error: No .txt files found";

	//Step 2.1 - Open output file and write the header.
	var Fp = new File();
	Fp.Open(APP_PATH + "Outputs/loaded_txt_files_" + Exe.GetDate() + ".txt", 'w');
	Fp.WriteLine("Extracted with NEMO");
	Fp.WriteLine("-------------------");

	for (var i = 0; i < offsets.length; i++)
    {
		//Step 2.2 - Iterate backwards till the start of the string is found for each offset
		var offset = offsets[i];
		do
        {
			offset--;
			var code = Exe.GetInt8(offset);
		} while (code !== 0 && code !== 0x40);//loop till NULL or @ is reached.

		//Step 2.3 - Extract the string and write to file
		var str = Exe.GetString(offset + 1);
		if (str !== ".txt") //Skip ".txt"
			Fp.WriteLine(str);
	}
	//Step 2.4 - Close the File
	Fp.Close();

	return "Txt File list has been extracted to Output folder";
}