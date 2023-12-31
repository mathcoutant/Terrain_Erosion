#include "terrain.hpp"

Terrain::Terrain()
{
	m_dimension = uvec3(64u, 32u, 64u);
	m_shader_terrain_point = new ShaderGLSL("terrain_render_shader");
	m_shader_background = new ShaderGLSL("background_shader");
	m_compute3D_init = new ShaderGLSL("init_textures3D_shader");
	m_compute3D_erosion = new ShaderGLSL("erosion_shader");
	m_compute3D_copy = new ShaderGLSL("Copy_grid_shader");
	m_is_erosion_enabled = false;
	m_is_erosion_continuous = false;
	m_erosion_passes_per_frame = 1u;
	m_erosion_factor = 1.0f;
	m_terrain_seed = 0u;
	m_scale = 1.0f;
	m_tex_terrain[0].create_empty(m_dimension, {GL_RGBA16UI,GL_RGBA,GL_UNSIGNED_SHORT}, TEX3D_SLOT_TERRAIN_READ);
	m_tex_terrain[1].create_empty(m_dimension, { GL_RGBA16UI,GL_RGBA,GL_UNSIGNED_SHORT }, TEX3D_SLOT_TERRAIN_WRITE);
	m_water_counter.allocate(sizeof(glm::uvec4));
	m_water_counter.set_target_and_slot(GL_SHADER_STORAGE_BUFFER, SSBO_SLOT_WATER_COUNTER);


}

void Terrain::load_shaders(std::string base_path)
{
	m_shader_terrain_point->add_shader(GL_VERTEX_SHADER, base_path, "shaders/terrain_vs.glsl");
	m_shader_terrain_point->add_shader(GL_GEOMETRY_SHADER, base_path, "shaders/terrain_gs.glsl");
	m_shader_terrain_point->add_shader(GL_FRAGMENT_SHADER, base_path, "shaders/terrain_fs.glsl");
	m_shader_terrain_point->compile_and_link_to_program();
	ContextHelper::add_shader_to_hot_reload(m_shader_terrain_point);

	m_shader_background->add_shader(GL_VERTEX_SHADER, base_path, "shaders/background_vs.glsl");
	m_shader_background->add_shader(GL_FRAGMENT_SHADER, base_path, "shaders/background_fs.glsl");
	m_shader_background->compile_and_link_to_program();
	ContextHelper::add_shader_to_hot_reload(m_shader_background);

	m_compute3D_init->add_shader(GL_COMPUTE_SHADER, base_path, "shaders/init3D_cs.glsl");
	m_compute3D_init->compile_and_link_to_program();
	ContextHelper::add_shader_to_hot_reload(m_compute3D_init);

	m_compute3D_erosion->add_shader(GL_COMPUTE_SHADER, base_path, "shaders/erosion_cs.glsl");
	m_compute3D_erosion->compile_and_link_to_program();
	ContextHelper::add_shader_to_hot_reload(m_compute3D_erosion);

	m_compute3D_copy->add_shader(GL_COMPUTE_SHADER, base_path, "shaders/copy_terrain_cs.glsl");
	m_compute3D_copy->compile_and_link_to_program();
	ContextHelper::add_shader_to_hot_reload(m_compute3D_copy);
}

void Terrain::resize()
{
	m_voxel_count = m_dimension.x * m_dimension.y * m_dimension.z;
	m_workgroup_count = (m_dimension - uvec3(1u,1u,1u)) / WORK_GROUP3D_SIZE + uvec3(1u, 1u, 1u);

	std::cout << "Terrain new size: " << std::to_string(m_dimension.x) << " X " << std::to_string(m_dimension.y) << " X " << std::to_string(m_dimension.z) << " X " << std::endl;

	m_tex_terrain[0].re_create_empty(m_dimension);
	m_tex_terrain[1].re_create_empty(m_dimension);
	//Reset water counter
	glm::uvec4 zero = glm::uvec4(0u);
	m_water_counter.write_to_gpu(&zero);

	//Recreating binds images for access in compute shaders
	m_compute3D_init->use_shader_program();
	glDispatchCompute(m_workgroup_count.x, m_workgroup_count.y, m_workgroup_count.z);
	glFinish();
}

void Terrain::render()
{
	m_dummy_vao.use_vao();
	m_shader_terrain_point->use_shader_program();
	glDrawArrays(GL_POINTS, 0, m_voxel_count);
	glFinish();
	m_shader_background->use_shader_program();
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
	glFlush();
}

void Terrain::erode()
{ 
	if (m_is_erosion_enabled || m_is_erosion_continuous)
	{
		for (int i = 0; i < m_erosion_passes_per_frame; i++)
		{
			m_compute3D_erosion->use_shader_program();
			glDispatchCompute(m_workgroup_count.x, m_workgroup_count.y, m_workgroup_count.z);
			glFinish();
			//Maybe several shaders will be needed, but we ping-pong read/write at the end of a pass

			m_compute3D_copy->use_shader_program();
			glDispatchCompute(m_workgroup_count.x, m_workgroup_count.y, m_workgroup_count.z);
			glFinish();
		}
	}
}


void Terrain::write_params_to_application_struct(ApplicationUboDataStructure& app_ubo)
{
	app_ubo.dimension.x = m_dimension.x;
	app_ubo.dimension.y = m_dimension.y;
	app_ubo.dimension.z = m_dimension.z;
	app_ubo.dimension.w = m_voxel_count;

	app_ubo.params.x = m_erosion_factor;
	app_ubo.params.y = uintBitsToFloat(m_terrain_seed);
	app_ubo.params.z = m_scale;
	//app_ubo.params.w from UI
}

void Terrain::gui(ApplicationUboDataStructure& app_ubo)
{
	if (ImGui::TreeNode("Terrain"))
	{
			ImGui::SliderFloat("Scale", &(m_scale), 0.1f, 10.0f);
			int d = m_terrain_seed;
			ImGui::SliderInt("Seed", &(d), 0, 1000000);
			if (d != m_terrain_seed)
				resize();
			m_terrain_seed = d;

			ImGui::SliderFloat("Y cut", &(app_ubo.params.w), 0.0f, 1.0f);
			
			if (ImGui::Button("Re init"))
			{
				resize();
			}

			uvec3 old_dim = m_dimension;
			d = m_dimension.x;
			ImGui::SliderInt("Texture size X ", &(d), 1, 1000);
			m_dimension.x = d;
			d = m_dimension.y;
			ImGui::SliderInt("Texture size Y", &(d), 1, 1000);
			m_dimension.y = d;
			d = m_dimension.z;
			ImGui::SliderInt("Texture size Z", &(d), 1, 1000);
			m_dimension.z = d;

			//m_dimension = (m_dimension / uvec3(32)) * uvec3(32);

			if (old_dim != m_dimension)
				resize();

			d = m_erosion_passes_per_frame;
			ImGui::InputInt("Erosion passes", &(d), 1, 100);
			m_erosion_passes_per_frame = d;
			m_is_erosion_enabled = ImGui::Button("Erode");
			ImGui::SameLine();
			ImGui::Checkbox("Continuous Erosion", &m_is_erosion_continuous);

		ImGui::TreePop();
	}
	if (ImGui::TreeNode("Erosion"))
	{
		ImGui::SliderFloat("Erosion factor", &m_erosion_factor, 0.0f, 10.0f);
		ImGui::TreePop();
	}
}