-- Personal Omarchy Quattro keybindings
--
-- Philosophy:
--   Left hand  -> apps, system actions, common functions
--   Right hand -> HJKL window navigation
--   Shift      -> move / secondary action
--
-- Omarchy defaults are loaded before this file.
-- Every key combination owned by this config is explicitly unbound first.

local function rebind(keys, description, action, options)
	hl.unbind(keys)
	o.bind(keys, description, action, options)
end

-- ============================================================================
-- APPS / LAUNCHERS
-- ============================================================================

rebind("SUPER + A", "Omarchy menu", "omarchy-menu toggle")

rebind("SUPER + B", "Browser", { omarchy = "browser" })

rebind("SUPER + SHIFT + B", "Bitwarden", { launch = "bitwarden" })

rebind("SUPER + D", "Editor", { omarchy = "editor" })

rebind("SUPER + E", "Thunderbird", { launch = "thunderbird" })

rebind("SUPER + F", "File manager", { omarchy = "nautilus" })

rebind("SUPER + G", "WhatsApp", {
	webapp = "https://web.whatsapp.com/",
	focus = true,
})

rebind("SUPER + SHIFT + G", "Toggle floating/tiling", hl.dsp.window.toggle_floating())

rebind("SUPER + T", "Terminal", { launch = "ghostty" })

rebind("SUPER + W", "Obsidian", {
	launch = "obsidian",
	focus = "^obsidian$",
})

-- ============================================================================
-- WINDOW FOCUS — VIM HJKL
-- ============================================================================

rebind("SUPER + H", "Focus left", hl.dsp.focus({ direction = "l" }))

rebind("SUPER + J", "Focus down", hl.dsp.focus({ direction = "d" }))

rebind("SUPER + K", "Focus up", hl.dsp.focus({ direction = "u" }))

rebind("SUPER + L", "Focus right", hl.dsp.focus({ direction = "r" }))

-- ============================================================================
-- MOVE WINDOWS — SUPER + SHIFT + HJKL
-- ============================================================================

rebind("SUPER + SHIFT + H", "Move window left", hl.dsp.window.swap({ direction = "l" }))

rebind("SUPER + SHIFT + J", "Move window down", hl.dsp.window.swap({ direction = "d" }))

rebind("SUPER + SHIFT + K", "Move window up", hl.dsp.window.swap({ direction = "u" }))

rebind("SUPER + SHIFT + L", "Move window right", hl.dsp.window.swap({ direction = "r" }))

-- ============================================================================
-- RESIZE WINDOWS — SUPER + ALT + HJKL
-- ============================================================================

rebind(
	"SUPER + ALT + H",
	"Resize left",
	hl.dsp.window.resize({
		x = -100,
		y = 0,
		relative = true,
	})
)

rebind(
	"SUPER + ALT + J",
	"Resize down",
	hl.dsp.window.resize({
		x = 0,
		y = 100,
		relative = true,
	})
)

rebind(
	"SUPER + ALT + K",
	"Resize up",
	hl.dsp.window.resize({
		x = 0,
		y = -100,
		relative = true,
	})
)

rebind(
	"SUPER + ALT + L",
	"Resize right",
	hl.dsp.window.resize({
		x = 100,
		y = 0,
		relative = true,
	})
)

-- ============================================================================
-- WINDOW ACTIONS
-- ============================================================================

rebind("SUPER + Q", "Close window", hl.dsp.window.close())

rebind(
	"SUPER + SHIFT + F",
	"Full screen",
	hl.dsp.window.fullscreen({
		mode = "fullscreen",
	})
)

rebind("SUPER + SHIFT + T", "Toggle horizontal/vertical tile", hl.dsp.layout("togglesplit"))

-- ============================================================================
-- SCRATCHPAD
-- ============================================================================

-- SUPER+S is already the Omarchy default, but we explicitly own it here.
rebind("SUPER + S", "Toggle scratchpad", hl.dsp.workspace.toggle_special("scratchpad"))

-- Replace Omarchy's SUPER+ALT+S with the more consistent SHIFT variant.
hl.unbind("SUPER + ALT + S")

rebind(
	"SUPER + SHIFT + S",
	"Move window to scratchpad",
	hl.dsp.window.move({
		workspace = "special:scratchpad",
		follow = false,
	})
)

-- ============================================================================
-- SCREENSHOTS
-- ============================================================================

rebind("SUPER + X", "Screenshot area", "omarchy-capture-screenshot")

rebind("SUPER + SHIFT + X", "Screenshot full screen", "omarchy-capture-region --take-fullscreen")

-- ============================================================================
-- REMINDERS / TIME
-- ============================================================================

rebind("SUPER + R", "Show reminders", "omarchy-reminder show")

rebind("SUPER + SHIFT + R", "Set reminder", "omarchy-menu toggle reminder-set")

rebind("SUPER + CTRL + T", "Show time", "omarchy-notification-time")

-- ============================================================================
-- SYSTEM
-- ============================================================================

rebind("SUPER + Delete", "Lock system", "omarchy-system-lock")

-- ============================================================================
-- DISABLED PREINSTALLED WEBAPP BINDINGS
-- ============================================================================

-- ChatGPT
hl.unbind("SUPER + SHIFT + A")

-- Grok
hl.unbind("SUPER + SHIFT + ALT + A")

-- Google Photos
hl.unbind("SUPER + SHIFT + P")

-- YouTube
hl.unbind("SUPER + SHIFT + Y")

-- X Post
hl.unbind("SUPER + SHIFT + ALT + X")

-- SUPER+SHIFT+X (X) is already replaced above by full-screen screenshot.
