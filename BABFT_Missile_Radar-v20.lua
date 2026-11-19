local Players,RunService,UIS,CAS,Lighting=game:GetService("Players"),game:GetService("RunService"),game:GetService("UserInputService"),game:GetService("ContextActionService"),game:GetService("Lighting")
local plr=Players.LocalPlayer
local pGui=plr:WaitForChild("PlayerGui")

for _,v in ipairs(pGui:GetChildren()) do
	if v.Name=="TurbineRadarGui" then v:Destroy() end
end
for _,v in ipairs(Lighting:GetChildren()) do
	if v.Name=="RadarNV" then v:Destroy() end
end

local CANNON_SPEED,BASE_FOV=260,70
local TARGETS={
	JetTurbine="JET",
	SonicJetTurbine="SONIC JET",
	WinterJetTurbine="WINTER JET",
	Thruster="THRUSTER",
	UltraThruster="ULTRA THRUSTER",
	MegaThruster="MEGA THRUSTER",
	SpookyThruster="SPOOKY THRUSTER",
	WinterThruster="WINTER THRUSTER",
	PilotSeat="PILOT SEAT"
}
local JET_NAMES={JetTurbine=true,SonicJetTurbine=true,WinterJetTurbine=true}

local M_GRN,C_GRN=Color3.fromRGB(0,255,100),Color3.fromRGB(0,175,65)
local M_RED,C_RED=Color3.fromRGB(255,50,50),Color3.fromRGB(185,25,25)
local M_CYN=Color3.fromRGB(80,225,255)
local M_ORG=Color3.fromRGB(255,145,40)
local M_PRP=Color3.fromRGB(190,85,255)
local BLK,WHT=Color3.new(),Color3.new(1,1,1)

local enabled,ownEnabled,droneEnabled,nvOn,zoomHeld,aimHeld,canHeld,zoomMult=false,false,false,false,false,false,false,2.5
local markers,seen,missiles,mSeen,plrMarkers,ropeParts,camParts,noiseLines={},{},{},{},{},{},{},{}
local hovered,locked,conn,addConn,remConn=nil,nil,nil,nil,nil
local moveMouse=mousemoverel or (Input and Input.MouseMove)

local function mk(c,p,par)
	local o=Instance.new(c)
	for k,v in pairs(p) do o[k]=v end
	o.Parent=par
	return o
end

local nv=mk("ColorCorrectionEffect",{Name="RadarNV",TintColor=Color3.fromRGB(70,255,110),Brightness=0.18,Contrast=0.25,Saturation=-0.35,Enabled=false},Lighting)
local gui=mk("ScreenGui",{Name="TurbineRadarGui",ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=999999},pGui)
local hud=mk("Frame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Visible=false,ZIndex=1},gui)

local border=mk("Frame",{Size=UDim2.new(1,-28,1,-28),Position=UDim2.fromOffset(14,14),BackgroundTransparency=1,ZIndex=2},hud)
mk("UIStroke",{Thickness=3,Color=M_GRN,Transparency=0.2,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},border)

local noiseBox=mk("Frame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Visible=false,ZIndex=3},hud)
for i=1,20 do
	local nl=mk("Frame",{Size=UDim2.new(1,0,0,2),Position=UDim2.fromScale(0,(i-1)/20),BackgroundColor3=Color3.fromRGB(165,165,170),BackgroundTransparency=0.88,BorderSizePixel=0,ZIndex=3},noiseBox)
	table.insert(noiseLines,nl)
end

mk("TextLabel",{Size=UDim2.fromOffset(320,36),Position=UDim2.new(0.5,-160,0,22),BackgroundTransparency=1,Text="MISSILE LAUNCHER",TextColor3=M_GRN,TextStrokeTransparency=0.2,TextStrokeColor3=BLK,Font=Enum.Font.Code,TextSize=24,ZIndex=10},hud)
local nvLbl=mk("TextLabel",{Size=UDim2.fromOffset(820,24),Position=UDim2.new(0.5,-410,0,54),BackgroundTransparency=1,Text="NVG [Z]: OFF | ZOOM [C]: 1.0x | LOCK [SHIFT] | VEH [TAB] | PLR [Q] | AIM [CTRL]: OFF | CANNON [ALT]: OFF",TextColor3=M_GRN,TextStrokeTransparency=0.2,TextStrokeColor3=BLK,Font=Enum.Font.Code,TextSize=14,ZIndex=10},hud)

local cur=mk("TextLabel",{Size=UDim2.fromOffset(32,32),AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,Text="◇",TextColor3=C_GRN,TextStrokeTransparency=0.2,TextStrokeColor3=BLK,Font=Enum.Font.Code,TextSize=24,ZIndex=9999,Visible=false},gui)
local canMark=mk("TextLabel",{Size=UDim2.fromOffset(90,46),AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,Text="¤\nCANNON",TextColor3=M_CYN,TextStrokeTransparency=0.2,TextStrokeColor3=BLK,Font=Enum.Font.Code,TextSize=16,ZIndex=90,Visible=false},gui)

local offPool,mOffPool={},{}
local function getOffItem(idx)
	if not offPool[idx] then
		local box=mk("Frame",{Size=UDim2.fromOffset(76,54),AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,ZIndex=95,Visible=false},gui)
		local tri=mk("TextLabel",{Size=UDim2.fromOffset(32,32),Position=UDim2.new(0.5,-16,0,0),BackgroundTransparency=1,Text="▲",TextColor3=M_GRN,TextStrokeTransparency=0.2,TextStrokeColor3=BLK,Font=Enum.Font.Code,TextSize=24,ZIndex=96},box)
		local dst=mk("TextLabel",{Size=UDim2.new(1,0,0,18),Position=UDim2.fromOffset(0,32),BackgroundTransparency=1,Text="0 studs",TextColor3=M_GRN,TextStrokeTransparency=0.2,TextStrokeColor3=BLK,Font=Enum.Font.Code,TextSize=13,ZIndex=96},box)
		offPool[idx]={box=box,tri=tri,dst=dst}
	end
	return offPool[idx]
end

local function getMOffItem(idx)
	if not mOffPool[idx] then
		local box=mk("Frame",{Size=UDim2.fromOffset(64,64),AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1,ZIndex=94,Visible=false},gui)
		local arr=mk("TextLabel",{Size=UDim2.fromOffset(32,32),Position=UDim2.new(0.5,-16,0.5,-16),BackgroundTransparency=1,Text="<",TextColor3=M_ORG,TextStrokeTransparency=0.2,TextStrokeColor3=BLK,Font=Enum.Font.Code,TextSize=28,ZIndex=95},box)
		local bang=mk("TextLabel",{Size=UDim2.fromOffset(24,32),Position=UDim2.new(0.5,-12,0.5,-16),BackgroundTransparency=1,Text="!",TextColor3=M_ORG,TextStrokeTransparency=0.2,TextStrokeColor3=BLK,Font=Enum.Font.Code,TextSize=26,ZIndex=95},box)
		mOffPool[idx]={box=box,arr=arr,bang=bang}
	end
	return mOffPool[idx]
end

local pnl=mk("Frame",{Size=UDim2.fromOffset(265,96),Position=UDim2.fromOffset(24,86),BackgroundColor3=Color3.fromRGB(25,25,30),BackgroundTransparency=0.2,Visible=false,ZIndex=20},gui)
mk("UICorner",{CornerRadius=UDim.new(0,8)},pnl)
mk("UIStroke",{Thickness=2,Color=Color3.fromRGB(255,105,105)},pnl)
local pnlTitle=mk("TextLabel",{Size=UDim2.new(1,-16,0,20),Position=UDim2.fromOffset(8,6),BackgroundTransparency=1,Text="TARGET LOCKED",TextColor3=Color3.fromRGB(255,155,155),TextStrokeTransparency=0.35,TextStrokeColor3=BLK,Font=Enum.Font.Code,TextSize=15,TextXAlignment=0,ZIndex=21},pnl)
local pnlTxt=mk("TextLabel",{Size=UDim2.new(1,-16,1,-28),Position=UDim2.fromOffset(8,26),BackgroundTransparency=1,TextColor3=Color3.fromRGB(245,245,250),TextStrokeTransparency=0.45,TextStrokeColor3=BLK,Font=Enum.Font.Code,TextSize=14,TextXAlignment=0,TextYAlignment=0,Text="",ZIndex=21},pnl)

local btn=mk("TextButton",{Size=UDim2.fromOffset(145,40),Position=UDim2.new(0,24,1,-64),BackgroundColor3=Color3.fromRGB(35,35,40),TextColor3=WHT,Font=Enum.Font.GothamBold,TextSize=15,Text="Radar: OFF",ZIndex=50},gui)
mk("UICorner",{CornerRadius=UDim.new(0,8)},btn)
local btnStr=mk("UIStroke",{Thickness=2,Color=Color3.fromRGB(100,100,110),ApplyStrokeMode=Enum.ApplyStrokeMode.Border},btn)

local ownBtn=mk("TextButton",{Size=UDim2.fromOffset(74,20),Position=UDim2.new(0,176,1,-64),BackgroundColor3=Color3.fromRGB(35,35,40),TextColor3=Color3.fromRGB(200,200,210),Font=Enum.Font.Code,TextSize=11,Text="OWN: OFF",ZIndex=50},gui)
mk("UICorner",{CornerRadius=UDim.new(0,5)},ownBtn)
local ownStr=mk("UIStroke",{Thickness=1.5,Color=Color3.fromRGB(100,100,110),ApplyStrokeMode=Enum.ApplyStrokeMode.Border},ownBtn)

local drnBtn=mk("TextButton",{Size=UDim2.fromOffset(74,18),Position=UDim2.new(0,176,1,-42),BackgroundColor3=Color3.fromRGB(35,35,40),TextColor3=Color3.fromRGB(200,200,210),Font=Enum.Font.Code,TextSize=11,Text="DRONE: OFF",ZIndex=50},gui)
mk("UICorner",{CornerRadius=UDim.new(0,5)},drnBtn)
local drnStr=mk("UIStroke",{Thickness=1.5,Color=Color3.fromRGB(100,100,110),ApplyStrokeMode=Enum.ApplyStrokeMode.Border},drnBtn)

local function updHud()
	nvLbl.Text=string.format("NVG [Z]: %s | ZOOM [C]: %.1fx | LOCK [SHIFT] | VEH [TAB] | PLR [Q] | AIM [CTRL]: %s | CANNON [ALT]: %s",nvOn and "ON" or "OFF",zoomHeld and zoomMult or 1,aimHeld and "ON" or "OFF",canHeld and "ON" or "OFF")
end

local function setNV(s)
	nvOn,nv.Enabled=s,s
	updHud()
end

local function setZoom(s)
	if zoomHeld==s then return end
	zoomHeld=s
	if s then
		CAS:BindActionAtPriority("RadarZoom",function(_,_,i)
			if i.UserInputType==Enum.UserInputType.MouseWheel then
				zoomMult=math.clamp(zoomMult+(i.Position.Z>0 and 0.5 or -0.5),1,8)
				updHud()
			end
			return Enum.ContextActionResult.Sink
		end,false,3000,Enum.UserInputType.MouseWheel)
	else
		CAS:UnbindAction("RadarZoom")
	end
	updHud()
end

local function cycleVehicle()
	local pool={}
	for _,d in ipairs(markers) do
		if not d.isPlayer then table.insert(pool,d) end
	end
	if #pool==0 then return end
	local idx=locked and table.find(pool,locked) or 0
	locked=pool[(idx%#pool)+1]
end

local function cyclePlayer()
	local pool={}
	for _,d in ipairs(markers) do
		if d.isPlayer then table.insert(pool,d) end
	end
	if #pool==0 then return end
	local idx=locked and table.find(pool,locked) or 0
	locked=pool[(idx%#pool)+1]
end

local function getRoot(i)
	local c=i
	while c and c~=workspace do
		if c:IsA("Model") and TARGETS[c.Name] then return c end
		c=c.Parent
	end
	return i:FindFirstAncestorOfClass("Model") or i
end

local function getPart(inst)
	if inst:IsA("BasePart") then return inst end
	if inst:IsA("Model") then return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart",true) end
	return inst:FindFirstAncestorWhichIsA("BasePart")
end

local function isDynamite(o)
	local n=o.Name:lower()
	if n:find("dynamite") then return true end
	if o.Parent and o.Parent~=workspace and o.Parent.Name:lower():find("dynamite") then return true end
	return false
end

local function isRope(o)
	if o:IsA("RopeConstraint") then return true end
	local n=o.Name:lower()
	if n:find("rope") then return true end
	if o.Parent and o.Parent~=workspace and o.Parent.Name:lower():find("rope") then return true end
	return false
end

local function getDynamiteRoot(o)
	if o.Parent and o.Parent:IsA("Model") and o.Parent.Name:lower():find("dynamite") then
		return o.Parent
	end
	return o
end

local function isCamPart(o)
	local n=o.Name:lower()
	if n=="camera" or n=="domecamera" or n=="dome camera" or n:find("dome") then return true end
	local m=o:FindFirstAncestorOfClass("Model")
	if m then
		local mn=m.Name:lower()
		if mn=="camera" or mn=="domecamera" or mn=="dome camera" or mn:find("dome") then return true end
	end
	return false
end

local function getTeamZonePos(teamName)
	for _,obj in ipairs(workspace:GetChildren()) do
		local n=obj.Name:lower()
		if n:find(teamName:lower(),1,true) and (n:find("zone") or n:find("spawn") or n:find("plot") or n:find("team")) then
			local p=getPart(obj)
			if p then return p.Position end
		end
	end
	return nil
end

local function checkOwnerValue(obj,myName,myId)
	local tag=obj:FindFirstChild("Tag") or obj:FindFirstChild("Owner") or obj:FindFirstChild("Creator")
	if tag and tag:IsA("ValueBase") then
		local v=tostring(tag.Value)
		if v==myName or v==myId then return true end
		if v~="" and v~="nil" then return false end
	end
	local attrOwner=obj:GetAttribute("Owner") or obj:GetAttribute("UserId")
	if attrOwner~=nil then
		local v=tostring(attrOwner)
		if v==myName or v==myId then return true end
		if v~="" then return false end
	end
	return nil
end

local function isOwnInstance(inst)
	if not inst then return false end
	local char=plr.Character
	if char and inst:IsDescendantOf(char) then return true end

	local myName,myId=plr.Name,tostring(plr.UserId)
	local teamName=plr.Team and plr.Team.Name or nil

	local curObj=inst
	while curObj and curObj~=workspace do
		local ownCheck=checkOwnerValue(curObj,myName,myId)
		if ownCheck~=nil then return ownCheck end
		local n=curObj.Name
		if n==myName or n==myId then return true end
		if teamName and (n==teamName or n==teamName.."Zone" or n==teamName.."Blocks") then
			return true
		end
		curObj=curObj.Parent
	end

	local part=getPart(inst)
	if part then
		if teamName then
			local blocksFolder=workspace:FindFirstChild("Blocks")
			if blocksFolder then
				local myFolder=blocksFolder:FindFirstChild(teamName)
				if myFolder and inst:IsDescendantOf(myFolder) then return true end
				for _,folder in ipairs(blocksFolder:GetChildren()) do
					if folder~=myFolder and inst:IsDescendantOf(folder) then return false end
				end
			end
		end

		local ok,connParts=pcall(function() return part:GetConnectedParts(true) end)
		if ok and connParts then
			for _,cp in ipairs(connParts) do
				if char and cp:IsDescendantOf(char) then return true end
				local pCur=cp
				while pCur and pCur~=workspace do
					local ownCheck=checkOwnerValue(pCur,myName,myId)
					if ownCheck~=nil then return ownCheck end
					if pCur.Name==myName or (teamName and pCur.Name==teamName) then return true end
					pCur=pCur.Parent
				end
			end
		end

		if teamName then
			local zPos=getTeamZonePos(teamName)
			if zPos and (part.Position-zPos).Magnitude<175 and part.AssemblyLinearVelocity.Magnitude<2 then
				return true
			end
		end
	end

	return false
end

local function isCameraBlockActive(cam)
	if not cam then return false end
	local subj=cam.CameraSubject
	if subj and subj:IsA("Instance") then
		local char=plr.Character
		if not (char and subj:IsDescendantOf(char)) then
			if isCamPart(subj) then return true end
		end
	end
	if cam.CameraType~=Enum.CameraType.Custom and cam.CameraType~=Enum.CameraType.Follow then
		local cPos=cam.CFrame.Position
		for i=#camParts,1,-1 do
			local cp=camParts[i]
			if not cp or not cp.Parent then
				table.remove(camParts,i)
			elseif (cp.Position-cPos).Magnitude<28 then
				return true
			end
		end
	end
	return false
end

local function hasRopeNearby(pos)
	for i=#ropeParts,1,-1 do
		local rp=ropeParts[i]
		if not rp or not rp.Parent then
			table.remove(ropeParts,i)
		elseif (rp.Position-pos).Magnitude<=16 then
			return true
		end
	end
	return false
end

local function hideOffPool()
	for _,item in ipairs(offPool) do item.box.Visible=false end
	for _,item in ipairs(mOffPool) do item.box.Visible=false end
end

local function clear()
	if conn then conn:Disconnect() conn=nil end
	if addConn then addConn:Disconnect() addConn=nil end
	if remConn then remConn:Disconnect() remConn=nil end
	CAS:UnbindAction("RadarTab")
	CAS:UnbindAction("RadarQ")
	CAS:UnbindAction("RadarLock")
	hovered,locked,aimHeld,canHeld=nil,nil,false,false
	pnl.Visible,hud.Visible,cur.Visible,canMark.Visible,noiseBox.Visible=false,false,false,false,false
	hideOffPool()
	setZoom(false)
	setNV(false)
	if workspace.CurrentCamera then workspace.CurrentCamera.FieldOfView=BASE_FOV end
	UIS.MouseDeltaSensitivity,UIS.MouseIconEnabled,cur.TextColor3=1,true,C_GRN
	for _,d in ipairs(markers) do d.gui:Destroy() end
	for _,m in ipairs(missiles) do m.gui:Destroy() end
	table.clear(markers)
	table.clear(seen)
	table.clear(missiles)
	table.clear(mSeen)
	table.clear(plrMarkers)
	table.clear(ropeParts)
	table.clear(camParts)
end

local function track(o)
	if isCamPart(o) then
		local cp=getPart(o)
		if cp and not table.find(camParts,cp) then table.insert(camParts,cp) end
	end

	if isRope(o) then
		local rp=o:IsA("RopeConstraint") and (o.Attachment0 and o.Attachment0.Parent or o.Attachment1 and o.Attachment1.Parent) or getPart(o)
		if rp and rp:IsA("BasePart") and not table.find(ropeParts,rp) then
			table.insert(ropeParts,rp)
		end
	end

	if isDynamite(o) then
		local dr=getDynamiteRoot(o)
		if mSeen[dr] then return end
		mSeen[dr]=true
		task.defer(function()
			if not enabled or not dr.Parent then mSeen[dr]=nil return end
			local p=getPart(dr)
			if not p then mSeen[dr]=nil return end
			local isOwn=isOwnInstance(dr) or isOwnInstance(p)
			if isOwn and not ownEnabled then mSeen[dr]=nil return end
			for _,m in ipairs(missiles) do
				if m.part.Parent and (m.part.Position-p.Position).Magnitude<=10 then
					mSeen[dr]=nil
					return
				end
			end
			local bb=mk("BillboardGui",{Name="MissileMark",Adornee=p,Size=UDim2.fromOffset(140,64),AlwaysOnTop=true,MaxDistance=math.huge},pGui)
			local lbl=mk("TextLabel",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,RichText=true,Text=isOwn and '<font size="28">※</font>\n&lt;OWN MISSILE&gt;' or '<font size="28">※</font>\n&lt;MISSILE&gt;',TextColor3=isOwn and M_CYN or M_ORG,TextStrokeTransparency=0.25,TextStrokeColor3=BLK,Font=Enum.Font.Code,TextSize=14},bb)
			table.insert(missiles,{gui=bb,part=p,root=dr,isOwn=isOwn})
		end)
		return
	end

	local tag=TARGETS[o.Name]
	if not tag then return end
	local r=getRoot(o)
	if seen[r] then return end
	seen[r]=true
	task.defer(function()
		if not enabled or not r.Parent then seen[r]=nil return end
		local p=getPart(r)
		if not p then seen[r]=nil return end
		local isOwn=isOwnInstance(r) or isOwnInstance(p)
		if isOwn and not ownEnabled then seen[r]=nil return end

		local isJet=JET_NAMES[o.Name] or JET_NAMES[r.Name] or false
		local isDrone=false
		if isJet and hasRopeNearby(p.Position) then
			if not droneEnabled then seen[r]=nil return end
			isDrone=true
			tag="DRONE"
		end

		for _,m in ipairs(markers) do
			if not m.isPlayer and m.part.Parent and (m.part.Position-p.Position).Magnitude<15 then
				seen[r]=nil
				return
			end
		end
		local bb=mk("BillboardGui",{Name="RadarMark",Adornee=p,Size=UDim2.fromOffset(170,68),AlwaysOnTop=true,MaxDistance=math.huge},pGui)
		local lbl=mk("TextLabel",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,TextColor3=isOwn and M_CYN or M_GRN,TextStrokeTransparency=0.3,TextStrokeColor3=BLK,Font=Enum.Font.Code,TextSize=16},bb)
		table.insert(markers,{gui=bb,label=lbl,part=p,root=r,name=r.Name,tag=tag,isOwn=isOwn,isDrone=isDrone,isPlayer=false})
	end)
end

local function updatePlayers()
	for _,p in ipairs(Players:GetPlayers()) do
		if p~=plr then
			local hrp=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			local existing=plrMarkers[p]
			if hrp and hrp.Parent then
				if not existing or not existing.part or not existing.part.Parent then
					if existing and existing.gui then existing.gui:Destroy() end
					local bb=mk("BillboardGui",{Name="PlayerRadarMark",Adornee=hrp,Size=UDim2.fromOffset(150,68),AlwaysOnTop=true,MaxDistance=math.huge},pGui)
					local lbl=mk("TextLabel",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,TextColor3=M_PRP,TextStrokeTransparency=0.3,TextStrokeColor3=BLK,Font=Enum.Font.Code,TextSize=16},bb)
					local entry={gui=bb,label=lbl,part=hrp,root=p.Character,name=p.Name,tag="PLR",isOwn=false,isDrone=false,isPlayer=true,playerObj=p}
					plrMarkers[p]=entry
					table.insert(markers,entry)
				end
			elseif existing then
				if locked==existing then locked=nil end
				if existing.gui then existing.gui:Destroy() end
				local idx=table.find(markers,existing)
				if idx then table.remove(markers,idx) end
				plrMarkers[p]=nil
			end
		end
	end
	for p,entry in pairs(plrMarkers) do
		if not p.Parent then
			if locked==entry then locked=nil end
			if entry.gui then entry.gui:Destroy() end
			local idx=table.find(markers,entry)
			if idx then table.remove(markers,idx) end
			plrMarkers[p]=nil
		end
	end
end

local function rescan()
	if not enabled then return end
	locked,hovered=nil,nil
	for _,d in ipairs(markers) do d.gui:Destroy() end
	for _,m in ipairs(missiles) do m.gui:Destroy() end
	table.clear(markers)
	table.clear(seen)
	table.clear(missiles)
	table.clear(mSeen)
	table.clear(plrMarkers)
	table.clear(ropeParts)
	table.clear(camParts)
	for _,o in ipairs(workspace:GetDescendants()) do track(o) end
	updatePlayers()
end

local function start()
	clear()
	UIS.MouseIconEnabled,cur.Visible,hud.Visible=false,true,true
	CAS:BindActionAtPriority("RadarTab",function(_,st)
		if st==Enum.UserInputState.Begin then cycleVehicle() end
		return Enum.ContextActionResult.Sink
	end,false,3000,Enum.KeyCode.Tab)
	CAS:BindActionAtPriority("RadarQ",function(_,st)
		if st==Enum.UserInputState.Begin then cyclePlayer() end
		return Enum.ContextActionResult.Sink
	end,false,3000,Enum.KeyCode.Q)
	CAS:BindActionAtPriority("RadarLock",function(_,st)
		if st==Enum.UserInputState.Begin then
			locked=(hovered and locked~=hovered) and hovered or nil
		end
		return Enum.ContextActionResult.Pass
	end,false,3000,Enum.KeyCode.LeftShift,Enum.KeyCode.RightShift)

	for _,o in ipairs(workspace:GetDescendants()) do track(o) end
	updatePlayers()
	addConn=workspace.DescendantAdded:Connect(track)
	local noiseTick,plrTick=0,0

	conn=RunService.RenderStepped:Connect(function(dt)
		UIS.MouseIconEnabled=false
		local cam=workspace.CurrentCamera
		if not cam then return end

		plrTick+=dt
		if plrTick>=0.5 then
			plrTick=0
			updatePlayers()
		end

		local extCam=isCameraBlockActive(cam)
		noiseBox.Visible=extCam
		if extCam then
			noiseTick+=dt
			if noiseTick>=0.05 then
				noiseTick=0
				for _,nl in ipairs(noiseLines) do
					nl.Position=UDim2.fromScale(0,math.random())
					nl.Size=UDim2.new(1,0,0,math.random(1,3))
					nl.BackgroundTransparency=0.82+(math.random()*0.1)
				end
			end
		end

		cam.FieldOfView+=((zoomHeld and BASE_FOV/zoomMult or BASE_FOV)-cam.FieldOfView)*math.min(dt*14,1)
		local sens=zoomHeld and 1/math.max(zoomMult*0.75,1) or 1
		UIS.MouseDeltaSensitivity=sens

		local mPos=UIS:GetMouseLocation()
		cur.Position=UDim2.fromOffset(mPos.X,mPos.Y)
		local hrp=plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
		local originPos=extCam and cam.CFrame.Position or (hrp and hrp.Position or cam.CFrame.Position)
		hovered=nil
		local best=35
		local offIdx,mOffIdx=0,0
		local vp=cam.ViewportSize
		local c=vp/2
		local padX,padY=38,38

		for i=#missiles,1,-1 do
			local m=missiles[i]
			if not m.part or not m.part.Parent then
				mSeen[m.root]=nil
				m.gui:Destroy()
				table.remove(missiles,i)
			else
				local msp,mon=cam:WorldToViewportPoint(m.part.Position)
				local inBounds=mon and msp.Z>0 and msp.X>=14 and msp.X<=vp.X-14 and msp.Y>=14 and msp.Y<=vp.Y-14
				if not inBounds then
					mOffIdx+=1
					local item=getMOffItem(mOffIdx)
					item.box.Visible=true
					local dir=Vector2.new(msp.X-c.X,msp.Y-c.Y)*(msp.Z<0 and -1 or 1)
					dir=dir.Magnitude==0 and Vector2.new(0,-1) or dir.Unit
					local s=math.min((c.X-padX)/math.max(math.abs(dir.X),1e-3),(c.Y-padY)/math.max(math.abs(dir.Y),1e-3))
					item.box.Position=UDim2.fromOffset(c.X+dir.X*s,c.Y+dir.Y*s)
					item.arr.Rotation=math.deg(math.atan2(dir.Y,dir.X))+180
					item.bang.Position=UDim2.new(0.5,-12-dir.X*18,0.5,-16-dir.Y*18)
					local mCol=m.isOwn and M_CYN or M_ORG
					item.arr.TextColor3=mCol
					item.bang.TextColor3=mCol
				end
			end
		end

		for i=#markers,1,-1 do
			local d=markers[i]
			if not d.part or not d.part.Parent then
				if locked==d then locked=nil end
				if d.isPlayer and d.playerObj then
					plrMarkers[d.playerObj]=nil
				else
					seen[d.root]=nil
				end
				d.gui:Destroy()
				table.remove(markers,i)
			else
				local sp,on=cam:WorldToViewportPoint(d.part.Position)
				local dist=math.floor((originPos-d.part.Position).Magnitude)
				local inBounds=on and sp.Z>0 and sp.X>=14 and sp.X<=vp.X-14 and sp.Y>=14 and sp.Y<=vp.Y-14
				if inBounds then
					local cd=(Vector2.new(sp.X,sp.Y)-mPos).Magnitude
					if cd<=best then best,hovered=cd,d end
				else
					offIdx+=1
					local item=getOffItem(offIdx)
					item.box.Visible=true
					local dir=Vector2.new(sp.X-c.X,sp.Y-c.Y)*(sp.Z<0 and -1 or 1)
					dir=dir.Magnitude==0 and Vector2.new(0,-1) or dir.Unit
					local s=math.min((c.X-padX)/math.max(math.abs(dir.X),1e-3),(c.Y-padY)/math.max(math.abs(dir.Y),1e-3))
					item.box.Position=UDim2.fromOffset(c.X+dir.X*s,c.Y+dir.Y*s)
					item.tri.Rotation=math.deg(math.atan2(dir.Y,dir.X))+90
					local col=(d==locked) and M_RED or (d.isPlayer and M_PRP or (d.isOwn and M_CYN or M_GRN))
					item.tri.TextColor3=col
					item.dst.TextColor3=col
					item.dst.Text=dist.." studs"
				end
				d.dist=dist
			end
		end

		for j=offIdx+1,#offPool do offPool[j].box.Visible=false end
		for j=mOffIdx+1,#mOffPool do mOffPool[j].box.Visible=false end

		for _,d in ipairs(markers) do
			local lk,hv=d==locked,d==hovered
			local openSym=d.isPlayer and (lk and "【 ○ 】" or "{○}") or (d.isDrone and (lk and "【 × 】" or "[ × ]") or (lk and "【 + 】" or "[ + ]"))
			d.label.Text=string.format("%s\n%s\n%d studs",openSym,d.tag,d.dist or 0)
			d.label.TextColor3=(lk or hv) and M_RED or (d.isPlayer and M_PRP or (d.isOwn and M_CYN or M_GRN))
		end
		cur.TextColor3=(canHeld and locked and not locked.isDrone) and M_CYN or ((aimHeld and locked) and M_RED or (hovered and C_RED or C_GRN))

		if locked and locked.part and locked.part.Parent then
			local rawDist=(originPos-locked.part.Position).Magnitude
			local vel=locked.part.AssemblyLinearVelocity
			local spd=vel.Magnitude
			pnl.Visible=true
			pnlTxt.Text=string.format("TYPE: %s\nOBJ: %s\nDIST: %d studs | SPD: %d",locked.tag,locked.name,math.floor(rawDist),math.floor(spd))

			local allowCannon=not locked.isDrone
			local canWorld=locked.part.Position+(spd>5 and vel*(rawDist/CANNON_SPEED) or Vector3.zero)
			local csp,con=cam:WorldToViewportPoint(canWorld)
			canMark.Visible=allowCannon and con and csp.Z>0
			if canMark.Visible then canMark.Position=UDim2.fromOffset(csp.X,csp.Y) end

			local asp,aon=cam:WorldToViewportPoint(locked.part.Position)
			local stepGain=0.32*math.min(sens,1)
			if canHeld and allowCannon and con and csp.Z>0 and moveMouse then
				local dx,dy=csp.X-mPos.X,csp.Y-mPos.Y
				if math.abs(dx)>0.5 or math.abs(dy)>0.5 then
					moveMouse(dx*stepGain,dy*stepGain)
				end
			elseif aimHeld and aon and asp.Z>0 and moveMouse then
				local dx,dy=asp.X-mPos.X,asp.Y-mPos.Y
				if math.abs(dx)>0.5 or math.abs(dy)>0.5 then
					moveMouse(dx*stepGain,dy*stepGain)
				end
			end
		else
			pnl.Visible,canMark.Visible=false,false
		end
	end)
end

UIS.InputBegan:Connect(function(i)
	if not enabled then return end
	if i.KeyCode==Enum.KeyCode.LeftControl or i.KeyCode==Enum.KeyCode.RightControl then
		aimHeld=true
		updHud()
	elseif i.KeyCode==Enum.KeyCode.LeftAlt or i.KeyCode==Enum.KeyCode.RightAlt then
		canHeld=true
		updHud()
	elseif i.KeyCode==Enum.KeyCode.Z then
		setNV(not nvOn)
	elseif i.KeyCode==Enum.KeyCode.C then
		setZoom(true)
	end
end)
UIS.InputEnded:Connect(function(i)
	if i.KeyCode==Enum.KeyCode.C then setZoom(false)
	elseif i.KeyCode==Enum.KeyCode.LeftControl or i.KeyCode==Enum.KeyCode.RightControl then aimHeld=false updHud()
	elseif i.KeyCode==Enum.KeyCode.LeftAlt or i.KeyCode==Enum.KeyCode.RightAlt then canHeld=false updHud() end
end)
UIS.WindowFocusReleased:Connect(function() setZoom(false) aimHeld=false canHeld=false updHud() end)

ownBtn.MouseButton1Click:Connect(function()
	ownEnabled=not ownEnabled
	ownBtn.Text=ownEnabled and "OWN: ON" or "OWN: OFF"
	ownBtn.BackgroundColor3=ownEnabled and Color3.fromRGB(0,115,150) or Color3.fromRGB(35,35,40)
	ownBtn.TextColor3=ownEnabled and WHT or Color3.fromRGB(200,200,210)
	ownStr.Color=ownEnabled and M_CYN or Color3.fromRGB(100,100,110)
	rescan()
end)

drnBtn.MouseButton1Click:Connect(function()
	droneEnabled=not droneEnabled
	drnBtn.Text=droneEnabled and "DRONE: ON" or "DRONE: OFF"
	drnBtn.BackgroundColor3=droneEnabled and Color3.fromRGB(0,140,70) or Color3.fromRGB(35,35,40)
	drnBtn.TextColor3=droneEnabled and WHT or Color3.fromRGB(200,200,210)
	drnStr.Color=droneEnabled and M_GRN or Color3.fromRGB(100,100,110)
	rescan()
end)

btn.MouseButton1Click:Connect(function()
	enabled=not enabled
	btn.Text=enabled and "Radar: ON" or "Radar: OFF"
	btn.BackgroundColor3=enabled and Color3.fromRGB(0,140,70) or Color3.fromRGB(35,35,40)
	btnStr.Color=enabled and Color3.fromRGB(0,255,120) or Color3.fromRGB(100,100,110)
	if enabled then start() else clear() end
end)
