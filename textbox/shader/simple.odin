package shader

SIMPLE_VERTEX :cstring : `
#version 330 core
layout (location = 0) in vec2 vertex; 

uniform mat4 model;
uniform mat4 projection;

void main()
{
    gl_Position = projection * model * vec4(vertex.xy, 0.0, 1.0);
}`

SIMPLE_FRAG :cstring : `
#version 330 core
out vec4 fragColor;

uniform vec4 color;

void main()
{
    fragColor = color;
}`

/*
Loads a simple 2D shader 
vertex is x, y : vec2
Uniforms :
projection : mat4
model : mat4
color : vec4
*/
load_simple_shader :: proc() -> u32  {
    v := SIMPLE_VERTEX
    f := SIMPLE_FRAG
    program :=  loadShader(&v, &f)

return program
}
