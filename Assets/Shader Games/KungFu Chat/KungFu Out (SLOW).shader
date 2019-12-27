Shader "Games/KungFu Out" {
    Properties {
        _StateTex ("State Input", 2D) = "black" {}
        _OutTex ("Output", 2D) = "black" {}
        _TextTex ("Text Block Image", 2D) = "black" {} 
        _BGTex ("Background Image", 2D) = "black" {}
        _FGTex ("Foreground Image", 2D) = "black" {}
        _CharTex ("Sprite Texture", 2D) = "black" {}
        _ZombTex ("Zombie Texture", 2D) = "black" {}
        _BossTex ("Boss Texture", 2D) = "black" {}
        _UITex ("Menu Texture", 2D) = "black" {}
        //_Test ("Test", Vector) = (0., 0., 0., 0.)
    }
    SubShader
    {
        Pass
        {
            Name "KungFu Out"
            CGPROGRAM

            #include "UnityCustomRenderTexture.cginc"
            #include "KungFu_Include.cginc"
            #pragma vertex CustomRenderTextureVertexShader
            #pragma fragment pixel_shader
            #pragma fragmentoption ARB_precision_hint_nicest
            #pragma target 3.0

            #define iResolution _OutTex_TexelSize.zw
            #define specialCol1 float3(0.2, 0.2, 1.2)
            #define specialCol2 float3(0.3, 0.1, 1.1)
            #define bossCol1 float3(0.1, 1.0, 0.1)
            #define bossCol2 float3(0.1, 0.5, 0.1)

            //RWStructuredBuffer<float4> buffer : register(u1);
            Texture2D<float4> _StateTex;
            Texture2D<float4> _TextTex;
            Texture2D<float4> _CharTex;
            Texture2D<float4> _ZombTex;
            Texture2D<float4> _BossTex;
            Texture2D<float4> _UITex;
            sampler2D _BGTex;
            sampler2D _FGTex;
            float4 _OutTex_TexelSize;
            float4 _BGTex_TexelSize;
            //float4 _Test;
            float2 time;

            struct renderObjStruct
            {
                float skip;
                float4 posDirHP;
                float4 charAnimHistFrame;
                // float4 hitbox;
                // float4 punch;
            };

            float sdSquare(in float2 p, in float2 pos, in float2 size) {
                float2 d = abs(p - pos) - size;
                return length(max(d,0.0));
            }

            float3 RenderBar(float2 pos, float4 barPosSize, float3 col,
                float3 barCol1, float3 barCol2) {
                float t = sdSquare(pos, barPosSize.xy, barPosSize.zw);
                return lerp(lerp(barCol2, barCol1, (5 + barPosSize.x - pos.x) * 0.05), 
                    col, smoothstep(0., 0.5, t));
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

            // Character animations

            float4 drawCharacter(float4 posFragCoord, float4 typeFrameFlipState) {
                float4 posOffset, fragCoordFrame, translate;
                float3 sizeFlip;

                posOffset.xy = posFragCoord.xy;
                posOffset.zw = charA[typeFrameFlipState.x] + 
                    locSizeA[typeFrameFlipState.w].xy;
                fragCoordFrame.xy = posFragCoord.zw;
                sizeFlip.xy = locSizeA[typeFrameFlipState.w].zw;
                sizeFlip.z = typeFrameFlipState.z;
                translate = typeFrameFlipState.w < _KNOCKED_STAND ?
                    charTrans[typeFrameFlipState.x][typeFrameFlipState.w] : 0..xxxx;
                fragCoordFrame.zw = float2(typeFrameFlipState.y, 0);

                [flatten]
                if (typeFrameFlipState.w == _HIT ||
                    typeFrameFlipState.w == _POSE ||
                    typeFrameFlipState.w == _SPECIAL) {
                    fragCoordFrame.zw = 0..xx;
                }
                else if (typeFrameFlipState.w == _KNOCKED_STAND) {
                    translate = 
                        lerp(float4(charStandTrans[typeFrameFlipState.x][0].xy,
                                    charStandTrans[typeFrameFlipState.x][1].xy),
                             float4(charStandTrans[typeFrameFlipState.x][0].zw,
                                    charStandTrans[typeFrameFlipState.x][1].zw),
                             typeFrameFlipState.y / (frameA[_KNOCKED_STAND] - 1.));
                }

                return spriteTemplate(posOffset, fragCoordFrame, translate, sizeFlip,
                    _CharTex, typeFrameFlipState.x == _XIEXE ? 1.45 : SCALE);
            }

            // Zombie animations

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

            // Draw object from render object struct

            void draw(inout float3 col, in float2 fragCoord,
                in renderObjStruct renderObj) {

                float4 o = 0..xxxx;
                [branch]
                if (renderObj.charAnimHistFrame.x < 100.) {
                    o = drawCharacter(
                        float4(renderObj.posDirHP.xy, fragCoord),
                        float4(renderObj.charAnimHistFrame.x,
                            floor(renderObj.charAnimHistFrame.w),
                            renderObj.posDirHP.z,
                            floor(renderObj.charAnimHistFrame.y)));
                }
                else if (renderObj.charAnimHistFrame.x < 200.) {
                    o = drawZombie(
                        float4(renderObj.posDirHP.xy, fragCoord),
                        float4(renderObj.charAnimHistFrame.x - 100.,
                            floor(renderObj.charAnimHistFrame.w),
                            floor(renderObj.posDirHP.z / 10.),
                            floor(renderObj.charAnimHistFrame.y)));
                }
                else if (renderObj.charAnimHistFrame.x < 300.) {
                    o = drawRasengan(
                            float4(renderObj.posDirHP.xy, fragCoord),
                                float4(renderObj.charAnimHistFrame.x - 200.,
                                renderObj.charAnimHistFrame.w,
                                renderObj.posDirHP.z,
                                renderObj.charAnimHistFrame.y));
                }
                else {
                    o = drawBoss(
                            float4(renderObj.posDirHP.xy, fragCoord),
                            float4(renderObj.charAnimHistFrame.x - 300.,
                                floor(renderObj.charAnimHistFrame.w),
                                renderObj.posDirHP.z,
                                floor(renderObj.charAnimHistFrame.y)));
                }
                col = lerp(col, o.xyz, o.a);
            }
            
            // x is between 0, 1
            float specialMoveAnim(float x, float multiplier) {
                float3 fn;
                fn.x = smoothstep(0., 1., -(x * 3. - 1.2)) * 0.5;
                fn.y = smoothstep(0., 1., -(x * 3. - 2.8)) * 0.5;
                fn.z = sin((x - 0.45) * 100.) * lerp(0.05, 0., x * 1.7) + 0.505;
                return max(fn.x + fn.y, x < 0.56 ? fn.z : 0.) * multiplier;
            }

            float4 pixel_shader (v2f_customrendertexture IN) : SV_TARGET
            {
                float2 uv = IN.globalTexcoord.xy;
                float2 fragCoord = uv * iResolution;

                float4 state = LoadValue(_StateTex, txState);
                state.zw *= 6.;
                float4 charSelect = LoadValue(_StateTex, txCharSelect);
                
                float3 col = 0..xxx;

                // Character Select
                if (floor(state.x) == 0.) {
                    float4 pointers = LoadValue(_StateTex, txPointers);

                    // Player 1 selection
                    float2 selection;
                    selection.x = charSelect.z > -1. ? charSelect.z :
                        charSelect.x > -1. ? charSelect.x : -1.;
                    // Player 2 selection
                    selection.y = charSelect.w > -1. ? charSelect.w :
                        charSelect.y > -1. ? charSelect.y : -1.;

                    col = _UITex.Load(int3(fragCoord.x + 332, fragCoord.y, 0));

                    if (selection.x > -1.) {
                        float4 pose = charPose(_CharTex, uint4(0..xx, charA[selection.x]),
                            (fragCoord + float2(10., 50.)) * 1.5);
                        col = lerp(col, pose.rgb, pose.a);
                    }

                    if (selection.y > -1.) {
                        float4 pose = charPose(_CharTex, uint4(0..xx, charA[selection.y]),
                            (fragCoord + float2(-110., 50.)) * 1.5);
                        col = lerp(col, pose.rgb, pose.a);
                    }

                    float4 btns = _UITex.Load(int3(fragCoord.x + 152, fragCoord.y, 0));
                    col = lerp(col, btns.rgb, btns.a);
                    
                    if (selection.x > -1.) {
                        float b0 = sdRoundedBox(fragCoord, charBtnArr[selection.x], 8..xx, 10.);
                        col = lerp(float3(0., 1..xx), col, smoothstep(0.5, 3.0, abs(b0)));
                    }

                    if (selection.y > -1.) {
                        float b1 = sdRoundedBox(fragCoord, charBtnArr[selection.y], 8..xx, 10.);
                        col = lerp(float3(1..xx, 0.), col, smoothstep(0.5, 3.0, abs(b1)));
                    }

                    float4 p1Cursor = cursor1(_UITex, floor(pointers.xy), fragCoord + float2(30, 20));
                    float4 p2Cursor = cursor2(_UITex, floor(pointers.zw), fragCoord + float2(30, 20));
                    col = lerp(col, p1Cursor.rgb, p1Cursor.a);
                    col = lerp(col, p2Cursor.rgb, p2Cursor.a);
                }
                // Actual Game
                else {
                    // uint4 p1ButtonBuffer = LoadValue(_StateTex, txP1ButtonBuffer);
                    // uint4 p2ButtonBuffer = LoadValue(_StateTex, txP2ButtonBuffer);
                    // uint4 p1ButtonBuffer2 = LoadValue(_StateTex, txP1ButtonBuffer2);
                    // uint4 p2ButtonBuffer2 = LoadValue(_StateTex, txP2ButtonBuffer2);
                    // float2 buttonFilter = LoadValue(_StateTex, txButtonFilter);
                    float4 score = LoadValue(_StateTex, txScore);
                    float4 stagePosZContIndex = LoadValue(_StateTex, txStagePosZContIndex);
                    float4 sortedQueue = LoadValue(_StateTex, txRenderQueue);
                    float posToScreen = max(stagePosZContIndex.x - MIDDLE_X, 0.0);

                    // Render queue in array
                    renderObjStruct renderObj[MAX_ARR_SIZE];

                    renderObj[0].skip = 0.;
                    renderObj[0].posDirHP = LoadValue(_StateTex, txP1PosDirHP);
                    renderObj[0].posDirHP.x -= posToScreen;
                    renderObj[0].posDirHP.y = round(renderObj[0].posDirHP.y);
                    renderObj[0].charAnimHistFrame = LoadValue(_StateTex, txP1CharAnimHistFrame);
                    // renderObj[0].hitbox = LoadValue(_StateTex, txP1HitBox);
                    // renderObj[0].punch = LoadValue(_StateTex, txP1Punch);

                    renderObj[1].skip = 0.;
                    renderObj[1].posDirHP = LoadValue(_StateTex, txP2PosDirHP);
                    renderObj[1].posDirHP.x -= posToScreen;
                    renderObj[1].posDirHP.y = round(renderObj[1].posDirHP.y);
                    renderObj[1].charAnimHistFrame = LoadValue(_StateTex, txP2CharAnimHistFrame);
                    // renderObj[1].hitbox = LoadValue(_StateTex, txP2HitBox);
                    // renderObj[1].punch = LoadValue(_StateTex, txP2Punch);
                    
                    [unroll]
                    for (int i = 0; i < MAX_ARR_SIZE - 4; i++) {
                        renderObj[i + 2].skip = 0.;
                        renderObj[i + 2].posDirHP = LoadValue(_StateTex, int2(i, txZombiesPosDirHP.y));
                        renderObj[i + 2].posDirHP.x -= posToScreen;
                        renderObj[i + 2].posDirHP.y = round(renderObj[i + 2].posDirHP.y);
                        renderObj[i + 2].charAnimHistFrame = LoadValue(_StateTex, int2(i, txZombiesAnimHistFrame.y));
                        renderObj[i + 2].charAnimHistFrame.x += 100;
                        // renderObj[i + 2].hitbox = LoadValue(_StateTex, int2(i, txZombiesHitBox.y));
                        // renderObj[i + 2].punch = LoadValue(_StateTex, int2(i, txZombiesPunch.y));
                    }

                    // Boss
                    renderObj[MAX_ARR_SIZE - 1].skip = (stagePosZContIndex.z >= _BOSS) ? 0. : 1.;
                    renderObj[MAX_ARR_SIZE - 1].posDirHP = LoadValue(_StateTex, txBossPosDirHP);
                    renderObj[MAX_ARR_SIZE - 1].posDirHP.x -= posToScreen;
                    renderObj[MAX_ARR_SIZE - 1].charAnimHistFrame = LoadValue(_StateTex, txBossAnimHistFrame);
                    renderObj[MAX_ARR_SIZE - 1].charAnimHistFrame.x += 300;
                    // renderObj[MAX_ARR_SIZE - 1].hitbox = LoadValue(_StateTex, txBossHitBox);
                    // renderObj[MAX_ARR_SIZE - 1].punch = LoadValue(_StateTex, txBossPunch);

                    // Rasengan
                    renderObj[MAX_ARR_SIZE - 2].skip =
                        (floor(renderObj[MAX_ARR_SIZE - 1].charAnimHistFrame.y) == _BOSS_RASENGAN &&
                            step(133., renderObj[MAX_ARR_SIZE - 1].posDirHP.z) > 0.) ? 0. : 1.;
                    renderObj[MAX_ARR_SIZE - 2].posDirHP = float4(-1150, -25, 1., 0.);
                    renderObj[MAX_ARR_SIZE - 2].charAnimHistFrame = float4(0..xxx, floor(fmod(_Time.w * 2., 3.)));
                    renderObj[MAX_ARR_SIZE - 2].charAnimHistFrame.x += 200;

                    time = state.zw;

                    float2 bgUV = uv * float2((_BGTex_TexelSize.w * 0.125) / _BGTex_TexelSize.z, 0.125);
                    bgUV.y -= fmod(floor(time.x), 8) * 0.125;
                    bgUV.x += stagePosZContIndex.x / iResolution.x * 0.5;
                    col = tex2D(_BGTex, bgUV);

                    // Depth sorted indices
                    int indices[MAX_ARR_SIZE];

                    int j;
                    [unroll]
                    for (j = MAX_ARR_SIZE - 1; j >= MAX_ARR_SIZE / 2; j--) {
                        indices[j] = floor(fmod(sortedQueue.y, MAX_ARR_SIZE));
                        sortedQueue.y /= MAX_ARR_SIZE;
                    }
                    [unroll]
                    for (; j >= 0; j--) {
                        indices[j] = floor(fmod(sortedQueue.x, MAX_ARR_SIZE));
                        sortedQueue.x /= MAX_ARR_SIZE;
                    }

                    [unroll]
                    for (j = MAX_ARR_SIZE - 1; j >= 0; j--) {
                        if (renderObj[indices[j]].skip) continue;
                        draw(col, fragCoord, renderObj[indices[j]]);
                    }

                    // Special move

                    if (renderObj[0].charAnimHistFrame.y == _SPECIAL) {
                        float2 anim;
                        renderObj[0].charAnimHistFrame.w /= frameA[_SPECIAL];
                        anim.x = lerp(0., 50., renderObj[0].charAnimHistFrame.w);
                        anim.y = specialMoveAnim(renderObj[0].charAnimHistFrame.w, 400.) - 200.;
                        float4 sm = specialMove(_CharTex, int4(-55 + anim.x, -15 + anim.y,
                            charA[renderObj[0].charAnimHistFrame.x]), fragCoord);
                        col.rgb = lerp(col.rgb, sm.rgb, sm.a);

                    }
                    if (renderObj[1].charAnimHistFrame.y == _SPECIAL) {
                        float2 anim;
                        renderObj[1].charAnimHistFrame.w /= frameA[_SPECIAL];
                        anim.x = lerp(0., 50., renderObj[1].charAnimHistFrame.w);
                        anim.y = specialMoveAnim(renderObj[1].charAnimHistFrame.w, 400.) - 200.;
                        float4 sm = specialMove(_CharTex, int4(-55 + anim.x, -15 + anim.y,
                            charA[renderObj[1].charAnimHistFrame.x]), fragCoord);
                        col.rgb = lerp(col.rgb, sm.rgb, sm.a);
                    }

                    float4 fg = tex2D(_FGTex, bgUV);
                    col = lerp(col, fg, fg.r + fg.b > 0.8 ? 0 : 1);
                    float blink = step(0, sin(_Time.y * 8));

                    float4 UI = hpBar(_UITex, uint4(35, 146, 54 * renderObj[0].posDirHP.w * 0.01, 0), fragCoord);
                    UI += hpBar(_UITex, uint4(91, 146, 54 * renderObj[1].posDirHP.w * 0.01, 1), fragCoord);
                    UI += profilePic(_CharTex, uint4(4, 147, charA[renderObj[0].charAnimHistFrame.x]), fragCoord);
                    UI += profilePic(_CharTex, uint4(147, 147, charA[renderObj[1].charAnimHistFrame.x]), fragCoord);
                    UI += specialUI(_UITex, uint2(0, 5), fragCoord);
                    if (score.z >= 100.) UI += specialHint(_UITex, uint2(19, 14), fragCoord * 1.2) * (1. - blink);
                    if (score.w >= 100.) UI += specialHint(_UITex, uint2(119, 14), fragCoord * 1.2) * (1. - blink);
                    col = lerp(col, UI, UI.a);

                    col += hpUI(_UITex, uint2(0, 143), fragCoord);

                    score.zw *= 0.01;
                    col = RenderBar(fragCoord, float4(8. + 39.5 * score.z, 9., 39.5 * score.z, 3.), col,
                        specialCol1, specialCol2);
                    col = RenderBar(fragCoord, float4(93. + 39.5 * score.w, 9., 39.5 * score.w, 3.), col,
                        specialCol1, specialCol2);

                    float zombCount = PrintInt((uv + float2(-0.41, -0.88)) * 10.0, floor(stagePosZContIndex.y), 2);
                    col.xyz += float3(zombCount, zombCount, 0.);
                    
                    col.xyz += PrintInt((uv + float2(-0.2, -0.91)) * 28.0, floor(score.x), 5);
                    col.xyz += PrintInt((uv + float2(-0.63, -0.91)) * 28.0, floor(score.y), 5);

                    // HP bar

                    if (stagePosZContIndex.z >= _BOSS) {
                        float4 posDirHP = renderObj[MAX_ARR_SIZE - 1].posDirHP;
                        col = RenderBar(fragCoord, float4(30. + posDirHP.x + 20.,
                            posDirHP.y + 110., 20., 3.), col,
                            0..xxx, 0..xxx);
                        col = RenderBar(fragCoord, float4(30. + posDirHP.x + 20. * posDirHP.w * 0.004,
                            posDirHP.y + 110., 20. * posDirHP.w * 0.004, 3.), col,
                            bossCol1, bossCol2);
                    }

                    if (stagePosZContIndex.z == _CONTINUE) {
                        float4 go = goForward(_UITex, uint2(130, 70), fragCoord);
                        col = lerp(col, go, blink * go.a );
                    }

                    if (stagePosZContIndex.z == _CUTSCENE1) {
                        col *= 0.05;
                        if (abs(stagePosZContIndex.w - 6.) <= 6.) {
                            float4 bossScene = _BossTex.Load(int3(fragCoord.x + 1860., fragCoord.y + 842., 0));
                            col = lerp(col, bossScene.rgb, bossScene.a);
                            float4 bossText = bossText1(_UITex, uint2(15, 10), fragCoord);
                            col = lerp(col, bossText.rgb, bossText.a *
                                step(6., stagePosZContIndex.w));
                        }
                        if (abs(stagePosZContIndex.w - 18.) <= 6.) {
                            float4 player = charFace(_CharTex, int4(-10, 0.,
                                charA[renderObj[0].charAnimHistFrame.x]), fragCoord);
                            col = lerp(col, player.rgb, player.a);
                            player = charFace(_CharTex, int4(60, 0.,
                                charA[renderObj[1].charAnimHistFrame.x]), fragCoord);
                            col = lerp(col, player.rgb, player.a);
                            float4 playerText = playerText1(_UITex, uint2(15, 10), fragCoord);
                            col = lerp(col, playerText.rgb, playerText.a *
                                step(18., stagePosZContIndex.w));
                        }
                    }
                    else if (stagePosZContIndex.z == _CREDITS) {
                        col *= 1. - min(stagePosZContIndex.w, 1.);
                        float3 creditCol = credits(_UITex, uint2(0, 0), fragCoord).rgb;
                        creditCol += PrintInt((uv + float2(-0.26, -0.32)) * 10.0,
                            floor(min(score.y + score.x, 99999)), 5);
                        col += creditCol * min(stagePosZContIndex.w, 1.);
                    }
                }

                //// Sprite Testing

                // float4 char1 = drawCharacter(
                //         float4(float2(80., 12.), fragCoord),
                //         float4(_1001,
                //             floor(fmod(_Time.w, frameA[_STAND_IDLE])),
                //             _Test.w,
                //             floor(_STAND_IDLE)));
                // col = lerp(col, char1.rgb, char1.a);

                // float4 char2 = drawCharacter(
                //         float4(float2(80., 12.) - _Test.xy, fragCoord),
                //         float4(_1001,
                //             floor(fmod(_Time.w, frameA[floor(_Test.z)])),
                //             _Test.w,
                //             floor(_Test.z)));
                // col = lerp(col, char2.rgb, char2.a);

                // float4 char3 = drawCharacter(
                //         float4(float2(80., 12.), fragCoord),
                //         float4(_1001,
                //             floor(fmod(_Time.w, frameA[_KNOCKED_IDLE])),
                //             _Test.w,
                //             floor(_KNOCKED_IDLE)));
                // col = lerp(col, char3.rgb, char3.a);

                // float4 char4 = drawCharacter(
                //         float4(float2(40., 12.) - _Test.xy, fragCoord),
                //         float4(_SCRN,
                //             floor(fmod(_Time.w, frameA[_PUNCH_LEFT])),
                //             _Test.w,
                //             floor(_PUNCH_LEFT)));
                // col = lerp(col, char4.rgb, char4.a);

                //// Boss Testing

                // float4 bossPosDirHP = LoadValue(_StateTex, txBossPosDirHP);
                // float4 bossAnimHistFrame = LoadValue(_StateTex, txBossAnimHistFrame);
                // float4 boss = drawBoss(
                //                 float4(bossPosDirHP.xy, fragCoord),
                //                 float4(bossAnimHistFrame.x,
                //                     floor(bossAnimHistFrame.w),
                //                     bossPosDirHP.z,
                //                     floor(bossAnimHistFrame.y)));
                // col.xyz = lerp(col.xyz, boss.xyz, boss.a);
                // col.xyz += PrintInt((uv + float2(-0.3, -0.7)) * 28.0, floor(bossAnimHistFrame.y), 1);
                // col.xyz += PrintInt((uv + float2(-0.3, -0.63)) * 28.0, floor(renderObj[MAX_ARR_SIZE - 1].posDirHP.w), 3);
                
                //buffer[0] = bossPosDirHP;

                //if (floor(bossAnimHistFrame.y) == _BOSS_RASENGAN &&
                //         step(133., bossPosDirHP.z)) {
                //     float4 rasengan = drawRasengan(
                //                     float4(-1150, -25, fragCoord),
                //                     float4(bossAnimHistFrame.x,
                //                         floor(fmod(_Time.w * 2., 3.)),
                //                         bossPosDirHP.z,
                //                         bossAnimHistFrame.y));
                //     col.xyz = lerp(col.xyz, rasengan.xyz * 2.0, rasengan.a);
                //}

                //// Hitbox Debug

                // float4 hitbox = LoadValue(_StateTex, txBossHitBox) + float4(renderObj[MAX_ARR_SIZE - 1].posDirHP.xy, 0..xx);
                // if (all(abs(fragCoord - hitbox.xy) < hitbox.zw)) {
                //     col += float3(0.5,0,0);
                // }
                
                // float4 punch = float4(LoadValue(_StateTex, txBossPunch).xy, 50., 45.) + float4(0..xx, renderObj[MAX_ARR_SIZE - 1].posDirHP.xy);
                // if (distance(punch.zw, fragCoord) < punch.x) {
                //     col += float3(0.5,0,0);
                // }
                // for (int i = 2; i < 10; i++) {
                //     float4 hitbox = renderObj[i].hitbox + float4(renderObj[i].posDirHP.xy, 0..xx);
                //     if (all(abs(fragCoord - hitbox.xy) < hitbox.zw)) {
                //         col += float3(0.5,0,0);
                //     }
                //     float4 punch = renderObj[i].punch + float4(0..xx, renderObj[i].posDirHP.xy);
                //     if (distance(punch.zw, fragCoord) < punch.x) {
                //         col += float3(0.5,0,0);
                //     }
                // }

                //// Input Debug

                //col.xyz += PrintInt((uv + float2(-0.2, -0.7)) * 28.0, floor(max(buttonFilter.x * 10, 0)), 5);
                // col.xyz += PrintInt((uv + float2(-0.63, -0.7)) * 28.0, floor(max(buttonFilter.y * 10, 0)), 5);

                // if (abs(fragCoord.y - 45) <= 3 && fragCoord.x > 60 && fragCoord.x <= 80) {
                //     uint4 input = p1ButtonBuffer;
                //     fragCoord.x = floor((fragCoord.x - 61) * 0.5);
                //     input.xyz /= pow(4, fragCoord.x);
                //     input.xyz = input.xyz % 4;
                //     if (fragCoord.y < 44) {
                //         col.xyz = input.x < 1 ? 0..xxx : input.x < 2 ? float3(1, 0, 0) : float3(0, 1, 0);
                //     }
                //     else if (fragCoord.y < 46) {
                //         col.xyz = input.y < 1 ? 0..xxx : input.y < 2 ? float3(0, 0, 1) : float3(1, 1, 0);
                //     }
                //     else {
                //         col.xyz = input.z < 1 ? 0..xxx : 1..xxx;
                //     }
                // }
                // if (abs(fragCoord.y - 45) <= 3 && fragCoord.x > 80 && fragCoord.x <= 100) {
                //     uint4 input = p1ButtonBuffer2;
                //     fragCoord.x = floor((fragCoord.x - 81) * 0.5);
                //     input.xyz /= pow(4, fragCoord.x);
                //     input.xyz = input.xyz % 4;
                //     if (fragCoord.y < 44) {
                //         col.xyz = input.x < 1 ? 0..xxx : input.x < 2 ? float3(1, 0, 0) : float3(0, 1, 0);
                //     }
                //     else if (fragCoord.y < 46) {
                //         col.xyz = input.y < 1 ? 0..xxx : input.y < 2 ? float3(0, 0, 1) : float3(1, 1, 0);
                //     }
                //     else {
                //         col.xyz = input.z < 1 ? 0..xxx : 1..xxx;
                //     }
                // }
                //buffer[0] = float4(p1ButtonBuffer.w, (p1ButtonBuffer.z % 4).xxx);

                return float4(col, 1.0);
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}