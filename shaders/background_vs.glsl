#version 460
#define UBO_APPLICATION_BINDING 0
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

out vec3 dir_ws;
void main() 
{
	if(gl_VertexID==0)
	{
		vec4 v = vec4(-1.0,-1.0,0.0,1.0);
		vec4 v_ws = inv_w_v_p * v;
		v_ws/=v_ws.w;
		dir_ws = v_ws.xyz - cam_pos.xyz;
		gl_Position = v;
	}
	else if(gl_VertexID==1)
	{
		vec4 v = vec4(1.0,-1.0,0.0,1.0);
		vec4 v_ws = inv_w_v_p * v;
		v_ws/=v_ws.w;
		dir_ws = v_ws.xyz - cam_pos.xyz;
		gl_Position = v;
	}
	else if(gl_VertexID==2)
	{
		vec4 v = vec4(-1.0,1.0,0.0,1.0);
		vec4 v_ws = inv_w_v_p * v;
		v_ws/=v_ws.w;
		dir_ws = v_ws.xyz - cam_pos.xyz;
		gl_Position = v;
	}
	else //(gl_VertexID==3)
	{
		vec4 v = vec4(1.0,1.0,0.0,1.0);
		vec4 v_ws = inv_w_v_p * v;
		v_ws/=v_ws.w;
		dir_ws = v_ws.xyz - cam_pos.xyz;
		gl_Position = v;
	}
}

