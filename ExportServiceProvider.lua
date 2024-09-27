--[[----------------------------------------------------------------------------

ExportServiceProvider.lua
Export service provider description for Lightroom Mylio uploader

------------------------------------------------------------------------------]]

-- Lightroom SDK
local LrBinding = import 'LrBinding'
local LrDialogs = import 'LrDialogs'
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrView = import 'LrView'
local LrLogger = import 'LrLogger'
local LrTasks = import 'LrTasks'

-- Common shortcuts
local bind = LrView.bind
local share = LrView.share

-- Mylio plugin object
local mylioPlugin = {}

-- Mylio logger
local mylioLogger = LrLogger( 'libraryLogger' )
mylioLogger:enable( 'print' )

--------------------------------------------------------------------------------
--
-- plugin properties
--
mylioPlugin.supportsIncrementalPublish = 'only'

mylioPlugin.hideSections = { 'exportLocation', 'fileNaming', 'fileSettings', 'imageSettings', 'outputSharpening', 'metadata', 'watermarking', 'video' }

mylioPlugin.allowFileFormats = { 'JPEG' }

mylioPlugin.allowColorSpaces = { 'sRGB' }

mylioPlugin.canExportVideo = false -- video is not supported through the Mylio plug-in

mylioPlugin.small_icon = 'small.png'

mylioPlugin.publish_fallbackNameBinding = 'fullname'

mylioPlugin.titleForPublishedCollection = LOC "$$$/Mylio/TitleForPublishedCollection=Photoset"

mylioPlugin.titleForPublishedCollection_standalone = LOC "$$$/Mylio/TitleForPublishedCollection/Standalone=Photoset"

mylioPlugin.titleForPublishedSmartCollection = LOC "$$$/Mylio/TitleForPublishedSmartCollection=Smart Photoset"

mylioPlugin.titleForPublishedSmartCollection_standalone = LOC "$$$/Mylio/TitleForPublishedSmartCollection/Standalone=Smart Photoset"

mylioPlugin.titleForGoToPublishedCollection = "disable" --LOC "$$$/Mylio/TitleForGoToPublishedCollection=Show in Mylio"

mylioPlugin.titleForGoToPublishedPhoto = "disable" --LOC "$$$/Mylio/TitleForGoToPublishedCollection=Show in Mylio"

mylioPlugin.supportsCustomSortOrder = true


--------------------------------------------------------------------------------
--
-- plugin functions
--
function mylioPlugin.updateExportSettings( exportSettings )
    exportSettings.LR_format = 'JPEG'
    exportSettings.LR_jpeg_quality = 1
    exportSettings.LR_embeddedMetadataOption = 'all'
    exportSettings.LR_removeFaceMetadata = false
    exportSettings.LR_removeLocationMetadata = false
end

function mylioPlugin.getCollectionBehaviorInfo( publishSettings )
    return {
        defaultCollectionName = LOC "$$$/Mylio/DefaultCollectionName/Photostream=Photostream",
        defaultCollectionCanBeDeleted = true,
        canAddCollection = true,
        maxCollectionSetDepth = 0,
            -- Collection sets are not supported through the Mylio plug-in.
    }
end

function mylioPlugin.deletePhotosFromPublishedCollection( publishSettings, arrayOfPhotoIds, deletedCallback )
    for i, photoId in ipairs( arrayOfPhotoIds ) do
        deletedCallback( photoId )
    end
end

function mylioPlugin.metadataThatTriggersRepublish( publishSettings )
    return {
        default = false,
        title = true,
        caption = true,
        keywords = true,
        gps = true,
        dateCreated = true
    }
end

function mylioPlugin.shouldReverseSequenceForPublishedCollection( publishSettings, collectionInfo )
    return false
end

function mylioPlugin.processRenderedPhotos( functionContext, exportContext )
    local exportSession = exportContext.exportSession
    -- Make a local reference to the export parameters.
    local exportSettings = assert( exportContext.propertyTable )
    -- Get the # of photos.
    local nPhotos = exportSession:countRenditions()
    -- Set progress title.
    local progressScope = exportContext:configureProgress {
        title = nPhotos > 1
        and LOC( "$$$/Mylio/Publish/Progress=Publishing ^1 photos to Mylio", nPhotos )
        or LOC "$$$/Mylio/Publish/Progress/One=Publishing one photo to Mylio",
    }

    -- Iterate through photo renditions.
    for i, rendition in exportContext:renditions { stopIfCanceled = true } do
        -- Update progress scope.
        progressScope:setPortionComplete( ( i - 1 ) / nPhotos )
        -- Get next photo.
        local photo = rendition.photo
        -- See if we previously uploaded this photo.
        if (not rendition.wasSkipped) then
        
            local success, pathOrMessage = rendition:waitForRender()
            local catalog = import "LrApplication".activeCatalog()



            -- Update progress scope again once we've got rendered photo.
            progressScope:setPortionComplete( ( i - 0.5 ) / nPhotos )

            -- Check for cancellation again after photo has been rendered.
            if progressScope:isCanceled() then break end

            -- when render was successful, copy into correct destination location
            if success then

                -- Set a color for  exported JPEG
         
               


                local LrDialogs = import 'LrDialogs'

                local parameters = "-XMP:Label=purple"
                local cmd = ''

                if WIN_ENV then
                    cmd = '"' .. LrPathUtils.child( _PLUGIN.path, "exiftool.exe") .. '" ' .. parameters
                    cmd = cmd .. ' "' .. pathOrMessage .. '"'
                    cmd = '"' .. cmd .. '"'
                else
                    cmd = "'" .. LrPathUtils.child( _PLUGIN.path, "exiftool") .. "' " .. parameters
                    cmd = cmd .. " '" .. pathOrMessage .. "'"
                end
                    
                mess = LrTasks.execute(cmd)
                

                


                

                local originalPath = photo:getRawMetadata('path')
                local destName = mylioPlugin.getFilenameWithoutExtension(originalPath)
                local destNamePostfix = "_non"            
                local destExtension = mylioPlugin.getFilenameExtension(pathOrMessage)
                
                -- see if it is master file or a copy
                local copy_name = photo:getFormattedMetadata('copyName')
                
                if copy_name then
                    -- if is a copy then rename to -Copy 1 ...
                    -- also create a snapshot for this copy
                    destNamePostfix = '-' .. copy_name
                    catalog:withWriteAccessDo('create snapshot', function() photo:createDevelopSnapshot(copy_name, true) end)
                else 
                    destNamePostfix = '_display'
                end

                local destinationPath = destName .. destNamePostfix .. destExtension

                -- move rendered image to destination
                mylioPlugin.trace('orig path: ' .. originalPath)
                mylioPlugin.trace('dest path: ' .. destinationPath)



                local moveResult, moveFailureReason = LrFileUtils.move(pathOrMessage, destinationPath)


                if (not moveResult) then
                    -- file might already exist, try again
                    LrFileUtils.delete(destinationPath)
                    moveResult, moveFailureReason = LrFileUtils.move(pathOrMessage, destinationPath)
                end
                
                -- inform Lr that publish was a success, or if something failed
                if (moveResult) then
                    rendition:recordPublishedPhotoId(destinationPath)
                else
                    LrDialogs.message(moveResult)
                    LrDialogs.message(moveFailureReason)
                    mylioPlugin.trace('move from ' .. pathOrMessage .. ' to ' .. destinationPath .. ' failed: ' .. moveFailureReason)
                end
            end
        end
    end

    progressScope:done()
end

--------------------------------------------------------------------------------
--
-- helpers
--
function mylioPlugin.getIndexToFilenameExtension( filename )
    local reverseFilename = string.reverse(filename)
    local extBegin, extEnd = string.find(reverseFilename, "%.")
    return string.len(filename) - extBegin + 1
end

function mylioPlugin.getFilenameWithoutExtension( filename )
    local index = mylioPlugin.getIndexToFilenameExtension(filename)
    return string.sub(filename, 1, index-1)
end

function mylioPlugin.getFilenameExtension( filename )
    local index = mylioPlugin.getIndexToFilenameExtension(filename)
    return string.sub(filename, index)
end

function mylioPlugin.trace( obj )
--    if (obj ~= nil) then
--        local objString = tostring(obj)
--        if (objString ~= nil) then
--            mylioLogger:trace( ' MYLIO: ' .. tostring(objString) )
--        end
--    end
end

--------------------------------------------------------------------------------
-- returns our plugin object
return mylioPlugin;
