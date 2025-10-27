-- Test CSS parsing regex
local testCSS = [[.O{fill:#369c2e}.P{fill:#5fb935}.Q{fill:#368528}.R{fill:#a322d4}.S{fill:#2234cb}.T{fill:#f122ad}.U{fill:#0e982e}.V{fill:#d322e8}.W{fill:#36a72e}.X{fill:#1ce4a3}.Y{fill:#6822bc}.Z{fill:#8a22b4}.a{fill:#18742e}.b{fill:#28ff3c}]]

print("Testing CSS parsing...")

-- Test the regex pattern
for rule in testCSS:gmatch('[^%s]+%{[^}]+%}') do
    print("Rule: " .. rule)
    local className = rule:match('%.([^%s]+)')
    local colorValue = rule:match('fill:([^%s]+)')
    print("  Class: " .. (className or "nil"))
    print("  Color: " .. (colorValue or "nil"))
    print()
end
