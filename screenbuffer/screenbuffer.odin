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
    
Vertex :: struct {
    position: glm.vec3,
    texture:  glm.vec2,
}

ScreenVertices: []Vertex = {
    { {-1,  1, 0}, {0, 1}, }, // top left
    { { 1, -1, 0}, {1, 0}, }, // bottom right
    { { 1 , 1, 0}, {1, 1}, }, // top right
    { {-1,  1, 0}, {0, 1}, }, // top left
    { {-1, -1, 0}, {0, 0}, }, // bottom left
    { { 1, -1, 0}, {1, 0}, }, // bottom right
}

Pixel :: struct {
    r : u8,
    g : u8,
    b : u8,
    a : u8,
}

Image :: struct {
    width:  i32,
    height: i32,
    data:   ^[]Pixel,
}


ScreenBuffer :: struct {
    vao : u32,
    vbo : u32,
    shader : u32,
    texture : u32,
    image: Image,
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

    // Center the window in the primary monitor
    primary_monitor := glfw.GetPrimaryMonitor()
    video_mode := glfw.GetVideoMode(primary_monitor)
    x_pos := (video_mode.width - WIDTH) / 2
    y_pos := (video_mode.height - HEIGHT) / 2
    glfw.SetWindowPos(window_handle, x_pos, y_pos)
    return window_handle
}

initScreen :: proc()  -> ScreenBuffer {
    screenBuffer := ScreenBuffer{}

    vertexSource := cstring(#load("vertexshader.glsl"))
    fragmentSource := cstring(#load("fragmentshader.glsl"))
    shaderProgram: u32 = shader.loadShader(&vertexSource, &fragmentSource)
    screenBuffer.shader = shaderProgram

    gl.GenVertexArrays(1, &screenBuffer.vao)
    gl.GenBuffers(1, &screenBuffer.vbo)

    gl.BindVertexArray(screenBuffer.vao)

    gl.BindBuffer(gl.ARRAY_BUFFER, screenBuffer.vbo)
    gl.BufferData(gl.ARRAY_BUFFER, len(ScreenVertices) * size_of(ScreenVertices[0]), raw_data(ScreenVertices), gl.STATIC_DRAW)

    uptr: uintptr  
    // vertice pointer
    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 5 * size_of(f32), uptr)
    gl.EnableVertexAttribArray(0)
    // texture pointer
    gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 5 * size_of(f32), (3 * size_of(f32)))
    gl.EnableVertexAttribArray(1)

    gl.BindBuffer(gl.ARRAY_BUFFER, 0)
    gl.BindVertexArray(0)

    gl.GenTextures(1, &screenBuffer.texture)
    gl.BindTexture(gl.TEXTURE_2D, screenBuffer.texture)

    return screenBuffer
}

renderToTexture :: proc(screenBuffer : ScreenBuffer, image: Image) {

    if image.data != nil {
        imageDataPtr := raw_data(image.data[:])
        gl.TexImage2D( gl.TEXTURE_2D, 0, gl.RGBA, image.width, image.height, 0, gl.RGBA, gl.UNSIGNED_BYTE, imageDataPtr )
        gl.GenerateMipmap(gl.TEXTURE_2D)
    } else {
        fmt.eprintf("Unable to load texture")
    }
    // gl.UseProgram(screenBuffer.shader)
    // gl.Uniform1i(gl.GetUniformLocation(screenBuffer.shader, "texture1"), 0)

}

updateScreen :: proc(screenBuffer : ScreenBuffer) {
        gl.ActiveTexture(gl.TEXTURE0)
        gl.BindTexture(gl.TEXTURE_2D, screenBuffer.texture)
        gl.UseProgram(screenBuffer.shader)
        gl.BindVertexArray(screenBuffer.vao)
        gl.DrawArrays(gl.TRIANGLES, 0, 6)
}

drawRectagle := proc(x:i32, y:i32, width:i32, height:i32, color : Pixel, image:Image){
    for row in 0..< height{
        if (y + row) >= image.height {
            break
        }
        for col in 0..<width{
            if (x + col) >= image.width {
                continue
            }
           image.data[((y+row)*image.width) + col+x] = color
        }
    }
}

main :: proc() {

    window_handle := initWindow()
    if window_handle == nil {
        panic("Unable to init")
    }
    screenBuffer := initScreen()
    
    image: Image = {
        width  = WIDTH,
        height = HEIGHT,
    }
    bufferSize := image.height * image.width 
    imageBuffer := make([]Pixel, bufferSize)
    defer delete(imageBuffer)
    image.data = &imageBuffer

    dt: f32 = 0
    lastTime: f32 = 0
    running := true
    
    height :i32 = 400
    for running {
        currentTime := f32(glfw.GetTime())
        dt = currentTime - lastTime
        lastTime = currentTime
        fmt.printf("\r%.f FPS ", 1/dt)

        glfw.PollEvents()
        // handle input
        if glfw.WindowShouldClose(window_handle) {
            running = false
        }

        if glfw.GetKey(window_handle, glfw.KEY_ESCAPE) != 0 {
            running = false
        }

        if glfw.GetKey(window_handle, glfw.KEY_A) != 0 {
            fmt.printf("Pressed A\n")
        }
        if glfw.GetKey(window_handle, glfw.KEY_UP) != 0 {
            height += i32(200.0*dt)
        }

        if glfw.GetKey(window_handle, glfw.KEY_DOWN) != 0 {
            height -= i32(200.0*dt)
        }

        gl.ClearColor(0.1, 0.3, 0.5, 1.0)
        gl.Clear(gl.COLOR_BUFFER_BIT)

        /// main code 
        drawRectagle(0, 0, 1600, 900, Pixel{0,0,0,0}, image)
        drawRectagle(100, 100, 1400, height, Pixel{10,200,150,255}, image)
        /// main code

        renderToTexture(screenBuffer, image)
        updateScreen(screenBuffer)
        glfw.SwapBuffers(window_handle)
        
    }
    glfw.Terminate()
}

