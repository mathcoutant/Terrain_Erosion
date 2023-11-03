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

//Random functions for the rain cycle
uint seed = 42u; // Initial seed value

uint random() {
    seed ^= (seed << 13);
    seed ^= (seed >> 17);
    seed ^= (seed << 5);
    return seed;
}

float randomInRange(float min, float max) {
    float zeroToOne = float(random()) / float(0xFFFFFFFFu);
    return mix(min, max, zeroToOne);
}

float randomFromOneToTen() {
    return randomInRange(1.0, 11.0);
}

bool isOnSurface(ivec3 voxel_coord) {
    vec3 upperVoxel = vec3(imageLoad(tex_terrain_read,voxel_coord + ivec3(0,1,0)).xyz) * FRACTION_DIVIDER;
    if (upperVoxel.x > max(upperVoxel.y,upperVoxel.z))
        return true;
    return false;
}

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

    //Rain
    if (randomFromOneToTen() > 9){
        float rain_drop = water_counter.x / (dimension.x * dimension.z);
        if(water_counter.x>rain_drop){
            terrain.x -= rain_drop*FRACTION_DIVIDER;
            if(terrain.x < 0) terrain.x=0;
            terrain.z += rain_drop*FRACTION_DIVIDER;
            atomicAdd(water_counter.x, uint(-rain_drop));
        }
    }
    
    //Calculate the amount of water that will flow to lower voxels
    float waterLost = 0;
    float soilLost = 0;
    if (terrain.z > 0) {
        for (int x_=voxel_coord.x -1; x_<voxel_coord.x +2; x_++){
            for(int z_=voxel_coord.z -1; z_<voxel_coord.z +2; z_++){
                if(x_!=voxel_coord.x || z_!=voxel_coord.z){
                    ivec3 neighbour_coord = voxel_coord + ivec3(x_,-1,z_);
                    if (neighbour_coord.x>=dimension.x || neighbour_coord.x==0 || neighbour_coord.y>=dimension.y || neighbour_coord.y==0 || neighbour_coord.z>=dimension.z || neighbour_coord.z==0)
                        break;//abort invocation if voxel out from texture3D
                    if (isOnSurface(neighbour_coord)) {
                        vec3 neighbour = vec3(imageLoad(tex_terrain_read,neighbour_coord).xyz) * FRACTION_DIVIDER;
                        if (neighbour.z < 1){ //Maybe to delete
                            waterLost += terrain.z/8;
                        }
                        if (terrain.y > 0){
                            soilLost += terrain.z/8 * 0.05;
                        }
                    }
                }
            }
        }
    }

    //Calculate the amount of water that will come from upper voxels
    float waterGained = 0;
    float soilGained = 0;
    if(terrain.z < 1) {//Maybe to delete
        for (int x_=voxel_coord.x -1; x_<voxel_coord.x+2; x_++){
            for(int z_=voxel_coord.z -1; z_<voxel_coord.z+2; z_++){
                if(x_!=voxel_coord.x || z_!=voxel_coord.z){
                    ivec3 neighbour_coord = voxel_coord + ivec3(x_,1,z_);
                    if (neighbour_coord.x>=dimension.x || neighbour_coord.x==0 || neighbour_coord.y>=dimension.y || neighbour_coord.y==0 || neighbour_coord.z>=dimension.z || neighbour_coord.z==0)
                        break;//abort invocation if voxel out from texture3D
                    if (isOnSurface(neighbour_coord)) {
                        vec3 neighbour = vec3(imageLoad(tex_terrain_read,neighbour_coord).xyz) * FRACTION_DIVIDER;
                        if(neighbour.z > 0) {
                            waterGained += neighbour.z/8;
                        }
                        if(neighbour.y > 0) {
                            soilGained += neighbour.z/8 * 0.05;
                        }
                    }
                }
            }
        }
    }

    //Update the voxel 
    terrain.z -= waterLost;
    terrain.y -= soilLost;
    if(terrain.y<0) terrain.y = 0;
    terrain.x += waterLost + soilLost;
    if(terrain.x>1) terrain.x = 1;
    
    terrain.z += waterGained;
    terrain.y += soilGained;
    terrain.x -= waterGained + soilGained;
    if(terrain.x<0) terrain.x = 0;

//    //if terrain is water 
//    if (terrain.z>max(terrain.x,terrain.y)){
//        //gives 5% of water to the soils around
//        for (int x_ = voxel_coord.x -1;x_<voxel_coord.x +2;x_++){
//            for(int z_= voxel_coord.z -1;z_<voxel_coord.z +2;z_++){
//                if(x_ !=voxel_coord.x || z_ !=voxel_coord.z){
//                    ivec3 neighbour_coord = voxel_coord + ivec3(x_,0,z_);
//                    if (neighbour_coord.x>=dimension.x || neighbour_coord.x==0 || neighbour_coord.y>=dimension.y || neighbour_coord.y==0 || neighbour_coord.z>=dimension.z || neighbour_coord.z==0)
//                        break;//abort invocation if voxel out from texture3D
//                    vec3 neighbour = vec3(imageLoad(tex_terrain_read,neighbour_coord).xyz) * FRACTION_DIVIDER;
//                    if (neighbour.y>max(neighbour.x,neighbour.z)){
//                        terrain.z-=0.05;
//                        terrain.x+=0.05;
//                    }
//                }
//            }
//        }
//    }
//
//    //Water flows
//    if (terrain.z>max(terrain.x,terrain.y)){  //if terrain is water
//        int empty_cubes=0; //count the number of empty cubes around
//        for (int x_ = voxel_coord.x -1;x_<voxel_coord.x +2;x_++){
//            for(int z_= voxel_coord.z -1;z_<voxel_coord.z +2;z_++){
//                if(x_ !=voxel_coord.x || z_ !=voxel_coord.z){
//                    ivec3 neighbour_coord = voxel_coord + ivec3(x_,0,z_);
//                    if (neighbour_coord.x>=dimension.x || neighbour_coord.x==0 || neighbour_coord.y>=dimension.y || neighbour_coord.y==0 || neighbour_coord.z>=dimension.z || neighbour_coord.z==0)
//                        break;//abort invocation if voxel out from texture3D
//                    vec3 neighbour = vec3(imageLoad(tex_terrain_read,neighbour_coord).xyz) * FRACTION_DIVIDER;
//                    if (neighbour.x>max(neighbour.y,neighbour.z)){
//                        empty_cubes+=1;
//                    }
//                }
//            }
//        }
//        float amount_water=terrain.z/empty_cubes;
//
//        for (int x_ = voxel_coord.x -1;x_<voxel_coord.x +2;x_++){
//            for(int z_= voxel_coord.z -1;z_<voxel_coord.z +2;z_++){
//                if(x_ !=voxel_coord.x || z_ !=voxel_coord.z){
//                    ivec3 neighbour_coord = voxel_coord + ivec3(x_,0,z_);
//                    if (neighbour_coord.x>=dimension.x || neighbour_coord.x<0 || neighbour_coord.y>=dimension.y || neighbour_coord.y<0 || neighbour_coord.z>=dimension.z || neighbour_coord.z<0)
//                        break;//abort invocation if voxel out from texture3D
//                    vec3 neighbour = vec3(imageLoad(tex_terrain_read,neighbour_coord).xyz) * FRACTION_DIVIDER;
//                    if (neighbour.x>max(neighbour.y,neighbour.z)){
//                        neighbour.z += amount_water;
//                        neighbour.x-=amount_water;
//                    }
//                }
//            }
//        }
//        terrain.z -=amount_water;
//    }
//    
//    //if terrain is soil 
//    //GET 5% of water from water cubes and lose 5% of soil
//    if (terrain.y>max(terrain.x,terrain.z)){
//        for (int x_ = voxel_coord.x -1;x_<voxel_coord.x +2;x_++){
//            for(int z_= voxel_coord.z -1;z_<voxel_coord.z +2;z_++){
//                if(x_ !=voxel_coord.x || z_ !=voxel_coord.z){
//                    ivec3 neighbour_coord = voxel_coord + ivec3(x_,0,z_);
//                    if (neighbour_coord.x>=dimension.x || neighbour_coord.x==0 || neighbour_coord.y>=dimension.y || neighbour_coord.y==0 || neighbour_coord.z>=dimension.z || neighbour_coord.z==0)
//                        break;//abort invocation if voxel out from texture3D
//                    vec3 neighbour = vec3(imageLoad(tex_terrain_read,neighbour_coord).xyz) * FRACTION_DIVIDER;
//                    if (neighbour.z>max(neighbour.y,neighbour.x)){
//                        terrain.y-=0.05;
//                        terrain.z+=0.05;
//                    }
//                }
//            }
//        }
//    }


    //Evaporation of 5% of water voxels
    if (terrain.z>max(terrain.x,terrain.y)) {
        float water_evaporated = terrain.z*0.05;
        terrain.z -= water_evaporated;
        terrain.x += water_evaporated;
        atomicAdd(water_counter.x, uint(water_evaporated*FRACTION_QUANTIZER));
    }

    

    //transforms a bit of water into rock in the same voxel, for demo purpose
    //float sum_soil_water = terrain.y + terrain.z;
    //float new_water = terrain.z * 0.99;//1% of water removed
    //float new_soil = sum_soil_water - new_water;//ensure total matter conservation

    uvec3 new_terrain_quantized = clamp(uvec3(terrain*FRACTION_QUANTIZER),0u,FRACTION_QUANTIZER);
    imageStore(tex_terrain_write,voxel_coord,uvec4(new_terrain_quantized,0));

}