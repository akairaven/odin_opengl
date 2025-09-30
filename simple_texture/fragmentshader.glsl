#version 330 core

in vec4 vertexColor;
in vec2 TexCoord;
out vec4 FragColor;

uniform sampler2D texture1;

void main()
{
   // FragColor = vec4(vertexColor);
    FragColor = texture(texture1, TexCoord);
} 
