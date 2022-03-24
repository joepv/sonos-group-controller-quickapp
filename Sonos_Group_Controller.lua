----------------------------------------------------------------------------------
-- Sonos Group Controller
-- Version 1.2 (March 2022)
-- Copyright (c)2022 Joep Verhaeg <info@joepverhaeg.nl> 

-- Full documentation you can find at:
-- https://docs.joepverhaeg.nl/sonos-group-controller
----------------------------------------------------------------------------------
-- THANK YOU NOTE:
-- I used the Sonos Player v0.1 from tinman/Intuitech as a base to start. Special 
-- thanks to him.

-- DESCRIPTION:
-- This Quick App is created to be used in Lua scenes and other Quick Apps. It has
-- a minimal user interface that WILL NOT BE AUTOMATICALLY updated. Although there
-- is a refresh button. It is designed this way to keep it low profile on your
-- home network.

-- On Init the Quick App retrieves the first 4 Sonos favorites and adds
-- them to the buttons. At every command the volume status is updated. There is no
-- polling for status changes. Press the refresh button for this. Again it is 
-- designed this way.

-- SETUP:
-- Set the IPv4 QUICK APP VARIABLE to the IP address of the Sonos Player you want
-- to control. 

-- QUICKSTART:
-- Lua : fibaro.call(qaId, "savePlayStateAndPause")
-- Desc: Save the current player state and pause the player.

-- Lua : fibaro.call(qaId, "setPreviousPlayerState")
-- Desc: Retrieve the previous saved player state and set the play state to this.

-- Lua : fibaro.call(qaId, "playFavorite", "title", "15")
-- Desc: Play a Sonos favorite at the specified volume by using the name from the 
--      favorites list

-- Lua : fibaro.call(qaId, "AddToGroup", "playerUuid")
-- Desc: Add Sonos player to a group by using the Uuid of the group master.

-- Lua : fibaro.call(qaId, "LeaveGroup")
-- Desc: Remove the Sonos player from a group.

-- Lua : fibaro.call(qaId, "playFromUri", "uri", "meta")
-- Desc: Play an mp3, InTune or other audio format from an Uri.

-- Lua : fibaro.call(qaId, "setVolume", "15")
-- Desc: Set the Sonos Player volume.

escapeCache = {}
local function xmlEscape(s)
    local r = escapeCache[s]
    if not r then
        local g = string.gsub
        r = g(s, "&", "&amp;")
        r = g(r, '"', "&quot;")
        r = g(r, "'", "&apos;")
        r = g(r, "<", "&lt;")
        r = g(r, ">", "&gt;")
        escapeCache[s] = r
    end
    return r
end

function QuickApp:onInit()
    self:debug("onInit")
    self.ipaddr = self:getVariable("IPv4")
    self.port = 1400
    self.mute = false
    self:updateProperty("mute", false)
    self:updateProperty("power", true)
    --self:updateView("volslider", "value", "5")
    self.FAV = {}
    self.AVTRANSPORT_URI = "/MediaRenderer/AVTransport/Control"
    self.RENDERING_CONTROL_URI = "/MediaRenderer/RenderingControl/Control"
    self.http = net.HTTPClient({ timeout = 5000 })
    
    if (self.ipaddr ~= "none") then
        self:getZoneInfo()
        self:getFavorites()
        self:getVolume()
    else
        self:debug("Please set the IPv4 Quick App variable to the IP address of the Sonos Player!")
    end
end

function QuickApp:savePlayStateAndPause()
    local GET_TRANSPORT_INFO_ACTION = '"urn:schemas-upnp-org:service:AVTransport:1#GetTransportInfo"'
    local GET_TRANSPORT_INFO_BODY = '<u:GetTransportInfo xmlns:u="urn:schemas-upnp-org:service:AVTransport:1"><InstanceID>0</InstanceID></u:GetTransportInfo>'
    self:sendRequest(self.AVTRANSPORT_URI, GET_TRANSPORT_INFO_ACTION, GET_TRANSPORT_INFO_BODY,
        function(data)
            --self:debug(data.data)
            local xmlData = xmlParser.parseXml(data.data)
            local state = xmlParser.getXmlPath(xmlData, "s:Envelope", "s:Body", "u:GetTransportInfoResponse", "CurrentTransportState")[1][1].text
            self:updateProperty("state", state)
            --self:debug(state)
            self:pause()
        end,
        function(data)
            self:debug("DEVICE IS OFFLINE - ERROR READING STATE")
            self:updateProperty("state", "OFFLINE")
            --self:pause()
        end)
end

function QuickApp:setPreviousPlayerState()
    self:debug(self.id)
    local state = fibaro.getValue(self.id, "state")
    self:debug(state)
    if (state == "PLAYING") then
        self:play()
    end
end

function QuickApp:getFavorites()
    local ZONE_CONTROL_URI = "/MediaServer/ContentDirectory/Control"
    local SOAP_ACTION = "urn:schemas-upnp-org:service:ContentDirectory:1#Browse"
    local BODY = "<u:Browse xmlns:u=\"urn:schemas-upnp-org:service:ContentDirectory:1\"><ObjectID>FV:2</ObjectID><BrowseFlag>BrowseDirectChildren</BrowseFlag><Filter>*</Filter><StartingIndex>0</StartingIndex><RequestedCount></RequestedCount><SortCriteria>+r:ordinal</SortCriteria></u:Browse>"
    self:sendRequest(ZONE_CONTROL_URI, SOAP_ACTION, BODY, 
    function(data)
        --self:debug(data.data)
        local xmlData = xmlParser.parseXml(data.data)
        local browseResponse = xmlParser.getXmlPath(xmlData, "s:Envelope", "s:Body", "u:BrowseResponse", "Result")[1][1].text
        local xmlBrowseResponse = xmlParser.parseXml(browseResponse)
        local favoriteItems = xmlParser.getXmlPath(xmlBrowseResponse, "DIDL-Lite")
        -- check if table is empty
        if (favoriteItems[1][1] ~= nil) then
            local i = 1
            repeat
                local title = xmlParser.getXmlPath(favoriteItems[1][i], "item", "dc:title")[1][1].text
                local resPath = xmlParser.getXmlPath(favoriteItems[1][i], "item", "res")[1][1].text or ""
                local res = xmlEscape(resPath)
                local resmd = xmlEscape(xmlParser.getXmlPath(favoriteItems[1][i], "item", "r:resMD")[1][1].text)
                --self:debug(i,title,res,resmd) 
                self.FAV[i] = {title=title,source=res,metadata=resmd}
                i = i+1
            until (favoriteItems[1][i] == nill)
            for k=1, i-1 do
                self:updateView("btn_fav" .. k, "text", self.FAV[k]['title'])
                self:debug(self.FAV[k]['title'])
                if k == 4 then break end
            end
        end
    end,
    function(data) self:debug("ERROR"); self:debug(data) end)
end

function QuickApp:playFavorite(title, volume)
    local source, meta
    for k,v in pairs(self.FAV) do
        if v['title'] == title then
            source = v['source']
            meta   = v['metadata']
            break
        end
    end
    if (source) then
        self:setVolume(tonumber(volume))
        self:playFromUri(source, meta)
    else
        self:debug("ERROR: Favorite with title " .. title .. " not found!")
    end
end

function QuickApp:getZoneInfo()
  local ZONE_CONTROL_URI = "/ZoneGroupTopology/Control"
  local SOAP_ACTION = "urn:schemas-upnp-org:service:ZoneGroupTopology:1#GetZoneGroupState"
  local BODY = "<u:GetZoneGroupState xmlns:u=\"urn:schemas-upnp-org:service:ZoneGroupTopology:1\"></u:GetZoneGroupState>"
  self:sendRequest(ZONE_CONTROL_URI, SOAP_ACTION, BODY, 
        function(data) 
          --self:debug(data.data)
          local xmlData = xmlParser.parseXml(data.data)
          local zoneGroupState = xmlParser.getXmlPath(xmlData, "s:Envelope", "s:Body", "u:GetZoneGroupStateResponse", "ZoneGroupState")[1][1].text
          local xmlZoneGroupState = xmlParser.parseXml(zoneGroupState)
          local zoneGroupMembers = xmlParser.getXmlPath(xmlZoneGroupState, "ZoneGroupState", "ZoneGroups", "ZoneGroup", "ZoneGroupMember")
          for k,v in pairs(zoneGroupMembers) do
            local zonename = v['attribute']['ZoneName']
            local uuid     = v['attribute']['UUID']
            local ip       = v['attribute']['Location']:match("(%d+%.%d+%.%d+%.%d+)")
            local location = v['attribute']['Location']
            if (ip == self.ipaddr) then
                self:updateProperty("manufacturer", "Sonos")
                self:updateProperty("model", uuid) 
                self:updateView("lbl_System", "text", "Systeem: " .. zonename)
            end
          end
        end, 
        function(data) self:debug("ERROR"); self:debug(data) end
  )
end

function QuickApp:refresh()
    self:getFavorites()
    self:getVolume()
end

function QuickApp:SetFavorite1()
    if (self.FAV[1] ~= nill) then
        self:playFromUri(self.FAV[1]['source'], self.FAV[1]['metadata'])
        self:getVolume()
    end
end

function QuickApp:SetFavorite2()
    if (self.FAV[2] ~= nill) then
        self:playFromUri(self.FAV[2]['source'], self.FAV[2]['metadata'])
        self:getVolume()
    end
end

function QuickApp:SetFavorite3()
    if (self.FAV[3] ~= nill) then
        self:playFromUri(self.FAV[3]['source'], self.FAV[3]['metadata'])
        self:getVolume()
    end
end

function QuickApp:SetFavorite4()
    if (self.FAV[4] ~= nill) then
        self:playFromUri(self.FAV[4]['source'], self.FAV[4]['metadata'])
        self:getVolume()
    end
end

function QuickApp:AddToGroup(playerUuid)
  local GROUPMANAGEMENT_CONTROL_URI = "/GroupManagement/Control"
  local SOAP_ACTION = "urn:schemas-upnp-org:service:GroupManagement:1#AddMember"
  local BODY = "<u:AddMember xmlns:u=\"urn:schemas-upnp-org:service:GroupManagement:1\"><MemberID>" .. playerUuid .."</MemberID></u:AddMember>"
  self:sendRequest(GROUPMANAGEMENT_CONTROL_URI, SOAP_ACTION, BODY, 
        function(data) self:debug(data.data) end, 
        function(data) self:debug("ERROR"); self:debug(data) end
  )
end

function QuickApp:LeaveGroup()
    local AVTRANSPORT_CONTROL_URI = "/MediaRenderer/AVTransport/Control"
    local SOAP_ACTION = "urn:schemas-upnp-org:service:AVTransport:1#BecomeCoordinatorOfStandaloneGroup"
    local BODY = "<u:BecomeCoordinatorOfStandaloneGroup xmlns:u=\"urn:schemas-upnp-org:service:AVTransport:1\"><InstanceID>0</InstanceID></u:BecomeCoordinatorOfStandaloneGroup>"
    self:sendRequest(AVTRANSPORT_CONTROL_URI, SOAP_ACTION, BODY, 
        function(data) self:debug(data.data) end, 
        function(data) self:debug("ERROR"); self:debug(data) end
    )
end

function QuickApp:RemoveMember(playerUuid)
  local GROUPMANAGEMENT_CONTROL_URI = "/GroupManagement/Control"
  local SOAP_ACTION = "urn:schemas-upnp-org:service:GroupManagement:1#RemoveMember"
  local BODY = "<u:RemoveMember xmlns:u=\"urn:schemas-upnp-org:service:GroupManagement:1\"><MemberID>" .. playerUuid .."</MemberID></u:RemoveMember>"
  self:sendRequest(GROUPMANAGEMENT_CONTROL_URI, SOAP_ACTION, BODY, 
        function(data) self:debug(data.data) end, 
        function(data) self:debug("ERROR"); self:debug(data) end
  )
end

function QuickApp:getCurTrackInfo(data)
    local ok = pcall(function()
    local xmlData = xmlParser.parseXml(data)
    local trackData = xmlParser.getXmlPath(xmlData, "s:Envelope", "s:Body", "u:GetPositionInfoResponse", "TrackURI")[1][1].text
            local function formatURI(uri)
                if (uri ~= nil) then
                    if (string.find(uri, "http://", 1)) then
            uri =  string.gsub(uri, "http:/*", "")
                    end
                    if (string.find(uri,"x%-file%-cifs://", 1)) then
                        uri =  string.gsub(uri, "x%-file%-cifs:/*", "")
                    end
                    if (string.find(uri, 'x%-rincon%-mp3radio://', 1)) then
            uri =  string.gsub(uri, "x%-rincon%-mp3radio:/*", "")
                    end
                else
                uri = "empty"
                end
                return uri
            end
            self:updateProperty("currentSourceURI", formatURI(trackData))
            self:setVariable("currentSourceURI", formatURI(trackData))
end)
if (not ok) then
self:debug('xml parse error')
end
end

function QuickApp:getCurrentSourceURI()
    local GET_CUR_TRACK_ACTION = "urn:schemas-upnp-org:service:AVTransport:1#GetPositionInfo"
    local GET_CUR_TRACK_BODY = "<u:GetPositionInfo xmlns:u=\"urn:schemas-upnp-org:service:AVTransport:1\"><InstanceID>0</InstanceID><Channel>Master</Channel></u:GetPositionInfo>"
    self:sendRequest(self.AVTRANSPORT_URI, GET_CUR_TRACK_ACTION, GET_CUR_TRACK_BODY, 
        function(data) self:getCurTrackInfo(data.data) end, 
        function(data) self:debug("ERROR"); self:debug(data) end
    )
end

function QuickApp:GetMediaInfo()
    local GET_CUR_TRACK_ACTION = "urn:schemas-upnp-org:service:AVTransport:1#GetMediaInfo"
    local GET_CUR_TRACK_BODY = "<u:GetMediaInfo xmlns:u=\"urn:schemas-upnp-org:service:AVTransport:1\"><InstanceID>0</InstanceID><Channel>Master</Channel></u:GetMediaInfo>"
    self:sendRequest(self.AVTRANSPORT_URI, GET_CUR_TRACK_ACTION, GET_CUR_TRACK_BODY, 
        function(data) self:debug(data.data) end
    )
end

function QuickApp:getTransportInfo(callback, errorCallback)
    local GET_TRANSPORT_INFO_ACTION = '"urn:schemas-upnp-org:service:AVTransport:1#GetTransportInfo"'
    local GET_TRANSPORT_INFO_BODY = '<u:GetTransportInfo xmlns:u="urn:schemas-upnp-org:service:AVTransport:1"><InstanceID>0</InstanceID></u:GetTransportInfo>'
local success = function(data)
        local ok = pcall(function()
    local xmlData = xmlParser.parseXml(data.data)
    local state = xmlParser.getXmlPath(xmlData, "s:Envelope", "s:Body", "u:GetTransportInfoResponse", "CurrentTransportState")[1][1].text
            callback(state)
end)
if (not ok) then
self:debug('xml parse error')
end
end
self:sendRequest(self.AVTRANSPORT_URI, GET_TRANSPORT_INFO_ACTION, GET_TRANSPORT_INFO_BODY, success, errorCallback)
end

function QuickApp:playFromUri(uri, meta)
    local SET_TRANSPORT_ACTION = '"urn:schemas-upnp-org:service:AVTransport:1#SetAVTransportURI"'
    local PLAY_URI_BODY_TEMPLATE = '<u:SetAVTransportURI xmlns:u="urn:schemas-upnp-org:service:AVTransport:1"><InstanceID>0</InstanceID><CurrentURI>' ..uri.. '</CurrentURI><CurrentURIMetaData>' .. meta .. '</CurrentURIMetaData></u:SetAVTransportURI>'
self:sendRequest(self.AVTRANSPORT_URI, SET_TRANSPORT_ACTION, PLAY_URI_BODY_TEMPLATE, 
function(data)
            self:play()
        end
    )
end

function QuickApp:playFromCIFS(uri)
    local muri = 'x-file-cifs://' .. uri
    local PLAY_URI_BODY_TEMPLATE = '<u:SetAVTransportURI xmlns:u="urn:schemas-upnp-org:service:AVTransport:1"><InstanceID>0</InstanceID><CurrentURI>'..muri..'</CurrentURI><CurrentURIMetaData></CurrentURIMetaData></u:SetAVTransportURI>'
local SET_TRANSPORT_ACTION = '"urn:schemas-upnp-org:service:AVTransport:1#SetAVTransportURI"'
self:sendRequest(self.AVTRANSPORT_URI, SET_TRANSPORT_ACTION, PLAY_URI_BODY_TEMPLATE, 
function(data)
            self:play()
        end
    )
end

function QuickApp:play()
    local PLAY_ACTION = '"urn:schemas-upnp-org:service:AVTransport:1#Play"'
    local PLAY_BODY = '<u:Play xmlns:u="urn:schemas-upnp-org:service:AVTransport:1"><InstanceID>0</InstanceID><Speed>1</Speed></u:Play>'
    self:sendRequest(self.AVTRANSPORT_URI, PLAY_ACTION, PLAY_BODY)
    self:getVolume()
end

function QuickApp:pause()
    local PAUSE_ACTION = '"urn:schemas-upnp-org:service:AVTransport:1#Pause"'
    local PAUSE_BODY = '<u:Pause xmlns:u="urn:schemas-upnp-org:service:AVTransport:1"><InstanceID>0</InstanceID><Speed>1</Speed></u:Pause>'
    self:sendRequest(self.AVTRANSPORT_URI, PAUSE_ACTION, PAUSE_BODY)
    self:getVolume()
end

function QuickApp:stop()
    local STOP_ACTION = '"urn:schemas-upnp-org:service:AVTransport:1#Stop"'
    local STOP_BODY = '<u:Stop xmlns:u="urn:schemas-upnp-org:service:AVTransport:1"><InstanceID>0</InstanceID><Speed>1</Speed></u:Stop>'
    self:sendRequest(self.AVTRANSPORT_URI, STOP_ACTION, STOP_BODY)
    self:getVolume()
end

function QuickApp:next()
    local NEXT_ACTION = '"urn:schemas-upnp-org:service:AVTransport:1#Next"'
    local NEXT_BODY = '<u:Next xmlns:u="urn:schemas-upnp-org:service:AVTransport:1"><InstanceID>0</InstanceID><Speed>1</Speed></u:Next>'
    self:sendRequest(self.AVTRANSPORT_URI, NEXT_ACTION, NEXT_BODY)
    self:getVolume()
end

function QuickApp:prev()
    local PREV_ACTION = '"urn:schemas-upnp-org:service:AVTransport:1#Previous"'
    local PREV_BODY = '<u:Previous xmlns:u="urn:schemas-upnp-org:service:AVTransport:1"><InstanceID>0</InstanceID><Speed>1</Speed></u:Previous>'
    self:sendRequest(self.AVTRANSPORT_URI, PREV_ACTION, PREV_BODY)
    self:getVolume()
end

function QuickApp:setVolume(volume)
    local SET_VOLUME_ACTION = '"urn:schemas-upnp-org:service:RenderingControl:1#SetVolume"'
    local SET_VOLUME_BODY_TEMPLATE = '<u:SetVolume xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1"><InstanceID>0</InstanceID><Channel>Master</Channel><DesiredVolume>'..tostring(volume)..'</DesiredVolume></u:SetVolume>'
self:sendRequest(self.RENDERING_CONTROL_URI, SET_VOLUME_ACTION, SET_VOLUME_BODY_TEMPLATE)
    self:updateProperty("volume", volume)
end

function QuickApp:getVolume()
    local success = function(data)
        local ok = pcall(function()
            local xmlData = xmlParser.parseXml(data.data)
            local volume = xmlParser.getXmlPath(xmlData, "s:Envelope", "s:Body", "u:GetVolumeResponse", "CurrentVolume")[1][1].text
                self:updateProperty("volume", tonumber(volume))
                self:updateView("slider", "value", tonumber(volume))
        end)
        if (not ok) then
            self:debug('xml parse error')
        end
    end
    local GET_VOLUME_ACTION = '"urn:schemas-upnp-org:service:RenderingControl:1#GetVolume"'
    local GET_VOLUME_BODY = '<u:GetVolume xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1"><InstanceID>0</InstanceID><Channel>Master</Channel></u:GetVolume>'
    self:sendRequest(self.RENDERING_CONTROL_URI, GET_VOLUME_ACTION, GET_VOLUME_BODY, success)
end

function QuickApp:setMute(mute)
    local m = mute
    if type(m)=='boolean' then m = m and 1 or 0 end
    local SET_MUTE_ACTION = '"urn:schemas-upnp-org:service:RenderingControl:1#SetMute"'
    local SET_MUTE_BODY_TEMPLATE = '<u:SetMute xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1"><InstanceID>0</InstanceID><Channel>Master</Channel><DesiredMute>'..tonumber(m)..'</DesiredMute></u:SetMute>'
self:sendRequest(self.RENDERING_CONTROL_URI, SET_MUTE_ACTION, SET_MUTE_BODY_TEMPLATE)
    self:updateProperty("mute", mute)
    self.mute = mute
    self:getVolume()
end

function QuickApp:domute() 
    self.mute = fibaro.getValue(plugin.mainDeviceId, "mute")
    self.mute = not self.mute
    self:setMute(self.mute)
    self:getVolume()
end

function QuickApp:sendRequest(uri, action, body, successCallback, errorCallback)
    local ENVELOPE = '<?xml version="1.0" encoding="utf-8"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body>'..body..'</s:Body></s:Envelope>'
    self.http:request('http://' .. self.ipaddr .. ':' .. tostring(self.port) .. uri, {
    options = {
            headers = {
                    ['Content-Type'] = 'text/xml',
                    ['SOAPACTION'] = action
            },
            data = ENVELOPE,
            method = 'POST'
            },
            success = function(response)
                --self:debug(response.status)
                --self:debug(response.data)
                if successCallback ~= nil then successCallback(response) end
            end
            ,
            error = function(message)
                --self:debug("error:", message)
                if errorCallback ~= nil then errorCallback(resmessageponse) end
        end         
    })
end