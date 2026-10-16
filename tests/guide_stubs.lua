-- Extend the existing LibGlass mock locally; no sibling files or second mock world.
-- These implement only state/events used by the browser, not visual correctness.
local create=CreateFrame
rawset(_G,"CreateFrame",function(kind,name,parent,template)
    local frame=create(kind,name,parent,template)
    local makeText=frame.CreateFontString
    frame.CreateFontString=function(self,...)
        local text=makeText(self,...)
        text.GetStringHeight=function(t)
            local lines=0
            for line in ((t:GetText() or "").."\n"):gmatch("(.-)\n") do
                lines=lines+math.max(1,math.ceil(#line/40))
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
    frame.SetPropagateKeyboardInput=function(self,value) self.propagate=value end
    if kind=="EditBox" then
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
    elseif kind=="ScrollFrame" then
        frame.SetScrollChild=function(self,child) self.child=child end
        frame.SetVerticalScroll=function(self,value) self.scrollOffset=value end
        frame.GetVerticalScroll=function(self) return self.scrollOffset or 0 end
        frame.GetVerticalScrollRange=function(self) return math.max(0,self.child:GetHeight()-self:GetHeight()) end
    end
    return frame
end)
