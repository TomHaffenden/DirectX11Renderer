

cbuffer PerFrameCB : register(b1)
{
	matrix ViewProjection;
}

cbuffer PerObjectCB : register(b2)
{
	matrix World;
}

SamplerState sampler1;

TextureCube cubeMap : register(t3);

struct VS_OUTPUT
{
	float4 PosH : SV_POSITION;
	float3 PosL : POSITION;
};

VS_OUTPUT VS(float3 Pos : POSITION)
{
	VS_OUTPUT output = (VS_OUTPUT)0;

	output.PosH = mul(Pos, ViewProjection).xyww;
	output.PosL = Pos;

	return output;
}

float4 PS(VS_OUTPUT input) : SV_TARGET
{
	float4 colour = cubeMap.Sample(sampler1, input.PosL);
	return colour;// *float4(0.1, 0.2, 0.4, 1.0f);
}