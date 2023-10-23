#ifndef BUFFER_STRUCTURES
#define BUFFER_STRUCTURES

#include <glm/glm.hpp>

#define uint uint32_t // for compatibility with GLSL
using namespace glm;

//structures for uniform buffers (UBOs) require proper 16 byte alignment (std140 layout)
//structures for shader storage buffers (SSBOs) require only 4 byte alignment (std430 layout)
//more at https://www.khronos.org/opengl/wiki/Interface_Block_(GLSL)#Memory_layout

//Texture channels ID:
#define TEXTURE3D_SLOT_MATERIALID 0
//...

//GLSL: layout(binding = 0, std140) uniform UBO_APPLICATION
#define UBO_APPLICATION_BINDING 0
struct ApplicationUboDataStructure
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

#endif

