window.requestAnimationFrame = window.requestAnimationFrame || window.mozRequestAnimationFrame ||
                            window.webkitRequestAnimationFrame || window.msRequestAnimationFrame

window.cancelAnimationFrame = window.cancelAnimationFrame || window.mozCancelAnimationFrame

window.AudioContext = window.AudioContext || window.webkitAudioContext || () -> throw("AudioContext not supported")
