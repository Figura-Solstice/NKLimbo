---@class NKLimbo.Transform
---@field pos Vector3?
---@field rot Vector3

local vec2 = vectors.vec2
local vec3 = vectors.vec3
local mat4 = matrices.mat4

--- @class NKLimbo
local NKLimbo = {}
NKLimbo.__index = NKLimbo

local NKLimboInternals = {}

--- @alias NKLimbo.ArmMode "OUT" | "HANG" | "NONE"
--- @alias NKLimbo.TransformCollection {[string]: NKLimbo.Transform}

--- @class NKLimbo.Instance
--- @field Head ModelPart
--- @field BodyPivot ModelPart
--- @field LeftArm ModelPart
--- @field RightArm ModelPart
--- @field LeftLeg ModelPart
--- @field RightLeg ModelPart
--- @field hasUpperPivot boolean
--- @field factor number | Vector3
--- @field vels NKLimbo.TransformCollection? 
--- @field tickPhysics (fun(old: Vector3, new: Vector3, vel: Vector3): Vector3, Vector3)?
--- @field disable {[string]: boolean}
--- @field speed number
--- @field offsetRot Vector3
--- @field calculatedTransforms NKLimbo.TransformCollection 
--- @field oldCalculatedTransforms NKLimbo.TransformCollection
--- @field armMode NKLimbo.ArmMode
local NKLimboInstance = {}
NKLimboInstance.__index = NKLimboInstance

---@alias NKLimbo.PartsParameter { head: ModelPart, bodyPivot: ModelPart, leftArm: ModelPart, rightArm: ModelPart, leftLeg: ModelPart, rightLeg: ModelPart }

-- method taken from Auria's ear/tail libraries.
-- clever method :P
--- @type { [NKLimbo.Instance]: any }
local updatingLeans = {}
NKLimbo._updatingLeans = updatingLeans
NKLimbo._internals = NKLimboInternals

---comment
---@param old NKLimbo.TransformCollection
---@param new NKLimbo.TransformCollection
---@param consumer fun(old: NKLimbo.Transform, new: NKLimbo.Transform, key: string): NKLimbo.Transform
---@return NKLimbo.TransformCollection
function NKLimboInternals.walkTransforms(old, new, consumer)
    local copy
    copy = {}
    for orig_key, orig_value in next, new, nil do
        copy[orig_key] = consumer(old[orig_key], orig_value, orig_key)
    end
    return copy
end

---@param old NKLimbo.TransformCollection
---@param orig NKLimbo.TransformCollection
---@param d number
---@return NKLimbo.TransformCollection
function NKLimboInternals.copyAndLerpTransforms(old, orig, d)
    return NKLimboInternals.walkTransforms(old, orig, function (old, new)
        return {
            pos = old.pos and math.lerp(old.pos, new.pos, d) or nil,
            rot = old.rot and math.lerp(old.rot, new.rot, d) or nil
        }
    end)
end

function NKLimboInternals.extract_rot(mat)
    if type(mat) == "Matrix4" then mat = mat:deaugmented() end

    local heading = math.atan2(-mat.v31, mat.v11)
    local attitude = math.asin(mat.v21)
    local bank = math.atan2(-mat.v23, mat.v22)

    local v = vec3(bank, heading, attitude):toDeg()
    return v
end


---@return NKLimbo.TransformCollection
function NKLimboInternals.empty_transform()
    return {
        Head = {
            rot = vec3()
        },
        BodyPivot = {
            rot = vec3()
        },
        LeftArm = {
            rot = vec3()
        },
        RightArm = {
            rot = vec3()
        },
        LeftLeg = {
            rot = vec3(),
            pos = vec3()
        },
        RightLeg = {
            rot = vec3(),
            pos = vec3()
        },
    }
end

---@param parts NKLimbo.PartsParameter
---@return NKLimbo.Instance
function NKLimbo.new(parts)
    local self = setmetatable({}, NKLimboInstance) --[[@as NKLimbo.Instance]]
    self.Head = parts.head
    self.BodyPivot = parts.bodyPivot
    self.LeftArm = parts.leftArm
    self.RightArm = parts.rightArm
    self.LeftLeg = parts.leftLeg
    self.RightLeg = parts.rightLeg
    self.factor = 2
    self.speed = 1
    self.armMode = "NONE"
    self.hasUpperPivot = self.Head:getParent() == self.BodyPivot
    self.offsetRot = vec3()
    self.disable = {}
    updatingLeans[self] = true
    
    self.calculatedTransforms = NKLimboInternals.empty_transform()
    self.oldCalculatedTransforms = NKLimboInternals.copyAndLerpTransforms(self.calculatedTransforms, self.calculatedTransforms, 1)

    return self
end

NKLimbo.presets = {}

---Creates and configures an instance of NKLimbo using Niko's settings.
---@param parts NKLimbo.PartsParameter
---@return NKLimbo.Instance
function NKLimbo.presets.niko(parts)
    local instance = NKLimbo.new(parts)
    instance:setPhysics(function (old, new, vel)
        vel = vel * 0.8 + (new - (old)) * 2
        return new + vel, vel
    end)
    instance:setArmMode("OUT")
    instance:setSpeed(.25)
    instance:setDivisionFactor(vec2(3,2))
    return instance
end

---Sets the function to use for physics.
---@param tick (fun(old: Vector3, new: Vector3, vel: Vector3): Vector3, Vector3)?
---@return NKLimbo.Instance
function NKLimboInstance:setPhysics(tick)
    self.vels = nil
    self.tickPhysics = tick
    return self
end

---Sets whether or not the lean should be enabled.
---@param state boolean
---@return NKLimbo.Instance
function NKLimboInstance:setEnabled(state)
    updatingLeans[self] = state and self or nil
    if not state then
        self.oldCalculatedTransforms = NKLimboInternals.empty_transform()
        self.calculatedTransforms = self.oldCalculatedTransforms
        self:draw()
    end
    return self
end

---Sets the value the head rotation is divided by.
---@param num number | Vector2 | nil
---@return NKLimbo.Instance
function NKLimboInstance:setDivisionFactor(num)
    if type(num) == "Vector2" then
        self.factor = num:augmented()
    else
        self.factor = num or 2
    end
    return self
end

---Sets the speed of the lean. 0-1
---@param num number?
---@return NKLimbo.Instance
function NKLimboInstance:setSpeed(num)
    self.speed = math.clamp(num or 1, 0, 1)
    return self
end

---Sets the arm mode of the lean.
---@param mode NKLimbo.ArmMode
---@return NKLimbo.Instance
function NKLimboInstance:setArmMode(mode)
    self.armMode = mode
    return self
end

---@package
function NKLimboInstance:draw(delta)
    delta = delta or 1
    local t = NKLimboInternals.copyAndLerpTransforms(self.oldCalculatedTransforms, self.calculatedTransforms, delta)
    if self.hasUpperPivot then
        self.BodyPivot:setRot(t.BodyPivot.rot)
        self.Head:setRot(t.Head.rot)
        self.LeftArm:setRot(t.LeftArm.rot)
        self.RightArm:setRot(t.RightArm.rot)
    else
        local mat = matrices.mat4()
            :translate(self.BodyPivot:getPivot())
            :translate(0,-12,0)
            :rotate(t.BodyPivot.rot)
            :translate(0,12,0)
            :translate(-self.BodyPivot:getPivot())
        local offset = mat:apply()
        local rot = NKLimboInternals.extract_rot(mat)
        self.BodyPivot:setRot(rot)
        self.BodyPivot:setPos(offset)
        self.Head:setRot(t.Head.rot + t.BodyPivot.rot)
        self.Head:setPos(offset)
        self.LeftArm:setRot(t.LeftArm.rot + t.BodyPivot.rot):setPos(mat:apply(vec3(-5,0,0)) - vec3(-5,0,0))
        self.RightArm:setRot(t.RightArm.rot + t.BodyPivot.rot):setPos(mat:apply(vec3(5,0,0)) - vec3(5,0,0))
    end
    self.LeftLeg:setRot(t.LeftLeg.rot)
    self.LeftLeg:setPos(t.LeftLeg.pos)
    self.RightLeg:setRot(t.RightLeg.rot)
    self.RightLeg:setPos(t.RightLeg.pos)
end

---@package
function NKLimboInstance:update(headRot)
    local t = NKLimboInternals.empty_transform()
    ---@diagnostic disable-next-line: assign-type-mismatch
    self.oldCalculatedTransforms = NKLimboInternals.copyAndLerpTransforms(self.oldCalculatedTransforms, self.calculatedTransforms, self.speed)
    t.BodyPivot.rot = headRot/self.factor + (self.armMode == "NONE" and vec3() or (vec3(0,0,(headRot/self.factor).y/5)))
    t.Head.rot = (-headRot/self.factor + (self.armMode == "NONE" and vec3() or (vec3(0,0,(headRot/self.factor).y/5))))

    if self.armMode == "HANG" then
        t.LeftArm.rot = ((-headRot * vec3(1,1/3,1))/self.factor) - vec3(0,0,math.max((headRot/self.factor).y/3,0))
        t.RightArm.rot = ((-headRot * vec3(1,1/3,1))/self.factor) - vec3(0,0,math.min((headRot/self.factor).y/3,0))
    elseif self.armMode == "OUT" then
        t.LeftArm.rot = ((-headRot * vec3(1,1/3,1))/self.factor) - vec3(0,0,(headRot/self.factor).y/3):applyFunc(math.abs)
        t.RightArm.rot = ((-headRot * vec3(1,1/3,1))/self.factor) + vec3(0,0,-(headRot/self.factor).y/3):applyFunc(math.abs)
    else
        t.LeftArm.rot = ((-headRot * vec3(1,1/3,1))/self.factor)
        t.RightArm.rot = ((-headRot * vec3(1,1/3,1))/self.factor) 
    end

    t.LeftLeg.rot = vec3(headRot.y/7,0,-headRot.y/60) / self.factor
    t.LeftLeg.pos = mat4()
        :translate(0,12,0)
        :rotate(t.LeftLeg.rot)
        :translate(0,-12,0)
        :apply()
    t.RightLeg.rot = vec3(-headRot.y/7,0,-headRot.y/60) / self.factor
    t.RightLeg.pos = mat4()
        :translate(0,12,0)
        :rotate(t.RightLeg.rot)
        :translate(0,-12,0)
        :apply()

    if self.tickPhysics then
        if not self.vels then
            self.vels = NKLimboInternals.empty_transform()
        end
        t = NKLimboInternals.copyAndLerpTransforms(self.calculatedTransforms, t, self.speed)
        local new = NKLimboInternals.walkTransforms(self.calculatedTransforms, t, function (old, new, key)
            local ret = {}
            local vel = self.vels[key]
            if old.pos then
                ret.pos, vel.pos = self.tickPhysics(old.pos, new.pos, vel.pos)
            end
            if old.rot then
                ret.rot, vel.rot = self.tickPhysics(old.rot, new.rot, vel.rot)
            end
            self.vels[key] = vel
            return ret
        end)
        t = new
    end
    self.calculatedTransforms = NKLimboInternals.copyAndLerpTransforms(self.calculatedTransforms, t, self.speed)
end

events.TICK:register(function ()
    -- I could use that one vanilla_model.HEAD:getOriginRot() snippet...
    -- but that doesn't work very well with tweakeroo's freecam if
    -- paperdoll is enabled.
    local headRot = player:getRot():sub(0,player:getBodyYaw()).xy_ * -1
    headRot = (((headRot)+180)%360-180)
    if (player:getPose() ~= "STANDING") or player:getVehicle() then
        headRot = vec3() -- hilarious method imo
    end
    for self, _ in pairs(updatingLeans) do
        local disable = false
        for key, value in pairs(self.disable) do
            if value then disable = true break end
        end
        if disable then
            self:update(vec3())
        else
            if self.offsetRot:length() > 0 then
                self:update(((headRot+self.offsetRot)+180)%360-180)
            else
                self:update(headRot)
            end
        end
    end
end, "NKLimbo.TICK")

events.RENDER:register(function(delta, ctx)
    if (ctx == "OTHER" and not (host:getScreen() == "net.minecraft.class_481")) then return end
    if not vanilla_model.BODY:getOriginVisible() and ctx == "PAPERDOLL" then return end
    for self, _ in pairs(updatingLeans) do
        self:draw(delta * self.speed)
    end
end, "NKLimbo.RENDER")

return NKLimbo