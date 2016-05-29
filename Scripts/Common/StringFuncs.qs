///==================================///
/// Extra String Prototype Functions ///
///==================================///

//##############################\\
//# Replace substring at index #\\
//##############################\\

String.prototype.replaceAt = function(index, repstr)
{
    return (this.slice(0, index) + repstr + this.slice(index + repstr.length));
}

//####################################################################\\
//# Generate String by repeating the source string count no of times #\\
//####################################################################\\

String.prototype.repeat = function(count)
{
    var result = '';
    var base = this.toString();

    for (var i = 0; i < count; i++)
    {
        result += base;
    }
    return result;
}

//#############################################\\
//# Get the Number of Bytes in the Hex String #\\
//#############################################\\

String.prototype.byteCount = function()
{
    var hlen = this.replace(/ /g, '').length; //No value checking is done atm
    if ((hlen % 2) !== 0)
        hlen++;

    return hlen/2;
}

//#################################################################\\
//# Convert Little Endian Hex String to Big Endian with no spaces #\\
//#################################################################\\

String.prototype.le2be = function()
{
    var be = this.split(' ').reverse().join();
    if ((be.length % 2) != 0)
        be = '0' + be;

    return be;
}