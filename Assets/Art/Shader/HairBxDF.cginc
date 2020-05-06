struct SurfaceOutputHair
// Upgrade NOTE: excluded shader from DX11, OpenGL ES 2.0 because it uses unsized arrays
#pragma exclude_renderers d3d11 gles
{
	half3 Albedo;
	half3 Normal;//Tangent actually
	half3 VNormal;//vertext normal
	half Eccentric;
	half Alpha;
	half Roughness;
	half3 Emission;
	half Specular;
};

struct SurfaceOutputFur
// Upgrade NOTE: excluded shader from DX11, OpenGL ES 2.0 because it uses unsized arrays
#pragma exclude_renderers d3d11 gles
{
	half3 Albedo;
	half MedulaScatter;
	half MedulaAbsorb;
	half3 Normal;//Tangent actually
	half3 VNormal;//vertext normal
	half3 Emission;
	half Alpha;
	half Roughness;
	half Specular;
	half Layer;
	half Kappa;
};

#define PI 3.1415926

inline float square(float x) {
	return x * x;
}

float acosFast(float inX)
{
	float x = abs(inX);
	float res = -0.156583f * x + (0.5 * PI);
	res *= sqrt(1.0f - x);
	return (inX >= 0) ? res : PI - res;
}
/*
float asinFast(float x)
{
	return (0.5 * PI) - acosFast(x);
}

float Hair_F(float CosTheta)
{
	const float n = 1.55;
	const float F0 = square((1 - n) / (1 + n));
	return F0 + (1 - F0) * Pow5(1 - CosTheta);
}*/

#define SQRT2PI 2.50663

//Gaussian Distribution for M term
inline float Hair_G(float B, float Theta)
{
	return exp(-0.5 * square(Theta) / (B*B)) / (SQRT2PI * B);
}

float HairIOF(float Eccentric) {
	float n = 1.55;
	float a = 1 - Eccentric;
	float ior1 = 2 * (n - 1) * (a * a) - n + 2;
	float ior2 = 2 * (n - 1) / (a * a) - n + 2;
	return 0.5f * ((ior1 + ior2) + 0.5f * (ior1 - ior2)); //assume cos2PhiH = 0.5f 
}

inline float3 SpecularFresnel(float3 F0, float vDotH) {
	return F0 + (1.0f - F0) * pow(1 - vDotH, 5);
}

inline float3 SpecularFresnelLayer(float3 F0, float vDotH, float layer) {
	float3 fresnel = SpecularFresnel(F0,  vDotH);
    return (fresnel * layer) / (1 + (layer-1) * fresnel);
}

float3 HairDiffuseKajiyaUE(SurfaceOutputHair s, float3 L, float3 V, half3 N, half Shadow, float Backlit, float Area) {
	float3 S = 0;
	float KajiyaDiffuse = 1 - abs(dot(N, L));

	float3 FakeNormal = normalize(V - N * dot(V, N));
	N = FakeNormal;

	// Hack approximation for multiple scattering.
	float Wrap = 1;
	float NoL = saturate((dot(N, L) + Wrap) / square(1 + Wrap));
	float DiffuseScatter = (1 / PI) * lerp(NoL, KajiyaDiffuse, 0.33);// *s.Metallic;
	float Luma = Luminance(s.Albedo);
	float3 ScatterTint = pow(s.Albedo / Luma, 1 - Shadow);
	S = sqrt(s.Albedo) * DiffuseScatter * ScatterTint;
	return S;
}

float3 HairSpecularMarschner(SurfaceOutputHair s, float3 L, float3 V, half3 N, float Shadow, float Backlit, float Area)
{
	float3 S = 0;

	const float VoL = dot(V, L);
	const float SinThetaL = dot(N, L);
	const float SinThetaV = dot(N, V);
	float cosThetaL = sqrt(max(0, 1 - SinThetaL * SinThetaL));
	float cosThetaV = sqrt(max(0, 1 - SinThetaV * SinThetaV));
	float CosThetaD = sqrt((1 + cosThetaL * cosThetaV + SinThetaV * SinThetaL) / 2.0);

	const float3 Lp = L - SinThetaL * N;
	const float3 Vp = V - SinThetaV * N;
	const float CosPhi = dot(Lp, Vp) * rsqrt(dot(Lp, Lp) * dot(Vp, Vp) + 1e-4);
	const float CosHalfPhi = sqrt(saturate(0.5 + 0.5 * CosPhi));

	float n_prime = 1.19 / CosThetaD + 0.36 * CosThetaD;

	float Shift = 0.0499f;
	float Alpha[] =
	{
		-0.0998,//-Shift * 2,
		0.0499f,// Shift,
		0.1996  // Shift * 4
	};
	float B[] =
	{
		Area + square(s.Roughness),
		Area + square(s.Roughness) / 2,
		Area + square(s.Roughness) * 2
	};

	float hairIOF = HairIOF(s.Eccentric);
	float F0 = square((1 - hairIOF) / (1 + hairIOF));

	float3 Tp;
	float Mp, Np, Fp, a, h, f;
	float ThetaH = SinThetaL + SinThetaV;
	// R
	Mp = Hair_G(B[0], ThetaH - Alpha[0]);
	Np = 0.25 * CosHalfPhi;
	Fp = SpecularFresnel(F0, sqrt(saturate(0.5 + 0.5 * VoL)));
	S += (Mp * Np) * (Fp * lerp(1, Backlit, saturate(-VoL)));

	// TT
	Mp = Hair_G(B[1], ThetaH - Alpha[1]);
	a = (1.55f / hairIOF) * rcp(n_prime);
	h = CosHalfPhi * (1 + a * (0.6 - 0.8 * CosPhi));
	f = SpecularFresnel(F0, CosThetaD * sqrt(saturate(1 - h * h)));
	Fp = square(1 - f);
	Tp = pow(s.Albedo, 0.5 * sqrt(1 - square((h * a))) / CosThetaD);
	Np = exp(-3.65 * CosPhi - 3.98);
	S += (Mp * Np) * (Fp * Tp) * Backlit;

	// TRT
	Mp = Hair_G(B[2], ThetaH - Alpha[2]);
	f = SpecularFresnel(F0, CosThetaD * 0.5f);
	Fp = square(1 - f) * f;
	Tp = pow(s.Albedo, 0.8 / CosThetaD);
	Np = exp(17 * CosPhi - 16.78);

	S += (Mp * Np) * (Fp * Tp);

	return S;
}

float3 HairSpecularKajiya(SurfaceOutputHair s, float3 tangent1, float3 tangent2, float3 V, float3 L)
{
	float3 H = normalize(L + V);

	float TdotH1 = dot(tangent1, H);
	float TdotH2 = dot(tangent2, H);

	float sinTH1 = sqrt(1.0f - saturate(TdotH1 * TdotH1));
	float sinTH2 = sqrt(1.0f - saturate(TdotH2 * TdotH2));

	// Attenuate the primary highlight by the fresnel term to give some room for the secondary highlight
	float3 fresnel = SpecularFresnel(s.Albedo, saturate(dot(H, V)));

	float3 specular = 0;
	specular += fresnel * s.Albedo * pow(sinTH1, 1);
	specular += (1.0 - fresnel) * s.Albedo * pow(sinTH2, (1 - s.Roughness) * 100);
	return specular;
}

float3 HairShading(SurfaceOutputHair s, float3 L, float3 V, half3 N, float Shadow, float Backlit, float Area)
{
	float3 S = float3(0, 0, 0);

	//S = HairSpecularKajiya(s, N, N, V, L); 
	S = HairSpecularMarschner(s, L, V, N, Shadow, Backlit, Area);
	S += HairDiffuseKajiyaUE(s, L, V, N, Shadow, Backlit, Area);

	S = -min(-S, 0.0);

	return S;
}

//N is world-space tangent
float3 HairBxDF(SurfaceOutputHair s, half3 N, half3 V, half3 L, float Shadow, float Backlit, float Area)
{
	return HairShading(s, L, V, N, Shadow, Backlit, Area);
}

float3 HairKajiyaShading(SurfaceOutputHair s, float3 L, float3 V, half3 N, float Shadow, float Backlit, float Area)
{
	float3 S = float3(0, 0, 0);

	S = HairSpecularKajiya(s, N, N, V, L); 
	S += HairDiffuseKajiyaUE(s, L, V, N, Shadow, Backlit, Area);

	S = -min(-S, 0.0);

	return S;
}

float3 KajiyaBxDF(SurfaceOutputHair s, half3 N, half3 V, half3 L, float Shadow, float Backlit, float Area)
{
	return HairKajiyaShading(s, L, V, N, Shadow, Backlit, Area);
}

// Yan, Ling-Qi, etc, "An efficient and practical near and far field fur reflectance model."
float3 FurBSDFYan(SurfaceOutputFur s, float3 L, float3 V, half3 N, float Shadow, float Backlit, float Area)
{
	float3 S = 0;

	const float VoL = dot(V, L);
	const float SinThetaL = dot(N, L);
	const float SinThetaV = dot(N, V);
	float cosThetaL = sqrt(max(0, 1 - SinThetaL * SinThetaL));
	float cosThetaV = sqrt(max(0, 1 - SinThetaV * SinThetaV));
	float CosThetaD = sqrt((1 + cosThetaL * cosThetaV + SinThetaV * SinThetaL) / 2.0);

	const float3 Lp = L - SinThetaL * N;
	const float3 Vp = V - SinThetaV * N;
	const float CosPhi = dot(Lp, Vp) * rsqrt(dot(Lp, Lp) * dot(Vp, Vp) + 1e-4);
	const float CosHalfPhi = sqrt(saturate(0.5 + 0.5 * CosPhi));

	float n_prime = 1.19 / CosThetaD + 0.36 * CosThetaD;

	float Shift = 0.0499f;
	float Alpha[] =
	{
		-0.0998,//-Shift * 2,
		0.0499f,// Shift,
		0.1996  // Shift * 4
	};
	float B[] =
	{
		Area + square(s.Roughness),
		Area + square(s.Roughness) / 2,
		Area + square(s.Roughness) * 2
	};

	//float F0 = square((1 - 1.55f) / (1 + 1.55f));
	float F0 = 0.04652;//eta=1.55f

	float3 Tp;
	float Mp, Np, Fp, a, h, f;
	float ThetaH = SinThetaL + SinThetaV;
	// R
	Mp = Hair_G(B[0], ThetaH - Alpha[0]);
	Np = 0.25 * CosHalfPhi;
	Fp = SpecularFresnelLayer(F0, sqrt(saturate(0.5 + 0.5 * VoL)), s.Layer);
	S += (Mp * Np) * (Fp * lerp(1, Backlit, saturate(-VoL)));

	// TT
	Mp = Hair_G(B[1], ThetaH - Alpha[1]);
	a = rcp(n_prime);
	h = CosHalfPhi * (1 + a * (0.6 - 0.8 * CosPhi));
	f = SpecularFresnelLayer(F0, CosThetaD * sqrt(saturate(1 - h * h)), s.Layer);
	Fp = square(1 - f);
	float sinGammaTSqr = square((h * a));
	float sm = sqrt(saturate(square(s.Kappa)-sinGammaTSqr));
	float sc = sqrt(1 - sinGammaTSqr) - sm;
	Tp = pow(s.Albedo, 0.5 * sc / CosThetaD) * pow(s.MedulaAbsorb*s.MedulaScatter, 0.5 * sm / CosThetaD);
	Np = exp(-3.65 * CosPhi - 3.98);
	S += (Mp * Np) * (Fp * Tp) * Backlit;

	// TRT
	Mp = Hair_G(B[2], ThetaH - Alpha[2]);
	f = SpecularFresnelLayer(F0, CosThetaD * 0.5f, s.Layer);
	Fp = square(1 - f) * f;
	// assume h = sqrt(3)/2, calculate sm and sc
	sm = sqrt(saturate(square(s.Kappa)-0.75f));
	sc = 0.5f - sm;
	Tp = pow(s.Albedo, sc / CosThetaD) * pow(s.MedulaAbsorb*s.MedulaScatter, sm / CosThetaD);
	Np = exp((6.3f*CosThetaD+0.7f)*CosPhi-(5*CosThetaD+2));

	S += (Mp * Np) * (Fp * Tp);

	// TTs
	// hacking approximate Cm
	Mp = abs(cosThetaL)*0.5f;
	// still assume h = sqrt(3)/2
	Tp = pow(s.Albedo, (sc+1-s.Kappa)/(4*CosThetaD)) * pow(s.MedulaAbsorb, s.Kappa / (4*CosThetaD));
	// hacking approximate pre-integrated Dtts based on Cn
	Np = 0.05*(2*CosPhi*CosPhi - 1) + 0.16f;//0.05*std::cos(2*Phi) + 0.16f;

	S += (Mp * Np) * (f * Tp);

	//TRTs
	float phi = acosFast(CosPhi);
	// hacking approximate pre-integrated Dtrts based on Cn
	Np = 0.05f * cos(1.5*phi+1.7) + 0.18f;
	// still assume h = sqrt(3)/2
	Tp = pow(s.Albedo, (3*sc+1-s.Kappa)/(4*CosThetaD)) * pow(s.MedulaAbsorb, (2*sm+s.Kappa) / (4*CosThetaD)) * pow(s.MedulaScatter, sm/(8*CosThetaD));
	Fp = f * (1-f);

	S += (Mp * Np) * (Fp * Tp);

	return S;
}

float3 FurDiffuseKajiya(SurfaceOutputFur s, float3 L, float3 V, half3 N, half Shadow, float Backlit, float Area) {
	float3 S = 0;
	float KajiyaDiffuse = 1 - abs(dot(N, L));

	float3 FakeNormal = normalize(V - N * dot(V, N));
	N = FakeNormal;

	// Hack approximation for multiple scattering.
	float Wrap = 1;
	float NoL = saturate((dot(N, L) + Wrap) / square(1 + Wrap));
	float DiffuseScatter = (1 / PI) * lerp(NoL, KajiyaDiffuse, 0.33);// *s.Metallic;
	float Luma = Luminance(s.Albedo);
	float3 ScatterTint = pow(s.Albedo / Luma, 1 - Shadow);
	S = sqrt(s.Albedo) * DiffuseScatter * ScatterTint;
	return S;
}

float3 FurBxDF(SurfaceOutputFur s, half3 N, half3 V, half3 L, float Shadow, float Backlit, float Area)
{
	float3 S = float3(0, 0, 0);

	S = FurBSDFYan(s, L, V, N, Shadow, Backlit, Area);
	S += FurDiffuseKajiya(s, L, V, N, Shadow, Backlit, Area);

	S = -min(-S, 0.0);

	return S;
}