// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

// Simplified Diffuse shader. Differences from regular Diffuse one:
// - no Main Color
// - fully supports only 1 directional light. Other lights can affect it, but it will be per-vertex/SH.


Shader "Custom/CRT Screen"
{
    Properties
    {
        _MainTex ("Base (RGB)", 2D) = "white" {}
        [HDR] _Tint ("Tint", Color) = (1,1,1,1)
        _Aberration ("Chromatic Aberration Offset", Range(0.0, 0.1)) = 0.003
        _DistScale ("Distance Scale", Range(0.0, 1.0)) = 0.03
        _RefProbeMix("Reflection Probe", Range(0.0, 1.0)) = 0.5
        _Dim ("Dim", Range(0.0, 1.0)) = 0.85
        _Res ("Scanline Res", Vector) = (200, 200, 0, 0)
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 150
    
        CGPROGRAM
        #pragma target 3.0
        #pragma surface surf Lambert vertex:vert exclude_path:prepass exclude_path:deferred noforwardadd noshadow nodynlightmap nolppv noshadowmask

        #include "UnityCG.cginc"

        #define ATARI_REZ _Res.xy

        sampler2D _MainTex;
        half3 _Tint;
        half2 _Res;
        half _Aberration;
        half _DistScale;
        half _Dim;
        half _RefProbeMix;

        struct Input
        {
            half2 uv_MainTex;
            half3 world_vertex;
            half3 worldRefl;
        };
        
        void vert (inout appdata_full v, out Input o) {
            UNITY_INITIALIZE_OUTPUT(Input,o);
            o.world_vertex = mul(unity_ObjectToWorld, v.vertex).xyz;
            half3 worldViewDir = normalize(UnityWorldSpaceViewDir(o.world_vertex));
            // world space normal
            half3 worldNormal = UnityObjectToWorldNormal(v.normal);
            // world space reflection vector
            o.worldRefl = reflect(-worldViewDir, worldNormal);

        }

        half3 BoxProjection(half3 direction, half3 position,
            half3 cubemapPosition, half3 boxMin, half3 boxMax) {
            half3 factors = ((direction > 0 ? boxMax : boxMin) - position) / direction;
            half scalar = min(min(factors.x, factors.y), factors.z);
            return direction * scalar + (position - cubemapPosition);
        }

        void surf (Input IN, inout SurfaceOutput o)
        {
            // Do CRT warp / vignette
            half2 uv = IN.uv_MainTex;

            // Get atari screen buffer pixel, with scanlines / chromatic aberration / flicker / vsync
            half3 fragColor = half3(0.0, 0.0, 0.0);
 
            half dist = distance(IN.world_vertex, _WorldSpaceCameraPos.xyz) * _DistScale;
            dist = saturate(dist);
            half2 atariXy = uv * ATARI_REZ;
            half scanAmt = lerp(0.1, 1.0, 
                saturate(sin(UNITY_PI * frac(atariXy.y))));
            scanAmt = lerp(scanAmt, 1.0, dist);
            half2 atariUv = (atariXy + 0.5) / ATARI_REZ;

            // chromatic aberration
            fragColor[0] = tex2Dlod(_MainTex, half4(atariUv, 0, -100))[0];
            atariUv += _Aberration;
            fragColor[1] = tex2Dlod(_MainTex, half4(atariUv, 0, -100))[1];
            atariUv += _Aberration;
            fragColor[2] = tex2Dlod(_MainTex, half4(atariUv, 0, -100))[2];

            fragColor.rgb *= scanAmt * (fmod(_Time.y * 10., 1.0) >= 0.5 ? 1.0 : _Dim) * _Tint;

            half3 boxProject = BoxProjection(IN.worldRefl, IN.world_vertex,
                unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin,
                unity_SpecCube0_BoxMax);
            
            half4 mc = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, boxProject, 1);
            mc.xyz = DecodeHDR(mc, unity_SpecCube0_HDR) * 0.5;

            o.Albedo = lerp(fragColor.rgb, mc.rgb, _RefProbeMix);
            o.Alpha = 1.0f;
        }
        ENDCG
    }

    FallBack "Diffuse"
}