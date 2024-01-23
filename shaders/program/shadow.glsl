////////////////////////////////////////
// Complementary Reimagined by EminGT //
////////////////////////////////////////

//Common//
#include "/lib/common.glsl"

//////////Fragment Shader//////////Fragment Shader//////////Fragment Shader//////////
#ifdef FRAGMENT_SHADER

flat in int mat;

in vec2 texCoord;

flat in vec3 sunVec, upVec;

in vec4 position;
flat in vec4 glColor;

flat in int passType;
flat in vec3 normal;
flat in float resolution;

//Uniforms//
uniform int isEyeInWater;

uniform vec3 cameraPosition;

uniform sampler2D tex;
uniform sampler2D noisetex;

layout(r32i) uniform iimage3D occupancyVolume;
layout(r32i) uniform iimage3D voxelCols;

#if WATER_CAUSTIC_STYLE >= 3
    uniform float frameTimeCounter;

    uniform sampler2D gaux4;
#endif

//Pipeline Constants//

//Common Variables//
float SdotU = dot(sunVec, upVec);
float sunVisibility = clamp(SdotU + 0.0625, 0.0, 0.125) / 0.125;

//Common Functions//
void DoNaturalShadowCalculation(inout vec4 color1, inout vec4 color2) {
    color1.rgb *= glColor.rgb;
    color1.rgb = mix(vec3(1.0), color1.rgb, pow(color1.a, (1.0 - color1.a) * 0.5) * 1.05);
    color1.rgb *= 1.0 - pow(color1.a, 64.0);
    color1.rgb *= 0.2; // Natural Strength

    color2.rgb = normalize(color1.rgb) * 0.5;
}

//Includes//

//Program//
void main() {
    if (passType == 0) {
        vec4 color1 = texture2DLod(tex, texCoord, 0); // Shadow Color

        #if SHADOW_QUALITY >= 1
            vec4 color2 = color1; // Light Shaft Color

            color2.rgb *= 0.25; // Natural Strength

            #if defined LIGHTSHAFTS_ACTIVE && LIGHTSHAFT_BEHAVIOUR == 1 && defined OVERWORLD
                float positionYM = position.y;
            #endif

            if (mat < 31008) {
                if (mat < 31000) {
                    DoNaturalShadowCalculation(color1, color2);
                } else {
                    if (mat == 31000) { // Water
                        vec3 worldPos = position.xyz + cameraPosition;

                        #if defined LIGHTSHAFTS_ACTIVE && LIGHTSHAFT_BEHAVIOUR == 1 && defined OVERWORLD
                            // For scene-aware light shafts to be more prone to get extreme near water
                            positionYM += 3.5;
                        #endif

                        // Water Caustics
                        #if WATER_CAUSTIC_STYLE < 3
                            #if MC_VERSION >= 11300
                                float wcl = GetLuminance(color1.rgb);
                                color1.rgb = color1.rgb * pow2(wcl) * 1.2;
                            #else
                                color1.rgb = mix(color1.rgb, vec3(GetLuminance(color1.rgb)), 0.88);
                                color1.rgb = pow2(color1.rgb) * vec3(2.5, 3.0, 3.0) * 0.96;
                            #endif
                        #else
                            #define WATER_SPEED_MULT_M WATER_SPEED_MULT * 0.035
                            vec2 causticWind = vec2(frameTimeCounter * WATER_SPEED_MULT_M, 0.0);
                            vec2 cPos1 = worldPos.xz * 0.10 - causticWind;
                            vec2 cPos2 = worldPos.xz * 0.05 + causticWind;

                            float cMult = 14.0;
                            float offset = 0.001;

                            float caustic = 0.0;
                            caustic += dot(texture2D(gaux4, cPos1 + vec2(offset, 0.0)).rg, vec2(cMult))
                                    - dot(texture2D(gaux4, cPos1 - vec2(offset, 0.0)).rg, vec2(cMult));
                            caustic += dot(texture2D(gaux4, cPos2 + vec2(0.0, offset)).rg, vec2(cMult))
                                    - dot(texture2D(gaux4, cPos2 - vec2(0.0, offset)).rg, vec2(cMult));
                            color1.rgb = vec3(max0(min1(caustic * 0.8 + 0.35)) * 0.65 + 0.35);

                            #if MC_VERSION < 11300
                                color1.rgb *= vec3(0.3, 0.45, 0.9);
                            #endif
                        #endif

                        #if MC_VERSION >= 11300
                            #if WATERCOLOR_MODE >= 2
                                color1.rgb *= glColor.rgb;
                            #else
                                color1.rgb *= vec3(0.3, 0.45, 0.9);
                            #endif
                        #endif
                        color1.rgb *= vec3(0.6, 0.8, 1.1);
                        ////

                        // Underwater Light Shafts
                        vec3 worldPosM = worldPos;

                        #if WATER_FOG_MULT > 100
                            #define WATER_FOG_MULT_M WATER_FOG_MULT * 0.01;
                            worldPosM *= WATER_FOG_MULT_M;
                        #endif

                        vec2 waterWind = vec2(syncedTime * 0.01, 0.0);
                        float waterNoise = texture2D(noisetex, worldPosM.xz * 0.012 - waterWind).g;
                            waterNoise += texture2D(noisetex, worldPosM.xz * 0.05 + waterWind).g;

                        float factor = max(2.5 - 0.025 * length(position.xz), 0.8333) * 1.3;
                        waterNoise = pow(waterNoise * 0.5, factor) * factor * 1.3;

                        #if MC_VERSION >= 11300 && WATERCOLOR_MODE >= 2
                            color2.rgb = normalize(sqrt1(glColor.rgb)) * vec3(0.24, 0.22, 0.26);
                        #else
                            color2.rgb = vec3(0.08, 0.12, 0.195);
                        #endif
                        color2.rgb *= waterNoise * (1.0 + sunVisibility - rainFactor);
                        ////

                        #ifdef UNDERWATERCOLOR_CHANGED
                            color1.rgb *= vec3(UNDERWATERCOLOR_RM, UNDERWATERCOLOR_GM, UNDERWATERCOLOR_BM);
                            color2.rgb *= vec3(UNDERWATERCOLOR_RM, UNDERWATERCOLOR_GM, UNDERWATERCOLOR_BM);
                        #endif
                    } else /*if (mat == 31004)*/ { // Ice
                        color1.rgb *= color1.rgb;
                        color1.rgb *= color1.rgb;
                        color1.rgb = mix(vec3(1.0), color1.rgb, pow(color1.a, (1.0 - color1.a) * 0.5) * 1.05);
                        color1.rgb *= 1.0 - pow(color1.a, 64.0);
                        color1.rgb *= 0.28;

                        color2.rgb = normalize(pow(color1.rgb, vec3(0.25))) * 0.5;
                    }
                }
            } else {
                if (mat < 31020) { // Glass, Glass Pane, Beacon (31008, 31012, 31016)
                    if (color1.a > 0.5) color1 = vec4(0.0, 0.0, 0.0, 1.0);
                    else color1 = vec4(vec3(0.2 * (1.0 - GLASS_OPACITY)), 1.0);
                    color2.rgb = vec3(0.3);
                } else {
                    DoNaturalShadowCalculation(color1, color2);
                }
            }
        #endif

        gl_FragData[0] = color1; // Shadow Color

        #if SHADOW_QUALITY >= 1
            #if defined LIGHTSHAFTS_ACTIVE && LIGHTSHAFT_BEHAVIOUR == 1 && defined OVERWORLD
                color2.a = 0.25 + max0(positionYM * 0.05); // consistencyMEJHRI7DG
            #endif

            gl_FragData[1] = color2; // Light Shaft Color
        #endif
    } else {
        vec4 col = textureLod(tex, texCoord, 0) * glColor;
        if (col.a > 0.1) {
            vec3 vxPos = position.xyz + fract(cameraPosition);
            for (int k = 0; k < 4; k++) {
                vec3 position2 = vxPos * (1<<k) - 0.1 * normal + voxelVolumeSize * 0.5;
                if (any(lessThan(position2, vec3(0))) || any(greaterThanEqual(position2, voxelVolumeSize - 0.01))) {
                    break;
                }
                if (k == 0) {
                    if (mat == 2) {
                        imageAtomicOr(occupancyVolume, ivec3(position2), 1<<4);
                    }
                    if (all(lessThan(mod(gl_FragCoord.xy, vec2(1.0, 2.0)), vec2(1.0)))) {
                        imageAtomicAdd(voxelCols,
                            ivec3(position2) * ivec3(1, 2, 1),
                            int(20 * col.r) + (int(20 * col.g) << 13));
                        imageAtomicAdd(voxelCols,
                            ivec3(position2) * ivec3(1, 2, 1) + ivec3(0, 1, 0),
                            int(20 * col.b) + (int(4.5 * (1 - col.a)) << 13) + (1<<23));
                    }
                }
                imageAtomicOr(occupancyVolume, ivec3(position2), 1<<(k + 5 * int(col.a < 0.9)));
            }
        }
        discard;
    }
}

#endif

/////////Geometry Shader////////Geometry Shader////////Geometry Shader/////////
#ifdef GEOMETRY_SHADER

layout(triangles) in;
layout(triangle_strip, max_vertices=6) out;

flat in int matV[3];
in vec2 texCoordV[3];
in vec2 lmCoordV[3];
in vec3 midBlock[3];
flat in vec3 sunVecV[3], upVecV[3];
in vec4 positionV[3];
flat in vec4 glColorV[3];

flat out int mat;
out vec2 texCoord;
flat out vec3 sunVec, upVec;
out vec4 position;
flat out vec4 glColor;

flat out int passType;
flat out vec3 normal;
flat out float resolution;

//Uniforms//

uniform int currentRenderedItemId;
uniform int blockEntityId;
uniform int entityId;
uniform vec3 cameraPosition;
uniform sampler2D tex;
uniform sampler2D specular;

//Includes//

void main() {
    vec3 cnormal = normalize(cross(positionV[1].xyz - positionV[0].xyz, positionV[2].xyz - positionV[0].xyz));
    vec3[3] vxPos;
    for (int i = 0; i < 3; i++) vxPos[i] = positionV[i].xyz + fract(cameraPosition);
    vec3 lowerBound = floor(min(min(vxPos[0], vxPos[1]), vxPos[2]));
    vec3 minAbsPos = min(min(abs(vxPos[0]), abs(vxPos[1])), abs(vxPos[2]));
    int bestNormalAxis = int(dot(vec3(greaterThanEqual(abs(cnormal), max(abs(cnormal).yzx, abs(cnormal.zxy)))), vec3(0.5, 1.5, 2.5)));
    int localResolution = min(4, int(-log2(infnorm(minAbsPos / voxelVolumeSize))));
    if (localResolution > 0) {
        for (int i = 0; i < 3; i++) {
            vec2 relProjectedPos
                = vec2(  vxPos[i][(bestNormalAxis+1)%3],   vxPos[i][(bestNormalAxis+2)%3])
                - vec2(lowerBound[(bestNormalAxis+1)%3], lowerBound[(bestNormalAxis+2)%3]);
            gl_Position = vec4(relProjectedPos * (1<<localResolution) / shadowMapResolution - 1, 0.0, 1.0);
            mat = matV[i];
            texCoord = texCoordV[i];
            sunVec = sunVecV[i];
            upVec = upVecV[i];
            position = positionV[i];
            glColor = glColorV[i];
            passType = 1;
            resolution = localResolution;
            normal = cnormal;
            EmitVertex();
        }
    }
    EndPrimitive();
    #if (defined OVERWORLD || defined END) && defined REALTIME_SHADOWS
        for (int i = 0; i < 3; i++) {
            gl_Position = gl_in[i].gl_Position;
            mat = matV[i];
            texCoord = texCoordV[i];
            sunVec = sunVecV[i];
            upVec = upVecV[i];
            position = positionV[i];
            glColor = glColorV[i];
            passType = 0;
            resolution = 0;
            normal = cnormal;
            EmitVertex();
        }
        EndPrimitive();
    #endif
}
#endif

//////////Vertex Shader//////////Vertex Shader//////////Vertex Shader//////////
#ifdef VERTEX_SHADER

flat out int matV;

out vec2 texCoordV;
out vec2 lmCoordV;

flat out vec3 sunVecV, upVecV;

out vec4 positionV;
flat out vec4 glColorV;

//Uniforms//
uniform mat4 shadowProjection, shadowProjectionInverse;
uniform mat4 shadowModelView, shadowModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

#if defined WAVING_ANYTHING_TERRAIN || defined WAVING_WATER_VERTEX
    uniform float frameTimeCounter;

    uniform vec3 cameraPosition;
#endif

//Attributes//
in vec4 mc_Entity;

#if defined PERPENDICULAR_TWEAKS || defined WAVING_ANYTHING_TERRAIN || defined WAVING_WATER_VERTEX
    attribute vec4 mc_midTexCoord;
#endif

//Common Variables//
#if (defined WAVING_ANYTHING_TERRAIN || defined WAVING_WATER_VERTEX) && defined NO_WAVING_INDOORS
    vec2 lmCoord = vec2(0.0);
#endif

//Common Functions//

//Includes//
#include "/lib/util/spaceConversion.glsl"

#if defined WAVING_ANYTHING_TERRAIN || defined WAVING_WATER_VERTEX
    #include "/lib/materials/materialMethods/wavingBlocks.glsl"
#endif

//Program//
void main() {
    texCoordV = gl_MultiTexCoord0.xy;
    lmCoordV = clamp(((gl_TextureMatrix[1] * gl_MultiTexCoord1).xy - 0.03125) * 1.06667, 0.0, 1.0);
    glColorV = gl_Color;

    sunVecV = GetSunVector();
    upVecV = normalize(gbufferModelView[1].xyz);

    matV = int(mc_Entity.x + 0.5);

    positionV = shadowModelViewInverse * shadowProjectionInverse * ftransform();

    #if defined WAVING_ANYTHING_TERRAIN || defined WAVING_WATER_VERTEX
        #ifdef NO_WAVING_INDOORS
            lmCoord = GetLightMapCoordinates();
        #endif

        DoWave(positionV.xyz, matV);
    #endif

    #ifdef PERPENDICULAR_TWEAKS
        if (matV == 10004 || matV == 10016) { // Foliage
            vec2 midCoord = (gl_TextureMatrix[0] * mc_midTexCoord).st;
            vec2 texMinMidCoord = texCoordV - midCoord;
            if (texMinMidCoord.y < 0.0) {
                vec3 normal = gl_NormalMatrix * gl_Normal;
                positionV.xyz += normal * 0.35;
            }
        }
    #endif

    if (matV == 31000) { // Water
        positionV.y += 0.015 * max0(length(positionV.xyz) - 50.0);
    }
    gl_Position = shadowProjection * shadowModelView * positionV;

    float lVertexPos = sqrt(gl_Position.x * gl_Position.x + gl_Position.y * gl_Position.y);
    float distortFactor = lVertexPos * shadowMapBias + (1.0 - shadowMapBias);
    gl_Position.xy *= 1.0 / distortFactor;
    gl_Position.z = gl_Position.z * 0.2;
}

#endif
