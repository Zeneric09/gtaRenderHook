#include "GameMath.hlsl"
#include "LightingFunctions.hlsl"
#include "GBuffer.hlsl"
#include "VoxelizingHelper.hlsl"
#include "AtmosphericScatteringFunctions.hlsli"
//--------------------------------------------------------------------------------------
// Constant Buffer Variables
//--------------------------------------------------------------------------------------
Texture2D txDiffuse : register( t0 );
Texture2D txSpec 	: register( t1 );
SamplerState samLinear : register(s0);
Texture2D txShadow 	: register(t4);

struct VS_INPUT
{
    float3 vPosition   	: POSITION;
    float2 vTexCoord    : TEXCOORD;
    float3 vInNormal    : NORMAL;
	float4 vInColor 	: COLOR;
};
struct GS_VOXEL_IN
{
	float4 vPosition		: SV_POSITION;    // World position
	float4 vNormal			: NORMAL;
	float4 vColor			: COLOR;
	float2 vTexCoord		: TEXCOORD0;         // Texture coord
};
struct PS_VOXEL_INPUT
{
	float4 vPosition	: SV_POSITION;
	float4 vWorldPos	: WPOS;
	float4 vNormal		: NORMAL;
	float4 vColor		: COLOR;
	float2 vTexCoord	: TEXCOORD0;
};
struct PS_DEFERRED_DN_IN
{
    float4 vPosition    : SV_POSITION;
    float4 vColor       : COLOR;
    float4 vNormalDepth : NORMAL;
    float4 vTexCoord    : TEXCOORD0;
    float4 vWorldPos    : TEXCOORD1;
};
//--------------------------------------------------------------------------------------
// Vertex Shader
//--------------------------------------------------------------------------------------
PS_DEFERRED_DN_IN VS(VS_INPUT i)
{
    PS_DEFERRED_DN_IN o;
	float4 	outPos 		= float4( i.vPosition,1.0);// transform to screen space
			outPos 		= mul( outPos, mWorld );
    o.vWorldPos = outPos;
			outPos		= mul( outPos, mView );
    o.vPosition 	    = mul( outPos, mProjection );
    o.vNormalDepth  = float4(mul((float3x3) mWorldInv, i.vInNormal), outPos.z);
	o.vTexCoord     = float4(i.vTexCoord, 0, 0);
	o.vColor		= i.vInColor;
	
    return o;
}
GS_VOXEL_IN VoxelVS(VS_INPUT i)
{
	GS_VOXEL_IN Out = (GS_VOXEL_IN)0.0f;

	Out.vPosition = mul(float4(i.vPosition, 1.0), mWorld);
	Out.vTexCoord = i.vTexCoord;
	Out.vNormal = float4(mul(i.vInNormal, (float3x3)mWorld), 1.0);
	Out.vColor = i.vInColor;
	return Out;
}
[maxvertexcount(18)]
void VoxelGS(triangle GS_VOXEL_IN input[3], inout TriangleStream<PS_VOXEL_INPUT> VoxelStream)
{
	for (int f = 0; f < 6; ++f)
	{
		// Compute screen coordinates
		PS_VOXEL_INPUT output;
		for (int v = 0; v < 3; v++)
		{
			output.vWorldPos = input[v].vPosition;
			output.vNormal = input[v].vNormal;
			output.vColor = input[v].vColor;
			output.vPosition = mul(input[v].vPosition, VoxelView[f]);
			output.vPosition = mul(output.vPosition, mProjection);
			output.vTexCoord = input[v].vTexCoord;
			VoxelStream.Append(output);
		}
		VoxelStream.RestartStrip();
	}
}

//--------------------------------------------------------------------------------------
// Pixel Shader
//--------------------------------------------------------------------------------------
float4 PS(PS_DEFERRED_DN_IN i) : SV_Target
{
    const float3 ViewPos = mViewInv[3].xyz;
    float3 WorldPos = i.vWorldPos.xyz;
    float3 Normals = (i.vNormalDepth.xyz * 0.5f + 0.5f) * 2.0f - 1.0f;
    Normals.z = sqrt(1.01 - dot(Normals.xy, Normals.xy));
    Normals = normalize(Normals);
    float3 LightDir = normalize(vSunLightDir.xyz);
    float3 ViewDir = normalize(WorldPos.xyz - ViewPos);
	float4 outColor =txDiffuse.Sample( samLinear, i.vTexCoord.xy ) * cDiffuseColor;
    outColor.xyz *= i.vColor.xyz;
	outColor.a		*=i.vColor.w;
    float3 FullScattering;
    outColor.rgb = CalculateFogColor(outColor.rgb, ViewDir, LightDir, i.vNormalDepth.w, WorldPos.z, FullScattering);
    DO_ALPHA_TEST(outColor.w)
	return outColor;
}

void ShadowPS(PS_DEFERRED_IN i)
{
	float4 outColor = txDiffuse.Sample(samLinear, i.vTexCoord.xy);
    outColor.a = outColor.a > 0.95f ? outColor.a : InterleavedGradientNoise(i.vPosition.xy) * outColor.a;
	if (outColor.a < 0.2f)
		discard;
}

PS_DEFERRED_OUT DeferredPS(PS_DEFERRED_IN i)
{
    PS_DEFERRED_OUT Out;
    float4 baseColor = cDiffuseColor;
    if (bHasTexture != 0)
        baseColor *= txDiffuse.Sample(samLinear, i.vTexCoord.xy);
    
    float4 params = bHasSpecTex > 0 ? float4(txSpec.Sample(samLinear, i.vTexCoord.xy).xyz, 3) : float4(fSpecularIntensity, fGlossiness, 0, 3);
    params.w = baseColor.a > 0.95f ? 3 : 5;
    baseColor.a = baseColor.a > 0.95f ? baseColor.a : InterleavedGradientNoise(i.vPosition.xy) * baseColor.a;
    
	if (baseColor.a < 0.2f)
		discard;
    FillGBufferVertexRadiance(Out, baseColor, -i.vNormalDepth.xyz, i.vNormalDepth.w, params, i.vColor);
	return Out;
}

void VoxelPS(PS_VOXEL_INPUT i)
{
	float4 outColor = txDiffuse.Sample(samLinear, i.vTexCoord)* cDiffuseColor;
	float DiffuseTerm;
	CalculateDiffuseTerm(-i.vNormal.xyz, vSunLightDir.xyz, DiffuseTerm, 0.5f);

	int3 gPos = (int3) ConvertToVoxelSpace(i.vWorldPos.xyz);

	if (gPos.x > 0 && gPos.x < voxelGridSize && gPos.y > 0 && gPos.y < voxelGridSize && gPos.z > 0 && gPos.z < voxelGridSize) {
        float4 color = float4(outColor.xyz * outColor.w * max(DiffuseTerm, 1 - vSunLightDir.w), outColor.w);
        InjectColorAndNormal(gPos, color, -i.vNormal.xyz);
    }
}
void VoxelEmmissivePS(PS_VOXEL_INPUT i)
{
	float4 outColor = txDiffuse.Sample(samLinear, i.vTexCoord)* cDiffuseColor;
	float DiffuseTerm;
	CalculateDiffuseTerm(i.vNormal.xyz, vSunLightDir.xyz, DiffuseTerm, 0.5f);

	int3 gPos = (int3) ConvertToVoxelSpace(i.vWorldPos.xyz);

	if (gPos.x > 0 && gPos.x < voxelGridSize && gPos.y > 0 && gPos.y < voxelGridSize && gPos.z > 0 && gPos.z < voxelGridSize) {
        float4 color = float4(outColor.xyz * outColor.w * i.vColor.xyz * 4, outColor.w);
        InjectColorAndNormal(gPos, color, -i.vNormal.xyz);
	}
}