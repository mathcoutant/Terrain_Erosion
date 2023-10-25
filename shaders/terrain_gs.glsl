#version 460
#define UBO_APPLICATION_BINDING 0

layout(points) in;
layout(triangle_strip, max_vertices = 18) out;
//layout(binding = 0, r8ui) restrict readonly uniform uimage3D tex_material_id;

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

in uint material_id[]; 
out uint material_id_fs;

void main()
{
    vec3 pos = gl_in[0].gl_Position.xyz;
    vec3 v[8]; //les 8 sommets du cube
    vec2 s = 0.5*0.5*params.z*vec2(-1.0,1.0);//s.x = - 0.5*params.z;; s.y = 0.5*params.z;

    material_id_fs = material_id[0];
    v[0] = pos + s.xxx;
    v[2] = pos + s.yxy;
    v[3] = pos + s.xxy;
    v[1] = pos + s.yxx;
    v[4] = pos + s.xyx;
    v[5] = pos + s.yyx;
    v[6] = pos + s.yyy;
    v[7] = pos + s.xyy;
/* (Old code, to delete in next commit)
	v[0] = vec3(pos.x-params.z/2,pos.y-params.z/2,pos.z-params.z/2);
    v[2] = vec3(pos.x+params.z/2,pos.y-params.z/2,pos.z+params.z/2);
    v[3] = vec3(pos.x-params.z/2,pos.y-params.z/2,pos.z+params.z/2);
    v[1] = vec3(pos.x+params.z/2,pos.y-params.z/2,pos.z-params.z/2);
    v[4] = vec3(pos.x-params.z/2,pos.y+params.z/2,pos.z-params.z/2);
    v[5] = vec3(pos.x+params.z/2,pos.y+params.z/2,pos.z-params.z/2);
    v[6] = vec3(pos.x+params.z/2,pos.y+params.z/2,pos.z+params.z/2);
    v[7] = vec3(pos.x-params.z/2,pos.y+params.z/2,pos.z+params.z/2);
*/
    gl_Position = w_v_p*vec4(v[1],1.0);
    EmitVertex();
    gl_Position = w_v_p*vec4(v[0],1.0);
    EmitVertex();
    gl_Position = w_v_p*vec4(v[2],1.0);
    EmitVertex();
    gl_Position = w_v_p*vec4(v[3],1.0);
    EmitVertex();
    gl_Position = w_v_p*vec4(v[6],1.0);
    EmitVertex();
    gl_Position = w_v_p*vec4(v[7],1.0);
    EmitVertex();
    gl_Position = w_v_p*vec4(v[5],1.0);
    EmitVertex();
    gl_Position = w_v_p*vec4(v[4],1.0);
    EmitVertex();
    gl_Position = w_v_p*vec4(v[1],1.0);
    EmitVertex();
    gl_Position = w_v_p*vec4(v[0],1.0);
    EmitVertex();
    
    EndPrimitive();//end of generated "drawcall" to be rasterized

    gl_Position = w_v_p*vec4(v[2],1.0);
    EmitVertex();
    gl_Position = w_v_p*vec4(v[1],1.0);
    EmitVertex();
    gl_Position = w_v_p*vec4(v[6],1.0);
    EmitVertex();
    gl_Position = w_v_p*vec4(v[5],1.0);
    EmitVertex();
    EndPrimitive();

    gl_Position = w_v_p*vec4(v[4],1.0);
    EmitVertex();
    gl_Position = w_v_p*vec4(v[0],1.0);
    EmitVertex();
    gl_Position = w_v_p*vec4(v[7],1.0);
    EmitVertex();
    gl_Position = w_v_p*vec4(v[3],1.0);
    EmitVertex();
    EndPrimitive();
};