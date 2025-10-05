package main

import "core:fmt"
import glm "core:math/linalg/glsl"
import gl "vendor:OpenGL"
import "vendor:glfw"
import "shader"

WIDTH :: 1600
HEIGHT :: 900
TITLE :: "Hello Round Textbox!"

GL_MAJOR_VERSION :: 4
GL_MINOR_VERSION :: 5

Context :: struct {
    shaders : map[string]u32,
    rectBuffer : RectBuffer,
}

Image :: struct {
    width:  i32,
    height: i32,
    dim:    i32,
    data:   ^u8,
}

RectBuffer :: struct {
    initialized : bool,
    vao : u32,
    vbo : u32,
}

initWindow :: proc() -> glfw.WindowHandle {
    if !bool(glfw.Init()) {
        fmt.eprintln("GLFW has failed to load.")
        return nil
    }
    glfw.WindowHint(glfw.RESIZABLE, glfw.FALSE)
    window_handle := glfw.CreateWindow(WIDTH, HEIGHT, TITLE, nil, nil)

    if window_handle == nil {
        fmt.eprintln("GLFW has failed to load the window.")
        return nil
    }
    glfw.MakeContextCurrent(window_handle)
    gl.load_up_to(GL_MAJOR_VERSION, GL_MINOR_VERSION, glfw.gl_set_proc_address)
    gl.Enable(gl.BLEND);
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
    gl.Viewport(0, 0, WIDTH, HEIGHT);
    
    glfw.SetInputMode(window_handle, glfw.CURSOR, glfw.CURSOR_DISABLED)

    // Center the window in the primary monitor
    primary_monitor := glfw.GetPrimaryMonitor()
    video_mode := glfw.GetVideoMode(primary_monitor)
    x_pos := (video_mode.width - WIDTH) / 2
    y_pos := (video_mode.height - HEIGHT) / 2
    glfw.SetWindowPos(window_handle, x_pos, y_pos)
    
    return window_handle
}

initContext :: proc() -> Context {
    ctx := Context{}
    
    ctx.rectBuffer =  initRectBuffer()

    ctx.shaders["main"] = shader.load_texture_shader()
    ctx.shaders["text"] = shader.load_text_shader()
    ctx.shaders["simple"] = shader.load_simple_shader()
    ctx.shaders["roundShape"] = shader.load_simple_rounded_shader()

    projection := glm.mat4Ortho3d(0, WIDTH, HEIGHT, 0, -1, 1)
    gl.UseProgram(ctx.shaders["main"])
    shader.setMat4(ctx.shaders["main"], "projection", &projection)

    gl.UseProgram(ctx.shaders["text"])
    shader.setMat4(ctx.shaders["text"], "projection", &projection)

    gl.UseProgram(ctx.shaders["simple"])
    shader.setMat4(ctx.shaders["simple"], "projection", &projection)
    
    gl.UseProgram(ctx.shaders["roundShape"])
    shader.setMat4(ctx.shaders["roundShape"], "projection", &projection)
    return ctx
}

drawText :: proc(ctx : Context, textureID: u32, text: string, atlas : FontAtlas, 
                position : glm.vec2, rotate : f32, color : glm.vec4) -> (width, height : f32)
{
    textShader := ctx.shaders["text"]
    assert(textShader != 0)
    width = 0
    height = atlas.fontSize
    nTri :i32= i32(len(text)) * 6 // 6 vertices per quad (2 triangles)
    vertices := make([]glm.vec4, len(text)*6)
    vPos := 0
    xPos :f32 = 0
    for r in text { 
        packedChar := atlas.packedChar[r-32]
        quad := atlas.quads[r-32]
        charWidth := quad.x1 - quad.x0
        // charHeight := quad.y1 - quad.y0
        x0 :f32 = xPos
        x1 :f32 = xPos + charWidth
        y0 :f32 = atlas.ascent + packedChar.yoff
        y1 :f32 = atlas.ascent + packedChar.yoff2 
        vertices[vPos]   = glm.vec4{x0, y0, quad.s0, quad.t0}
        vertices[vPos+1] = glm.vec4{x0, y1, quad.s0, quad.t1}
        vertices[vPos+2] = glm.vec4{x1, y0, quad.s1, quad.t0}
        vertices[vPos+3] = glm.vec4{x1, y1, quad.s1, quad.t1}
        vertices[vPos+4] = glm.vec4{x1, y0, quad.s1, quad.t0}
        vertices[vPos+5] = glm.vec4{x0, y1, quad.s0, quad.t1}
        vPos += 6
        xPos += packedChar.xadvance
        width += xPos
    }
    width = xPos
    gl.UseProgram(textShader)
    model := glm.mat4(1)
    model *= glm.mat4Translate(glm.vec3{position.x, position.y, 0}) // position on screen
    model *= glm.mat4Translate(glm.vec3{.5*width, .5*height, 0}) // move to center of sprite
    model *= glm.mat4Rotate(glm.vec3{0,0,1}, glm.radians_f32(rotate)) //  do rotation
    model *= glm.mat4Translate(glm.vec3{-.5*width, -.5*height, 0}) // move back to top left corner of sprite
    shader.setMat4(textShader, "model", &model)

    colorV := color
    shader.setVec4(textShader, "textColor", &colorV)
    textVao, textVbo : u32
    gl.GenVertexArrays(1, &textVao)
    gl.GenBuffers(1, &textVbo)

    gl.BindVertexArray(textVao)
    gl.BindBuffer(gl.ARRAY_BUFFER, textVbo)
    gl.BufferData(gl.ARRAY_BUFFER, len(vertices) * size_of(vertices[0]), raw_data(vertices), gl.STATIC_DRAW)
    gl.VertexAttribPointer(0, 4, gl.FLOAT, gl.FALSE, 4 * size_of(f32), uintptr(0))
    gl.EnableVertexAttribArray(0)

    gl.ActiveTexture(gl.TEXTURE0)
    gl.BindTexture(gl.TEXTURE_2D, textureID);

    gl.DrawArrays(gl.TRIANGLES, 0, nTri)

    // cleanup
    gl.BindBuffer(gl.ARRAY_BUFFER, 0)
    gl.DeleteBuffers(1, &textVbo)
    gl.BindVertexArray(0);
    gl.DeleteVertexArrays(1, &textVao)
    delete(vertices)
    return width, height
}

loadAtlasTexture :: proc(bitmap : ^u8, width : i32, height : i32) -> u32 {
    texture: u32
    gl.GenTextures(1, &texture)
    gl.BindTexture(gl.TEXTURE_2D, texture)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
    gl.TexImage2D( gl.TEXTURE_2D, 0, gl.RED, width, height, 0, gl.RED, gl.UNSIGNED_BYTE, bitmap)
    gl.GenerateMipmap(gl.TEXTURE_2D)
    return texture
}

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

drawRect :: proc(ctx : Context, rect: [4]f32, color: glm.vec4) {
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


drawRoundRect :: proc(ctx : Context, rect: [4]f32, radius: f32, color: glm.vec4) {
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

main :: proc() {
    fontfile := #load("Cousine-Regular.ttf")
    atlas : FontAtlas
    makeAtlas(&fontfile, 512, 256, 32, 32, 95, &atlas, allocator=context.allocator) // load basic ascii 32~127
    defer destroyAtlas(&atlas)

    window_handle := initWindow()
    if window_handle == nil {
        panic("Unable to init")
    }
    ctx := initContext()

    atlasTexture := loadAtlasTexture(&atlas.bitmap[0], atlas.bitmapWidth, atlas.bitmapHeight)
    
    currentTime := f32(glfw.GetTime())
    dt: f32 = 0
    lastTime: f32 = 0
    running := true

    text := fmt.aprintf("0 FPS")
    for running {
        currentTime = f32(glfw.GetTime())
        dt = currentTime - lastTime
        lastTime = currentTime

        glfw.PollEvents()
        // handle input
        if glfw.WindowShouldClose(window_handle) {
            running = false
        }

        if glfw.GetKey(window_handle, glfw.KEY_ESCAPE) != 0 {
            running = false
        }

        // render display
        gl.ClearColor(0.1, 0.3, 0.5, 1.0)
        gl.Clear(gl.COLOR_BUFFER_BIT)
    
        drawRoundRect(ctx, {45,95,1510,710}, 20, {1,1,1,1} )      
        drawRoundRect(ctx, {50,100,1500,700}, 15, {.25,.25,.25,1} )      
        drawText(ctx, atlasTexture, "This is a round textbox", atlas, {70, 120}, 0, glm.vec4{1,1,1,1})

        text = fmt.aprintf("%.f FPS", 1/dt)
        w, h := drawText(ctx, atlasTexture, text, atlas, {1480, 860}, 0, glm.vec4(1))
        drawRect(ctx, {1470,855,w+20,h+10}, {.2,.2,.4,1})
        drawRect(ctx, {1475,860,w+10,h}, {0,.2,.6,1})
        w, h = drawText(ctx, atlasTexture, text, atlas, {1480, 860}, 0, glm.vec4{1,1,0,1})

        glfw.SwapBuffers(window_handle)
        
    }
    glfw.Terminate()
}

