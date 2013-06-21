# Copyright (c) 2013 Taher Haveliwala
# All Rights Reserved
#
# asteroids.coffee
#
# See LICENSE for licensing
#

class ImageManager

    constructor: ->
        @imageCache = {}
    
    imageMap: 
        ship: 'assets/img/ship.png'
        bullet: 'assets/img/bullet.gif'
        asteroid: 'assets/img/asteroid.gif'
    
    # key: name of image asset
    # callback(img): callback after img is loaded
    loadImage: (key, callback) ->
        if key of @imageCache
            @imageCache[key].clone(callback) if callback
        else
            fabric.Image.fromURL(@imageMap[key],
                                 (img) =>
                                    @imageCache[key] = img
                                    img.clone(callback) if callback)

class SoundManager
    buffers: null
    pending: null
    enabled: true
    context: null
    mainNode: null
    
    soundMap:
        shoot: 'assets/sound/shoot.ogg'
        explosion: 'assets/sound/explosion.ogg'
        thruster: 'assets/sound/thruster.ogg'
        
    constructor: ->
        @buffers = {}
        @pending = {}
        
        try
            @context = new AudioContext()
        catch e
            alert(e)
        
        @mainNode = @context.createGainNode()
        @mainNode.connect(@context.destination)
    

    loadSounds: ->
        for key of @soundMap
            @loadSound(key)
    
    # key: name of sound
    # callback(key): callback after sound 'key' is loaded
    loadSound: (key, callback) ->
        # check that it's a valid sound
        if key not of @soundMap
            throw "Sound key #{ key } not found"
        
        # check if already loaded
        if key of @buffers
            callback(key) if callback
            return
        
        # check if loading
        if key of @pending
            @pending[key].push(callback) if callback
            return
        
        @pending[key] = []
        @pending[key].push(callback) if callback
        
        # jquery doesn't support arraybuffer, so fallback to raw api
        request = new XMLHttpRequest()
        request.open('GET', @soundMap[key], true)
        request.responseType = 'arraybuffer'
        request.onload =
            =>
                @context.decodeAudioData(request.response,
                                         (buffer) =>
                                            console.log("sound #{ key } loaded")
                                            @buffers[key] = buffer
                                            callback(key) for callback in @pending[key]
                                            delete @pending[key]
                                          (data) =>
                                            throw "bad buffer for #{ key }")
        request.send()

    
    mute: ->
        @mainNode.gain.value = 0

    unmute: ->
        @mainNode.gain.value = 1
            
    stopAll: ->
        @mainNode.disconnect()
        @mainNode = @context.createGainNode()
        @mainNode.connect(@context.destination)
        
    getSoundSource: (key, settings) ->
        if !@enabled then return false
        
        def_settings =
            looping: false
            volume: 0.2
        
        settings = $.merge {}, def_settings, settings
        
        if not key in @buffers
            throw "Sound #{ key } not loaded"
        
        source = @context.createBufferSource()
        source.buffer = @buffers[key]
        source.gain.value = settings.volume
        source.loop = settings.loop
        
        source.connect(@mainNode)
        
        return source

# Create a new sound object each time you want to play a sound.
# If you have a looping sound you want to pause and restart, you can
# reuse the same Sound object.
class Sound
    key: null
    looping: null
    volume: null
    source: null
    
    playing: false
    
    constructor: (key, @looping=false, @volume=0.5) ->
        @key = key
        @load()
    
    load: (callback) ->
        gGame.soundManager.loadSound(@key, callback)
        
    # wrap the real play (_play()) in a load() call to ensure sound was loaded
    # calling play on an already playing Sound object has no effect
    play: () ->
        if not @playing or (@source? and @source.playbackState == @source.FINISHED_STATE)
            @playing = true
            @load(() => @_play(@loop, @volume))
        
    _play: (looping, volume) ->
        @source = gGame.soundManager.getSoundSource(@key, { loop: looping, volume: volume })
        @source.start(0)
    
    stop: ->
        @source?.stop(0)
        @source = null
        @playing = false

class AsteroidsGameEngine
    GAME_WIDTH: 640
    GAME_HEIGHT: 480
    SHOOT_RATE: 5
    
    canvas: null    
    
    ship: null
    entities: null
    pendingDestroyList: null

    prevTime: null
    lastShootTime: 0

    paused: false
    gameOver: false
    
    constructor: ->
    
    setup: ->
        $canvas = $('<canvas>', {
            'id': 'canvas'
        })
        $('#game').append($canvas)
    
        @canvas = new fabric.StaticCanvas('canvas', {'selectable': false})
        @canvas.setWidth(@GAME_WIDTH)
        @canvas.setHeight(@GAME_HEIGHT)

        @imageManager = new ImageManager()
        @soundManager = new SoundManager()
        @inputEngine = new InputEngine()
    
        # pre-load sound and image assets
        @soundManager.loadSounds()
        @imageManager.loadImage('ship')
        @imageManager.loadImage('asteroid')
        @imageManager.loadImage('bullet')

        $(document).on('click', '#resume', @resumeGame)
        $(document).on('click', '#pause', @pauseGame)
        $('#reset').click(@resetGame)

        @resetGame()
        @resumeGame()
        
    resetGame: =>
        @animRequest = null
        @canvas.clear()
        
        @ship = null
        @entities =
            ship: []
            asteroid: []
            bullet: []            

        @pendingDestroyList = []
            
        @prevTime = null
        @lastShootTime = 0

        @gameOver = false

        # add a ship entity
        @ship = new Ship(@canvas.getWidth() / 2,
                         @canvas.getHeight() / 2,
                         0,
                         0)
        @entities['ship'] = [@ship]
            
        # add random asteroid field
        @addAsteroidField(10)
        
        @resumeGame()

    resumeGame: =>
        @soundManager.unmute()
        @paused = false
        @animRequest = requestAnimationFrame(gGame.step)
        $('#resume').attr('id', 'pause')
                    .attr('value', 'Pause')

    pauseGame: =>
        return if @gameOver
        
        @paused = true
        
        @soundManager.mute()
        
        @prevTime = null
        if @animRequest? then cancelAnimationFrame(@animRequest)
        @animRequest = null
        $('#pause').attr('id', 'resume')
                   .attr('value', 'Resume')

    # convert canvas mouse click (canvas) coords to normal cartesian coords
    canvasToMath: (canvasX, canvasY, canvasAngle) ->
        return [canvasX, @GAME_HEIGHT - canvasY, -canvasAngle]
    
    # convert normal cartesian coords to canvas coords
    mathToCanvas: (mathX, mathY, mathAngle) ->
        return [mathX, @GAME_HEIGHT - mathY, -mathAngle]
    
    addAsteroidField: (n) ->
        for i in [0...n]
            r = Math.random()*(@canvas.getHeight()/2-64) + 64
            theta = Math.random()*2*Math.PI
            
            x = r*Math.cos(theta)
            y = r*Math.sin(theta)

            velX = Math.random()*200 - 100 + 50
            velY = Math.random()*200 - 100 + 50

            @addAsteroid(x, y, velX, velY)
            
    addAsteroid: (x, y, velX, velY) ->
        @entities['asteroid'].push(new Asteroid(x, y, velX, velY))

    step: (ts) =>
        return if @paused or @gameOver

        if not @prevTime
            @prevTime = ts
            @animRequest = requestAnimationFrame(@step)
            return
        
        curTime = ts
        deltaTime = curTime - @prevTime
        
        # handle any events (such as shooting)
        @handleEvents(curTime, deltaTime)

        # detect any collisions
        @detectCollisions()

        # detect if we won
        @detectWin()
                
        # update all the entities and render them
        for key, entityList of @entities
            for entity in entityList
                entity.update(deltaTime)
                entity.render()

        # render the canvas
        @canvas.renderAll()

        # remove destroyed entities from entity list if necessary
        for entity in @pendingDestroyList
            util.remove(@entities[entity.key], entity)
            @pendingDestroyList = []

        @prevTime = curTime
        @animRequest = requestAnimationFrame(@step) unless @gameOver

    detectWin: ->
        if @entities['asteroid'].length == 0
            @endGame('win')
            
    detectCollisions: ->
        # ship<->asteroid
        for asteroid in @entities['asteroid']
            if asteroid.collidesWith(@ship)
                @collideShip()
            
        # bullet<->asteroid
        for bullet in @entities['bullet']
            for asteroid in @entities['asteroid']
                if bullet.collidesWith(asteroid)
                    @collideBulletAsteroid(bullet, asteroid)

    endGame: (state) ->
        @gameOver = true
        $('#canvas').off('.asteroids')
        if state is "win"
            text = 'You won!'
        else
            text = 'Game Over!'
        @canvas.add(new fabric.Text(text, {
                top: @GAME_HEIGHT / 2
                left: @GAME_WIDTH / 2
                fill: '#ffffff'
                textBackgroundColor: 'rgb(64,128,128)'
            }))

    collideShip: (asteroid) ->
        @destroy(@ship)
        (new Sound('explosion')).play()
        @endGame('lose')
        
    collideBulletAsteroid: (bullet, asteroid) ->
        @destroy(bullet)
        @destroy(asteroid)
        (new Sound('explosion')).play()
        
    # handle any events that aren't handled by the entities themselves
    # (e.g., spawning of new entities)
    handleEvents: (curTime, deltaTime) ->
        if @inputEngine.actionState['shoot']
            if curTime - @lastShootTime > 1000/@SHOOT_RATE
                @entities['bullet'].push(new Bullet(@ship))
                (new Sound('shoot')).play()
                @lastShootTime = curTime

    destroy: (entity) ->
        entity.destroy()
        @pendingDestroyList.push(entity)

util = null

exports = this
exports.Sound = Sound

$ ->
    gGame = new AsteroidsGameEngine()
    window.gGame = gGame

    util = Asteroids.util
    
    gGame.setup()

