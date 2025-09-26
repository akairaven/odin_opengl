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

SpriteVertices :: []glm.vec4 {
    {0, 0, 0, 0}, 
    {0, 1, 0, 1}, 
    {1, 0, 1, 0}, 
    {1, 1, 1, 1}, 
}

ScreenBuffer :: struct {
    vao : u32,
    vbo : u32,
    shader : u32,
    textures : ^[]Texture,
}

Texture :: struct {
    ID : u32,
    width : i32,
    height : i32,
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

initScreen :: proc() -> ScreenBuffer {
    screenBuffer := ScreenBuffer{}

    vertexSource := cstring(#load("vertexshader.glsl"))
    fragmentSource := cstring(#load("fragmentshader.glsl"))
    screenBuffer.shader = shader.loadShader(&vertexSource, &fragmentSource)

    gl.GenVertexArrays(1, &screenBuffer.vao)
    gl.GenBuffers(1, &screenBuffer.vbo)

    gl.BindVertexArray(screenBuffer.vao)

    gl.BindBuffer(gl.ARRAY_BUFFER, screenBuffer.vbo)
    gl.BufferData(gl.ARRAY_BUFFER, len(SpriteVertices) * size_of(SpriteVertices[0]), raw_data(SpriteVertices), gl.STATIC_DRAW)

    uptr: uintptr  
    gl.VertexAttribPointer(0, 4, gl.FLOAT, gl.FALSE, 4 * size_of(f32), uptr)
    gl.EnableVertexAttribArray(0)

    gl.BindBuffer(gl.ARRAY_BUFFER, 0)
    gl.BindVertexArray(0)
    return screenBuffer
}

drawSprite :: proc(screenBuffer : ScreenBuffer, position : glm.vec2, size : glm.vec2, rotate : f32, color : glm.vec3) {
    gl.UseProgram(screenBuffer.shader)
    model := glm.mat4(1)
    model *= glm.mat4Translate(glm.vec3{position.x, position.y, 0}) // position on screen
    model *= glm.mat4Translate(glm.vec3{.5*size.x, .5*size.y, 0}) // move to center of sprite
    model *= glm.mat4Rotate(glm.vec3{0,0,1}, glm.radians_f32(rotate)) //  do rotation
    model *= glm.mat4Translate(glm.vec3{-.5*size.x, -.5*size.y, 0}) // move back to top left corner of sprite
    model *= glm.mat4Scale(glm.vec3{size.x, size.y, 1})
    shader.setMat4(screenBuffer.shader, "model", &model)

    colorV := color
    shader.setVec3(screenBuffer.shader, "spriteColor", &colorV)

    gl.ActiveTexture(gl.TEXTURE0)
    gl.BindTexture(gl.TEXTURE_2D, screenBuffer.textures[0].ID);
    gl.BindVertexArray(screenBuffer.vao)
    gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)
    gl.BindVertexArray(0);
}

loadTexture :: proc(shader : u32, bitmap : []u8, width : i32, height : i32) -> u32 {
    gl.UseProgram(shader)
    texture: u32
    gl.GenTextures(1, &texture)
    gl.BindTexture(gl.TEXTURE_2D, texture)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
    gl.TexImage2D( gl.TEXTURE_2D, 0, gl.RGBA, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, raw_data(bitmap))
    gl.GenerateMipmap(gl.TEXTURE_2D)
    return texture
}

makeBmp :: proc(s : string, color: glm.vec4) -> (bmp: []u8, width: i32, height: i32) {
    length := len(s) * 13
    output := make([]u8, length*4*9) // 4colors pixels per line (8 + blank)
    offset :i32 = 0
    for i := 12; i>0; i-=1 {
        for letter in s {
            if (letter < 32) || (letter > 127) do continue
            bits := BitmapFont[letter-32][i]
            for i :u8 = 0;i<8;i+=1{
                if bool(bits >> (7-i) & 1) {
                    output[offset] = u8(color[0])
                    output[offset+1] = u8(color[1])
                    output[offset+2] = u8(color[2])
                    output[offset+3] = u8(color[3])
                    offset += 4
                } 
                else {
                    offset += 4
                }
            }
            offset += 4
        }
    }
    width = i32(len(s)) * 9
    height = 13
    return output, width, height
}

main :: proc() {

    window_handle := initWindow()
    if window_handle == nil {
        panic("Unable to init")
    }
    screenBuffer := initScreen()
    gl.UseProgram(screenBuffer.shader)
    projection := glm.mat4Ortho3d(0, WIDTH, HEIGHT, 0, -1, 1)
    shader.setMat4(screenBuffer.shader, "projection", &projection)
    
    text := "Hello Odin..."
    bmp, width, height := makeBmp(text, {250,250,250,255})
    textTexture := loadTexture(screenBuffer.shader, bmp, i32(width), i32(height))
    delete(bmp)
    texture := Texture{textTexture, width, height}
    textures := []Texture{texture}
    screenBuffer.textures = &textures    // loadTexture(screenBuffer.shader, bmp, i32(len(text)), 13)a

    dt: f32 = 0
    lastTime: f32 = 0
    running := true

    textPosition := glm.vec2{20, 20} 
    textRotation :f32 = 0
    textSize := 2*glm.vec2{f32(width),13}
    textSpeed : f32 = 500

    for running {
        currentTime := f32(glfw.GetTime())
        dt = currentTime - lastTime
        lastTime = currentTime
        // fmt.printf("\r%.f FPS ", 1/dt)

        text := fmt.aprintf("Hello Odin! We have : %.f FPS", 1/dt)
        bmp, width, height := makeBmp(text, {250,250,250,255})
        textTexture := loadTexture(screenBuffer.shader, bmp, i32(width), i32(height))
        delete(bmp)
        texture := Texture{textTexture, width, height}
        textures[0] = texture
        textSize := 2*glm.vec2{f32(width),13}

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
    
        drawSprite(screenBuffer, glm.round_vec2(textPosition), textSize, textRotation, glm.vec3{1,1 ,1})
        
        glfw.SwapBuffers(window_handle)
        
    }
    glfw.Terminate()
}

