-- SUNC Testing GUI for Roblox
-- A comprehensive testing interface for SUNC (Script Universal Compatibility) tests
-- Provides real-time feedback on executor function compatibility

--[[
    STRUCTURE:
    1. Constants & Configuration
    2. Utility Functions
    3. UI Factory Functions
    4. Business Logic (Test Management)
    5. Event Handlers
    6. Initialization
]]

-- ========================================
-- CONSTANTS & CONFIGURATION
-- ========================================

local CONFIG = {
    -- UI Dimensions
    MAIN_SIZE = UDim2.new(0, 700, 0, 450),
    LEFT_PANEL_WIDTH = 320,
    
    -- Animation Settings
    TWEEN_INFO = TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
    HOVER_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    PROGRESS_TWEEN = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
    
    -- Test Configuration
    TOTAL_TESTS = 90,
    LOG_ENTRY_HEIGHT = 32,
    UPDATE_INTERVAL = 0.1,
    
    -- Colors
    COLORS = {
        BACKGROUND = Color3.fromRGB(25, 25, 25),
        PANEL_DARK = Color3.fromRGB(20, 20, 20),
        PANEL_LIGHT = Color3.fromRGB(30, 30, 30),
        ACCENT = Color3.fromRGB(35, 35, 35),
        PRIMARY = Color3.fromRGB(100, 200, 255),
        SUCCESS = Color3.fromRGB(100, 255, 100),
        WARNING = Color3.fromRGB(255, 200, 100),
        ERROR = Color3.fromRGB(255, 100, 100),
        INFO = Color3.fromRGB(100, 150, 255),
        TEXT_PRIMARY = Color3.fromRGB(255, 255, 255),
        TEXT_SECONDARY = Color3.fromRGB(200, 200, 200),
        TEXT_MUTED = Color3.fromRGB(150, 150, 150),
        TEXT_DISABLED = Color3.fromRGB(100, 100, 100)
    }
}

-- Known SUNC functions for detection and filtering
local SUNC_FUNCTIONS = {
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
    "getrawmetatable", "getnamecallmethod", "filtergc", "getfunctionhash", "setreadonly", "isreadonly",
    "getfenv", "setfenv", "getupvalue", "setupvalue", "getupvalues", "setupvalues", "getconstant",
    "getconstants", "setconstant", "setconstants", "getprotos", "getproto", "setproto", "getstack",
    "setstack", "getlocal", "setlocal", "getlocals", "setlocals", "getregistry"
}

-- Convert to lookup table for O(1) access
local SUNC_FUNCTION_LOOKUP = {}
for _, func in ipairs(SUNC_FUNCTIONS) do
    SUNC_FUNCTION_LOOKUP[func:lower()] = true
end

-- ========================================
-- SERVICES & GLOBALS
-- ========================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ========================================
-- STATE MANAGEMENT
-- ========================================

local State = {
    testResults = {
        passed = 0,
        timeout = 0,
        failed = 0,
        total = CONFIG.TOTAL_TESTS
    },
    timeElapsed = 0,
    isTestingActive = false,
    functionLogs = {},
    currentProgress = 0,
    processedFunctions = {},
    actualTestCount = 0, -- Track actual tests processed
    
    -- UI References (populated during creation)
    ui = {}
}

-- ========================================
-- UTILITY FUNCTIONS
-- ========================================

--- Validates input parameters
-- @param value: any - The value to validate
-- @param expectedType: string - Expected type
-- @param paramName: string - Parameter name for error messages
-- @return boolean - Whether validation passed
local function validateInput(value, expectedType, paramName)
    if type(value) ~= expectedType then
        warn(string.format("Invalid %s: expected %s, got %s", paramName, expectedType, type(value)))
        return false
    end
    return true
end

--- Safely executes a function with error handling
-- @param func: function - Function to execute
-- @param errorMessage: string - Custom error message
-- @return boolean, any - Success status and result/error
local function safeExecute(func, errorMessage)
    if not validateInput(func, "function", "func") then
        return false, "Invalid function parameter"
    end
    
    local success, result = pcall(func)
    if not success then
        warn(errorMessage .. ": " .. tostring(result))
    end
    return success, result
end

--- Extracts function name from console message with improved detection
-- @param message: string - Console message to parse
-- @return string|nil - Function name if found
local function extractFunctionName(message)
    if not validateInput(message, "string", "message") then
        return nil
    end
    
    -- Clean the message of status indicators and whitespace
    local cleanMessage = message:gsub("[✅❌ℹ️❕⚠️]", ""):gsub("^%s+", ""):gsub("%s+$", "")
    
    -- Look for function names in the message
    for funcName, _ in pairs(SUNC_FUNCTION_LOOKUP) do
        -- Check for exact matches and common patterns
        local patterns = {
            "^" .. funcName .. "$",  -- Exact match
            "^" .. funcName .. "%s",  -- Function name at start
            "%s" .. funcName .. "$",  -- Function name at end
            "%s" .. funcName .. "%s", -- Function name in middle
            "'" .. funcName .. "'",   -- Quoted function name
            '"' .. funcName .. '"',   -- Double quoted function name
            funcName .. "%(", -- Function call pattern
            funcName .. "%.", -- Method call pattern
        }
        
        for _, pattern in ipairs(patterns) do
            if cleanMessage:lower():find(pattern) then
                return funcName
            end
        end
    end
    
    return nil
end

--- Determines if message represents a function test result with improved logic
-- @param message: string - Message to analyze
-- @return boolean - Whether this is a function test result
local function isFunctionTestResult(message)
    if not validateInput(message, "string", "message") then
        return false
    end
    
    local lowerMessage = message:lower()
    
    -- Skip obvious non-function messages
    local skipPatterns = {
        "getting", "loading", "starting", "completed", "past", "debug:",
        "test completed", "script loaded", "results will appear",
        "sunc test", "compatibility test", "check the gui"
    }
    
    for _, pattern in ipairs(skipPatterns) do
        if lowerMessage:find(pattern, 1, true) then
            return false
        end
    end
    
    -- Must contain a recognizable function name
    local funcName = extractFunctionName(message)
    if not funcName then
        return false
    end
    
    -- Additional validation for function test results
    -- Look for patterns that indicate this is a test result
    local resultPatterns = {
        "function is nil",
        "neutral",
        "passed",
        "failed",
        "working",
        "not working",
        "error",
        "success"
    }
    
    local hasResultPattern = false
    for _, pattern in ipairs(resultPatterns) do
        if lowerMessage:find(pattern, 1, true) then
            hasResultPattern = true
            break
        end
    end
    
    -- If it has a function name and either a status indicator or result pattern, it's likely a test result
    return hasResultPattern or message:find("[✅❌❕⚠️]")
end

--- Creates a UI corner with specified radius
-- @param parent: Instance - Parent object
-- @param radius: number - Corner radius (default: 8)
-- @return UICorner - Created corner object
local function createCorner(parent, radius)
    radius = radius or 8
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = parent
    return corner
end

--- Adds hover animations to a button
-- @param button: GuiButton - Button to animate
-- @param normalColor: Color3 - Normal state color
-- @param hoverColor: Color3 - Hover state color
local function addButtonAnimations(button, normalColor, hoverColor)
    if not button or not button:IsA("GuiButton") then
        warn("Invalid button provided to addButtonAnimations")
        return
    end
    
    local isHovered = false
    
    button.MouseEnter:Connect(function()
        if not isHovered then
            isHovered = true
            local colorTween = TweenService:Create(button, CONFIG.HOVER_TWEEN, {BackgroundColor3 = hoverColor})
            colorTween:Play()
        end
    end)
    
    button.MouseLeave:Connect(function()
        if isHovered then
            isHovered = false
            local colorTween = TweenService:Create(button, CONFIG.HOVER_TWEEN, {BackgroundColor3 = normalColor})
            colorTween:Play()
        end
    end)
end

-- ========================================
-- UI FACTORY FUNCTIONS
-- ========================================

--- Creates the main GUI container
-- @return ScreenGui - Main screen GUI
local function createMainGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "SUNCTestingGUI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = playerGui
    
    return screenGui
end

--- Creates the main frame with shadow (fixed dragging)
-- @param parent: Instance - Parent container
-- @return Frame, Frame - Main frame and shadow frame
local function createMainFrame(parent)
    -- Container frame for both shadow and main frame
    local containerFrame = Instance.new("Frame")
    containerFrame.Name = "Container"
    containerFrame.Size = UDim2.new(0, CONFIG.MAIN_SIZE.X.Offset + 8, 0, CONFIG.MAIN_SIZE.Y.Offset + 8)
    containerFrame.Position = UDim2.new(0.5, -(CONFIG.MAIN_SIZE.X.Offset + 8)/2, 0.5, -(CONFIG.MAIN_SIZE.Y.Offset + 8)/2)
    containerFrame.BackgroundTransparency = 1
    containerFrame.BorderSizePixel = 0
    containerFrame.ZIndex = 99
    containerFrame.Parent = parent
    
    -- Shadow frame
    local shadowFrame = Instance.new("Frame")
    shadowFrame.Name = "Shadow"
    shadowFrame.Size = UDim2.new(1, 0, 1, 0)
    shadowFrame.Position = UDim2.new(0, 0, 0, 0)
    shadowFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    shadowFrame.BackgroundTransparency = 0.7
    shadowFrame.BorderSizePixel = 0
    shadowFrame.ZIndex = 99
    shadowFrame.Parent = containerFrame
    createCorner(shadowFrame, 16)
    
    -- Main frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, CONFIG.MAIN_SIZE.X.Offset, 0, CONFIG.MAIN_SIZE.Y.Offset)
    mainFrame.Position = UDim2.new(0, 4, 0, 4)
    mainFrame.BackgroundColor3 = CONFIG.COLORS.BACKGROUND
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = true
    mainFrame.ZIndex = 100
    mainFrame.Parent = containerFrame
    createCorner(mainFrame, 12)
    
    return mainFrame, containerFrame
end

--- Creates a close button
-- @param parent: Instance - Parent container
-- @return TextButton - Close button
local function createCloseButton(parent)
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -40, 0, 10)
    closeButton.BackgroundColor3 = CONFIG.COLORS.ACCENT
    closeButton.Text = "×"
    closeButton.TextColor3 = CONFIG.COLORS.TEXT_SECONDARY
    closeButton.TextSize = 18
    closeButton.Font = Enum.Font.GothamBold
    closeButton.BorderSizePixel = 0
    closeButton.ZIndex = 102
    closeButton.Parent = parent
    createCorner(closeButton, 15)
    
    return closeButton
end

--- Creates the left panel with progress and stats
-- @param parent: Instance - Parent container
-- @return Frame, table - Left panel and UI references
local function createLeftPanel(parent)
    local leftPanel = Instance.new("Frame")
    leftPanel.Name = "LeftPanel"
    leftPanel.Size = UDim2.new(0, CONFIG.LEFT_PANEL_WIDTH, 1, 0)
    leftPanel.Position = UDim2.new(0, 0, 0, 0)
    leftPanel.BackgroundColor3 = CONFIG.COLORS.PANEL_DARK
    leftPanel.BorderSizePixel = 0
    leftPanel.ZIndex = 101
    leftPanel.Parent = parent
    
    local ui = {}
    
    -- Progress container
    local progressContainer = Instance.new("Frame")
    progressContainer.Name = "ProgressContainer"
    progressContainer.Size = UDim2.new(0, 180, 0, 180)
    progressContainer.Position = UDim2.new(0.5, -90, 0, 30)
    progressContainer.BackgroundTransparency = 1
    progressContainer.ZIndex = 102
    progressContainer.Parent = leftPanel
    
    -- Background circle
    local bgCircle = Instance.new("Frame")
    bgCircle.Size = UDim2.new(1, 0, 1, 0)
    bgCircle.BackgroundTransparency = 1
    bgCircle.ZIndex = 103
    bgCircle.Parent = progressContainer
    createCorner(bgCircle, 90)
    
    local bgStroke = Instance.new("UIStroke")
    bgStroke.Color = CONFIG.COLORS.ACCENT
    bgStroke.Thickness = 8
    bgStroke.Parent = bgCircle
    
    -- Progress circle
    local progressCircle = Instance.new("Frame")
    progressCircle.Size = UDim2.new(1, 0, 1, 0)
    progressCircle.BackgroundTransparency = 1
    progressCircle.ZIndex = 104
    progressCircle.Parent = progressContainer
    createCorner(progressCircle, 90)
    
    local progressStroke = Instance.new("UIStroke")
    progressStroke.Color = CONFIG.COLORS.SUCCESS
    progressStroke.Thickness = 8
    progressStroke.Transparency = 1
    progressStroke.Parent = progressCircle
    ui.progressStroke = progressStroke
    
    -- Progress text
    local progressText = Instance.new("TextLabel")
    progressText.Size = UDim2.new(0, 120, 0, 40)
    progressText.Position = UDim2.new(0.5, -60, 0.5, -35)
    progressText.BackgroundTransparency = 1
    progressText.Text = "0%"
    progressText.TextColor3 = CONFIG.COLORS.TEXT_PRIMARY
    progressText.TextSize = 32
    progressText.Font = Enum.Font.GothamBold
    progressText.TextXAlignment = Enum.TextXAlignment.Center
    progressText.ZIndex = 105
    progressText.Parent = progressContainer
    ui.progressText = progressText
    
    -- Progress subtext
    local progressSubtext = Instance.new("TextLabel")
    progressSubtext.Size = UDim2.new(0, 120, 0, 20)
    progressSubtext.Position = UDim2.new(0.5, -60, 0.5, 5)
    progressSubtext.BackgroundTransparency = 1
    progressSubtext.Text = "0/" .. CONFIG.TOTAL_TESTS
    progressSubtext.TextColor3 = CONFIG.COLORS.TEXT_MUTED
    progressSubtext.TextSize = 16
    progressSubtext.Font = Enum.Font.Gotham
    progressSubtext.TextXAlignment = Enum.TextXAlignment.Center
    progressSubtext.ZIndex = 105
    progressSubtext.Parent = progressContainer
    ui.progressSubtext = progressSubtext
    
    -- Status text
    local statusText = Instance.new("TextLabel")
    statusText.Size = UDim2.new(1, -20, 0, 25)
    statusText.Position = UDim2.new(0, 10, 0, 230)
    statusText.BackgroundTransparency = 1
    statusText.Text = "Ready to test"
    statusText.TextColor3 = CONFIG.COLORS.TEXT_DISABLED
    statusText.TextSize = 14
    statusText.Font = Enum.Font.Gotham
    statusText.TextXAlignment = Enum.TextXAlignment.Center
    statusText.ZIndex = 103
    statusText.Parent = leftPanel
    ui.statusText = statusText
    
    -- Version text
    local versionText = Instance.new("TextLabel")
    versionText.Size = UDim2.new(1, -20, 0, 25)
    versionText.Position = UDim2.new(0, 10, 0, 255)
    versionText.BackgroundTransparency = 1
    versionText.Text = "v2.2.0"
    versionText.TextColor3 = CONFIG.COLORS.TEXT_DISABLED
    versionText.TextSize = 12
    versionText.Font = Enum.Font.Gotham
    versionText.TextXAlignment = Enum.TextXAlignment.Center
    versionText.ZIndex = 103
    versionText.Parent = leftPanel
    
    -- Statistics
    local statsContainer = Instance.new("Frame")
    statsContainer.Size = UDim2.new(1, -20, 0, 80)
    statsContainer.Position = UDim2.new(0, 10, 0, 320)
    statsContainer.BackgroundTransparency = 1
    statsContainer.ZIndex = 102
    statsContainer.Parent = leftPanel
    
    local statData = {
        {title = "Passed", key = "passed", color = CONFIG.COLORS.SUCCESS},
        {title = "Timeout", key = "timeout", color = CONFIG.COLORS.WARNING},
        {title = "Failed", key = "failed", color = CONFIG.COLORS.ERROR}
    }
    
    ui.statCards = {}
    
    for i, stat in ipairs(statData) do
        local statCard = Instance.new("Frame")
        statCard.Size = UDim2.new(0.31, 0, 1, 0)
        statCard.Position = UDim2.new((i-1) * 0.345, 0, 0, 0)
        statCard.BackgroundColor3 = CONFIG.COLORS.PANEL_LIGHT
        statCard.BorderSizePixel = 0
        statCard.ZIndex = 103
        statCard.Parent = statsContainer
        createCorner(statCard, 8)
        
        local statValue = Instance.new("TextLabel")
        statValue.Size = UDim2.new(1, -10, 0, 35)
        statValue.Position = UDim2.new(0, 5, 0, 15)
        statValue.BackgroundTransparency = 1
        statValue.Text = "0"
        statValue.TextColor3 = CONFIG.COLORS.TEXT_PRIMARY
        statValue.TextSize = 28
        statValue.Font = Enum.Font.GothamBold
        statValue.TextXAlignment = Enum.TextXAlignment.Center
        statValue.ZIndex = 104
        statValue.Parent = statCard
        ui.statCards[stat.key] = statValue
        
        local statTitle = Instance.new("TextLabel")
        statTitle.Size = UDim2.new(1, -10, 0, 20)
        statTitle.Position = UDim2.new(0, 5, 0, 50)
        statTitle.BackgroundTransparency = 1
        statTitle.Text = stat.title
        statTitle.TextColor3 = CONFIG.COLORS.TEXT_MUTED
        statTitle.TextSize = 12
        statTitle.Font = Enum.Font.Gotham
        statTitle.TextXAlignment = Enum.TextXAlignment.Center
        statTitle.ZIndex = 104
        statTitle.Parent = statCard
    end
    
    -- Time container
    local timeContainer = Instance.new("Frame")
    timeContainer.Size = UDim2.new(1, -20, 0, 40)
    timeContainer.Position = UDim2.new(0, 10, 0, 405)
    timeContainer.BackgroundColor3 = CONFIG.COLORS.PANEL_LIGHT
    timeContainer.BorderSizePixel = 0
    timeContainer.ZIndex = 102
    timeContainer.Parent = leftPanel
    createCorner(timeContainer, 8)
    
    local timeValue = Instance.new("TextLabel")
    timeValue.Size = UDim2.new(0, 60, 1, 0)
    timeValue.Position = UDim2.new(0, 10, 0, 0)
    timeValue.BackgroundTransparency = 1
    timeValue.Text = "0s"
    timeValue.TextColor3 = CONFIG.COLORS.TEXT_PRIMARY
    timeValue.TextSize = 18
    timeValue.Font = Enum.Font.GothamBold
    timeValue.TextXAlignment = Enum.TextXAlignment.Left
    timeValue.ZIndex = 103
    timeValue.Parent = timeContainer
    ui.timeValue = timeValue
    
    local timeTitle = Instance.new("TextLabel")
    timeTitle.Size = UDim2.new(1, -70, 1, 0)
    timeTitle.Position = UDim2.new(0, 70, 0, 0)
    timeTitle.BackgroundTransparency = 1
    timeTitle.Text = "Time Taken"
    timeTitle.TextColor3 = CONFIG.COLORS.TEXT_MUTED
    timeTitle.TextSize = 14
    timeTitle.Font = Enum.Font.Gotham
    timeTitle.TextXAlignment = Enum.TextXAlignment.Left
    timeTitle.ZIndex = 103
    timeTitle.Parent = timeContainer
    
    return leftPanel, ui
end

--- Creates the right panel with search and logs
-- @param parent: Instance - Parent container
-- @return Frame, table - Right panel and UI references
local function createRightPanel(parent)
    local rightPanel = Instance.new("Frame")
    rightPanel.Name = "RightPanel"
    rightPanel.Size = UDim2.new(1, -CONFIG.LEFT_PANEL_WIDTH, 1, 0)
    rightPanel.Position = UDim2.new(0, CONFIG.LEFT_PANEL_WIDTH, 0, 0)
    rightPanel.BackgroundColor3 = CONFIG.COLORS.BACKGROUND
    rightPanel.BorderSizePixel = 0
    rightPanel.ZIndex = 101
    rightPanel.Parent = parent
    
    local ui = {}
    
    -- Search container
    local searchContainer = Instance.new("Frame")
    searchContainer.Size = UDim2.new(1, -20, 0, 40)
    searchContainer.Position = UDim2.new(0, 10, 0, 20)
    searchContainer.BackgroundColor3 = CONFIG.COLORS.ACCENT
    searchContainer.BorderSizePixel = 0
    searchContainer.ZIndex = 102
    searchContainer.Parent = rightPanel
    createCorner(searchContainer, 8)
    
    -- Search icon
    local searchIcon = Instance.new("TextLabel")
    searchIcon.Size = UDim2.new(0, 30, 1, 0)
    searchIcon.Position = UDim2.new(0, 10, 0, 0)
    searchIcon.BackgroundTransparency = 1
    searchIcon.Text = "🔍"
    searchIcon.TextColor3 = CONFIG.COLORS.TEXT_MUTED
    searchIcon.TextSize = 16
    searchIcon.Font = Enum.Font.Gotham
    searchIcon.TextXAlignment = Enum.TextXAlignment.Center
    searchIcon.ZIndex = 103
    searchIcon.Parent = searchContainer
    
    -- Search textbox
    local searchBox = Instance.new("TextBox")
    searchBox.Size = UDim2.new(1, -50, 1, 0)
    searchBox.Position = UDim2.new(0, 40, 0, 0)
    searchBox.BackgroundTransparency = 1
    searchBox.Text = ""
    searchBox.PlaceholderText = "Search functions..."
    searchBox.PlaceholderColor3 = CONFIG.COLORS.TEXT_DISABLED
    searchBox.TextColor3 = CONFIG.COLORS.TEXT_PRIMARY
    searchBox.TextSize = 14
    searchBox.Font = Enum.Font.Gotham
    searchBox.TextXAlignment = Enum.TextXAlignment.Left
    searchBox.BorderSizePixel = 0
    searchBox.ZIndex = 103
    searchBox.Parent = searchContainer
    ui.searchBox = searchBox
    
    -- Functions title
    local functionsTitle = Instance.new("TextLabel")
    functionsTitle.Size = UDim2.new(1, -120, 0, 30)
    functionsTitle.Position = UDim2.new(0, 10, 0, 80)
    functionsTitle.BackgroundTransparency = 1
    functionsTitle.Text = "Functions"
    functionsTitle.TextColor3 = CONFIG.COLORS.TEXT_PRIMARY
    functionsTitle.TextSize = 18
    functionsTitle.Font = Enum.Font.GothamBold
    functionsTitle.TextXAlignment = Enum.TextXAlignment.Left
    functionsTitle.ZIndex = 103
    functionsTitle.Parent = rightPanel
    
    -- Start test button
    local startButton = Instance.new("TextButton")
    startButton.Size = UDim2.new(0, 100, 0, 30)
    startButton.Position = UDim2.new(1, -110, 0, 80)
    startButton.BackgroundColor3 = CONFIG.COLORS.PRIMARY
    startButton.Text = "Start Test"
    startButton.TextColor3 = CONFIG.COLORS.TEXT_PRIMARY
    startButton.TextSize = 14
    startButton.Font = Enum.Font.GothamBold
    startButton.BorderSizePixel = 0
    startButton.ZIndex = 103
    startButton.Parent = rightPanel
    createCorner(startButton, 6)
    ui.startButton = startButton
    
    -- Function logs container
    local logsContainer = Instance.new("ScrollingFrame")
    logsContainer.Size = UDim2.new(1, -20, 1, -130)
    logsContainer.Position = UDim2.new(0, 10, 0, 120)
    logsContainer.BackgroundColor3 = CONFIG.COLORS.PANEL_LIGHT
    logsContainer.BorderSizePixel = 0
    logsContainer.ScrollBarThickness = 6
    logsContainer.ScrollBarImageColor3 = CONFIG.COLORS.TEXT_DISABLED
    logsContainer.ScrollBarImageTransparency = 0.5
    logsContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
    logsContainer.ScrollingDirection = Enum.ScrollingDirection.Y
    logsContainer.ZIndex = 102
    logsContainer.Parent = rightPanel
    createCorner(logsContainer, 8)
    ui.logsContainer = logsContainer
    
    return rightPanel, ui
end

-- ========================================
-- BUSINESS LOGIC
-- ========================================

--- Updates the progress display with correct calculation
-- @param current: number - Current progress value
-- @param total: number - Total possible value
local function updateProgress(current, total)
    if not validateInput(current, "number", "current") or not validateInput(total, "number", "total") then
        return
    end
    
    local cappedCurrent = math.min(current, total)
    local percentage = math.floor((cappedCurrent / total) * 100)
    State.currentProgress = percentage
    
    State.ui.progressText.Text = percentage .. "%"
    State.ui.progressSubtext.Text = cappedCurrent .. "/" .. total
    
    local progressTween = TweenService:Create(State.ui.progressStroke, CONFIG.PROGRESS_TWEEN, {
        Transparency = 1 - (percentage / 100)
    })
    progressTween:Play()
end

--- Updates the statistics display
local function updateStats()
    for key, card in pairs(State.ui.statCards) do
        if State.testResults[key] then
            card.Text = tostring(State.testResults[key])
        end
    end
end

--- Adds a console log entry to the GUI with improved detection
-- @param message: string - Log message to add
local function addConsoleLog(message)
    if not validateInput(message, "string", "message") then
        return
    end
    
    local logFrame = Instance.new("Frame")
    logFrame.Name = "LogEntry" .. #State.functionLogs
    logFrame.Size = UDim2.new(1, -10, 0, 30)
    logFrame.Position = UDim2.new(0, 5, 0, #State.functionLogs * CONFIG.LOG_ENTRY_HEIGHT)
    logFrame.BackgroundColor3 = CONFIG.COLORS.ACCENT
    logFrame.BorderSizePixel = 0
    logFrame.ZIndex = 103
    logFrame.Parent = State.ui.logsContainer
    createCorner(logFrame, 4)
    
    local isFunctionResult = isFunctionTestResult(message)
    local functionName = extractFunctionName(message)
    local shouldCount = false
    
    if isFunctionResult and functionName then
        if not State.processedFunctions[functionName] then
            State.processedFunctions[functionName] = true
            shouldCount = true
            State.actualTestCount = State.actualTestCount + 1
        end
    end
    
    -- Status indicator with improved logic
    local statusIndicator = Instance.new("TextLabel")
    statusIndicator.Size = UDim2.new(0, 30, 1, 0)
    statusIndicator.Position = UDim2.new(0, 5, 0, 0)
    statusIndicator.BackgroundTransparency = 1
    statusIndicator.TextSize = 16
    statusIndicator.Font = Enum.Font.Gotham
    statusIndicator.TextXAlignment = Enum.TextXAlignment.Center
    statusIndicator.ZIndex = 104
    statusIndicator.Parent = logFrame
    
    -- Determine status based on message content
    if message:find("✅") or (isFunctionResult and (message:lower():find("working") or message:lower():find("passed"))) then
        statusIndicator.Text = "✅"
        statusIndicator.TextColor3 = CONFIG.COLORS.SUCCESS
        if shouldCount then
            State.testResults.passed = State.testResults.passed + 1
        end
    elseif message:find("❌") or (isFunctionResult and (message:lower():find("function is nil") or message:lower():find("failed") or message:lower():find("error"))) then
        statusIndicator.Text = "❌"
        statusIndicator.TextColor3 = CONFIG.COLORS.ERROR
        if shouldCount then
            State.testResults.failed = State.testResults.failed + 1
        end
    elseif message:find("❕") or message:find("⚠️") or (isFunctionResult and message:lower():find("neutral")) then
        statusIndicator.Text = "❕"
        statusIndicator.TextColor3 = CONFIG.COLORS.WARNING
        if shouldCount then
            State.testResults.timeout = State.testResults.timeout + 1
        end
    else
        statusIndicator.Text = "ℹ️"
        statusIndicator.TextColor3 = CONFIG.COLORS.INFO
    end
    
    -- Message label
    local messageLabel = Instance.new("TextLabel")
    messageLabel.Size = UDim2.new(1, -80, 1, 0)
    messageLabel.Position = UDim2.new(0, 35, 0, 0)
    messageLabel.BackgroundTransparency = 1
    messageLabel.Text = message:gsub("[✅❌❕⚠️ℹ️]", ""):gsub("^%s+", "")
    messageLabel.TextColor3 = CONFIG.COLORS.TEXT_PRIMARY
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
    timeLabel.TextColor3 = CONFIG.COLORS.TEXT_MUTED
    timeLabel.TextSize = 10
    timeLabel.Font = Enum.Font.Gotham
    timeLabel.TextXAlignment = Enum.TextXAlignment.Right
    timeLabel.ZIndex = 104
    timeLabel.Parent = logFrame
    
    table.insert(State.functionLogs, logFrame)
    
    -- Update canvas size and scroll
    State.ui.logsContainer.CanvasSize = UDim2.new(0, 0, 0, #State.functionLogs * CONFIG.LOG_ENTRY_HEIGHT)
    State.ui.logsContainer.CanvasPosition = Vector2.new(0, State.ui.logsContainer.CanvasSize.Y.Offset)
    
    -- Update stats and progress if this was a function result
    if isFunctionResult and shouldCount then
        updateStats()
        -- Use actual test count for more accurate progress
        updateProgress(State.actualTestCount, State.testResults.total)
    end
end

--- Runs the SUNC compatibility test
local function runSUNCTest()
    if State.isTestingActive then 
        warn("Test already in progress")
        return 
    end
    
    State.isTestingActive = true
    State.ui.startButton.Text = "Testing..."
    State.ui.startButton.BackgroundColor3 = CONFIG.COLORS.TEXT_MUTED
    State.ui.statusText.Text = "Running tests..."
    
    -- Reset state
    State.testResults = {passed = 0, timeout = 0, failed = 0, total = CONFIG.TOTAL_TESTS}
    State.functionLogs = {}
    State.processedFunctions = {}
    State.timeElapsed = 0
    State.currentProgress = 0
    State.actualTestCount = 0
    
    -- Clear existing logs
    for _, child in ipairs(State.ui.logsContainer:GetChildren()) do
        if child.Name:find("LogEntry") then
            child:Destroy()
        end
    end
    
    -- Reset displays
    updateProgress(0, CONFIG.TOTAL_TESTS)
    updateStats()
    
    -- Start time tracking
    local startTime = tick()
    local timeConnection
    timeConnection = RunService.Heartbeat:Connect(function()
        if State.isTestingActive then
            State.timeElapsed = tick() - startTime
            State.ui.timeValue.Text = math.floor(State.timeElapsed) .. "s"
        else
            timeConnection:Disconnect()
        end
    end)
    
    -- Override print to capture SUNC output
    local originalPrint = print
    print = function(...)
        local args = {...}
        local message = ""
        for i, arg in ipairs(args) do
            message = message .. tostring(arg)
            if i < #args then
                message = message .. " "
            end
        end
        
        originalPrint(...)
        
        if State.isTestingActive then
            addConsoleLog(message)
        end
    end
    
    -- Run test in separate thread
    spawn(function()
        safeExecute(function()
            -- Set up SUNC debug environment
            getgenv().sUNCDebug = {
                ["printcheckpoints"] = false,
                ["delaybetweentests"] = 0
            }
            
            print("🚀 Starting SUNC compatibility test...")
            print("📥 Loading SUNC script...")
            
            wait(1)
            
            -- Execute SUNC script
            local success, result = safeExecute(function()
                return loadstring(game:HttpGet("https://script.sunc.su/"))()
            end, "Failed to load SUNC script")
            
            if success then
                print("✅ SUNC script loaded successfully")
                print("📊 Test results will appear above...")
            else
                print("❌ SUNC script failed to load: " .. tostring(result))
            end
            
            -- Wait for tests to complete
            wait(5)
            
        end, "Error during SUNC test execution")
        
        -- Restore original print
        print = originalPrint
        
        -- Test complete
        State.isTestingActive = false
        State.ui.startButton.Text = "Start Test"
        State.ui.startButton.BackgroundColor3 = CONFIG.COLORS.PRIMARY
        State.ui.statusText.Text = "Test completed"
        
        print("🏁 SUNC test completed!")
        print("📈 Check the GUI for detailed results")
        
        -- Final progress update using actual test count
        if State.actualTestCount > 0 then
            updateProgress(State.actualTestCount, State.actualTestCount)
            -- Update the total to match actual tests found
            State.testResults.total = State.actualTestCount
            State.ui.progressSubtext.Text = State.actualTestCount .. "/" .. State.actualTestCount
        else
            updateProgress(CONFIG.TOTAL_TESTS, CONFIG.TOTAL_TESTS)
            State.ui.progressText.Text = "100%"
            State.ui.progressSubtext.Text = CONFIG.TOTAL_TESTS .. "/" .. CONFIG.TOTAL_TESTS
        end
    end)
end

-- ========================================
-- EVENT HANDLERS
-- ========================================

--- Sets up search functionality
-- @param searchBox: TextBox - Search input box
local function setupSearch(searchBox)
    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        local searchTerm = searchBox.Text:lower()
        
        for _, logFrame in ipairs(State.functionLogs) do
            local messageLabel = logFrame:FindFirstChild("TextLabel")
            if messageLabel then
                local messageText = messageLabel.Text:lower()
                logFrame.Visible = searchTerm == "" or messageText:find(searchTerm, 1, true) ~= nil
            end
        end
    end)
end

--- Sets up drag functionality for the container frame (fixed shadow issue)
-- @param containerFrame: Frame - Container frame that holds both shadow and main frame
local function setupDragging(containerFrame)
    local dragging = false
    local dragStart = nil
    local startPos = nil
    
    -- Get the main frame for input detection
    local mainFrame = containerFrame:FindFirstChild("MainFrame")
    if not mainFrame then return end
    
    mainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = containerFrame.Position
        end
    end)
    
    mainFrame.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            containerFrame.Position = UDim2.new(
                startPos.X.Scale, 
                startPos.X.Offset + delta.X, 
                startPos.Y.Scale, 
                startPos.Y.Offset + delta.Y
            )
        end
    end)
    
    mainFrame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
end

-- ========================================
-- INITIALIZATION
-- ========================================

--- Main initialization function
local function initialize()
    print("🔧 Initializing SUNC Testing GUI...")
    
    -- Create main GUI structure
    local screenGui = createMainGUI()
    local mainFrame, containerFrame = createMainFrame(screenGui)
    local closeButton = createCloseButton(mainFrame)
    
    -- Create panels
    local leftPanel, leftUI = createLeftPanel(mainFrame)
    local rightPanel, rightUI = createRightPanel(mainFrame)
    
    -- Merge UI references
    for key, value in pairs(leftUI) do
        State.ui[key] = value
    end
    for key, value in pairs(rightUI) do
        State.ui[key] = value
    end
    
    -- Set up animations
    addButtonAnimations(State.ui.startButton, CONFIG.COLORS.PRIMARY, Color3.fromRGB(120, 220, 255))
    addButtonAnimations(closeButton, CONFIG.COLORS.ACCENT, Color3.fromRGB(60, 60, 60))
    
    -- Set up event handlers
    State.ui.startButton.MouseButton1Click:Connect(runSUNCTest)
    closeButton.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)
    
    setupSearch(State.ui.searchBox)
    setupDragging(containerFrame) -- Pass container frame instead of main frame
    
    print("✅ SUNC Testing GUI loaded successfully!")
    print("📋 Click 'Start Test' to begin SUNC compatibility testing")
    print("🔍 Use the search box to filter function results")
end

-- Start the application
safeExecute(initialize, "Failed to initialize SUNC Testing GUI")