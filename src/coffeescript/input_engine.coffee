# Copyright (c) 2013 Taher Haveliwala
# All Rights Reserved
#
# input_engine.coffee
#
# See LICENSE for licensing
#

class InputEngine
    # Useful constants
    LEFT_ARROW = 37
    UP_ARROW = 38
    RIGHT_ARROW = 39
    DOWN_ARROW = 40
    SPACE = " ".charCodeAt(0)

    # key bindings
    # e.g., 87 -> 'move-up'
    bindings: {}
    
    # map of currently enabled input actions
    actionState: {}
    
    constructor: ->
        # bind the keys
        @bind(LEFT_ARROW, 'turn-left')
        @bind(RIGHT_ARROW, 'turn-right')
        @bind(UP_ARROW, 'accelerate')
        @bind(DOWN_ARROW, 'decelerate')
        @bind(SPACE, 'shoot')
        
        # listen to appropriate events
        $('body').keydown(@onKeyDown)
        $('body').keyup(@onKeyUp)
        
    onKeyDown: (e) =>
        action = @bindings[e.which]
        
        @actionState[action] = true if action
        
        return false
        
    onKeyUp: (e) =>
        action = @bindings[e.which]
        
        @actionState[action] = false if action
        
        return false
        
    bind: (keycode, action) ->
        @bindings[keycode] = action
        
    bindLetter: (keyLetter, action) ->
        @bind(keyLetter.charCodeAt(0), action)

exports = this
exports.InputEngine = InputEngine
