Shader "Unlit/debug"
{
    Properties
    {
        _Flowmap("Flowmap", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="AlphaTest" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
                half3 tspace0 : TEXCOORD2; // tangent.x, bitangent.x, normal.x
                half3 tspace1 : TEXCOORD3; // tangent.y, bitangent.y, normal.y
                half3 tspace2 : TEXCOORD4; // tangent.z, bitangent.z, normal.z
            };

            sampler2D _Flowmap;
            float4 _Flowmap_ST;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _Flowmap);
                UNITY_TRANSFER_FOG(o,o.vertex);

                half3 wNormal = UnityObjectToWorldNormal(v.normal);
                half3 wTangent = UnityObjectToWorldDir(v.tangent.xyz);
                // compute bitangent from cross product of normal and tangent
                half tangentSign = v.tangent.w * unity_WorldTransformParams.w;
                half3 wBitangent = cross(wNormal, wTangent) * tangentSign;
                // output the tangent space matrix
                o.tspace0 = half3(wTangent.x, wBitangent.x, wNormal.x);
                o.tspace1 = half3(wTangent.y, wBitangent.y, wNormal.y);
                o.tspace2 = half3(wTangent.z, wBitangent.z, wNormal.z);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                // sample the texture
                float4 flow = tex2D(_Flowmap, i.uv);
                float3 direction = flow * 2.0f - 1.0f;
                float3 localTangent = -float3(direction.x,-direction.y,-direction.z);
                float3 worldTangent;

                float3 vtTangent = float3(i.tspace0.y, i.tspace1.y, i.tspace2.y);

                worldTangent.x = dot(i.tspace0, direction);
                worldTangent.y = dot(i.tspace1, direction);
                worldTangent.z = dot(i.tspace2, direction);
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                clip(flow.a-0.5f);
                return float4(localTangent,flow.a);
            }
            ENDCG
        }
    }
}
