///===========================================================================================///
/// Register all your Addons in this file. All Addons need to be registered to appear in NEMO ///
///===========================================================================================///

//#########################################################################################\\
//# Addon Registrations                                                                   #\\
//#########################################################################################\\
//#                                                                                       #\\
//# FORMAT : RegisterAddon(funcName, description, tooltip);                               #\\
//#                                                                                       #\\
//#	funcName is the function called when an Addon is clicked. All your logic & code for   #\\
//# the addon goes inside it. If it is not defined the Addon will not be available        #\\
//# inside "Addons" menu of NEMO.                                                         #\\
//#                                                                                       #\\
//# Remember funcName is a string here so make sure it is inside single or double quotes. #\\
//# Also keep funcName definition in any .qs file inside the Addons folder                #\\
//# (to avoid confusion with Patches).                                                    #\\
//#                                                                                       #\\
//# description is the text that shows up in the "Addons" menu of NEMO. So keep it brief. #\\
//#                                                                                       #\\
//# tooltip is the text which shows detail about what a particular tool/addon does        #\\
//# it shows up when you hover over an Addon.                                             #\\
//#                                                                                       #\\
//#########################################################################################\\

RegisterAddon("ExtractMsgTable", "Extract msgstringtable", "Extracts embedded msgstringtable from the loaded client");

RegisterAddon("ExtractTxtNames", "Extract txt file names", "Extracts embedded txt file names in the loaded client");

RegisterAddon("GenMapEffectPlugin", "Generate Mapeffect plugin by Curiosity", "Generates Curiosity's mapeffect plugin for the loaded client");

RegisterAddon("GenPktExtractDLL", "Generate Packet Extract DLL", "Generates Packet Extractor DLL for the loaded client");

RegisterAddon("GetPacketKeys", "Get Packet Keys", "Retrieves the packet keys used in the loaded client for Obfuscation");

RegisterAddon("DumpImportTable", "Dump Import Table", "Dumps the Full Import table (dll names and imported functions) for the loaded client")
