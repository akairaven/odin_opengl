package shader

import "core:fmt"
import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"

setMat4 :: proc(shaderProgram : u32, name : cstring, mat4: ^glm.mat4) {
		gl.UniformMatrix4fv(
			gl.GetUniformLocation(shaderProgram, name), 1, false, &mat4[0, 0])
}

setVec2 :: proc(shaderProgram : u32, name : cstring, vec2: ^glm.vec2) {
		gl.Uniform2fv(
			gl.GetUniformLocation(shaderProgram, name), 1, &vec2[0])
}

setVec3 :: proc(shaderProgram : u32, name : cstring, vec3: ^glm.vec3) {
		gl.Uniform3fv(
			gl.GetUniformLocation(shaderProgram, name), 1, &vec3[0])
}

setVec4 :: proc(shaderProgram : u32, name : cstring, vec4: ^glm.vec4) {
		gl.Uniform4fv(
			gl.GetUniformLocation(shaderProgram, name), 1, &vec4[0])
}

setFloat :: proc(shaderProgram : u32, name : cstring, f: f32) {
		gl.Uniform1f(
			gl.GetUniformLocation(shaderProgram, name), f)
}

set1i :: proc(shaderProgram : u32, name : cstring, i: i32) {
		gl.Uniform1i(
			gl.GetUniformLocation(shaderProgram, name), i)
}

loadShader :: proc(vertex_source : ^cstring, fragment_source : ^cstring) -> u32 {
	success: i32
	infolog: [512]u8

	// vertex shader
	vertex_shader: u32 = gl.CreateShader(gl.VERTEX_SHADER)
	gl.ShaderSource(vertex_shader, 1, vertex_source, nil)

	gl.CompileShader(vertex_shader)
	gl.GetShaderiv(vertex_shader, gl.COMPILE_STATUS, &success)
	if success == 0 {
		gl.GetShaderInfoLog(vertex_shader, 512, nil, &infolog[0])
		fmt.eprintf("Error with vertex Shader : %v\n", string(infolog[:]))
	}

	// fragment shader
	fragment_shader: u32 = gl.CreateShader(gl.FRAGMENT_SHADER)
	gl.ShaderSource(fragment_shader, 1, fragment_source, nil)
	gl.CompileShader(fragment_shader)
	gl.GetShaderiv(fragment_shader, gl.COMPILE_STATUS, &success)
	if success == 0 {
		gl.GetShaderInfoLog(fragment_shader, 512, nil, &infolog[0])
		fmt.eprintf("Error with fragment Shader : %v\n", string(infolog[:]))
	}

	// shader program
	shaderProgram: u32 = gl.CreateProgram()
	gl.AttachShader(shaderProgram, vertex_shader)
	gl.AttachShader(shaderProgram, fragment_shader)
	gl.LinkProgram(shaderProgram)

	gl.GetProgramiv(shaderProgram, gl.LINK_STATUS, &success)
	if success == 0 {
		gl.GetShaderInfoLog(shaderProgram, 512, nil, &infolog[0])
		fmt.eprintf("Error with Shader link : %v\n", string(infolog[:]))
	}

	// cleanup
	gl.DeleteShader(vertex_shader)
	gl.DeleteShader(fragment_shader)
	return shaderProgram
}

