local CFG={
  adapter="Reactor Logic Adapter_0",
  title="Mekanism Fusion Control",
  poll=0.25,
  injMin=2,
  injMax=98,
  allowOff=true,
  scale={xl=0.5,l=0.75,m=1,s=1.5},
  col={
    bg=colors.black, frame=colors.lightBlue, title=colors.cyan, sub=colors.lightGray,
    text=colors.white, dim=colors.gray, ok=colors.green, bad=colors.red,
    accent=colors.yellow, fuel=colors.lightBlue, case=colors.yellow, bar=colors.gray
  },
  lang={
    adapter="Adapter", control="Control Level", energy="Energy Buffer", temps="Temperatures",
    fuel="Fuel", case="Case", controls="Reactor Controls", on="On", off="Off",
    range="Buffer Target Range", min="Min", max="Max", p10="+10", m10="-10",
    inj="Injection", set="set", auto="Auto", status="Status", ignited="Ignited", cold="Cold",
    producing="Producing", water="Water", steam="Steam", dt="DT-Fuel", d="Deuterium", t="Tritium",
    plasma="Plasma", ended="Beendet.", prompt="Neue Injection Rate"
  }
}

local rla=peripheral.wrap(CFG.adapter) if not rla then error("Adapter nicht gefunden") end
local mon=peripheral.find("monitor")
local native=term.current()
local function use(t) if t then term.redirect(t) else term.redirect(native) end term.setBackgroundColor(CFG.col.bg) term.setTextColor(CFG.col.text) term.clear() term.setCursorPos(1,1) end
use(mon)
if mon then
  local mw,mh=term.getSize()
  if mw>=120 then mon.setTextScale(CFG.scale.xl)
  elseif mw>=84 then mon.setTextScale(CFG.scale.l)
  elseif mw>=60 then mon.setTextScale(CFG.scale.m)
  else mon.setTextScale(CFG.scale.s) end
  use(mon)
end
local W,H=term.getSize()

local UI={}
local function rect(x1,y1,x2,y2,c) term.setBackgroundColor(c) paintutils.drawFilledBox(x1,y1,x2,y2,c) term.setBackgroundColor(CFG.col.bg) end
local function border(x1,y1,x2,y2,c) paintutils.drawBox(x1,y1,x2,y2,c) end
local function txt(x,y,s,c) term.setTextColor(c or CFG.col.text) term.setCursorPos(x,y) term.write(s) term.setTextColor(CFG.col.text) end
local function center(y,s,c) local x=math.max(1,math.floor((W-#s)/2)+1) txt(x,y,s,c) end
local function btn(id,x1,y1,x2,y2,label,bg,fg) rect(x1,y1,x2,y2,bg) local cx=math.floor((x1+x2-#label)/2) txt(cx, y1, label, fg) UI[id]={x1=x1,y1=y1,x2=x2,y2=y2} end
local function hit(id,x,y) local b=UI[id]; return b and x>=b.x1 and x<=b.x2 and y>=b.y1 and y<=b.y2 end
local function clamp(v,a,b) if v<a then return a elseif v>b then return b else return v end end
local function fmt(n,u) if type(n)~="number" then return "n/a" end local a=math.abs(n)
  if a>=1e12 then return string.format("%.2fT",n/1e12)..(u or "") end
  if a>=1e9 then return string.format("%.2fG",n/1e9)..(u or "") end
  if a>=1e6 then return string.format("%.2fM",n/1e6)..(u or "") end
  if a>=1e3 then return string.format("%.2fk",n/1e3)..(u or "") end
  return string.format("%.0f",n)..(u or "")
end

local inj=rla.getInjectionRate() or 0
local lastNonZero=inj>0 and inj or CFG.injMin
local auto=true
local targetMin, targetMax = 0.30, 0.80

local M=2
local G=2
local rightW=math.max(28, math.floor(W*0.28))
local leftW=math.floor((W - (M*2) - rightW - (G*3)) / 3)
local graphH=H-11
local xL=M
local xC=xL+leftW+G
local xR=xC+leftW+G
local xCtrl=W-rightW-M+1
local yTop=5
local yBot=yTop+graphH-1

local function injClamp(v)
  v=math.floor(v+0.5)
  if v<=0 then if CFG.allowOff then return 0 else return CFG.injMin end end
  if v>0 and v<CFG.injMin then return CFG.injMin end
  return clamp(v,0,CFG.injMax)
end
local function injSet(v)
  v=injClamp(v)
  local ok=pcall(function() rla.setInjectionRate(v) end)
  if ok then inj=v if v>0 then lastNonZero=v end end
end

local function drawHeader()
  rect(1,1,W,H,CFG.col.bg)
  border(1,1,W,H,CFG.col.frame)
  center(2,CFG.title,CFG.col.title)
  center(3,CFG.lang.adapter..": "..CFG.adapter,CFG.col.sub)
  paintutils.drawLine(M,4,W-M,4,CFG.col.frame)
end

local function barV(x,yTop,yBot,ratio,bg,fill)
  ratio=clamp(ratio,0,1)
  rect(x,yTop,x+12,yBot,bg)
  if ratio>0 then
    local h=yBot-yTop+1
    local fh=math.max(1, math.floor(h*ratio+0.5))
    rect(x+1, yBot-fh+1, x+11, yBot-1, fill)
  end
end

local function drawGraphs(eNow,eMax,pHeat,pMax,cHeat,cMax)
  txt(xL, yTop-1, CFG.lang.control, CFG.col.accent)
  rect(xL, yTop, xL+leftW-1, yBot, CFG.col.dim)
  local cRatio=(rla.getInjectionRate() or 0)/CFG.injMax
  barV(xL+2, yTop+1, yBot-1, cRatio, CFG.col.dim, colors.white)
  txt(xL, yBot+1, string.format("%.1f%%", cRatio*100), CFG.col.sub)

  txt(xC, yTop-1, CFG.lang.energy, CFG.col.accent)
  rect(xC, yTop, xC+leftW-1, yBot, CFG.col.dim)
  local eRatio = (eMax>0) and (eNow/eMax) or 0
  local mid = yTop + math.floor((yBot-yTop+1) * (1-eRatio))
  rect(xC+2, yTop+1, xC+leftW-3, mid-1, CFG.col.bad)
  rect(xC+2, mid, xC+leftW-3, yBot-1, CFG.col.ok)
  txt(xC, yBot+1, fmt(eNow,"J").."  "..string.format("%.1f%%",eRatio*100), CFG.col.sub)

  txt(xR, yTop-1, CFG.lang.temps, CFG.col.accent)
  rect(xR, yTop, xR+leftW-1, yBot, CFG.col.bg)
  rect(xR+2, yTop+1, xR+13, yBot-1, CFG.col.dim)
  rect(xR+leftW-14, yTop+1, xR+leftW-3, yBot-1, CFG.col.dim)
  local pr=(pMax and pMax>0) and (pHeat/pMax) or 0
  local cr=(cMax and cMax>0) and (cHeat/cMax) or 0
  barV(xR+2, yTop+1, yBot-1, pr, CFG.col.dim, CFG.col.fuel)
  barV(xR+leftW-14, yTop+1, yBot-1, cr, CFG.col.dim, CFG.col.case)
  txt(xR+2, yBot+1, CFG.lang.fuel, CFG.col.fuel)
  txt(xR+leftW-14, yBot+1, CFG.lang.case, CFG.col.case)
end

local function drawControls(prod)
  local bx=xCtrl; local by=yTop
  border(bx,by,W-M,yBot,CFG.col.frame)
  txt(bx+2,by,CFG.lang.controls,CFG.col.text)
  btn("on",  bx+2, by+2, bx+11, by+2, CFG.lang.on,  CFG.col.ok, CFG.col.bg)
  btn("off", bx+13,by+2, bx+22, by+2, CFG.lang.off, CFG.col.bad, CFG.col.bg)

  txt(bx+2, by+4, CFG.lang.range, CFG.col.text)
  rect(bx+2,by+5,W-M-1,by+5,CFG.col.bg)
  local barY=by+6
  rect(bx+2,barY,W-M-1,barY,CFG.col.bad)
  local bw=(W-M-1)-(bx+2)
  local rl=bx+2+math.floor(bw*targetMin)
  local rr=bx+2+math.floor(bw*targetMax)
  paintutils.drawLine(rl,barY,rr,barY,CFG.col.ok)
  txt(bx+2,by+7,CFG.lang.min,CFG.col.text)
  btn("minp",bx+7,by+7,bx+11,by+7,CFG.lang.p10,CFG.col.dim,CFG.col.bg)
  btn("minm",bx+13,by+7,bx+17,by+7,CFG.lang.m10,CFG.col.dim,CFG.col.bg)
  txt(bx+19,by+7,string.format("%d%%",math.floor(targetMin*100)),CFG.col.text)

  txt(bx+2,by+9,CFG.lang.max,CFG.col.text)
  btn("maxp",bx+7,by+9,bx+11,by+9,CFG.lang.p10,CFG.col.dim,CFG.col.bg)
  btn("maxm",bx+13,by+9,bx+17,by+9,CFG.lang.m10,CFG.col.dim,CFG.col.bg)
  txt(bx+19,by+9,string.format("%d%%",math.floor(targetMax*100)),CFG.col.text)

  txt(bx+2,by+11,CFG.lang.inj,CFG.col.text)
  btn("injm10",bx+2,by+12,bx+6,by+12,CFG.lang.m10,CFG.col.dim,CFG.col.bg)
  btn("injm1", bx+8,by+12,bx+10,by+12,"-1",CFG.col.dim,CFG.col.bg)
  btn("injp1", bx+12,by+12,bx+14,by+12,"+1",CFG.col.dim,CFG.col.bg)
  btn("injp10",bx+16,by+12,bx+20,by+12,CFG.lang.p10,CFG.col.dim,CFG.col.bg)
  btn("injs",  bx+22,by+12,W-M-1,by+12,CFG.lang.set,CFG.col.dim,CFG.col.bg)

  txt(bx+2,by+14,CFG.lang.auto,CFG.col.text)
  btn("auto",bx+10,by+14,W-M-1,by+14,auto and CFG.lang.on or CFG.lang.off, auto and CFG.col.ok or CFG.col.bad, CFG.col.bg)

  txt(bx+2,by+16,CFG.lang.status,CFG.col.text)
  local ign=rla.isIgnited and rla.isIgnited() or false
  txt(bx+2,by+17, ign and CFG.lang.ignited or CFG.lang.cold, ign and CFG.col.ok or CFG.col.sub)
  txt(bx+2,by+18, CFG.lang.producing..": "..fmt(prod,"J/t"), CFG.col.text)
  txt(bx+2,by+19, CFG.lang.inj..": "..tostring(inj), CFG.col.text)
end

local function drawFooter(water,steam,fuel,deu,tri,pHeat,pMax,cHeat,cMax)
  paintutils.drawLine(M,H-2,W-M,H-2,CFG.col.frame)
  txt(M,H-1, CFG.lang.plasma.." "..fmt(pHeat,"K").."/"..fmt(pMax,"K").."  "..CFG.lang.case.." "..fmt(cHeat,"K").."/"..fmt(cMax,"K"), CFG.col.sub)
  txt(M,H,   CFG.lang.water.." "..fmt(water).."  "..CFG.lang.steam.." "..fmt(steam).."  "..CFG.lang.dt.." "..fmt(fuel).."  "..CFG.lang.d.." "..fmt(deu).."  "..CFG.lang.t.." "..fmt(tri), CFG.col.sub)
end

local function promptNumber(prompt,def)
  if mon then use(nil) end
  term.clear() term.setCursorPos(1,1) txt(1,1,prompt.." ("..def.."):",CFG.col.title)
  term.setTextColor(CFG.col.text)
  local s=read() local n=tonumber(s) if not n then n=def end
  if mon then use(mon) end
  return n
end

local function autoStep(er)
  if not auto then return end
  if er<targetMin then injSet(inj+1) elseif er>targetMax then injSet(inj-1) end
end

local function drawAll()
  local prod=rla.getProducing() or 0
  local eNow=rla.getEnergy() or 0
  local eMax=rla.getMaxEnergy() or 0
  local water=rla.getWater() or 0
  local steam=rla.getSteam() or 0
  local fuel=rla.getFuel() or 0
  local deu=rla.getDeuterium() or 0
  local tri=rla.getTritium() or 0
  local pHeat=rla.getPlasmaHeat and (rla.getPlasmaHeat() or 0) or 0
  local pMax=rla.getMaxPlasmaHeat and (rla.getMaxPlasmaHeat() or 0) or 0
  local cHeat=rla.getCaseHeat and (rla.getCaseHeat() or 0) or 0
  local cMax=rla.getMaxCaseHeat and (rla.getMaxCaseHeat() or 0) or 0
  inj=rla.getInjectionRate() or inj
  drawHeader()
  drawGraphs(eNow,eMax,pHeat,pMax,cHeat,cMax)
  drawControls(prod)
  drawFooter(water,steam,fuel,deu,tri,pHeat,pMax,cHeat,cMax)
  return eNow,eMax
end

drawAll()
local t=os.startTimer(CFG.poll)
while true do
  local e={os.pullEvent()}
  if e[1]=="terminate" then break end
  if e[1]=="char" and e[2]=="q" then break end
  if e[1]=="timer" and e[2]==t then
    local eNow,eMax=drawAll()
    autoStep((eMax>0) and (eNow/eMax) or 0)
    t=os.startTimer(CFG.poll)
  elseif e[1]=="monitor_touch" and mon and e[2]==peripheral.getName(mon) then
    local x,y=e[3],e[4]
    if hit("on",x,y) then injSet(lastNonZero>0 and lastNonZero or CFG.injMin) drawAll() end
    if hit("off",x,y) and CFG.allowOff then injSet(0) drawAll() end
    if hit("minp",x,y) then targetMin=clamp(targetMin+0.10,0,0.9) if targetMin>targetMax then targetMax=targetMin end drawAll() end
    if hit("minm",x,y) then targetMin=clamp(targetMin-0.10,0,0.9) if targetMin>targetMax then targetMax=targetMin end drawAll() end
    if hit("maxp",x,y) then targetMax=clamp(targetMax+0.10,0.1,1) if targetMax<targetMin then targetMin=targetMax end drawAll() end
    if hit("maxm",x,y) then targetMax=clamp(targetMax-0.10,0.1,1) if targetMax<targetMin then targetMin=targetMax end drawAll() end
    if hit("injm10",x,y) then injSet(inj-10) drawAll() end
    if hit("injm1",x,y)  then injSet(inj-1)  drawAll() end
    if hit("injp1",x,y)  then injSet(inj+1)  drawAll() end
    if hit("injp10",x,y) then injSet(inj+10) drawAll() end
    if hit("injs",x,y)   then local n=promptNumber(CFG.lang.prompt,inj) injSet(n) drawAll() end
    if hit("auto",x,y)   then auto=not auto drawAll() end
  end
end

use(nil) term.clear() term.setCursorPos(1,1) print(CFG.lang.ended)
