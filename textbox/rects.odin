package main

import glm "core:math/linalg/glsl"
import gl "vendor:OpenGL"
import "shader"

drawRect :: proc(ctx : AppContext, rect: [4]f32, color: glm.vec4) {
    shaderProgram := ctx.shaders["simple"]
    assert(shaderProgram != 0)
    gl.UseProgram(shaderProgram)
    model := glm.mat4(1)
    model *= glm.mat4Translate(glm.vec3{rect[0], rect[1], 0}) // position on screen
    model *= glm.mat4Scale(glm.vec3{rect[2], rect[3], 1})
    shader.setMat4(shaderProgram, "model", &model)

    colorV := color
    shader.setVec4(shaderProgram, "color", &colorV)

    gl.BindVertexArray(ctx.rectBuffer.vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, ctx.rectBuffer.vbo)
    gl.EnableVertexAttribArray(0)

    gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)

    gl.BindBuffer(gl.ARRAY_BUFFER, 0)
    gl.BindVertexArray(0)
}


drawRoundRect :: proc(ctx : AppContext, rect: [4]f32, radius: f32, color: glm.vec4) {
    shaderProgram := ctx.shaders["roundShape"]
    assert(shaderProgram != 0)
    gl.UseProgram(shaderProgram)
    model := glm.mat4(1)
    model *= glm.mat4Translate(glm.vec3{rect[0], rect[1], 0}) // position on screen
    model *= glm.mat4Scale(glm.vec3{rect[2], rect[3], 1})
    shader.setMat4(shaderProgram, "model", &model)

    colorV := color
    shader.setVec4(shaderProgram, "color", &colorV)
    shader.setFloat(shaderProgram, "cornerRadius", radius)
    halfsize := glm.vec2{rect[2] , rect[3] } * .5 
    shader.setVec2(shaderProgram, "halfSize", &halfsize)
    center := glm.vec2{rect[0] + rect[2]/2, rect[1] + rect[3] /2}
    shader.setVec2(shaderProgram, "rectCenter", &center)

    gl.BindVertexArray(ctx.rectBuffer.vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, ctx.rectBuffer.vbo)
    gl.EnableVertexAttribArray(0)

    gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)

    gl.BindBuffer(gl.ARRAY_BUFFER, 0)
    gl.BindVertexArray(0)
}


