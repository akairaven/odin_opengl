package main
// import "base:runtime"
import "core:mem"
import "core:fmt"
import glm "core:math/linalg/glsl"
import gl "vendor:OpenGL"
import "vendor:glfw"
import "shader"

WIDTH :: 1600
HEIGHT :: 900
TITLE :: "Hello SDF in GL World!"

GL_MAJOR_VERSION :: 3
GL_MINOR_VERSION :: 3

main :: proc() {
    when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	if !bool(glfw.Init()) {
		fmt.eprintln("GLFW has failed to load.")
		return
	}

	windowHandle := glfw.CreateWindow(WIDTH, HEIGHT, TITLE, nil, nil)

	defer glfw.Terminate()
	defer glfw.DestroyWindow(windowHandle)

	if windowHandle == nil {
		fmt.eprintln("GLFW has failed to load the window.")
		return
	}

	glfw.MakeContextCurrent(windowHandle)
	gl.load_up_to(GL_MAJOR_VERSION, GL_MINOR_VERSION, glfw.gl_set_proc_address)

	// Center the window in the primary monitor
	primary_monitor := glfw.GetPrimaryMonitor()
	video_mode := glfw.GetVideoMode(primary_monitor)
	x_pos := (video_mode.width - WIDTH) / 2
	y_pos := (video_mode.height - HEIGHT) / 2
	glfw.SetWindowPos(windowHandle, x_pos, y_pos)

	shaderProgram := shader.load_rounded_shader()
    gl.UseProgram(shaderProgram)
    projection := glm.mat4Ortho3d(0, WIDTH, HEIGHT, 0, -1, 1)
    shader.setMat4(shaderProgram, "projection", &projection)

    rectBuffer := initRectBuffer()
    
	// main loop
	running := true
	for running {
		gl.ClearColor(0.1, 0.3, 0.5, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT)
        drawRoundRect(rectBuffer, shaderProgram, {250,150, 400, 400}, {50,100,150,200}, {.4,.7,.4,1})
        drawRoundRect(rectBuffer, shaderProgram, {900,200, 200, 50 }, {25, 25, 25, 25}, {.8,.6,.5,1})
        drawRoundRect(rectBuffer, shaderProgram, {900,300, 200, 50 }, {5, 5, 5, 5}, {.8,.6,.5,1})
        drawRoundRect(rectBuffer, shaderProgram, {900,400, 200, 50 }, {15, 15, 0, 0}, {.8,.6,.5,1})
		glfw.SwapBuffers(windowHandle)
		glfw.PollEvents()
		// handle input
		if glfw.WindowShouldClose(windowHandle) {
			running = false
		}

		if glfw.GetKey(windowHandle, glfw.KEY_ESCAPE) != 0 {
			running = false
		}
	}
}

