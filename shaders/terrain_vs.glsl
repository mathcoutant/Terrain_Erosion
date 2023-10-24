#version 460
#define UBO_APPLICATION_BINDING 0

layout(binding = 0, r8ui) restrict readonly uniform uimage3D tex_material_id;

//matches buffer_structures.hpp
layout(binding = UBO_APPLICATION_BINDING, std140) uniform UBO_APPLICATION
{
    //General
    mat4 proj; //projection matrix (view to eye)
    mat4 inv_proj; //inverse projection matrix (eye to view)
    mat4 w_v; //world to view matrix
    mat4 w_v_p; //world to eye matrix
    mat4 inv_w_v_p; //eye to world matrix
    vec4 cam_pos;//camera position in world space, .w: time
    //Light
    vec4 sun_light;//.xyz: direction, .w:intensity
    //Terrain
    ivec4 dimension; //.x:dimension.x, .y:dimension.y, .z: dimension.z, .w:Voxel_count
    vec4 params;//.x: erosion factor, .y: terrain_seed [UINT], .z:scale, .w:unused
    //Modelisation parameters to add probably
};


out vec3 pos[];
out uint material_id;
void main() 
{
    int dim_2d = (dimension.y*dimension.z);
    ivec3 voxel_coord = ivec3(gl_VertexID / dim_2d,(gl_VertexID % dim_2d)/dimension.z,(gl_VertexID % dim_2d) % dimension.z);

    vec3 pos = voxel_coord * params.z;
    material_id = imageLoad(tex_material_id,voxel_coord).x;

    gl_Position = w_v_p*vec4(pos,1.0);
}
