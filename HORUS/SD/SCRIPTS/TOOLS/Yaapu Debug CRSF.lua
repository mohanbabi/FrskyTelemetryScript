local logfilename
local logfile
local flushtime = getTime()
local MAX_MESSAGES = 17

local mavSeverity = {}
mavSeverity[0]="EMR"
mavSeverity[1]="ALR"
mavSeverity[2]="CRT"
mavSeverity[3]="ERR"
mavSeverity[4]="WRN"
mavSeverity[5]="NOT"
mavSeverity[6]="INF"
mavSeverity[7]="DBG"

local status = {}
-- MESSAGES
status.messages = {}
status.msgBuffer = ""
status.lastMsgValue = 0
status.lastMsgTime = 0
status.lastMessage = nil
status.lastMessageSeverity = 0
status.lastMessageCount = 1
status.messageCount = 0

local function getLogFilename()
  local datenow = getDateTime()  
  local info = model.getInfo()
  local modelName = string.lower(string.gsub(info.name, "[%c%p%s%z]", ""))
  return modelName..string.format("-%04d%02d%02d_%02d%02d%02d.clog", datenow.year, datenow.mon, datenow.day, datenow.hour, datenow.min, datenow.sec)
end

local function formatMessage(severity,msg)
  local clippedMsg = msg
  
  if #msg > 50 then
    clippedMsg = string.sub(msg,1,50)
    msg = nil
    collectgarbage()
    collectgarbage()
  end
  
  if status.lastMessageCount > 1 then
    return string.format("%02d:%s (x%d) %s", status.messageCount, mavSeverity[severity], status.lastMessageCount, clippedMsg)
  else
    return string.format("%02d:%s %s", status.messageCount, mavSeverity[severity], clippedMsg)
  end
end

local function pushMessage(severity, msg)
  if msg == status.lastMessage then
    status.lastMessageCount = status.lastMessageCount + 1
  else  
    status.lastMessageCount = 1
    status.messageCount = status.messageCount + 1
  end
  if status.messages[(status.messageCount-1) % MAX_MESSAGES] == nil then
    status.messages[(status.messageCount-1) % MAX_MESSAGES] = {}
  end
  status.messages[(status.messageCount-1) % MAX_MESSAGES][1] = formatMessage(severity,msg)
  status.messages[(status.messageCount-1) % MAX_MESSAGES][2] = severity
  
  status.lastMessage = msg
  status.lastMessageSeverity = severity
  -- Collect Garbage
  collectgarbage()
  collectgarbage()
end

local function drawMessageScreen()
  for i=0,#status.messages do
    if  status.messages[(status.messageCount + i) % (#status.messages+1)][2] == 4 then
      lcd.setColor(CUSTOM_COLOR,lcd.RGB(255,255,0))
    elseif status.messages[(status.messageCount + i) % (#status.messages+1)][2] < 4 then
      lcd.setColor(CUSTOM_COLOR,lcd.RGB(255,70,0))  
    else
      lcd.setColor(CUSTOM_COLOR,lcd.RGB(255,255,255))
    end
    lcd.drawText(0,26+13*i, status.messages[(status.messageCount + i) % (#status.messages+1)][1],SMLSIZE+CUSTOM_COLOR)
  end
end

local function processTelemetry(DATA_ID,VALUE)
  if DATA_ID == 0x5000 then -- MESSAGES
    if VALUE ~= status.lastMsgValue then
      status.lastMsgValue = VALUE
      local c
      local msgEnd = false
      for i=3,0,-1
      do
        c = bit32.extract(VALUE,i*8,7)
        if c ~= 0 then
          status.msgBuffer = status.msgBuffer .. string.char(c)
          collectgarbage()
          collectgarbage()
        else
          msgEnd = true;
          break;
        end
      end
      if msgEnd then
        local severity = (bit32.extract(VALUE,7,1) * 1) + (bit32.extract(VALUE,15,1) * 2) + (bit32.extract(VALUE,23,1) * 4)
        pushMessage( severity, status.msgBuffer)
        -- reset hash for next string
        status.msgBuffer = nil
        -- recover memory
        collectgarbage()
        collectgarbage()
        status.msgBuffer = ""
      end
    end
  end
end

local function background()
  for i=1,5
  do
    local command, data = crossfireTelemetryPop()
    if command == 128 and data ~= nil then
      local appid = bit32.lshift(data[2],8) + data[1]
      local value =  bit32.lshift(data[6],24) + bit32.lshift(data[5],16) + bit32.lshift(data[4],8) + data[3]
      pushMessage(7, string.format("%04X:%08X",appid, value))
      
      local log_string = string.format("%02X%02X;%02X%02X%02X%02X", data[2],data[1],data[6],data[5],data[4],data[3])
      io.write(logfile, getTime(), ";", log_string ,"\r\n")             
      
      processTelemetry(appid, value)
    end
  end
  
  if getTime() - flushtime > 50 then
    -- flush
    pcall(io.close,logfile)
    logfile = io.open("/LOGS/"..logfilename,"a")
    
    flushtime = getTime()
  end  
end

local function run(event)
  background()
  
  lcd.setColor(CUSTOM_COLOR, 0x0AB1)
  lcd.clear(CUSTOM_COLOR)
  
  lcd.setColor(CUSTOM_COLOR, 0xFFFF)
  
  drawMessageScreen()
  
  lcd.drawText(1,1,"YAAPU CRSF DEBUG 1.0",MIDSIZE+CUSTOM_COLOR)
  lcd.drawText(1,LCD_H-20,tostring("/LOGS/"..logfilename),CUSTOM_COLOR)
  collectgarbage()
  collectgarbage()
  return 0
end

local function init()
  logfilename = getLogFilename()
  logfile = io.open("/LOGS/"..logfilename,"a")
  --io.write(logfile, "counter;f_time;data_id;value\r\n")  
	pushMessage(7,"READY!")
end

return {run=run, init=init}


