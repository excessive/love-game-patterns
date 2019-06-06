function love.conf(t)
	t.version = "11.0"
	t.window.width          = 800
	t.window.height         = 600
	t.window.fullscreen     = false
	t.window.fullscreentype = "desktop"
	t.window.msaa           = 4
	t.window.vsync          = true
	t.window.resizable      = true
	t.window.highdpi        = true
	-- Always use gamma correction.
	t.gammacorrect = true
	-- Disable joystick accel on mobile
	t.accelerometerjoystick = false
	t.modules.physics = false
	t.modules.audio = false
	-- Don't delay prints.
	io.stdout:setvbuf("no")
end
