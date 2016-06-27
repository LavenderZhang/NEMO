LT =  //LangType Hash
{
    "Value": -1,   //g_serviceType Address
    "Hex"  : "",   //Address in Little Endian Format
    "Error": false //Any Error Strings (remains false if LangType was extracted properly)
};
GetLangType(LT);

WM = //WindowMgr Hash
{
    "MakeWin": -1,   //Address of UIWindowMgr::MakeWindow
    "MovEcx" : "",   //Code for MOV ECX, g_windowMgr
    "Error"  : false //Any Error Strings (remains false if above 2 was extracted properly)
};
GetWinMgrData(WM);

EBP_TYPE = HasFramePointer(); //true if Frame Pointer Optimization is not done

PK =
{
    "KeyAssigner": -1,      //Address of Function which assigns the Packet Keys to ECX+4, ECX+8 and ECX+0C respectively
    "Type"       : -1,      //Type of Function:
                            //  0 = Only assigns the Packet keys which are PUSHed as arguments,
                            //  1 = Function also serves as the Encryptor depending on the mode value PUSHed as argument => keys are inside the function body
                            //  2 = Same as 1 But Function is virtualized (for new clients only)
    "Keys"   : [0, 0, 0],   //The 3 Packet Keys Extracted/Mapped
    "MovEcx" : "",          //The MOV ECX code before the KeyAssigner is called
    "OvrAddr": -1,          //Address to overwrite with a JMP (needed for Packet Key patch for Type = 0)
    "Error"  : false        //Any Error Strings (remains false if all went while getting the info)
};
GetPacketKeyData(PK);

LUA =
{
    "D2S"       : "", //PUSH OFFSET "d>s" in hex
    "D2D"       : "", //PUSH OFFSET "d>d" in hex
    "ReqJob"    : "", //PUSH OFFSET "ReqJobName" in hex
    "EspConst"  :  0, //const from SUB ESP, const before Function name is PUSHed
    "StrAlloc"  : -1, //Function which allocates memory for storing Function Name
    "AllocType" : -1, //Type of the above function
    "StatePush" : "", //PUSH DWORD PTR DS:[LuaState] in hex
    "FnCaller"  : -1, //Function which calls a Lua function specified by the name
    "Error"     : false
};
GetLuaData();//function directly works on LUA hash and hence doesnt need to be passed as argument

SKL = //Used for Enable*Skills patches
{
    "Offset"    : -1,
    "Prefix"    : "",
    "PatchID"   : false,
    "Error"     : false
}