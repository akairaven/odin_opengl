package shader

SIMPLE_ROUNDED_VERTEX :cstring : `
#version 330 core
layout (location = 0) in vec3 vertex; 

uniform mat4 model;
uniform mat4 projection;

void main()
{
    gl_Position = projection * model * vec4(vertex.xy, 0.0, 1.0);
}`

SIMPLE_ROUNDED_FRAG :cstring : `
#version 330 core
out vec4 fragColor;
layout(origin_upper_left) in vec4 gl_FragCoord;

uniform vec2 halfSize;
uniform vec2 rectCenter;
uniform vec4 cornerRadius;
uniform vec4 color;

// from Inigo Quilez tutorial on SDF
float roundedBoxSDF(vec2 p,vec2 b, vec4 r ) 
{
    r.xy = (p.x>0.0)?r.xy : r.zw; // left or right
    r.x  = (p.y>0.0)?r.y  : r.x; // top or bottom
    vec2 q = abs(p)-b+r.x;
    return min(max(q.x,q.y),0.0) + length(max(q,0.0)) - r.x;
}

void main()
{
   vec2 p = gl_FragCoord.xy;

   float distance = roundedBoxSDF(p - rectCenter, halfSize, cornerRadius);
   if (distance > 0.00) {
        discard;
    }
    else {
        fragColor = color;
    }
}`

/*
Loads a rounded simple 2D shader 
vertex is x, y: vec2
Uniforms :
projection : mat4
model : mat4
halfSize : vec2
rectCenter : vec2
cornerRadius : vec4 top-right, bottom-right, top-left, bottom-left
color : vec4
*/

load_rounded_shader :: proc() -> u32  {
    v := SIMPLE_ROUNDED_VERTEX
    f := SIMPLE_ROUNDED_FRAG
    program :=  loadShader(&v, &f)

return program
}
