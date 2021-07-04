--
-- An FRSKY S.Port <passthrough protocol> based Telemetry script for the Horus X10 and X12 radios
--
-- Copyright (C) 2018-2021. Alessandro Apostoli
-- https://github.com/yaapu
--
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY, without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program; if not, see <http://www.gnu.org/licenses>.
--

---------------------
-- MAIN CONFIG
-- 480x272 LCD_W x LCD_H
---------------------

---------------------
-- VERSION
---------------------
-- load and compile of lua files
-- uncomment to force compile of all chunks, comment for release
--#define COMPILE
-- fix for issue OpenTX 2.2.1 on X10/X10S - https://github.com/opentx/opentx/issues/5764

---------------------
-- FEATURE CONFIG
---------------------
-- enable splash screen for no telemetry data
--#define SPLASH
-- enable battery percentage based on voltage
-- enable code to draw a compass rose vs a compass ribbon
--#define COMPASS_ROSE

---------------------
-- DEV FEATURE CONFIG
---------------------
-- enable memory debuging 
--#define MEMDEBUG
-- enable dev code
--#define DEV
-- uncomment haversine calculation routine
--#define HAVERSINE
-- enable telemetry logging to file (experimental)
--#define LOGTELEMETRY
-- use radio channels imputs to generate fake telemetry data
--#define TESTMODE
-- enable debug of generated hash or short hash string
--#define HASHDEBUG
-- enable MESSAGES DEBUG
--#define DEBUG_MESSAGES
--#define DEBUG_FENCE
--#define DEBUG_TERRAIN
--#define DEBUG_WIND
--#define DEBUG_AIRSPEED

---------------------
-- DEBUG REFRESH RATES
---------------------
-- calc and show hud refresh rate
--#define HUDRATE
-- calc and show telemetry process rate
-- #define BGTELERATE

---------------------
-- SENSOR IDS
---------------------
















-- Throttle and RC use RPM sensor IDs


---------------------
-- BATTERY DEFAULTS
---------------------
---------------------------------
-- BACKLIGHT SUPPORT
-- GV is zero based, GV 8 = GV 9 in OpenTX
---------------------------------
---------------------------------
-- CONF REFRESH GV
---------------------------------

--
--
--

--

----------------------
-- COMMON LAYOUT
----------------------
-- enable vertical bars HUD drawing (same as taranis)
--#define HUD_ALGO1
-- enable optimized hor bars HUD drawing
--#define HUD_ALGO2
-- enable hor bars HUD drawing, 2 px resolution
-- enable hor bars HUD drawing, 1 px resolution
--#define HUD_ALGO4






--------------------------------------------------------------------------------
-- MENU VALUE,COMBO
--------------------------------------------------------------------------------

--------------------------
-- UNIT OF MEASURE
--------------------------
local unitScale = getGeneralSettings().imperial == 0 and 1 or 3.28084
local unitLabel = getGeneralSettings().imperial == 0 and "m" or "ft"
local unitLongScale = getGeneralSettings().imperial == 0 and 1/1000 or 1/1609.34
local unitLongLabel = getGeneralSettings().imperial == 0 and "km" or "mi"



-----------------------
-- BATTERY 
-----------------------
-- offsets are: 1 celm, 4 batt, 7 curr, 10 mah, 13 cap, indexing starts at 1
-- 


----------------------
--- COLORS
----------------------

--#define COLOR_LABEL 0x7BCF
--#define COLOR_BG 0x0169
--#define COLOR_BARSEX 0x10A3


--#define COLOR_SENSORS 0x0169

-----------------------------------
-- STATE TRANSITION ENGINE SUPPORT
-----------------------------------


--------------------------
-- CLIPPING ALGO DEFINES
--------------------------

-----------------------------
-- LEFT RIGHT telemetry
-----------------------------


---------------------------------
-- LAYOUT
---------------------------------






-- x:300 y:135 inside HUD











local customSensorXY = {
  { 80, 193, 80, 203},
  { 160, 193, 160, 203},
  { 240, 193, 240, 203},
  { 320, 193, 320, 203},
  { 400, 193, 400, 203},
  { 480, 193, 480, 203},
}

local function draw(myWidget,drawLib,conf,telemetry,status,battery,alarms,frame,utils,customSensors,leftPanel,centerPanel,rightPanel)
  lcd.setColor(CUSTOM_COLOR,0xFFFF)
  centerPanel.drawHud(myWidget,drawLib,conf,telemetry,status,battery,utils)
  lcd.setColor(CUSTOM_COLOR,0xFFFF)
  drawLib.drawRArrow(240,174,20,math.floor(telemetry.homeAngle - telemetry.yaw),CUSTOM_COLOR)--HomeDirection(telemetry)
  -- with dual battery default is to show aggregate view
  if status.batt2sources.fc or status.batt2sources.vs then
    if status.showDualBattery == false then
      -- dual battery: aggregate view
      rightPanel.drawPane(380,drawLib,conf,telemetry,status,alarms,battery,0,utils)
      -- left pane info
      leftPanel.drawPane(0,drawLib,conf,telemetry,status,alarms,battery,0,utils)
    else
      -- dual battery:battery 1 right pane
      rightPanel.drawPane(380,drawLib,conf,telemetry,status,alarms,battery,1,utils)
      -- dual battery:battery 2 left pane
      rightPanel.drawPane(0,drawLib,conf,telemetry,status,alarms,battery,2,utils)
    end
  else
    -- battery 1 right pane in single battery mode
    rightPanel.drawPane(380,drawLib,conf,telemetry,status,alarms,battery,1,utils)
    -- left pane info  in single battery mode
    leftPanel.drawPane(0,drawLib,conf,telemetry,status,alarms,battery,0,utils)
  end
  utils.drawTopBar()
  local msgRows = 4
  if customSensors ~= nil then
    msgRows = 1
    -- draw custom sensors
    drawLib.drawCustomSensors(0,customSensors,customSensorXY,utils,status,0x8C71)
  end
  drawLib.drawStatusBar(msgRows,conf,telemetry,status,battery,alarms,frame,utils)
  drawLib.drawFailsafe(telemetry,utils)
  drawLib.drawArmStatus(status,telemetry,utils)
  local nextX = drawLib.drawTerrainStatus(utils,status,telemetry,101,19)
  drawLib.drawFenceStatus(utils,status,telemetry,nextX,19)
  
  lcd.setColor(CUSTOM_COLOR,0xFFFF)
end

return {draw=draw}

