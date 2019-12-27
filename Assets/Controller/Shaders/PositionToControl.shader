Shader "Controller/PositionToControl" {
    Properties {
        _P1Base ("Player 1 Base Position", 2D) = "black" {}
        _P2Base ("Player 2 Base Position", 2D) = "black" {}
        _Speed ("Speed", Float) = 0.7
    }
    SubShader
    {
        Tags {
            "ForceNoShadowCasting"="True"
            "IgnoreProjector"="True"
            "DisableBatching" = "True"
        }
        ZWrite Off
        //ZTest Off
        Lighting Off
        SeparateSpecular Off
        Fog { Mode Off }

        Pass
        {
            Name "Pos2Control"
            CGPROGRAM
            #include "UnityCustomRenderTexture.cginc"
            #pragma vertex CustomRenderTextureVertexShader
            #pragma fragment pixel_shader
            #pragma fragmentoption ARB_precision_hint_fastest
            #pragma target 3.0

            Texture2D<fixed4> _P1Base;
            Texture2D<fixed4> _P2Base;
            fixed _Speed;

            fixed4 pixel_shader (v2f_customrendertexture IN) : SV_TARGET
            {   
                fixed2 uv = IN.globalTexcoord.xy;
                fixed4 b1 = _P1Base.Load(int3(0,0,0)).xzwy;
                fixed4 b2 = _P2Base.Load(int3(0,0,0)).xzwy;
                fixed4 i = fixed4(b1.xy, b2.xy);
                //i = pow(i, 3);

                fixed4 col = (uv.x < 0.5) ?
                    //clamp(i * _Speed, -1, 1) :
                    i * _Speed:
                    fixed4(b1.z, b2.z, 0, min(1, b1.w + b2.w));

                return col;
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}