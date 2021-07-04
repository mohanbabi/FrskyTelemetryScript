--
-- An FRSKY S.Port <passthrough protocol> based Telemetry script for the Taranis X9D+ and QX7+ radios
--
-- Copyright (C) 2018. Alessandro Apostoli
--   https://github.com/yaapu
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
-- Passthrough protocol reference:
--   https://cdn.rawgit.com/ArduPilot/ardupilot_wiki/33cd0c2c/images/FrSky_Passthrough_protocol.xlsx
--
---------------------
-- GLOBAL DEFINES
---------------------
--#define 
--#define X7
-- always use loadscript() instead of loadfile()
-- force a loadscript() on init() to compile all .lua in .luac
--#define COMPILE
---------------------
-- VERSION
---------------------
---------------------
-- FEATURES
---------------------
-- enable support for custom background functions
--#define CUSTOM_BG_CALL
-- enable battery % by voltage (x9d 2019 only)
--#define BATTPERC_BY_VOLTAGE

---------------------
-- DEBUG
---------------------
-- show button event code on message screen
--#define DEBUGEVT
-- display memory info
--#define MEMDEBUG
-- calc and show background function rate
--#define BGRATE
-- calc and show run function rate
--#define FGRATE
-- calc and show hud refresh rate
--#define HUDRATE
-- calc and show telemetry process rate
--#define BGTELERATE
-- debug fence
--#define FENCEDEBUG
-- debug terrain
--#define TERRAINDEBUG
---------------------
-- TESTMODE
---------------------
-- enable script testing via radio sticks
--#define TESTMODE


---------------------
-- SENSORS
---------------------












-- Throttle and RC use RPM sensor IDs







------------------------
-- MIN MAX
------------------------
-- min

------------------------
-- LAYOUT
------------------------
  














--------------------------------------------------------------------------------
-- MENU VALUE,COMBO
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- ALARMS
--------------------------------------------------------------------------------
--[[
 ALARM_TYPE_MIN needs arming (min has to be reached first), value below level for grace, once armed is periodic, reset on landing
 ALARM_TYPE_MAX no arming, value above level for grace, once armed is periodic, reset on landing
 ALARM_TYPE_TIMER no arming, fired periodically, spoken time, reset on landing
 ALARM_TYPE_BATT needs arming (min has to be reached first), value below level for grace, no reset on landing
{ 
  1 = notified, 
  2 = alarm start, 
  3 = armed, 
  4 = type(0=min,1=max,2=timer,3=batt), 
  5 = grace duration
  6 = ready
  7 = last alarm
}  
--]]



-----------------------
-- UNIT SCALING
-----------------------
local unitScale = getGeneralSettings().imperial == 0 and 1 or 3.28084
local unitLabel = getGeneralSettings().imperial == 0 and "m" or "ft"
local unitLongScale = getGeneralSettings().imperial == 0 and 1/1000 or 1/1609.34
local unitLongLabel = getGeneralSettings().imperial == 0 and "km" or "mi"



-----------------------
-- HUD AND YAW
-----------------------
-- vertical distance between roll horiz segments

-- vertical distance between roll horiz segments
-----------------------
-- BATTERY 
-----------------------
-- offsets are: 1 celm, 4 batt, 7 curr, 10 mah, 13 cap, indexing starts at 1



-- X-Lite Support

-----------------------------------
-- STATE TRANSITION ENGINE SUPPORT
-----------------------------------






local vspd = 0

local function drawHud(drawLib,conf,telemetry,status,battery,getMaxValue)
  -- clean right and left
  lcd.drawFilledRectangle(62-2, 0+7, 5, 10, ERASE, 0)
  lcd.drawFilledRectangle(62+88-7, 0+7, 8, 10, ERASE, 0)
  -- HUD
  local r = -telemetry.roll
  local cx,cy,dx,dy,ccx,ccy
  local yPos = 0 + 7 + 8
  -----------------------
  -- artificial horizon
  -----------------------
  -- no roll ==> segments are vertical, offsets are multiples of 6
  if telemetry.roll == 0 then
    dx=0
    dy=telemetry.pitch
    cx=0
    cy=6
    ccx=0
    ccy=2*6
  else
    -- center line offsets
    dx = math.cos(math.rad(90 - r)) * -telemetry.pitch
    dy = math.sin(math.rad(90 - r)) * telemetry.pitch
    -- 1st line offsets
    cx = math.cos(math.rad(90 - r)) * 6
    cy = math.sin(math.rad(90 - r)) * 6
  end
  local rollX = 212/2 - 1 - 2
  for dist=1,6
  do
    drawLib.drawLineWithClipping(rollX + dx - dist*cx,dy + 33 + dist*cy,r,(dist%2==0 and 20 or 8),DOTTED,62,62 + 88,8,56 - 1)
    drawLib.drawLineWithClipping(rollX + dx + dist*cx,dy + 33 - dist*cy,r,(dist%2==0 and 20 or 8),DOTTED,62,62 + 88,8,56 - 1)
  end
  -----------------------
  -- dark color for "ground"
  -----------------------
  local minY = 8
  local minX = 62 + 1
  -- vario width is 6
  local maxX = 62 + 88 - 8
  local maxY = 54
  local ox = 106 + dx - 2
  local oy = 33 + dy
  local yy = 0
  -- angle of the line passing on point(ox,oy)
  local angle = math.tan(math.rad(-telemetry.roll))
  -- for each pixel of the hud base/top draw vertical black 
  -- lines from hud border to horizon line
  -- horizon line moves with pitch/roll
  for xx= minX,maxX
  do
    yy = (oy - ox*angle) + math.floor(xx*angle)
    if telemetry.roll > 90 or telemetry.roll < -90 then
      if yy > minY then
        lcd.drawLine(xx, minY, xx, math.min(yy,maxY),SOLID,0)
      end
    else
      if yy < maxY then
        lcd.drawLine(xx, maxY, xx, math.max(yy,minY),SOLID,0)
      end
    end
  end
  vspd = telemetry.vSpeed
  -------------------------------------
  -- vario indicator on right
  -------------------------------------
  lcd.drawLine(62 + 88 - 6, 7, 62 + 88 - 6, yPos + 40, SOLID, 0)
  
  local varioMax = 10
  local varioSpeed = math.min(math.abs(0.1*vspd),10)
  local varioY = 0
  local arrowY = -1
  if vspd > 0 then
    varioY = 33 - 4 - varioSpeed/varioMax*22
  else
    varioY = 33 + 6
    arrowY = 1
  end
  lcd.drawFilledRectangle(62 + 88 - 6, varioY, 6, varioSpeed/varioMax*22, FORCE, 0)
  -------------------------------------
  -- left and right indicators on HUD
  -------------------------------------
  -- black borders
  lcd.drawRectangle(62, 33 - 5, 19, 11, FORCE, 0)
  lcd.drawRectangle(62 + 88 -  17 - 3, 33 - 5, 20, 11, FORCE, 0)
  -- erase area
  lcd.drawFilledRectangle(62, 33 - 4, 18, 9, ERASE, 0)
  lcd.drawFilledRectangle(62 + 88 -  17 - 2, 33 - 4, 19, 9, ERASE, 0)
  -- altitude (tracking max altitude but not max HAT)
  local alt = status.terrainEnabled == 1 and telemetry.heightAboveTerrain or getMaxValue(telemetry.homeAlt,11)
  alt = alt * unitScale -- alt is meters*3.28 = feet

  if math.abs(alt) < 10 then
      lcd.drawNumber(62 + 88,33 - 3,alt * 10,PREC1+RIGHT)
  else
      lcd.drawNumber(62 + 88,33 - 3,alt,RIGHT)
  end
  -- hspeed
  local speed = getMaxValue(telemetry.hSpeed,14) * conf.horSpeedMultiplier
  if math.abs(speed) > 99 then
    lcd.drawNumber(62+1,33 - 3,speed*0.1,0)
  else
    lcd.drawNumber(62+1,33 - 3,speed,PREC1)
  end
  
  lcd.drawLine(212/2-9-3,33,212/2-4-3,33 ,SOLID,0) -- -1 to compensate for H offset 
  lcd.drawLine(212/2-3-3,33,212/2-3-3,33+3 ,SOLID,0)
  
  lcd.drawLine(212/2+4-3,33,212/2+9-3,33 ,SOLID,0)
  lcd.drawLine(212/2+3-3,33,212/2+3-3,33+3 ,SOLID,0)
  -- vspeed box (dm/s)
  local xx = math.abs(vspd*conf.vertSpeedMultiplier) > 9999 and 4 or 3
  xx = xx + (vspd*conf.vertSpeedMultiplier < 0 and 1 or 0)
  
  lcd.drawFilledRectangle((212)/2 - (xx/2)*5 - 2, LCD_H - 17, xx*5+3, 10, ERASE)
  
  if math.abs(vspd*conf.vertSpeedMultiplier) > 99 then -- 
    lcd.drawNumber((212)/2 + (xx/2)*5, LCD_H - 15, vspd*0.1*conf.vertSpeedMultiplier, SMLSIZE+RIGHT)
  else
    lcd.drawNumber((212)/2 + (xx/2)*5, LCD_H - 15, vspd*conf.vertSpeedMultiplier, SMLSIZE+RIGHT+PREC1)
  end
  lcd.drawRectangle((212)/2 - (xx/2)*5 - 2, LCD_H - 17, xx*5+3, 10, FORCE+SOLID)
    
  if status.showMinMaxValues == true then
    drawLib.drawVArrow(62 +   17 + 4, 33 - 4,6,true,false)
  end
  -- min/max arrows
  if status.showMinMaxValues == true then
    drawLib.drawVArrow(62 + 88 - 24, 33 - 4,6,true,false)
  end
  -- arming status, show only if timer is not running, hide otherwise
  if telemetry.failsafe == 0 and telemetry.ekfFailsafe == 0 and telemetry.battFailsafe == 0 and status.timerRunning == 0 then
    if telemetry.statusArmed == 1 then
      lcd.drawText(62 + 88/2 - 15, 20, " ARMED ", SMLSIZE+INVERS)
    else
      lcd.drawText(62 + 88/2 - 21, 20, " DISARMED ", SMLSIZE+INVERS+BLINK)
    end
  end
  -- yaw angle box
  xx = telemetry.yaw < 10 and 1 or ( telemetry.yaw < 100 and -2 or -5 )
  lcd.drawNumber(212/2 + xx - 8, 0+7-1, telemetry.yaw, MIDSIZE+INVERS)
  -- terrain status
  local xNext = 62 + 2
  if status.terrainEnabled == 1 then
    local flags = SMLSIZE+INVERS
    if telemetry.terrainUnhealthy == 1 then
      flags = flags+BLINK
    end
    lcd.drawText(xNext, 48, "T", flags)
    xNext = xNext+6
  end
  -- fence status
  if telemetry.fencePresent == 1 then
    local flags = SMLSIZE+INVERS
    if telemetry.fenceBreached == 1 then
      flags = flags+BLINK
    end
    lcd.drawText(xNext, 48, "F", flags)
  end
end


return {
  drawHud=drawHud,
  yawRibbonPoints=yawRibbonPoints
}