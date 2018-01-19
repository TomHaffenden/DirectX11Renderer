//--------------------------------------------------------------------------------------
// File: ObjectShader.fx
//
// Copyright (c) Microsoft Corporation. All rights reserved.
//--------------------------------------------------------------------------------------

struct Fresnel
{
	float bias;
	float scale;
	float power;
	float padding;
	float3 colour;
	float padding2;
};

struct Material
{
	Fresnel fresnel;
	float4 ambient;
	float4 diffuse;
	float3 specular;
	float shininess;
};

struct DirectionalLight
{
	float4 position;
	float4 ambient;
	float4 diffuse;
	float4 specular;
};

/*struct PointLight
{
	float4 position;
	float3 ambient;
	float constant;
	float3 diffuse;
	float Linear;
	float3 specular;
	float quadratic;
};*/

struct Light
{
	float4 position;
	float3 ambient;
	float range;
	float3 diffuse;
	float Linear;
	float3 specular;
	float quadratic;
	float3 direction;
	float cone;
};

struct LightOutput
{
	float3 ambient;
	float3 diffuse;
	float3 specular;
};

//--------------------------------------------------------------------------------------
// Constant Buffer Variables
//--------------------------------------------------------------------------------------

#define NUM_LIGHTS 20

cbuffer RarelyCB : register ( b0 )
{
	float ScreenWidth;
	float ScreenHeight;
	float2 padding2;
}

cbuffer PerFrameCB : register( b1 )
{
	matrix ViewProjection;
	DirectionalLight dirLight;
	Light lights[NUM_LIGHTS];
	float3 ViewPos;
	float padding;
}

cbuffer PerObjectCB : register ( b2 )
{
	matrix World;
	Material material;
	float TextureScale;
	float bDiffuseTexture;
	float bSpecularTexture;
	float bNormalMapTexture;
}

SamplerState sampler1;


Texture2D diffuseMap : register(t0);

Texture2D specularMap : register(t1);

Texture2D normalMap : register(t2);

TextureCube cubeMap : register(t3);

//--------------------------------------------------------------------------------------
struct VS_OUTPUT
{
	float4 Pos : SV_POSITION;
	float4 WorldPos : POSITION;
	float2 TexCoord : UV;
	float4 Normal : NORMALH;
	float4 WorldNormal : NORMALW;
	float4 WorldTangent : TANGENTW;
};

//--------------------------------------------------------------------------------------
// Vertex Shader
//--------------------------------------------------------------------------------------
VS_OUTPUT VS( float3 Pos : POSITION, float2 TexCoord : UV, float3 Normal : NORMAL, float4 Tangent : TANGENT )
{
    VS_OUTPUT output = (VS_OUTPUT)0;

	output.WorldPos = mul(float4(Pos.xyz, 1.0f), World);
	output.Pos = mul(output.WorldPos, ViewProjection);

	output.TexCoord = TexCoord * TextureScale;

	output.Normal = normalize(float4(Normal, 0.0f));

	output.WorldNormal = normalize(mul(output.Normal, World));

	output.WorldTangent = float4(mul(float4(Tangent.xyz, 0.0f), World).xyz, Tangent.w);
	
    return output;
}


//--------------------------------------------------------------------------------------
// Pixel Shader
//--------------------------------------------------------------------------------------
float3 NormalSampleToWorldSpace(float3 normalMapSample, float3 NormalW, float4 TangentW)
{
	float3 NormalT = 2.0f*normalMapSample - 1.0f;
	float3 N = NormalW;
	float3 T = normalize(TangentW.xyz - dot(TangentW.xyz, N) *N);
	float3 B = cross(N, T) *TangentW.w;

	float3x3 TBN = float3x3(T, B, N);

	float3 bumpedNormalW = mul(NormalT, TBN);

	return normalize(bumpedNormalW);
}

void CalculateDirectionalLight(float3 normal, float3 viewDirection, inout LightOutput output)
{
	float3 lightDirection = normalize(dirLight.position.xyz);

	float diff = clamp(dot(normal, lightDirection), 0.0, 1.0);

	float3 reflectDirection = reflect(-lightDirection, normal);

	float spec = pow(max(dot(viewDirection, reflectDirection), 0.0), material.shininess);

	float3 ambient = dirLight.ambient.xyz * material.ambient.xyz;
	float3 diffuse = dirLight.diffuse.xyz * diff * material.diffuse.xyz;
	float3 specular = dirLight.specular.xyz * spec * material.specular.xyz;

	output.ambient += ambient;
	output.diffuse += diffuse;
	output.specular += specular;

	return;
}

/*void CalculatePointLight(PointLight light, float3 normal, float3 viewDirection, float3 worldPos, inout LightOutput output)
{
	float3 lightDirection = normalize(light.position.xyz - worldPos);

	float diff = clamp(dot(normal, lightDirection), 0.0, 1.0);

	float3 reflectDirection = reflect(-lightDirection, normal);

	float spec = pow(max(dot(viewDirection, reflectDirection), 0.0), material.shininess);

	float distance = length(light.position.xyz - worldPos);
	float attenuation = 1.0f / (light.constant + light.Linear * distance + light.quadratic * (distance * distance));

	float3 ambient = light.ambient.xyz * material.ambient.xyz;
	float3 diffuse = light.diffuse.xyz * diff * material.diffuse.xyz;
	float3 specular = light.specular.xyz * spec * material.specular.xyz;
	ambient *= attenuation;
	diffuse *= attenuation;
	specular *= attenuation;

	output.ambient += max(ambient, 0.0f);
	output.diffuse += max(diffuse, 0.0f);
	output.specular += max(specular, 0.0f);

	return;
}*/

void CalculateLight(Light light, float3 normal, float3 viewDirection, float3 worldPos, inout LightOutput output)
{
	float3 lightDirection = light.position.xyz - worldPos;
	float distance = length(lightDirection);

	if (distance >= light.range) return;

	lightDirection = normalize(lightDirection);

	float diff = clamp(dot(normal, lightDirection), 0.0, 1.0);

	float3 reflectDirection = reflect(-lightDirection, normal);

	float spec = pow(max(dot(reflectDirection, viewDirection), 0.0), material.shininess);

	float spot = pow(max(dot(-lightDirection, normalize(light.direction)), 0.000001f), light.cone);

	float attenuation = spot / (1.0f + (light.Linear * abs(distance)) + light.quadratic * (distance * distance));

	float3 ambient = light.ambient.xyz * material.ambient.xyz;
	float3 diffuse = light.diffuse.xyz * diff * material.diffuse.xyz;
	float3 specular = light.specular.xyz * spec * material.specular.xyz;

	ambient *= attenuation;
	diffuse *= attenuation;
	specular *= attenuation;

	output.ambient += max(ambient, 0.0f);
	output.diffuse += max(diffuse, 0.0f);
	output.specular += max(specular, 0.0f);

	return;
}

float4 PS( VS_OUTPUT input ) : SV_Target
{
	float3 viewDirection = normalize(ViewPos - input.WorldPos.xyz);

	float4 diffuseColour;
	if (bDiffuseTexture == 1)
	{
		diffuseColour = diffuseMap.Sample(sampler1, input.TexCoord);
	}
	else
	{
		diffuseColour = material.diffuse;
	}
	
	clip(diffuseColour.a - 0.9);

	float3 Normal = normalize(input.WorldNormal.xyz);

	if (bNormalMapTexture == 1) {
		float3 normalMapSample = normalMap.Sample(sampler1, input.TexCoord).rgb;
		Normal = NormalSampleToWorldSpace(normalMapSample, Normal, input.WorldTangent);
	}

	LightOutput output = (LightOutput)0;

	CalculateDirectionalLight(Normal, viewDirection, output);

	for (int i = 0; i < NUM_LIGHTS; i++)
	{
		CalculateLight(lights[i], Normal, viewDirection, input.WorldPos.xyz, output);
	}

	float3 result = { 0.0f, 0.0f, 0.0f };

	result += (output.ambient + output.diffuse);

	result *= diffuseColour;

	float3 specular = output.specular;
	if (bSpecularTexture == 1)
	{
		specular *= specularMap.Sample(sampler1, input.TexCoord).rgb;
	}

	result = clamp(result + specular, 0.0, 1.0);

	float R = material.fresnel.bias + material.fresnel.scale * pow(1.0 + dot(-viewDirection, Normal), material.fresnel.power);

	result = lerp(result, material.fresnel.colour, R);

	result += cubeMap.Sample(sampler1, reflect(-viewDirection, Normal)) * max((material.diffuse - 1.0f), 0.0f);

	return float4(result, 1.0f);
}