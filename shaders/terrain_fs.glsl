#version 460

layout (location = 0) out vec4 pixel_color;

flat in uint material_id_fs;

void main() 
{
    vec3 color;
    if (material_id_fs == 1)
        color = vec3(0.5,0.5,0.0);
    else
        color = vec3(0.0,0.0,0.5);

    pixel_color = vec4(color,1.0);
}