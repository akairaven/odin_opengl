package glfw_window

import "base:runtime"
import "core:fmt"
import glm "core:math/linalg/glsl"
import gl "vendor:OpenGL"
import "vendor:glfw"

WIDTH :: 1600
HEIGHT :: 900
TITLE :: "Hello GL World!"

GL_MAJOR_VERSION :: 4
GL_MINOR_VERSION :: 5

/* Simple shader program */
load_shaders :: proc() -> u32 {
	vertex_shader_source: cstring = `#version 330 core
                                     layout (location = 0) in vec3 aPos;
                                     void main()
                                     {
                                     gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);
                                     }`


	fragment_shader_source: cstring = `#version 330 core
										out vec4 FragColor;
										void main()
										{
										FragColor = vec4(1.0f, 0.5f, 0.2f, 1.0f);
										} `


	success: i32
	infolog: [512]u8
	// vertex shader
	v_shader: u32 = gl.CreateShader(gl.VERTEX_SHADER)
	gl.ShaderSource(v_shader, 1, &vertex_shader_source, nil)
	gl.CompileShader(v_shader)
	gl.GetShaderiv(v_shader, gl.COMPILE_STATUS, &success)
	if success == 0 {
		gl.GetShaderInfoLog(v_shader, 512, nil, raw_data(infolog[:]))
		fmt.eprintf("Error with vertex Shader : %v\n", string(infolog[:]))
	}
	// fragment shader
	f_shader: u32 = gl.CreateShader(gl.FRAGMENT_SHADER)
	gl.ShaderSource(f_shader, 1, &fragment_shader_source, nil)
	gl.CompileShader(f_shader)
	gl.GetShaderiv(f_shader, gl.COMPILE_STATUS, &success)
	if success == 0 {
		gl.GetShaderInfoLog(f_shader, 512, nil, raw_data(infolog[:]))
		fmt.eprintf("Error with vertex Shader : %v\n", string(infolog[:]))
	}

	shaderProgram: u32 = gl.CreateProgram()
	gl.AttachShader(shaderProgram, v_shader)
	gl.AttachShader(shaderProgram, f_shader)
	gl.LinkProgram(shaderProgram)

	gl.GetProgramiv(shaderProgram, gl.LINK_STATUS, &success)
	if success == 0 {
		gl.GetShaderInfoLog(v_shader, 512, nil, raw_data(infolog[:]))
	}

	// cleanup
	gl.DeleteShader(v_shader)
	gl.DeleteShader(f_shader)
	return shaderProgram
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

	// Center the window in the primary monitor
	primary_monitor := glfw.GetPrimaryMonitor()
	video_mode := glfw.GetVideoMode(primary_monitor)
	x_pos := (video_mode.width - WIDTH) / 2
	y_pos := (video_mode.height - HEIGHT) / 2
	glfw.SetWindowPos(window_handle, x_pos, y_pos)

	shaderProgram := load_shaders()

	vertices: []f32 = {
		0.5, 0.5, 0.0, // top right
		0.5, -0.5, 0.0, // bottom right
		-0.5, -0.5, 0.0, // Bottom-left
		-0.5, 0.5, 0.0, // top left
	}

    // order of the vertices
	indices: []u32 = {0, 1, 3, 1, 2, 3}

	vbo: u32
	vao: u32
	ebo: u32

	gl.GenVertexArrays(1, &vao)
	gl.GenBuffers(1, &vbo)
	gl.GenBuffers(1, &ebo)

	gl.BindVertexArray(vao)

	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	gl.BufferData(
		gl.ARRAY_BUFFER,
		len(vertices) * size_of(vertices[0]),
		raw_data(vertices),
		gl.STATIC_DRAW,
	)

	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)
	gl.BufferData(
		gl.ELEMENT_ARRAY_BUFFER,
		len(indices) * size_of(indices[0]),
		raw_data(indices),
		gl.STATIC_DRAW,
	)

	uptr: uintptr
	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * size_of(f32), uptr)
	gl.EnableVertexAttribArray(0)

	gl.BindBuffer(gl.ARRAY_BUFFER, 0)
	gl.BindVertexArray(0)

	// for line instead of filled uncomment
	//gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE)
	// main loop

	running := true
	for running {
		gl.ClearColor(0.1, 0.3, 0.5, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT)

		gl.UseProgram(shaderProgram)
		gl.BindVertexArray(vao)
		gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil)
		glfw.SwapBuffers(window_handle)
		glfw.PollEvents()
		// handle input
		if glfw.WindowShouldClose(window_handle) {
			running = false
		}

		if glfw.GetKey(window_handle, glfw.KEY_ESCAPE) != 0 {
			running = false
		}
	}
}

