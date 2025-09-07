[07Sept.2025 00:00:20.034] [Render thread/INFO] [net.minecraft.client.Minecraft/]: Stopping!
local function findRLA()
  local p = {peripheral.getNames()}
  for _,name in ipairs(p) do
    local w = peripheral.wrap(name)
    if type(w)=="table" and w.getInjectionRate and w.setInjectionRate and w.getProducing then
      return w,name
    end
  end
  error("Reactor Logic Adapter nicht gefunden")
end

local function findMonitor()
  local m = peripheral.find("monitor")
  if not m then return nil end
  m.setTextScale(0.5)
  return m
end

local rla,rlaName = findRLA()
local mon = findMonitor()
local native = term.current()
local t,w,h

local function useTerm(dest)
  if dest then term.redirect(dest) else term.redirect(native) end
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
  term.clear()
  term.setCursorPos(1,1)
  w,h = term.getSize()
end

useTerm(mon)

local function shortNum(n,unit)
  if type(n)~="number" then return "n/a" end
  local a = math.abs(n)
  local s,u = n,""
  if a>=1e12 then s = string.format("%.2f", n/1e12) u="T"
  elseif a>=1e9 then s = string.format("%.2f", n/1e9) u="G"
  elseif a>=1e6 then s = string.format("%.2f", n/1e6) u="M"
  elseif a>=1e3 then s = string.format("%.2f", n/1e3) u="k"
  else s = string.format("%.0f", n) u="" end
  return s..u..(unit or "")
end

local function bar(x,y,ww,ratio,col)
  ratio = math.max(0, math.min(1, ratio or 0))
  paintutils.drawFilledBox(x,y,x+ww-1,y, colors.gray)
  local fill = math.floor(ww*ratio+0.5)
  if fill>0 then
    term.setBackgroundColor(col)
    paintutils.drawFilledBox(x,y,x+fill-1,y, col)
    term.setBackgroundColor(colors.black)
  end
end

local function center(y,textLine,col)
  local tx = tostring(textLine)
  local x = math.max(1, math.floor((w-#tx)/2)+1)
  if col then term.setTextColor(col) end
  term.setCursorPos(x,y)
  term.write(tx)
  term.setTextColor(colors.white)
end

local function label(x,y,k,v,unit)
  term.setCursorPos(x,y)
  term.setTextColor(colors.lightGray)
  term.write(k..": ")
  term.setTextColor(colors.white)
  term.write(v and tostring(v)..(unit or "") or "n/a")
end

local function drawButton(x,y,txt,active)
  term.setCursorPos(x,y)
  term.setBackgroundColor(active and colors.green or colors.gray)
  term.setTextColor(colors.black)
  term.write(" "..txt.." ")
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
end

local function readNumber(prompt,def)
  if mon then useTerm(nil) end
  term.clear()
  term.setCursorPos(1,1)
  term.setTextColor(colors.cyan)
  print(prompt.." (Enter für "..tostring(def).."):")
  term.setTextColor(colors.white)
  local s = read()
  local n = tonumber(s)
  if not n then n = def end
  if mon then useTerm(mon) end
  return n
end

local inj = rla.getInjectionRate() or 0
local lastTouch = 0
local running = true
local pollMs = 500

local function draw()
  term.clear()
  local okIgnited = rla.isIgnited and rla.isIgnited() or false
  local canIgn = rla.canIgnite and rla.canIgnite() or false
  local prod = rla.getProducing() or 0
  local e = rla.getEnergy() or 0
  local eMax = rla.getMaxEnergy() or 0
  local water = rla.getWater() or 0
  local steam = rla.getSteam() or 0
  local fuel = rla.getFuel() or 0
  local deu = rla.getDeuterium() or 0
  local tri = rla.getTritium() or 0
  local pHeat = rla.getPlasmaHeat and rla.getPlasmaHeat() or 0
  local pMax = rla.getMaxPlasmaHeat and rla.getMaxPlasmaHeat() or 0
  local cHeat = rla.getCaseHeat and rla.getCaseHeat() or 0
  local cMax = rla.getMaxCaseHeat and rla.getMaxCaseHeat() or 0
  inj = rla.getInjectionRate() or inj

  center(1,"Mekanism Fusion Control",colors.cyan)
  center(2,"Adapter: "..rlaName,colors.lightGray)

  local y = 4
  label(2,y,"Status", okIgnited and "Ignited" or (canIgn and "Ready" or "Cold")); y=y+1
  label(2,y,"Produktion", shortNum(prod,"J/t")); y=y+1
  label(2,y,"Energie", shortNum(e,"J").." / "..shortNum(eMax,"J")); y=y+1
  bar(2,y,w-3, eMax>0 and (e/eMax) or 0, colors.green); y=y+2
  label(2,y,"Wasser", shortNum(water)); y=y+1
  label(2,y,"Dampf", shortNum(steam)); y=y+1
  label(2,y,"DT-Fuel", shortNum(fuel)); y=y+1
  label(2,y,"Deuterium", shortNum(deu)); y=y+1
  label(2,y,"Tritium", shortNum(tri)); y=y+2
  label(2,y,"Plasma Heat", shortNum(pHeat,"K").." / "..shortNum(pMax,"K")); y=y+1
  bar(2,y,w-3, pMax>0 and (pHeat/pMax) or 0, colors.orange); y=y+2
  label(2,y,"Case Heat", shortNum(cHeat,"K").." / "..shortNum(cMax,"K")); y=y+1
  bar(2,y,w-3, cMax>0 and (cHeat/cMax) or 0, colors.yellow); y=y+2

  local btnY = h-2
  term.setCursorPos(2,btnY); term.setTextColor(colors.lightGray); term.write("Injection Rate: ")
  term.setTextColor(colors.white); term.write(tostring(inj))
  local b1x = w-24
  drawButton(b1x,btnY," -10 ",false)
  drawButton(b1x+6,btnY," -1 ",false)
  drawButton(b1x+11,btnY," +1 ",false)
  drawButton(b1x+16,btnY," +10 ",false)
  drawButton(2,h,"  s:Set  ",false)
  drawButton(13,h,"  q:Quit ",false)
end

local function applyRate(newRate)
  newRate = math.max(0, math.floor(newRate))
  local ok,err = pcall(function() rla.setInjectionRate(newRate) end)
  if ok then inj = newRate end
end

local function handleTouch(x,y)
  local btnY = h-2
  if y==btnY then
    local b1x = w-24
    if x>=b1x and x<=b1x+5 then applyRate(inj-10) return end
    if x>=b1x+6 and x<=b1x+10 then applyRate(inj-1) return end
    if x>=b1x+11 and x<=b1x+14 then applyRate(inj+1) return end
    if x>=b1x+16 and x<=b1x+20 then applyRate(inj+10) return end
  elseif y==h then
    if x>=2 and x<=10 then
      local n = readNumber("Neue Injection Rate", inj)
      applyRate(n)
      return
    end
    if x>=13 and x<=21 then running=false return end
  end
end

local function loop()
  draw()
  while running do
    local e = {os.pullEventRaw()}
    if e[1]=="terminate" then running=false
    elseif e[1]=="timer" then draw()
    elseif e[1]=="monitor_touch" and mon and e[2]==peripheral.getName(mon) then handleTouch(e[3],e[4]); draw()
    elseif e[1]=="char" then
      local c = e[2]
      if c=="q" then running=false
      elseif c=="+" then applyRate(inj+1); draw()
      elseif c=="-" then applyRate(inj-1); draw()
      elseif c=="[" then applyRate(inj-10); draw()
      elseif c=="]" then applyRate(inj+10); draw()
      elseif c=="s" then local n = readNumber("Neue Injection Rate", inj); applyRate(n); draw()
      end
    end
    os.startTimer(pollMs/1000)
  end
end

loop()
useTerm(nil)
term.clear()
term.setCursorPos(1,1)
print("Beendet.")
