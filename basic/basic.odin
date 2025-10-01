package glfw_window

import "base:runtime"
import "core:fmt"
import gl "vendor:OpenGL"
import "vendor:glfw"

WIDTH :: 1600
HEIGHT :: 900
TITLE :: "Hello GL World!"

GL_MAJOR_VERSION :: 4
GL_MINOR_VERSION :: 5

resize :: proc "c" (window_handle: glfw.WindowHandle, width: i32, height: i32) {
	context = runtime.default_context()
	fmt.printf("Resize to %v %v\n", width, height)
}

main :: proc() {
	if !bool(glfw.Init()) {
		fmt.eprintln("GLFW has failed to load.")
		return
	}

	window_handle := glfw.CreateWindow(WIDTH, HEIGHT, TITLE, nil, nil)

	defer glfw.Terminate()
	defer glfw.DestroyWindow(window_handle)

	if window_handle == nil {
		fmt.eprintln("GLFW has failed to load the window.")
		return
	}

	glfw.MakeContextCurrent(window_handle)
	gl.load_up_to(GL_MAJOR_VERSION, GL_MINOR_VERSION, glfw.gl_set_proc_address)
	fmt.printf("GL Version : %v\n", gl.GetString(gl.VERSION))

	// List of all monitors with their modes
	monitors := glfw.GetMonitors()
	for monitor, i in monitors {
		video_mode := glfw.GetVideoMode(monitor)
		fmt.printf("Monitor : %v - Mode : %v \n", i, video_mode)
	}

	// Center the window in the primary monitor
	primary_monitor := glfw.GetPrimaryMonitor()
	video_mode := glfw.GetVideoMode(primary_monitor)
	x_pos := (video_mode.width - WIDTH) / 2
	y_pos := (video_mode.height - HEIGHT) / 2
	glfw.SetWindowPos(window_handle, x_pos, y_pos)

	// attach a callback to window resize
	glfw.SetWindowSizeCallback(window_handle, resize)

	// main loop
	running := true
	for running {
		gl.ClearColor(0.1, 0.3, 0.5, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT)
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

		glfw.SwapBuffers(window_handle)
	}
}

