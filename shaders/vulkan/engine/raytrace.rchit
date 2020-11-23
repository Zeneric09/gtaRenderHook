#version 460
#extension GL_NV_ray_tracing : require
#extension GL_EXT_scalar_block_layout : require
#extension GL_EXT_shader_16bit_storage : require
#extension GL_EXT_nonuniform_qualifier : enable
#extension GL_GOOGLE_include_directive : enable
#include "raycommon.glsl"

layout(location = 0) rayPayloadInNV hitPayload prd;
layout(location = 1) rayPayloadInNV bool inShadow;

hitAttributeNV vec3 attribs;

layout(binding = 0, set = 0) uniform accelerationStructureNV topLevelAS;
layout(binding = 1, set = 2, scalar) buffer ScnDesc
{
    sceneDesc i[];
}
scnDesc;

layout(binding = 2, set = 2, scalar) buffer Vertices { Vertex v[]; } vertices[];
layout(binding = 3, set = 2) buffer Indices { uint16_t i[]; } indices[];
layout(binding = 4, set = 2) uniform texture2D textures[];
layout(binding = 5, set = 2, scalar) buffer MatDesc
{
    MaterialDesc i[];
}
matDesc;
layout(binding = 6, set = 1) uniform sampler testSampler;

void main()
{
    int obj_id = scnDesc.i[gl_InstanceID].objId;
    // Indices of the triangle
    ivec3 ind = ivec3(indices[obj_id].i[3 * gl_PrimitiveID + 0], //
    indices[obj_id].i[3 * gl_PrimitiveID + 1], //
    indices[obj_id].i[3 * gl_PrimitiveID + 2]);//
    // Vertex of the triangle
    Vertex v0 = vertices[obj_id].v[ind.x];
    Vertex v1 = vertices[obj_id].v[ind.y];
    Vertex v2 = vertices[obj_id].v[ind.z];

    const vec3 barycentrics = vec3(1.0 - attribs.x - attribs.y, attribs.x, attribs.y);

    // Computing the normal at hit position
    vec3 normal = v0.normals.xyz * barycentrics.x + v1.normals.xyz * barycentrics.y + v2.normals.xyz * barycentrics.z;
    // Computing the coordinates of the hit position
    vec3 worldPos = v0.pos.xyz * barycentrics.x + v1.pos.xyz * barycentrics.y + v2.pos.xyz * barycentrics.z;
    // Transforming the position to world space
    worldPos = vec3(vec4(worldPos, 1.0) * scnDesc.i[gl_InstanceID].transfo);

    // Transforming the normal to world space
    normal = normalize(vec3(scnDesc.i[gl_InstanceID].transfoIT * vec4(normal, 0.0)));
    vec4 color = unpackUnorm4x8(v0.color) * barycentrics.x + unpackUnorm4x8(v1.color)  * barycentrics.y + unpackUnorm4x8(v2.color) * barycentrics.z;

    vec3 up = normalize(vec3(0, -100, 20));
    MaterialDesc material = matDesc.i[scnDesc.i[gl_InstanceID].txtOffset + v0.material];

    vec2 tc = v0.uv.xy * barycentrics.x + v1.uv.xy * barycentrics.y + v2.uv.xy * barycentrics.z;

    inShadow = true;
    /*if(dot(normal, up) > 0)
    {
        float tMin   = 0.001;
        float tMax   = 1000.0;
        vec3  origin = worldPos;
        vec3  rayDir = up;
        uint  flags =
            gl_RayFlagsSkipClosestHitShaderNV;
        traceNV(topLevelAS,  // acceleration structure
                flags,       // rayFlags
                0xFF,        // cullMask
                0,           // sbtRecordOffset
                0,           // sbtRecordStride
                1,           // missIndex
                origin,      // ray origin
                tMin,        // ray min range
                rayDir,      // ray direction
                tMax,        // ray max range
                1            // payload (location = 1)
        );
    }*/
    prd.normalDepth = vec4(normal, gl_HitTNV);
    if (material.spec_id > 0){
        vec4 spec_color = texture(sampler2D(textures[material.spec_id], testSampler), tc);
        vec3 origin = worldPos;
        vec3 rayDir = reflect(gl_WorldRayDirectionNV, normal);
        prd.attenuation *= spec_color.r;
        prd.done      = 0;
        prd.rayOrigin = origin;
        prd.rayDir    = rayDir;
        prd.materialParams = spec_color.rgb;
    }
    if (material.txd_id > 0) {
        vec4 tex_color = texture(sampler2D(textures[material.txd_id], testSampler), tc);
        prd.hitValue = tex_color.rgb;//* unpackUnorm4x8(material.color).xyz;
    }
    else
    prd.hitValue = vec3(unpackUnorm4x8(material.color).xyz);
}
