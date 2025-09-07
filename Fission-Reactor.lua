local CFG = {
  adapterName = "Reactor Logic Adapter_0",
  title = "Mekanism Fusion Control",
  poll = 0.25,
  maxInjection = 98,
  minInjection = 2,
  allowOff = true,
  monitorScale = {large=0.5, medium=0.75, small=1},
  colors = {
    frame = colors.lightBlue,
    title = colors.cyan,
    subtitle = colors.lightGray,
    panelStroke = colors.lightBlue,
    controlBarBg = colors.gray,
    controlBarFill = colors.white,
    energyLow = colors.red,
    energyHigh = colors.green,
    tempFuel = colors.lightBlue,
    tempCase = colors.yellow,
    btnOn = colors.green,
    btnOff = colors.red,
    btn = colors.gray,
    text = colors.white,
    textDim = colors.lightGray,
    bg = colors.black
  },
  lang = {
    adapter = "Adapter",
    controlLevel = "Control Level",
    energyBuffer = "Energy Buffer",
    temperatures = "Temperatures",
    fuel = "Fuel",
    case = "Case",
    controls = "Reactor Controls",
    on = "On",
    off = "Off",
    bufferTarget = "Buffer Target Range",
    min = "Min",
    max = "Max",
    plus10 = "+10",
    minus10 = "-10",
    injection = "Injection",
    set = "set",
    autoReg = "Auto-Reg",
    status = "Status",
    ignited = "Ignited",
    cold = "Cold",
    producing = "Producing",
    water = "Water",
    steam = "Steam",
    dtfuel = "DT-Fuel",
    deuterium = "Deuterium",
    tritium = "Tritium",
    plasma = "Plasma",
    caseHeat = "Case",
    newRate = "Neue Injection Rate",
    ended = "Beendet."
  }
}

local rla = peripheral.wrap(CFG.adapterName)
if not rla then error(CFG.adapterName.." nicht gefunden") end

local mon = peripheral.find("monitor")
local native = term.current()
local function use(tgt) if tgt then term.redirect(tgt) else term.redirect(native) end term.setBackgroundColor(CFG.colors.bg) term.setTextColor(CFG.colors.text) term.clear() term.setCursorPos(1,1) end
use(mon)

local w,h = term.getSize()
if mon then
  if w >= 120 then mon.setTextScale(CFG.monitorScale.large) elseif w >= 80 then mon.setTextScale(CFG.monitorScale.medium) else mon.setTextScale(CFG.monitorScale.small) end
  use(mon) w,h = term.getSize()
end

local ui = {}
local function rect(x1,y1,x2,y2,bg) term.setBackgroundColor(bg) paintutils.drawFilledBox(x1,y1,x2,y2,bg) term.setBackgroundColor(CFG.colors.bg) end
local function text(x,y,s,fg) term.setTextColor(fg or CFG.colors.text) term.setCursorPos(x,y) term.write(s) term.setTextColor(CFG.colors.text) end
local function center(y,s,fg) local X=math.max(1,math.floor((w-#s)/2)+1) text(X,y,s,fg) end
local function button(id,x1,y1,x2,y2,label,bg,fg) rect(x1,y1,x2,y2,bg) local cx=math.floor((x1+x2-#label)/2) text(cx,y1+math.floor((y2-y1)/2),label,fg) ui[id]={x1=x1,y1=y1,x2=x2,y2=y2} end
local function hit(id,x,y) local b=ui[id]; return b and x>=b.x1 and x<=b.x2 and y>=b.y1 and y<=b.y2 end
local function barV(x,y,hgt,ratio,colBg,colFill) rect(x,y,x+10,y+hgt,colBg) local fill=math.floor(hgt*math.max(0,math.min(1,ratio))) if fill>0 then rect(x+1,y+hgt-fill+1,x+9,y+hgt-1,colFill) end end
local function fmt(n,u) if type(n)~="number" then return "n/a" end local a=math.abs(n) if a>=1e12 then return string.format("%.2fT",n/1e12)..(u or "") end if a>=1e9 then return string.format("%.2fG",n/1e9)..(u or "") end if a>=1e6 then return string.format("%.2fM",n/1e6)..(u or "") end if a>=1e3 then return string.format("%.2fk",n/1e3)..(u or "") end return string.format("%.0f",n)..(u or "") end

local inj = rla.getInjectionRate() or 0
local lastNonZero = inj>0 and inj or CFG.minInjection
local targetMin = 0.30
local targetMax = 0.80
local autoReg = true

local function drawFrame()
  rect(1,1,w,h,CFG.colors.bg)
  paintutils.drawLine(2,3,w-1,3,CFG.colors.frame)
  paintutils.drawLine(2,h-2,w-1,h-2,CFG.colors.frame)
  center(1,CFG.title,CFG.colors.title)
  center(2,CFG.lang.adapter..": "..CFG.adapterName,CFG.colors.subtitle)
end

local function drawPanels(eNow,eMax,pHeat,pMax,cHeat,cMax,prod)
  local gx=3
  local gh=h-10
  rect(gx,5,gx+14,gh+5,CFG.colors.controlBarFill)
  text(gx,4,CFG.lang.controlLevel,colors.yellow)
  local clRatio=(rla.getInjectionRate() or 0)/CFG.maxInjection
  barV(gx+2,6,gh-2,clRatio,CFG.colors.controlBarBg,CFG.colors.controlBarFill)
  text(gx,gh+6,string.format("%.1f%%",clRatio*100),CFG.colors.textDim)

  local ex=gx+20
  rect(ex,5,ex+20,gh+5,CFG.colors.controlBarBg)
  text(ex,4,CFG.lang.energyBuffer,colors.orange)
  local eratio=(eMax>0) and (eNow/eMax) or 0
  local midY=6+math.floor((gh-2)*(1-eratio))
  rect(ex+2,midY,ex+18,gh-1,CFG.colors.energyHigh)
  rect(ex+2,6,ex+18,midY-1,CFG.colors.energyLow)
  text(ex,gh+6,fmt(eNow,"J").."  "..string.format("%.1f%%",eratio*100),CFG.colors.textDim)

  local tx=ex+26
  text(tx,4,CFG.lang.temperatures,CFG.colors.title)
  rect(tx,5,tx+12,gh+5,CFG.colors.bg)
  rect(tx+2,6,tx+10,gh-1,CFG.colors.controlBarBg)
  rect(tx+16,6,tx+24,gh-1,CFG.colors.controlBarBg)
  local pr=(pMax and pMax>0) and (pHeat/pMax) or 0
  local cr=(cMax and cMax>0) and (cHeat/cMax) or 0
  barV(tx+2,6,gh-2,pr,CFG.colors.controlBarBg,CFG.colors.tempFuel)
  barV(tx+16,6,gh-2,cr,CFG.colors.controlBarBg,CFG.colors.tempCase)
  text(tx+1,gh+6,CFG.lang.fuel,CFG.colors.tempFuel)
  text(tx+15,gh+6,CFG.lang.case,CFG.colors.tempCase)

  local ctrlX=w-28
  rect(ctrlX,5,w-2,gh+5,CFG.colors.bg)
  paintutils.drawBox(ctrlX,5,w-2,gh+5,CFG.colors.panelStroke)
  text(ctrlX+2,6,CFG.lang.controls,CFG.colors.text)
  button("on",ctrlX+2,8,ctrlX+12,10,CFG.lang.on,CFG.colors.btnOn,CFG.colors.bg)
  button("off",ctrlX+14,8,w-4,10,CFG.lang.off,CFG.colors.btnOff,CFG.colors.bg)
  text(ctrlX+2,12,CFG.lang.bufferTarget,CFG.colors.text)
  rect(ctrlX+2,13,w-4,15,CFG.colors.bg)
  rect(ctrlX+2,16,w-4,18,CFG.colors.controlBarBg)
  local rbw=(w-6-(ctrlX+2))
  local rl=ctrlX+2+math.floor(rbw*targetMin)
  local rr=ctrlX+2+math.floor(rbw*targetMax)
  rect(ctrlX+2,16,w-4,18,CFG.colors.energyLow)
  rect(rl,16,rr,18,CFG.colors.energyHigh)
  text(ctrlX+2,19,CFG.lang.min,CFG.colors.text)
  button("minp",ctrlX+7,19,ctrlX+11,19,CFG.lang.plus10,CFG.colors.btn,CFG.colors.bg)
  button("minm",ctrlX+13,19,ctrlX+17,19,CFG.lang.minus10,CFG.colors.btn,CFG.colors.bg)
  text(ctrlX+19,19,tostring(math.floor(targetMin*100)).."%",CFG.colors.text)
  text(ctrlX+2,21,CFG.lang.max,CFG.colors.text)
  button("maxp",ctrlX+7,21,ctrlX+11,21,CFG.lang.plus10,CFG.colors.btn,CFG.colors.bg)
  button("maxm",ctrlX+13,21,ctrlX+17,21,CFG.lang.minus10,CFG.colors.btn,CFG.colors.bg)
  text(ctrlX+19,21,tostring(math.floor(targetMax*100)).."%",CFG.colors.text)
  text(ctrlX+2,23,CFG.lang.injection,CFG.colors.text)
  button("injm10",ctrlX+2,24,ctrlX+6,24,CFG.lang.minus10,CFG.colors.btn,CFG.colors.bg)
  button("injm1",ctrlX+7,24,ctrlX+10,24,"-1",CFG.colors.btn,CFG.colors.bg)
  button("injp1",ctrlX+11,24,ctrlX+14,24,"+1",CFG.colors.btn,CFG.colors.bg)
  button("injp10",ctrlX+15,24,ctrlX+19,24,CFG.lang.plus10,CFG.colors.btn,CFG.colors.bg)
  button("injs",ctrlX+21,24,w-4,24,CFG.lang.set,CFG.colors.btn,CFG.colors.bg)
  text(ctrlX+2,26,CFG.lang.autoReg,CFG.colors.text)
  button("auto",ctrlX+12,26,w-4,26,autoReg and CFG.lang.on or CFG.lang.off,autoReg and CFG.colors.btnOn or CFG.colors.btnOff,CFG.colors.bg)
  text(ctrlX+2,28,CFG.lang.status,CFG.colors.text)
  local ign = rla.isIgnited and rla.isIgnited() or false
  text(ctrlX+2,29,ign and CFG.lang.ignited or CFG.lang.cold,ign and CFG.colors.btnOn or CFG.colors.textDim)
  text(ctrlX+2,30,CFG.lang.producing..": "..fmt(prod,"J/t"),CFG.colors.text)
  text(ctrlX+2,31,CFG.lang.injection..": "..tostring(inj),CFG.colors.text)
end

local function drawStats(eNow,eMax,water,steam,fuel,deu,tri,pHeat,pMax,cHeat,cMax)
  local y=h-1
  paintutils.drawLine(2,y,w-1,y,CFG.colors.frame)
  local s1=CFG.lang.water.." "..fmt(water).."  "..CFG.lang.steam.." "..fmt(steam).."  "..CFG.lang.dtfuel.." "..fmt(fuel).."  "..CFG.lang.deuterium.." "..fmt(deu).."  "..CFG.lang.tritium.." "..fmt(tri)
  local s2=CFG.lang.plasma.." "..fmt(pHeat,"K").."/"..fmt(pMax,"K").."  "..CFG.lang.caseHeat.." "..fmt(cHeat,"K").."/"..fmt(cMax,"K")
  text(2,h-0,s1,CFG.colors.textDim)
  text(2,h-2,s2,CFG.colors.textDim)
end

local function readNumber(prompt,def)
  if mon then use(nil) end
  term.clear() term.setCursorPos(1,1) term.setTextColor(CFG.colors.title) print(prompt.." ("..def.."):")
  term.setTextColor(CFG.colors.text)
  local s=read() local n=tonumber(s) if not n then n=def end
  if mon then use(mon) end
  return n
end

local function clampInj(v)
  v=math.floor(v+0.5)
  if v<=0 then return CFG.allowOff and 0 or CFG.minInjection end
  if v>0 and v<CFG.minInjection then return CFG.minInjection end
  if v>CFG.maxInjection then return CFG.maxInjection end
  return v
end

local function setInj(v)
  v=clampInj(v)
  local ok=pcall(function() rla.setInjectionRate(v) end)
  if ok then inj=v if v>0 then lastNonZero=v end end
end

local function stepAuto(eratio)
  if not autoReg then return end
  if eratio < targetMin then setInj(inj+1) elseif eratio > targetMax then setInj(inj-1) end
end

local function drawAll()
  local prod = rla.getProducing() or 0
  local eNow = rla.getEnergy() or 0
  local eMax = rla.getMaxEnergy() or 0
  local water = rla.getWater() or 0
  local steam = rla.getSteam() or 0
  local fuel = rla.getFuel() or 0
  local deu = rla.getDeuterium() or 0
  local tri = rla.getTritium() or 0
  local pHeat = rla.getPlasmaHeat and (rla.getPlasmaHeat() or 0) or 0
  local pMax = rla.getMaxPlasmaHeat and (rla.getMaxPlasmaHeat() or 0) or 0
  local cHeat = rla.getCaseHeat and (rla.getCaseHeat() or 0) or 0
  local cMax = rla.getMaxCaseHeat and (rla.getMaxCaseHeat() or 0) or 0
  inj = rla.getInjectionRate() or inj
  drawFrame()
  drawPanels(eNow,eMax,pHeat,pMax,cHeat,cMax,prod)
  drawStats(eNow,eMax,water,steam,fuel,deu,tri,pHeat,pMax,cHeat,cMax)
  return eNow,eMax
end

drawAll()
local tmr=os.startTimer(CFG.poll)
while true do
  local ev={os.pullEvent()}
  if ev[1]=="monitor_touch" and mon and ev[2]==peripheral.getName(mon) then
    local x,y=ev[3],ev[4]
    if hit("on",x,y) then setInj(lastNonZero>0 and lastNonZero or CFG.minInjection) drawAll() end
    if hit("off",x,y) and CFG.allowOff then setInj(0) drawAll() end
    if hit("minp",x,y) then targetMin=math.min(targetMin+0.10,0.9) if targetMin>targetMax then targetMax=targetMin end drawAll() end
    if hit("minm",x,y) then targetMin=math.max(targetMin-0.10,0) if targetMin>targetMax then targetMax=targetMin end drawAll() end
    if hit("maxp",x,y) then targetMax=math.min(targetMax+0.10,1) if targetMax<targetMin then targetMin=targetMax end drawAll() end
    if hit("maxm",x,y) then targetMax=math.max(targetMax-0.10,0.1) if targetMax<targetMin then targetMin=targetMax end drawAll() end
    if hit("injm10",x,y) then setInj(inj-10) drawAll() end
    if hit("injm1",x,y) then setInj(inj-1) drawAll() end
    if hit("injp1",x,y) then setInj(inj+1) drawAll() end
    if hit("injp10",x,y) then setInj(inj+10) drawAll() end
    if hit("injs",x,y) then local n=readNumber(CFG.lang.newRate,inj) setInj(n) drawAll() end
    if hit("auto",x,y) then autoReg=not autoReg drawAll() end
  elseif ev[1]=="char" then
    if ev[2]=="q" then break end
  elseif ev[1]=="timer" and ev[2]==tmr then
    local eNow,eMax=drawAll()
    local er=(eMax>0) and (eNow/eMax) or 0
    stepAuto(er)
    tmr=os.startTimer(CFG.poll)
  elseif ev[1]=="terminate" then break end
end

use(nil) term.clear() term.setCursorPos(1,1) print(CFG.lang.ended)
