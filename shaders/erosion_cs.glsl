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

if (terrain.x>max(terrain.y,terrain.z))
    return;//do not simulate if voxel is air, nothing to do

if (voxel_coord.y == dimension.y - 1)
    return;//do not simulate if voxel on the top level (we concider it will always be air)

vec3 upperVoxel = vec3(imageLoad(tex_terrain_read,voxel_coord + ivec3(0,1,0)).xyz) * FRACTION_DIVIDER;
if (upperVoxel.x < max(upperVoxel.y,upperVoxel.z))
    return;//do not simulate if voxel is not on the surface

//victo's code :
if (terrain.z>max(terrain.x,terrain.y)){  //if terrain is water
    int empty_cubes=0; //count the number of empty cubes around
    for (int x_ = voxel_coord.x -1;x_<voxel_coord.x +2;x_++){
        for(int z_= voxel_coord.z -1;z_<voxel_coord.z +2;z_++){
            if(x_ !=voxel_coord.x || z_ !=voxel_coord.z){
                ivec3 neighbour_coord = voxel_coord + ivec3(x_,0,z_);
                if (neighbour_coord.x>=dimension.x || neighbour_coord.x==0 || neighbour_coord.y>=dimension.y || neighbour_coord.y==0 || neighbour_coord.z>=dimension.z || neighbour_coord.z==0)
                    break;//abort invocation if voxel out from texture3D
                vec3 neighbour = vec3(imageLoad(tex_terrain_read,neighbour_coord).xyz) * FRACTION_DIVIDER;
                if (neighbour.x>max(neighbour.y,neighbour.z)){
                    empty_cubes+=1;
                }
            }
        }
    }
    float amount_water=terrain.z/empty_cubes;

    for (int x_ = voxel_coord.x -1;x_<voxel_coord.x +2;x_++){
        for(int z_= voxel_coord.z -1;z_<voxel_coord.z +2;z_++){
            if(x_ !=voxel_coord.x || z_ !=voxel_coord.z){
                ivec3 neighbour_coord = voxel_coord + ivec3(x_,0,z_);
                if (neighbour_coord.x>=dimension.x || neighbour_coord.x<0 || neighbour_coord.y>=dimension.y || neighbour_coord.y<0 || neighbour_coord.z>=dimension.z || neighbour_coord.z<0)
                    break;//abort invocation if voxel out from texture3D
                vec3 neighbour = vec3(imageLoad(tex_terrain_read,neighbour_coord).xyz) * FRACTION_DIVIDER;
                if (neighbour.x>max(neighbour.y,neighbour.z)){
                    neighbour.z += amount_water;
                    neighbour.x-=amount_water;
                }
            }
        }
    }
    terrain.z -=amount_water;
}

//transforms a bit of water into rock in the same voxel, for demo purpose

float sum_soil_water = terrain.y + terrain.z;
float new_water = terrain.z * 0.99;//1% of water removed
float new_soil = sum_soil_water - new_water;//ensure total matter conservation

vec3 new_terrain = vec3(terrain.x,new_soil,new_water);


uvec3 new_terrain_quantized = clamp(uvec3(new_terrain*FRACTION_QUANTIZER),0u,FRACTION_QUANTIZER);
imageStore(tex_terrain_write,voxel_coord,uvec4(new_terrain_quantized,0));

}