package main

import "core:fmt"
import glm "core:math/linalg/glsl"
import gl "vendor:OpenGL"
import "vendor:glfw"
import "shader"

WIDTH :: 1600
HEIGHT :: 900
TITLE :: "Hello GL World!"

GL_MAJOR_VERSION :: 4
GL_MINOR_VERSION :: 5

/* 
first 2 coord are mode, last 2 are texture
rendered as triangle strip
*/

Context :: struct {
    shader : u32
}

Texture :: u32

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

    vertexSource := cstring(#load("vertexshader.glsl"))
    fragmentSource := cstring(#load("fragmentshader.glsl"))
    ctx.shader = shader.loadShader(&vertexSource, &fragmentSource)

    return ctx
}

drawText :: proc(textShader : u32, textureID: Texture, text: string, atlas : FontAtlas, 
                position : glm.vec2, rotate : f32, color : glm.vec3) -> (width, height : f32)
{
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
    shader.setVec3(textShader, "spriteColor", &colorV)
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

loadAtlasTexture :: proc(shader : u32, bitmap : ^u8, width : i32, height : i32) -> u32 {
    gl.UseProgram(shader)
    texture: u32
    gl.GenTextures(1, &texture)
    gl.BindTexture(gl.TEXTURE_2D, texture)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
    // gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
    // gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
    gl.TexImage2D( gl.TEXTURE_2D, 0, gl.RED, width, height, 0, gl.RED, gl.UNSIGNED_BYTE, bitmap)
    gl.GenerateMipmap(gl.TEXTURE_2D)
    return texture
}

main :: proc() {
    fontfile := #load("Cousine-Regular.ttf")
    atlas : FontAtlas
    makeAtlas(&fontfile, 512, 256, 32, 32, 95, &atlas, allocator=context.allocator) // load basic ascii 32~127
    // makeAtlas(&fontfile, 1024, 1024, 32, 32, 95, &atlas, allocator=context.allocator) // load basic ascii 32~127
    defer destroyAtlas(&atlas)

    window_handle := initWindow()
    if window_handle == nil {
        panic("Unable to init")
    }
    ctx := initContext()
    gl.UseProgram(ctx.shader)
    projection := glm.mat4Ortho3d(0, WIDTH, HEIGHT, 0, -1, 1)
    shader.setMat4(ctx.shader, "projection", &projection)
    
    atlasTexture := loadAtlasTexture(ctx.shader, &atlas.bitmap[0], atlas.bitmapWidth, atlas.bitmapHeight)
    // texture := Texture{atlasTexture}
    // fmt.printf("%v", texture)
    // textures := []Texture{texture}
    // screenBuffer.textures = &textures    // loadTexture(screenBuffer.shader, bmp, i32(len(text)), 13)a

    dt: f32 = 0
    lastTime: f32 = 0
    running := true

    textPosition := glm.vec2{0, 0} 
    textRotation :f32 = 0
    textSize := glm.vec2{0,0}
    textSpeed : f32 = 500

    for running {
        currentTime := f32(glfw.GetTime())
        dt = currentTime - lastTime
        lastTime = currentTime
        // fmt.printf("\r%.f FPS ", 1/dt)

        glfw.PollEvents()
        // handle input
        if glfw.WindowShouldClose(window_handle) {
            running = false
        }

        if glfw.GetKey(window_handle, glfw.KEY_ESCAPE) != 0 {
            running = false
        }

        if glfw.GetKey(window_handle, glfw.KEY_R) != 0 {
            textRotation += 1*dt*textSpeed
            if textRotation > 360 {
               textRotation = 0
            }
        }

        if glfw.GetKey(window_handle, glfw.KEY_W) != 0 {
            textPosition.y -= textSpeed*dt
            if textPosition.y < 1 {
                textPosition.y = 0
            }
        }

        if glfw.GetKey(window_handle, glfw.KEY_S) != 0 {
            textPosition.y += textSpeed*dt
            if (textPosition.y + textSize.y) >= HEIGHT {
                textPosition.y = HEIGHT-textSize.y
            }
        }

        if glfw.GetKey(window_handle, glfw.KEY_A) != 0 {
            textPosition.x -= textSpeed*dt
            if textPosition.x < 1 {
                textPosition.x = 0
            }
        }

        if glfw.GetKey(window_handle, glfw.KEY_D) != 0 {
            textPosition.x += textSpeed*dt
            if (textPosition.x + textSize.x) >= WIDTH {
                textPosition.x = WIDTH-textSize.x
            }
        }

        // render display
        gl.ClearColor(0.1, 0.3, 0.5, 1.0)
        gl.Clear(gl.COLOR_BUFFER_BIT)
    
        text := fmt.aprintf("Hello Odin! %.f FPS", 1/dt)
        w, h := drawText(ctx.shader, atlasTexture, text, atlas, glm.round_vec2(textPosition), textRotation, glm.vec3{1., 1., 1.})
        textSize = glm.vec2{w, h}
        
        glfw.SwapBuffers(window_handle)
        
    }
    glfw.Terminate()
}

