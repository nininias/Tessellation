#ifndef CUSTOM_UNIVERSALPIPELINE_TESSELLATION_UV
#define CUSTOM_UNIVERSALPIPELINE_TESSELLATION_UV


#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"

//==========================================
// 曲面细分常数
//==========================================


TEXTURE2D(_LandMap);
SAMPLER(sampler_LandMap);
TEXTURE2D(_SnowMap);
SAMPLER(sampler_SnowMap);
TEXTURE2D(_SunkenMap);
SAMPLER(sampler_SunkenMap);
TEXTURE2D(_SnowDisplacementMap);
SAMPLER(sampler_SnowDisplacementMap);
TEXTURE2D(_SnowNormalMap);
SAMPLER(sampler_SnowNormalMap);

CBUFFER_START(UnityPerMaterial)
uniform float _TessFactor_Include;  // 曲面细分因子
uniform float4 _LandMap_ST;
uniform float4 _SnowMap_ST;
uniform float4 _SunkenMap_ST;
uniform float _SnowDisplacementIntensity;
CBUFFER_END

//==========================================
// 曲面细分数据结构
//==========================================

struct Tess_Attributes
{
    float4 positionOS : POSITION;
    float4 texcoord   : TEXCOORD0;
    float3 normalOS   : NORMAL;
    float4 tangentOS  : TANGENT;
};
struct Tess_Varyings
{
    float4 positionCS  : SV_POSITION;
    float3 positionWS  : TEXCOORD0;
    float3 positionOS  : TEXCOORD1;
    float4 uv          : TEXCOORD2;
    float3 normalWS    : TEXCOORD3;
    float3 tangentWS   : TEXCOORD4;
    float3 bitangentWS : TEXCOORD5;
};

struct Tess_ControlPoint //这个结构体作为Hull Shader的输入/输出控制点
{
    float4 positionOS : INTERNALTESSPOS;  
    float4 uv         : TEXCOORD0;
    float3 normalOS   : TEXCOORD1;
    float4 tangentOS  : TEXCOORD2;
};

struct Tess_TessFactors  //细分因子
{
    float edge[3] : SV_TessFactor;  //三个细分因子
    float inside  : SV_InsideTessFactor;    //第四个细分因子
};

struct Tess_DomainAttributes
{
    float4 positionOS : TEXCOORD0;
    float4 uv         : TEXCOORD1;
    float3 normalOS   : TEXCOORD2;
    float4 tangentOS  : TEXCOORD3;
};

//==========================================
// 曲面细分部分
//==========================================
// 顶点着色器，顶点→Hull
Tess_ControlPoint vert_Tess_Include(Tess_Attributes IN)
{
    Tess_ControlPoint OUT;
    OUT = (Tess_ControlPoint)0;
    OUT.positionOS = IN.positionOS;
    OUT.uv = IN.texcoord;
    OUT.uv.zw = OUT.uv.xy;
    OUT.normalOS = IN.normalOS;
    OUT.tangentOS = IN.tangentOS;
    return OUT;
}

//Hull着色器，Hull→Domain
[domain("tri")]      //指定patch的类型
[outputcontrolpoints(3)]    //指定输出的控制点的数量（每个图元）
[patchconstantfunc("patchConstantFuncInclude")]    //指定面片常数函数。
[outputtopology("triangle_cw")] //输出拓扑结构。
[partitioning("integer")]   //分割模式，起到告知GPU应该如何分割补丁的作用。硬分割
Tess_ControlPoint hull_Tess_Include(
    InputPatch<Tess_ControlPoint, 3> patch,  //向Hull 程序传递曲面补丁的参数
    uint id : SV_OutputControlPointID)
{
    return patch[id];
}

Tess_TessFactors patchConstantFuncInclude(InputPatch<Tess_ControlPoint, 3> patch)    //决定了Patch的属性是如何被细分的，每个Patch调用一次
{
    Tess_TessFactors OUT;
    OUT.edge[0] = OUT.edge[1] = OUT.edge[2] = _TessFactor_Include;  //控制三角形每条边的细分数量
    OUT.inside = _TessFactor_Include;   //控制内部边的细分数量
    return OUT;
}

//Vertex着色器，Vertex→Fragment
Tess_Varyings vert_AfterTess_Include(Tess_DomainAttributes IN)
{
    Tess_Varyings OUT;
    OUT = (Tess_Varyings)0;
    OUT.positionOS = IN.positionOS;
    OUT.uv.xy = TRANSFORM_TEX(IN.uv.xy, _LandMap);
    OUT.uv.zw = TRANSFORM_TEX(IN.uv.zw, _SnowMap);

    // VertexNormalInputs normalInput = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);
    // OUT.normalWS = normalInput.normalWS;
    // OUT.tangentWS = normalInput.tangentWS;
    // OUT.bitangentWS = normalInput.bitangentWS;

    float3 normalOS = IN.normalOS;
    float4 tangentOS = IN.tangentOS;
    OUT.normalWS = TransformObjectToWorldNormal(normalOS);
    OUT.tangentWS = TransformObjectToWorldDir(tangentOS.xyz);
    OUT.bitangentWS = cross(OUT.normalWS, OUT.tangentWS.xyz) * tangentOS.w;
    
    float3 displacementSnow = SAMPLE_TEXTURE2D_LOD(_SnowDisplacementMap, sampler_SnowDisplacementMap, IN.uv.zw, 0).rgb;
    float d = SAMPLE_TEXTURE2D_LOD(_SunkenMap, sampler_SunkenMap, IN.uv.zw, 0).r * _SnowDisplacementIntensity;

    OUT.positionOS.xyz -= normalOS * d;
    OUT.positionOS.xyz += normalOS * _SnowDisplacementIntensity * displacementSnow;

    OUT.positionWS = TransformObjectToWorld(OUT.positionOS);
    OUT.positionCS = TransformWorldToHClip(OUT.positionWS);
    
    


    

    return OUT;
}

//Domainy着色器，Domain→Geometry
[domain("tri")]
Tess_Varyings domain_Tess_Include(
    Tess_TessFactors factors,    //由patchConstantFunc函数生成的细分因子
    OutputPatch<Tess_ControlPoint, 3> patch,     //Hull着色器传入的patch数据。第二个参数需要和InputPatch第二个参数对应
    float3 barycentricCoordinates : SV_DomainLocation)  //由曲面细分阶段阶段传入的顶点位置信息
{
    Tess_DomainAttributes OUT;
    //初始化OUT
    OUT = (Tess_DomainAttributes)0;
    //根据重心坐标插入法线数据
    OUT.normalOS = patch[0].normalOS * barycentricCoordinates.x + 
                   patch[1].normalOS * barycentricCoordinates.y + 
                   patch[2].normalOS * barycentricCoordinates.z;
    //根据重心坐标进行位置
    OUT.positionOS = patch[0].positionOS * barycentricCoordinates.x + 
                     patch[1].positionOS * barycentricCoordinates.y + 
                     patch[2].positionOS * barycentricCoordinates.z;
    //根据重心坐标插入切线数据
    OUT.tangentOS = patch[0].tangentOS * barycentricCoordinates.x + 
                    patch[1].tangentOS * barycentricCoordinates.y + 
                    patch[2].tangentOS * barycentricCoordinates.z;
    //根据重心坐标插入UV   
    OUT.uv = patch[0].uv * barycentricCoordinates.x + 
             patch[1].uv * barycentricCoordinates.y + 
             patch[2].uv * barycentricCoordinates.z;

    return vert_AfterTess_Include(OUT);
}

#endif