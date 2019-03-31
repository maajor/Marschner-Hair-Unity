Shader "Custom/Hair"
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
	{/*
		Pass
		 {
			 Name "Depth"
			 Tags { "RenderType" = "AlphaTest" "LightMode" = "ForwardBase"  }
			 Fog { Mode Off }
			 ZWrite On ZTest Less Cull Off
			 Offset 1, 1
			 //ColorMask 0

			 CGPROGRAM

			 #pragma vertex vert
				#pragma fragment frag
			#pragma multi_compile_fwdbase
				//#pragma fragmentoption ARB_precision_hint_fastest
				#include "UnityCG.cginc"
			#include "AutoLight.cginc"

			sampler2D _MainTex;
				struct v2f {
					float4 pos          : POSITION;
					float4 uv    : TEXCOORD0;
					float3 worldPos : TEXCOORD1;
					LIGHTING_COORDS(2,3)
				};

				v2f vert(appdata_full v)
				{
					v2f o;
					o.pos = UnityObjectToClipPos(v.vertex);
					o.worldPos = mul(unity_ObjectToWorld, v.vertex);
					o.uv = v.texcoord;
					TRANSFER_VERTEX_TO_FRAGMENT(o);
					return o;
				}

				half4 frag(v2f i) : COLOR
				{
					half4 property = tex2D(_MainTex, i.uv);
					clip(property.w-0.99f);
					float atten = LIGHT_ATTENUATION(i);
					return half4(atten, atten, atten,1);
				}
			ENDCG
		  }*/
			
		Tags { "RenderType" = "AlphaTest" }
		LOD 200
		Cull Off
		//ZWrite Off

		CGPROGRAM
		#include "HairSurf.cginc"
		//#include "AutoLight.cginc"
		#pragma shader_feature MARSCHER_SPECULAR KAJIYA_SPECULAR
		#pragma surface surf Hair fullforwardshadows// alpha:premul


		// Use shader model 3.0 target, to get nicer looking lighting
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
			float3 worldPos;
			float3 worldNormal;
		};

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
			o.Alpha = saturate(property.a);
			o.VNormal = IN.worldNormal;
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
