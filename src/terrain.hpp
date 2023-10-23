#ifndef TERRAIN_CLASS
#define TERRAIN_CLASS

#include"buffer_structures.hpp"
#include "helpers/helpers_common.hpp"
#include <GLFW/glfw3.h>


#define WORK_GROUP3D_SIZE uvec3(4,4,4);// 4x4x4 = 64 threads
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

	//Ressources Texture3D
	Texture3D tex_material_id;//to define (0 = empty, 1 = rock .... ???)

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

