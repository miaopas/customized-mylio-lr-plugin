local LrFunctionContext = import 'LrFunctionContext'
local LrBinding = import 'LrBinding'
local LrDialogs = import 'LrDialogs'
local LrView = import 'LrView'
local LrProgressScope = import "LrProgressScope"
local LrDialogs = import 'LrDialogs'
local LrTasks = import 'LrTasks'
local LrApplication = import 'LrApplication'
local LrPathUtils = import 'LrPathUtils'
local LrApplicationView = import 'LrApplicationView'
local LrLogger = import 'LrLogger'
local logger = LrLogger('MylioPlugin')
logger:enable("logfile")
local log = logger:quickf('info')


function table_to_string(t)
	s = ""
	for kk, vv in pairs(t) do
		s = s .. kk .. ":"
		for k, v in pairs(vv) do
			s = s .. k .. ":" .. v .. "\n" -- concatenate key/value pairs, with a newline in-between
		end
		s = s .. "\n" .. "\n"
	end
	return s
end


LrTasks.startAsyncTask(function ()
	LrFunctionContext.callWithContext("Restore Snapshots", function(context)
		local catalog = LrApplication.activeCatalog()
		
		-- all photos need to be processd
		local photos = catalog:getTargetPhotos()

		if photos == nil then
			LrDialogs.message("Please select a photo")
			return
		end

		local names = ''
		local total = #photos
		local progressScope = LrDialogs.showModalProgressDialog({title = 'Restoring virtual copys ...', functionContext = context, } )
		local captionTail = " (total: " .. total ..")"
		
		--Switch to develop view
		LrApplicationView.switchToModule('develop')

		for i,photo in ipairs(photos) do
			
			if progressScope:isCanceled() then
				break
			end 
			progressScope:setPortionComplete(i, total)
			progressScope:setCaption("Restoring #" .. i .. captionTail)
			LrTasks.yield()

			--for each photo, refine selection to just itself.
			catalog:setSelectedPhotos(photo, {})

			-- get all snapshots
			local snapshot_list = photo:getDevelopSnapshots()
			-- log(table_to_string(snapshot_list))
			-- count all snapshots begin with Copy
			local num_of_copys = 0
			for i, t in pairs(snapshot_list) do
				-- if snapshots have name Copy
				if t['name']:find('Copy', 1, 4) then
					-- num_of_copys = num_of_copys + 1
					
					--create virtual copies
					local new_copies = catalog:createVirtualCopies( t['name'] )
					
					for ii,photoo in ipairs(new_copies) do 
						LrTasks.yield()
						photoo:applyDevelopSnapshot(t['snapshotID'])
						photoo = {}
					end
					-- LrDialogs.message("Hello World")
				end
			end



			


		end
		LrApplicationView.switchToModule('library')
		LrDialogs.message("Finished")
	end)

  end)

