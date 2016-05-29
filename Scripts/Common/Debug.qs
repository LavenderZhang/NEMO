//###########################################################\\
//# Sends formatted output to debugger with offset and data #\\
//###########################################################\\

function SendA_n_D(prefix, offset, data)
{
    if (typeof(data) === "number")
        data = Num2Hex(data, 4, true);

    print( prefix + "Writing to offset (0x" + Num2Hex(offset, 4, true) + ") => " + data );
}

//######################################################\\
//# Sends address in Big Endian Hex format to debugger #\\
//######################################################\\

function SendAddr(prefix, offset)
{
    print( prefix + " Offset = 0x" + Num2Hex(offset, 4, true) );
}
