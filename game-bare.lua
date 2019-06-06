local g_tick_rate = 1/60
local g_player = {
	size      = 20,
	color     = { 1, 0, 0 },
	position  = { 0, 0 },
	last_position = { 0, 0 },
	force     = { 0, 0 },
	velocity  = { 0, 0 }
}

local g_rng = love.math.newRandomGenerator(42)
local function spawn_items(n)
	local items = {}
	for i=1,n do
		local range = 300
		table.insert(items, {
			size = 10,
			color = { 0, 0.5, 1 },
			position = { g_rng:random(-range, range), g_rng:random(-range, range) }
		})
	end
	items.count = n
	return items
end
local g_items = spawn_items(1)

local function vec2_length(v)
	return math.sqrt(v[1]^2 + v[2]^2)
end

local function vec2_distance(a, b)
	return vec2_length({ a[1] - b[1], a[2] - b[2] })
end

local function vec2_normalize(v)
	local len = vec2_length(v)
	if len == 0 then
		return { 0, 0 }
	end
	return { v[1] / len, v[2] / len }
end

local function vec2_add(a, b)
	return { a[1] + b[1], a[2] + b[2] }
end

local function vec2_scale(a, s)
	return { a[1] * s, a[2] * s }
end

local g_tick = 0
function love.update(dt)
	-- Update physics systems at a constant tick rate, for consistency
	g_tick = g_tick + dt
	while g_tick >= g_tick_rate do
		g_tick = g_tick - g_tick_rate

		-- Add velocity using a=f/m
		local p = g_player -- useless, but reduces the density here a lot
		local a = vec2_scale(p.force, 0.5) -- 1.0 / mass (2)
		p.velocity = vec2_add(p.velocity, p.force)
		p.velocity = vec2_scale(vec2_normalize(p.velocity), math.min(vec2_length(p.velocity), 200)) -- speed limit=200
		p.force = { 0, 0 } -- force is from player's input, reset now that we've used it.

		-- Integrate velocity into position
		-- simplistic bouncing off the walls.
		-- realistically, you'd want to do this better - this bounces early.
		local next_position = vec2_add(p.position, p.velocity)
		local w2s = 0.5 * love.graphics.getWidth() - p.size
		local h2s = 0.5 * love.graphics.getHeight() - p.size
		if next_position[1] > w2s or next_position[1] < -w2s then
			p.velocity[1] = -p.velocity[1]
			next_position = vec2_add(p.position, p.velocity)
		end
		if next_position[2] > h2s or next_position[2] < -h2s then
			p.velocity[2] = -p.velocity[2]
			next_position = vec2_add(p.position, p.velocity)
		end
		p.last_position = vec2_scale(p.position, 1)
		p.position = next_position
		
		-- exponential velocity falloff
		local new_velocity = vec2_length(p.velocity) * math.exp(-6.0 * g_tick_rate)
		p.velocity = vec2_scale(vec2_normalize(p.velocity), new_velocity)

		-- item pickup
		for i=#g_items,1,-1 do
			local dist = vec2_distance(g_items[i].position, p.position)
			if dist < g_items[i].size + p.size then
				table.remove(g_items, i)
			end
		end

		-- spawn more!
		if #g_items == 0 then
			g_items = spawn_items(math.ceil(g_items.count * 1.5))
		end
	end

	-- Add force every frame, to be added to velocity next tick
	local dir = { 0, 0 }
	if love.keyboard.isDown "up"    then dir[2] = dir[2] - 1 end
	if love.keyboard.isDown "down"  then dir[2] = dir[2] + 1 end
	if love.keyboard.isDown "left"  then dir[1] = dir[1] - 1 end
	if love.keyboard.isDown "right" then dir[1] = dir[1] + 1 end
	
	-- Prevent diagonal inputs from being too fast.
	dir = vec2_normalize(dir)

	-- Apply force based on input (scaled by delta!)
	g_player.force = vec2_add(g_player.force, vec2_scale(dir, 50 * dt))
end

-- Draw entities, interpolated if needed
love.graphics.setBackgroundColor(0.25, 0.25, 0.25)
function love.draw()
	local w, h = love.graphics.getDimensions()
	love.graphics.translate(w/2, h/2)

	for _, item in ipairs(g_items) do
		love.graphics.setColor(item.color)
		love.graphics.circle("fill", item.position[1], item.position[2], item.size)
	end
	
	-- use current lag (remainder of world tick) to keep the visuals smooth when
	-- tick rate doesn't match display rate
	local alpha = g_tick / g_tick_rate
	local pos = vec2_add(vec2_scale(g_player.last_position, 1-alpha), vec2_scale(g_player.position, alpha))
	love.graphics.setColor(g_player.color)
	love.graphics.circle("fill", pos[1], pos[2], g_player.size)

	local v = g_player.velocity
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.print(("(%d, %d)\n%d m/s"):format(v[1], v[2], vec2_length(v)), -w/2, -h/2)
end
