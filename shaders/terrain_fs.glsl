#version 460

layout (location = 0) out vec4 pixel_color;

in vec3 color_fs;

void main() 
{
    pixel_color = vec4(color_fs,1.0);
}