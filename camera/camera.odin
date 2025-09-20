package glfw_window

import "base:runtime"
import "core:fmt"
import glm "core:math/linalg/glsl"
import gl "vendor:OpenGL"
import "vendor:glfw"
import "vendor:stb/image"

WIDTH :: 1600
HEIGHT :: 900
TITLE :: "Hello GL World!"

GL_MAJOR_VERSION :: 4
GL_MINOR_VERSION :: 5

Movement :: enum {
    Up,
    Down,
    Forward,
    Back,
    Left,
    Right
}

Vertex :: struct {
    position: glm.vec3,
    texture:  glm.vec2,
}

Image :: struct {
    width:  i32,
    height: i32,
    dim:    i32,
    data:   ^u8,
}

Camera :: struct {
    yaw:         f64,
    pitch:       f64,
    front:       glm.vec3,
    position:    glm.vec3,
    up:          glm.vec3,
}

camera := Camera {
    yaw         = -90,
    pitch       = 0,
    front       = glm.vec3{0, 0, -1},
    position    = glm.vec3{0, 0, 3},
    up          = glm.vec3{0, 1, 0},
}

moveCamera:: proc (move : Movement, cameraSpeed : f32) {
    #partial switch move {
    case .Up : camera.position.y += cameraSpeed
    case .Down : camera.position.y -= cameraSpeed
    case .Forward : camera.position += cameraSpeed * camera.front
    case .Back : camera.position -= cameraSpeed * camera.front
    case .Left : camera.position -= cameraSpeed * glm.normalize(glm.cross(camera.front, camera.up))
    case .Right : camera.position += cameraSpeed * glm.normalize(glm.cross(camera.front, camera.up))
    }
}

Mouse :: struct {
    lastX:       f64,
    lastY:       f64,
    Xoffset:     f64,
    Yoffset:     f64,
    initialized: bool,
    sensitivity: f64,
}

mouse := Mouse {
    sensitivity = 0.1,
}

updateCamera :: proc (Xoffset :f64, Yoffset : f64) {
    camera.yaw += Xoffset
    camera.pitch += Yoffset
    if camera.pitch > 89 {
        camera.pitch = 89
    }
    if camera.pitch < -89 {
        camera.pitch = -89
    }
    direction := glm.vec3{}

    direction.x = f32(glm.cos(glm.radians_f64(camera.yaw)) * glm.cos(glm.radians_f64(camera.pitch)))
    direction.y = f32(glm.sin(glm.radians_f64(camera.pitch)))
    direction.z = f32(glm.sin(glm.radians_f64(camera.yaw)) * glm.cos(glm.radians_f64(camera.pitch)))
    camera.front = glm.normalize(direction)
}

mouseInput :: proc "c" (window: glfw.WindowHandle, xpos: f64, ypos: f64) {
    context = runtime.default_context()
    if !mouse.initialized {
        mouse.lastX = xpos
        mouse.lastY = ypos
        mouse.initialized = true
    }
    mouse.Xoffset = (xpos - mouse.lastX) * mouse.sensitivity
    mouse.Yoffset = (mouse.lastY - ypos) * mouse.sensitivity
    mouse.lastY = ypos
    mouse.lastX = xpos
    updateCamera(mouse.Xoffset,mouse.Yoffset)
}

init :: proc() -> glfw.WindowHandle {
    if !bool(glfw.Init()) {
        fmt.eprintln("GLFW has failed to load.")
        return nil
    }

    window_handle := glfw.CreateWindow(WIDTH, HEIGHT, TITLE, nil, nil)

    if window_handle == nil {
        fmt.eprintln("GLFW has failed to load the window.")
        return nil
    }
    glfw.MakeContextCurrent(window_handle)
    gl.load_up_to(GL_MAJOR_VERSION, GL_MINOR_VERSION, glfw.gl_set_proc_address)

    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
    gl.Enable(gl.BLEND)
    gl.Enable(gl.DEPTH_TEST)

    glfw.SetInputMode(window_handle, glfw.CURSOR, glfw.CURSOR_DISABLED)
    glfw.SetCursorPosCallback(window_handle, mouseInput)

    // Center the window in the primary monitor
    primary_monitor := glfw.GetPrimaryMonitor()
    video_mode := glfw.GetVideoMode(primary_monitor)
    x_pos := (video_mode.width - WIDTH) / 2
    y_pos := (video_mode.height - HEIGHT) / 2
    glfw.SetWindowPos(window_handle, x_pos, y_pos)
    return window_handle
}

cleanup :: proc(window_handle: glfw.WindowHandle) {
    defer glfw.Terminate()
    defer glfw.DestroyWindow(window_handle)
}

main :: proc() {

    window_handle := init()
    if window_handle == nil {
        panic("Unable to init")
    }
    defer cleanup(window_handle)

    shaderProgram: u32 = load_shaders()
    vertices := make_cube(width = 1, texture_count = 2.0)

    vbo: u32
    vao: u32

    gl.GenVertexArrays(1, &vao)
    gl.GenBuffers(1, &vbo)

    gl.BindVertexArray(vao)

    gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
    gl.BufferData(
        gl.ARRAY_BUFFER,
        len(vertices) * size_of(vertices[0]),
        raw_data(vertices[:]),
        gl.STATIC_DRAW,
    )

    uptr: uintptr
    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 5 * size_of(f32), uptr)
    gl.EnableVertexAttribArray(0)

    gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 5 * size_of(f32), (3 * size_of(f32)))
    gl.EnableVertexAttribArray(1)

    gl.BindBuffer(gl.ARRAY_BUFFER, 0)
    gl.BindVertexArray(0)

    img: Image
    img.data = image.load("logo-slim.png", &img.width, &img.height, &img.dim, 4)
    fmt.printf("Loaded image %d X %d X %d\n", img.width, img.height, img.dim)

    texture1: u32
    gl.GenTextures(1, &texture1)
    gl.BindTexture(gl.TEXTURE_2D, texture1)

    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
    // set texture filtering parameters
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

    if img.data != nil {
        gl.TexImage2D( gl.TEXTURE_2D, 0, gl.RGBA, img.width, img.height, 0, gl.RGBA, gl.UNSIGNED_BYTE, img.data)
        gl.GenerateMipmap(gl.TEXTURE_2D)
    } else {
        fmt.eprintf("unable to load texture")
    }

    gl.UseProgram(shaderProgram)
    gl.Uniform1i(gl.GetUniformLocation(shaderProgram, "texture1"), 0)

    image.image_free(img.data)

    model := glm.mat4(1) * 1
    modelLoc := gl.GetUniformLocation(shaderProgram, "model")
    gl.UniformMatrix4fv(modelLoc, 1, false, &model[0, 0])

    view := glm.mat4LookAt(camera.position, camera.position + camera.front, camera.up)

    projection := glm.mat4Perspective(glm.radians(f32(45.0)), f32(WIDTH) / f32(HEIGHT), 0.1, 100)
    projectionLoc := gl.GetUniformLocation(shaderProgram, "projection")
    gl.UniformMatrix4fv(projectionLoc, 1, false, &projection[0, 0])

    // main loop
    running := true
    dt: f32 = 0
    lastTime: f32 = 0
    cameraSpeed: f32 = 0

    direction := glm.vec3{0, 0, 2}
    pitch: f64 = 0
    yaw: f64 = 0

    for running {
        currentTime := f32(glfw.GetTime())
        dt = currentTime - lastTime
        lastTime = currentTime
        cameraSpeed = dt * 2

        glfw.PollEvents()
        // handle input
        if glfw.WindowShouldClose(window_handle) {
            running = false
        }

        if glfw.GetKey(window_handle, glfw.KEY_ESCAPE) != 0 {
            running = false
        }
        if glfw.GetKey(window_handle, glfw.KEY_W) != 0 {
            moveCamera(.Forward, cameraSpeed)
        }
        if glfw.GetKey(window_handle, glfw.KEY_S) != 0 {
            moveCamera(.Back, cameraSpeed)
        }
        if glfw.GetKey(window_handle, glfw.KEY_A) != 0 {
            moveCamera(.Left, cameraSpeed)
        }
        if glfw.GetKey(window_handle, glfw.KEY_D) != 0 {
            moveCamera(.Right, cameraSpeed)
        }

        if glfw.GetKey(window_handle, glfw.KEY_LEFT_SHIFT) != 0 {
            moveCamera(.Down, cameraSpeed)
        }
        if glfw.GetKey(window_handle, glfw.KEY_SPACE) != 0 {
            moveCamera(.Up, cameraSpeed)
        }
        // display
        gl.ClearColor(0.1, 0.3, 0.5, 1.0)
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
        gl.ActiveTexture(gl.TEXTURE0)
        gl.BindTexture(gl.TEXTURE_2D, texture1)
        gl.UseProgram(shaderProgram)

        view = glm.mat4LookAt(camera.position, camera.position + camera.front, camera.up)
        viewLoc := gl.GetUniformLocation(shaderProgram, "view")
        gl.UniformMatrix4fv(viewLoc, 1, false, &view[0, 0])

        gl.BindVertexArray(vao)
        gl.DrawArrays(gl.TRIANGLES, 0, 36)

        glfw.SwapBuffers(window_handle)

    }
}

