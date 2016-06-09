///==================================================================///
/// UseRagnarokIcon patch is already achieved in UseCustomIcon patch ///
/// so we use the true argument to make the patch stop there         ///
///==================================================================///

function UseRagnarokIcon()
{
    UseCustomIcon(true);
}

//##########################################################################\\
//# Modify Resource Table to use the 8bpp 32x32 icon present in the client #\\ <- UseRagnarokIcon stops here
//# and overwrite the icon data with the one from user specified icon file #\\
//##########################################################################\\

function UseCustomIcon(nomod)
{
    //Step 1 - Get the Resource Tree
    var rsrcTree = __GetRsrcDir(Exe.GetDirOffset(2), 0, 0);

    //Step 2.1 - Find the resource dir of RT_GROUP_ICON = 0xE (check the function in core)
    var entry = __GetRsrcEntry(rsrcTree, [0xE]);
    if (entry === -1)
        return "Failed in Step 2 - Unable to find icongrp";

    var offset = entry.addr + 0x10;
    var id = Exe.GetInt32(offset);

    //Step 2.2 - Adjust 114 subdir to use 119 data - thus same icon will be used for both
    if (id === 119)
        Exe.ReplaceInt32(offset + 0x8 + 0x4, Exe.GetInt32(offset + 0x4));
    else
        Exe.ReplaceInt32(offset + 0x4, Exe.GetInt32(offset + 0x8 + 0x4));

    if (nomod)
        return true;

    ///============================================///
    /// Now that icon is enabled lets overwrite it ///
    ///============================================///

    //Step 4 - Find the RT_GROUP_ICON , 119, 1042 resource entry address
    var entry = __GetRsrcEntry(rsrcTree, [0xE, 0x77, 0x412]);//RT_GROUP_ICON , 119, 1042
    switch (entry)
    {
        case -2: return "Failed in Step 4 - Unable to find icongrp/lang";
        case -3: return "Failed in Step 4 - Unable to find icongrp/lang/bundle";
    }

    var icoGrpOff = entry.dataAddr;

    //Step 5.1 - Get the new icon file name from user
    var iconFile = Exe.GetUserInput('$inpIconFile', I_FILE, "File Input - Use Custom Icon", "Enter the Icon File", APP_PATH);
    if (!iconFile)
        return "Patch Cancelled";

    //Step 5.2 - Load the icon
    var icondir = __LoadIconFile(iconFile);

    //Step 5.3 - Find the image that meets the spec = 8bpp 32x32
    var i = 0;
    for (; i < icondir.idCount; i++)
    {
        var entry = icondir.idEntries[i];
        if (entry.bHeight == 32 && entry.bWidth == 32 && entry.wBitCount == 8 && entry.bColorCount == 0)
            break;
    }
    if (i === icondir.idCount)
        return "Failed in Step 5 - No usable images in Icon file specified";

    var icondirentry = icondir.idEntries[i];

    //Step 6 - Find a valid RT_ICON - colorcount = 0, bpp = 8, and ofcourse the id will belong to valid resource
    var idCount = Exe.GetInt16(icoGrpOff + 4);
    var pos = icoGrpOff + 6;

    for (var i = 0; i < idCount; i++)
    {
        var memicondirentry =
        {
            "bWidth"       : Exe.GetInt8(pos),
            "bHeight"      : Exe.GetInt8(pos+1),
            "bColorCount"  : Exe.GetInt8(pos+2),
            "bReserved"    : Exe.GetInt8(pos+3),
            "wPlanes"      : Exe.GetInt16(pos+4),
            "wBitCount"    : Exe.GetInt16(pos+6),
            "dwBytesInRes" : Exe.GetInt32(pos+8),
            "nID"          : Exe.GetInt16(pos+12)
        };

        if (memicondirentry.bColorCount == 0 && memicondirentry.wBitCount == 8 && //8bpp
            memicondirentry.bWidth == 32 && memicondirentry.bWidth == 32)         //32x32 image
        {
            entry = __GetRsrcEntry(rsrcTree, [0x3, memicondirentry.nID, 0x412]);//returns negative number on fail or ResourceEntry object on success
            if (entry < 0)
                continue;

            break;
        }

        pos += 14;
    }
    if (i === idCount)
        return "Failed in Step 6 - no suitable icon found in exe";

    if (memicondirentry.dwBytesInRes < icondirentry.dwBytesInRes)
        return "Failed in Step 6 - Icon wont fit";//size should be 40 (header) + 256*4 (palette) + 32*32 (xor mask) + 32*32/8 (and mask)

    //Step 7.1 - Update the size in bytes dwBytesInRes and wPlanes as per the uploaded icon
    Exe.ReplaceInt16(pos - 14 + 4, icondirentry.wPlanes);
    Exe.ReplaceInt16(pos - 14 + 8, icondirentry.dwBytesInRes);

    //Step 7.2 - Finally update the icon image
    Exe.ReplaceInt32(entry.addr + 4, icondirentry.dwBytesInRes);
    Exe.ReplaceHex(entry.dataAddr, icondirentry.iconimage);

    return true;
}

//###############################################\\
//# Extracts the Resource Directory into a hash #\\
//###############################################\\

function __GetRsrcDir(rsrcAddr, offset, id)
{
    var result =
    {
        "id"       : id,
        "addr"     : rsrcAddr + offset,
        "dirType"  : true,
        "children" : []
    };

    var count = Exe.GetInt16(result.addr + 12) + Exe.GetInt16(result.addr + 14);
    for (var i = 0; i < count; i++)
    {
        id = Exe.GetInt32(result.addr + 16 + i*8);
        offset = Exe.GetInt32(result.addr + 16 + i*8 + 4);
        if (offset < 0)
            result.children.push( __GetRsrcDir(rsrcAddr, offset & 0x7FFFFFFF, id) );
        else
            result.children.push( __GetRsrcFile(rsrcAddr, offset, id) );
    }
    return result;
}

//##########################################\\
//# Extracts the Resource File into a hash #\\
//##########################################\\

function __GetRsrcFile(rsrcAddr, offset, id)
{
    offset += rsrcAddr;
    var result =
    {
        "id"       : id,
        "addr"     : offset,
        "dirType"  : false,
        "dataAddr" : Exe.Virl2Real(Exe.GetInt32(offset) + Exe.GetImgBase()),
        "dataSize" : Exe.GetInt32(offset + 4)
    };
    return result;
}

//###############################################################\\
//# Extracts a Resource Entry (File or Dir) given its hierarchy #\\
//###############################################################\\

function __GetRsrcEntry(rootDir, hierList)
{
    var entry = rootDir;
    for (var i = 0; i < hierList.length; i++)
    {
        if (!entry.dirType)
            break;

        var fail = true;
        var j = 0;
        for (; j < entry.children.length; j++)
        {
            if (entry.children[j].id == hierList[i])
            {
                fail = false;
                break;
            }
        }
        if (fail)
        {
            entry = -(i+1);
            break;
        }
        else
        {
            entry = entry.children[j];
        }
    }
    return entry;
}

//#####################################################################################\\
//# Helper Function to read the data from an icon file to a useful structure (object) #\\
//#####################################################################################\\

function __LoadIconFile(fname)
{
    //Step 1.1 - Open the icon file
    var fp = new File();
    fp.Open(fname, 'rb');

    //Step 1.2 - Prepare an icondir structure/object and fill with the Header
    var pos = 0;
    var icondir =
    {
        "idReserved" : fp.ReadInt16(pos),
        "idType"     : fp.ReadInt16(pos + 2),
        "idCount"    : fp.ReadInt16(pos + 4),
        "idEntries"  : []
    };
    pos += 6;

    //Step 2.2 - Read all the image entry + data
    for (var i = 0; i < icondir.idCount; i++)
    {
        var icondirentry =
        {
            'bWidth'        : fp.ReadInt8(pos),
            'bHeight'       : fp.ReadInt8(pos + 1),
            'bColorCount'   : fp.ReadInt8(pos + 2),
            'bReserved'     : fp.ReadInt8(pos + 3),
            'wPlanes'       : fp.ReadInt16(pos + 4),
            'wBitCount'     : fp.ReadInt16(pos + 6),
            'dwBytesInRes'  : fp.ReadInt32(pos + 8),
            'dwImageOffset' : fp.ReadInt32(pos + 12)
        };
        icondirentry.iconimage = fp.ReadHex(icondirentry.dwImageOffset, icondirentry.dwBytesInRes);

        icondir.idEntries[i]   = icondirentry;
        pos += 16;
    }

    //Step 2.3 - Close the file
    fp.Close();

    //Step 3 - Return the structure created
    return icondir;
}
