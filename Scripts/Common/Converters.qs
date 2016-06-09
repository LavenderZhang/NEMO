///======================///
/// Conversion Functions ///
///======================///

//#################################################\\
//# Convert a String to its equivalent Hex String #\\
//#################################################\\

function Ascii2Hex(bytes)
{
    var result = "";
    for (var i = 0; i < bytes.length; i++)
    {
        var hex = bytes.charCodeAt(i).toString(16).toUpperCase();
        if (hex.length === 1)// for values < 16
            hex = '0' + hex;

        result += ' ' + hex;
    }
    return result;
}

//##########################################################\\
//# Convert a Hex String to its equivalent String of Bytes #\\
//# i.e. reverse of above.                                 #\\
//##########################################################\\

function Hex2Ascii(hex)
{
    var splits = hex.trim().split(/ /g);

    var result = "";
    for (var i = 0; i < splits.length; i++)
    {
        if (splits[i] === "")
            continue;

        var byt = parseInt(splits[i], 16);
        result += String.fromCharCode(byt);
    }
    return result;
}

//###############################################################\\
//# Convert a Number to it equivalent Hex String.               #\\
//# Little Endian String will contain spaces before each 'byte' #\\
//###############################################################\\

function Num2Hex(number, count, needBE)
{
    // Setup Default Arg values
    if (typeof(count) !== "number" || count > 4)//upto 4 bytes is expected
        count = 4;

    if (typeof(needBE) !== "boolean")
        needBE = false;

    // Convert Signed Number to equivalent Unsigned number ( toString function won't work for signed value )
    if (number < 0)
        number = 0xFFFFFFFF + number + 1;

    // Convert Number to Hex String in UpperCase
    var hex = number.toString(16).toUpperCase();
    if ((hex.length % 2) !== 0)
        hex = '0' + hex;

    var result = "";
    if (needBE)
    {
        //Set result with hex having higher positions with 00 if no of 'bytes' < count. We can also do le2be of the else part instead but that would be much more time taking.
        result = "00000000".substr(0, count*2 - hex.length) + hex;
    }
    else
    {
        //Fill each 'byte' in reverse order with a space before into result.
        var index = hex.length - 2;
        for (var i = 0; i < count; i++)
        {
            if (index < 0)
            {
                result += " 00";
            }
            else
            {
                result += " " + hex.substr(index, 2);
                index -= 2;
            }
        }
    }
    return result;
}

//###############################################################\\
//# Convert a Little Endian Hex String to its equivalent Number #\\
//###############################################################\\

function Hex2Num(hex, count, isSigned)
{
    // Setup Default Arg values
    if (typeof(count) !== "number" || count > 4)
        count = 4;

    if (typeof(isSigned) !== "boolean")
        isSigned = true;

    // Prepare max value based on count
    var max = Math.pow(0x100, count);

    // Convert the Little Endian Hex to Big Endian & strip Extra Bytes
    var be = hex.le2be().slice(-count*2);

    // Convert the Big Endian to Number
    var number = (-1 & parseInt("0x" + hex.le2be(), 16));

    // Sign check
    if (isSigned && number > max/2)
        number -= max;

    return number;
}
