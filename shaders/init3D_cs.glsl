#version 460
layout(local_size_x = 4, local_size_y = 4,local_size_z = 4) in;

layout(binding = 0, r8ui) uniform uimage3D tex_material_id;

layout(binding = 0, std140) uniform UBO_APPLICATION
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

void main() {
ivec3 voxel_coord = ivec3(gl_GlobalInvocationID.xyz);

if (voxel_coord.x>=dimension.x || voxel_coord.y>=dimension.y || voxel_coord.z>=dimension.z)
    return;//abort invocation if voxel out from texture3D

uint material_id;
if (voxel_coord.x>=dimension.x/2 || voxel_coord.y>=dimension.y/2 || voxel_coord.z>=dimension.z/2)
    material_id = 1;
else
    material_id = 0;

imageStore(tex_material_id,voxel_coord,uvec4(material_id,0,0,0));
}