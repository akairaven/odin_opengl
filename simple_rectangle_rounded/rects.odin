package main

import glm "core:math/linalg/glsl"
import gl "vendor:OpenGL"
import "shader"

RectBuffer :: struct {
    vao : u32,
    vbo : u32,
    initialized : bool,
}

/* Generate a vao, vbo for a rectancle using triangle strip
*/
initRectBuffer :: proc() -> RectBuffer {
    vertices : [4]glm.vec2 = {{0,0},
                              {0,1},
                              {1,0},
                              {1,1}}
    rectBuffer : RectBuffer
    gl.GenVertexArrays(1, &rectBuffer.vao)
    gl.GenBuffers(1, &rectBuffer.vbo)
    gl.BindVertexArray(rectBuffer.vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, rectBuffer.vbo)

    gl.BufferData(gl.ARRAY_BUFFER, len(vertices) * size_of(vertices[0]), &vertices[0], gl.STATIC_DRAW)
    gl.VertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 2 * size_of(f32), uintptr(0))

    gl.BindBuffer(gl.ARRAY_BUFFER, 0)
    gl.BindVertexArray(0)
    rectBuffer.initialized = true
    return rectBuffer
}
/*
rect is x, y, width, height
radius order is top-right, bottom-right, top-left, bottom-left 
*/
drawRoundRect :: proc(rectBuffer: RectBuffer, shaderProgram: u32, rect: [4]f32, radius: [4]f32, color: [4]f32) {
    assert(shaderProgram != 0)
    assert(rectBuffer.initialized)
    gl.UseProgram(shaderProgram)
    model := glm.mat4(1)
    model *= glm.mat4Translate(glm.vec3{rect[0], rect[1], 0}) // position on screen
    model *= glm.mat4Scale(glm.vec3{rect[2], rect[3], 1})
    shader.setMat4(shaderProgram, "model", &model)

    color := color
    shader.setVec4(shaderProgram, "color", &color)
    radius := radius
    shader.setVec4(shaderProgram, "cornerRadius", &radius)
    halfsize := glm.vec2{rect[2] , rect[3] }  / 2  
    shader.setVec2(shaderProgram, "halfSize", &halfsize)
    center := glm.vec2{rect[0] + rect[2]/2, rect[1] + rect[3] / 2}
    shader.setVec2(shaderProgram, "rectCenter", &center)

    gl.BindVertexArray(rectBuffer.vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, rectBuffer.vbo)
    gl.EnableVertexAttribArray(0)

    gl.PolygonMode(gl.FRONT_AND_BACK, gl.FILL)
    gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)

    gl.BindBuffer(gl.ARRAY_BUFFER, 0)
    gl.BindVertexArray(0)
}

