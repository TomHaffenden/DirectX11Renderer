struct VS_OUTPUT
{
	float4 Pos : SV_POSITION;
	float2 TexCoord : UV;
};

cbuffer RarelyCB : register (b0)
{
	float ScreenWidth;
	float ScreenHeight;
	float2 padding;
}

SamplerState sampler1
{
	Filter = ANISOTROPIC;
	MaxAnisotropy = 8;
};

Texture2D screenOutput : register(t0);
Texture2D screenOutput2 : register(t1);

//--------------------------------------------------------------------------------------
// Vertex Shader
//--------------------------------------------------------------------------------------
VS_OUTPUT VS_POSTPROCESSING(float4 Pos : POSITION, float2 TexCoord : UV)
{
	VS_OUTPUT output = (VS_OUTPUT)0;

	output.Pos = Pos;
	output.TexCoord = TexCoord;

	return output;
}

static const float weights[] = { 0.01f, 0.05f, 0.1f, 0.2f, 0.5f, 0.2f, 0.1f, 0.05f, 0.01f };

float4 PS_VERTICALBLUR(VS_OUTPUT input) : SV_Target
{
	static const float pixelOffsetY = 1.0f / (ScreenHeight / 4.0f);

	float4 result = 0;

	for (int i = 0; i < 9; i++)
	{
		float4 temp = screenOutput.Sample(sampler1, float2(input.TexCoord.x, input.TexCoord.y + (pixelOffsetY * (i - 4))));
		result += temp * weights[i];
	}

	result = clamp(result, 0.0, 1.0f);
	return float4(result.xyz, 1.0f);
}

float4 PS_HORIZONTALBLUR(VS_OUTPUT input) : SV_Target
{
	static const float pixelOffsetX = 1.0f / (ScreenWidth / 4.0f);

	float4 result = 0;

	for (int i = 0; i < 9; i++)
	{
		float4 temp = screenOutput.Sample(sampler1, float2(input.TexCoord.x + (pixelOffsetX * (i - 4)), input.TexCoord.y));
		result += temp * weights[i];
	}

	result = clamp(result, 0.0, 1.0f);
	return float4(result.xyz, 1.0f);
}

float4 PS_DOWNSAMPLE(VS_OUTPUT input) : SV_Target
{
	return screenOutput.Sample(sampler1, input.TexCoord*2.0f);
}

float4 PS_SAMPLE(VS_OUTPUT input) : SV_Target
{
	return screenOutput.Sample(sampler1, input.TexCoord);
}

float4 PS_BRIGHTPASS(VS_OUTPUT input) : SV_Target
{
	float3 result = screenOutput.Sample(sampler1, input.TexCoord);

	result *= 0.18f / (0.08f + 0.001f);

	result *= (1.0f + (result / (0.8f * 0.8f)));

	result -= 5.0f;

	result = max(result, 0.0f);

	result /= (10.0f + result);

	return float4(result, 1.0f);
}

float4 PS_COMBINE(VS_OUTPUT input) : SV_Target
{

	float4 result =  screenOutput.Sample(sampler1, input.TexCoord/2.0f);
	result += screenOutput2.Sample(sampler1, input.TexCoord);

	return saturate(result);
}