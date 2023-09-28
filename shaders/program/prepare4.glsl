#include "/lib/common.glsl"
#ifdef FSH
in vec2 lrTexCoord;
in mat4 unProjectionMatrix;
in mat4 prevProjectionMatrix;

uniform float viewWidth;
uniform float viewHeight;
vec2 view = vec2(viewWidth, viewHeight);

uniform float near;
uniform float far;
float farPlusNear = far + near;
float farMinusNear = far - near;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform sampler2D colortex2;
uniform sampler2D colortex8;
uniform sampler2D colortex10;
const bool colortex10MipmapEnabled = true;
uniform sampler2D colortex12;
uniform sampler2D colortex13;
float GetLinearDepth(float depth) {
	return (2.0 * near) / (farPlusNear - depth * (farMinusNear));
}
#define FALLOFF_SPEED 0.04
#define MAX_OLDWEIGHT 0.5
void main() {
    vec4 normalDepthData = texelFetch(colortex8, ivec2(gl_FragCoord.xy), 0);
    vec4 newColor = texture(colortex10, lrTexCoord);
    vec4 playerPos = unProjectionMatrix * vec4(gl_FragCoord.xy / view * 2 - 1, 1 - 2 * normalDepthData.w, 1);
    vec4 prevPlayerPos = vec4(playerPos.xyz / playerPos.w + cameraPosition - previousCameraPosition, 1);
    vec4 prevPos = prevProjectionMatrix * prevPlayerPos;
    float ndotv = dot(playerPos.xyz, normalDepthData.xyz);
    float normalWeight = clamp(1.05 * dot(prevPlayerPos.xyz, normalDepthData.xyz) / ndotv, 1 + ndotv, 1);
    normalWeight *= normalWeight;
    prevPos.xyz = 0.5 * prevPos.xyz / prevPos.w + 0.5;
    vec4 prevColor = vec4(0);
    vec4 tex13Data = vec4(0);
    float weight = FALLOFF_SPEED * (1 - length(fract(view * lrTexCoord) - 0.5));
    float prevDepth = 1 - texelFetch(colortex2, ivec2(view * prevPos.xy), 0).w;
    if (prevPos.xy == clamp(prevPos.xy, vec2(0), vec2(1))) {
        tex13Data = texture(colortex13, prevPos.xy);
        prevColor = texture(colortex12, prevPos.xy);
        prevColor.a *= normalWeight;
        prevColor.a = clamp(
            MAX_OLDWEIGHT * (
                1 - 5 * (1 - GetLinearDepth(1 - normalDepthData.a)) * 
                length(cameraPosition - previousCameraPosition)
            ), 0.8 * prevColor.a, prevColor.a);
    } else {
        prevColor.a = 0;
    }
    float prevLinDepth = GetLinearDepth(prevDepth);
    float prevCompareDepth = GetLinearDepth(prevPos.z);
    if ((max(abs(prevDepth - prevPos.z),
            abs(prevLinDepth - prevCompareDepth) / (prevLinDepth + prevCompareDepth)) > 0.05
            && length(view * prevPos.xy - gl_FragCoord.xy) > 2.5)
         || normalDepthData.a > 1.5
         || length(normalDepthData.rgb) < 0.1) {
        prevColor.a = 0;
    }
    if (fract(tex13Data.a) > 0.12 * newColor.a) {
        prevColor.a *= 0.0;
    }
    tex13Data.a = clamp(0.1 * newColor.a - 0.05, 0.05, 0.95);
    /*RENDERTARGETS:12,13*/
    gl_FragData[0] = vec4(
        mix(newColor.rgb,
            prevColor.rgb,
            prevColor.a / (prevColor.a + weight)
            ),
        prevColor.a + weight);
    //gl_FragData[0].rgb = newColor;
    gl_FragData[1] = tex13Data;
}
#endif
#ifdef VSH

out vec2 lrTexCoord;
out mat4 unProjectionMatrix;
out mat4 prevProjectionMatrix;
uniform int frameCounter;

uniform float viewWidth;
uniform float viewHeight;
vec2 view = vec2(viewWidth, viewHeight);

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;

void main() {
    unProjectionMatrix = gbufferModelViewInverse
                       * gbufferProjectionInverse;
    prevProjectionMatrix = gbufferPreviousProjection
                         * gbufferPreviousModelView;
    gl_Position = ftransform();
    lrTexCoord = gl_Position.xy / gl_Position.w * 0.5 + 0.5;
    lrTexCoord = 0.5 * (lrTexCoord - vec2(frameCounter % 2, frameCounter / 2 % 2) / view);
}
#endif