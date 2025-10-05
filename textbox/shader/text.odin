package shader

TEXT_VERTEX :cstring : `
#version 330 core
layout (location = 0) in vec4 vertex; 

out vec2 TexCoords;

uniform mat4 model;
uniform mat4 projection;

void main()
{
    TexCoords = vertex.zw;
    gl_Position = projection * model * vec4(vertex.xy, 0.0, 1.0);
}`

TEXT_FRAG :cstring : `
#version 330 core
in vec2 TexCoords;
out vec4 color;

uniform sampler2D image;
uniform vec4 textColor;

void main()
{    
    color = textColor * texture(image, TexCoords).r;
}`

/*
Loads a text shader for use with an atlas texture with is red channel only 
vertex is x, y, texture_x, texture_+y : vec4
Uniforms :
projection : mat4
model : mat4
color : vec4
*/
load_text_shader :: proc() -> u32  {
    v := TEXT_VERTEX
    f := TEXT_FRAG
    program :=  loadShader(&v, &f)

return program
}
