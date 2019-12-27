Shader "Controller/PositionBase"
{
    Properties
    {
        _POut ("Position Out", 2D) = "black" {}
        _Reset ("Reset", Float) = 0.0
        _UpDown ("Up/Down", Float) = 0.0
        _LeftRight ("Left/Right", Float) = 0.0
        _Dst ("Distance Clip", Float) = 0.02
    }

    SubShader
    {
        Tags { "Queue"="Overlay" "ForceNoShadowCasting"="True" "IgnoreProjector"="True" }
        ZWrite Off
        ZTest Always
        Cull Off

        Pass
        {
            Lighting Off
            SeparateSpecular Off
            Fog { Mode Off }

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma fragmentoption ARB_precision_hint_fastest
            #pragma target 3.0

            #include "UnityCG.cginc"

            //RWStructuredBuffer<float4> buffer : register(u1);
            
            Texture2D<half4> _POut;
            half _UpDown;
            half _LeftRight;
            half _Reset;
            half _Dst;

            struct appdata
            {
                half4 vertex : POSITION;
                half2 uv : TEXCOORD0;
            };

            struct v2f
            {
                half3 uv : TEXCOORD0;
                half4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = half4(v.uv * 2 - 1, 0, 1);
                #ifdef UNITY_UV_STARTS_AT_TOP
                v.uv.y = 1-v.uv.y;
                #endif
                o.uv.xy = UnityStereoTransformScreenSpaceTex(v.uv);
                o.uv.z = (distance(_WorldSpaceCameraPos,
                    mul(unity_ObjectToWorld, half4(0,0,0,1)).xyz) > _Dst) ? -1 : 1;
                return o;
            }
            
            half4 frag (v2f ps) : SV_Target
            {
                clip(ps.uv.z);
                half4 i = _POut.Load(int3(0,0,0));
                half3 o = i.xyz - unity_ObjectToWorld._m03_m13_m23;
                o = mul((half3x3)unity_WorldToObject, o);
                //buffer[0] = float4(o, i.w);
                o.y = _Reset;
                o.x += _LeftRight;
                o.z += _UpDown;
                return half4(o, i.w);
            }
            ENDCG
        }
    }
}
