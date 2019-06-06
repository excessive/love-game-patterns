local vec2 = {}
local vec2_mt = {}
vec2_mt.__index = vec2
local function new_vec2(x, y)
	return setmetatable({
		x = x,
		y = y
	}, vec2_mt)
end

function vec2.new(x, y)
	return new_vec2(x, y)
end

function vec2:add(other)
	return vec2.new(self.x + other.x, self.y + other.y)
end

function vec2:length()
	return math.sqrt(self.x^2 + self.y^2)
end

function vec2:normalize()
	local len = self:length()
	if len == 0 then
		return vec2.new(0, 0)
	end
	return vec2.new(self.x / len, self.y / len)
end

function vec2:scale(scale)
	return vec2.new(self.x * scale, self.y * scale)
end

function vec2:copy()
	return vec2.new(self.x, self.y)
end

-- Player entity with everything we need to operate
local player = {}
local player_mt = {}
player_mt.__index = player
local function new_player()
	return setmetatable({
		color = { 1, 0, 0 },
		position = vec2.new(0, 0),
		last_position = vec2.new(0, 0),
		force = vec2.new(0, 0),
		velocity = vec2.new(0, 0),
		size = 20,
		-- friction = 0, -- just keep going!
		friction = 60,
		mass = 2.0,
		speed = 50
	}, player_mt)
end

function player.new()
	return new_player()
end

-- Add force every frame, to be added to velocity next tick
function player:update_input(dt)
	local dir = vec2.new(0, 0)
	if love.keyboard.isDown "right" then dir.x = dir.x + 1 end
	if love.keyboard.isDown "down"  then dir.y = dir.y + 1 end
	if love.keyboard.isDown "up"    then dir.y = dir.y - 1 end
	if love.keyboard.isDown "left"  then dir.x = dir.x - 1 end

	-- Prevent diagonal inputs from being too fast.
	dir = dir:normalize()

	-- Apply force based on input (scaled by delta!)
	self.force = self.force:add(dir:scale(self.speed * dt))
end

-- Add velocity using a=f/m
function player:accelerate()
	local accel = self.force:scale(1.0 / self.mass)
	self.velocity = self.velocity:add(self.force)
	self.velocity = self.velocity:normalize():scale(math.min(self.velocity:length(), 200))

	-- force is from player's input, reset now that we've used it.
	self.force = vec2.new(0, 0)
end

-- Integrate velocity into position
function player:integrate(dt)
	local next_position = self.position:add(self.velocity)
	local w, h = love.graphics.getDimensions()
	w = w / 2 - self.size
	h = h / 2 - self.size
	-- simplistic bouncing off the walls.
		-- realistically, you'd want to do this better - this bounces early.
	if next_position.x > w or next_position.x < -w then
		self.velocity.x = -self.velocity.x
		next_position = self.position:add(self.velocity)
	end
	if next_position.y > h or next_position.y < -h then
		self.velocity.y = -self.velocity.y
		next_position = self.position:add(self.velocity)
	end
	self.last_position = self.position:copy()
	self.position = next_position

	-- exponential velocity falloff
	local new_speed = self.velocity:length() * math.exp(-self.friction * 0.1 * dt)
	self.velocity = self.velocity:normalize():scale(new_speed)
end

function player:update(dt)
	self:accelerate()
	self:integrate(dt)
end

-- Draw player, using current lag (remainder of world tick / timestep)
-- to keep the visuals smooth when tick rate doesn't match display rate
function player:draw(alpha)
	local pos = self.last_position:scale(1 - alpha):add(self.position:scale(alpha))
	love.graphics.setColor(self.color)
	love.graphics.circle("fill", pos.x, pos.y, self.size)
end

local item = {}
local item_mt = {}
item_mt.__index = item
local function new_item(rng, range)
	return setmetatable({
		color = { 0, 0.5, 1 },
		size = 10,
		position = vec2.new(rng:random(-range, range), rng:random(-range, range))
	}, item_mt)
end

function item:draw()
	love.graphics.setColor(self.color)
	love.graphics.circle("fill", self.position.x, self.position.y, self.size)
end

local world = {}
local world_mt = {}
world_mt.__index = world
local function new_world()
	local ret = setmetatable({
		rng = love.math.newRandomGenerator(42),
		player = player.new(),
		items = {},
		timestep = 1 / 60,
		lag = 0
	}, world_mt)
	ret.items = ret:spawn_items(1)
	return ret
end

function world.new()
	return new_world()
end

function world:spawn_items(count)
	local items = {}
	for i = 1, count do
		local range = 300
		items[#items+1] = new_item(self.rng, range)
	end
	items.count = count
	return items
end

function world:tick(dt)
	local player = self.player
	player:update(dt)
	
	for i = #self.items, 1, -1 do
		local item = self.items[i]
		local dist = vec2.new(item.position.x - player.position.x, item.position.y - player.position.y):length()
		if dist < item.size + player.size then
			table.remove(self.items, i)
		end
	end
	-- spawn more!
	if #self.items < 1 then
		self.items = self:spawn_items(math.ceil(self.items.count * 1.5))
	end
end

function world:update(dt)
	-- Update physics systems at a constant tick rate, for consistency
	self.lag = self.lag + dt
	while self.lag >= self.timestep do
		self.lag = self.lag - self.timestep
		self:tick(self.timestep)
	end
	self.player:update_input(dt)
end

function world:draw(ox, oy)
	love.graphics.translate(ox, oy)
	for _, item in ipairs(self.items) do
		item:draw()
	end
	local alpha = self.lag / self.timestep
	self.player:draw(alpha)
end

local g_world = world.new()
function love.update(dt)
	g_world:update(dt)
end

love.graphics.setBackgroundColor(0.25, 0.25, 0.25)
function love.draw()
	local w, h = love.graphics.getDimensions()
	g_world:draw(w/2, h/2)
	love.graphics.setColor(1, 1, 1)
	love.graphics.print(
		("(%d,%d)\n%d m/s"):format(
			g_world.player.velocity.x,
			g_world.player.velocity.y,
			g_world.player.velocity:length()
		),
		-w/2, -h/2
	)
end
