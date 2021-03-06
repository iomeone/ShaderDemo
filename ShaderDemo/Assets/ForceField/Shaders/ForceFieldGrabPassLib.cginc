﻿#include "UnityCG.cginc"

struct appdata
{
    float4 vertex : POSITION;
    float2 uv : TEXCOORD0;
    float3 normal : NORMAL;
};

struct v2f
{
    float2 uv : TEXCOORD0;
    float4 vertex : SV_POSITION;
    float rimLight : TEXCOORD1;
    float4 grabPos : TEXCOORD2;
    float4 screenPos : TEXCOORD3;
};

sampler2D _MainTex;
float4 _MainTex_ST;

sampler2D _CameraDepthTexture;

sampler2D _GrabTempTex;

fixed4 _RimColor;
float _RimPower;
float _IntersectPower;

sampler2D _NoiseTex;
float4 _NoiseTex_ST;
float _DistortStrength;
float _DistortTimeFactor;

v2f vert (appdata v)
{
    v2f o;
    o.vertex = UnityObjectToClipPos(v.vertex);
    o.uv = TRANSFORM_TEX(v.uv, _MainTex);
    o.grabPos = ComputeGrabScreenPos(o.vertex);
    //计算屏幕坐标，范围[0, w]，未齐次除法
    o.screenPos = ComputeScreenPos(o.vertex);
    //计算观察空间的深度值z，并储存到o.screenPos.z
    COMPUTE_EYEDEPTH(o.screenPos.z);
    float3 worldNormal = UnityObjectToWorldNormal(v.normal);
    float4 worldPos = mul(unity_ObjectToWorld, v.vertex);
    float3 worldView = normalize(UnityWorldSpaceViewDir(worldPos));
    o.rimLight = 1 - abs(dot(worldNormal, worldView));
    return o;
}

fixed4 frag (v2f i) : SV_Target
{
    //获取已有的深度信息,此时的深度图里没有力场的信息
    //判断相交
    float depth = SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(i.screenPos));
    float sceneZ = LinearEyeDepth(depth);
    float partZ = i.screenPos.z;
    float diff = sceneZ - partZ;
    float intersect = pow(1 - diff, _IntersectPower);
    
    //圆环
    float rim = pow(i.rimLight, _RimPower);
    float glow = max(intersect, rim);
    
    //扭曲
    float4 offset = tex2D(_NoiseTex, i.uv - _Time.xy * _DistortTimeFactor);
    i.grabPos.xy -= offset.xy * _DistortStrength;
    fixed4 color = tex2Dproj(_GrabTempTex, i.grabPos);
    
    fixed3 rimColor = _RimColor.rgb * glow;
    color.rgb += rimColor;
    return color;
}