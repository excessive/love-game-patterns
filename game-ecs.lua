local g_world = {
	tick_rate = 1/60,
	tick = 0
}

-- Player entity with everything we need to operate
local g_player = {
	player    = {},
	mass      = 2,
	speed     = 50,
	max_speed = 200,
	size      = 20,
	color     = { 1, 0, 0 },
	position  = { 0, 0 },
	force     = { 0, 0 },
	velocity  = { 0, 0 }
}
table.insert(g_world, g_player)

local rng = love.math.newRandomGenerator(42)
local g_items = 1
local function spawn_items(n)
	for i=1,n do
		local range = 300
		table.insert(g_world, {
			size = 10,
			color = { 0, 0.5, 1 },
			position = { rng:random(-range, range), rng:random(-range, range) },
			collectible = true
		})
	end
end
spawn_items(g_items)

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

-- Add force every frame, to be added to velocity next tick
local input = {}
function input.filter(e)
	return e.player and e.speed and e.force
end
function input.update(entities, dt)
	local dir = { 0, 0 }
	if love.keyboard.isDown "up"    then dir[2] = dir[2] - 1 end
	if love.keyboard.isDown "down"  then dir[2] = dir[2] + 1 end
	if love.keyboard.isDown "left"  then dir[1] = dir[1] - 1 end
	if love.keyboard.isDown "right" then dir[1] = dir[1] + 1 end

	-- Prevent diagonal inputs from being too fast.
	dir = vec2_normalize(dir)

	-- Apply force based on input (scaled by delta!)
	for _, e in ipairs(entities) do
		e.force = vec2_add(e.force, vec2_scale(dir, e.speed * dt))
	end
end

-- Add velocity using a=f/m
local accelerate = {}
function accelerate.filter(e)
	return e.velocity and e.force and e.mass
end
function accelerate.update(entities, dt)
	for _, e in ipairs(entities) do
		local a = vec2_scale(e.force, 1.0 / math.max(0.001, e.mass))
		e.velocity = vec2_add(e.velocity, e.force)
		-- force is from player's input, reset now that we've used it.
		e.force    = { 0, 0 }
		if e.max_speed then
			local v = e.velocity
			e.velocity = vec2_scale(vec2_normalize(v), math.min(vec2_length(v), e.max_speed))
		end
	end
end

-- Integrate velocity into position
local integrate = {}
function integrate.filter(e)
	return e.position and e.velocity and e.size
end

function integrate.update(entities, dt)
	-- local friction = 0 -- just keep going!
	local friction = 60
	local w2 = love.graphics.getWidth()/2
	local h2 = love.graphics.getHeight()/2
	for _, e in ipairs(entities) do
		e.last_position = vec2_scale(e.position, 1)
		-- simplistic bouncing off the walls.
		-- realistically, you'd want to do this better - this bounces early.
		local next_position = vec2_add(e.position, e.velocity)
		local w2s = w2 - e.size
		local h2s = h2 - e.size
		if next_position[1] > w2s or next_position[1] < -w2s then
			e.velocity[1] = -e.velocity[1]
			next_position = vec2_add(e.position, e.velocity)
		end
		if next_position[2] > h2s or next_position[2] < -h2s then
			e.velocity[2] = -e.velocity[2]
			next_position = vec2_add(e.position, e.velocity)
		end
		e.position = next_position

		-- exponential velocity falloff
		local new_velocity = vec2_length(e.velocity) * math.exp(-friction * 0.1 * dt)
		e.velocity = vec2_scale(vec2_normalize(e.velocity), new_velocity)
	end
end

local collision = {}
function collision.filter(e)
	return e.position and e.size and (e.collectible or e.player)
end
function collision.update(entities, dt)
	local player
	for _, e in ipairs(entities) do
		if e.player then
			player = e
			break
		end
	end
	if not player then
		return
	end
	local remove = {}
	local remaining = 0
	for i, e in ipairs(entities) do
		if e.collectible then
			remaining = remaining + 1
		end
		if e ~= player and e.collectible then
			local dist = vec2_distance(e.position, player.position)
			if dist < e.size + player.size then
				table.insert(remove, g_world[e])
			end
		end
	end
	table.sort(remove)
	for i=#remove,1,-1 do
		table.remove(g_world, remove[i])
	end
	-- spawn more!
	if remaining == 0 then
		g_items = math.ceil(g_items * 1.5)
		spawn_items(g_items)
	end
end

-- Draw entities, interpolated if needed
local draw = {}
function draw.filter(e)
	return e.position and e.size and e.color
end
function draw.update(entities, dt)
	local w, h = love.graphics.getDimensions()
	love.graphics.translate(w/2, h/2)
	for _, e in ipairs(entities) do
		love.graphics.setColor(e.color)
		local pos = e.position
		-- if we have a last position, use current lag (remainder of world tick)
		-- to keep the visuals smooth when tick rate doesn't match display rate
		if e.last_position then
			local alpha = g_world.tick / g_world.tick_rate
			pos = vec2_add(vec2_scale(e.last_position, 1-alpha), vec2_scale(pos, alpha))
		end
		love.graphics.circle("fill", pos[1], pos[2], e.size)
	end
	love.graphics.origin()
end

local function update_systems(world, systems, dt)
	for _, system in ipairs(systems) do
		local matches = {}
		for i, entity in ipairs(world) do
			if system.filter(entity) then
				table.insert(matches, entity)
				world[entity] = i
			end
		end
		system.update(matches, dt)
	end
end

function love.update(dt)
	-- Update physics systems at a constant tick rate, for consistency
	g_world.tick = g_world.tick + dt
	while g_world.tick >= g_world.tick_rate do
		g_world.tick = g_world.tick - g_world.tick_rate
		update_systems(g_world, { accelerate, integrate, collision }, g_world.tick_rate)
	end
	update_systems(g_world, { input }, dt)
end

love.graphics.setBackgroundColor(0.25, 0.25, 0.25)
function love.draw()
	update_systems(g_world, { draw }, 0)

	local v = g_player.velocity
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.print(("(%d, %d)\n%d m/s"):format(v[1], v[2], vec2_length(v)), 0, 0)
end
