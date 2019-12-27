Shader "Controller/PositionOut"
{
    Properties
    {
        _BtnDown ("Button Down", Float) = 0.0
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

            //RWStructuredBuffer<fixed4> buffer : register(u1);
            
            fixed _Dst;
            fixed _BtnDown;

            struct appdata
            {
                fixed4 vertex : POSITION;
                fixed2 uv : TEXCOORD0;
            };

            struct v2f
            {
                fixed3 uv : TEXCOORD0;
                fixed4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = fixed4(v.uv * 2 - 1, 0, 1);
                #ifdef UNITY_UV_STARTS_AT_TOP
                v.uv.y = 1-v.uv.y;
                #endif
                o.uv.xy = UnityStereoTransformScreenSpaceTex(v.uv);
                o.uv.z = (distance(_WorldSpaceCameraPos,
                    mul(unity_ObjectToWorld, fixed4(0,0,0,1)).xyz) > _Dst) ? -1 : 1;
                return o;
            }
            
            fixed4 frag (v2f ps) : SV_Target
            {
                clip(ps.uv.z);
                fixed3 o = unity_ObjectToWorld._m03_m13_m23;
                return fixed4(o, _BtnDown);
            }
            ENDCG
        }
    }
}
