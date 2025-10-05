package shader

TEXTURE_VERTEX :cstring : `
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

TEXTURE_FRAG :cstring : `
#version 330 core
in vec2 TexCoords;
out vec4 color;

uniform sampler2D image;
uniform vec3 spriteColor;

void main()
{    
    color = vec4(spriteColor, 1.0) * texture(image, TexCoords);
}`

/*
Loads a texture 2D shader 
vertex is x, y, texture_x, texture_y: vec4
Uniforms :
projection : mat4
model : mat4
*/
load_texture_shader :: proc() -> u32  {
    v := TEXTURE_VERTEX
    f := TEXTURE_FRAG
    program :=  loadShader(&v, &f)

return program
}
