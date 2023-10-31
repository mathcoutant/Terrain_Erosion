#version 460
#define TEX3D_SLOT_TERRAIN_READ 0
#define TEX3D_SLOT_TERRAIN_WRITE 1
#define SSBO_SLOT_WATER_COUNTER 0
#define UBO_APPLICATION_BINDING 0
#define FRACTION_DIVIDER (1.0/60000.0)
#define FRACTION_QUANTIZER (60000u)
layout (local_size_x = 4, local_size_y = 4,local_size_z = 4) in;

layout(binding = TEX3D_SLOT_TERRAIN_READ, rgba16ui) readonly uniform uimage3D tex_terrain_read;
layout(binding = TEX3D_SLOT_TERRAIN_WRITE, rgba16ui) uniform uimage3D tex_terrain_write;

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


layout(std430, binding = SSBO_SLOT_WATER_COUNTER) buffer SSBO_WATER_COUNTER
{
    uvec4 water_counter;
};

void main() {
ivec3 voxel_coord = ivec3(gl_GlobalInvocationID.xyz);

if (voxel_coord.x>=dimension.x || voxel_coord.y>=dimension.y || voxel_coord.z>=dimension.z)
    return;//abort invocation if voxel out from texture3D

vec3 terrain = vec3(imageLoad(tex_terrain_read,voxel_coord).xyz) * FRACTION_DIVIDER;

//transforms a bit of water into rock in the same voxel, for demo purpose

float sum_soil_water = terrain.y + terrain.z;
float new_water = terrain.y * 0.99;//1% of whater removed
float new_soil = sum_soil_water - new_water;//ensure total matter conservation

vec3 new_terrain = vec3(terrain.x,new_water,new_soil);


uvec3 new_terrain_quantized = clamp(uvec3(new_terrain*FRACTION_QUANTIZER),0u,FRACTION_QUANTIZER);
imageStore(tex_terrain_write,voxel_coord,uvec4(new_terrain_quantized,0));

}