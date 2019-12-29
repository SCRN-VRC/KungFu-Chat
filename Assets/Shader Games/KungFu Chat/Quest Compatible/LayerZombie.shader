Shader "Games/KungFu Zombies"
{
	Properties
	{
        _StateTex ("State Input", 2D) = "black" {}
        _ZombTex ("Zombie Texture", 2D) = "black" {}
        _Resolution ("Output Res", Vector) = (180., 180., 0., 0.)
        _DepthScale ("Depth Sorting Scale", Float) = 0.1
        _Dst ("Distance Disable", Float) = 0.1
    }
    SubShader
    {
        Tags { "Queue"="Geometry" "ForceNoShadowCasting"="True" "IgnoreProjector"="True" }
        Cull Off

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing
            #pragma instancing_options procedural:setup
            #pragma fragmentoption ARB_precision_hint_fastest
            #pragma target 3.0

            #include "UnityCG.cginc"
            #include "../KungFu_Include.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float4 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float4 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct renderObjStruct
            {
                float skip;
                float4 posDirHP;
                float4 charAnimHistFrame;
            };

            struct fragOut
            {
                float4 col : COLOR0;
                float depth: DEPTH;
            };

            Texture2D<float4> _StateTex;
            Texture2D<float4> _ZombTex;
            float2 _Resolution;
            float _DepthScale;
            float _Dst;

            float4 drawZombie(float4 posFragCoord, float4 typeFrameFlipState) {
                float4 posOffset, fragCoordFrame, translate;
                float3 sizeFlip;

                posOffset.xy = posFragCoord.xy;
                fragCoordFrame.xy = posFragCoord.zw;
                // I messed up exploding zombie sprites so
                // it needs to be flipped by default
                sizeFlip.z = (typeFrameFlipState.x == _ZBOOM) ?
                    1 - typeFrameFlipState.z : typeFrameFlipState.z;
                
                posOffset.zw = zStateLoc[typeFrameFlipState.x][typeFrameFlipState.w].xy;
                sizeFlip.xy = zSizeFrame[typeFrameFlipState.x][typeFrameFlipState.w].xy;
                translate = zTranslate[typeFrameFlipState.x][typeFrameFlipState.w];
                fragCoordFrame.zw = float2(typeFrameFlipState.y, 0);

                [flatten]
                if (typeFrameFlipState.x == _ZBOOM &&
                    typeFrameFlipState.w == _ZATTK) {
                    fragCoordFrame.zw = float2(fmod(typeFrameFlipState.y, 8),
                        -1. * floor(typeFrameFlipState.y / 8.));
                }

                return spriteTemplate(posOffset, fragCoordFrame, translate, sizeFlip,
                    _ZombTex, ZSCALE);
            }

            void draw(inout float4 col, in float2 fragCoord,
                in renderObjStruct renderObj, inout float depth,
                in float characterDepth) {

                float4 o = drawZombie(
                        float4(renderObj.posDirHP.xy, fragCoord),
                        float4(renderObj.charAnimHistFrame.x,
                            floor(renderObj.charAnimHistFrame.w),
                            floor(renderObj.posDirHP.z / 10.),
                            floor(renderObj.charAnimHistFrame.y)));
                col.rgba = lerp(col.rgba, o.rgba, o.a);
                depth = lerp(depth, characterDepth, o.a);
            }

            void setup() {}

            v2f vert (appdata v)
            {
                // Setup instancing
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);

                // Screenspace
                o.vertex = float4(v.uv.xy * 2 - 1, 0, 1);
                #ifdef UNITY_UV_STARTS_AT_TOP
                v.uv.y = 1-v.uv.y;
                #endif
                o.uv.xy = UnityStereoTransformScreenSpaceTex(v.uv);

                // Distance Disable
                o.uv.z = (distance(_WorldSpaceCameraPos,
                    mul(unity_ObjectToWorld, float4(0,0,0,1)).xyz) > _Dst) ? -1 : 1;
                
                float4 clipPos = UnityObjectToClipPos(v.vertex);
                // Quad depth
                o.uv.w = clipPos.z / clipPos.w;

                return o;

                // o.vertex = UnityObjectToClipPos(v.vertex);
                // o.uv = v.uv;
                // return o;
            }

            fragOut frag (v2f i)
            {
                clip(i.uv.z);
                UNITY_SETUP_INSTANCE_ID(i);
                #if !defined(UNITY_INSTANCING_ENABLED)
                uint unity_InstanceID = 0;
                #endif

                float2 fragCoord = i.uv.xy * _Resolution.xy;
                float4 stagePosZContIndex = LoadValue(_StateTex, txStagePosZContIndex);
                float posToScreen = max(stagePosZContIndex.x - MIDDLE_X, 0.0);

                fragOut o;
                o.col = 0..xxxx;
                o.depth = 0.;

                // Render queue in array
                renderObjStruct renderObj;

                renderObj.skip = 0.;
                renderObj.posDirHP = LoadValue(_StateTex,
                    int2(unity_InstanceID, txZombiesPosDirHP.y));
                renderObj.posDirHP.x -= posToScreen;
                renderObj.posDirHP.y = round(renderObj.posDirHP.y);
                renderObj.charAnimHistFrame = LoadValue(_StateTex,
                    int2(unity_InstanceID, txZombiesAnimHistFrame.y));
                renderObj.charAnimHistFrame.x;

                // Background at 0.1, zombies must be above 0.1
                float zombDepth = lerp(0.2, 0.5,
                    (UPPER_Y - renderObj.posDirHP.y) / UPPER_Y);
                draw(o.col, fragCoord, renderObj, o.depth, zombDepth);

                #if !(UNITY_REVERSED_Z)
                o.depth = 1. - o.depth;
                #endif
                // Start at mesh depth
                o.depth = o.depth * _DepthScale + i.uv.w;
                return o;
            }
            ENDCG
        }
    }
}
