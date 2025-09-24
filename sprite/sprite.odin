package main

import "core:fmt"
import glm "core:math/linalg/glsl"
import gl "vendor:OpenGL"
import "vendor:glfw"
import "vendor:stb/image"
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

Image :: struct {
    width:  i32,
    height: i32,
    dim:    i32,
    data:   ^u8,
}

ScreenBuffer :: struct {
    vao : u32,
    vbo : u32,
    shader : u32,
    texture : u32,
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

loadTexture :: proc(shader : u32, filename : cstring) -> u32 {
    gl.UseProgram(shader)

    img: Image
    img.data = image.load(filename, &img.width, &img.height, &img.dim, 4)
    fmt.printf("Loaded image %d X %d X %d\n", img.width, img.height, img.dim)

    texture: u32
    gl.GenTextures(1, &texture)
    gl.BindTexture(gl.TEXTURE_2D, texture)

    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
    if img.data != nil {
        gl.TexImage2D( gl.TEXTURE_2D, 0, gl.RGBA, img.width, img.height, 0, gl.RGBA, gl.UNSIGNED_BYTE, img.data)
        gl.GenerateMipmap(gl.TEXTURE_2D)
    } else {
        fmt.eprintf("Unable to load texture : %s", filename)
    }
    image.image_free(img.data)
    return texture
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
    gl.BindTexture(gl.TEXTURE_2D, screenBuffer.texture);
    gl.BindVertexArray(screenBuffer.vao)
    gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)
    gl.BindVertexArray(0);
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
    
    screenBuffer.texture = loadTexture(screenBuffer.shader, "player.png")

    dt: f32 = 0
    lastTime: f32 = 0
    running := true
    playerPosition := glm.vec2{0, 0} 
    playerRotation :f32 = 0
    // playerSize := glm.vec2{32, 32}
    playerSize := glm.vec2{64,64}
    playerSpeed : f32 = 500

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
            playerRotation += 1*dt*playerSpeed
            if playerRotation > 360 {
               playerRotation = 0
            }
        }

        if glfw.GetKey(window_handle, glfw.KEY_W) != 0 {
            playerPosition.y -= playerSpeed*dt
            if playerPosition.y < 1 {
                playerPosition.y = 0
            }
        }

        if glfw.GetKey(window_handle, glfw.KEY_S) != 0 {
            playerPosition.y += playerSpeed*dt
            if (playerPosition.y + playerSize.y) >= HEIGHT {
                playerPosition.y = HEIGHT-playerSize.y
            }
        }

        if glfw.GetKey(window_handle, glfw.KEY_A) != 0 {
            playerPosition.x -= playerSpeed*dt
            if playerPosition.x < 1 {
                playerPosition.x = 0
            }
        }

        if glfw.GetKey(window_handle, glfw.KEY_D) != 0 {
            playerPosition.x += playerSpeed*dt
            if (playerPosition.x + playerSize.x) >= WIDTH {
                playerPosition.x = WIDTH-playerSize.y
            }
        }

        // render display
        gl.ClearColor(0.1, 0.3, 0.5, 1.0)
        gl.Clear(gl.COLOR_BUFFER_BIT)
    
        drawSprite(screenBuffer, glm.round_vec2(playerPosition), playerSize, playerRotation, glm.vec3{1,1 ,1})
        
        glfw.SwapBuffers(window_handle)
        
    }
    glfw.Terminate()
}

