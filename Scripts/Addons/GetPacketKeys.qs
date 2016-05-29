//###########################################################\\
//# Extract Packet Keys from loaded client and dump to file #\\
//###########################################################\\

function GetPacketKeys()
{
    //Step 1.1 - Check if Packet Key Info is available
    if (PK.Error)
        throw "Failed in Step 1 - " + PK.Error;

	//Step 1.2 - Convert the keys to comma seperated string in BE format.
    var keys = "0x" + Num2Hex(PK.Keys[0], 4, true) + ", 0x" + Num2Hex(PK.Keys[1], 4, true) + ", 0x" + Num2Hex(PK.Keys[2], 4, true);

	//Step 2 - Write them to file.
	var Fp = new File();
	Fp.Open(APP_PATH + "Outputs/PacketKeys_" + Exe.GetDate() + ".txt", 'w');
	Fp.WriteLine("Packet Keys : (" + keys + ")");
	Fp.Close();

	return "Packet Keys have been written to Output folder";
}