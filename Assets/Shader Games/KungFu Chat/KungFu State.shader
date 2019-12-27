Shader "Games/KungFu State" {
    Properties {
        _StateTex ("State Input", 2D) = "black" {}
        _ControlIn ("Players Joystick Input", 2D) = "black" {}
    }
    SubShader
    {
        Pass
        {
            Name "KungFu State"
            CGPROGRAM
            #include "UnityCustomRenderTexture.cginc"
            #include "KungFu_Include.cginc"
            #pragma vertex CustomRenderTextureVertexShader
            #pragma fragment pixel_shader
            #pragma fragmentoption ARB_precision_hint_nicest
            #pragma target 3.0

            // Tags to tell which player killed what zombie for score keeping
            #define DEATH_TRIGGER1 1234.0
            #define DEATH_TRIGGER2 2345.0
            #define DEATH_TRIGGER3 3456.0 // No points
            #define BOSS_ARMOR_L 3.
            #define BOSS_ARMOR_H 7.

           // RWStructuredBuffer<float4> buffer : register(u1);

            Texture2D<float4> _StateTex;
            Texture2D<float4> _ControlIn;
            float4 _StateTex_TexelSize;

            void StoreMulti(int4 re, float4 va, inout float4 fragColor, int2 px )
            {
                fragColor = (all(px - re.xy >= 0) &&
                    all(px - re.zw <= 0)) ? va : fragColor;
            }

            float pow5Pulse( float c, float w, float x )
            {
                x = abs(x - c);
                if( x>w ) return 0.0;
                x /= w;
                return 1.0 - pow(x, 4)*(3.0-2.0*x);
            }

            float expStep( float x, float k, float n )
            {
                return min(1., exp( -k*pow(x,n) ) );
            }

            // return true if the rectangle and circle are colliding
            int RectCircleIntersect(float2 Zdist, float4 circle, float4 rect,
                    float far){
                [flatten]
                if (abs(Zdist.x - Zdist.y) > far) return 0;
                float2 distXY = abs(circle.zw - rect.zw - rect.xy * 0.5);
                [flatten]
                if (any(distXY > (rect.xy * 0.5 + circle.xx))) return 0;
                [flatten]
                if (any(distXY <= (rect.xy * 0.5))) return 1;
                float2 dxy = distXY - rect.xy * 0.5;
                return (dxy.x*dxy.x+dxy.y*dxy.y <= (circle.x*circle.x));
            }

            void doButtonBuffer (inout uint4 inputBuffer, in float2 joysticks,
                    in float button) {
                // Stop at the 20th bit
                inputBuffer.xyz = (inputBuffer.xyz * 4) % 1048576;
                // Left/Right
                inputBuffer.x += abs(joysticks.x) < 0.2 ? 0 :
                    joysticks.x < 0. ? 1 : 2;
                // Up/Down
                inputBuffer.y += abs(joysticks.y) < 0.2 ? 0 :
                    joysticks.y < 0. ? 1 : 2;
                // Button press
                inputBuffer.z += button > 0.5 ? 1 : 0;
            }

            void copyBuffer (in uint4 ibuf, inout uint4 obuf) {
                obuf.xyz = (obuf.xyz * 4) % 1048576;
                ibuf.xyz = (ibuf.xyz / 262144) % 4;
                obuf.xyz += ibuf.xyz;
            }
            
            void countSort(inout float2 arr[MAX_ARR_SIZE], in float place) {
                int i, freq[RANGE];
                float2 output[MAX_ARR_SIZE];

                [unroll]
                for (i = 0; i < RANGE; i++)
                    freq[i] = 0;
                [unroll]
                for(i = 0; i < MAX_ARR_SIZE; i++)
                    freq[floor((arr[i].y / place) % RANGE)]++;
                [unroll]
                for(i = 1; i < RANGE; i++)
                    freq[i] += freq[i - 1];
                [unroll]
                for(i = MAX_ARR_SIZE - 1; i >= 0; i--) {
                    output[freq[floor((arr[i].y / place) % RANGE)] - 1] = arr[i];
                    freq[floor((arr[i].y / place) % RANGE)]--;
                }
                [unroll]
                for(i = 0; i < MAX_ARR_SIZE; i++)
                    arr[i] = output[i];
            }

            void radixSort(inout float2 arr[MAX_ARR_SIZE], in float maxx) {

                float multiple = 1.0;
                while (abs(maxx) > EPSILON)
                {
                    countSort(arr, multiple);
                    multiple *= 10;
                    maxx /= 10;
                }
            }

            void damageCalc(inout float4 punch, inout float4 posDirHP,
                in float3 damage, in float doArmorDamage) {
                //punch.y = any(damage.xy > 1.) ? -1. : punch.y;
                posDirHP.w = (punch.y < 0.) ?
                    posDirHP.w - damage.z :
                    posDirHP.w;
                punch.z += (doArmorDamage > 0. && punch.y < 0. && damage.z > 0.) ?
                    1. : 0.;
                punch.y = max(punch.y < 0. && damage.z > 0. ?
                    3.6 : punch.y - 0.2, -1.);
            }

            float4 pixel_shader (v2f_customrendertexture IN) : SV_TARGET
            {   
                float2 uv = IN.globalTexcoord.xy;
                int2 px = int2(uv * _StateTex_TexelSize.zw);

                // Player 1:
                //    joysticks.x = Left/Right
                //    joysticks.y = Up/Down
                // Player 2:
                //    joysticks.z = Left/Right
                //    joysticks.w = Up/Down

                float4 joysticks = _ControlIn.Load(int3(0,0,0));
                joysticks = clamp(joysticks * 1.5, -2, 2);
                //joysticks.w = 1;
                //joysticks.y = 1;

                float4 buttons = _ControlIn.Load(int3(1,0,0));
                //buttons.xy = 1;

                float4 state = LoadValue(_StateTex, txState);
                float4 score = LoadValue(_StateTex, txScore);
                float4 p1PosDirHP = LoadValue(_StateTex, txP1PosDirHP);
                float4 p2PosDirHP = LoadValue(_StateTex, txP2PosDirHP);

                float4 p1HitBox = LoadValue(_StateTex, txP1HitBox);
                float4 p2HitBox = LoadValue(_StateTex, txP2HitBox);

                float4 p1Punch = LoadValue(_StateTex, txP1Punch);
                float4 p2Punch = LoadValue(_StateTex, txP2Punch);
                float4 p1p2Stagger = LoadValue(_StateTex, txP1P2Stagger);

                // Boss
                float4 bossAnimHistFrame = LoadValue(_StateTex, txBossAnimHistFrame);

                // Character #, Animation #, Previous animation #,
                // Current animation frame
                float4 p1CharAnimHistFrame = LoadValue(_StateTex, txP1CharAnimHistFrame);
                float4 p2CharAnimHistFrame = LoadValue(_StateTex, txP2CharAnimHistFrame);
                float4 stagePosZContIndex = LoadValue(_StateTex, txStagePosZContIndex);
                float2 buttonFilter = LoadValue(_StateTex, txButtonFilter);
                
                // Character Select
                float4 pointers = LoadValue(_StateTex, txPointers);
                float4 charSelect = LoadValue(_StateTex, txCharSelect);
                float readyState = LoadValue(_StateTex, txReadyState).x;

                // Down, Left, Right, Attack
                uint4 p1ButtonBuffer = LoadValue(_StateTex, txP1ButtonBuffer);
                uint4 p2ButtonBuffer = LoadValue(_StateTex, txP2ButtonBuffer);
                uint4 p1ButtonBuffer2 = LoadValue(_StateTex, txP1ButtonBuffer2);
                uint4 p2ButtonBuffer2 = LoadValue(_StateTex, txP2ButtonBuffer2);

                // state.z = buttons.w > 0.5 ? 0. : state.z + 0.1;
                // state.w = buttons.w > 0.5 ? 0. : state.w + 0.2;
                state.z = buttons.w > 0.5 ? 0. : state.z + 0.016666667;
                state.w = buttons.w > 0.5 ? 0. : state.w + 0.033333333;
                state.zw *= 6.;
                state.x = readyState > 0.5 ? 1.0 : state.x;

                p1CharAnimHistFrame.x = charSelect.z;
                p2CharAnimHistFrame.x = charSelect.w;

                if (state.z < 1.0) {
                    state.xy = 0.;
                    stagePosZContIndex = float4(0..xx, 1.0, 0.);
                    p1PosDirHP.x = MIDDLE_X;
                    p2PosDirHP.x = MIDDLE_X - 45;
                    p1PosDirHP.w = p2PosDirHP.w = 100.0;
                    p1HitBox = p2HitBox = float4(12, 40, 22, 40);
                    p1Punch = p2Punch = 0..xxxx;
                    p1p2Stagger = 0..xxxx;
                    score = float4(0..xx, 50..xx);
                    p1ButtonBuffer = p2ButtonBuffer = 0..xxxx;
                    pointers = float4(30., 180., 180., 180.);
                    charSelect = clamp(charSelect, -1., NUM_CHARS);
                    //charSelect = -1..xxxx;
                }

                // buffer[0] = float4(p1CharAnimHistFrame.x, state.z,
                //     charSelect.zw);

                float4 col = 0..xxxx;

                p1PosDirHP.xy = state.x < 0.5 ? MIDDLE_X : p1PosDirHP.xy;
                p2PosDirHP.xy = state.x < 0.5 ? MIDDLE_X - 45 : p2PosDirHP.xy;

                if (p1ButtonBuffer.w > 2) {
                    doButtonBuffer(p1ButtonBuffer, joysticks.xy, buttons.x);
                    doButtonBuffer(p2ButtonBuffer, joysticks.zw, buttons.y);
                    copyBuffer(p1ButtonBuffer, p1ButtonBuffer2);
                    copyBuffer(p2ButtonBuffer, p2ButtonBuffer2);
                    p1ButtonBuffer.w = 0;
                }
                p1ButtonBuffer.w += 1;

                // Player Logic
                if (px.y <= txStagePosZContIndex.y) {
                    if (px.y == txP1P2Stagger.y && px.x > txP1P2Stagger.x) return 0..xxxx;

                    float3 p1p2Hit = 0..xxx;
                    if (stagePosZContIndex.z >= _BOSS) {
                        float bossPunch = LoadValue(_StateTex, txBossPunch).r;
                        float2 bossXY = LoadValue(_StateTex, txBossPosDirHP).xy;
                        p1p2Hit.x += RectCircleIntersect(float2(bossXY.y, p1PosDirHP.y),
                            float4(bossPunch, 0., 50., 45.) + float4(0..xx, bossXY),
                            p1HitBox + float4(0..xx, p1PosDirHP.xy), 8.);
                        p1p2Hit.y += RectCircleIntersect(float2(bossXY.y, p2PosDirHP.y),
                            float4(bossPunch, 0., 50., 45.) + float4(0..xx, bossXY),
                            p2HitBox + float4(0..xx, p2PosDirHP.xy), 8.);
                    }
                    else {
                        [unroll]
                        for (int i = 0; i < 8; i++) {
                            float4 zPunch = _StateTex.Load(int3(i, txZombiesPunch.y, 0));
                            float4 zPos = _StateTex.Load(int3(i, txZombiesPosDirHP.y, 0));
                            float zType = _StateTex.Load(int3(i, txZombiesAnimHistFrame.y, 0)).x;
                            p1p2Hit.x += RectCircleIntersect(float2(zPos.y, p1PosDirHP.y),
                                zPunch + float4(0..xx, zPos.xy),
                                p1HitBox + float4(0..xx, p1PosDirHP.xy),
                                zType == _ZBOOM ? 6 : 4);
                            p1p2Hit.y += RectCircleIntersect(float2(zPos.y, p2PosDirHP.y),
                                zPunch + float4(0..xx, zPos.xy),
                                p2HitBox + float4(0..xx, p2PosDirHP.xy),
                                zType == _ZBOOM ? 6 : 4);
                            p1p2Hit.z += zType == _ZBOOM ? 1. : 0.;
                        }
                    }

                    // Special move, cost 100% special meter
                    p1CharAnimHistFrame.y = buttonFilter.x > 11.5 && score.z >= 100.
                        ? _SPECIAL : p1CharAnimHistFrame.y;

                    p2CharAnimHistFrame.y = buttonFilter.y > 11.5 && score.w >= 100.
                        ? _SPECIAL : p2CharAnimHistFrame.y;

                    // Got hit
                    p1CharAnimHistFrame.y = p1p2Hit.x > 0 && p1CharAnimHistFrame.y <
                        _KNOCKED_IDLE ? _HIT : p1CharAnimHistFrame.y;

                    p2CharAnimHistFrame.y = p1p2Hit.y > 0 && p2CharAnimHistFrame.y <
                        _KNOCKED_IDLE ? _HIT : p2CharAnimHistFrame.y;

                    int2 p1State = int2(p1CharAnimHistFrame.yz);
                    int2 p2State = int2(p2CharAnimHistFrame.yz);

                    // Player 1
                    p1PosDirHP.xy = (p1State.x > _WALK) ? p1PosDirHP.xy :
                        p1PosDirHP.xy + joysticks.xy * SPEED;

                    //p1PosDirHP.xy = float2(201,10);

                    p1PosDirHP.x = clamp(p1PosDirHP, stagePosZContIndex.x - UPPER_X,
                            stagePosZContIndex.x + MIDDLE_X);
                    p1PosDirHP.y = clamp(p1PosDirHP.y, LOWER_Y, UPPER_Y);

                    // Player 2
                    p2PosDirHP.xy = (p2State.x > _WALK) ? p2PosDirHP.xy :
                        p2PosDirHP.xy + joysticks.zw * SPEED;

                    //p2PosDirHP.xy = float2(151,10);

                    p2PosDirHP.x = clamp(p2PosDirHP, stagePosZContIndex.x - UPPER_X,
                            stagePosZContIndex.x + MIDDLE_X);
                    p2PosDirHP.y = clamp(p2PosDirHP.y, LOWER_Y, UPPER_Y);

                    [flatten]
                    if (p1CharAnimHistFrame.y < _KNOCKED_IDLE) {
                        p1PosDirHP.z = joysticks.x > EPSILON ?
                            0. : joysticks.x < -EPSILON ? 1. : p1PosDirHP.z;
                    }
                    [flatten]
                    if (p2CharAnimHistFrame.y < _KNOCKED_IDLE) {
                        p2PosDirHP.z = joysticks.z > EPSILON ?
                            0. : joysticks.z < -EPSILON ? 1. : p2PosDirHP.z;
                    }

                    // Save last state
                    p1CharAnimHistFrame.z = p1CharAnimHistFrame.y;

                    [branch]
                    if (p1State.x == _STAND_IDLE) {
                        p1HitBox = p1p2Stagger.z > 0.0 ? 0..xxxx : float4(12.0, 40.0, 22.0, 40.0);
                        p1p2Stagger.z -= p1p2Stagger.z > 0.0 ? 1.0 : 0.0;
                        p1Punch = 0..xxxx;
                        p1CharAnimHistFrame.w = fmod(state.w, frameA[_STAND_IDLE]);
                        p1CharAnimHistFrame.y = abs(joysticks.x) + abs(joysticks.y) > EPSILON ?
                            _WALK : _STAND_IDLE;
                        p1CharAnimHistFrame.y = buttons.x > 0.5 ? _PUNCH_LEFT :
                            p1CharAnimHistFrame.y;
                    } else if (p1State.x == _WALK) {
                        p1HitBox =  p1p2Stagger.z > 0.0 ? 0..xxxx : float4(12.0, 40.0, 22.0, 40.0);
                        p1p2Stagger.z -= p1p2Stagger.z > 0.0 ? 1.0 : 0.0;
                        p1Punch = 0..xxxx;
                        p1CharAnimHistFrame.w = fmod(state.w, frameA[_WALK]);
                        p1CharAnimHistFrame.y = abs(joysticks.x) + abs(joysticks.y) > EPSILON ?
                            _WALK : _STAND_IDLE;
                        p1CharAnimHistFrame.y = buttons.x > 0.5 ? _PUNCH_LEFT :
                            p1CharAnimHistFrame.y;
                    } else if (p1State.x == _PUNCH_LEFT) {
                        p1p2Stagger.z = 0.0;
                        p1CharAnimHistFrame.w = !(p1State.x == p1State.y) ?
                            0.0 : p1CharAnimHistFrame.w + 0.25;
                        p1CharAnimHistFrame.w = min(p1CharAnimHistFrame.w, frameA[_PUNCH_LEFT]);
                        p1HitBox = float4(12.0, 40.0,
                            p1PosDirHP.z < 0.5 ? 18.0 : 26.0, 40.0);
                        p1Punch = float4(lerp(0., PUNCHDIST,
                            pow5Pulse(4.0, 2.0, p1CharAnimHistFrame.w)), 0.,
                            p1PosDirHP.z < 0.5 ? 40.0 : 5.0, 60.0);
                        [flatten]
                        if (round(p1CharAnimHistFrame.w) == frameA[_PUNCH_LEFT]) {
                            p1CharAnimHistFrame.y = abs(joysticks.x) + abs(joysticks.y) > EPSILON ?
                                _WALK : _STAND_IDLE;
                            p1CharAnimHistFrame.y = buttons.x > 0.5 ? _PUNCH_RIGHT :
                                p1CharAnimHistFrame.y;
                            p1CharAnimHistFrame.w = 0.0;
                        }
                    } else if (p1State.x == _PUNCH_RIGHT) {
                        p1p2Stagger.z = 0.0;
                        p1CharAnimHistFrame.w = !(p1State.x == p1State.y) ?
                            0.0 : p1CharAnimHistFrame.w + 0.25;
                        p1CharAnimHistFrame.w = min(p1CharAnimHistFrame.w, frameA[_PUNCH_RIGHT]);
                        p1HitBox = float4(12.0, 40.0,
                            p1PosDirHP.z < 0.5 ? 18.0 : 26.0, 40.0);
                        p1Punch = float4(lerp(0., PUNCHDIST,
                            pow5Pulse(4.0, 2.0, p1CharAnimHistFrame.w)), 0.,
                            p1PosDirHP.z < 0.5 ? 40.0 : 5.0, 60.0);
                        [flatten]
                        if (round(p1CharAnimHistFrame.w) == frameA[_PUNCH_RIGHT]) {
                            p1CharAnimHistFrame.y = abs(joysticks.x) + abs(joysticks.y) > EPSILON ?
                                _WALK : _STAND_IDLE;
                            p1CharAnimHistFrame.y = buttons.x > 0.5 ? _PUNCH_LEFT :
                                p1CharAnimHistFrame.y;
                        }
                    }
                    else if (p1State.x == _HIT) {
                        p1Punch = 0..xxxx;
                        bool sameState = (p1CharAnimHistFrame.z == p1CharAnimHistFrame.y);
                        p1CharAnimHistFrame.w = sameState ? p1CharAnimHistFrame.w + 0.04 : 0.0;
                        [flatten]
                        if (p1CharAnimHistFrame.w > 0.5) {
                            p1PosDirHP.w -= p1p2Hit.z > 0.5 ||
                                (bossAnimHistFrame.y == _BOSS_RASENGAN)? 10.0 : 5.0;
                            p1p2Stagger.z += 1.0;
                            score.z = min(score.z + 5.0, 100.);
                            p1CharAnimHistFrame.y = (p1PosDirHP.w <= 0 || p1p2Stagger.z > 2.0) ?
                                _KNOCKED_DOWN : _STAND_IDLE;
                            p1CharAnimHistFrame.w = 0.;
                        }
                    }
                    else if (p1State.x == _KNOCKED_IDLE) {
                        p1Punch = 0..xxxx;
                        p1HitBox = 0..xxxx;
                        p1CharAnimHistFrame.w = fmod(state.w, frameA[_KNOCKED_IDLE]);
                        p1CharAnimHistFrame.y = buttons.x > 0.5 ? _KNOCKED_STAND :
                            p1CharAnimHistFrame.y;
                        p1PosDirHP.w = buttons.x > 0.5 ? 100. : p1PosDirHP.w;
                        p1p2Stagger.x = buttons.x > 0.5 ? 0.0 : p1p2Stagger.x;
                        score.x = buttons.x > 0.5 ? 0.0 : score.x;
                    }
                    else if (p1State.x == _KNOCKED_DOWN) {
                        p1Punch = 0..xxxx;
                        p1HitBox = 0..xxxx;
                        bool sameState = (p1CharAnimHistFrame.z == p1CharAnimHistFrame.y);
                        p1CharAnimHistFrame.w = sameState ?
                            min(p1CharAnimHistFrame.w + 0.1, frameA[_KNOCKED_DOWN]) : 0.0;
                        [flatten]
                        if (p1CharAnimHistFrame.w == frameA[_KNOCKED_DOWN]) {
                            p1CharAnimHistFrame.y = p1PosDirHP.w <= 0 ? _KNOCKED_IDLE :
                                _KNOCKED_STAND;
                            p1CharAnimHistFrame.w = 0.;
                        }
                    }
                    else if (p1State.x == _KNOCKED_STAND) {
                        p1Punch = 0..xxxx;
                        p1HitBox = 0..xxxx;
                        bool sameState = (p1CharAnimHistFrame.z == p1CharAnimHistFrame.y);
                        p1CharAnimHistFrame.w = sameState ?
                            min(p1CharAnimHistFrame.w + 0.1, frameA[_KNOCKED_STAND]) : 0.0;
                        p1CharAnimHistFrame.y = (p1CharAnimHistFrame.w == frameA[_KNOCKED_STAND]) ?
                            _STAND_IDLE : p1CharAnimHistFrame.y;
                    }
                    else if (p1State.x == _SPECIAL) {
                        // Cover entire screen
                        p1HitBox = 0..xxxx;
                        bool sameState = (p1CharAnimHistFrame.z == p1CharAnimHistFrame.y);
                        p1CharAnimHistFrame.w = sameState ?
                            min(p1CharAnimHistFrame.w + 0.065, frameA[_SPECIAL]) : 0.0;
                        p1Punch = float4(lerp(0., 300.,
                            pow5Pulse(5., 3., p1CharAnimHistFrame.w)),
                            0..xxx);
                        [flatten]
                        if (p1CharAnimHistFrame.w == frameA[_SPECIAL]) {
                            score.z -= 100.0;
                            p1CharAnimHistFrame.y = _STAND_IDLE;
                        }
                    }

                    // Save last state
                    p2CharAnimHistFrame.z = p2CharAnimHistFrame.y;

                    [branch]
                    if (p2State.x == _STAND_IDLE) {
                        p2HitBox = p1p2Stagger.w > 0.0 ? 0..xxxx : float4(12.0, 40.0, 22.0, 40.0);
                        p1p2Stagger.w -= p1p2Stagger.w > 0.0 ? 1.0 : 0.0;
                        p2Punch = 0..xxxx;
                        p2CharAnimHistFrame.w = fmod(state.w, frameA[_STAND_IDLE]);
                        p2CharAnimHistFrame.y = abs(joysticks.z) + abs(joysticks.w) > EPSILON ?
                            _WALK : _STAND_IDLE;
                        p2CharAnimHistFrame.y = buttons.y > 0.5 ? _PUNCH_LEFT :
                            p2CharAnimHistFrame.y;
                    } else if (p2State.x == _WALK) {
                        p2HitBox = p1p2Stagger.w > 0.0 ? 0..xxxx : float4(12.0, 40.0, 22.0, 40.0);
                        p1p2Stagger.w -= p1p2Stagger.w > 0.0 ? 1.0 : 0.0;
                        p2Punch = 0..xxxx;
                        p2CharAnimHistFrame.w = fmod(state.w, frameA[_WALK]);
                        p2CharAnimHistFrame.y = abs(joysticks.z) + abs(joysticks.w) > EPSILON ?
                            _WALK : _STAND_IDLE;
                        p2CharAnimHistFrame.y = buttons.y > 0.5 ? _PUNCH_LEFT :
                            p2CharAnimHistFrame.y;
                    } else if (p2State.x == _PUNCH_LEFT) {
                        p1p2Stagger.w = 0.;
                        p2CharAnimHistFrame.w = !(p2State.x == p2State.y) ?
                            0.0 : p2CharAnimHistFrame.w + 0.25;
                        p2CharAnimHistFrame.w = min(p2CharAnimHistFrame.w, frameA[_PUNCH_LEFT]);
                        p2HitBox = float4(12.0, 40.0,
                            p2PosDirHP.z < 0.5 ? 18.0 : 26.0, 40.0);
                        p2Punch = float4(lerp(0., PUNCHDIST,
                            pow5Pulse(4.0, 2.0, p2CharAnimHistFrame.w)), 0.,
                            p2PosDirHP.z < 0.5 ? 40.0 : 5.0, 60.0);
                        [flatten]
                        if (round(p2CharAnimHistFrame.w) == frameA[_PUNCH_LEFT]) {
                            p2CharAnimHistFrame.y = abs(joysticks.z) + abs(joysticks.w) > EPSILON ?
                                _WALK : _STAND_IDLE;
                            p2CharAnimHistFrame.y = buttons.y > 0.5 ? _PUNCH_RIGHT :
                                p2CharAnimHistFrame.y;
                            p2CharAnimHistFrame.w = 0.0;
                        }
                    } else if (p2State.x == _PUNCH_RIGHT) {
                        p1p2Stagger.w = 0.;
                        p2CharAnimHistFrame.w = !(p2State.x == p2State.y) ?
                            0.0 : p2CharAnimHistFrame.w + 0.25;
                        p2CharAnimHistFrame.w = min(p2CharAnimHistFrame.w, frameA[_PUNCH_RIGHT]);
                        p2HitBox = float4(12.0, 40.0,
                            p2PosDirHP.z < 0.5 ? 18.0 : 26.0, 40.0);
                        p2Punch = float4(lerp(0., PUNCHDIST,
                            pow5Pulse(4.0, 2.0, p2CharAnimHistFrame.w)), 0.,
                            p2PosDirHP.z < 0.5 ? 40.0 : 5.0, 60.0);
                        [flatten]
                        if (round(p2CharAnimHistFrame.w) == frameA[_PUNCH_RIGHT]) {
                            p2CharAnimHistFrame.y = abs(joysticks.z) + abs(joysticks.w) > EPSILON ?
                                _WALK : _STAND_IDLE;
                            p2CharAnimHistFrame.y = buttons.y > 0.5 ? _PUNCH_LEFT :
                                p2CharAnimHistFrame.y;
                        }
                    }
                    else if (p2State.x == _HIT) {
                        p2Punch = 0..xxxx;
                        bool sameState = (p2CharAnimHistFrame.z == p2CharAnimHistFrame.y);
                        p2CharAnimHistFrame.w = sameState ? p2CharAnimHistFrame.w + 0.04 : 0.0;
                        [flatten]
                        if (p2CharAnimHistFrame.w > 0.5) {
                            p2PosDirHP.w -= p1p2Hit.z > 0.5 ||
                                (bossAnimHistFrame.y == _BOSS_RASENGAN) ? 10.0 : 5.0;
                            p1p2Stagger.w += 1.0;
                            score.w = min(score.w + 5.0, 100.);
                            p2CharAnimHistFrame.y = (p2PosDirHP.w <= 0 || p1p2Stagger.w > 2.0) ?
                                _KNOCKED_DOWN : _STAND_IDLE;
                            p2CharAnimHistFrame.w = 0.;
                        }
                    }
                    else if (p2State.x == _KNOCKED_IDLE) {
                        p2Punch = 0..xxxx;
                        p2HitBox = 0..xxxx;
                        p2CharAnimHistFrame.w = fmod(state.w, frameA[_KNOCKED_IDLE]);
                        p2CharAnimHistFrame.y = buttons.y > 0.5 ? _KNOCKED_STAND :
                            p2CharAnimHistFrame.y;
                        p2PosDirHP.w = buttons.y > 0.5 ? 100. : p2PosDirHP.w;
                        p1p2Stagger.y = buttons.y > 0.5 ? 0.0 : p1p2Stagger.y;
                        score.y = buttons.y > 0.5 ? 0.0 : score.y;
                    }
                    else if (p2State.x == _KNOCKED_DOWN) {
                        p2Punch = 0..xxxx;
                        p2HitBox = 0..xxxx;
                        p1p2Stagger.w = 0.0;
                        bool sameState = (p2CharAnimHistFrame.z == p2CharAnimHistFrame.y);
                        p2CharAnimHistFrame.w = sameState ?
                            min(p2CharAnimHistFrame.w + 0.1, frameA[_KNOCKED_DOWN]) : 0.0;
                        [flatten]
                        if (p2CharAnimHistFrame.w == frameA[_KNOCKED_DOWN]) {
                            p2CharAnimHistFrame.y = p2PosDirHP.w <= 0 ? _KNOCKED_IDLE :
                                _KNOCKED_STAND;
                            p2CharAnimHistFrame.w = 0.;
                        }
                    }
                    else if (p2State.x == _KNOCKED_STAND) {
                        p2Punch = 0..xxxx;
                        p2HitBox = 0..xxxx;
                        bool sameState = (p2CharAnimHistFrame.z == p2CharAnimHistFrame.y);
                        p2CharAnimHistFrame.w = sameState ?
                            min(p2CharAnimHistFrame.w + 0.1, frameA[_KNOCKED_STAND]) : 0.0;
                        p2CharAnimHistFrame.y = (p2CharAnimHistFrame.w == frameA[_KNOCKED_STAND]) ?
                            _STAND_IDLE : p2CharAnimHistFrame.y;
                    }
                    else if (p2State.x == _SPECIAL) {
                        // Cover entire screen
                        p2HitBox = 0..xxxx;
                        bool sameState = (p2CharAnimHistFrame.z == p2CharAnimHistFrame.y);
                        p2CharAnimHistFrame.w = sameState ?
                            min(p2CharAnimHistFrame.w + 0.065, frameA[_SPECIAL]) : 0.0;
                        p2Punch = float4(lerp(0., 300.,
                            pow5Pulse(5., 3., p2CharAnimHistFrame.w)),
                            0..xxx);
                        [flatten]
                        if (p2CharAnimHistFrame.w == frameA[_SPECIAL]) {
                            score.w -= 100.0;
                            p2CharAnimHistFrame.y = _STAND_IDLE;
                        }
                    }

                    state.zw *= 0.166666667;
                    StoreValue(txState,                 state, col, px);
                    StoreValue(txP1PosDirHP,            p1PosDirHP, col, px);
                    StoreValue(txP2PosDirHP,            p2PosDirHP, col, px);
                    StoreValue(txP1CharAnimHistFrame,   p1CharAnimHistFrame, col, px);
                    StoreValue(txP2CharAnimHistFrame,   p2CharAnimHistFrame, col, px);
                    StoreValue(txP1ButtonBuffer,        p1ButtonBuffer, col, px);
                    StoreValue(txP2ButtonBuffer,        p2ButtonBuffer, col, px);
                    StoreValue(txP1ButtonBuffer2,       p1ButtonBuffer2, col, px);
                    StoreValue(txP2ButtonBuffer2,       p2ButtonBuffer2, col, px);
                    StoreValue(txP1HitBox,              p1HitBox, col, px);
                    StoreValue(txP2HitBox,              p2HitBox, col, px);
                    StoreValue(txP1Punch,               p1Punch, col, px);
                    StoreValue(txP2Punch,               p2Punch, col, px);
                    StoreValue(txP1P2Stagger,           p1p2Stagger, col, px);
                }

                // Shared Region

                if (px.y == txScore.y) {
                    // Boss
                    float4 bossPosDirHP = LoadValue(_StateTex, txBossPosDirHP);
                    float4 bossHitBox = LoadValue(_StateTex, txBossHitBox);
                    float4 bossPunch = LoadValue(_StateTex, txBossPunch);

                    float4 aZombiesPosDirHP[8];
                    float4 aZombiesAnimHistFrame[8];
                    // float4 aZombiesHitBox[8];

                    if (state.z < 1.0 || stagePosZContIndex.z > 0.5) {
                        [unroll]
                        for (int i = 0; i < 8; i++) {
                            aZombiesPosDirHP[i] = float4(max(p1PosDirHP.x, p2PosDirHP.x) +
                                250 + i * 10.0, i * 2.0, 0, 100);
                            aZombiesAnimHistFrame[i] = float4(float(px.x) % 2, _ZWALK.xx, 0);
                            // aZombiesHitBox[i] = float4(10, 40, 0..xx);
                        }
                    }
                    else {
                        [unroll]
                        for (int i = 0; i < 8; i++) {
                            aZombiesPosDirHP[i] =
                                LoadValue(_StateTex, int2(i, txZombiesPosDirHP.y));
                            aZombiesAnimHistFrame[i] =
                                LoadValue(_StateTex, int2(i, txZombiesAnimHistFrame.y));
                            // aZombiesHitBox[i] =
                            //     LoadValue(_StateTex, int2(i, txZombiesHitBox.y));
                            stagePosZContIndex.y -= aZombiesPosDirHP[i].w - EPSILON < -DEATH_TRIGGER1 ?
                                1 : 0;
                            score.xz += abs(aZombiesPosDirHP[i].w + DEATH_TRIGGER1) < EPSILON ? 10. : 0.0;
                            score.yw += abs(aZombiesPosDirHP[i].w + DEATH_TRIGGER2) < EPSILON ? 10. : 0.0;
                            score.zw = min(score.zw, 100.);
                        }
                    }

                    // Sort the render queue by position height
                    if (px.x == txRenderQueue.x) {

                        float4 renderQueue = 0..xxxx;
                        float2 renderIndicies[MAX_ARR_SIZE];
                        int i, j;

                        renderIndicies[0].y = p1PosDirHP.y;
                        renderIndicies[1].y = p2PosDirHP.y;
                        renderIndicies[0].x = 0;
                        renderIndicies[1].x = 1;
                        [unroll]
                        for (i = 2; i < MAX_ARR_SIZE - 2; i++) {
                            renderIndicies[i].x = i;
                            renderIndicies[i].y = aZombiesPosDirHP[i - 2].y;
                        }
                        renderIndicies[MAX_ARR_SIZE - 1].y = BOSS_DEFAULT_POS.y;
                        renderIndicies[MAX_ARR_SIZE - 2].y = BOSS_DEFAULT_POS.y + 1.;
                        renderIndicies[MAX_ARR_SIZE - 1].x = MAX_ARR_SIZE - 1;
                        renderIndicies[MAX_ARR_SIZE - 2].x = MAX_ARR_SIZE - 2;

                        radixSort(renderIndicies, UPPER_Y);

                        // Shifting floats cause bit shifting on the Quest
                        // doesn't work

                        [unroll]
                        for (i = 0; i < MAX_ARR_SIZE / 2; i++) {
                            renderQueue.x *= MAX_ARR_SIZE;
                            renderQueue.x += renderIndicies[i].x;
                        }
                        [unroll]
                        for (; i < MAX_ARR_SIZE; i++) {
                            renderQueue.y *= MAX_ARR_SIZE;
                            renderQueue.y += renderIndicies[i].x;
                        }

                        //StoreValue(txRenderQueue, renderQueue, col, px);
                        return renderQueue;
                    }

                    // Filter to recognize buttons
                    if (px.x == txButtonFilter.x) {
                        uint3 temp1, temp2;

                        //// Must be same direction
                        //// No one would notice anyway so I removed it
                        // float4 dir;
                        // dir = float4(input11.x, input12.x, input21.x, input22.x) / 4096;
                        // dir %= 4;
                        // dir.x = abs(int(input11.x) - int(input12.x)) < EPSILON ? 1. : -1.;
                        // dir.y = abs(int(input21.x) - int(input22.x)) < EPSILON ? 1. : -1.;

                        float2 score = 0..xx;
                        int i, j;

                        // Only recognizing dragon punch
                        [unroll]
                        for (i = 0; i < 20; i++) {
                            // P1 input
                            temp1.xyz = p1ButtonBuffer / pow(4, i);
                            temp1.xyz = temp1.xyz % 4;
                            // P2 input
                            temp2.xyz = p2ButtonBuffer / pow(4, i);
                            temp2.xyz = temp2.xyz % 4;

                            // Left / Right
                            score.x += (temp1.x != 0) ? 
                                DPFilter[i].x > 0.5 ? DPFilter[i].x : DPFilter[i].x - 1. :
                                DPFilter[i].x > 0.5 ? DPFilter[i].x - 1. : DPFilter[i].x;
                            score.y += (temp2.x != 0) ? 
                                DPFilter[i].x > 0.5 ? DPFilter[i].x : DPFilter[i].x - 1. :
                                DPFilter[i].x > 0.5 ? DPFilter[i].x - 1. : DPFilter[i].x;
                            
                            // Up / Down
                            score.x += (temp1.y == 1) ?
                                DPFilter[i].y > 0.5 ? DPFilter[i].y : DPFilter[i].y - 1. :
                                DPFilter[i].y > 0.5 ? DPFilter[i].y - 1. : DPFilter[i].y;
                            score.y += (temp2.y == 1) ? 
                                DPFilter[i].y > 0.5 ? DPFilter[i].y : DPFilter[i].y - 1. :
                                DPFilter[i].y > 0.5 ? DPFilter[i].y - 1. : DPFilter[i].y;
                            
                            // Button
                            // More points for true positive
                            score.x += (temp1.z > 0.5) ?
                                DPFilter[i].z > 0.5 ? 2. * DPFilter[i].z : DPFilter[i].z - 1. :
                                DPFilter[i].z > 0.5 ? DPFilter[i].z - 1. : DPFilter[i].z;
                            score.y += (temp2.z > 0.5) ?
                                DPFilter[i].z > 0.5 ? 2. * DPFilter[i].z : DPFilter[i].z - 1. :
                                DPFilter[i].z > 0.5 ? DPFilter[i].z - 1. : DPFilter[i].z;
                        }
                        [unroll]
                        for (j = 9; i < 30; i++, j++) {
                            //2nd buffer
                            temp1.xyz = p1ButtonBuffer2 / pow(4, j - 9);
                            temp1.xyz = temp1.xyz % 4;

                            temp2.xyz = p2ButtonBuffer2 / pow(4, j - 9);
                            temp2.xyz = temp2.xyz % 4;

                            score.x += (temp1.x != 0) ? 
                                DPFilter[j].x > 0.5 ? DPFilter[j].x : DPFilter[j].x - 1. :
                                DPFilter[j].x > 0.5 ? DPFilter[j].x - 1. : DPFilter[j].x;
                            score.y += (temp2.x != 0) ? 
                                DPFilter[j].x > 0.5 ? DPFilter[j].x : DPFilter[j].x - 1. :
                                DPFilter[j].x > 0.5 ? DPFilter[j].x - 1. : DPFilter[j].x;
                            
                            score.x += (temp1.y == 1) ?
                                DPFilter[j].y > 0.5 ? DPFilter[j].y : DPFilter[j].y - 1. :
                                DPFilter[j].y > 0.5 ? DPFilter[j].y - 1. : DPFilter[j].y;
                            score.y += (temp2.y == 1) ? 
                                DPFilter[j].y > 0.5 ? DPFilter[j].y : DPFilter[j].y - 1. :
                                DPFilter[j].y > 0.5 ? DPFilter[j].y - 1. : DPFilter[j].y;
                            
                            score.x += (temp1.z > 0.5) ?
                                DPFilter[j].z > 0.5 ? DPFilter[j].z : DPFilter[j].z - 1. :
                                DPFilter[j].z > 0.5 ? DPFilter[j].z - 1. : DPFilter[j].z;
                            score.y += (temp2.z > 0.5) ?
                                DPFilter[j].z > 0.5 ? DPFilter[j].z : DPFilter[j].z - 1. :
                                DPFilter[j].z > 0.5 ? DPFilter[j].z - 1. : DPFilter[j].z;
                        }
                        return score.xyxy;
                    }

                    // Level progression
                    float pos = max(p1PosDirHP.x, p2PosDirHP.x);
                    if (stagePosZContIndex.z == _CONTINUE) {
                        stagePosZContIndex.y = (pos > checkPoint[stagePosZContIndex.w]) ?
                            spawnMax[stagePosZContIndex.w] : 0.0;
                        stagePosZContIndex.z = (pos > checkPoint[stagePosZContIndex.w]) ?
                            stagePosZContIndex.w > TOTAL_STAGES - 2 ?
                                _CUTSCENE1 : _FIGHT : _CONTINUE;
                        stagePosZContIndex.w = stagePosZContIndex.z == _CUTSCENE1 ?
                            0. : stagePosZContIndex.w;
                    }
                    else if (stagePosZContIndex.z == _FIGHT) {
                        stagePosZContIndex.w = stagePosZContIndex.y <= 0 ?
                            stagePosZContIndex.w + 1 : stagePosZContIndex.w;
                        stagePosZContIndex.z = stagePosZContIndex.y <= 0 ?
                            _CONTINUE : _FIGHT;
                    }
                    else if (stagePosZContIndex.z == _BOSS) {
                        // Do stuff for the boss battle
                        bossAnimHistFrame.y = _BOSS_INTRO;
                        stagePosZContIndex.z = _END;
                    }
                    else if (stagePosZContIndex.z == _CUTSCENE1) {
                        stagePosZContIndex.z = stagePosZContIndex.w >= 24. ?
                            _BOSS : _CUTSCENE1;
                        stagePosZContIndex.w = stagePosZContIndex.w + 0.1;
                    }
                    else if (stagePosZContIndex.z == _END) {
                        stagePosZContIndex.z = bossPosDirHP.w <= 0. ?
                            _CREDITS : stagePosZContIndex.z;
                        stagePosZContIndex.w = 0.;
                    }
                    else if (stagePosZContIndex.z == _CREDITS) {
                        stagePosZContIndex.w = min(stagePosZContIndex.w + 0.01, 100.);
                    }

                    //stagePosZContIndex.z = _BOSS;
                    stagePosZContIndex.x += stagePosZContIndex.z == _CONTINUE ?
                        pos > stagePosZContIndex.x ? (pos - stagePosZContIndex.x) / 15.
                        : 0. : 0.;

                    // Boss
                    if (stagePosZContIndex.z >= _BOSS) {

                        // Interrupt on hit
                        float2 hitDetect;
                        float2 bossXY = float2(BOSS_DEFAULT_POS.x + max(stagePosZContIndex.x - MIDDLE_X, 0.0),
                            BOSS_DEFAULT_POS.y);
                        hitDetect.x = RectCircleIntersect(float2(p1PosDirHP.y, bossPosDirHP.y),
                            p1Punch + float4(0..xx, p1PosDirHP.xy),
                            bossHitBox + float4(0..xx, bossPosDirHP.xy), 8.);
                        hitDetect.y = RectCircleIntersect(float2(p2PosDirHP.y, bossPosDirHP.y),
                            p2Punch + float4(0..xx, p2PosDirHP.xy),
                            bossHitBox + float4(0..xx, bossPosDirHP.xy), 8.);

                        score.z += hitDetect.x > 0. && bossPunch.y < 0. ? 10. : 0.;
                        score.w += hitDetect.y > 0. && bossPunch.y < 0. ? 10. : 0.;
                        score.zw = min(score.zw, 100.);

                        float3 damage;
                        damage.x = (p1CharAnimHistFrame.y == _SPECIAL) ? 10. : 1.;
                        damage.y = (p2CharAnimHistFrame.y == _SPECIAL) ? 10. : 1.;
                        damage.z = dot(hitDetect, damage.xy);

                        [branch]
                        if (bossAnimHistFrame.y == _BOSS_IDLE) {
                            // Move back to default position
                            bossPosDirHP.xy -= (bossPosDirHP.xy - bossXY) / 10.;
                            bossHitBox = float4(50., 50., 20., 45.);

                            bossPunch = float4(0., bossPunch.yzw);
                            damageCalc(bossPunch, bossPosDirHP, damage, 0.0);

                            bossAnimHistFrame.w =
                                fmod(bossAnimHistFrame.w + 0.2, bSizeFrame[_BOSS_IDLE].z);
                            bossPosDirHP.z += 0.2;

                            [flatten]
                            if (bossPosDirHP.z >= 14. || bossPosDirHP.w <= 0.) {
                                bossPosDirHP.z = 0.0;
                                bossAnimHistFrame.w = 0.0;
                                bossAnimHistFrame.y = bossAnimHistFrame.x < 2. ?
                                    bossAnimHistFrame.x < 1. ? _BOSS_SPIN : _BOSS_JUSTICE :
                                    _BOSS_RASENGAN;
                                bossAnimHistFrame.y = bossPosDirHP.w <= 0. ?
                                    _BOSS_FALL : bossAnimHistFrame.y;
                                bossAnimHistFrame.x = fmod(bossAnimHistFrame.x + 1., 3.);
                            }
                        }
                        else if (bossAnimHistFrame.y == _BOSS_SPIN) {
                            bossPosDirHP.x = bossXY.x - lerp(170., 40.,
                                (sin(bossPosDirHP.z * 0.35) + 2.0) * 0.5);
                            bossPosDirHP.xy = lerp(bossPosDirHP.xy, bossXY,
                                expStep(bossPosDirHP.z / 50., 1000., 3));
                            bossHitBox = float4(50., 50., 20., 45.);
                           
                            bossPunch = float4(30., bossPunch.yzw);
                            damageCalc(bossPunch, bossPosDirHP, damage, 1.0);

                            bossAnimHistFrame.w =
                                fmod(bossAnimHistFrame.w + 1.0, bSizeFrame[_BOSS_SPIN].z);
                            bossPosDirHP.z += 0.5;

                            [flatten]
                            if (bossPosDirHP.z >= 150. || bossPunch.z >= BOSS_ARMOR_L) {
                                bossPosDirHP.z = 0.0;
                                bossAnimHistFrame.w = 0.0;
                                bossAnimHistFrame.y = bossPunch.z >= BOSS_ARMOR_L ? 
                                    _BOSS_FALL : _BOSS_IDLE;
                                bossPunch.z = 0.;
                            }
                        }
                        else if (bossAnimHistFrame.y == _BOSS_JUSTICE) {
                            bossPosDirHP.y = lerp(40., 100., sin(bossPosDirHP.z * 0.46));
                            bossPosDirHP.x = lerp(50., -20., sin(bossPosDirHP.z * 0.16));
                            // Ease it in from default position
                            bossPosDirHP.xy =
                                lerp(float2(bossXY.x - bossPosDirHP.x, bossPosDirHP.y),
                                    bossXY, expStep(bossPosDirHP.z / 50., 1000., 3));
                            bossHitBox = float4(50., 50., 20., 45.);

                            bossPunch = float4(30., bossPunch.yzw);
                            damageCalc(bossPunch, bossPosDirHP, damage, 1.0);

                            bossAnimHistFrame.w =
                                fmod(bossAnimHistFrame.w + 0.2, bSizeFrame[_BOSS_JUSTICE].z);
                            bossPosDirHP.z += 0.5;

                            [flatten]
                            if (bossPosDirHP.z >= 200. || bossPunch.z >= BOSS_ARMOR_L) {
                                bossPosDirHP.z = 0.0;
                                bossAnimHistFrame.w = 0.0;
                                bossAnimHistFrame.y = bossPunch.z >= BOSS_ARMOR_L ? 
                                    _BOSS_FALL : _BOSS_IDLE;
                                bossPunch.z = 0.;
                            }
                        }
                        else if (bossAnimHistFrame.y == _BOSS_RASENGAN) {
                            bossHitBox = float4(50., 50., 20., 45.);
                            
                            bossPunch = float4(lerp(0., 200., step(133., bossPosDirHP.z)),
                                bossPunch.yzw);
                            damageCalc(bossPunch, bossPosDirHP, damage, 1.0);

                            bossAnimHistFrame.w = bossAnimHistFrame.w + 0.15;
                            bossPosDirHP.z += 1.0;

                            [flatten]
                            if (bossAnimHistFrame.w >= bSizeFrame[_BOSS_RASENGAN].z
                                    || bossPunch.z >= BOSS_ARMOR_H) {
                                bossPosDirHP.z = 0.0;
                                bossAnimHistFrame.w = 0.0;
                                bossAnimHistFrame.y = bossPunch.z >= BOSS_ARMOR_H ? 
                                    _BOSS_FALL : _BOSS_IDLE;
                                bossPunch.z = 0.;
                            }
                        }
                        // else if (bossAnimHistFrame.y == _BOSS_HIT) {
                        //     bossHitBox = 0..xxxx;
                        //     bossAnimHistFrame.w += 0.01;
                        //     [flatten]
                        //     if (bossAnimHistFrame.w >= 0.5) {
                        //         bossPosDirHP.z = sameState ? bossPosDirHP.z + 1 : 0.0;
                        //         bossAnimHistFrame.w = 0.0;
                        //         bossAnimHistFrame.y = bossPosDirHP.z > 2. ?
                        //             _BOSS_FALL : _BOSS_IDLE;
                        //         bossPosDirHP.z = bossPosDirHP.z > 2. ?
                        //             0.0 :  bossPosDirHP.z;
                        //     }
                        // }
                        else if (bossAnimHistFrame.y == _BOSS_FALL) {
                            bossHitBox = float4(50., 50., 20., 45.);
                            bossPunch = float4(0., bossPunch.yzw);
                            damageCalc(bossPunch, bossPosDirHP, damage, 0.0);

                            bossAnimHistFrame.w = bossAnimHistFrame.w + 0.1;
                            [flatten]
                            if (bossAnimHistFrame.w >= bSizeFrame[_BOSS_FALL].z) {
                                bossPosDirHP.z = 0.0;
                                bossAnimHistFrame.w = 0.0;
                                bossAnimHistFrame.y = _BOSS_DOWN;
                            }
                        }
                        else if (bossAnimHistFrame.y == _BOSS_DOWN) {
                            bossHitBox = float4(50., 50., 20., 45.);
                            bossPunch = float4(0., bossPunch.yzw);
                            damageCalc(bossPunch, bossPosDirHP, damage, 0.0);

                            bossAnimHistFrame.w = bossAnimHistFrame.w + 0.01;
                            [flatten]
                            if (bossAnimHistFrame.w >= 0.5) {
                                bossPosDirHP.z = 0.0;
                                bossAnimHistFrame.w = 0.0;
                                bossAnimHistFrame.y = bossPosDirHP.w > 0. ? _BOSS_UP : 
                                    _BOSS_DOWN;
                            }
                        }
                        else if (bossAnimHistFrame.y == _BOSS_UP) {
                            bossHitBox = 0..xxxx;
                            bossPunch = float4(0., bossPunch.yzw);
                            damageCalc(bossPunch, bossPosDirHP, damage, 0.0);
                            
                            bossAnimHistFrame.w = bossAnimHistFrame.w + 0.1;
                            [flatten]
                            if (bossAnimHistFrame.w >= bSizeFrame[_BOSS_UP].z) {
                                bossPosDirHP.z = 0.0;
                                bossAnimHistFrame.w = 0.0;
                                bossAnimHistFrame.y = _BOSS_IDLE;
                            }
                        }
                        else if (bossAnimHistFrame.y == _BOSS_INTRO) {
                            bossPosDirHP.xy = bossXY;
                            bossHitBox = 0..xxxx;
                            bossPunch = float4(0., bossPunch.ywz);
                            bossAnimHistFrame.w =
                                fmod(bossAnimHistFrame.w + 0.2, bSizeFrame[_BOSS_INTRO].z);
                            float3 tsc;
                            tsc.x = 50. - bossPosDirHP.z;
                            sincos(tsc.x, tsc.y, tsc.z);
                            bossPosDirHP.x -= (tsc.x * tsc.y) * 3.0;
                            bossPosDirHP.y = (tsc.x * tsc.z) * 3.0;
                            // Use direction as timer
                            bossPosDirHP.z += 0.5;
                            [flatten]
                            if (bossPosDirHP.z >= 50.0) {
                                bossAnimHistFrame.w = 0.0;
                                bossPosDirHP.z = 0.0;
                                bossAnimHistFrame.y = _BOSS_IDLE;
                            }
                        }
                        else {
                            bossAnimHistFrame.y = _BOSS_IDLE;
                        }
                    }
                    else {
                        bossPosDirHP.xyz = 0..xxx;
                        bossPosDirHP.w = 150.0;
                        bossAnimHistFrame = 0..xxxx;
                        bossHitBox = 0..xxxx;
                        bossPunch = 0..xxxx;
                    }

                    StoreValue(txScore,                 score, col, px);
                    StoreValue(txStagePosZContIndex,    stagePosZContIndex, col, px);
                    StoreValue(txBossPosDirHP,          bossPosDirHP, col, px);
                    StoreValue(txBossAnimHistFrame,     bossAnimHistFrame, col, px);
                    StoreValue(txBossHitBox,            bossHitBox, col, px);
                    StoreValue(txBossPunch,             bossPunch, col, px);
                }

                // Character select
                if (px.y == txCharSelect.y) {
                    if (state.x == 0) {
                        pointers = clamp(pointers + joysticks * 0.5, 0., 180.);
                        //pointers = float4(charBtnArr[_1001], charBtnArr[_MERLIN]);
                        //pointers = 0;
                        float4 iPointers = pointers;
                        charSelect.xy = -1.;
                        // Player 1
                        charSelect.x = all(abs(iPointers.xy - charBtnArr[_SCRN]) < 18.5) ?
                            _SCRN : charSelect.x;
                        charSelect.x = all(abs(iPointers.xy - charBtnArr[_1001]) < 18.5) ?
                            _1001 : charSelect.x;
                        charSelect.x = all(abs(iPointers.xy - charBtnArr[_MERLIN]) < 18.5) ?
                            _MERLIN : charSelect.x;
                        charSelect.x = all(abs(iPointers.xy - charBtnArr[_SCRUFFY]) < 18.5) ?
                            _SCRUFFY : charSelect.x;
                        charSelect.x = all(abs(iPointers.xy - charBtnArr[_XIEXE]) < 18.5) ?
                            _XIEXE : charSelect.x;

                        // Player 2
                        charSelect.y = all(abs(iPointers.zw - charBtnArr[_SCRN]) < 18.5) ?
                            _SCRN : charSelect.y;
                        charSelect.y = all(abs(iPointers.zw - charBtnArr[_1001]) < 18.5) ?
                            _1001 : charSelect.y;
                        charSelect.y = all(abs(iPointers.zw - charBtnArr[_MERLIN]) < 18.5) ?
                            _MERLIN : charSelect.y;
                        charSelect.y = all(abs(iPointers.zw - charBtnArr[_SCRUFFY]) < 18.5) ?
                            _SCRUFFY : charSelect.y;
                        charSelect.y = all(abs(iPointers.zw - charBtnArr[_XIEXE]) < 18.5) ?
                            _XIEXE : charSelect.y;

                        // Save the selection
                        charSelect.z = buttons.x > 0.5 ?
                            iPointers.y < 24. ? charSelect.z : charSelect.x : charSelect.z;
                        charSelect.w = buttons.y > 0.5 ?
                            iPointers.w < 24. ? charSelect.w : charSelect.y : charSelect.w;

                        float ready = (iPointers.y < 24. && buttons.x > 0.5) ||
                             (iPointers.w < 24. && buttons.y > 0.5) ? 1.0 : 0.0;

                        StoreValue(txReadyState,            ready.xxxx, col, px);
                    }
                    StoreValue(txCharSelect,            charSelect, col, px);
                    StoreValue(txPointers,              pointers, col, px);
                } else

                // Zombies Logic

                if (px.y > txStagePosZContIndex.y) {

                    float4 zombiesPosDirHP =
                        LoadValue(_StateTex, int2(px.x, txZombiesPosDirHP.y));
                    float4 zombiesAnimHistFrame =
                        LoadValue(_StateTex, int2(px.x, txZombiesAnimHistFrame.y));
                    float4 zombiesHitBox =
                        LoadValue(_StateTex, int2(px.x, txZombiesHitBox.y));
                    float4 zombiesPunch =
                        LoadValue(_StateTex, int2(px.x, txZombiesPunch.y));

                    int zombieType = zombiesAnimHistFrame.x;

                    if (state.z < 1.0 || stagePosZContIndex.z > 0.5) {
                        zombiesPosDirHP = float4(max(p1PosDirHP.x, p2PosDirHP.x) +
                            (250. + px.x * ((zombieType == _ZBOOM) ? 70. : 10.)) * (fmod(px.x, 2) < 0.5 ? -1. : 1.),
                            px.y * 2.0, 0,
                            (zombieType == _ZBOOM) ? ZBOOM_HP : 100.);
                        // Spawn exploding zombies after stage 1
                        zombiesAnimHistFrame = float4(
                            stagePosZContIndex.w < 2 ? fmod(px.x, 2) : _ZBOOM,
                            _ZWALK.xx, 0);
                        zombiesHitBox = 0..xxxx;
                        zombiesPunch = 0..xxxx;
                    }

                    float2 trgtPlayer = px.x < _StateTex_TexelSize.z * 0.5 ?
                        p1PosDirHP.w > 0.0 ? p1PosDirHP.xy : p2PosDirHP.xy:
                        p2PosDirHP.w > 0.0 ? p2PosDirHP.xy : p1PosDirHP.xy;

                    trgtPlayer.xy = p1PosDirHP.w + p2PosDirHP.w <= 0. ?
                        zombiesPosDirHP.xy : trgtPlayer.xy;

                    // Larger AOE, more damage for special attack
                    float damage = (p1CharAnimHistFrame.y == _SPECIAL ||
                        p2CharAnimHistFrame.y == _SPECIAL) ? 500. : 20.;

                    // Interrupt on hit
                    float2 hitDetect;
                    hitDetect.x = RectCircleIntersect(float2(p1PosDirHP.y, zombiesPosDirHP.y),
                        p1Punch + float4(0..xx, p1PosDirHP.xy),
                        zombiesHitBox + float4(0..xx, zombiesPosDirHP.xy), damage > 100. ? 50. : 5);
                    hitDetect.y = RectCircleIntersect(float2(p2PosDirHP.y, zombiesPosDirHP.y),
                        p2Punch + float4(0..xx, p2PosDirHP.xy),
                        zombiesHitBox + float4(0..xx, zombiesPosDirHP.xy), damage > 100. ? 50. : 5);

                    zombiesAnimHistFrame.y = zombiesAnimHistFrame.y != _ZDIE &&
                        (hitDetect.x + hitDetect.y > 0.5) ?
                            _ZHIT : zombiesAnimHistFrame.y;

                    int2 zState = int2(zombiesAnimHistFrame.yz);
                    // Save last state
                    zombiesAnimHistFrame.z = zombiesAnimHistFrame.y;

                    if (stagePosZContIndex.z < 0.5) {
                        if (zState.x == _ZWALK) {
                            zombiesPosDirHP.w = (zombiesPosDirHP.w < -99.0) ?
                                zombieType == _ZBOOM ? ZBOOM_HP : 100.0 : zombiesPosDirHP.w;

                            zombiesHitBox = float4(15., 30., 18, 30);
                            zombiesPunch = 0..xxxx;
                            zombiesAnimHistFrame.w = fmod(state.w,
                                zSizeFrame[zombiesAnimHistFrame.x][_ZWALK].z);
                            float2 targetDir;
                            targetDir.x = min((zombiesPosDirHP.x - trgtPlayer.x) *
                                ZSPEED, ZSPEED_MAX) * (zombieType == _ZBOOM ? 3.0 : 1.0);
                            targetDir.y = distance(zombiesPosDirHP.y, trgtPlayer.y) > 0.05 * px.x ?
                                sign(zombiesPosDirHP.y - trgtPlayer.y) * 0.6 : 0.;
                            zombiesPosDirHP.xy -= targetDir;

                            // Saving two bits of data into one float
                            float hitBy = fmod(zombiesPosDirHP.z, 10.);
                            zombiesPosDirHP.z = zombiesPosDirHP.x - trgtPlayer.x < 0. ? 0. : 10.;
                            zombiesPosDirHP.z += hitBy;
                            [flatten]
                            if (distance(zombiesPosDirHP.xy, trgtPlayer) <= 
                                (zombieType == _ZBOOM ? 2.0 : 1.0) * ZATTKDIST) {
                                zombiesAnimHistFrame.y = _ZATTK;
                            }
                        }
                        else if (zState.x == _ZATTK) {
                            if (zombieType != _ZBOOM) {
                                zombiesAnimHistFrame.w = fmod(state.w * (1.0 + 0.03 * px.x),
                                    zSizeFrame[zombiesAnimHistFrame.x][_ZATTK].z);
                                float l1 = pow5Pulse(6., 1.2, zombiesAnimHistFrame.w);
                                float l2 = pow5Pulse(4., 1., zombiesAnimHistFrame.w);
                                zombiesHitBox = lerp(float4(15., 32.,
                                    floor(zombiesPosDirHP.z / 10.) < 0.5 ? 20. : 15., 32.),
                                    float4(24., 18., floor(zombiesPosDirHP.z / 10.) < 0.5 ? 26. : 12., 20.),
                                    l1);
                                zombiesPunch = float4(lerp(0., ZPUNCHDIST, l2), 0.,
                                    floor(zombiesPosDirHP.z / 10.) < 0.5 ? 38. : 0., 30.);
                                
                                // Saving two bits of data into one float
                                float hitBy = fmod(zombiesPosDirHP.z, 10.);
                                zombiesPosDirHP.z = zombiesPosDirHP.x - trgtPlayer.x < 0. ? 0. : 10.;
                                zombiesPosDirHP.z += hitBy;
                                if (round(zombiesAnimHistFrame.w) == 
                                        zSizeFrame[zombiesAnimHistFrame.x][_ZATTK].z &&
                                        distance(zombiesPosDirHP.xy, trgtPlayer.xy) > ZATTKDIST) {
                                    zombiesAnimHistFrame.y = _ZWALK;
                                }
                            }
                            else {
                                bool sameState = (zombiesAnimHistFrame.z == zombiesAnimHistFrame.y);
                                zombiesAnimHistFrame.w = sameState ?
                                    min(zombiesAnimHistFrame.w + 0.75,
                                        zSizeFrame[zombiesAnimHistFrame.x][_ZATTK].z) : 0.0;
                                zombiesHitBox = float4(15., 30., 18, 30) * step(zombiesAnimHistFrame.w, 11.0);
                                zombiesPunch = float4(lerp(0., 50.,
                                    pow5Pulse(16.0, 3.0, zombiesAnimHistFrame.w)), 0.,
                                    floor(zombiesPosDirHP.z / 10.) > 0.5 ? 30. : 20., 30.);
                                float hitBy = fmod(zombiesPosDirHP.z, 10.);
                                zombiesPosDirHP.z = zombiesPosDirHP.x - trgtPlayer.x < 0. ? 0. : 10.;
                                zombiesPosDirHP.z += hitBy;
                                [flatten]
                                if (round(zombiesAnimHistFrame.w) == 
                                        zSizeFrame[zombiesAnimHistFrame.x][_ZATTK].z) {
                                    zombiesPosDirHP.w = -DEATH_TRIGGER3; // No points if it blows up
                                    zombiesPosDirHP.xy = float2(max(p1PosDirHP.x, p2PosDirHP.x) +
                                        (250 + px.x * 70.0) * fmod(px.x, 2.) < 0.5 ? -1. : 1., px.y * 2.0);
                                    zombiesAnimHistFrame.y = _ZWALK;
                                    zombiesAnimHistFrame.w = 0.;
                                }
                            }
                        }
                        else if (zState.x == _ZHIT) {
                            zombiesPunch = 0..xxxx;
                            bool sameState = (zombiesAnimHistFrame.z == zombiesAnimHistFrame.y);
                            zombiesAnimHistFrame.w = sameState ? zombiesAnimHistFrame.w + 0.04 : 0.0;
                            
                            // Two floats in one
                            float dir = floor(zombiesPosDirHP.z / 10.) * 10.;
                            zombiesPosDirHP.z = hitDetect.x > 0.5 ? 1. : 
                                hitDetect.y > 0.5 ? 2. : fmod(zombiesPosDirHP.z, 10.);
                            zombiesPosDirHP.z += dir;
                            [flatten]
                            if (zombiesAnimHistFrame.w > 0.5) {
                                zombiesPosDirHP.w -= damage;
                                zombiesAnimHistFrame.y = (zombiesPosDirHP.w <= 0.5) ?
                                    _ZDIE : _ZWALK;
                                zombiesAnimHistFrame.w = 0.;
                                float tagged = fmod(zombiesPosDirHP.z, 10.);
                                zombiesPosDirHP.w = zombiesPosDirHP.w < 0.5 && tagged > 1.5 ?
                                    -DEATH_TRIGGER2 : zombiesPosDirHP.w < 0.5 && tagged > 0.5 ?
                                        -DEATH_TRIGGER1 : zombiesPosDirHP.w;
                            }
                        }
                        else if (zState.x == _ZDIE) {
                            zombiesHitBox = 0..xxxx;
                            zombiesPunch = 0..xxxx;
                            // Clear death tags
                            zombiesPosDirHP.w = -100.0;
                            bool sameState = (zombiesAnimHistFrame.z == zombiesAnimHistFrame.y);
                            zombiesAnimHistFrame.w = sameState ?
                                min(zombiesAnimHistFrame.w + 0.04,
                                    zSizeFrame[zombiesAnimHistFrame.x][_ZDIE].z) : 0.0;
                            if (round(zombiesAnimHistFrame.w) == 
                                    zSizeFrame[zombiesAnimHistFrame.x][_ZDIE].z) {
                                zombiesPosDirHP.xy = float2(max(p1PosDirHP.x, p2PosDirHP.x) +
                                    250 + px.x * 10.0, px.y * 2.0);
                                zombiesAnimHistFrame.y = _WALK;
                            }
                        }
                        else {
                            zombiesAnimHistFrame.y = _WALK;
                        }
                    }

                    StoreMulti(txZombiesPosDirHP,       zombiesPosDirHP, col, px);
                    StoreMulti(txZombiesAnimHistFrame,  zombiesAnimHistFrame, col, px);
                    StoreMulti(txZombiesHitBox,         zombiesHitBox, col, px);
                    StoreMulti(txZombiesPunch,          zombiesPunch, col, px);
                }

                return col;
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}