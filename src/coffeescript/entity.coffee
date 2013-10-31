# Copyright (c) 2013 Taher Haveliwala
# All Rights Reserved
#
# entity.coffee
#
# See LICENSE for licensing
#

util = Asteroids.util

class Entity
    # orientation in degrees
    orientation: 0
    wraparound: true
    
    img: null
    
    destroyed: false
    
    constructor: (x, y, vel_x=0, vel_y=0, orientation=0) ->
        @pos = {}
        @vel = {}
        
        @pos.x = x
        @pos.y = y
        @vel.x = vel_x
        @vel.y = vel_y

        gGame.imageManager.loadImage(@key, @setImage)
        
    setImage: (img) =>
        unless @destroyed
            @img = img
            @render()
            gGame.canvas.add(@img)
        
    render: =>
        if @destroyed and @img?
            gGame.canvas.remove(@img)
            @img = null
            return
        
        [cX, cY, cAngle] = gGame.mathToCanvas(@pos.x, @pos.y, @orientation)
        if @img
            @img.set(
                angle: cAngle
                left: cX
                top: cY
            ).setCoords()  # setCoords() will update bounding box
        
    update: (deltaTime) ->
        return if @destroyed
        
        deltaX = deltaTime/1000 * @vel.x
        deltaY = deltaTime/1000 * @vel.y
        
        @pos.x += deltaX
        @pos.y += deltaY
    
        width = gGame.GAME_WIDTH
        height = gGame.GAME_HEIGHT
    
        if @wraparound
            while @pos.x >= width
                @pos.x -= width
    
            while @pos.y >= height
                @pos.y -= height
    
            while @pos.x < 0
                @pos.x += width
                
            while @pos.y < 0
                @pos.y += height
                
        else
            if (@pos.x < 0 or @pos.x >= width or
                @pos.y < 0 or @pos.y >= height)
                 @outOfBounds()
                
    outOfBounds: () ->
        gGame.destroy(this)
        
    collidesWith: (other) ->
        if this.img? and other.img?
            return this.img.intersectsWithObject(other.img)
        else
            return false
        
    destroy: ->
        @destroyed = true

class Ship extends Entity
    ACCEL_INCR = 1/10
    ROTATE_INCR = (360/1000) * 0.5
    MAX_SPEED = 500

    key: 'ship'
    
    thrusterSound: null

    constructor: (x, y, x_vel, y_vel) ->
        super
        @thrusterSound = new Sound('thruster', true)
    
    update: (deltaTime) ->
        return if @destroyed
        
        actionState = gGame.inputEngine.actionState
        if actionState['turn-left']
            @rotateLeft(deltaTime)
        if actionState['turn-right']
            @rotateRight(deltaTime)
        if actionState['accelerate']
            @accelerate(deltaTime)
        if actionState['decelerate']
            @decelerate(deltaTime)
            
        if not actionState['decelerate'] and
           not actionState['accelerate']
            @decelerate(deltaTime, "coast")
            
        super(deltaTime)

    rotateRight: (deltaTime) ->
        @orientation -= ROTATE_INCR * deltaTime
        if (@orientation < 0)
            @orientation += Math.floor(Math.abs(@orientation) / 360)

    rotateLeft: (deltaTime) ->
        @orientation += ROTATE_INCR * deltaTime
        @orientation %= 360
        
    accelerate: (deltaTime) ->
        # accelerate along orientation
        @vel.x += ACCEL_INCR * deltaTime * Math.cos(util.toRad(@orientation))
        @vel.y += ACCEL_INCR * deltaTime * Math.sin(util.toRad(@orientation))
        
        # but make sure we're not going too fast
        speed = Math.sqrt(Math.pow(@vel.x, 2) + Math.pow(@vel.y, 2))
        if speed > MAX_SPEED
            cur_vel_angle = util.getAngle(@vel.y, @vel.x)
            @vel.x = Math.cos(cur_vel_angle) * MAX_SPEED
            @vel.y = Math.sin(cur_vel_angle) * MAX_SPEED
            
        @thrusterSound.play()
            
    decelerate: (deltaTime, type) ->
        if type == "coast"
            incr = ACCEL_INCR/4
        else
            incr = ACCEL_INCR

        @thrusterSound.stop()
            
        speed = Math.sqrt(Math.pow(@vel.x, 2) + Math.pow(@vel.y, 2))
        speed -= incr * deltaTime
        speed = 0 if speed < 0

        cur_vel_angle = util.getAngle(@vel.y, @vel.x)
        @vel.x = Math.cos(cur_vel_angle) * speed
        @vel.y = Math.sin(cur_vel_angle) * speed
        
    destroy: ->
        @thrusterSound.stop()
        super
    
class Asteroid extends Entity
    key: 'asteroid'

    constructor: (x, y, x_vel, y_vel) ->
        super
        
class Bullet extends Entity
    VEL_MAG = 200

    key: 'bullet'

    constructor: (ship) ->
        # we derive the bullet's position and velocity vector
        # from the ship's
        
        ship_cos = Math.cos(util.toRad(ship.orientation))
        ship_sin = Math.sin(util.toRad(ship.orientation))
        
        x = ship.pos.x + ship.img.width/2 * ship_cos
        y = ship.pos.y + ship.img.width/2 * ship_sin
        
        x_vel = VEL_MAG * ship_cos
        y_vel = VEL_MAG * ship_sin
        
        x_vel += ship.vel.x unless util.sign(ship.vel.x) != util.sign(x_vel)
        y_vel += ship.vel.y unless util.sign(ship.vel.y) != util.sign(y_vel)
        
        @wraparound = false
        super(x, y , x_vel, y_vel)
    
exports = this
exports.Entity = Entity
exports.Ship = Ship
exports.Asteroid = Asteroid
exports.Bullet = Bullet

