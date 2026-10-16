local _, NS = ...
local DIST,FOV=10,0.6
local function Call(object,name,...)
    if not object or type(object[name])~="function" then return false end
    return pcall(object[name],object,...)
end
local function Number(v) return type(v)=="number" and v==v and math.abs(v)<math.huge end

-- Same custom ModelScene actor path measured by PetStableProbe Models.lua.
-- Exact displays preserve skins; no SetCreature/SetUnit or model-file fallback.
function NS.CreateAppearancePreview(parent,Text,interactive)
    local preview=CreateFrame("Frame",nil,parent)
    preview.OnReady=false
    local fallback=Text(preview,13,{0.65,0.72,0.7,1})
    fallback:SetPoint("CENTER"); fallback:SetWidth(200); fallback:SetJustifyH("CENTER"); fallback:SetWordWrap(true)
    local portrait=preview:CreateTexture(nil,"ARTWORK"); portrait:SetPoint("CENTER"); portrait:SetSize(96,96); portrait:Hide()
    local ok,scene=pcall(CreateFrame,"ModelScene",nil,preview)
    if not ok then scene=nil end
    local actor
    if scene then
        -- Keep the projection square, as in the measured probe's near-square
        -- viewport. A wide/shallow card must not squeeze the camera's vertical
        -- field of view while fitting as though it were a portrait viewport.
        scene:SetPoint("CENTER",preview,"CENTER"); scene:EnableMouse(false)
        local created,result=Call(scene,"CreateActor"); if created then actor=result end
    end
    preview.scene,preview.actor=scene,actor
    local group,elapsed,since,dragX,baseScale,boundsWidth,boundsHeight
    preview.yaw=0.5; preview.zoom=1
    local function Viewport()
        if scene then
            local side=math.max(1,math.min(preview:GetWidth(),preview:GetHeight()))
            scene:SetSize(side,side)
        end
    end
    local function Camera()
        Call(scene,"SetCameraFieldOfView",FOV)
        Call(scene,"SetCameraNearClip",0.1); Call(scene,"SetCameraFarClip",100)
        Call(scene,"SetCameraPosition",DIST,0,0)
        Call(scene,"SetCameraOrientationByYawPitchRoll",math.pi,0,0)
    end
    local function Fallback()
        if scene then scene:Hide() end
        Call(actor,"ClearModel"); preview:SetScript("OnUpdate",nil); preview.ready=false
        fallback:SetText("Appearance preview unavailable")
        local fn=rawget(_G,"SetPortraitTextureFromCreatureDisplayID")
        if group and group.portraitVerified and group.displayID and type(fn)=="function" then
            local success=pcall(fn,portrait,group.displayID)
            if success then portrait:Show(); fallback:SetText("Verified portrait; 3D unavailable"); fallback:ClearAllPoints(); fallback:SetPoint("BOTTOM",0,4) end
        end
        fallback:Show()
        if preview.OnReady then preview.OnReady(false) end
    end
    local function Fit()
        if not boundsWidth then
            local success,a,b,c,d,e,f=Call(actor,"GetActiveBoundingBox")
            if type(a)=="table" and type(b)=="table" then a,b,c,d,e,f=a.x,a.y,a.z,b.x,b.y,b.z end
            if not success or not (Number(a) and Number(b) and Number(c) and Number(d) and Number(e) and Number(f)) then return false end
            local w,h=math.sqrt((d-a)^2+(e-b)^2),f-c
            if w<=0.001 or h<=0.001 then return false end
            -- Bounds are read once at unit scale. Reset/layout never remeasure
            -- a scaled actor or change the original framing measurements.
            boundsWidth,boundsHeight=w,h
        end
        local view=2*DIST*math.tan(FOV/2)
        baseScale=0.72*view/math.max(boundsWidth,boundsHeight)
        return Call(actor,"SetScale",baseScale*preview.zoom)
    end
    local function Update(self,delta)
        if not self.ready then
            elapsed=elapsed+delta; since=since+delta
            if since>=0.2 then
                since=0
                if Fit() then self.ready=true; fallback:Hide(); if self.OnReady then self.OnReady(true) end
                elseif elapsed>=4 then Fallback(); return end
            end
        end
        if dragX and type(rawget(_G,"GetCursorPosition"))=="function" then
            local x=GetCursorPosition(); self.yaw=self.yaw+(x-dragX)*0.012; dragX=x; Call(actor,"SetYaw",self.yaw)
        end
        if self.ready and not dragX then self:SetScript("OnUpdate",nil) end
    end
    function preview.Clear()
        preview:SetScript("OnUpdate",nil); dragX=nil; group=nil; preview.key=nil; preview.ready=false
        Call(actor,"ClearModel"); if scene then scene:Hide() end
        portrait:SetTexture(nil); portrait:Hide(); fallback:Hide()
        boundsWidth,boundsHeight,baseScale=nil,nil,nil
        if preview.OnReady then preview.OnReady(false) end
    end
    function preview.Set(value)
        if value and preview.key==value.key then return end
        preview.Clear(); group=value; if not value then return end
        preview.key=value.key; preview.yaw=0.5; preview.zoom=1
        fallback:ClearAllPoints(); fallback:SetPoint("CENTER"); fallback:SetText("Loading appearance..."); fallback:Show()
        if not (value.displayID and value.modelVerified and actor) then Fallback(); return end
        Viewport(); scene:Show(); Camera()
        Call(actor,"SetScale",1); Call(actor,"SetUseCenterForOrigin",true,true,true)
        Call(actor,"SetPosition",0,0,0); Call(actor,"SetYaw",preview.yaw)
        local success,accepted=Call(actor,"SetModelByCreatureDisplayID",value.displayID,false)
        if not success or accepted~=true then Fallback(); return end
        -- A still pose avoids running nine idle animations while browsing.
        Call(actor,"SetAnimation",0,0,0,0)
        elapsed,since=0,0; preview:SetScript("OnUpdate",Update)
    end
    function preview.Rotate(delta) if preview.ready then preview.yaw=preview.yaw+delta; Call(actor,"SetYaw",preview.yaw) end end
    function preview.Zoom(delta)
        if preview.ready then preview.zoom=math.max(0.65,math.min(1.8,preview.zoom+delta)); Call(actor,"SetScale",baseScale*preview.zoom) end
    end
    function preview.Reset()
        preview.yaw=0.5; preview.zoom=1; Call(actor,"SetYaw",preview.yaw); if preview.ready then Fit() end
    end
    preview:SetScript("OnSizeChanged",function() Viewport(); if preview.ready then Fit() end end)
    preview:SetScript("OnHide",preview.Clear)
    if interactive then
        preview:EnableMouse(true); preview:EnableMouseWheel(true)
        preview:SetScript("OnMouseWheel",function(_,delta) preview.Zoom(delta*0.1) end)
        preview:SetScript("OnMouseDown",function(_,button)
            if button=="LeftButton" and preview.ready and type(rawget(_G,"GetCursorPosition"))=="function" then
                dragX=GetCursorPosition(); preview:SetScript("OnUpdate",Update)
            end
        end)
        preview:SetScript("OnMouseUp",function() dragX=nil; if preview.ready then preview:SetScript("OnUpdate",nil) end end)
    else preview:EnableMouse(false) end
    return preview
end
