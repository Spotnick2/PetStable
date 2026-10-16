-- Extend the existing LibGlass mock locally; no sibling files or second mock world.
-- These implement only state/events used by the browser, not visual correctness.
local create=CreateFrame
rawset(_G,"CreateFrame",function(kind,name,parent,template)
    local frame=create(kind,name,parent,template)
    local setSize=frame.SetSize
    frame.SetSize=function(self,width,height)
        local changed=self:GetWidth()~=width or self:GetHeight()~=height
        setSize(self,width,height)
        local fn=self:GetScript("OnSizeChanged"); if changed and fn then fn(self,width,height) end
    end
    frame.GetPoint=function(self,index) return unpack(self._points[index or 1] or {}) end
    local setScale=frame.SetScale
    frame.SetScale=function(self,value) self.scaleValue=value; setScale(self,value) end
    frame.GetScale=function(self) return self.scaleValue or 1 end
    frame.HasScript=function() return true end
    frame.GetChildren=function(self)
        local children={}; for _,child in ipairs(WoW.frames) do if child._parent==self then children[#children+1]=child end end
        return unpack(children)
    end
    frame.HookScript=function(self,event,hook)
        local original=self:GetScript(event)
        self:SetScript(event,function(...) if original then original(...) end; hook(...) end)
    end
    local makeText=frame.CreateFontString
    frame.CreateFontString=function(self,...)
        local text=makeText(self,...)
        text.GetStringHeight=function(t)
            local lines=0
            for line in ((t:GetText() or "").."\n"):gmatch("(.-)\n") do
                lines=lines+math.max(1,math.ceil(#line/math.max(1,math.floor(t:GetWidth()/7))))
            end
            return lines*16
        end
        return text
    end
    local hide=frame.Hide
    frame.Hide=function(self)
        local wasShown=self:IsShown(); hide(self)
        local fn=self:GetScript("OnHide"); if wasShown and fn then fn(self) end
    end
    frame.SetShown=function(self,shown) if shown then self:Show() else self:Hide() end end
    frame.SetPropagateKeyboardInput=function(self,value) self.propagate=value end
    if kind=="EditBox" then
        local setFont=frame.SetFont
        frame.SetFont=function(self,file,height,flags)
            assert(type(flags)=="string", "EditBox:SetFont requires explicit flags on Forever")
            return setFont(self,file,height,flags)
        end
        frame._text=""
        frame.HasFocus=function(self) return self.focused==true end
        frame.SetFocus=function(self)
            self.focused=true
            local fn=self:GetScript("OnEditFocusGained"); if fn then fn(self) end
        end
        frame.ClearFocus=function(self)
            local hadFocus=self.focused; self.focused=false
            local fn=self:GetScript("OnEditFocusLost"); if hadFocus and fn then fn(self) end
        end
        local setText=frame.SetText
        frame.SetText=function(self,value)
            setText(self,value)
            local fn=self:GetScript("OnTextChanged"); if fn then fn(self,false) end
        end
    elseif kind=="ModelScene" then
        frame.CreateActor=function()
            local actor={}
            function actor:SetModelByCreatureDisplayID(id) self.display=id; return not WoW.rejectModel end
            function actor:ClearModel() self.display=nil; self.cleared=true end
            function actor:SetScale(value) self.scale=value end
            function actor:SetUseCenterForOrigin() end
            function actor:SetPosition() end
            function actor:SetYaw(value) self.yaw=value end
            function actor:SetAnimation(...) self.animation={...} end
            function actor:GetActiveBoundingBox() if not WoW.modelTimeout then return -2,-1,-1,2,1,3 end end
            return actor
        end
    elseif kind=="Slider" then
        frame.SetValue=function(self,value)
            value=math.max(self.minimum or 0,math.min(self.maximum or 0,value))
            if value==self.value then return end
            self.value=value
            local fn=self:GetScript("OnValueChanged"); if fn then fn(self,value) end
        end
        frame.GetValue=function(self) return self.value or 0 end
        frame.SetMinMaxValues=function(self,minimum,maximum)
            self.minimum=minimum; self.maximum=maximum; self:SetValue(self:GetValue())
        end
        frame.GetMinMaxValues=function(self) return self.minimum,self.maximum end
        frame.SetEnabled=function(self,value) self.enabled=value end
        frame.IsEnabled=function(self) return self.enabled end
        frame.SetThumbTexture=function(self,file)
            self.thumb=self:CreateTexture(nil,"OVERLAY"); self.thumb:SetTexture(file)
        end
        frame.GetThumbTexture=function(self) return self.thumb end
    elseif kind=="ScrollFrame" then
        frame.SetScrollChild=function(self,child)
            self.child=child
            local setHeight=child.SetHeight
            child.SetHeight=function(c,height)
                setHeight(c,height)
                local fn=self:GetScript("OnScrollRangeChanged"); if fn then fn(self,0,self:GetVerticalScrollRange()) end
            end
        end
        frame.SetVerticalScroll=function(self,value)
            if value==self.scrollOffset then return end
            self.scrollOffset=value
            local fn=self:GetScript("OnVerticalScroll"); if fn then fn(self,value) end
        end
        frame.GetVerticalScroll=function(self) return self.scrollOffset or 0 end
        frame.GetVerticalScrollRange=function(self) return math.max(0,self.child:GetHeight()-self:GetHeight()) end
    end
    return frame
end)
