package glfw_window

import "core:fmt"
import gl "vendor:OpenGL"

/* Simple shader program */
load_shaders :: proc() -> u32 {
	success: i32
	infolog: [512]u8

	// vertex shader
	vertex_shader_source := cstring(#load("vertexshader.glsl"))
	v_shader: u32 = gl.CreateShader(gl.VERTEX_SHADER)
	gl.ShaderSource(v_shader, 1, &vertex_shader_source, nil)

	gl.CompileShader(v_shader)
	gl.GetShaderiv(v_shader, gl.COMPILE_STATUS, &success)
	if success == 0 {
		gl.GetShaderInfoLog(v_shader, 512, nil, raw_data(infolog[:]))
		fmt.eprintf("Error with vertex Shader : %v\n", string(infolog[:]))
	}
	// fragment shader
	fragment_shader_source := cstring(#load("fragmentshader.glsl"))

	f_shader: u32 = gl.CreateShader(gl.FRAGMENT_SHADER)
	gl.ShaderSource(f_shader, 1, &fragment_shader_source, nil)
	gl.CompileShader(f_shader)
	gl.GetShaderiv(f_shader, gl.COMPILE_STATUS, &success)
	if success == 0 {
		gl.GetShaderInfoLog(f_shader, 512, nil, raw_data(infolog[:]))
		fmt.eprintf("Error with vertex Shader : %v\n", string(infolog[:]))
	}

	// shader program
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

