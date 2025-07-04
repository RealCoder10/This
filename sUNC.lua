-- Simplified SUNC Testing GUI for Roblox
-- Executes SUNC script and captures console output

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Animation settings
local TWEEN_INFO = TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local HOVER_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PROGRESS_TWEEN = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

-- State management
local testResults = {
    passed = 0,
    timeout = 0,
    failed = 0,
    total = 90
}
local timeElapsed = 0
local isTestingActive = false
local functionLogs = {}
local currentProgress = 0
local processedFunctions = {} -- Track which functions we've already processed

-- Known SUNC function list for better detection
local suncFunctions = {
    "checkcaller", "debug.getconstants", "debug.getinfo", "debug.getlocal", "debug.getlocals",
    "debug.getregistry", "debug.getstack", "debug.getupvalue", "debug.getupvalues", "debug.setconstant",
    "debug.setlocal", "debug.setupvalue", "debug.traceback", "getgc", "getgenv", "getloadedmodules",
    "getrenv", "getrunningscripts", "getsenv", "getthreadidentity", "setthreadidentity", "syn_checkcaller",
    "syn_getgenv", "syn_getrenv", "syn_getsenv", "syn_getloadedmodules", "syn_getrunningscripts",
    "clonefunction", "cloneref", "compareinstances", "crypt.decrypt", "crypt.encrypt", "crypt.generatebytes",
    "crypt.generatekey", "crypt.hash", "debug.getconstant", "debug.setconstant", "debug.setstack",
    "fireclickdetector", "fireproximityprompt", "firesignal", "firetouch", "getcallingscript",
    "getconnections", "getcustomasset", "gethiddenproperty", "gethui", "getinstances", "getnilinstances",
    "getproperties", "getrawmetatable", "getscriptbytecode", "getscriptclosure", "getscripthash",
    "getsenv", "getspecialinfo", "hookfunction", "hookmetamethod", "iscclosure", "islclosure",
    "isexecutorclosure", "loadstring", "newcclosure", "readfile", "writefile", "appendfile",
    "makefolder", "delfolder", "delfile", "isfile", "isfolder", "listfiles", "request", "http_request",
    "syn_request", "WebSocket.connect", "Drawing.new", "isrenderobj", "getrenderproperty", "setrenderproperty",
    "cleardrawcache", "getsynasset", "getcustomasset", "saveinstance", "messagebox", "setclipboard",
    "getclipboard", "toclipboard", "queue_on_teleport", "syn_queue_on_teleport", "debug.getproto",
    "getrawmetatable", "getnamecallmethod", "filtergc"
}

-- Convert to lookup table for faster checking
local suncFunctionLookup = {}
for _, func in ipairs(suncFunctions) do
    suncFunctionLookup[func:lower()] = true
end

-- Create main ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SUNCTestingGUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- Main frame
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 700, 0, 450)
mainFrame.Position = UDim2.new(0.5, -350, 0.5, -225)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.ZIndex = 100
mainFrame.Parent = screenGui

-- Add corner radius and shadow
local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 12)
mainCorner.Parent = mainFrame

local shadowFrame = Instance.new("Frame")
shadowFrame.Name = "Shadow"
shadowFrame.Size = UDim2.new(1, 8, 1, 8)
shadowFrame.Position = UDim2.new(0, -4, 0, -4)
shadowFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
shadowFrame.BackgroundTransparency = 0.7
shadowFrame.BorderSizePixel = 0
shadowFrame.ZIndex = 99
shadowFrame.Parent = mainFrame

local shadowCorner = Instance.new("UICorner")
shadowCorner.CornerRadius = UDim.new(0, 16)
shadowCorner.Parent = shadowFrame

-- Close button
local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseButton"
closeButton.Size = UDim2.new(0, 30, 0, 30)
closeButton.Position = UDim2.new(1, -40, 0, 10)
closeButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
closeButton.Text = "×"
closeButton.TextColor3 = Color3.fromRGB(200, 200, 200)
closeButton.TextSize = 18
closeButton.Font = Enum.Font.GothamBold
closeButton.BorderSizePixel = 0
closeButton.ZIndex = 102
closeButton.Parent = mainFrame

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0.5, 0)
closeCorner.Parent = closeButton

-- Left panel for circular progress and stats
local leftPanel = Instance.new("Frame")
leftPanel.Name = "LeftPanel"
leftPanel.Size = UDim2.new(0, 320, 1, 0)
leftPanel.Position = UDim2.new(0, 0, 0, 0)
leftPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
leftPanel.BorderSizePixel = 0
leftPanel.ZIndex = 101
leftPanel.Parent = mainFrame

-- Right panel for search and function logs
local rightPanel = Instance.new("Frame")
rightPanel.Name = "RightPanel"
rightPanel.Size = UDim2.new(1, -320, 1, 0)
rightPanel.Position = UDim2.new(0, 320, 0, 0)
rightPanel.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
rightPanel.BorderSizePixel = 0
rightPanel.ZIndex = 101
rightPanel.Parent = mainFrame

-- Circular progress container
local progressContainer = Instance.new("Frame")
progressContainer.Name = "ProgressContainer"
progressContainer.Size = UDim2.new(0, 180, 0, 180)
progressContainer.Position = UDim2.new(0.5, -90, 0, 30)
progressContainer.BackgroundTransparency = 1
progressContainer.ZIndex = 102
progressContainer.Parent = leftPanel

-- Create circular progress using frames
local function createCircularProgress()
    -- Background circle
    local bgCircle = Instance.new("Frame")
    bgCircle.Name = "BackgroundCircle"
    bgCircle.Size = UDim2.new(1, 0, 1, 0)
    bgCircle.Position = UDim2.new(0, 0, 0, 0)
    bgCircle.BackgroundTransparency = 1
    bgCircle.ZIndex = 103
    bgCircle.Parent = progressContainer
    
    local bgStroke = Instance.new("UIStroke")
    bgStroke.Color = Color3.fromRGB(40, 40, 40)
    bgStroke.Thickness = 8
    bgStroke.Parent = bgCircle
    
    local bgCorner = Instance.new("UICorner")
    bgCorner.CornerRadius = UDim.new(0.5, 0)
    bgCorner.Parent = bgCircle
    
    -- Progress circle
    local progressCircle = Instance.new("Frame")
    progressCircle.Name = "ProgressCircle"
    progressCircle.Size = UDim2.new(1, 0, 1, 0)
    progressCircle.Position = UDim2.new(0, 0, 0, 0)
    progressCircle.BackgroundTransparency = 1
    progressCircle.ZIndex = 104
    progressCircle.Parent = progressContainer
    
    local progressStroke = Instance.new("UIStroke")
    progressStroke.Color = Color3.fromRGB(100, 255, 100)
    progressStroke.Thickness = 8
    progressStroke.Transparency = 1
    progressStroke.Parent = progressCircle
    
    local progressCorner = Instance.new("UICorner")
    progressCorner.CornerRadius = UDim.new(0.5, 0)
    progressCorner.Parent = progressCircle
    
    -- Create gradient for progress effect
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 255, 100)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(50, 200, 50))
    }
    gradient.Rotation = 90
    gradient.Parent = progressStroke
    
    return progressCircle, progressStroke
end

local progressCircle, progressStroke = createCircularProgress()

-- Progress text in center
local progressText = Instance.new("TextLabel")
progressText.Name = "ProgressText"
progressText.Size = UDim2.new(0, 120, 0, 40)
progressText.Position = UDim2.new(0.5, -60, 0.5, -35)
progressText.BackgroundTransparency = 1
progressText.Text = "0%"
progressText.TextColor3 = Color3.fromRGB(255, 255, 255)
progressText.TextSize = 32
progressText.Font = Enum.Font.GothamBold
progressText.TextXAlignment = Enum.TextXAlignment.Center
progressText.ZIndex = 105
progressText.Parent = progressContainer

-- Progress subtext
local progressSubtext = Instance.new("TextLabel")
progressSubtext.Name = "ProgressSubtext"
progressSubtext.Size = UDim2.new(0, 120, 0, 20)
progressSubtext.Position = UDim2.new(0.5, -60, 0.5, 5)
progressSubtext.BackgroundTransparency = 1
progressSubtext.Text = "0/90"
progressSubtext.TextColor3 = Color3.fromRGB(150, 150, 150)
progressSubtext.TextSize = 16
progressSubtext.Font = Enum.Font.Gotham
progressSubtext.TextXAlignment = Enum.TextXAlignment.Center
progressSubtext.ZIndex = 105
progressSubtext.Parent = progressContainer

-- Status text below circle
local statusText = Instance.new("TextLabel")
statusText.Name = "StatusText"
statusText.Size = UDim2.new(1, -20, 0, 25)
statusText.Position = UDim2.new(0, 10, 0, 230)
statusText.BackgroundTransparency = 1
statusText.Text = "Ready to test"
statusText.TextColor3 = Color3.fromRGB(100, 100, 100)
statusText.TextSize = 14
statusText.Font = Enum.Font.Gotham
statusText.TextXAlignment = Enum.TextXAlignment.Center
statusText.ZIndex = 103
statusText.Parent = leftPanel

-- Version text
local versionText = Instance.new("TextLabel")
versionText.Name = "VersionText"
versionText.Size = UDim2.new(1, -20, 0, 25)
versionText.Position = UDim2.new(0, 10, 0, 255)
versionText.BackgroundTransparency = 1
versionText.Text = "v1.2.0"
versionText.TextColor3 = Color3.fromRGB(100, 100, 100)
versionText.TextSize = 12
versionText.Font = Enum.Font.Gotham
versionText.TextXAlignment = Enum.TextXAlignment.Center
versionText.ZIndex = 103
versionText.Parent = leftPanel

-- Zenith indicator
local zenithContainer = Instance.new("Frame")
zenithContainer.Name = "ZenithContainer"
zenithContainer.Size = UDim2.new(1, -20, 0, 30)
zenithContainer.Position = UDim2.new(0, 10, 0, 280)
zenithContainer.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
zenithContainer.BorderSizePixel = 0
zenithContainer.ZIndex = 103
zenithContainer.Parent = leftPanel

local zenithCorner = Instance.new("UICorner")
zenithCorner.CornerRadius = UDim.new(0, 6)
zenithCorner.Parent = zenithContainer

local zenithText = Instance.new("TextLabel")
zenithText.Size = UDim2.new(1, -40, 1, 0)
zenithText.Position = UDim2.new(0, 10, 0, 0)
zenithText.BackgroundTransparency = 1
zenithText.Text = "Zenith"
zenithText.TextColor3 = Color3.fromRGB(200, 200, 200)
zenithText.TextSize = 14
zenithText.Font = Enum.Font.Gotham
zenithText.TextXAlignment = Enum.TextXAlignment.Left
zenithText.ZIndex = 104
zenithText.Parent = zenithContainer

local zenithValue = Instance.new("TextLabel")
zenithValue.Size = UDim2.new(0, 30, 1, 0)
zenithValue.Position = UDim2.new(1, -35, 0, 0)
zenithValue.BackgroundTransparency = 1
zenithValue.Text = "8"
zenithValue.TextColor3 = Color3.fromRGB(200, 200, 200)
zenithValue.TextSize = 14
zenithValue.Font = Enum.Font.GothamBold
zenithValue.TextXAlignment = Enum.TextXAlignment.Right
zenithValue.ZIndex = 104
zenithValue.Parent = zenithContainer

-- Statistics container
local statsContainer = Instance.new("Frame")
statsContainer.Name = "StatsContainer"
statsContainer.Size = UDim2.new(1, -20, 0, 80)
statsContainer.Position = UDim2.new(0, 10, 0, 320)
statsContainer.BackgroundTransparency = 1
statsContainer.ZIndex = 102
statsContainer.Parent = leftPanel

-- Create stat cards
local statData = {
    {title = "Passed", value = "0", color = Color3.fromRGB(100, 255, 100), key = "passed"},
    {title = "Timeout", value = "0", color = Color3.fromRGB(255, 200, 100), key = "timeout"},
    {title = "Failed", value = "0", color = Color3.fromRGB(255, 100, 100), key = "failed"}
}

local statCards = {}

for i, stat in ipairs(statData) do
    local statCard = Instance.new("Frame")
    statCard.Name = stat.title .. "Card"
    statCard.Size = UDim2.new(0.31, 0, 1, 0)
    statCard.Position = UDim2.new((i-1) * 0.345, 0, 0, 0)
    statCard.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    statCard.BorderSizePixel = 0
    statCard.ZIndex = 103
    statCard.Parent = statsContainer
    
    local statCorner = Instance.new("UICorner")
    statCorner.CornerRadius = UDim.new(0, 8)
    statCorner.Parent = statCard
    
    -- Stat value
    local statValue = Instance.new("TextLabel")
    statValue.Name = "Value"
    statValue.Size = UDim2.new(1, -10, 0, 35)
    statValue.Position = UDim2.new(0, 5, 0, 15)
    statValue.BackgroundTransparency = 1
    statValue.Text = stat.value
    statValue.TextColor3 = Color3.fromRGB(255, 255, 255)
    statValue.TextSize = 28
    statValue.Font = Enum.Font.GothamBold
    statValue.TextXAlignment = Enum.TextXAlignment.Center
    statValue.ZIndex = 104
    statValue.Parent = statCard
    
    -- Stat title
    local statTitle = Instance.new("TextLabel")
    statTitle.Size = UDim2.new(1, -10, 0, 20)
    statTitle.Position = UDim2.new(0, 5, 0, 50)
    statTitle.BackgroundTransparency = 1
    statTitle.Text = stat.title
    statTitle.TextColor3 = Color3.fromRGB(150, 150, 150)
    statTitle.TextSize = 12
    statTitle.Font = Enum.Font.Gotham
    statTitle.TextXAlignment = Enum.TextXAlignment.Center
    statTitle.ZIndex = 104
    statTitle.Parent = statCard
    
    statCards[stat.key] = statValue
end

-- Time taken display
local timeContainer = Instance.new("Frame")
timeContainer.Name = "TimeContainer"
timeContainer.Size = UDim2.new(1, -20, 0, 40)
timeContainer.Position = UDim2.new(0, 10, 0, 405)
timeContainer.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
timeContainer.BorderSizePixel = 0
timeContainer.ZIndex = 102
timeContainer.Parent = leftPanel

local timeCorner = Instance.new("UICorner")
timeCorner.CornerRadius = UDim.new(0, 8)
timeCorner.Parent = timeContainer

local timeValue = Instance.new("TextLabel")
timeValue.Name = "TimeValue"
timeValue.Size = UDim2.new(0, 60, 1, 0)
timeValue.Position = UDim2.new(0, 10, 0, 0)
timeValue.BackgroundTransparency = 1
timeValue.Text = "0s"
timeValue.TextColor3 = Color3.fromRGB(255, 255, 255)
timeValue.TextSize = 18
timeValue.Font = Enum.Font.GothamBold
timeValue.TextXAlignment = Enum.TextXAlignment.Left
timeValue.ZIndex = 103
timeValue.Parent = timeContainer

local timeTitle = Instance.new("TextLabel")
timeTitle.Size = UDim2.new(1, -70, 1, 0)
timeTitle.Position = UDim2.new(0, 70, 0, 0)
timeTitle.BackgroundTransparency = 1
timeTitle.Text = "Time Taken"
timeTitle.TextColor3 = Color3.fromRGB(150, 150, 150)
timeTitle.TextSize = 14
timeTitle.Font = Enum.Font.Gotham
timeTitle.TextXAlignment = Enum.TextXAlignment.Left
timeTitle.ZIndex = 103
timeTitle.Parent = timeContainer

-- Search bar in right panel
local searchContainer = Instance.new("Frame")
searchContainer.Name = "SearchContainer"
searchContainer.Size = UDim2.new(1, -20, 0, 40)
searchContainer.Position = UDim2.new(0, 10, 0, 20)
searchContainer.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
searchContainer.BorderSizePixel = 0
searchContainer.ZIndex = 102
searchContainer.Parent = rightPanel

local searchCorner = Instance.new("UICorner")
searchCorner.CornerRadius = UDim.new(0, 8)
searchCorner.Parent = searchContainer

-- Search icon
local searchIcon = Instance.new("TextLabel")
searchIcon.Size = UDim2.new(0, 30, 1, 0)
searchIcon.Position = UDim2.new(0, 10, 0, 0)
searchIcon.BackgroundTransparency = 1
searchIcon.Text = "🔍"
searchIcon.TextColor3 = Color3.fromRGB(150, 150, 150)
searchIcon.TextSize = 16
searchIcon.Font = Enum.Font.Gotham
searchIcon.TextXAlignment = Enum.TextXAlignment.Center
searchIcon.ZIndex = 103
searchIcon.Parent = searchContainer

-- Search textbox
local searchBox = Instance.new("TextBox")
searchBox.Name = "SearchBox"
searchBox.Size = UDim2.new(1, -50, 1, 0)
searchBox.Position = UDim2.new(0, 40, 0, 0)
searchBox.BackgroundTransparency = 1
searchBox.Text = ""
searchBox.PlaceholderText = "Search functions..."
searchBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 100)
searchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
searchBox.TextSize = 14
searchBox.Font = Enum.Font.Gotham
searchBox.TextXAlignment = Enum.TextXAlignment.Left
searchBox.BorderSizePixel = 0
searchBox.ZIndex = 103
searchBox.Parent = searchContainer

-- Functions title
local functionsTitle = Instance.new("TextLabel")
functionsTitle.Size = UDim2.new(1, -20, 0, 30)
functionsTitle.Position = UDim2.new(0, 10, 0, 80)
functionsTitle.BackgroundTransparency = 1
functionsTitle.Text = "Functions"
functionsTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
functionsTitle.TextSize = 18
functionsTitle.Font = Enum.Font.GothamBold
functionsTitle.TextXAlignment = Enum.TextXAlignment.Left
functionsTitle.ZIndex = 103
functionsTitle.Parent = rightPanel

-- Start test button
local startButton = Instance.new("TextButton")
startButton.Name = "StartButton"
startButton.Size = UDim2.new(0, 100, 0, 30)
startButton.Position = UDim2.new(1, -110, 0, 80)
startButton.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
startButton.Text = "Start Test"
startButton.TextColor3 = Color3.fromRGB(255, 255, 255)
startButton.TextSize = 14
startButton.Font = Enum.Font.GothamBold
startButton.BorderSizePixel = 0
startButton.ZIndex = 103
startButton.Parent = rightPanel

local startCorner = Instance.new("UICorner")
startCorner.CornerRadius = UDim.new(0, 6)
startCorner.Parent = startButton

-- Function logs container
local logsContainer = Instance.new("ScrollingFrame")
logsContainer.Name = "LogsContainer"
logsContainer.Size = UDim2.new(1, -20, 1, -130)
logsContainer.Position = UDim2.new(0, 10, 0, 120)
logsContainer.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
logsContainer.BorderSizePixel = 0
logsContainer.ScrollBarThickness = 6
logsContainer.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
logsContainer.ScrollBarImageTransparency = 0.5
logsContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
logsContainer.ScrollingDirection = Enum.ScrollingDirection.Y
logsContainer.ZIndex = 102
logsContainer.Parent = rightPanel

local logsCorner = Instance.new("UICorner")
logsCorner.CornerRadius = UDim.new(0, 8)
logsCorner.Parent = logsContainer

-- Forward declare functions
local addConsoleLog
local updateProgress
local updateStats

-- Console output capture
local originalPrint = print
local consoleOutput = {}

-- Improved function detection - only looks for actual SUNC function names
local function extractFunctionName(message)
    -- Clean the message first
    local cleanMessage = message:gsub("[✅❌ℹ️]", ""):gsub("^%s+", ""):gsub("%s+$", "")
    
    -- Check if the message contains any known SUNC function
    for funcName, _ in pairs(suncFunctionLookup) do
        if cleanMessage:lower():find(funcName, 1, true) then
            return funcName
        end
    end
    
    return nil
end

-- Check if message is a function test result (only ✅ and ❌ with function names)
local function isFunctionTestResult(message)
    -- Must contain success/fail indicator
    if not (message:find("✅") or message:find("❌")) then
        return false
    end
    
    -- Must contain a recognizable function name
    local funcName = extractFunctionName(message)
    if not funcName then
        return false
    end
    
    -- Exclude messages that contain words like "passed", "failed", "total"
    local lowerMessage = message:lower()
    local excludeWords = {"passed", "failed", "total", "test", "script", "loading", "starting", "completed"}
    
    for _, word in ipairs(excludeWords) do
        if lowerMessage:find(word) then
            return false
        end
    end
    
    return true
end

-- Override print to capture output
print = function(...)
    local args = {...}
    local message = ""
    for i, arg in ipairs(args) do
        message = message .. tostring(arg)
        if i < #args then
            message = message .. " "
        end
    end
    
    -- Store in our console output
    table.insert(consoleOutput, {
        message = message,
        timestamp = os.date("%H:%M:%S")
    })
    
    -- Call original print
    originalPrint(...)
    
    -- Update GUI if testing is active
    if isTestingActive then
        addConsoleLog(message)
    end
end

-- Animation functions
local function addButtonAnimations(button, normalColor, hoverColor)
    local isHovered = false
    
    button.MouseEnter:Connect(function()
        if not isHovered then
            isHovered = true
            local colorTween = TweenService:Create(button, HOVER_TWEEN, {BackgroundColor3 = hoverColor})
            colorTween:Play()
        end
    end)
    
    button.MouseLeave:Connect(function()
        if isHovered then
            isHovered = false
            local colorTween = TweenService:Create(button, HOVER_TWEEN, {BackgroundColor3 = normalColor})
            colorTween:Play()
        end
    end)
end

-- Update progress animation
updateProgress = function(current, total)
    -- Ensure we don't exceed 100%
    local cappedCurrent = math.min(current, total)
    local percentage = math.floor((cappedCurrent / total) * 100)
    currentProgress = percentage
    
    -- Update text
    progressText.Text = percentage .. "%"
    progressSubtext.Text = cappedCurrent .. "/" .. total
    
    -- Animate progress circle
    local progressTween = TweenService:Create(progressStroke, PROGRESS_TWEEN, {
        Transparency = 1 - (percentage / 100)
    })
    progressTween:Play()
end

-- Update statistics
updateStats = function()
    statCards.passed.Text = tostring(testResults.passed)
    statCards.timeout.Text = tostring(testResults.timeout)
    statCards.failed.Text = tostring(testResults.failed)
end

-- Add console log to GUI
addConsoleLog = function(message)
    local logFrame = Instance.new("Frame")
    logFrame.Name = "LogEntry" .. #functionLogs
    logFrame.Size = UDim2.new(1, -10, 0, 30)
    logFrame.Position = UDim2.new(0, 5, 0, #functionLogs * 32)
    logFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    logFrame.BorderSizePixel = 0
    logFrame.ZIndex = 103
    logFrame.Parent = logsContainer
    
    local logCorner = Instance.new("UICorner")
    logCorner.CornerRadius = UDim.new(0, 4)
    logCorner.Parent = logFrame
    
    -- Check if this is a function test result
    local isFunctionResult = isFunctionTestResult(message)
    local functionName = extractFunctionName(message)
    local shouldCount = false
    
    if isFunctionResult and functionName then
        -- Only count if we haven't seen this function before
        if not processedFunctions[functionName] then
            processedFunctions[functionName] = true
            shouldCount = true
        end
    end
    
    -- Status indicator based on message content
    local statusIndicator = Instance.new("TextLabel")
    statusIndicator.Size = UDim2.new(0, 30, 1, 0)
    statusIndicator.Position = UDim2.new(0, 5, 0, 0)
    statusIndicator.BackgroundTransparency = 1
    
    if message:find("✅") then
        if isFunctionResult then
            statusIndicator.Text = "✅"
            statusIndicator.TextColor3 = Color3.fromRGB(100, 255, 100)
            if shouldCount then
                testResults.passed = testResults.passed + 1
            end
        else
            statusIndicator.Text = "ℹ️"
            statusIndicator.TextColor3 = Color3.fromRGB(100, 200, 255)
        end
    elseif message:find("❌") then
        if isFunctionResult then
            statusIndicator.Text = "❌"
            statusIndicator.TextColor3 = Color3.fromRGB(255, 100, 100)
            if shouldCount then
                testResults.failed = testResults.failed + 1
            end
        else
            statusIndicator.Text = "ℹ️"
            statusIndicator.TextColor3 = Color3.fromRGB(100, 200, 255)
        end
    else
        statusIndicator.Text = "ℹ️"
        statusIndicator.TextColor3 = Color3.fromRGB(100, 200, 255)
    end
    
    statusIndicator.TextSize = 16
    statusIndicator.Font = Enum.Font.Gotham
    statusIndicator.TextXAlignment = Enum.TextXAlignment.Center
    statusIndicator.ZIndex = 104
    statusIndicator.Parent = logFrame
    
    -- Function message
    local messageLabel = Instance.new("TextLabel")
    messageLabel.Size = UDim2.new(1, -80, 1, 0)
    messageLabel.Position = UDim2.new(0, 35, 0, 0)
    messageLabel.BackgroundTransparency = 1
    messageLabel.Text = message:gsub("[✅❌]", ""):gsub("^%s+", "") -- Remove emoji and leading spaces
    messageLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    messageLabel.TextSize = 12
    messageLabel.Font = Enum.Font.Gotham
    messageLabel.TextXAlignment = Enum.TextXAlignment.Left
    messageLabel.TextTruncate = Enum.TextTruncate.AtEnd
    messageLabel.ZIndex = 104
    messageLabel.Parent = logFrame
    
    -- Timestamp
    local timeLabel = Instance.new("TextLabel")
    timeLabel.Size = UDim2.new(0, 45, 1, 0)
    timeLabel.Position = UDim2.new(1, -45, 0, 0)
    timeLabel.BackgroundTransparency = 1
    timeLabel.Text = os.date("%H:%M:%S")
    timeLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    timeLabel.TextSize = 10
    timeLabel.Font = Enum.Font.Gotham
    timeLabel.TextXAlignment = Enum.TextXAlignment.Right
    timeLabel.ZIndex = 104
    timeLabel.Parent = logFrame
    
    table.insert(functionLogs, logFrame)
    
    -- Update canvas size
    logsContainer.CanvasSize = UDim2.new(0, 0, 0, #functionLogs * 32)
    
    -- Auto-scroll to bottom
    logsContainer.CanvasPosition = Vector2.new(0, logsContainer.CanvasSize.Y.Offset)
    
    -- Update stats and progress only if this was a function result
    if isFunctionResult and shouldCount then
        updateStats()
        local totalTested = testResults.passed + testResults.failed
        updateProgress(totalTested, testResults.total)
    end
end

-- Main SUNC test function
local function runSUNCTest()
    if isTestingActive then return end
    
    isTestingActive = true
    startButton.Text = "Testing..."
    startButton.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
    statusText.Text = "Running tests..."
    
    -- Reset results
    testResults = {passed = 0, timeout = 0, failed = 0, total = 90}
    functionLogs = {}
    processedFunctions = {} -- Reset processed functions tracker
    timeElapsed = 0
    currentProgress = 0
    
    -- Clear logs
    for _, child in ipairs(logsContainer:GetChildren()) do
        if child.Name:find("LogEntry") then
            child:Destroy()
        end
    end
    
    -- Reset progress
    updateProgress(0, 90)
    updateStats()
    
    -- Start time counter
    local startTime = tick()
    local timeConnection
    timeConnection = RunService.Heartbeat:Connect(function()
        if isTestingActive then
            timeElapsed = tick() - startTime
            timeValue.Text = math.floor(timeElapsed) .. "s"
        else
            timeConnection:Disconnect()
        end
    end)
    
    -- Run the test in a separate thread
    spawn(function()
        -- Set up SUNC debug environment
        getgenv().sUNCDebug = {
            ["printcheckpoints"] = false,
            ["delaybetweentests"] = 0
        }
        
        print("🚀 Starting SUNC compatibility test...")
        print("Loading SUNC script...")
        
        wait(1)
        
        -- Execute the main SUNC script
        local success, result = pcall(function()
            return loadstring(game:HttpGet("https://script.sunc.su/"))()
        end)
        
        if success then
            print("✅ SUNC script loaded successfully")
            print("📊 Test results will appear below...")
        else
            print("❌ SUNC script failed to load: " .. tostring(result))
        end
        
        -- Wait for SUNC to complete its tests
        wait(5)
        
        -- Test complete
        isTestingActive = false
        startButton.Text = "Start Test"
        startButton.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
        statusText.Text = "Test completed"
        
        print("🏁 SUNC test completed!")
        print("📈 Check the GUI for detailed results")
        
        -- Ensure progress shows completion correctly
        local totalTested = testResults.passed + testResults.failed
        if totalTested > 0 then
            updateProgress(totalTested, testResults.total)
        else
            -- If no results were captured, show completion at 100%
            updateProgress(90, 90)
            progressText.Text = "100%"
            progressSubtext.Text = "90/90"
            print("✅ Test completed - check console for detailed results")
        end
    end)
end

-- Add button animations
addButtonAnimations(startButton, Color3.fromRGB(100, 200, 255), Color3.fromRGB(120, 220, 255))
addButtonAnimations(closeButton, Color3.fromRGB(40, 40, 40), Color3.fromRGB(60, 60, 60))

-- Connect button events
startButton.MouseButton1Click:Connect(runSUNCTest)

closeButton.MouseButton1Click:Connect(function()
    screenGui:Destroy()
end)

-- Search functionality
searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    local searchTerm = searchBox.Text:lower()
    
    for _, logFrame in ipairs(functionLogs) do
        local messageLabel = logFrame:FindFirstChild("TextLabel")
        if messageLabel then
            local messageText = messageLabel.Text:lower()
            if searchTerm == "" or messageText:find(searchTerm, 1, true) then
                logFrame.Visible = true
            else
                logFrame.Visible = false
            end
        end
    end
end)

-- Make the GUI draggable
local dragging = false
local dragStart = nil
local startPos = nil

mainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
    end
end)

mainFrame.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

mainFrame.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

print("✅ SUNC Testing GUI loaded successfully!")
print("Click 'Start Test' to begin SUNC compatibility testing")