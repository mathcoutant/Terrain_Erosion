#version 460
#define TEX3D_SLOT_TERRAIN_READ 0
#define TEX3D_SLOT_TERRAIN_WRITE 1
#define SSBO_SLOT_WATER_COUNTER 0
#define UBO_APPLICATION_BINDING 0
#define FRACTION_DIVIDER (1.0/60000.0)
#define FRACTION_QUANTIZER (60000u)
layout (local_size_x = 4, local_size_y = 4,local_size_z = 4) in;

layout(binding = TEX3D_SLOT_TERRAIN_READ, rgba16ui) restrict writeonly uniform uimage3D tex_terrain_read;
layout(binding = TEX3D_SLOT_TERRAIN_WRITE, rgba16ui) restrict writeonly uniform uimage3D tex_terrain_write;

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

void main() {
ivec3 voxel_coord = ivec3(gl_GlobalInvocationID.xyz);

if (voxel_coord.x>=dimension.x || voxel_coord.y>=dimension.y || voxel_coord.z>=dimension.z)
    return;//abort invocation if voxel out from texture3D

vec3 value = vec3(0.5);
value.x = 0.0;
value.z = float(voxel_coord.y)/float(dimension.y);
//vec3(voxel_coord)/vec3(dimension.xyz);

uvec3 new_terrain_quantized = clamp(uvec3(value*FRACTION_QUANTIZER),0u,FRACTION_QUANTIZER);

imageStore(tex_terrain_read,voxel_coord,uvec4(new_terrain_quantized,0));
imageStore(tex_terrain_write,voxel_coord,uvec4(new_terrain_quantized,0));
}