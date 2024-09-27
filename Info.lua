--[[----------------------------------------------------------------------------

Info.lua
Summary information for Mylio Lightroom plug-in

------------------------------------------------------------------------------]]

return {

	LrSdkVersion = 3.0,
	LrSdkMinimumVersion = 3.0, -- minimum SDK version required by this plug-in

	LrToolkitIdentifier = 'com.mylio.publish',
	LrPluginName = LOC "$$$/Mylio/PluginName=Mylio",
	
	LrExportServiceProvider = {
		title = LOC "$$$/Mylio/Mylio-title=Mylio",
		file = 'ExportServiceProvider.lua',
	},
	
	LrLibraryMenuItems = {
	    {
		    title = LOC "$$$/Mylio/CustomDialog=Restore virtual copys from snapshot",
		    file = "restoreCopy.lua",
		},
	},

	LrMetadataProvider = 'MetadataDefinition.lua',

	VERSION = { major=1, minor=0, revision=0, build=0, },

}
