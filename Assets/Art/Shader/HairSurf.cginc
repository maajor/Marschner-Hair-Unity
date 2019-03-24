#include "HairBxDF.cginc"

inline fixed4 LightingHair(SurfaceOutputHair s, half3 viewDir, UnityGI gi)
{
	clip(s.Alpha - 0.5f);
	fixed4 c = fixed4(0,0,0,1);
	c.rgb = HairBxDF(s, s.Normal, viewDir,gi.light.dir, 0);

#ifdef UNITY_LIGHT_FUNCTION_APPLY_INDIRECT
	c.rgb += s.Albedo * gi.indirect.diffuse;
#endif

	return c;
}

inline void LightingHair_GI(
	SurfaceOutputHair s,
	UnityGIInput data,
	inout UnityGI gi)
{
	gi = UnityGlobalIllumination(data, 1.0f, s.Normal);
}