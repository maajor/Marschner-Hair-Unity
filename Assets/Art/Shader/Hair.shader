Shader "Custom/Hair"
{
    Properties
    {
        _MainTex ("Color RGB-Color A-Alpha", 2D) = "white" {}
        _PropertyMap ("PropertyMap R-Depth G-ID A-Root", 2D) = "white" {}
		_Flowmap("Flowmap", 2D) = "white" {}
    }
    SubShader
	{
		Tags { "RenderType" = "AlphaTest" }
		LOD 200
		Cull Off

		CGPROGRAM
		#include "HairSurf.cginc"
		#pragma shader_feature MARSCHER_SPECULAR KAJIYA_SPECULAR
		#define KAJIYA_SPECULAR 1
		#pragma surface surf Hair fullforwardshadows


		// Use shader model 3.0 target, to get nicer looking lighting
		#pragma target 3.0

		sampler2D _MainTex;
		sampler2D _PropertyMap;
		sampler2D _Flowmap;

		struct Input
		{
			float2 uv_MainTex;
			float3 worldNormal;
		};

		void surf(Input IN, inout SurfaceOutputHair o)
		{
			half4 c = tex2D(_MainTex, IN.uv_MainTex);
			half4 property = tex2D(_PropertyMap, IN.uv_MainTex);
			half4 flowmap = tex2D(_Flowmap, IN.uv_MainTex);
			o.Albedo = c.rgb;
			o.Eccentric = lerp(0.0f, 0.15f, property.r);
			o.Normal = float3(0,1,0);
			o.Roughness = lerp(0.2, 0.5, property.g);
			o.Alpha = c.a;
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
