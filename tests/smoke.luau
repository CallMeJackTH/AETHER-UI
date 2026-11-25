local window = Library:CreateWindow({ Title = "AETHER", Size = Vector2.new(650, 420) })
MockStep(1)
print("window created; tabs:", #window.Tabs, "active:", window.ActiveTab and window.ActiveTab.Name)
print("mock errors:", MOCK_ERRORS or 0)
