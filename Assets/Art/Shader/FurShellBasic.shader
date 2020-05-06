Shader "Custom/FurShellBasic"
{
    Properties
    {
		_MainTex("MainTex", 2D) = "white" {}
		_ClipTex("ClipTex", 2D) = "white" {}
		_Tiling("Tiling", Range(1,100)) = 30
		_ClipOffset("ClipOffset", Range(-1,1)) = 0
		_RootColor("RootColor", Color) = (0,0,0,1)
		_TipColor("TipColor", Color) = (0,0,0,1)
		_ColorVariationRange("ColorVariation-HSV", Vector) = (0,0,0,1)
		_RoughnessRange("RoughnessRange", Vector) = (0.3, 0.5,0,0)
    }
    SubShader
	{	
		Tags { "RenderType" = "AlphaTest"}
		LOD 200
		Cull Off

		CGPROGRAM
		#include "FurShellSurf.cginc"
		#pragma surface surf Standard fullforwardshadows vertex:vert

		#pragma target 3.0

		sampler2D _MainTex;
		sampler2D _ClipTex;
		uniform float3 _RootColor;
		uniform float3 _TipColor;
		uniform float4 _RoughnessRange;
		uniform float4 _RandomColor;
		uniform float4 _ColorVariationRange;
		float _Tiling;
		float _ClipOffset;

		struct Input
		{
			float2 uv_MainTex;
			float3 color;
		};

		void vert(inout appdata_full v, out Input o) {
			UNITY_INITIALIZE_OUTPUT(Input, o);
			o.uv_MainTex = v.texcoord;
			o.color = v.color;
		}
		float3 rgb2hsv(float3 c)
		{
			float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
			float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
			float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));

			float d = q.x - min(q.w, q.y);
			float e = 1.0e-10;
			return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
		}

		float3 hsv2rgb(float3 c)
		{
			float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
			float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
			return c.z * lerp(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
		}

		float ScreenDitherToAlpha(float x, float y, float c0)
		{
			const float dither[64] = {
				0, 32, 8, 40, 2, 34, 10, 42,
				48, 16, 56, 24, 50, 18, 58, 26 ,
				12, 44, 4, 36, 14, 46, 6, 38 ,
				60, 28, 52, 20, 62, 30, 54, 22,
				3, 35, 11, 43, 1, 33, 9, 41,
				51, 19, 59, 27, 49, 17, 57, 25,
				15, 47, 7, 39, 13, 45, 5, 37,
				63, 31, 55, 23, 61, 29, 53, 21 };

			int xMat = int(x) & 7;
			int yMat = int(y) & 7;

			float limit = (dither[yMat * 8 + xMat] + 11.0) / 64.0;
			return lerp(limit*c0, 1.0, c0);
		}

		void surf(Input IN, inout SurfaceOutputStandard o)
		{
			half4 baseTex = tex2D(_MainTex, IN.uv_MainTex);
			half4 cliptex = tex2D(_ClipTex, IN.uv_MainTex*_Tiling);

			float layer =  1-IN.color.g;
			float3 basecolor = lerp(_RootColor, _TipColor, layer);
			o.Albedo = baseTex.rgb*basecolor;
			//o.Albedo = worldTangent;
			//o.Albedo = float3(IN.color.r,IN.color.r,IN.color.r);

			o.Smoothness = 1-_RoughnessRange.x;

			o.Alpha = cliptex.a + IN.color.r/3.0f + _ClipOffset;
			clip(o.Alpha - 0.5f);
		}
		ENDCG
	}
	SubShader
	{
		Pass
		 {
			 Name "ShadowCaster"
			 Tags { "LightMode" = "ShadowCaster" }

			 Fog { Mode Off }
			 ZWrite On ZTest Less Cull Off
			 Offset 1, 1

			 CGPROGRAM

			 #pragma vertex vert
			 #pragma fragment frag
			 #pragma multi_compile_shadowcaster
			 #pragma fragmentoption ARB_precision_hint_fastest

			 #include "UnityCG.cginc"

			 sampler2D _MainTex;

			 struct v2f
			 {
				 V2F_SHADOW_CASTER;
				 half2 uv:TEXCOORD1;
			 };

			 v2f vert(appdata_base v)
			 {
				 v2f o;
				 o.uv = v.texcoord;
				 TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
				 return o;
			 }

			 float4 frag(v2f i) : COLOR
			 {
				 fixed alpha = tex2D(_MainTex, i.uv).a;
				 clip(alpha - 0.5f);
				 SHADOW_CASTER_FRAGMENT(i)
			 }

			 ENDCG
		  }
			}
    
}
