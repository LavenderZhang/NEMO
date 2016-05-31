///=================================================================================================================///
/// Register all your Patches and Patch Groups in this file. Always register a group before using its id in a patch ///
///=================================================================================================================///

//###########################################################\\
//# Patch Group registrations                               #\\
//###########################################################\\
//#                                                         #\\
//# FORMAT: RegisterGroup(id, name, mutex);                 #\\
//#                                                         #\\
//# If mutex is true, only one of the patches in the group  #\\
//# can be selected at a time. id = 0 is already registered #\\
//# as the "Generic" group with mutex = false               #\\
//#                                                         #\\
//###########################################################\\

RegisterGroup( 1, "ChatLimit", true);

RegisterGroup( 2, "FixCameraAngles", true);

RegisterGroup( 3, "IncreaseZoomOut", true);

RegisterGroup( 4, "UseIcon", true);

RegisterGroup( 5, "MultiGRFs", true);

RegisterGroup( 6, "SharedBodyPalettes", true)

RegisterGroup( 7, "SharedHeadPalettes", true);

RegisterGroup( 8, "OnlySelectedLoginBackground", true);

RegisterGroup( 9, "PacketEncryptionKeys", false);

RegisterGroup(10, "LoginMode", true);

RegisterGroup(11, "CashShop", true);

RegisterGroup(12, "HideButton", false);

RegisterGroup(14, "LicenseScreen", true);

RegisterGroup(15, "Resurrection", true);

RegisterGroup(16, "WalkToDelay", true);

//################################################################################################\\
//# Patch registrations                                                                          #\\
//################################################################################################\\
//#                                                                                              #\\
//# FORMAT: RegisterPatch(id, funcName, name, type, group id, author, description, recommended); #\\
//#                                                                                              #\\
//# funcName is the function called when a patch is selected. All the logic & code for the patch #\\
//# goes inside it. If its not defined then the patch won't be added to the Patch Table.         #\\
//#                                                                                              #\\
//# funcName_ if defined is also called while the patch is being added to Patch Table and NEMO   #\\
//# skips the patch addition if the result is false.                                             #\\
//#                                                                                              #\\
//# _funcName if defined is called when a patch gets deselected.                                 #\\
//#                                                                                              #\\
//# Remember funcName is a string here so make sure it is inside single or double quotes.        #\\
//# Also funcName, funcName_ and _funcName functions can be defined in any .qs file inside the   #\\
//#                                                                                              #\\
//# recommended is a boolean that sets up specific patches as "Recommended Patches". Such        #\\
//# Patches also get a "(Recommended)" tag after the patch name automatically.                   #\\
//#                                                                                              #\\
//################################################################################################\\

//0 - not used currently

RegisterPatch(  1, "UseTildeForMatk", "Use Tilde for Matk", "UI", 0, "Neo", "Make the client use tilde (~) symbol for Matk in Stats Window instead of Plus (+)", false);

RegisterPatch(  2, "AllowChatFlood", "Chat Flood Allow", "UI", 1, "Shinryo", "Disable the clientside repeat limit of 3, and sets it to the specified value", false);

RegisterPatch(  3, "RemoveChatLimit", "Chat Flood Remove Limit", "UI", 1, "Neo", "Remove the clientside limitation which checks for maximum repeated lines", false);

RegisterPatch(  4, "CustomAuraLimits", "Use Custom Aura Limits", "UI", 0, "Neo", "Allows the client to display standard auras within user specified limits for Classes and Levels", false);

RegisterPatch(  5, "EnableProxySupport", "Enable Proxy Support", "Fix", 0, "Ai4rei/AN", "Ignores server-provided IP addresses when changing servers", false);

RegisterPatch(  6, "ForceSendClientHash", "Force Send Client Hash Packet", "Packet", 0, "GreenBox, Neo", "Forces the client to send a packet with it's MD5 hash for all LangTypes. Only use if you have enabled it in your server", false);
/*
RegisterPatch(  7, "ChangeGravityErrorHandler", "Change Gravity Error Handler", "Fix", 0, " ", "It changes the Gravity Error Handler Mesage for a Custom One Pre-Defined by Diff Team", false);
*/
RegisterPatch(  8, "CustomWindowTitle", "Custom Window Title", "UI", 0, "Shinryo", "Changes window title. Normally, the window title is 'Ragnarok'", false);

RegisterPatch(  9, "Disable1rag1Params", "Disable 1rag1 type parameters", "Fix", 0, "Shinryo", "Enable this to launch the client directly without patching or any 1rag1, 1sak1 etc parameters", true);

RegisterPatch( 10, "Disable4LetterCharnameLimit", "Disable 4 Letter Character Name Limit", "Fix", 0, "Shinryo", "Will allow people to use character names shorter than 4 characters", false);

RegisterPatch( 11, "Disable4LetterUsernameLimit", "Disable 4 Letter User Name Limit", "Fix", 0, "Shinryo", "Will allow people to use account names shorter than 4 characters", false);

RegisterPatch( 12, "Disable4LetterPasswordLimit", "Disable 4 Letter Password Limit", "Fix", 0, "Shinryo", "Will allow people to use passwords shorter than 4 characters", false);

RegisterPatch( 13, "DisableFilenameCheck", "Disable Ragexe Filename Check", "Fix", 0, "Shinryo", "Disables the check that forces the client to quit if not called an official name like ragexe.exe for all LangTypes", true);

RegisterPatch( 14, "DisableHallucinationWavyScreen", "Disable Hallucination Wavy Screen", "Fix", 0, "Shinryo", "Disables the Hallucination effect (screen becomes wavy and lags the client), used by baphomet, horongs, and such", true);

RegisterPatch( 15, "DisableHShield", "Disable HShield", "Fix", 0, "Ai4rei/AN, Neo", "Disables HackShield", true);

RegisterPatch( 16, "DisableSwearFilter", "Disable Swear Filter", "UI", 0, "Shinryo", "The content of manner.txt has no impact on ability to send text", false);

RegisterPatch( 17, "EnableOfficialCustomFonts", "Enable Official Custom Fonts", "UI", 0, "Shinryo", "This option forces Official Custom Fonts (eot files int data folder) on all LangType", false);

RegisterPatch( 18, "SkipServiceSelect", "Skip Service Selection Screen", "UI", 0, "Shinryo", "Jumps directly to the login interface without asking to select a service", false);

RegisterPatch( 19, "EnableTitleBarMenu", "Enable Title Bar Menu", "UI", 0, "Shinryo", "Enable Title Bar Menu (Reduce, Maximize, Close button) and the window icon", false);

RegisterPatch( 20, "ExtendChatBox", "Extend Chat Box", "UI", 0, "Shinryo", "Extend the Main/Battle chat box max input chars from 70 to 234", false);

RegisterPatch( 21, "ExtendChatRoomBox", "Extend Chat Room Box", "UI", 0, "Shinryo", "Extend the chat room box max input chars from 70 to 234", false);

RegisterPatch( 22, "ExtendPMBox", "Extend PM Box", "UI", 0, "Shinryo", "Extend the PM chat box max input chars from 70 to 221", false);

RegisterPatch( 23, "EnableWhoCommand", "Enable /who command", "UI", 0, "Neo", "Enable /w and /who command for all LangTypes", true);

RegisterPatch( 24, "FixCameraAnglesRecomm", "Fix Camera Angles", "UI", 2, "Shinryo", "Unlocks the possible camera angles to give more freedom of placement. Gives a medium range of around 60 degrees", true);

RegisterPatch( 25, "FixCameraAnglesLess", "Fix Camera Angles (LESS)", "UI", 2, "Shinryo", "Unlocks the possible camera angles to give more freedom of placement. This enables an 30deg angle", false);

RegisterPatch( 26, "FixCameraAnglesFull", "Fix Camera Angles (FULL)", "UI", 2, "Shinryo", "Unlocks the possible camera angles to give more freedom of placement. This enables an almost ground-level camera", false);

RegisterPatch( 27, "HKLMtoHKCU", "HKLM To HKCU", "Fix", 0, "Shinryo", "This makes the client use HK_CURRENT_USER registry entries instead of HK_LOCAL_MACHINE. Necessary for users who have no admin privileges on their computer", false);

RegisterPatch( 28, "IncreaseViewID", "Increase Headgear ViewID", "Data", 0, "Shinryo", "Increases the limit for the headgear ViewIDs from 2000 to User Defined value (max 32000)", false);

RegisterPatch( 29, "DisableGameGuard", "Disable Game Guard", "Fix", 0, "Neo", "Disables Game Guard from new clients", true);

RegisterPatch( 30, "IncreaseZoomOut50Per", "Increase Zoom Out 50%", "UI", 3, "Shinryo", "Increases the zoom-out range by 50 percent", false);

RegisterPatch( 31, "IncreaseZoomOut75Per", "Increase Zoom Out 75%", "UI", 3, "Shinryo", "Increases the zoom-out range by 75 percent", false);

RegisterPatch( 32, "IncreaseZoomOutMax", "Increase Zoom Out Max", "UI", 3, "Shinryo", "Maximizes the zoom-out range", false);

RegisterPatch( 33, "KoreaServiceTypeXMLFix", "Always Call SelectKoreaClientInfo()", "Fix", 0, "Shinryo", "Calls SelectKoreaClientInfo() always before SelectClientInfo() allowing you to use features that would be only visible on Korean Service Type", true);

RegisterPatch( 34, "EnableShowName", "Enable /showname", "Fix", 0, "Neo", "Enables use of /showname command on all LangTypes", true);

RegisterPatch( 35, "ReadDataFolderFirst", "Read Data Folder First", "Data", 0, "Shinryo", "Gives the data directory contents priority over the data/sdata.grf contents", false);

RegisterPatch( 36, "ReadMsgstringtableDotTxt", "Read msgstringtable.txt", "Data", 0, "Shinryo", "This option will force the client to read all the user interface messages from msgstringtable.txt instead of displaying the Korean messages", true);

RegisterPatch( 37, "ReadQuestid2displayDotTxt", "Read questid2display.txt", "Data", 0, "Shinryo", "Makes the client to load questid2display.txt on all LangTypes (instead of only 0)", true);

RegisterPatch( 38, "RemoveGravityAds", "Remove Gravity Ads", "UI", 0, "Shinryo", "Removes Gravity ads on the login background", true);

RegisterPatch( 39, "RemoveGravityLogo", "Remove Gravity Logo", "UI", 0, "Shinryo", "Removes Gravity Logo on the login background", true);

RegisterPatch( 40, "RestoreLoginWindow", "Restore Login Window", "Fix", 10, "Shinryo, Neo", "Circumvents Gravity's new token-based login system and restores the normal login window", true);

RegisterPatch( 41, "DisableNagleAlgorithm", "Disable Nagle Algorithm", "Packet", 0, "Shinryo", "Disables the Nagle Algorithm. The Nagle Algorithm queues packets before they are sent in order to minimize protocol overhead. Disabling the algorithm will slightly increase network traffic, but it will decrease latency as well", true);

RegisterPatch( 42, "SkipResurrectionButton", "Skip Resurrection Button", "UI", 15, "Shinryo", "Skip showing resurrection button when you die with Token of Ziegfried in inventory", false);

RegisterPatch( 43, "DeleteCharWithEmail", "Always Use Email for Char Deletion", "Fix", 0, "Neo", "Makes the Client use Email as Deletion Password for all LangTypes", false);

RegisterPatch( 44, "TranslateClient", "Translate Client", "UI", 0, "Ai4rei/AN, Neo", "This will translate some of the Hard-coded Korean phrases with strings stored in TranslateClient.txt. It also fixes the Korean Job name issue with LangType", true);

RegisterPatch( 45, "UseCustomAuraSprites", "Use Custom Aura Sprites", "Data", 0, "Shinryo", "This option will make it so your warp portals will not be affected by your aura sprites. For this you will have to make aurafloat.tga and auraring.bmp and place them in your 'data\\texture\\effect' folder", false);

RegisterPatch( 46, "UseNormalGuildBrackets", "Use Normal Guild Brackets", "UI", 0, "Shinryo", "On LangType 0, instead of square-brackets, japanese style brackets are used, this option reverts that behaviour to the normal square brackets '[' and ']'", true);

RegisterPatch( 47, "UseRagnarokIcon", "Use Ragnarok Icon", "UI", 4, "Shinryo, Neo", "Makes the hexed client use the RO program icon instead of the generic Win32 app icon", false);

RegisterPatch( 48, "UsePlainTextDescriptions", "Use Plain Text Descriptions", "Data", 0, "Shinryo", "Signals that the contents of text files are text files, not encoded", true);

RegisterPatch( 49, "EnableMultipleGRFsV1", "Enable Multiple GRFs", "UI", 5, "Shinryo", "Enables the use of multiple grf files by putting them in a data.ini file in your client folder.You can only load up to 10 total grf files with this option ( -9)", true);

RegisterPatch( 50, "SkipLicenseScreen", "Skip License Screen", "UI", 14, "Shinryo, MS", "Skip the warning screen and goes directly to the main window with the Service Select", false);

RegisterPatch( 51, "ShowLicenseScreen", "Always Show License Screen", "UI", 14, "Neo", "Makes the client always show the License for all LangTypes", false);

RegisterPatch( 52, "UseCustomFont", "Use Custom Font", "UI", 0, "Ai4rei/AN", "Allows the use of user-defined font for all LangTypes. The LangType-specific charset is still being enforced, so if the selected font does not support it, the system falls back to a font that does", false);

RegisterPatch( 53, "UseAsciiOnAllLangTypes", "Use Ascii on All LangTypes", "UI", 0, "Ai4rei/AN", "Makes the Client Enable ASCII irrespective of Font or LangTypes", true);

RegisterPatch( 54, "ChatColorGM", "Chat Color - GM", "Color", 0, "Ai4rei/AN, Shakto", "Changes the GM Chat color and sets it to the specified value. Default value is ffff00 (Yellow)", false);

RegisterPatch( 55, "ChatColorPlayerOther", "Chat Color - Other Player", "Color", 0, "Ai4rei/AN, Shakto", "Changes other players Chat color and sets it to the specified value. Default value is ffffff (White)" );
/*     Behaves identically to GM Chat Color patch - to be removed
RegisterPatch( 56, "ChatColorMain", "Chat Color - Main", "Color", 0, "Ai4rei/AN, Shakto", "Changes the Main Chat color and sets it to the specified value", false);
*/
RegisterPatch( 57, "ChatColorGuild", "Chat Color - Guild", "Color", 0, "Ai4rei/AN, Shakto", "Changes the Guild Chat color and sets it to the specified value. Default Value is b4ffb4 (Light Green)", false);

RegisterPatch( 58, "ChatColorPartyOther", "Chat Color - Other Party ", "Color", 0, "Ai4rei/AN, Shakto", "Changes the Other Party members Chat color and sets it to the specified value. Default value is ffc8c8 (Pinkish)", false);

RegisterPatch( 59, "ChatColorPartySelf", "Chat Color - Your Party", "Color", 0, "Ai4rei/AN, Shakto", "Changes Your Party Chat color and sets it to the specified value. Default value is ffc800 (Orange)", false);

RegisterPatch( 60, "ChatColorPlayerSelf", "Chat Color - Self", "Color", 0, "Ai4rei/AN, Shakto", "Changes your character's Chat color and sets it to the specified value. Default value is 00ff00 (Green)", false);

RegisterPatch( 61, "DisablePacketEncryption", "Disable Packet Encryption", "UI", 0, "Ai4rei/AN", "Disable kRO Packet ID Encryption. Also known as Skip Packet Obfuscation", false);

RegisterPatch( 62, "DisableLoginEncryption", "Disable Login Encryption", "Fix", 0, "Neo", "Disable Encryption in Login Packet 0x2b0", true);

RegisterPatch( 63, "UseOfficialClothPalette", "Use Official Cloth Palettes", "UI", 0, "Neo", "Use Official Cloth Palette on all LangTypes. Do not use this if you are using the 'Enable Custom Jobs' patch", false);

RegisterPatch( 64, "FixChatAt", "@ Bug Fix", "UI", 0, "Shinryo", "Correct the bug to write @ in chat", true);

RegisterPatch( 65, "ChangeItemInfo", "Load Custom lua file instead of iteminfo*.lub", "UI", 0, "Neo", "Makes the client load your own lua file instead of iteminfo*.lub . If you directly use itemInfo*.lub for your translated items, it may become lost during the next kRO update", true);

RegisterPatch( 66, "LoadItemInfoPerServer", "Load iteminfo with char server", "Data", 0, "Neo", "Load ItemInfo file and call main function with selected char server name as argument", false);

RegisterPatch( 67, "DisableQuakeEffect", "Disable Quake skill effect", "UI", 0, "Ai4rei/AN", " Disables the Earthquake skill effect", false);

RegisterPatch( 68, "Enable64kHairstyle", "Enable 64k Hairstyle", "UI", 0, "Ai4rei/AN", "Increases Max Hairstyle limit to 64k from default 27", false);

RegisterPatch( 69, "ExtendNpcBox", "Extend Npc Dialog Box", "UI", 0, "Ai4rei/AN", "Increases Max input chars of NPC Dialog boxes from 2052 to 4096", false);

RegisterPatch( 70, "CustomExpBarLimits", "Use Custom Exp Bar Limits", "UI", 0, "Neo", "Allows client to use user specified limits for Exp Bars", false);

RegisterPatch( 71, "IgnoreResourceErrors", "Ignore Resource Errors", "Fix", 0, "Shinryo", "Prevents the client from displaying a variety of Error messages (but not all of them) including missing files. This does not guarantee the client will work in-spite of missing files", false);

RegisterPatch( 72, "IgnoreMissingPaletteError", "Ignore Missing Palette Error", "Fix", 0, "Shinryo", "Prevents the client from displaying error messages about missing palettes. It does not guarantee client will not crash if files are missing", false);

RegisterPatch( 73, "RemoveHourlyAnnounce", "Remove Hourly Announce", "UI", 0, "Ai4rei/AN", "Remove hourly game grade and hourly play time minder announcements", true);

RegisterPatch( 74, "IncreaseScreenshotQuality", "Increase Screenshot Quality", "UI", 0, "Ai4rei/AN", "Allows changing the JPEG quality parameter for screenshots", false);

RegisterPatch( 75, "EnableFlagEmotes", "Enable Flag Emoticons", "UI", 0, "Neo", "Enable Selected Flag Emoticons for all LangTypes. You need to specify a txt file as input with the flag constants assigned to 1-9", false);

RegisterPatch( 76, "EnforceOfficialLoginBackground", "Enforce Official Login Background", "UI", 0, "Shinryo", "Enforce Official Login Background for all LangType", false);

RegisterPatch( 77, "EnableCustom3DBones", "Enable Custom 3D Bones", "Data", 0, "Ai4rei/AN", "Enables the use of custom 3D monsters (Granny) by lifting Hard-coded ID limit", false);

RegisterPatch( 78, "MoveCashShopIcon", "Move Cash Shop Icon", "UI",  11, "Neo", "Move the Cash Shop icon to user specified co-ordinates. Positive values are relative to left and top, Negative values are relative to right and bottom", false);

RegisterPatch( 79, "SharedBodyPalettesV2", "Shared Body Palettes Type2", "UI", 6, "Ai4rei/AN, Neo", "Makes the client use a single cloth palette set (body_%d.pal) for all job classes both genders", false);

RegisterPatch( 80, "SharedBodyPalettesV1", "Shared Body Palettes Type1", "UI", 6, "Ai4rei/AN, Neo", "Makes the client use a single cloth palette set (body_%s_%d.pal) for all job classes but separate for both genders", false);

RegisterPatch( 81, "RenameLicenseTxt", "Rename License File", "Data", 0, "Neo", "Rename the filename used for EULA from '..\\licence.txt' to user specified name (Path is relative to Data folder)", false);

RegisterPatch( 82, "SharedHeadPalettesV1", "Shared Head Palettes Type1", "UI", 7, "Ai4rei/AN, Neo", "Makes the client use a single hair palette set (head_%s_%d.pal) for all job classes but separate for both genders", false);

RegisterPatch( 83, "SharedHeadPalettesV2", "Shared Head Palettes Type2", "UI", 7, "Ai4rei/AN, Neo", "Makes the client use a single hair palette set (head_%d.pal) for all job classes both genders", false);

RegisterPatch( 84, "RemoveSerialDisplay", "Remove Serial Display", "UI", 0, "Shinryo", "Removes the display of the client serial number in the login window (bottom right corner)", true);

RegisterPatch( 85, "ShowCancelToServiceSelect","Show Cancel To Service Select", "UI", 0, "Neo", "Restores the Cancel button in Login Window for switching back to Service Select Window. The button will be placed in between Login and Exit buttons", false);

RegisterPatch( 86, "OnlyFirstLoginBackground", "Only First Login Background", "UI", 8, "Shinryo", "Displays always the first login background", false);

RegisterPatch( 87, "OnlySecondLoginBackground", "Only Second Login Background", "UI", 8, "Shinryo", "Displays always the second login background", false);

RegisterPatch( 88, "AllowSpaceInGuildName", "Allow space in guild name", "UI", 0, "Shakto", "Allow player to create a guild with space in the name (/guild \"Space Name\")", false);

RegisterPatch( 90, "EnableDNSSupport", "Enable DNS Support", "UI", 0, "Shinryo", "Enable DNS support for clientinfo.xml", true);

RegisterPatch( 91, "DcToLoginWindow", "Disconnect to Login Window", "UI", 0, "Neo", "Make the client return to Login Window upon disconnection", false);

RegisterPatch( 92, "PacketFirstKeyEncryption", "Packet First Key Encryption", "Packet", 9, "Shakto, Neo", "Change the 1st key for packet encryption. Dont select the patch Disable Packet Header Encryption if you are using this. Don't use it if you don't know what you are doing", false);

RegisterPatch( 93, "PacketSecondKeyEncryption", "Packet Second Key Encryption", "Packet", 9, "Shakto, Neo", "Change the 2nd key for packet encryption. Dont select the patch Disable Packet Header Encryption if you are using this. Don't use it if you don't know what you are doing", false);

RegisterPatch( 94, "PacketThirdKeyEncryption", "Packet Third Key Encryption", "Packet", 9, "Shakto, Neo", "Change the 3rd key for packet encryption. Dont select the patch Disable Packet Header Encryption if you are using this. Don't use it if you don't know what you are doing", false);

RegisterPatch( 95, "UseSSOLoginPacket", "Use SSO Login Packet", "Packet", 10, "Ai4rei/AN", "Enable using SSO packet on all LangType (to use login and pass with a launcher)", false);

RegisterPatch( 96, "RemoveGMSprite", "Remove GM Sprites", "UI", 0, "Neo", "Remove the GM sprites and keeping all the functionality like Yellow name and Admin right click menu", false);

RegisterPatch( 97, "CancelToLoginWindow", "Cancel to Login Window", "Fix", 0, "Neo", "Makes clicking the Cancel button in Character selection window return to login window instead of Quitting", true);

RegisterPatch( 98, "DisableDCScream", "Disable dc_scream.txt", "UI", 0, "Neo", "Disable chat on file dc_scream", false);

RegisterPatch( 99, "DisableBAFrostJoke", "Disable ba_frostjoke.txt", "UI", 0, "Neo", "Disable chat on file ba_frostjoke", false);

RegisterPatch(100, "DisableMultipleWindows", "Disable Multiple Windows", "UI", 0, "Shinryo, Ai4rei/AN", "Prevents the client from creating more than one instance on all LangTypes", false);

RegisterPatch(101, "SkipCheaterFriendCheck", "Skip Friend list Cheat Check", "UI", 0, "Ai4rei/AN", "Prevents warnings during PM's when the sender has similar name to one of your friends", false);

RegisterPatch(102, "SkipCheaterGuildCheck", "Skip Guild Member Cheat Check", "UI", 0, "Ai4rei/AN", "Prevents warnings during PM's when the sender has similar name to one of your guild members", false);

RegisterPatch(103, "DisableAutofollow", "Disable Auto follow", "UI", 0, "Functor, Neo", "Disables player auto-follow on Shift+Right click", false);

RegisterPatch(104, "IncreaseHairLimits", "Increase Hair Style & Color Limits", "UI", 0, "Neo", "Modify the limits used in Make Character Window for Hair Style and Color to user specified values");

RegisterPatch(105, "HideNavButton", "Hide Nav Button", "UI", 12, "Neo", "Hide Navigation Button", false);

RegisterPatch(106, "HideBgButton", "Hide BG Button", "UI", 12, "Neo", "Hide Battleground Button", false);

RegisterPatch(107, "HideBankButton", "Hide Bank Button", "UI", 12, "Neo", "Hide Bank Button", false);

RegisterPatch(108, "HideBooking", "Hide Booking Button", "UI", 12, "Neo", "Hide Booking Button", false);

RegisterPatch(109, "HideRodex", "Hide Rodex Button", "UI", 12, "Neo", "Hide Rodex Button", false);

RegisterPatch(110, "HideAchieve", "Hide Achievements Button", "UI", 12, "Neo", "Hide Achievements Button", false);

RegisterPatch(111, "HideRecButton", "Hide Rec Button", "UI", 12, "Neo", "Hide Rec Button", false);

RegisterPatch(112, "HideMapButton", "Hide Map Button", "UI", 12, "Neo", "Hide Map Button", false);

RegisterPatch(113, "HideQuest", "Hide Quest Button", "UI", 12, "Neo", "Hide Quest Button", false);

RegisterPatch(114, "ChangeVendingLimit", "Change Vending Limit [Experimental]", "Data", 0, "Neo", "Change the Vending Limit of 1 Billion zeny to user specified value", false);

RegisterPatch(115, "EnableEffectForAllMaps", "Enable Effect for all Maps [Experimental]", "Data", 0, "Neo", "Make the client load the corresponding file in EffectTool folder for all maps", false);

RegisterPatch(116, "EnableTipOnStartup", "Enable Tip Window on Startup", "UI", 0, "Make the client actually show the Tip Window on startup, if it was checked/selected last time", false);
/*        Custom Font patch already does this irrespective of LangType - to be removed
RegisterPatch(151, "UseArialOnAllLangTypes", "Use Arial on All LangTypes", "UI", 0, "Ai4rei/AN, Shakto", "Makes Arial the default font on all LangTypes (it's enable ascii by default)", true);
*/

//======================================//
// Special Patches by Neo and Curiosity //
//======================================//

RegisterPatch(200, "EnableMultipleGRFsV2", "Enable Multiple GRFs - Embedded", "Custom", 5, "Neo", "Enables the use of multiple grf files without needing INI file in client folder. Instead you specify the INI file as input to the patch", false);

RegisterPatch(201, "EnableCustomHomunculus", "Enable Custom Homunculus", "Custom", 0, "Neo", "Enables the addition of Custom Homunculus using Lua Files", false);

RegisterPatch(202, "EnableCustomJobs", "Enable Custom Jobs", "Custom", 0, "Neo", "Enables the use of Custom Jobs (using Lua Files similar to Xray)", false);

RegisterPatch(203, "EnableCustomShields", "Enable Custom Shields", "Custom", 0, "Neo", "Enables the use of Custom Shield Types (using Lua Files similar to Xray)", false);

RegisterPatch(204, "IncreaseAtkDisplay", "Increase Attack Display", "Custom", 0, "Neo", "Increases the limit of digits displayed while attacking from 6 to 10", false);

RegisterPatch(205, "EnableMonsterTables", "Enable Monster Tables", "Custom", 0, "Ind, Neo", "Enables Loading of MonsterTalkTable.xml, PetTalkTable.xml & MonsterSkillInfo.xml for all LangTypes", false);

RegisterPatch(206, "LoadCustomQuestLua", "Load Custom Quest Lua/Lub files", "Custom", 0, "Neo", "Enables loading of custom lua files used for quests. You need to specify a txt file containing list of files in the 'lua files\\quest' folder to load (one file per line)", false);

RegisterPatch(207, "ResizeFont", "Resize Font", "Custom", 0, "Yommy, Neo", "Resizes the height of the font used to the value specified", false);

RegisterPatch(208, "RestoreCashShop", "Restore Cash Shop Icon", "Special", 0, "Neo", "Restores the Cash Shop Icon in RE clients that can have them", false);

RegisterPatch(209, "EnableMailBox", "Enable Mail Box for All LangTypes", "Custom", 0, "Neo", "Enables the full use of Mail Boxes and @mail commands (write is disabled for few LangTypes by default in 2013 Clients)", false);

RegisterPatch(210, "UseCustomIcon", "Use Custom Icon", "Custom", 4, "Neo", "Makes the hexed client use the User specified icon. Icon file should have an 8bpp (256 color) 32x32 image", false);

RegisterPatch(211, "UseCustomDLL", "Use Custom DLL", "Custom", 0, "Neo", "Makes the hexed client load the specified DLL and functions", false);

RegisterPatch(212, "RestoreRoulette", "Restore Roulette", "Custom", 0, "Neo", "Brings back the Roulette Icon that was removed in new clients", false);

RegisterPatch(213, "DisableHelpMsg", "Disable Help Message on Login", "Custom", 0, "Neo", "Prevents the Help Message being shown on Login for all LangTypes", true);

RegisterPatch(214, "RestoreModelCulling", "Restore Model Culling", "Custom", 0, "Curiosity", "Culls models in front of player by turning them transparent", false);

RegisterPatch(215, "IncreaseMapQuality", "Increase Map Quality", "Custom", 0, "Curiosity", "Makes client use 32 bit color maps for Map Textures", false);

RegisterPatch(216, "HideCashShop", "Hide Cash Shop", "Custom", 0, "Neo", "Hide Cash Shop Icon", false);

RegisterPatch(217, "HideRoulette", "Hide Roulette", "Custom", 0, "Neo", "Hide Roulette Icon", false);

RegisterPatch(218, "ShowExpNumbers", "Show Exp Numbers", "Custom", 0, "Neo", "Show Base and Job Exp numbers in Basic Info Window", false);

RegisterPatch(219, "ShowResurrectionButton", "Always Show Resurrection Button", "Custom", 15, "Neo", "Make the client always show Resurrection button with Token of Ziegfried in inventory irrespective of map type", false);

RegisterPatch(220, "DisableMapInterface", "Disable Map Interface", "Custom", 0, "Neo", "Disable the World View (Full Map) Interface", false);

RegisterPatch(221, "RemoveJobsFromBooking", "Remove Jobs from Booking", "Custom", 0, "Neo", "Removes user specified set of Job Names from Party Booking Window.", false);

RegisterPatch(222, "ShowReplayButton", "Show Replay Button", "Custom", 0, "Neo", "Makes the client show Replay button on Service Select screen that opens the Replay File List window", false);

RegisterPatch(223, "MoveItemCountUpwards", "Move Item Count Upwards [Experimental]", "Custom", 0, "Neo", "Move Item Count upwards in Shortcut Window so as to align with Skill Level display", false);
/*
RegisterPatch(224, "IncreaseNpcIDs", "Increase NPC Ids [Experimental]", "Custom", 0, "Neo", "Increase the Loaded NPC IDs to include 10K+ range IDs. Limits are configurable", false);
*/
RegisterPatch(225, "ShowRegisterButton", "Show Register Button", "Custom", 0, "Neo", "Makes the client always show register button on Login Window for all Langtypes. Clicking the button will open <registrationweb> from clientinfo and closes the client.", false);

RegisterPatch(226, "DisableWalkToDelay", "Disable Walk To Delay", "Fix", 16, "MegaByte", "Will have a quicker response to walking clicks. But client may likely send more/duplicated packets.", false);

RegisterPatch(227, "SetWalkToDelay", "Change Walk To Delay", "Fix", 16, "MegaByte", "Can have a quicker response to walking clicks. But client may likely send more/duplicated packets.", false);

RegisterPatch(228, "EnableEmblemForBG", "Enable Emblem hover for BG", "UI", 0, "Neo", "Makes the client show the Emblem on top of the character for Battleground mode as well along with GvG", false);
