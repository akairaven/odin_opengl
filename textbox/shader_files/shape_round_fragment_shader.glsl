#version 330 core
out vec4 fragColor;
layout(origin_upper_left) in vec4 gl_FragCoord;

uniform vec2 halfSize;
uniform vec2 rectCenter;
uniform float cornerRadius;
uniform vec4 color;


float roundedBoxSDF(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + vec2(r);
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
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
} 
