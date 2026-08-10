# NKLimbo
something something more than just your head gets rotated when looking around.

[Download](./NKLimbo.lua)

example code
```lua
local limbo = require("NKLimbo")

local root = models.model.root

local instance = limbo.new({
    bodyPivot = root.Body,
    head = root.Head,
    leftArm = root.LeftArm,
    leftLeg = root.LeftLeg,
    rightArm = root.RightArm,
    rightLeg = root.RightLeg
})
instance:setArmMode("HANG")
instance:setSpeed(.25)
instance:setDivisionFactor(vec2(3,1.5))
```

there's some presets under `NKLimbo.presets` (actually, there's just one...) if you don't want to bother configuring NKLimbo to look good yourself. in which case the code might look like this: 
```lua
local limbo = require("NKLimbo")

local root = models.model.root

local instance = limbo.presets.niko({
    bodyPivot = root.Body,
    head = root.Head,
    leftArm = root.LeftArm,
    leftLeg = root.LeftLeg,
    rightArm = root.RightArm,
    rightLeg = root.RightLeg
})
```

computation in NKLimbo can take a shortcut if you add another group in your bbmodel. if you have the following structure:
```
root/
    Head
    Body
    LeftArm
    RightArm
    LeftLeg
    RightLeg
```
you can do this to make it a bit more efficient, as it prevents the need for matrix math:
```
root/
    BodyPivot/
        Head
        Body
        LeftArm
        RightArm
    LeftLeg
    RightLeg
```
you'll want to pass in "BodyPivot" as the bodyPivot, instead of the body group itself. this is the main model structure that NKLimbo has been tested with, as it simplifies things significantly, though it should work the same either way.

NKLimbo was designed with vanilla model proportions in mind. not sure how well it'll work outside those proportions, though don't be afraid of trying it. if it works, that's great! if it doesn't, that's unfortunate.