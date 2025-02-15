Shader "Study/URP/Text/3.3 Tess Snow"
{
    Properties
    {   
        [Toggle(LAND_ON)] _EnableLand("Enable Land", Int) = 1
        [Toggle(SNOW_ON)] _EnableSnow("Enable Snow", Int) = 0
        [Toggle(SUNKEN_ON)] _EnableSunken("Enable Sunken", Int) = 0

        [Space(20)]
        [Header(Land)]
        _LandMap ("Land Albedo", 2D) = "white" {}
        [NoScaleOffset]_LandDisplacementMap ("Land Displacement Map", 2D) = "white" {}
        _LandDisplacementIntensity ("Land Displacement Intensity", Range(0, 20)) = 0.5
        [NoScaleOffset]_LandNormalMap ("Land Normal Map", 2D) = "bump" {}
        _LandNormalIntensity ("Land Normal Intensity", Range(0, 1)) = 1
        _LandColor ("Land Color", Color) = (1,1,1,1)

        [Space(20)]
        [Header(Snow)]
        _SnowMap ("Snow Albedo", 2D) = "white" {}
        [NoScaleOffset]_SnowDisplacementMap ("Snow Displacement Map", 2D) = "white" {}
        _SnowDisplacementIntensity ("Snow Displacement Intensity", Range(0, 20)) = 0.5
        [NoScaleOffset]_SnowNormalMap ("Snow Normal Map", 2D) = "bump" {}
        _SnowNormalIntensity ("Snow Normal Intensity", Range(0, 1)) = 1
        _SnowColor ("Snow Color", Color) = (1,1,1,1)

        [Space(20)]
        [Header(Sunken)]
        _SunkenMap ("Sunken Map", 2D) = "white" {}

        [Space(20)]
        [Header(Tessellation)]
        _TessFactor_Include ("Tessellation Factor", Range(1, 32)) = 4
    }
    SubShader
    {
        Tags 
        { 
            "RenderType"="Opaque" 
            "RenderPipeline" = "UniversalRenderPipeline"
        }

        HLSLINCLUDE

        //==========================================
        // includes
        //==========================================
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Assets/MyStudy/Scene/EverybodyAddsFuel/3.3 TessAndGeom/CustomTess_Snow.hlsl"

        //==========================================
        // pragmas  
        //==========================================
        #pragma target 4.6
        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
        #pragma multi_compile _ _SHADOWS_SOFT
        #pragma multi_compile _ _Anti ALIASING
        #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
        #pragma shader_feature LAND_ON SNOW_ON SUNKEN_ON

        //==========================================
        // defines
        //==========================================
        #define CUSTOM_TWO_PI 6.283185307179586
        #define CUSTOM_PI 3.141592653589793
        #define BLADE_SEGMENTS 3

        //==========================================
        // uniforms
        //==========================================
        // TEXTURE2D(_LandMap);
        // SAMPLER(sampler_LandMap);
        TEXTURE2D(_LandDisplacementMap);
        SAMPLER(sampler_LandDisplacementMap);
        TEXTURE2D(_LandNormalMap);
        SAMPLER(sampler_LandNormalMap);

        // TEXTURE2D(_SnowMap);
        // SAMPLER(sampler_SnowMap);
        // TEXTURE2D(_SnowDisplacementMap);
        // SAMPLER(sampler_SnowDisplacementMap);
        // TEXTURE2D(_SnowNormalMap);
        // SAMPLER(sampler_SnowNormalMap);

        // TEXTURE2D(_SunkenMap);
        // SAMPLER(sampler_SunkenMap);


        CBUFFER_START(UnityPerMaterial)
        // uniform float4 _LandMap_ST;
        uniform float _LandDisplacementIntensity;
        uniform float _LandNormalIntensity;
        // uniform float4 _SnowMap_ST;
        // uniform float _SnowDisplacementIntensity;
        uniform float _SnowNormalIntensity;
        uniform half4 _LandColor;
        uniform half4 _SnowColor;
        CBUFFER_END
        

        //==========================================
        // Structs and Packing
        //==========================================
        struct Attributes
        {
            float4 positionOS : POSITION;
            float2 texcoord : TEXCOORD0;
        };

        struct Varyings
        {
            float4 positionCS : SV_POSITION;
            float2 uv : TEXCOORD0;
        };


        //==========================================
        // Vertex Shader
        //==========================================
        Varyings vert_Common (Attributes IN)
        {
            Varyings OUT;
            OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);
            OUT.uv = TRANSFORM_TEX(IN.texcoord, _LandMap);
            return OUT;
        }

        //==========================================
        // 曲面细分部分
        //==========================================
        //引用了自定义的CustomTess.hlsl

        //==========================================
        // Fragment Shader
        //==========================================
        half4 frag_Common (Tess_Varyings IN) : SV_Target
        {
            half3 color = half3(0,0,0); //初始化颜色

            //Get Parameters
            half4 landAlbedo = SAMPLE_TEXTURE2D(_LandMap, sampler_LandMap, IN.uv.xy);
            half4 snowAlbedo = SAMPLE_TEXTURE2D(_SnowMap, sampler_SnowMap, IN.uv.zw);
            half4 sunkenTex = SAMPLE_TEXTURE2D(_SunkenMap, sampler_SunkenMap, IN.uv.zw);
            Light mainLight = GetMainLight();
            float3 N_normalWS = normalize(IN.normalWS);
            float3 T_tangentWS = normalize(IN.tangentWS);
            float3 B_bitangentWS = normalize(IN.bitangentWS);
            float3x3 TBN = float3x3(T_tangentWS , B_bitangentWS, N_normalWS);
            float3 normalTS_L = UnpackNormal(SAMPLE_TEXTURE2D_LOD(_LandNormalMap,sampler_LandNormalMap,IN.uv.xy,0));
            float3 normalTS_S = UnpackNormal(SAMPLE_TEXTURE2D_LOD(_SnowNormalMap,sampler_SnowNormalMap,IN.uv.zw,0));
            float3 normalWS_L = normalize(mul(normalTS_L , TBN)) * _LandNormalIntensity;
            float3 normalWS_S = normalize(mul(normalTS_S , TBN)) * _SnowNormalIntensity;
            float3 viewDirWS = normalize(GetWorldSpaceViewDir(IN.positionWS));
            float3 lightDirWS = normalize(mainLight.direction);
            
            //Light Calculation
            #if defined(LAND_ON)
            float NdotL_L = saturate(dot(normalWS_L, lightDirWS));
            float3 diffuse = mainLight.color * NdotL_L;
            float3 ambient = SampleSH(normalWS_L);
            color = diffuse * landAlbedo * _LandColor.rgb;
            #elif defined(SNOW_ON)
            float NdotL_S = saturate(dot(normalWS_S, lightDirWS));
            float3 diffuse = mainLight.color * NdotL_S;
            float3 ambient = SampleSH(normalWS_S);
            color = diffuse * snowAlbedo * _SnowColor.rgb + ambient;
            #elif defined(SUNKEN_ON)
            float NdotL_L = saturate(dot(normalWS_L, lightDirWS));
            float NdotL_S = saturate(dot(normalWS_S, lightDirWS));
            float3 diffuse_L = mainLight.color * NdotL_L;
            float3 diffuse_S = mainLight.color * NdotL_S;
            float3 ambient_L = SampleSH(normalWS_L);
            float3 ambient_S = SampleSH(normalWS_S);
            half3 snow = snowAlbedo * _SnowColor * diffuse_S + ambient_S;
            half3 land = landAlbedo * _LandColor * diffuse_L + ambient_L;
            half amount = sunkenTex.r;
            color = lerp(snow, land, amount);

            #endif

            return half4(color,  1);
        }

        ENDHLSL


        Pass
        {
            Name "Tess_Snow"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert_Tess_Include
            #pragma hull hull_Tess_Include
            #pragma domain domain_Tess_Include
            #pragma fragment frag_Common
            ENDHLSL

        }
    }
}

