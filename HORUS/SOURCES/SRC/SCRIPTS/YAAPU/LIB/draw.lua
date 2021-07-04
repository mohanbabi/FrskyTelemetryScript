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



-- model and opentx version
local ver, radio, maj, minor, rev = getVersion()
local yawRibbonPoints = {"N",nil,"NE",nil,"E",nil,"SE",nil,"S",nil,"SW",nil,"W",nil,"NW",nil}


local drawLine = nil

if string.find(radio, "x10") and tonumber(maj..minor..rev) < 222 then
  drawLine = function(x1,y1,x2,y2,flags1,flags2) lcd.drawLine(LCD_W-x1,LCD_H-y1,LCD_W-x2,LCD_H-y2,flags1,flags2) end
else
  drawLine = function(x1,y1,x2,y2,flags1,flags2) lcd.drawLine(x1,y1,x2,y2,flags1,flags2) end
end

local function drawHArrow(x,y,width,left,right,drawBlinkBitmap)
  lcd.drawLine(x, y, x + width,y, SOLID, 0)
  if left == true then
    lcd.drawLine(x + 1,y  - 1,x + 2,y  - 2, SOLID, 0)
    lcd.drawLine(x + 1,y  + 1,x + 2,y  + 2, SOLID, 0)
  end
  if right == true then
    lcd.drawLine(x + width - 1,y  - 1,x + width - 2,y  - 2, SOLID, 0)
    lcd.drawLine(x + width - 1,y  + 1,x + width - 2,y  + 2, SOLID, 0)
  end
end
--
local function drawVArrow(x,y,top,bottom,utils)
  if top == true then
    utils.drawBlinkBitmap("uparrow",x,y)
  else
    utils.drawBlinkBitmap("downarrow",x,y)
  end
end

local function drawHomeIcon(x,y,utils)
  lcd.drawBitmap(utils.getBitmap("minihomeorange"),x,y)
end

local function computeOutCode(x,y,xmin,ymin,xmax,ymax)
    local code = 0; --initialised as being inside of hud
    --
    if x < xmin then --to the left of hud
        code = bit32.bor(code,1);
    elseif x > xmax then --to the right of hud
        code = bit32.bor(code,2);
    end
    if y < ymin then --below the hud
        code = bit32.bor(code,8);
    elseif y > ymax then --above the hud
        code = bit32.bor(code,4);
    end
    --
    return code;
end

-- Cohen–Sutherland clipping algorithm
-- https://en.wikipedia.org/wiki/Cohen%E2%80%93Sutherland_algorithm
local function drawLineWithClippingXY(x0,y0,x1,y1,style,xmin,xmax,ymin,ymax,color,radio,rev)
  -- compute outcodes for P0, P1, and whatever point lies outside the clip rectangle
  local outcode0 = computeOutCode(x0, y0, xmin, ymin, xmax, ymax);
  local outcode1 = computeOutCode(x1, y1, xmin, ymin, xmax, ymax);
  local accept = false;

  while (true) do
    if ( bit32.bor(outcode0,outcode1) == 0) then
      -- bitwise OR is 0: both points inside window; trivially accept and exit loop
      accept = true;
      break;
    elseif (bit32.band(outcode0,outcode1) ~= 0) then
      -- bitwise AND is not 0: both points share an outside zone (LEFT, RIGHT, TOP, BOTTOM)
      -- both must be outside window; exit loop (accept is false)
      break;
    else
      -- failed both tests, so calculate the line segment to clip
      -- from an outside point to an intersection with clip edge
      local x = 0
      local y = 0
      -- At least one endpoint is outside the clip rectangle; pick it.
      local outcodeOut = outcode0 ~= 0 and outcode0 or outcode1
      -- No need to worry about divide-by-zero because, in each case, the
      -- outcode bit being tested guarantees the denominator is non-zero
      if bit32.band(outcodeOut,4) ~= 0 then --point is above the clip window
        x = x0 + (x1 - x0) * (ymax - y0) / (y1 - y0)
        y = ymax
      elseif bit32.band(outcodeOut,8) ~= 0 then --point is below the clip window
        x = x0 + (x1 - x0) * (ymin - y0) / (y1 - y0)
        y = ymin
      elseif bit32.band(outcodeOut,2) ~= 0 then --point is to the right of clip window
        y = y0 + (y1 - y0) * (xmax - x0) / (x1 - x0)
        x = xmax
      elseif bit32.band(outcodeOut,1) ~= 0 then --point is to the left of clip window
        y = y0 + (y1 - y0) * (xmin - x0) / (x1 - x0)
        x = xmin
      end
      -- Now we move outside point to intersection point to clip
      -- and get ready for next pass.
      if outcodeOut == outcode0 then
        x0 = x
        y0 = y
        outcode0 = computeOutCode(x0, y0, xmin, ymin, xmax, ymax)
      else
        x1 = x
        y1 = y
        outcode1 = computeOutCode(x1, y1, xmin, ymin, xmax, ymax)
      end
    end
  end
  if accept then
    drawLine(x0,y0,x1,y1, style,color)
  end
end

local function drawLineWithClipping(ox,oy,angle,len,style,xmin,xmax,ymin,ymax,color,radio,rev)
  local xx = math.cos(math.rad(angle)) * len * 0.5
  local yy = math.sin(math.rad(angle)) * len * 0.5
  
  local x0 = ox - xx
  local x1 = ox + xx
  local y0 = oy - yy
  local y1 = oy + yy    
  
  drawLineWithClippingXY(x0,y0,x1,y1,style,xmin,xmax,ymin,ymax,color,radio,rev)
end

local function drawNumberWithDim(x,y,xDim,yDim,number,dim,flags,dimFlags)
  lcd.drawNumber(x, y, number,flags)
  lcd.drawText(xDim, yDim, dim, dimFlags)
end

local function drawRArrow(x,y,r,angle,color)
  local ang = math.rad(angle - 90)
  local x1 = x + r * math.cos(ang)
  local y1 = y + r * math.sin(ang)
  
  ang = math.rad(angle - 90 + 150)
  local x2 = x + r * math.cos(ang)
  local y2 = y + r * math.sin(ang)
  
  ang = math.rad(angle - 90 - 150)
  local x3 = x + r * math.cos(ang)
  local y3 = y + r * math.sin(ang)
  ang = math.rad(angle - 270)
  local x4 = x + r * 0.5 * math.cos(ang)
  local y4 = y + r * 0.5 *math.sin(ang)
  --
  drawLine(x1,y1,x2,y2,SOLID,color)
  drawLine(x1,y1,x3,y3,SOLID,color)
  drawLine(x2,y2,x4,y4,SOLID,color)
  drawLine(x3,y3,x4,y4,SOLID,color)
end

local function drawFenceStatus(utils,status,telemetry,x,y)
  if telemetry.fencePresent == 0 then
    return x
  end
  if telemetry.fenceBreached == 1 then
    utils.drawBlinkBitmap("fence_breach",x,y)
    return x+21
  end
  lcd.drawBitmap(utils.getBitmap("fence_ok"),x,y)
  return x+21
end

local function drawTerrainStatus(utils,status,telemetry,x,y)
  if status.terrainEnabled == 0 then
    return x
  end
  if telemetry.terrainUnhealthy == 1 then
    utils.drawBlinkBitmap("terrain_error",x,y)
    return x+21
  end
  lcd.drawBitmap(utils.getBitmap("terrain_ok"),x,y)
  return x+21
end

local function initMap(map,name)
  if map[name] == nil then
    map[name] = 0
  end
end

local function drawMinMaxBar(x, y, w, h, color, value, min, max, flags)
  local perc = math.min(math.max(value,min),max)
  lcd.setColor(CUSTOM_COLOR,lcd.RGB(255,255, 255))
  lcd.drawFilledRectangle(x,y,w,h,CUSTOM_COLOR)
  lcd.setColor(CUSTOM_COLOR,color)
  lcd.drawGauge(x, y,w,h,perc-min,max-min,CUSTOM_COLOR)
  lcd.setColor(CUSTOM_COLOR, 0x0000) -- black
  local strperc = string.format("%02d%%",value)
  local xOffset = flags==0 and 10 or 17
  local yOffset = flags==0 and 1 or 4
  lcd.drawText(x+w/2-xOffset, y-yOffset, strperc, flags+CUSTOM_COLOR)
end

-- initialize up to 5 bars
local barMaxValues = {}
local barAvgValues = {}
local barSampleCounts = {}

local function updateBar(name, value)
  -- init
  initMap(barSampleCounts,name)
  initMap(barMaxValues,name)
  initMap(barAvgValues,name)
  
  -- update metadata
  barSampleCounts[name] = barSampleCounts[name]+1
  barMaxValues[name] = math.max(value,barMaxValues[name])
  -- weighted average on 5 samples
  barAvgValues[name] = barAvgValues[name]*0.9 + value*0.1
end
-- draw an horizontal dynamic bar with an average red pointer of the last 5 samples
local function drawBar(name, x, y, w, h, color, value, flags)
  updateBar(name, value)
  
  lcd.setColor(CUSTOM_COLOR, 0xFFFF)
  lcd.drawFilledRectangle(x,y,w,h,CUSTOM_COLOR)
  
  -- normalize percentage relative to MAX
  local perc = 0
  local avgPerc = 0
  if barMaxValues[name] > 0 then
    perc = value/barMaxValues[name]
    avgPerc = barAvgValues[name]/barMaxValues[name]
  end
  lcd.setColor(CUSTOM_COLOR, color)
  lcd.drawFilledRectangle(math.max(x,x+w-perc*w),y+1,math.min(w,perc*w),h-2,CUSTOM_COLOR)
  lcd.setColor(CUSTOM_COLOR, 0xF800)
  
  lcd.drawLine(x+w-avgPerc*(w-2),y+1,x+w-avgPerc*(w-2),y+h-2,SOLID,CUSTOM_COLOR)
  lcd.drawLine(1+x+w-avgPerc*(w-2),y+1,1+x+w-avgPerc*(w-2),y+h-2,SOLID,CUSTOM_COLOR)
  lcd.setColor(CUSTOM_COLOR, 0x0000)
  lcd.drawNumber(x+w-1,y-3,value,CUSTOM_COLOR+flags+RIGHT)
  -- border
  lcd.setColor(CUSTOM_COLOR, 0x0000)
  lcd.drawRectangle(x,y,w,h,CUSTOM_COLOR)
end


-- max is 20 samples every 1 sec
local graphSampleTime = {}
local graphMaxValues = {}
local graphMinValues = {}
local graphAvgValues = {}
local graphSampleCounts = {}
local graphSamples = {}

local function resetGraph(name)
  graphSampleTime[name] = 0
  graphMaxValues[name] = 0
  graphMinValues[name] = 0
  graphAvgValues[name] = 0
  graphSampleCounts[name] = 0
  graphSamples[name] = {}
end

local function updateGraph(name, value, maxSamples)
  if maxSamples == nil then
    maxSamples = 20
  end
  -- init
  initMap(graphSampleTime,name)
  initMap(graphMaxValues,name)
  initMap(graphMinValues,name)
  initMap(graphAvgValues,name)
  initMap(graphSampleCounts,name)
  
  if graphSamples[name] == nil then
    graphSamples[name] = {}
  end
  
  if getTime() - graphSampleTime[name] > 100 then
    graphAvgValues[name] = graphAvgValues[name]*0.9 + value*0.1
    graphSampleCounts[name] = graphSampleCounts[name]+1
    graphSamples[name][graphSampleCounts[name]%maxSamples] = value -- 0->49
    graphSampleTime[name] = getTime()
    graphMinValues[name] = math.min(value, graphMinValues[name])
    graphMaxValues[name] = math.max(value, graphMaxValues[name])
  end
  if graphSampleCounts[name] < 2 then
    return
  end
end

local function drawGraph(name, x ,y ,w , h, color, value, draw_bg, draw_value, unit, maxSamples)
  updateGraph(name, value, maxSamples)
  
  if maxSamples == nil then
    maxSamples = 20
  end
  
  if draw_bg == true then
    lcd.setColor(CUSTOM_COLOR, 0xFFFF)
    lcd.drawFilledRectangle(x,y,w,h,CUSTOM_COLOR)
  end
  
  lcd.setColor(CUSTOM_COLOR, color) -- graph color
  
  local height = h - 5 -- available height for the graph
  local step = (w-2)/(maxSamples-1)
  local maxY = y + h - 3
  
  local minMaxWindow = graphMaxValues[name] - graphMinValues[name] -- max difference between current window min/max
  
  -- scale factor based on current min/max difference
  local scale = height/minMaxWindow
  
  -- number of samples we can plot
  local sampleWindow = math.min(maxSamples-1,graphSampleCounts[name]-1)
  
  local lastY = nil
  for i=1,sampleWindow
  do
    local prevSample = graphSamples[name][(i-1+graphSampleCounts[name]-sampleWindow)%maxSamples]
    local curSample =  graphSamples[name][(i+graphSampleCounts[name]-sampleWindow)%maxSamples]
    
    local x1 = x + (i-1)*step
    local x2 = x + i*step
    
    local y1 = maxY - (prevSample-graphMinValues[name])*scale
    local y2 = maxY - (curSample-graphMinValues[name])*scale    
    lastY = y2
    lcd.drawLine(x1,y1,x2,y2,SOLID,CUSTOM_COLOR)
  end

  if lastY ~= nil then
    lcd.setColor(CUSTOM_COLOR, lcd.RGB(150,150,150))
    lcd.drawLine(x, lastY, x+w, lastY ,DOTTED, CUSTOM_COLOR)
  end
  
  if draw_bg == true then
    lcd.setColor(CUSTOM_COLOR, 0x0000)
    lcd.drawRectangle(x,y,w,h,CUSTOM_COLOR)
  end
  
  if draw_value == true and lastY ~= nil then
    lcd.setColor(CUSTOM_COLOR, 0xFFFF)
    lcd.drawText(x+2,lastY-6,string.format("%d%s",value,unit),CUSTOM_COLOR+SMLSIZE+INVERS)
  end

  return lastY
end

--[[
 x,y = top,left
 image = background image
 gx,gy = gauge center point 
 r1 = gauge radius
 r2 = gauge distance from center
 perc = value % normalized between min, max
 max = angle max
--]]
local function drawGauge(x, y, image, gx, gy, r1, r2, perc, max, color, utils)
  local ang = (360-(max/2))+((perc*0.01)*max)
  
  if ang > 360 then
    ang = ang - 360
  end
  
  local ra = math.rad(ang-90)
  local ra_left = math.rad(ang-90-20)
  local ra_right = math.rad(ang-90+20)
  
  -- tip of the triangle
  local x1 = gx + r1 * math.cos(ra)
  local y1 = gy + r1 * math.sin(ra)
  -- bottom left
  local x2 = gx + r2 * math.cos(ra_left)
  local y2 = gy + r2 * math.sin(ra_left)
  -- bottom right
  local x3 = gx + r2 * math.cos(ra_right)
  local y3 = gy + r2 * math.sin(ra_right)
  
  lcd.drawBitmap(utils.getBitmap(image), x, y)

  drawLine(x1,y1,x2,y2,SOLID,color)
  drawLine(x1,y1,x3,y3,SOLID,color)
  drawLine(x2,y2,x3,y3,SOLID,color)
end

local function drawFailsafe(telemetry,utils)
  if telemetry.ekfFailsafe > 0 then
    utils.drawBlinkBitmap("ekffailsafe",LCD_W/2 - 90,154)
  elseif telemetry.battFailsafe > 0 then
    utils.drawBlinkBitmap("battfailsafe",LCD_W/2 - 90,154)
  elseif telemetry.failsafe > 0 then
    utils.drawBlinkBitmap("failsafe",LCD_W/2 - 90,154)
  end
end

local function drawArmStatus(status,telemetry,utils)
  -- armstatus
  if not utils.failsafeActive(telemetry) and status.timerRunning == 0 then
    if (telemetry.statusArmed == 1) then
      lcd.drawBitmap(utils.getBitmap("armed"),LCD_W/2 - 90,154)
    else
      utils.drawBlinkBitmap("disarmed",LCD_W/2 - 90,154)
    end
  end
end

local function drawNoTelemetryData(status,telemetry,utils,telemetryEnabled)
  -- no telemetry data
  if (not telemetryEnabled()) then
    lcd.setColor(CUSTOM_COLOR,0xFFFF)
    lcd.drawFilledRectangle(88,74, 304, 84, CUSTOM_COLOR)
    lcd.setColor(CUSTOM_COLOR,0xF800)
    lcd.drawFilledRectangle(90,76, 300, 80, CUSTOM_COLOR)
    lcd.setColor(CUSTOM_COLOR,0xFFFF)
    lcd.drawText(110, 85, "no telemetry data", DBLSIZE+CUSTOM_COLOR)
    lcd.drawText(130, 120, "Yaapu Telemetry Widget 1.9.5-dev", SMLSIZE+CUSTOM_COLOR)
  end
end

local function drawFilledRectangle(x,y,w,h,flags)
    if w > 0 and h > 0 then
      lcd.drawFilledRectangle(x,y,w,h,flags)
    end
end


--[[
  based on olliw's improved version over mine :-)
  https://github.com/olliw42/otxtelemetry
--]]
local function drawCompassRibbon(y,myWidget,conf,telemetry,status,battery,utils,width,xMin,xMax,stepWidth,bigFont)
  local minY = y+1
  local heading = telemetry.yaw
  local minX = xMin
  local maxX = xMax
  local midX = (xMax + xMin)/2
  local tickNo = 4 --number of ticks on one side
  local stepCount = (maxX - minX -24)/(2*tickNo)
  local closestHeading = math.floor(heading/22.5) * 22.5
  local closestHeadingX = midX + (closestHeading - heading)/22.5 * stepCount
  local tickIdx = (closestHeading/22.5 - tickNo) % 16
  local tickX = closestHeadingX - tickNo*stepCount   
  for i = 1,10 do
      if tickX >= minX and tickX < maxX then
          if yawRibbonPoints[tickIdx+1] == nil then
              lcd.setColor(CUSTOM_COLOR, 0xFFFF)
              lcd.drawLine(tickX, minY, tickX, y+5, SOLID, CUSTOM_COLOR)
          else
              lcd.setColor(CUSTOM_COLOR, 0xFFFF)
              lcd.drawText(tickX, minY-3, yawRibbonPoints[tickIdx+1], CUSTOM_COLOR+SMLSIZE+CENTER)
          end
      end
      tickIdx = (tickIdx + 1) % 16
      tickX = tickX + stepCount
  end
  -- home icon
  local homeOffset = 0
  local angle = telemetry.homeAngle - telemetry.yaw
  if angle < 0 then angle = angle + 360 end
  if angle > 270 or angle < 90 then
    homeOffset = ((angle + 90) % 180)/180  * width
  elseif angle >= 90 and angle < 180 then
    homeOffset = width
  end
  drawHomeIcon(xMin + homeOffset -5,minY + (bigFont and 28 or 20),utils)
  
  -- text box
  local w = 60 -- 3 digits width
  if heading < 0 then heading = heading + 360 end
  if heading < 10 then
      w = 20
  elseif heading < 100 then
      w = 40
  end
  local scale = bigFont and 1 or 0.7
  lcd.setColor(CUSTOM_COLOR, 0x0000)
  lcd.drawFilledRectangle(midX - (w/2)*scale, minY-2, w*scale, 28*scale, CUSTOM_COLOR+SOLID)
  lcd.setColor(CUSTOM_COLOR, 0xFFFF)
  lcd.drawNumber(midX, bigFont and minY-6 or minY-2, heading, CUSTOM_COLOR+(bigFont and DBLSIZE or 0)+CENTER)
end

local function drawStatusBar(maxRows,conf,telemetry,status,battery,alarms,frame,utils)
  local yDelta = (maxRows-1)*12
  
  lcd.setColor(CUSTOM_COLOR,0x0000)
  lcd.drawFilledRectangle(0,229-yDelta,480,LCD_H-(229-yDelta),CUSTOM_COLOR)
  -- flight time
  lcd.setColor(CUSTOM_COLOR,0xFFFF)
  lcd.drawTimer(LCD_W, 224-yDelta, model.getTimer(2).value, DBLSIZE+CUSTOM_COLOR+RIGHT)
  -- flight mode
  lcd.setColor(CUSTOM_COLOR,0xFFFF)
  if status.strFlightMode ~= nil then
    lcd.drawText(1,230-yDelta,status.strFlightMode,MIDSIZE+CUSTOM_COLOR)
  end
  -- gps status, draw coordinatyes if good at least once
  if telemetry.lon ~= nil and telemetry.lat ~= nil then
    lcd.drawText(370, 227-yDelta, telemetry.strLat, SMLSIZE+CUSTOM_COLOR+RIGHT)
    lcd.drawText(370, 241-yDelta, telemetry.strLon, SMLSIZE+CUSTOM_COLOR+RIGHT)
  end
  -- gps status
  local hdop = telemetry.gpsHdopC
  local strStatus = utils.gpsStatuses[telemetry.gpsStatus]
  local flags = BLINK
  local mult = 1
  
  if telemetry.gpsStatus  > 2 then
    if telemetry.homeAngle ~= -1 then
      flags = PREC1
    end
    if hdop > 999 then
      hdop = 999
      flags = 0
      mult=0.1
    elseif hdop > 99 then
      flags = 0
      mult=0.1
    end
    lcd.drawNumber(270,226-yDelta, hdop*mult,DBLSIZE+flags+RIGHT+CUSTOM_COLOR)
    -- SATS
    lcd.setColor(CUSTOM_COLOR,0xFFFF)
    lcd.drawText(170,226-yDelta, strStatus, SMLSIZE+CUSTOM_COLOR)

    lcd.setColor(CUSTOM_COLOR,0xFFFF)
    if telemetry.numSats == 15 then
      lcd.drawNumber(170,235-yDelta, telemetry.numSats, MIDSIZE+CUSTOM_COLOR)
      lcd.drawText(200,239-yDelta, "+", SMLSIZE+CUSTOM_COLOR)
    else
      lcd.drawNumber(170,235-yDelta,telemetry.numSats, MIDSIZE+CUSTOM_COLOR)
    end
  elseif telemetry.gpsStatus == 0 then
    utils.drawBlinkBitmap("nogpsicon",150,227-yDelta)
  else
    utils.drawBlinkBitmap("nolockicon",150,227-yDelta)
  end
  
  local offset = math.min(maxRows,#status.messages+1)
  for i=0,offset-1 do
    lcd.setColor(CUSTOM_COLOR,utils.mavSeverity[status.messages[(status.messageCount + i - offset) % (#status.messages+1)][2]][2])
    lcd.drawText(1,(256-yDelta)+(12*i), status.messages[(status.messageCount + i - offset) % (#status.messages+1)][1],SMLSIZE+CUSTOM_COLOR)
  end
end

--------------------------
-- CUSTOM SENSORS SUPPORT
--------------------------

local function drawCustomSensors(x,customSensors,customSensorXY,utils,status,colorLabel)
    --lcd.setColor(CUSTOM_COLOR,lcd.RGB(0,75,128))
    lcd.setColor(CUSTOM_COLOR,0x0000)
    lcd.drawFilledRectangle(0,194,LCD_W,35,CUSTOM_COLOR)
    lcd.setColor(CUSTOM_COLOR,0x7BCF)
    lcd.drawLine(1,228,LCD_W-2,228,SOLID,CUSTOM_COLOR)
    
    local label,data,prec,mult,flags,sensorConfig
    for i=1,6
    do
      if customSensors.sensors[i] ~= nil then 
        sensorConfig = customSensors.sensors[i]
        
        if sensorConfig[4] == "" then
          label = string.format("%s",sensorConfig[1])
        else
          label = string.format("%s(%s)",sensorConfig[1],sensorConfig[4])
        end
        -- draw sensor label
        lcd.setColor(CUSTOM_COLOR,colorLabel)
        lcd.drawText(x+customSensorXY[i][1], customSensorXY[i][2],label, SMLSIZE+RIGHT+CUSTOM_COLOR)
        
        mult =  sensorConfig[3] == 0 and 1 or ( sensorConfig[3] == 1 and 10 or 100 )
        prec =  mult == 1 and 0 or (mult == 10 and 32 or 48)
        
        local sensorName = sensorConfig[2]..(status.showMinMaxValues == true and sensorConfig[6] or "")
        local sensorValue = getValue(sensorName) 
        local value = (sensorValue+(mult == 100 and 0.005 or 0))*mult*sensorConfig[5]        
        
        local sign = sensorConfig[6] == "+" and 1 or -1
        flags = sensorConfig[7] == 1 and 0 or MIDSIZE
        
        if sensorConfig[10] == true then
        -- RED lcd.RGB(255,0, 0)
        -- GREEN lcd.RGB(0, 255, 0)
        -- YELLOW lcd.RGB(255, 204, 0)
          local color = lcd.RGB(255,0, 0)
          -- min/max tracking
          if math.abs(value) ~= 0 then
            color = ( sensorValue*sign > sensorConfig[9]*sign and lcd.RGB(255, 0, 0) or (sensorValue*sign > sensorConfig[8]*sign and lcd.RGB(255, 204, 0) or lcd.RGB(0, 255, 0)))
          end
          drawMinMaxBar(x+customSensorXY[i][3]-sensorConfig[11],customSensorXY[i][4]+5,sensorConfig[11],sensorConfig[12],color,value,sensorConfig[13],sensorConfig[14],flags)
        else
          -- default font size
          local color = 0xFFFF
          -- min/max tracking
          if math.abs(value) ~= 0 and status.showMinMaxValues == false then
            color = ( sensorValue*sign > sensorConfig[9]*sign and lcd.RGB(255,70,0) or (sensorValue*sign > sensorConfig[8]*sign and 0xFFE0 or 0xFFFF))
          end
          lcd.setColor(CUSTOM_COLOR,color)
          local voffset = flags==0 and 6 or 0
          -- if a lookup table exists use it!
          if customSensors.lookups[i] ~= nil and customSensors.lookups[i][value] ~= nil then
            lcd.drawText(x+customSensorXY[i][3], customSensorXY[i][4]+voffset, customSensors.lookups[i][value] or value, flags+RIGHT+CUSTOM_COLOR)
          else
            lcd.drawNumber(x+customSensorXY[i][3], customSensorXY[i][4]+voffset, value, flags+RIGHT+prec+CUSTOM_COLOR)
          end
        end
      end
    end
end

local function drawWindArrow(x,y,r1,r2,arrow_angle, angle, skew, color)
  local a = math.rad(angle - 90)
  local ap = math.rad(angle + arrow_angle/2 - 90)
  local am = math.rad(angle - arrow_angle/2 - 90)
  
  local x1 = x + r1 * math.cos(a) * skew
  local y1 = y + r1 * math.sin(a)
  local x2 = x + r2 * math.cos(ap) * skew
  local y2 = y + r2 * math.sin(ap)
  local x3 = x + r2 * math.cos(am) * skew
  local y3 = y + r2 * math.sin(am)
  
  lcd.drawLine(x1,y1,x2,y2,SOLID,color)
  lcd.drawLine(x1,y1,x3,y3,SOLID,color)
  lcd.drawRectangle(x-2,y-2,4,4,SOLID+color)
end

local function drawLeftRightTelemetry(myWidget,conf,telemetry,status,battery)
    -- ALT
    local altPrefix = status.terrainEnabled == 1 and "HAT(" or "Alt("
    local alt = status.terrainEnabled == 1 and telemetry.heightAboveTerrain or telemetry.homeAlt
    lcd.setColor(CUSTOM_COLOR,0x0000)
    lcd.drawText(10, 50+16, altPrefix..unitLabel..")", SMLSIZE+0+CUSTOM_COLOR)
    lcd.setColor(CUSTOM_COLOR,0xFFFF)
    lcd.drawNumber(10,50+27,alt*unitScale,MIDSIZE+CUSTOM_COLOR+0)
    -- SPEED
    lcd.setColor(CUSTOM_COLOR,0x0000)
    lcd.drawText(10, 50+54, "Spd("..conf.horSpeedLabel..")", SMLSIZE+0+CUSTOM_COLOR)
    lcd.setColor(CUSTOM_COLOR,0xFFFF)
    lcd.drawNumber(10,50+65,telemetry.hSpeed*0.1* conf.horSpeedMultiplier,MIDSIZE+CUSTOM_COLOR+0)
    -- VSPEED
    lcd.setColor(CUSTOM_COLOR,0x0000)
    lcd.drawText(10, 50+92, "VSI("..conf.vertSpeedLabel..")", SMLSIZE+0+CUSTOM_COLOR)
    lcd.setColor(CUSTOM_COLOR,0xFFFF)
    lcd.drawNumber(10,50+103, telemetry.vSpeed*0.1*conf.vertSpeedMultiplier, MIDSIZE+CUSTOM_COLOR+0)
    -- DIST
    lcd.setColor(CUSTOM_COLOR,0x0000)
    lcd.drawText(10, 50+130, "Dist("..unitLabel..")", SMLSIZE+0+CUSTOM_COLOR)
    lcd.setColor(CUSTOM_COLOR,0xFFFF)
    lcd.drawNumber(10, 50+141, telemetry.homeDist*unitScale, MIDSIZE+0+CUSTOM_COLOR)
    
    -- RIGHT
    -- CELL
    if battery[1] * 0.01 < 10 then
      lcd.drawNumber(410, 15+5, battery[1] + 0.5, PREC2+0+MIDSIZE+CUSTOM_COLOR)
    else
      lcd.drawNumber(410, 15+5, (battery[1] + 0.5)*0.1, PREC1+0+MIDSIZE+CUSTOM_COLOR)
    end
    lcd.drawText(410+50, 15+6, status.battsource, SMLSIZE+CUSTOM_COLOR)
    lcd.drawText(410+50, 15+16, "V", SMLSIZE+CUSTOM_COLOR)
    -- aggregate batt %
    local strperc = string.format("%2d%%",battery[16])
    lcd.drawText(410+65, 15+30, strperc, MIDSIZE+CUSTOM_COLOR+RIGHT)
    -- Tracker
    lcd.setColor(CUSTOM_COLOR,0x0000)
    lcd.drawText(410, 15+70, "Tracker", SMLSIZE+0+CUSTOM_COLOR)
    lcd.setColor(CUSTOM_COLOR,0xFFFF)
    lcd.drawText(410, 15+82, string.format("%d@",(telemetry.homeAngle - 180) < 0 and telemetry.homeAngle + 180 or telemetry.homeAngle - 180), MIDSIZE+0+CUSTOM_COLOR)
    -- HDG
    lcd.setColor(CUSTOM_COLOR,0x0000)
    lcd.drawText(410, 15+110, "Heading", SMLSIZE+0+CUSTOM_COLOR)
    lcd.setColor(CUSTOM_COLOR,0xFFFF)
    lcd.drawText(410, 15+122, string.format("%d@",telemetry.yaw), MIDSIZE+0+CUSTOM_COLOR)
    -- home
    lcd.setColor(CUSTOM_COLOR,0xFE60)
    drawRArrow(410+28,15+175,22,math.floor(telemetry.homeAngle - telemetry.yaw),CUSTOM_COLOR)
end

return {
  drawNumberWithDim=drawNumberWithDim,
  drawHomeIcon=drawHomeIcon,
  drawHArrow=drawHArrow,
  drawVArrow=drawVArrow,
  drawRArrow=drawRArrow,
  drawGauge=drawGauge,
  drawBar=drawBar,
  updateBar=updateBar,
  drawMinMaxBar=drawMinMaxBar,
  drawGraph=drawGraph,
  updateGraph=updateGraph,
  resetGraph=resetGraph,
  computeOutCode=computeOutCode,
  drawLineWithClippingXY=drawLineWithClippingXY,
  drawLineWithClipping=drawLineWithClipping,
  drawFailsafe=drawFailsafe,
  drawArmStatus=drawArmStatus,
  drawNoTelemetryData=drawNoTelemetryData,
  drawStatusBar=drawStatusBar,
  drawFilledRectangle=drawFilledRectangle,
  drawCompassRibbon=drawCompassRibbon,
  yawRibbonPoints=yawRibbonPoints,
  drawFenceStatus=drawFenceStatus,
  drawTerrainStatus=drawTerrainStatus,
  drawCustomSensors=drawCustomSensors,
  drawWindArrow=drawWindArrow,
  drawLeftRightTelemetry=drawLeftRightTelemetry,
}

