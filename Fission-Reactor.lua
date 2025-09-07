local CFG={
  adapter="Reactor Logic Adapter_0",
  title="Fusion Control",
  poll=0.25,
  injMin=2, injMax=98, allowOff=true,
  forceScale=0.5,
  col={
    bg=colors.black, stroke=colors.gray,
    card=colors.gray, panel=colors.black,
    title=colors.white, sub=colors.lightGray, txt=colors.white,
    ok=colors.green, bad=colors.red, fuel=colors.lightBlue, case=colors.yellow, bar=colors.gray
  },
  lang={
    adapter="Adapter", control="Control", energy="Buffer", temps="Temps",
    fuel="Fuel", case="Case", controls="Controls",
    on="Start", off="Stop", range="Target", min="Min", max="Max",
    p10="+10", m10="-10", inj="Injection", set="Set", auto="Auto",
    status="Status", ignited="Ignited", cold="Cold",
    producing="Producing", injv="Injection", plasma="Plasma",
    ended="Beendet.", prompt="Neue Injection Rate",
    water="Water", steam="Steam", dt="DT-Fuel", d="Deuterium", t="Tritium"
  }
}

local rla=peripheral.wrap(CFG.adapter) if not rla then error("Adapter nicht gefunden") end
local mon=peripheral.find("monitor")
local native=term.current()
local function use(t) if t then term.redirect(t) else term.redirect(native) end term.setBackgroundColor(CFG.col.bg) term.setTextColor(CFG.col.txt) term.clear() term.setCursorPos(1,1) end
use(mon)
if mon and CFG.forceScale then mon.setTextScale(CFG.forceScale) use(mon) end
local W,H=term.getSize()

local UI={}
local function rect(x1,y1,x2,y2,c) if x1>x2 or y1>y2 then return end term.setBackgroundColor(c) paintutils.drawFilledBox(math.max(1,x1),math.max(1,y1),math.min(W,x2),math.min(H,y2),c) term.setBackgroundColor(CFG.col.bg) end
local function box(x1,y1,x2,y2,c) paintutils.drawBox(math.max(1,x1),math.max(1,y1),math.min(W,x2),math.min(H,y2),c or CFG.col.stroke) end
local function txt(x,y,s,c) if x<1 or x>W or y<1 or y>H then return end term.setTextColor(c or CFG.col.txt) term.setCursorPos(x,y) term.write(s) term.setTextColor(CFG.col.txt) end
local function center(y,s,c) local x=math.max(1,math.floor((W-#s)/2)+1) txt(x,y,s,c) end
local function btn(id,x1,y1,x2,y2,label,bg,fg) rect(x1,y1,x2,y2,bg) local cx=math.max(x1,math.floor((x1+x2-#label)/2)) txt(cx,y1,label,fg) UI[id]={x1=x1,y1=y1,x2=x2,y2=y2} end
local function hit(id,x,y) local b=UI[id]; return b and x>=b.x1 and x<=b.x2 and y>=b.y1 and y<=b.y2 end
local function clamp(v,a,b) if v<a then return a elseif v>b then return b else return v end end
local function fmt(n,u) if type(n)~="number" then return "n/a" end local a=math.abs(n) if a>=1e12 then return string.format("%.2fT",n/1e12)..(u or "") end if a>=1e9 then return string.format("%.2fG",n/1e9)..(u or "") end if a>=1e6 then return string.format("%.2fM",n/1e6)..(u or "") end if a>=1e3 then return string.format("%.2fk",n/1e3)..(u or "") end return string.format("%.0f",n)..(u or "") end

local inj=rla.getInjectionRate() or 0
local lastNonZero=inj>0 and inj or CFG.injMin
local auto=true
local targetMin,targetMax=0.30,0.80

local PAD=2
local HEADER=4
local FOOT=2
local xSide=W-math.max(30,math.floor(W*0.26))+1
local colsW=math.floor((xSide-1-PAD*4)/3)
local x1=PAD
local x2=x1+colsW+PAD
local x3=x2+colsW+PAD
local yTop=HEADER+1
local yBot=H-FOOT-1

local S={ctrl=0,energy=0,plasma=0,case=0}
local function ease(cur,target,alpha) return cur+(target-cur)*alpha end

local function header()
  rect(1,1,W,HEADER,CFG.col.bg)
  box(1,1,W,H)
  center(2,CFG.title,CFG.col.title)
  center(3,CFG.lang.adapter..": "..CFG.adapter,CFG.col.sub)
  paintutils.drawLine(PAD,HEADER,W-PAD,HEADER,CFG.col.stroke)
end

local function barV(x,y1,y2,ratio,bg,fill)
  ratio=clamp(ratio,0,1)
  rect(x,y1,x+12,y2,bg)
  if ratio>0 then
    local h=y2-y1+1
    local fh=math.max(1,math.floor(h*ratio+0.5))
    rect(x+2,y2-fh+2,x+10,y2-1,fill)
    paintutils.drawLine(x+2,y2-fh+1,x+10,y2-fh+1,colors.white)
  end
end

local function gaugeEnergy(x,y1,y2,ratio)
  rect(x,y1,x+colsW-1,y2,CFG.col.panel)
  rect(x+1,y1+1,x+colsW-2,y2-1,CFG.col.card)
  local mid=y1+1+math.floor((y2-2-y1)*(1-ratio))
  rect(x+2,y1+2,x+colsW-3,mid-1,CFG.col.bad)
  rect(x+2,mid,x+colsW-3,y2-2,CFG.col.ok)
end

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

local function controls(prod)
  box(xSide,yTop,W-PAD,yBot)
  local y=yTop+1
  btn("on", xSide+2,y,xSide+11,y,CFG.lang.on,CFG.col.ok,CFG.col.panel)
  btn("off",xSide+13,y,W-PAD-1,y,CFG.lang.off,CFG.col.bad,CFG.col.panel)
  y=y+2
  txt(xSide+2,y,CFG.lang.inj,CFG.col.txt)
  y=y+1
  btn("injm10",xSide+2,y,xSide+6,y,CFG.lang.m10,CFG.col.card,CFG.col.panel)
  btn("injm1", xSide+8,y,xSide+10,y,"-1",CFG.col.card,CFG.col.panel)
  btn("injp1", xSide+12,y,xSide+14,y,"+1",CFG.col.card,CFG.col.panel)
  btn("injp10",xSide+16,y,xSide+20,y,CFG.lang.p10,CFG.col.card,CFG.col.panel)
  btn("injs",  xSide+22,y,W-PAD-1,y,CFG.lang.set,CFG.col.card,CFG.col.panel)
  y=y+2
  txt(xSide+2,y,CFG.lang.auto,CFG.col.txt)
  btn("auto",xSide+12,y,W-PAD-1,y,auto and CFG.lang.on or CFG.lang.off,auto and CFG.col.ok or CFG.col.bad,CFG.col.panel)
  y=y+2
  txt(xSide+2,y,CFG.lang.range,CFG.col.txt)
  y=y+1
  txt(xSide+2,y,CFG.lang.min,CFG.col.txt)
  btn("minp",xSide+7,y,xSide+11,y,CFG.lang.p10,CFG.col.card,CFG.col.panel)
  btn("minm",xSide+13,y,xSide+17,y,CFG.lang.m10,CFG.col.card,CFG.col.panel)
  txt(xSide+19,y,string.format("%d%%",math.floor(targetMin*100)),CFG.col.txt)
  y=y+2
  txt(xSide+2,y,CFG.lang.max,CFG.col.txt)
  btn("maxp",xSide+7,y,xSide+11,y,CFG.lang.p10,CFG.col.card,CFG.col.panel)
  btn("maxm",xSide+13,y,xSide+17,y,CFG.lang.m10,CFG.col.card,CFG.col.panel)
  txt(xSide+19,y,string.format("%d%%",math.floor(targetMax*100)),CFG.col.txt)
  y=y+2
  txt(xSide+2,y,CFG.lang.status,CFG.col.txt)
  local ign=rla.isIgnited and rla.isIgnited() or false
  txt(xSide+2,y+1,ign and CFG.lang.ignited or CFG.lang.cold,ign and CFG.col.ok or CFG.col.sub)
  txt(xSide+2,y+2,CFG.lang.producing..": "..fmt(prod,"J/t"),CFG.col.txt)
  txt(xSide+2,y+3,CFG.lang.injv..": "..tostring(inj),CFG.col.txt)
end

local function footer(water,steam,fuel,deu,tri,pHeat,pMax,cHeat,cMax)
  paintutils.drawLine(PAD,H-2,W-PAD,H-2,CFG.col.stroke)
  txt(PAD,H-1,CFG.lang.plasma.." "..fmt(pHeat,"K").."/"..fmt(pMax,"K").."  "..CFG.lang.case.." "..fmt(cHeat,"K").."/"..fmt(cMax,"K"),CFG.col.sub)
  txt(PAD,H,CFG.lang.water.." "..fmt(water).."  "..CFG.lang.steam.." "..fmt(steam).."  "..CFG.lang.dt.." "..fmt(fuel).."  "..CFG.lang.d.." "..fmt(deu).."  "..CFG.lang.t.." "..fmt(tri),CFG.col.sub)
end

local function promptNumber(prompt,def)
  if mon then use(nil) end
  term.clear() term.setCursorPos(1,1) txt(1,1,prompt.." ("..def.."):",CFG.col.title)
  term.setTextColor(CFG.col.txt)
  local s=read() local n=tonumber(s) if not n then n=def end
  if mon then use(mon) end
  return n
end

local function autoStep(er) if not auto then return end if er<targetMin then injSet(inj+1) elseif er>targetMax then injSet(inj-1) end end

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

  local rCtrl=(inj/CFG.injMax)
  local rEnergy=(eMax>0) and (eNow/eMax) or 0
  local rPlasma=(pMax>0) and (pHeat/pMax) or 0
  local rCase=(cMax>0) and (cHeat/cMax) or 0

  if S.ctrl==0 then S={ctrl=rCtrl,energy=rEnergy,plasma=rPlasma,case=rCase} else
    S.ctrl=ease(S.ctrl,rCtrl,0.3)
    S.energy=ease(S.energy,rEnergy,0.3)
    S.plasma=ease(S.plasma,rPlasma,0.3)
    S.case=ease(S.case,rCase,0.3)
  end

  header()

  txt(x1,yTop-1,CFG.lang.control,CFG.col.sub)
  rect(x1,yTop,x1+colsW-1,yBot,CFG.col.panel)
  rect(x1+1,yTop+1,x1+colsW-2,yBot-1,CFG.col.card)
  barV(x1+math.floor(colsW/2)-6,yTop+2,yBot-2,S.ctrl,CFG.col.bar,CFG.col.ok)
  txt(x1+2,yBot+1,string.format("%.1f%%",S.ctrl*100),CFG.col.sub)

  txt(x2,yTop-1,CFG.lang.energy,CFG.col.sub)
  gaugeEnergy(x2,yTop,yBot,S.energy)
  txt(x2+2,yBot+1,fmt(eNow,"J"),CFG.col.sub)

  txt(x3,yTop-1,CFG.lang.temps,CFG.col.sub)
  rect(x3,yTop,x3+colsW-1,yBot,CFG.col.panel)
  rect(x3+1,yTop+1,x3+colsW-2,yBot-1,CFG.col.card)
  rect(x3+3,yTop+2,x3+13,yBot-2,CFG.col.panel)
  rect(x3+colsW-14,yTop+2,x3+colsW-4,yBot-2,CFG.col.panel)
  barV(x3+3,yTop+2,yBot-2,S.plasma,CFG.col.panel,CFG.col.fuel)
  barV(x3+colsW-14,yTop+2,yBot-2,S.case,CFG.col.panel,CFG.col.case)
  txt(x3+2,yBot+1,CFG.lang.fuel,CFG.col.fuel)
  txt(x3+colsW-14,yBot+1,CFG.lang.case,CFG.col.case)

  controls(prod)
  footer(water,steam,fuel,deu,tri,pHeat,pMax,cHeat,cMax)
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
