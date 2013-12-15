module("L_OnkyoReceiver1", package.seeall)

-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.

       

        local ONKYO_HEADER_SIZE = string.char(0, 0, 0, 16)
        local ONKYO_VERSION = string.char(1)
        local ONKYO_RESERVED = string.char(0, 0, 0)
        local ONKYO_CMD_START = "!1"
        local ONKYO_CMD_END = string.char(26)
        local ONKYO_CR = string.char(13)
        local ONKYO_LF = string.char(10)

		local SWP_SID = "urn:upnp-org:serviceId:SwitchPower1"
		local IPS_IID = "urn:micasaverde-com:serviceId:InputSelection1"
		local VOS_VID = "urn:micasaverde-com:serviceId:Volume1"
		local ONK_DID = "urn:onkyo-com:serviceId:Receiver1"

        local MAX_VOLUME = 70
		local ON_DELAY = 4000

        local ipAddress
		local zone
        local ipPort = 4999
        local buffer = ""
        local DEBUG_MODE = false
		local ip2serial = true --prevents sending ISCP commands over IP when using an IP to RS232 convertor

		local childDeviceZone = {}

        local socket = require("socket")


	
	local function findChild(label)
	    return childDeviceZone[label]
	end


	local function getZone1Status()
	    -- Trigger the Onkyo to give up it's Power status
            sendCommand("PWRQSTN")

            -- Trigger the Onkyo to give up it's Master Volume
            sendCommand("MVLQSTN")

            -- Trigger the Onkyo to give up it's Master Input
            sendCommand("SLIQSTN")
		
	    	-- Trigger the Onkyp to give up its Listening Mode
	    	sendCommand("LMDQSTN")

            -- Trigger the Onkyo to give up it's Centre Level
            sendCommand("CTLQSTN")

            -- Trigger the Onkyo to give up it's Subwoofer Status
            sendCommand("SWLQSTN")

            -- Trigger the Onkyo to give up it's Audyssey Status
            sendCommand("ADYQSTN")

            -- Trigger the Onkyo to give up it's Audyssey Dynamic EQ Status
            sendCommand("ADQQSTN")

            -- Trigger the Onkyo to give up it's Audyssey Dynamic Volume Status
            sendCommand("ADVQSTN")

            -- Trigger the Onkyo to give up it's Dolby Volume Status
            sendCommand("DVLQSTN")
	end
	
	local function getZone2Status()
	    -- Trigger the Onkyo to give up it's Z2 Power status
            sendCommand("ZPWQSTN")

            -- Trigger the Onkyo to give up it's Z2 Volume
            sendCommand("ZVLQSTN")

            -- Trigger the Onkyo to give up it's Z2 Input
            sendCommand("SLZQSTN")

	end
	
	local function getZone3Status()
	    -- Trigger the Onkyo to give up it's Z3 Power status
            sendCommand("PW3QSTN")

            -- Trigger the Onkyo to give up it's Z3 Volume
            sendCommand("ZL3QSTN")

            -- Trigger the Onkyo to give up it's Z3 Input
            sendCommand("SL3QSTN")
	end
	
	local function getZone4Status()
	    -- Trigger the Onkyo to give up it's Z4 Power status
            sendCommand("PW4QSTN")

            -- Trigger the Onkyo to give up it's Z4 Volume
            sendCommand("ZL4QSTN")

            -- Trigger the Onkyo to give up it's Z4 Input
            sendCommand("SL4QSTN")
	end

	local function initialiseZone(zone)
		if zone == "Z1" then
			-- Pause to let the receiver wake up
			debug("Waiting " .. ON_DELAY .. "ms before polling status")
			luup.sleep(ON_DELAY)
			getZone1Status()
		elseif zone == "Z2" then
			getZone2Status()
		elseif zone == "Z3" then
			getZone3Status()
		elseif zone == "Z4" then
			getZone4Status()
		end
	end


local function findZone(lul_device)
	    debug("Trying to find zone for device " .. lul_device)
	    local DeviceId = tostring(luup.devices[lul_device].id)
	    local ParentDevice = tostring(luup.devices[lul_device].device_num_parent)
	    debug("DeviceID=" .. DeviceId .. ", Parent="..ParentDevice)
	    if ParentDevice == nil then
	        zone = "Z1"
	    else
	        zone = DeviceId
	    end
	    debug("Zone: " .. zone)
	    return zone
end

local function matchIncomingData(lul_device, cmd, value)
		-- Main Zone Feedback --

                    if (cmd == "PWR") then
                        debug("Power " .. (value or "Not Available"))
			-- Strip the leading zero from power status
			local powerStatus = string.sub(value, 2)	
			luup.variable_set(SWP_SID, "Status", powerStatus, lul_device)

                    elseif (cmd == "MVL") then
                        debug("Master Volume " .. (value or "Not Available"))
                        -- Convert to Decimal, range 0..100
                        value = tonumber(value, 16)
                        luup.variable_set(VOS_VID, "Volume", value, lul_device)

		    elseif (cmd == "AMT") then
			debug("Mute " .. (value or "Not Available"))
                        luup.variable_set(VOS_VID, "Mute", value, lul_device)

                    elseif (cmd == "SLI") then
                        debug("Master Input " .. (value or "Not Available"))
                        luup.variable_set(IPS_IID, "Input", value, lul_device)

		    elseif (cmd == 'LMD') then
			debug("Listening Mode " .. (value or "Not Available"))
			luup.variable_set(ONK_DID, "ListeningMode", value, lul_device)

		    elseif (cmd == 'LTN') then
			debug("Late Night Mode " .. (value or "Not Available"))
			luup.variable_set(ONK_DID, "LTN", value, lul_device)

		    elseif (cmd == 'RAS') then
			debug("ReEQ " .. (value or "Not Available"))
			luup.variable_set(ONK_DID, "ReEq", value, lul_device)

		    elseif (cmd == "CTL") then			
			debug("Centre Level " .. (value or "Not Available"))
			luup.variable_set(ONK_DID, "CentreVolume", value, lul_device)

		    elseif (cmd == "SWL") then			
			debug("Subwoofer Level " .. (value or "Not Available"))
			luup.variable_set(ONK_DID, "SubwooferVolume", value, lul_device)

		    elseif (cmd == "ADY") then			
			debug("Audyssey " .. (value or "Not Available"))
			luup.variable_set(ONK_DID, "Audyssey", value, lul_device)

		    elseif (cmd == "ADQ") then			
			debug("Audyssey Dynamic EQ " .. (value or "Not Available"))
			luup.variable_set(ONK_DID, "AudysseyDynamicEq", value, lul_device)

		    elseif (cmd == "ADV") then			
			debug("Audyssey Dynamic Volume " .. (value or "Not Available"))
			luup.variable_set(ONK_DID, "AudysseyDynamicVolume", value, lul_device)

		    elseif (cmd == "DVL") then			
			debug("Dolby Volume " .. (value or "Not Available"))
			luup.variable_set(ONK_DID, "DolbyVolume", value, lul_device)


		-- Zone 2 --

		    elseif (cmd == "ZPW") then
			debug("Z2 Power " .. (value or "Not Available"))
                        -- Strip the leading zero from power status
			local powerStatus = string.sub(value, 2)	
			luup.variable_set(SWP_SID, "Status", powerStatus, findChild("Z2"))
                        
                    elseif (cmd == "ZVL") then
                        debug("Z2 Volume " .. (value or "Not Available"))
                        -- Convert to Decimal, range 0..100
                        value = tonumber(value, 16)
                        luup.variable_set(VOS_VID, "Volume", value, findChild("Z2"))

		    elseif (cmd == "ZMT") then
			debug("Mute " .. (value or "Not Available"))
                        luup.variable_set(VOS_VID, "Mute", value, findChild("Z2"))

                    elseif (cmd == "SLZ") then
                        debug("Z2 Input " .. (value or "Not Available"))
                        luup.variable_set(IPS_IID, "Input", value, findChild("Z2"))

		-- Zone 3 --

		    elseif (cmd == "PW3") then
			debug("Z3 Power " .. (value or "Not Available"))
			-- Strip the leading zero from power status
			local powerStatus = string.sub(value, 2)			
			luup.variable_set(SWP_SID, "Status", powerStatus,  findChild("Z3"))

                    elseif (cmd == "VL3") then
                        debug("Z3 Volume " .. (value or "Not Available"))
                        -- Convert to Decimal, range 0..100
                        value = tonumber(value, 16)
                        luup.variable_set(VOS_VID, "Volume", value, findChild("Z3"))

		    elseif (cmd == "MT3") then
			debug("Z3 Mute " .. (value or "Not Available"))
                        luup.variable_set(VOS_VID, "Mute", value, findChild("Z3"))

                    elseif (cmd == "SL3") then
                        debug("Z3 Input " .. (value or "Not Available"))
                        luup.variable_set(IPS_IID, "Input", value, findChild("Z3"))

		-- Zone 4 --

		    elseif (cmd == "PW4") then
			debug("Z4 Power " .. (value or "Not Available"))
			-- Strip the leading zero from power status
			local powerStatus = string.sub(value, 2)			
			luup.variable_set(SWP_SID, "Status", powerStatus,  findChild("Z4"))

                    elseif (cmd == "VL4") then
                        debug("Z4 Volume " .. (value or "Not Available"))
                        -- Convert to Decimal, range 0..100
                        value = tonumber(value, 16)
                        luup.variable_set(VOS_VID, "Volume", value, findChild("Z4"))

		    elseif (cmd == "MT4") then
			debug("Z4 Mute " .. (value or "Not Available"))
                        luup.variable_set(VOS_VID, "Mute", value, findChild("Z4"))

                    elseif (cmd == "SL4") then
                        debug("Z4 Input " .. (value or "Not Available"))
                        luup.variable_set(IPS_IID, "Input", value, findChild("Z4"))


                    else
                        debug("Unknown Command, Value " .. cmd .. "," .. (value or "Not Available"))
                    end
end


	--------------------------------------------
	------- Global Functions -------------------
	--------------------------------------------

        function log(text, level)
            luup.log("OnkyoReceiver: " .. text, (level or 1))
        end

        function debug(text)
            if (DEBUG_MODE == true) then
                log("debug: " .. text, 50)
            end
        end


function sendCommand(command)
            local cmd = ONKYO_CMD_START .. command
            local startTime, endTime

	    debug("Sending command" .. command)

            if (ipAddress ~= "") and (ip2serial == false) then
                --
                -- Account for the extra CR/LF characters that Vera adds on.
                -- For now we'll only handle Onkyo commands up to 255 characters in length
                -- just to keep the logic simple.
                --
                local dataSize = string.len(cmd) + 1
                assert(dataSize <= 255)

                cmd = "ISCP" .. ONKYO_HEADER_SIZE
                             .. string.char(0, 0, 0, dataSize)
                             .. ONKYO_VERSION .. ONKYO_RESERVED
                             .. cmd
            end

            startTime = socket.gettime()
            if (luup.io.write(cmd .. string.char(13)) == false) then
                log("Cannot send command " .. command .. " communications error")
                luup.set_failure(true)
                return false
            end
            endTime = socket.gettime()

            debug("ISCP request returned in "
                .. math.floor((endTime - startTime) * 1000) .. "ms")

            return true
        end


	function findChildren(ParentDevice)
	    for k, v in pairs(luup.devices) do
	        if (tostring(v.device_num_parent) == tostring(ParentDevice)) then
			childDeviceZone[v.id]=k
            		log("(findChild) device number: " .. k .. " Zone: " .. v.id)
        	end
    	    end
	end


	function setPower(lul_device, value)
                local originalValue = luup.variable_get(SWP_SID, "Status", lul_device)
		local zone = findZone(lul_device)
		debug("zone for power command is " .. zone )

                if (value == "1") then
                    	-- Power on
                    	luup.variable_set("urn:upnp-org:serviceId:SwitchPower1", "Target", "1", lul_device)
			if (zone == "Z1") then
				sendCommand("PWR01")
	   		elseif (zone == "Z2") then
				sendCommand("ZPW01")
			elseif (zone == "Z3") then
				sendCommand("PW301")
			elseif (zone == "Z4") then
				sendCommand("PW401")
	   		end

			-- Run the initialisation sequence only if zone was not already turned on
			if originalValue == "0" then
				initialiseZone(zone)
			end

                elseif (value == "0") then
                    	-- Power off
                    	luup.variable_set("urn:upnp-org:serviceId:SwitchPower1", "Target", "0", lul_device)
			if (zone == "Z1") then
				sendCommand("PWR00")
	   		elseif (zone == "Z2") then
				sendCommand("ZPW00")
			elseif (zone == "Z3") then
				sendCommand("PW300")
			elseif (zone == "Z4") then
				sendCommand("PW400")
	   		end

                else
                    -- TODO: Error handling
                end
	end

function requestPowerStatus(lul_device)

	local zone = findZone(lul_device)

	if (zone == "Z1") then
		sendCommand("PWRQSTN")
	elseif (zone == "Z2") then
		sendCommand("ZPWQSTN")
	elseif (zone == "Z3") then
		sendCommand("PW3QSTN")
	elseif (zone == "Z4") then
		sendCommand("PW4QSTN") 
	end
end

	function inputSelect(lul_device, value)
		local zone = findZone(lul_device)
		if (zone == "Z1") then
			sendCommand("SLI" .. value)
	    	elseif (zone == "Z2") then
			sendCommand("SLZ" .. value)
	    	end
	end

function setVolume(lul_device, value)

	local zone = findZone(lul_device)

	if (tostring(value) == "Mute") then
		if (zone == "Z1") then
			sendCommand("AMTTG")
	   	elseif (zone == "Z2") then
			sendCommand("ZMTTG")
		elseif (zone == "Z3") then 
			sendCommand("MT3TG")
		elseif (zone == "Z4") then 
			sendCommand("MT4TG")
	   	end

	elseif (tostring(value) == "Down") then

		if (zone == "Z1") then
			sendCommand("MVLDOWN")
	   	elseif (zone == "Z2") then
			sendCommand("ZVLDOWN")
		elseif (zone == "Z3") then 
			sendCommand("VL3DOWN")
		elseif (zone == "Z4") then 
			sendCommand("VL4DOWN")
	   	end

	elseif (tostring(value) == "Up") then

		if (zone == "Z1") then
			sendCommand("MVLUP")
	   	elseif (zone == "Z2") then
			sendCommand("ZVLUP")
		elseif (zone == "Z3") then 
			sendCommand("VL3UP")
		elseif (zone == "Z4") then 
			sendCommand("VL4UP")
	   	end

	else

                if (tonumber(value) > MAX_VOLUME) then
                    value = MAX_VOLUME
                end

                luup.variable_set("urn:onkyo-com:serviceId:Receiver1", "VolumeTarget", value, lul_device)

		if (zone == "Z1") then
			sendCommand(string.format("MVL%02X", value))
   		elseif (zone == "Z2") then
			sendCommand(string.format("ZVL%02X", value))
   		
		end
	end
end


function receiveIncomingData(lul_device, data)

 	if (data == ONKYO_CMD_END) then
                if (ipAddress ~= "") and (ip2serial == false) then
                    buffer = buffer:sub(19)
                    debug("Received Full Buffer from Receiver via Ethernet " .. buffer)
		elseif (ipAddress ~= "") and (ip2serial == true) then
		    buffer = buffer:sub(3)
                    debug("Received Full Buffer from Receiver via IP to Serial " .. buffer)
                else
                    -- TODO: Verify if we need to strip a few prefix characters?
                    buffer = buffer:sub(3)
                    debug("Received Full Buffer from Receiver via Serial " .. buffer)
                end

                -- Process the returning status...
                local cmd, value = buffer:match("^(%u%u%u)(.*)$")
                if (cmd ~= nil) then
			matchIncomingData(lul_device, cmd, value)
                end

                buffer = ""
        elseif (buffer == "" and (data == ONKYO_CR or data == ONKYO_LF)) then
                -- Skip over the trailing CR and LF characters.  Depending upon the model
                -- it may use either CR, or CR-LF, so we cover both cases here
        else
                buffer = buffer .. data
        end

end


function receiverStartup(lul_device)


            	ipAddress = luup.devices[lul_device].ip

	    	findChildren(lul_device)

            	if (ipAddress ~= "") then
            	    log("Running Network Attached I_OnkyoReceiver1.xml on " .. ipAddress)
            	    luup.io.open(lul_device, ipAddress, ipPort)
            	else
            	    log("Running Serial Attached I_OnkyoReceiver1.xml")
            	end 
        end
