# Copyright (c) 2013 Taher Haveliwala
# All Rights Reserved
#
# util.coffee
#

window.Asteroids = {} if not window.Asteroids

util = Asteroids.util = {}

util.sign = (x) ->
    return if x > 0 then 1 else if x < 0 then -1 else 0

util.cap = (val, max) ->
    if Math.abs(val) >= max
        return util.sign(val) * max
    else
        return max

util.toRad = (degrees) ->
    return degrees * (Math.PI / 180)

util.toDeg = (radians) ->
    return radians * (180 / Math.PI)

util.getAngle = (y, x) ->
    angle = Math.atan2(y, x)
    if angle >= 0
        return angle
    else
        return angle + 2*Math.PI

util.remove = (list, obj) ->
    list.splice(list.indexOf(obj), 1)
