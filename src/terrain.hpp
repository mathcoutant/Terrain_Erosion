#ifndef TERRAIN_CLASS
#define TERRAIN_CLASS

#include"buffer_structures.hpp"
#include "helpers/helpers_common.hpp"
#include <GLFW/glfw3.h>


#define WORK_GROUP3D_SIZE uvec3(4u,4u,4u)// 4x4x4 = 64 threads
class Terrain {

public:
	Terrain();
	void load_shaders(std::string base_path);

	void write_params_to_application_struct(ApplicationUboDataStructure& app_ubo);
	void resize();
	void erode();
	void render();

	void gui(ApplicationUboDataStructure& app_ubo);

private:
	ShaderGLSL *m_shader_terrain_point;
	ShaderGLSL *m_shader_background;

	//Compute shader
	ShaderGLSL* m_compute3D_init;
	ShaderGLSL* m_compute3D_erosion;
	ShaderGLSL* m_compute3D_copy;

	//Ressources Texture3D
	Texture3D m_tex_terrain[2];//RGBA16UI, 2 texture for ping-pong read/write
	//Each channel on 16 bits, as a uint: in [0, 2^16-1 = 65535], careful with overflow and substraction with uint !!!
	// .x: fraction_of_air * 60'000
	// .y: fraction_of_soil * 60'000
	// .z: fraction_of_water * 60'000
	// sum of .x, .y, .z should equal 60'000 at all time
	// .w: 16 bits field for padding, may be useful to encode neighborhood properties !

	GPUBuffer m_water_counter;// 1 uvec4, .x: stores water

	bool m_is_erosion_enabled;
	bool m_is_erosion_continuous;//erosion passes computed automatically each frame
	std::uint32_t m_erosion_passes_per_frame;//For

	float m_erosion_factor;//Abstract variable modelling how map is changed in 1 pass

	VertexArrayObject m_dummy_vao;//Dummy VAO to tessellation drawcall

	std::uint32_t m_terrain_seed;
	float m_scale;
	uvec3 m_dimension;//voxel resolution
	std::uint32_t m_voxel_count;// = m_dimension.x * m_dimension.y * m_dimension.z
	uvec3 m_workgroup_count;
};

#endif

