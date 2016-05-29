/* This file is going to be removed soon
function FixTetraVortex()
{
    /////////////////////////////////////////////
    // GOAL: Remove the Tetra Vortex bmp names //
    /////////////////////////////////////////////

    for (var i = 1; i <= 8; i++) {
        //Step 1 -    Find the tetra vortex .bmp string address
        var code = "effect\\tv-" + i +   ".bmp";
        var offset = Exe.FindString(code, REAL);
        if (offset === -1)
            return "Failed in Step 1." + i;

        //Step 2 - Zero out the string
        Exe.ReplaceHex(offset, "00");
    }
    return true;
}
*/