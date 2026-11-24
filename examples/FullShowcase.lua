-- AETHER UI Full Showcase
-- Executor entry point: fetches the standalone library build from GitHub.
-- Keep this file independent from ReplicatedStorage / ModuleScript installation.

local LIBRARY_URL = "https://raw.githubusercontent.com/CallMeJackTH/AETHER-UI/main/build/AetherUI.lua"

local function loadLibrary()
    local ok, source = pcall(function()
        return game:HttpGet(LIBRARY_URL)
    end)

    if not ok then
        error("[AETHER UI] Could not download library: " .. tostring(source))
    end

    if type(source) ~= "string" or source == "" then
        error("[AETHER UI] Library download returned empty content.")
    end

    local compileOk, chunk = pcall(loadstring, source)
    if not compileOk or type(chunk) ~= "function" then
        error("[AETHER UI] Library compilation failed: " .. tostring(chunk))
    end

    local runOk, library = pcall(chunk)
    if not runOk then
        error("[AETHER UI] Library initialization failed: " .. tostring(library))
    end

    if type(library) ~= "table" or type(library.CreateWindow) ~= "function" then
        error("[AETHER UI] Invalid library build: CreateWindow API is missing.")
    end

    return library
end

local ok, err = pcall(function()
    local Aether = loadLibrary()

    local Window = Aether:CreateWindow({
        Title = "AETHER UI",
        Subtitle = "Full Component Showcase",
        Size = UDim2.fromOffset(680, 500),
        Theme = "Dark",
        Acrylic = true
    })

    local Tab = Window:CreateTab({
        Name = "Showcase",
        Icon = "sparkles"
    })

    local Section = Tab:CreateSection("All Components")

    Section:CreateButton({
        Name = "Button",
        Description = "Click to test the button callback.",
        ButtonText = "Run",
        Callback = function()
            Window:Notify({
                Title = "Button",
                Content = "Callback fired."
            })
        end
    })

    Section:CreateToggle({
        Name = "Toggle",
        Default = true,
        Callback = function(value)
            print("[AETHER UI] Toggle:", value)
        end
    })

    Section:CreateSlider({
        Name = "Slider",
        Min = 1,
        Max = 10,
        Default = 5,
        Callback = function(value)
            print("[AETHER UI] Slider:", value)
        end
    })

    Section:CreateDropdown({
        Name = "Dropdown",
        Options = {"One", "Two", "Three"},
        Default = "One",
        Callback = function(value)
            print("[AETHER UI] Dropdown:", value)
        end
    })

    Section:CreateMultiDropdown({
        Name = "Multi Dropdown",
        Options = {"Alpha", "Beta", "Gamma"},
        Default = {"Alpha"},
        Callback = function(values)
            print("[AETHER UI] Multi Dropdown:", table.concat(values, ", "))
        end
    })

    Section:CreateTextbox({
        Name = "Textbox",
        Placeholder = "Enter some text...",
        Callback = function(value)
            print("[AETHER UI] Textbox:", value)
        end
    })

    Section:CreateKeybind({
        Name = "Keybind",
        Default = Enum.KeyCode.G,
        Callback = function(value)
            print("[AETHER UI] Keybind:", value)
        end
    })

    Section:CreateColorPicker({
        Name = "Color Picker",
        Callback = function(value)
            print("[AETHER UI] Color:", value)
        end
    })

    Section:CreateLabel("Label component")

    Section:CreateParagraph({
        Title = "Paragraph",
        Content = "A longer description for an interface control."
    })

    Section:CreateDivider()

    Section:CreateSearchBar({
        Name = "Search Bar",
        Placeholder = "Search...",
        Callback = function(value)
            print("[AETHER UI] Search:", value)
        end
    })

    Section:CreateProgressBar({
        Name = "Progress",
        Value = 45
    })

    Section:CreateLoadingIndicator({
        Name = "Loading Indicator"
    })

    Section:CreateTooltip({
        Name = "Tooltip",
        Tooltip = "Helpful contextual information"
    })

    Section:CreateContextMenu({
        Name = "Context Menu",
        Options = {"Copy", "Reset"}
    })

    Section:CreateModal({
        Name = "Modal",
        Title = "Example Modal",
        Content = "Modal content",
        Callback = function()
            print("[AETHER UI] Modal accepted")
        end
    })

    Section:CreateConfigurationManager({
        ConfigName = "Showcase"
    })

    Section:CreateThemeManager()

    Window:Notify({
        Title = "AETHER UI",
        Content = "Full Showcase loaded successfully."
    })
end)

if not ok then
    warn("[AETHER UI] Showcase failed: " .. tostring(err))
end
