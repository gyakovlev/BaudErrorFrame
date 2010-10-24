local SelectedError = 1;
local ErrorList = {};
local SoundTime = 0;
local QueueError = {};

StaticPopupDialogs["CHANGE_ERROR_SOUND"] = {
  text = "Enter path (eg. Interface\\AddOns\\AddOnName\\MySound.wav):",
  button1 = TEXT(ACCEPT),
  button2 = TEXT(CANCEL),
  hasEditBox = 1,
  maxLetters = 100,
  OnAccept = function()
    BaudErrorFrameAcceptSound();
  end,
  OnShow = function(self)
    local EditBox = getglobal(self:GetName().."EditBox");
    EditBox:SetText(BaudErrorFrameConfig.Sound or "");
    EditBox:HighlightText();
    EditBox:SetFocus();
  end,
  OnHide = function(self)
    if DEFAULT_CHAT_FRAME.editBox:IsVisible()then
      DEFAULT_CHAT_FRAME.editBox:SetFocus();
    end
    getglobal(self:GetName().."EditBox"):SetText("");
  end,
  EditBoxOnEnterPressed = function(self)
    BaudErrorFrameAcceptSound();
    self:GetParent():Hide();
  end,
  EditBoxOnEscapePressed = function(self)
    self:GetParent():Hide();
  end,
  timeout = 0,
  exclusive = 1,
  whileDead = 1,
  hideOnEscape = 1
};

function BaudErrorFrame_OnLoad(self)
  BaudErrorFrameVersionText:SetText("Version "..GetAddOnMetadata("!BaudErrorFrame","Version"));

  self:RegisterEvent("VARIABLES_LOADED");
  self:RegisterEvent("ADDON_ACTION_BLOCKED");
  self:RegisterEvent("MACRO_ACTION_BLOCKED");
  self:RegisterEvent("ADDON_ACTION_FORBIDDEN");
  UIParent:UnregisterEvent("ADDON_ACTION_FORBIDDEN");
  self:RegisterEvent("MACRO_ACTION_FORBIDDEN");
  UIParent:UnregisterEvent("MACRO_ACTION_FORBIDDEN");

  tinsert(UISpecialFrames,self:GetName());

  SlashCmdList["BaudErrorFrame"] = function()
    BaudErrorFrame:Show();
  end
  SLASH_BaudErrorFrame1 = "/bauderror";

  seterrorhandler(BaudErrorFrameHandler);
end


function BaudErrorFrame_OnEvent(self, event, ...)
  local arg1, arg2 = ...
  if(event=="VARIABLES_LOADED")then
    if(type(BaudErrorFrameConfig)~="table")then
      BaudErrorFrameConfig = {};
    end
    if(BaudErrorFrameConfig.Sound == nil)then
      --Backwards compatability
      BaudErrorFrameConfig.Sound = BaudErrorFrameSound or "Sound\\Character\\PlayerExertions\\GnomeMaleFinal\\GnomeMaleMainDeathA.wav";
    end
    if(BaudErrorFrameConfig.Messages == nil)then
      BaudErrorFrameConfig.Messages = true;
    end
    BaudErrorFrameChatEnabledText:SetText("Enable Chat Messages");
    BaudErrorFrameChatEnabled:SetChecked(BaudErrorFrameConfig.Messages);

    for Key, Value in ipairs(QueueError)do
      BaudErrorFrameShowError(Value);
    end
    QueueError = nil;

  elseif(event=="ADDON_ACTION_BLOCKED")then
    BaudErrorFrameAdd(arg1.." blocked from using "..arg2,4);

  elseif(event=="MACRO_ACTION_BLOCKED")then
    BaudErrorFrameAdd("Macro blocked from using "..arg1,4);

  elseif(event=="ADDON_ACTION_FORBIDDEN")then
    BaudErrorFrameAdd(arg1.." forbidden from using "..arg2.." (Only usable by Blizzard)",4);

  elseif(event=="MACRO_ACTION_FORBIDDEN")then
    BaudErrorFrameAdd("Macro forbidden from using "..arg1.." (Only usable by Blizzard)",4);
  end
end


function BaudErrorFrameChatEnabled_OnClick(self)
  if self:GetChecked()then
    PlaySound("igMainMenuOptionCheckBoxOff");
  else
    PlaySound("igMainMenuOptionCheckBoxOn");
  end
  BaudErrorFrameConfig.Messages = self:GetChecked()and true or false;
end


function BaudErrorFrameMinimapButton_OnEnter(self)
  if self.Dragging then
    return;
  end
  GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT");
  GameTooltip:AddLine("Baud Error Frame");
  GameTooltip:AddLine("Click to view errors.",1,1,1);
  GameTooltip:AddLine("Shift-drag to move button.",1,1,1);
  GameTooltip:Show();
end


function BaudErrorFrameMinimapButton_OnLeave()
  GameTooltip:Hide();
end


function BaudErrorFrameMinimapButton_OnDragStart(self)
  if IsShiftKeyDown()then
    self.Dragging = true;
    BaudErrorFrameMinimapButton_OnLeave();
  end
end


function BaudErrorFrameMinimapButton_OnDragStop(self)
  self:StopMovingOrSizing();
  self.Dragging = nil;	
  self.Moving = nil;
end


function BaudErrorFrameMinimapButton_OnUpdate(self)
  if not self.Dragging then
    return;
  end
  local MapScale = Minimap:GetEffectiveScale();
  local CX, CY = GetCursorPosition();
  local X, Y = (Minimap:GetRight() - 70) * MapScale, (Minimap:GetTop() - 70) * MapScale;
  local Dist = sqrt(math.pow(X - CX, 2) + math.pow(Y - CY, 2)) / MapScale;
  local Scale = self:GetEffectiveScale();
  if(Dist <= 90)then
    if self.Moving then
      self:StopMovingOrSizing();
      self.Moving = nil;
    end
    local Angle = atan2(CY - Y, X - CX) - 90;
    self:ClearAllPoints();
    self:SetPoint("CENTER", Minimap, "TOPRIGHT", (sin(Angle) * 80 - 70) * MapScale / Scale, (cos(Angle) * 77 - 73) * MapScale / Scale);

  elseif not self.Moving then
    self:ClearAllPoints();
    self:SetPoint("CENTER", UIParent, "BOTTOMLEFT",CX / Scale, CY / Scale);
    self:StartMoving();
    self.Moving = true;
  end
end


function BaudErrorFrameHandler(Error)
  BaudErrorFrameAdd(Error,3);
end


function BaudErrorFrameShowError(Error)
  if BaudErrorFrameConfig.Messages then
    DEFAULT_CHAT_FRAME:AddMessage(Error,0.8,0.1,0.1);
  end
  if(GetTime() > SoundTime)then
    PlaySoundFile(BaudErrorFrameConfig.Sound);
    SoundTime = GetTime() + 1;
  end
end


function BaudErrorFrameAdd(Error, Retrace)
  for Key, Value in pairs(ErrorList)do
    if(Value.Error==Error)then
      if(Value.Count < 99)then
        Value.Count = Value.Count + 1;
        BaudErrorFrameEditBoxUpdate();
      end
      return;
    end
  end
  if BaudErrorFrameConfig then
    BaudErrorFrameShowError(Error);
  else
    tinsert(QueueError, Error);
  end
  tinsert(ErrorList,{Error=Error,Count=1,Stack=debugstack(Retrace)});
  BaudErrorFrameMinimapCount:SetText(getn(ErrorList));
  BaudErrorFrameMinimapButton:Show();
  BaudErrorFrameScrollBar_Update();
end


function BaudErrorFrame_Select(Index)
  SelectedError = Index;
  BaudErrorFrameScrollBar_Update();
  BaudErrorFrameDetailScrollFrameScrollBar:SetValue(0);
end


function BaudErrorFrame_OnShow()
  PlaySound("gsTitleOptionExit");
  BaudErrorFrameScrollBar_Update();
end


function BaudErrorFrame_OnHide()
  PlaySound("gsTitleOptionExit");
end


function BaudErrorFrameEntry_OnClick(self)
  BaudErrorFrame_Select(self:GetID());
end


function BaudErrorFrameClearButton_OnClick(self)
  ErrorList = {};
  BaudErrorFrameMinimapButton:Hide();
  self:GetParent():Hide();
end


function BaudErrorFrameSoundButton_OnClick()
  PlaySound("gsTitleOptionExit");
  StaticPopup_Show("CHANGE_ERROR_SOUND");
end


function BaudErrorFrameAcceptSound(self)
  BaudErrorFrameConfig.Sound = getglobal(self:GetParent():GetName().."EditBox"):GetText();
end

function BaudErrorFrameScrollValue()
	if ErrorList and type(ErrorList)=="table"then
		local value=getn(ErrorList)
		return value
	end
end
function BaudErrorFrameScrollBar_Update()
  if not BaudErrorFrame:IsShown()then
    return;
  end
  local Index, Button, ButtonText, Text;

  local Frame = BaudErrorFrameListScrollBox;
  local FrameName = Frame:GetName();
  local ScrollBar = _G[FrameName.."ScrollBar"];
  local Highlight = _G[FrameName.."Highlight"];
  local Total = getn(ErrorList);
  FauxScrollFrame_Update(ScrollBar,Total,Frame.Entries,16);
  Highlight:Hide();
  for Line = 1, Frame.Entries do
    Index = Line + FauxScrollFrame_GetOffset(ScrollBar);
    Button = _G[FrameName.."Entry"..Line];
    ButtonText = _G[FrameName.."Entry"..Line.."Text"];
    if(Index <= Total)then
      Button:SetID(Index);
      ButtonText:SetText(ErrorList[Index].Error);
      Button:Show();
      if(Index==SelectedError)then
        Highlight:SetPoint("TOP",Button);
        Highlight:Show();
      end
    else
      Button:Hide();
    end
  end
  BaudErrorFrameEditBoxUpdate();
end


function BaudErrorFrameEditBoxUpdate()
  if ErrorList[SelectedError]then
    BaudErrorFrameEditBox.TextShown = ErrorList[SelectedError].Error.."\nCount: "..ErrorList[SelectedError].Count.."\n\nCall Stack:\n"..ErrorList[SelectedError].Stack;
  else
    BaudErrorFrameEditBox.TextShown = "";
  end
  BaudErrorFrameEditBox:SetText(BaudErrorFrameEditBox.TextShown);
--  BaudErrorFrameDetailScrollFrame:UpdateScrollChildRect();
end


function BaudErrorFrameEditBox_OnTextChanged(self)
  if(self:GetText()~=self.TextShown)then
	self:SetText(self.TextShown);
    self:ClearFocus();
    return;
  end
  BaudErrorFrameDetailScrollFrame:UpdateScrollChildRect();
end


function BaudErrorFrameEditBox_OnTextSet()
end
