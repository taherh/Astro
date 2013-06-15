# Copyright (c) 2013 Taher Haveliwala
# All Rights Reserved
#
# asteroids.coffee
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
    clips: {}
    enabled: true
    context: null
    mainNode: null
    
    soundMap:
        shoot: 'assets/sound/shoot.ogg'
        explosion: 'assets/sound/explosion.ogg'
        thruster: 'assets/sound/thruster.mp3'
        
    constructor: ->
        try
            @context = new webkitAudioContext()
        catch e
            alert(e)
        
        @mainNode = @context.createGainNode()
        @mainNode.connect(@context.destination)
    
    # key: name of sound
    # callback(sound): callback after sound is loaded
    loadSound: (sound, callback) ->
        key = sound.key
        if sound.key not of @soundMap
            throw "Sound key #{ key } not found"
        
        if key of @clips
            sound.clip = @clips[key]
            if not @clips[key].loaded
                sound.clip.callbacks.push(callback) if callback
            else
                callback(sound) if callback
            return
        
        clip =
            buffer: null
            loaded: false
            callbacks: []
        
        clip.callbacks.push(callback) if callback
        
        sound.clip = clip
        @clips[key] = clip
        
        # jquery doesn't support arraybuffer, so fallback to raw api
        request = new XMLHttpRequest()
        request.open('GET', @soundMap[key], true)
        request.responseType = 'arraybuffer'
        request.onload =
            =>
                @context.decodeAudioData(request.response,
                                         (buffer) =>
                                            console.log("sound #{ key } loaded")
                                            clip.buffer = buffer
                                            clip.loaded = true
                                            callback(sound) for callback in clip.callbacks
                                            clip.callback_list = []
                                          (data) =>
                                            sound.clip = null
                                            throw "bad buffer for #{ key }")
        request.send()

    
    toggleMute: ->
        if @mainNode.gain.value > 0
            @mainNode.gain.value = 0
        else
            @mainNode.gain.value = 1
            
    stopAll: ->
        @mainNode.disconnect()
        @mainNode = @context.createGainNode()
        @mainNode.connect(@context.destination)
        
    playSound: (sound, settings) ->
        if !@enabled then return false
        
        def_settings =
            looping: false
            volume: 0.2
        
        settings = $.merge {}, def_settings, settings
        
        if not sound.clip?.loaded
            throw "Sound #{ sound.key } not loaded"
        
        source = @context.createBufferSource()
        source.buffer = sound.clip.buffer
        source.gain.value = settings.volume
        source.loop = settings.looping
        
        source.connect(@mainNode)
        source.start(0)

        return source

class Sound
    key: null
    clip: null
    source: null
    playing: false
    
    constructor: (key) ->
        @key = key
    
    load: (callback) ->
        gGame.soundManager.loadSound(this, callback)
        
    play: (looping, volume) ->
        raw_play = () =>
            source = gGame.soundManager.playSound(this, {looping: looping, volume: volume})
            playing = true
    
        if @clip?.loaded
            raw_play()
        else
            @load(callback=raw_play)
    
    start:
        source?.start(0)
    stop:
        source?.stop(0)

class AsteroidsGameEngine
    GAME_WIDTH: 640
    GAME_HEIGHT: 480
    SHOOT_RATE: 3
    
    canvas: null    
    
    ship: null
    entities: null
    pendingDestroyList: null

    prevTime: null
    lastShootTime: 0

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
        @soundManager.loadSound(new Sound('shoot'))
        @soundManager.loadSound(new Sound('explosion'))
        @soundManager.loadSound(new Sound('thruster'))
        @imageManager.loadImage('asteroid')

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
        @animRequest = requestAnimationFrame(gGame.step)
        $('#resume').attr('id', 'pause')
                    .attr('value', 'Pause')

    pauseGame: =>
        return if @gameOver
        
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

            console.log("x=#{x}; y=#{y}")
            @addAsteroid(x, y, velX, velY)
            
    addAsteroid: (x, y, velX, velY) ->
        @entities['asteroid'].push(new Asteroid(x, y, velX, velY))

    step: (ts) =>
        if not @prevTime
            @prevTime = ts
            @animRequest = requestAnimationFrame(@step)
            return
        
        curTime = ts
        deltaTime = curTime - @prevTime
        
        @handleEvents(curTime, deltaTime)
        @detectCollisions()
        
        for key, entityList of @entities
            for entity in entityList
                entity.update(deltaTime)
                entity.render()

        @canvas.renderAll()
        
        for entity in @pendingDestroyList
            @canvas.remove(entity)
            util.remove(@entities[entity.key], entity)
            @pendingDestroyList = []

        @prevTime = curTime
        @animRequest = requestAnimationFrame(@step) unless @gameOver

    detectCollisions: ->
        # ship<->asteroid
        for asteroid in @entities['asteroid']
            if asteroid.collidesWith(@ship)
                @collideShip()
            
        # bullet<->asteroid
        for bullet in @entities['bullet']
            for asteroid in @entities['asteroid']
                if bullet.collidesWith(asteroid)
                    console.log('asteroid hit!')
                    @collideBulletAsteroid(bullet, asteroid)

    endGame: ->
        @gameOver = true
        $('#canvas').off('.asteroids')
        @canvas.add(new fabric.Text('Game Over!', {
                top: @GAME_HEIGHT / 2
                left: @GAME_WIDTH / 2
                fill: '#ffffff'
                textBackgroundColor: 'rgb(64,128,128)'
            }))

    collideShip: (asteroid) ->
        @destroy(@ship)
        (new Sound('explosion')).play(false, 1)
        @endGame()
        
    collideBulletAsteroid: (bullet, asteroid) ->
        @destroy(bullet)
        @destroy(asteroid)
        (new Sound('explosion')).play(false, 0.2)
        
    # handle any events that aren't handled by the entities themselves
    # (e.g., spawning of new entities)

    handleEvents: (curTime, deltaTime) ->
        if @inputEngine.actionState['shoot']
            if curTime - @lastShootTime > 1000/@SHOOT_RATE
                @entities['bullet'].push(new Bullet(@ship))
                (new Sound('shoot')).play(false, 0.2)
                @lastShootTime = curTime

    destroy: (entity) ->
        entity.destroy = true
        @pendingDestroyList.push(entity)

util = null

exports = this
exports.Sound = Sound

$ ->
    gGame = new AsteroidsGameEngine()
    window.gGame = gGame

    util = Asteroids.util
    
    gGame.setup()

