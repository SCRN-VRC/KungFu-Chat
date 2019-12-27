Shader "Games/KungFu Boss"
{
	Properties
	{
        _StateTex ("State Input", 2D) = "black" {}
        _BGTex ("Background Image", 2D) = "black" {}
        _BossTex ("Sprite Texture", 2D) = "black" {}
        _UITex ("Menu Texture", 2D) = "black" {}
        _CharTex ("Sprite Texture", 2D) = "black" {}
        [HideInInspector]_MinDepth ("Minimum Depth Offset", Range(0., 1.)) = 0.0009
        [HideInInspector]_MaxDepth ("Maximum Depth Offset", Range(0., 1.)) = 0.031
        _Resolution ("Output Res", Vector) = (180., 180., 0., 0.)
        _Dst ("Distance Disable", Float) = 0.1
    }
    SubShader
    {
        Tags { "Queue"="Overlay" "ForceNoShadowCasting"="True" "IgnoreProjector"="True" }
        Cull Off

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma fragmentoption ARB_precision_hint_fastest
            #pragma target 3.0

            #include "UnityCG.cginc"
            #include "../KungFu_Include.cginc"

            #define specialCol1 float3(0.2, 0.2, 1.2)
            #define specialCol2 float3(0.3, 0.1, 1.1)
            #define bossCol1 float3(0.1, 1.0, 0.1)
            #define bossCol2 float3(0.1, 0.5, 0.1)

            // Depth is flipped on the Quest
            #if !(UNITY_REVERSED_Z)
            #define LAYER_UI -0.01
            #define LAYER_CURSOR -0.02
            #else
            #define LAYER_UI 0.01
            #define LAYER_CURSOR 0.02
            #endif

            struct appdata
            {
                float4 vertex : POSITION;
                float4 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
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
            Texture2D<float4> _BossTex;
            Texture2D<float4> _UITex;
            Texture2D<float4> _CharTex;
            sampler2D _BGTex;
            float4 _BGTex_TexelSize;
            float2 _Resolution;
            float _MinDepth;
            float _MaxDepth;
            float _Dst;

            float sdSquare(in float2 p, in float2 pos, in float2 size) {
                float2 d = abs(p - pos) - size;
                return length(max(d, 0.0));
            }

            float4 RenderBar(float2 pos, float4 barPosSize, float4 col,
                float3 barCol1, float3 barCol2, inout float depth) {
                float t = sdSquare(pos, barPosSize.xy, barPosSize.zw);
                depth = lerp(depth, _MaxDepth + LAYER_UI, 1 - saturate(t));
                return float4(lerp(lerp(barCol2, barCol1, (5 + barPosSize.x - pos.x) * 0.05), 
                    col.rgb, smoothstep(0., 0.5, t)), col.a + 1. - saturate(t));
            }

            float sdBox( in float2 p, in float2 pos, in float2 b )
            {
                float2 d = abs(p - pos)-b;
                return length(max(d,0..xx)) + min(max(d.x,d.y),0.0);
            }

            float sdRoundedBox( in float2 p, in float2 pos, in float2 b, in float r )
            {
                return sdBox(p, pos, b) - r;
            }

            float4 drawBoss(float4 posFragCoord, float4 typeFrameFlipState) {
                float4 posOffset, fragCoordFrame, translate;
                float3 sizeFlip;

                posOffset.xy = posFragCoord.xy;
                posOffset.zw = bStateLoc[typeFrameFlipState.w].xy;
                fragCoordFrame.xy = posFragCoord.zw;
                fragCoordFrame.zw = int2(typeFrameFlipState.y, 0);
                translate = 0..xxxx;
                sizeFlip.xy = bSizeFrame[typeFrameFlipState.w];
                sizeFlip.z = 1.0;

                [flatten]
                if (typeFrameFlipState.w == _BOSS_RASENGAN) {
                    translate = float4(20, 0, 20, 0);
                    fragCoordFrame.zw = float2(fmod(typeFrameFlipState.y, 15),
                        -floor(typeFrameFlipState.y / 15.));
                }
                else if (typeFrameFlipState.w == _BOSS_UP) {
                    fragCoordFrame.z = bSizeFrame[_BOSS_UP].z - fragCoordFrame.z;
                }

                return spriteTemplate(posOffset, fragCoordFrame, translate, sizeFlip,
                    _BossTex, 1.3);
            }

            float4 drawRasengan(float4 posFragCoord, float4 typeFrameFlipState) {
                float4 posOffset, fragCoordFrame, translate;
                float3 sizeFlip;

                posOffset.xy = posFragCoord.xy;
                posOffset.zw = float2(0, 128);
                fragCoordFrame.xy = posFragCoord.zw;
                translate = 0..xxxx;
                sizeFlip.xy = float2(1024, 128);
                sizeFlip.z = 1.;
                fragCoordFrame.zw = float2(fmod(typeFrameFlipState.y, 2.),
                    -floor(typeFrameFlipState.y / 2.));

                return spriteTemplate(posOffset, fragCoordFrame, translate, sizeFlip,
                    _BossTex, 0.8);
            }

            void draw1(inout float4 col, in float2 fragCoord,
                in renderObjStruct renderObj, inout float depth,
                in float characterDepth) {

                float4 o = drawBoss(
                    float4(renderObj.posDirHP.xy, fragCoord),
                        float4(renderObj.charAnimHistFrame.x,
                            floor(renderObj.charAnimHistFrame.w),
                            floor(renderObj.posDirHP.z / 10.),
                            floor(renderObj.charAnimHistFrame.y)));
                col.rgba = lerp(col.rgba, o.rgba, o.a);
                depth = lerp(depth, characterDepth, o.a);
            }

            void draw2(inout float4 col, in float2 fragCoord,
                in renderObjStruct renderObj, inout float depth,
                in float characterDepth) {

                float4 o = drawRasengan(
                    float4(renderObj.posDirHP.xy, fragCoord),
                        float4(renderObj.charAnimHistFrame.x,
                        renderObj.charAnimHistFrame.w,
                        renderObj.posDirHP.z,
                        renderObj.charAnimHistFrame.y));
                col.rgba = lerp(col.rgba, o.rgba, o.a);
                depth = lerp(depth, characterDepth, o.a);
            }

            // x is between 0, 1
            float specialMoveAnim(float x, float multiplier) {
                float3 fn;
                fn.x = smoothstep(0., 1., -(x * 3. - 1.2)) * 0.5;
                fn.y = smoothstep(0., 1., -(x * 3. - 2.8)) * 0.5;
                fn.z = sin((x - 0.45) * 100.) * lerp(0.05, 0., x * 1.7) + 0.505;
                return max(fn.x + fn.y, x < 0.56 ? fn.z : 0.) * multiplier;
            }

            v2f vert (appdata v)
            {
                v2f o;

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

                //return o;

                // o.vertex = UnityObjectToClipPos(v.vertex);
                // o.uv = v.uv;
                return o;
            }

            fragOut frag (v2f i)
            {
                clip(i.uv.z);
                float2 fragCoord = i.uv.xy * _Resolution.xy;
                float4 charSelect = LoadValue(_StateTex, txCharSelect);
                float4 stagePosZContIndex = LoadValue(_StateTex, txStagePosZContIndex);
                float posToScreen = max(stagePosZContIndex.x - MIDDLE_X, 0.0);
                float4 state = LoadValue(_StateTex, txState);
                state.zw *= 6.;

                fragOut o;
                o.depth = 0.;
                o.col = 0..xxxx;

                // Depth is flipped on the Quest
                #if !(UNITY_REVERSED_Z)
                _MaxDepth = -_MaxDepth;
                _MinDepth = -_MinDepth;
                #endif

                if (floor(state.x) == 0.) {

                    float4 pointers = LoadValue(_StateTex, txPointers);

                    // Player 1 selection
                    float2 selection;
                    selection.x = charSelect.z > -1. ? charSelect.z :
                        charSelect.x > -1. ? charSelect.x : -1.;
                    // Player 2 selection
                    selection.y = charSelect.w > -1. ? charSelect.w :
                        charSelect.y > -1. ? charSelect.y : -1.;

                    o.col = _UITex.Load(int3(fragCoord.x + 332, fragCoord.y, 0));
                    float depth = _MaxDepth;

                    if (selection.x > -1.) {
                        float4 pose = charPose(_CharTex, uint4(0..xx, charA[selection.x]),
                            (fragCoord + float2(10., 50.)) * 1.5);
                        o.col = lerp(o.col, pose, pose.a);
                        depth = lerp(depth, _MaxDepth, pose.a);
                    }

                    if (selection.y > -1.) {
                        float4 pose = charPose(_CharTex, uint4(0..xx, charA[selection.y]),
                            (fragCoord + float2(-110., 50.)) * 1.5);
                        o.col = lerp(o.col, pose, pose.a);
                        depth = lerp(depth, _MaxDepth, pose.a);
                    }

                    float4 btns = _UITex.Load(int3(fragCoord.x + 152, fragCoord.y, 0));
                    o.col = lerp(o.col, btns, btns.a);
                    depth = lerp(depth, _MaxDepth, btns.a);

                    if (selection.x > -1.) {
                        float b0 = sdRoundedBox(fragCoord, charBtnArr[selection.x], 8..xx, 10.);
                        o.col = lerp(float4(0., 1..xxx), o.col, smoothstep(0.5, 3.0, abs(b0)));
                        depth = lerp(depth, _MaxDepth, b0);
                    }

                    if (selection.y > -1.) {
                        float b1 = sdRoundedBox(fragCoord, charBtnArr[selection.y], 8..xx, 10.);
                        o.col = lerp(float4(1..xx, 0., 1.), o.col, smoothstep(0.5, 3.0, abs(b1)));
                        depth = lerp(depth, _MaxDepth, b1);
                    }

                    float4 p1Cursor = cursor1(_UITex, floor(pointers.xy), fragCoord + float2(30, 20));
                    float4 p2Cursor = cursor2(_UITex, floor(pointers.zw), fragCoord + float2(30, 20));
                    o.col = lerp(o.col, p1Cursor, p1Cursor.a);
                    o.col = lerp(o.col, p2Cursor, p2Cursor.a);
                    depth = lerp(depth, _MaxDepth + LAYER_CURSOR, saturate(p1Cursor.a + p2Cursor.a));
                    o.depth = depth;
                }
                // Actual Game
                else {
                    float2 bgUV = i.uv * float2((_BGTex_TexelSize.w * 0.125) / _BGTex_TexelSize.z, 0.125);
                    bgUV.y -= fmod(floor(state.z), 8) * 0.125;
                    bgUV.x += stagePosZContIndex.x / _Resolution.x * 0.5;
                    o.col = float4(tex2D(_BGTex, bgUV).rgb, 1.0);
                    o.depth = _MinDepth;

                    renderObjStruct renderObj1;

                    renderObj1.skip = (stagePosZContIndex.z >= _BOSS) ? 0. : 1.;
                    renderObj1.posDirHP = LoadValue(_StateTex, txBossPosDirHP);
                    renderObj1.posDirHP.x -= posToScreen;
                    renderObj1.charAnimHistFrame = LoadValue(_StateTex, txBossAnimHistFrame);

                    renderObjStruct renderObj2;

                    renderObj2.skip =
                        (floor(renderObj1.charAnimHistFrame.y) == _BOSS_RASENGAN &&
                            step(133., renderObj1.posDirHP.z) > 0.) ? 0. : 1.;
                    renderObj2.posDirHP = float4(-1150, -25, 1., 0.);
                    renderObj2.charAnimHistFrame = float4(0..xxx, floor(fmod(_Time.w * 2., 3.)));

                    if (!renderObj1.skip) {
                        float bossDepth = lerp(_MinDepth, _MaxDepth,
                            (UPPER_Y - renderObj1.posDirHP.y) / UPPER_Y);
                        draw1(o.col, fragCoord, renderObj1, o.depth, bossDepth);
                    }
                    if (!renderObj2.skip) {
                        float rasDepth = lerp(_MinDepth, _MaxDepth,
                            (UPPER_Y - renderObj2.posDirHP.y) / UPPER_Y);
                        draw2(o.col, fragCoord, renderObj2, o.depth, rasDepth);
                    }
                    // HP bar

                    if (stagePosZContIndex.z >= _BOSS) {
                        float4 posDirHP = renderObj1.posDirHP;
                        o.col = RenderBar(fragCoord, float4(30. + posDirHP.x + 20.,
                            posDirHP.y + 110., 20., 3.), o.col,
                            0..xxx, 0..xxx, o.depth);
                        o.col = RenderBar(fragCoord, float4(30. + posDirHP.x + 20. * posDirHP.w * 0.00667,
                            posDirHP.y + 110., 20. * posDirHP.w * 0.00667, 3.), o.col,
                            bossCol1, bossCol2, o.depth);
                    }

                    float4 score = _StateTex.Load(int3(txScore, 0));
                    float4 char1HP;
                    char1HP.x = _StateTex.Load(int3(txP1PosDirHP, 0)).w;
                    char1HP.yzw = _StateTex.Load(int3(txP1CharAnimHistFrame, 0)).xyw;
                    float4 char2HP;
                    char2HP.x = _StateTex.Load(int3(txP2PosDirHP, 0)).w;
                    char2HP.yzw = _StateTex.Load(int3(txP2CharAnimHistFrame, 0)).xyw;

                    // Special move

                    if (char1HP.z == _SPECIAL) {
                        float2 anim;
                        char1HP.w /= frameA[_SPECIAL];
                        anim.x = lerp(0., 50., char1HP.w);
                        anim.y = specialMoveAnim(char1HP.w, 400.) - 200.;
                        float4 sm = specialMove(_CharTex, int4(-55 + anim.x, -15 + anim.y,
                            charA[char1HP.y]), fragCoord);
                        o.col = lerp(o.col, sm, sm.a);
                        o.depth = lerp(o.depth, _MaxDepth + LAYER_CURSOR, sm.a);

                    }
                    if (char2HP.z == _SPECIAL) {
                        float2 anim;
                        char2HP.w /= frameA[_SPECIAL];
                        anim.x = lerp(0., 50., char2HP.w);
                        anim.y = specialMoveAnim(char2HP.w, 400.) - 200.;
                        float4 sm = specialMove(_CharTex, int4(-55 + anim.x, -15 + anim.y,
                            charA[char2HP.y]), fragCoord);
                        o.col = lerp(o.col, sm, sm.a);
                        o.depth = lerp(o.depth, _MaxDepth + LAYER_CURSOR, sm.a);
                    }

                    float blink = step(0, sin(_Time.y * 8));

                    float4 UI = hpBar(_UITex, uint4(35, 146, 54 * char1HP.x * 0.01, 0), fragCoord);
                    UI += hpBar(_UITex, uint4(91, 146, 54 * char2HP.x * 0.01, 1), fragCoord);
                    UI += profilePic(_CharTex, uint4(4, 147, charA[char1HP.y]), fragCoord);
                    UI += profilePic(_CharTex, uint4(147, 147, charA[char2HP.y]), fragCoord);
                    UI += specialUI(_UITex, uint2(0, 5), fragCoord);
                    if (score.z >= 100.) UI += specialHint(_UITex, uint2(19, 14), fragCoord * 1.2) * (1. - blink);
                    if (score.w >= 100.) UI += specialHint(_UITex, uint2(119, 14), fragCoord * 1.2) * (1. - blink);

                    UI += hpUI(_UITex, uint2(0, 143), fragCoord);

                    o.col = lerp(o.col, UI, UI.a);
                    o.depth = lerp(o.depth, _MaxDepth + LAYER_UI, UI.a);

                    score.zw *= 0.01;
                    o.col = RenderBar(fragCoord, float4(8. + 39.5 * score.z, 9., 39.5 * score.z, 3.), o.col,
                        specialCol1, specialCol2, o.depth);
                    o.col = RenderBar(fragCoord, float4(93. + 39.5 * score.w, 9., 39.5 * score.w, 3.), o.col,
                        specialCol1, specialCol2, o.depth);
                    
                    UI = PrintInt((i.uv + float2(-0.2, -0.91)) * 28.0, floor(score.x), 5);
                    UI += PrintInt((i.uv + float2(-0.63, -0.91)) * 28.0, floor(score.y), 5);
                    float zombCount = PrintInt((i.uv + float2(-0.41, -0.88)) * 10.0, floor(stagePosZContIndex.y), 2);
                    UI += float4(zombCount.xx, 0., zombCount);

                    o.col = lerp(o.col, UI, UI.a);
                    o.depth = lerp(o.depth, _MaxDepth + LAYER_UI, UI.a);

                    if (stagePosZContIndex.z == _CONTINUE) {
                        float4 go = goForward(_UITex, uint2(130, 70), fragCoord);
                        o.col = lerp(o.col, go, blink * go.a);
                        o.depth = lerp(o.depth, _MaxDepth + LAYER_UI, blink * go.a);
                    }

                    if (stagePosZContIndex.z == _CUTSCENE1) {
                        o.col.rgb *= 0.05;
                        if (abs(stagePosZContIndex.w - 6.) <= 6.) {
                            float4 bossScene = _BossTex.Load(int3(fragCoord.x + 1860., fragCoord.y + 842., 0));
                            o.col = lerp(o.col, bossScene, bossScene.a);
                            float4 bossText = bossText1(_UITex, uint2(15, 10), fragCoord);
                            o.col = lerp(o.col, bossText, bossText.a *
                                step(6., stagePosZContIndex.w));
                        }
                        if (abs(stagePosZContIndex.w - 18.) <= 6.) {
                            float4 player = charFace(_CharTex, int4(-10, 0.,
                                charA[char1HP.y]), fragCoord);
                            o.col = lerp(o.col, player, player.a);
                            player = charFace(_CharTex, int4(60, 0.,
                                charA[char2HP.y]), fragCoord);
                            o.col = lerp(o.col, player, player.a);
                            float4 playerText = playerText1(_UITex, uint2(15, 10), fragCoord);
                            o.col = lerp(o.col, playerText, playerText.a *
                                step(18., stagePosZContIndex.w));
                        }
                        o.depth = _MaxDepth + LAYER_CURSOR;
                    }
                    else if (stagePosZContIndex.z == _CREDITS) {
                        o.col *= 1. - min(stagePosZContIndex.w, 1.);
                        float4 creditCol = credits(_UITex, uint2(0, 0), fragCoord);
                        creditCol += PrintInt((i.uv + float2(-0.26, -0.32)) * 10.0,
                            floor(min(score.y + score.x, 99999)), 5);
                        o.col += creditCol * min(stagePosZContIndex.w, 1.);
                        o.depth = _MaxDepth + LAYER_CURSOR;
                    }
                }
                o.depth += i.uv.w;
                return o;
            }
            ENDCG
        }
    }
}
