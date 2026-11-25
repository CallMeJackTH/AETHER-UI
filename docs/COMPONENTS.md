# Components Reference

Create components from a Section. Method names are Create followed by the component name.

~~~lua
local Button = Section:CreateButton({...})
local Toggle = Section:CreateToggle({...})
local Slider = Section:CreateSlider({...})
~~~

## Shared options

Most row components accept:

- Name — component title.
- Description — optional supporting text.
- Tooltip — optional tooltip text.
- Disabled — create the component disabled.
- Visible — set false to hide it initially.
- Flag — custom configuration key. Value components generate a Tab/Section/Name key when omitted. Set Flag = false to opt out of config registration.
- Callback — called when a component action or value changes, where supported.

Every finalized component supports:

~~~lua
component:SetDisabled(true)
component:IsDisabled()
component:SetVisible(false)
component:IsVisible()
component:SetTooltip("More information")
component:SetName("New title")
component:SetDescription("New description")
component:Destroy()
~~~

Value components generally expose Get(), Set(value, silent), and a Changed signal. The exact behavior is listed below.

## Button

~~~lua
Section:CreateButton({
    Name = "Run action",
    Description = "Execute the callback",
    Style = "Primary",
    Icon = "play",
    Callback = function()
        print("Clicked")
    end,
})
~~~

- Style: Default, Primary, Danger, or Ghost.
- Icon: optional supported icon name.
- Methods: Fire(), Set(text), Get(), SetStyle(style).
- Signal: Clicked.

## Toggle

~~~lua
local Toggle = Section:CreateToggle({
    Name = "Enabled",
    Default = false,
    Callback = function(value)
        print(value)
    end,
})
~~~

- Default: boolean; defaults to false.
- Methods: Set(boolean, silent), Get(), Toggle().
- Signal: Changed.

## Slider

~~~lua
local Slider = Section:CreateSlider({
    Name = "Speed",
    Min = 0,
    Max = 100,
    Default = 25,
    Increment = 1,
    Suffix = "%",
    Callback = function(value)
        print(value)
    end,
})
~~~

- Min and Max: numeric bounds.
- Default: initial value; defaults to Min.
- Increment: step size; defaults to 1.
- Suffix: optional text after the value.
- Methods: Set(number, silent), Get(), SetRange(min, max).
- Signal: Changed.

## Dropdown

~~~lua
Section:CreateDropdown({
    Name = "Difficulty",
    Options = { "Easy", "Normal", "Hard" },
    Default = "Normal",
    Placeholder = "Choose one...",
    Callback = function(value)
        print(value)
    end,
})
~~~

Options may also separate display text from values:

~~~lua
Options = {
    { Text = "Low", Value = 1 },
    { Text = "High", Value = 2 },
}
~~~

- Methods: Set(value, silent), Get(), SetOptions(options, keepSelection), Open(), Close().
- Signal: Changed.

## MultiDropdown

~~~lua
Section:CreateMultiDropdown({
    Name = "Targets",
    Options = { "Players", "NPCs", "Bosses" },
    Default = { "Players" },
    Max = 2,
    Placeholder = "None",
    Callback = function(values)
        print(table.concat(values, ", "))
    end,
})
~~~

- Default: array of selected values.
- Max: optional maximum number of selected values.
- Methods: Set(array, silent), Get(), Toggle(value), SetOptions(options), Open(), Close().
- Signal: Changed.

## Textbox

~~~lua
Section:CreateTextbox({
    Name = "Player name",
    Placeholder = "Enter a name",
    Default = "",
    MaxLength = 24,
    Callback = function(value, enterPressed)
        print(value, enterPressed)
    end,
})
~~~

- Numeric: true enables numeric input.
- Min and Max: optional numeric limits when Numeric is true.
- MaxLength: optional character limit.
- ClearOnFocus: clear the text when focused.
- Callback runs when focus is lost and receives value, enterPressed.
- Methods: Set(value, silent), Get(), Focus().
- Signal: Changed.

## Keybind

~~~lua
Section:CreateKeybind({
    Name = "Toggle feature",
    Default = Enum.KeyCode.F,
    Mode = "Press",
    Callback = function(pressed)
        print("Key state:", pressed)
    end,
    OnChanged = function(keyName)
        print("New key:", keyName)
    end,
})
~~~

- Default: Enum key, input type, key-name string such as "F", or nil.
- Mode: "Press" or "Hold".
- In Hold mode Callback receives true on press and false on release.
- Methods: Set(value, silent), Get(), GetKey().
- Signals: Pressed, Changed.

## ColorPicker

~~~lua
Section:CreateColorPicker({
    Name = "Accent color",
    Default = Color3.fromRGB(168, 181, 255),
    Callback = function(color)
        print(color)
    end,
})
~~~

- Default: Color3; defaults to the current accent color.
- Methods: Set(Color3 or "#RRGGBB", silent), Get(), Open(), Close().
- Signal: Changed.

## Label

~~~lua
Section:CreateLabel({
    Text = "Status: Ready",
    Color = Color3.fromRGB(170, 180, 200),
})
~~~

- Accepts Text or Name, and optional Color.
- Methods: Set(text), Get(), SetColor(color3).

## Paragraph

~~~lua
Section:CreateParagraph({
    Title = "Information",
    Content = "A longer description displayed inside a card.",
})
~~~

- Accepts Title or Name, and Content or Text.
- Methods: Set(content), Get(), SetTitle(title).

## Divider

~~~lua
Section:CreateDivider({ Text = "Advanced" })
~~~

- Optional Text or Name caption.
- Methods: Set(text), Get().

## SearchBar

~~~lua
Section:CreateSearchBar({
    Placeholder = "Search...",
    Callback = function(query)
        print(query)
    end,
})
~~~

The window also has its own search field, which filters items on the active tab.

## ProgressBar

~~~lua
local Progress = Section:CreateProgressBar({
    Name = "Loading",
    Min = 0,
    Max = 100,
    Default = 25,
    Suffix = "%",
})
~~~

Default is the initial value; Min and Max define the range (defaults 0 and 100). Suffix is optional display text. Use Set(value, silent), Get(), and SetIndeterminate(true/false) to update the progress bar.

## LoadingIndicator

~~~lua
local Loading = Section:CreateLoadingIndicator({
    Name = "Loading data",
    Description = "Please wait",
    Active = true,
})

Loading:Set(false) -- stop the spinner
Loading:Set(true)  -- start it again
~~~

## Configuration persistence

Toggle, Slider, Dropdown, MultiDropdown, Textbox, Keybind, and ColorPicker are value components and register for configuration persistence by default.

~~~lua
local Enabled = Section:CreateToggle({
    Name = "Enabled",
    Flag = "main_enabled",
    Default = false,
})

Library:SaveConfig("profile")
Library:LoadConfig("profile")
~~~

Choose stable, unique Flag strings when saving multiple settings. Use Flag = false for a value that should not be saved.
