package glfw_window

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
	Vertex :: struct {
		position: glm.vec3,
		color:    glm.vec4,
		texture:  glm.vec2,
	}

	vertices: []Vertex = {
		{
			{-0.5, 0.5, 0}, // top left
			{0, 1, 1, 0.2},
			{0, 1},
		},
		{
			{0.5, 0.5, 0}, // top right
			{1.0, 0, 0, 1},
			{1, 1},
		},
		{
			{0.5, -0.5, 0}, // bottom right
			{0, 1, 0, 1},
			{1, 0},
		},
		{
			{-0.5, -0.5, 0}, // Bottom-left
			{0, 0, 1, 1},
			{0, 0},
		},
	}
	indices: []u32 = {0, 1, 2, 3, 0, 2}

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
	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 9 * size_of(f32), uptr)
	gl.EnableVertexAttribArray(0)

	gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 9 * size_of(f32), (4 * size_of(f32)))
	gl.EnableVertexAttribArray(1)

	gl.VertexAttribPointer(2, 3, gl.FLOAT, gl.FALSE, 9 * size_of(f32), (7 * size_of(f32)))
	gl.EnableVertexAttribArray(2)

	gl.BindBuffer(gl.ARRAY_BUFFER, 0)
	gl.BindVertexArray(0)

	// main loop
	Image :: struct {
		width:  i32,
		height: i32,
		dim:    i32,
		data:   ^u8,
	}
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
		gl.TexImage2D(
			gl.TEXTURE_2D,
			0,
			gl.RGBA,
			img.width,
			img.height,
			0,
			gl.RGBA,
			gl.UNSIGNED_BYTE,
			img.data,
		)
		gl.GenerateMipmap(gl.TEXTURE_2D)
	} else {
		fmt.eprintf("unable to load texture")
	}

	gl.UseProgram(shaderProgram)
	gl.Uniform1i(gl.GetUniformLocation(shaderProgram, "texture1"), 0)

	image.image_free(img.data)

	running := true
	for running {
		gl.ClearColor(0.1, 0.3, 0.5, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT)

		gl.ActiveTexture(gl.TEXTURE0)
		gl.BindTexture(gl.TEXTURE_2D, texture1)
		gl.UseProgram(shaderProgram)
		gl.BindVertexArray(vao)

		// transformation
		trans := glm.mat4(1)
		trans = trans * glm.mat4Scale(glm.vec3{.75, .75, 0})
		trans = trans * glm.mat4Translate(glm.vec3{.3, .3, 0})
		trans = trans * glm.mat4Rotate(glm.vec3{0, 0, 1}, f32(glfw.GetTime()))

		transformLoc := gl.GetUniformLocation(shaderProgram, "transform")
		gl.UniformMatrix4fv(transformLoc, 1, false, &trans[0, 0])
		// transformation

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

