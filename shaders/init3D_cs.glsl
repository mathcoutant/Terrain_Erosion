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

vec2 hash21(float p);
float fbm(vec2 uv,int octaves);

float set_height(vec2 xz)//y axis 
{
    float factor = 3.0;
    float y = fbm((xz+1000.0*hash21(200.0+2.3*float(floatBitsToUint(params.y))))/factor,8)*0.5;//random terrain
    //y += 8.0*smoothstep(0.0,20.0,abs(xz.x - 5.0)-15.0);
    //y += 24.0*smoothstep(0.0,30.0,abs(xz.y)-25.0);
    return y;
}


void main() {
ivec3 voxel_coord = ivec3(gl_GlobalInvocationID.xyz);

if (voxel_coord.x>=dimension.x || voxel_coord.y>=dimension.y || voxel_coord.z>=dimension.z)
    return;//abort invocation if voxel out from texture3D

vec3 n_coords = vec3(voxel_coord)/float(dimension.y);


vec3 value = vec3(0.0);

value.z = n_coords.y<0.25?1.0:0.0;
float height_rock = clamp(set_height(20.0*n_coords.xz),0.0,0.96);

if (n_coords.y<=height_rock)
{
value.y = 1.0;
value.z = 0.0;
}
//vec3(voxel_coord)/vec3(dimension.xyz);


value.x = 1.0 - value.y - value.z;
uvec3 new_terrain_quantized = clamp(uvec3(value*FRACTION_QUANTIZER),0u,FRACTION_QUANTIZER);
imageStore(tex_terrain_read,voxel_coord,uvec4(new_terrain_quantized,0));
imageStore(tex_terrain_write,voxel_coord,uvec4(new_terrain_quantized,0));
}

///////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////
vec2 hash21(float p)
{
    vec3 p3 = fract(vec3(p) * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx+p3.yz)*p3.zy);
}
mat2 rotate2D(float r) {
    return mat2(cos(r), sin(r), -sin(r), cos(r));
}
vec2 triwave(vec2 uv){
    return
        abs(fract(uv)-.5);
}
float fbm(vec2 uv,int octaves)
{
    //this function generates the terrain height
    float value = 0.,
    value1=value,
    amplitude = 1.5;
    uv /= 16.;
    vec2 t1 = vec2(0.);
    vec2 warp = vec2(0.);
    
    mat2 r = rotate2D(13.);
    vec2 uv1 = uv;
    for (int i = 0; i < octaves; i++)
    {
        t1 *= rotate2D(abs(t1.x+t1.y));
        t1= triwave(uv-triwave(uv1*r/2.15))-t1.yx;
        value1=sqrt(value1*value1+value*value+0.00001);
        value = (abs(t1.x-t1.y) * amplitude-value);
        amplitude /= 2.15;
        uv1 = uv;
        uv = (uv.yx*2.15 + t1)*r;
    }
    
    return value1;
}