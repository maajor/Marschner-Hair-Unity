Shader "Custom/HairKajiya"
{
    Properties
    {
		_MainTex("PropertyMap R-Depth G-ID B-Root A-Alpha", 2D) = "white" {}
		_Flowmap("Flowmap", 2D) = "white" {}
		_RootColor("RootColor", Color) = (0,0,0,1)
		_TipColor("TipColor", Color) = (0,0,0,1)
		_ColorVariationRange("ColorVariation-HSV", Vector) = (0,0,0,1)
		_EccentricityMean("EccentricityMean", Float) = 0.07
		_RoughnessRange("RoughnessRange", Vector) = (0.3, 0.5,0,0)
    }
    SubShader
	{	
		Tags { "RenderType" = "AlphaTest"}
		LOD 200
		Cull Off

		CGPROGRAM
		#include "HairKajiyaSurf.cginc"
		#pragma surface surf HairKajiya fullforwardshadows vertex:vert

		#pragma target 3.0

		sampler2D _MainTex;
		sampler2D _Flowmap;
		uniform float3 _RootColor;
		uniform float3 _TipColor;
		uniform float _EccentricityMean;
		uniform float4 _RoughnessRange;
		uniform float4 _RandomColor;
		uniform float4 _ColorVariationRange;

		struct Input
		{
			float2 uv_MainTex;
			float4 screenUV;
			float3 worldN;
		};

		void vert(inout appdata_full v, out Input o) {
			UNITY_INITIALIZE_OUTPUT(Input, o);
			o.uv_MainTex = v.texcoord;
			o.worldN = UnityWorldToObjectDir(v.normal);
			o.screenUV = ComputeScreenPos(UnityObjectToClipPos(v.vertex));
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

		void surf(Input IN, inout SurfaceOutputHair o)
		{
			half4 property = tex2D(_MainTex, IN.uv_MainTex);
			half4 flowmap = tex2D(_Flowmap, IN.uv_MainTex);

			float3 basecolor = lerp(_RootColor, _TipColor, property.b);
			float3 basecolorHSV = rgb2hsv(basecolor);
			basecolorHSV += (property.g - 0.5f) * _ColorVariationRange.rgb * _ColorVariationRange.a;
			o.Albedo = hsv2rgb(basecolorHSV);

			o.Eccentric = lerp(0.0f, _EccentricityMean * 2, property.r);
			o.Normal = flowmap * 2.0f - 1.0f;
			o.Roughness = lerp(_RoughnessRange.x, _RoughnessRange.y, property.g);

			//animating dither
		    float2 screenPixel = (IN.screenUV.xy/IN.screenUV.w)* _ScreenParams.xy + _Time.yz*100;
			float dither = ScreenDitherToAlpha(screenPixel.x, screenPixel.y, property.a);
			o.Alpha = dither;

			o.VNormal = IN.worldN;
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
