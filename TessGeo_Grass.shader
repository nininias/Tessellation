Shader "Study/URP/Text/3.3 TessGeo Grass"
{
    Properties
    {
        [Space(20)]
        [Header(Colors)]
        _BottomColor ("Bottom Color", Color) = (1,1,1,1)
        _TopColor ("Top Color", Color) = (1,1,1,1)

        [Space(20)]
        [Header(Noise)]
        _RotateSeed ("Rotate Seed", Vector) = (0,0,0,0)
        _BendRotationRandom("Bend Rotation Random", Range(0,1)) = 0.5
        _BladeWidth ("Blade Width", Range(0,1)) = 0.5
        _BladeWidthRandom ("Blade Width Random", Range(0,1)) = 0.5
        _BladeHeight ("Blade Height", Range(0,1)) = 0.5 
        _BladeHeightRandom ("Blade Height Random", Range(0,1)) = 0.5

        [Space(20)]
        [Header(Tessellation)]
        _TessFactor ("Tessellation Factor", Range(1,64)) = 16

        [Space(20)]
        [Header(Wind)]
        _WindDistortionMap ("Wind Distortion Map", 2D) = "white" {}
        _WindFrequency ("Wind Frequency", Vector) = (0.05,0.05,0.0,0.0)
        _WindStrength ("Wind Strength", Range(0,1)) = 1

        [Space(20)]
        [Header(Blade)]
        _BladeForward ("Blade Forward", float) = 0.38
        _BladeCurve ("Blade Curve", Range(1,4)) = 1

        [Space(20)]
        [Header(Interaction)]
        _Radius ("Radius", Range(0,10)) = 0.5

    }
    SubShader
    {
        Cull Off
        ZTest LEqual
        ZWrite On
        Tags 
        { 
            "RenderType"="Opaque" 
            "RenderPipeline" = "UniversalRenderPipeline"
        }

        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Assets/MyStudy/Scene/EverybodyAddsFuel/3.3 TessAndGeom/CustomTess.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"


        #pragma target 4.6
        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
        #pragma multi_compile _ _SHADOWS_SOFT
        #pragma multi_compile _ _Anti ALIASING
        #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS

        #define CUSTOM_TWO_PI 6.283185307179586
        #define CUSTOM_PI 3.141592653589793
        #define BLADE_SEGMENTS 3

        TEXTURE2D(_WindDistortionMap);
        SAMPLER(sampler_WindDistortionMap);

        CBUFFER_START(UnityPerMaterial)
        uniform half4 _BottomColor ;
        uniform half4 _TopColor ;
        uniform float4 _RotateSeed ;
        uniform half _BendRotationRandom ;
        uniform half _BladeWidth ;
        uniform half _BladeWidthRandom ;
        uniform half _BladeHeight ;
        uniform half _BladeHeightRandom ;
        uniform half _BladeForward ;
        uniform half _BladeCurve ;
        uniform half _TessFactor ;
        uniform float2 _WindFrequency ;
        uniform half _WindStrength ;
        uniform float4 _WindDistortionMap_ST;
        uniform half _Radius ;
        uniform float4 _PositionMoving;
        CBUFFER_END



        // struct Attributes
        // {
        //     float4 positionOS   : POSITION;
        //     float2 uv           : TEXCOORD0;
        //     float3 normalOS     : NORMAL;
        //     float4 tangentOS    : TANGENT;
        // };

        // struct Varyings
        // {
        //     float4 positionCS   : SV_POSITION;
        //     float3 positionWS   : TEXCOORD0;
        //     float3 positionOS   : TEXCOORD1;
        //     float2 uv           : TEXCOORD2;
        //     float3 normalOS     : TEXCOORD3;
        //     float4 tangentOS    : TEXCOORD4;
        // };

        //Geo Struct
        struct geometryOutput
        {
            float4 positionCS  : SV_POSITION;
            float3 positionWS  : TEXCOORD0;
            float2 uv          : TEXCOORD1;
            float4 shadowCoord : TEXCOORD2; //阴影坐标
            float3 normalWS    : TEXCOORD3;
        };

        //随机数生成函数——输出[0,1]
        inline float rand(float3 co)
        {
            return frac(sin(dot(co.xyz, float3(12.9898,78.233,45.5432))) * 43758.5453);
        }

        //围绕轴旋转矩阵
        inline float3x3 AngleAxis3x3(float angle , float3 axis)
        {
            float c,s;
            sincos(angle , s , c);

            float t = 1.0 - c;
            float x = axis.x;
            float y = axis.y;
            float z = axis.z;

            return float3x3(
                t*x*x + c, t*x*y - s*z, t*x*z + s*y,
                t*x*y + s*z, t*y*y + c, t*y*z - s*x,
                t*x*z - s*y, t*y*z + s*x, t*z*z + c
            );
        }


        //ASE里面的旋转轴方法,好像也是罗德里格斯旋转公式
        float3 RotateAroundAxis( float3 center, float3 original, float3 u, float angle )
		{
				original -= center;
				float C = cos( angle );
				float S = sin( angle );
				float t = 1 - C;
				float m00 = t * u.x * u.x + C;
				float m01 = t * u.x * u.y - S * u.z;
				float m02 = t * u.x * u.z + S * u.y;
				float m10 = t * u.x * u.y + S * u.z;
				float m11 = t * u.y * u.y + C;
				float m12 = t * u.y * u.z - S * u.x;
				float m20 = t * u.x * u.z - S * u.y;
				float m21 = t * u.y * u.z + S * u.x;
				float m22 = t * u.z * u.z + C;
				float3x3 finalMatrix = float3x3( m00, m01, m02, m10, m11, m12, m20, m21, m22 );
				return mul( finalMatrix, original ) + center;
		}

        //==========================================
        // 曲面细分部分
        //==========================================
        // 顶点着色器，顶点→Hull
        Tess_ControlPoint vert_Tess(Tess_Attributes IN)
        {
            Tess_ControlPoint OUT;
            OUT.positionOS = IN.positionOS;
            OUT.uv = IN.texcoord;
            OUT.normalOS = IN.normalOS;
            OUT.tangentOS = IN.tangentOS;
            return OUT;
        }

        //Hull着色器，Hull→Domain
        [domain("tri")]      //指定patch的类型
        [outputcontrolpoints(3)]    //指定输出的控制点的数量（每个图元）
        [patchconstantfunc("patchConstantFunc")]    //指定面片常数函数。
        [outputtopology("triangle_cw")] //输出拓扑结构。
        [partitioning("integer")]   //分割模式，起到告知GPU应该如何分割补丁的作用。硬分割
        Tess_ControlPoint hull_Tess(
            InputPatch<Tess_ControlPoint, 3> patch,  //向Hull 程序传递曲面补丁的参数
            uint id : SV_OutputControlPointID)
        {
            return patch[id];
        }

        Tess_TessFactors patchConstantFunc(InputPatch<Tess_ControlPoint, 3> patch)    //决定了Patch的属性是如何被细分的，每个Patch调用一次
        {
            Tess_TessFactors OUT;

            OUT.edge[0] = OUT.edge[1] = OUT.edge[2] = _TessFactor;  //控制三角形每条边的细分数量
            OUT.inside = _TessFactor;   //控制内部边的细分数量

            return OUT;
        }

        //Domainy着色器，Domain→Geometry
        Tess_Varyings vert_AfterTess(Tess_DomainAttributes IN)
        {
            Tess_Varyings OUT;

            OUT.positionWS = TransformObjectToWorld(IN.positionOS);
            OUT.positionCS = TransformWorldToHClip(OUT.positionWS);
            OUT.positionOS = IN.positionOS;
            OUT.uv = IN.uv;
            OUT.normalOS = IN.normalOS;
            OUT.tangentOS = IN.tangentOS;

            return OUT;
        }

        [domain("tri")]
        Tess_Varyings domain_Tess(
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

            return vert_AfterTess(OUT);
        }


        //==========================================
        // 几何着色器部分
        //==========================================
        //用来定义生成草叶的位置，封装函数方便重复调用
        inline geometryOutput VertexOutput(float3 positionOS,float2 uv)
        {
            geometryOutput output;
            output = (geometryOutput)0;
            output.positionCS = TransformObjectToHClip(positionOS);
            output.positionWS = TransformObjectToWorld(positionOS);
            output.uv = uv;
            output.shadowCoord = TransformWorldToShadowCoord(output.positionWS);    //世界坐标转换到阴影坐标

            
            return output;
        }

        inline geometryOutput VertexOutput(float3 positionOS,float2 uv,float3 normalOS)
        {
            geometryOutput output;
            output = (geometryOutput)0;
            output.positionCS = TransformObjectToHClip(positionOS);
            output.positionWS = TransformObjectToWorld(positionOS);
            output.uv = uv;
            output.normalWS = TransformObjectToWorldNormal(normalOS);
            output.shadowCoord = TransformWorldToShadowCoord(output.positionWS);    //世界坐标转换到阴影坐标

            //光照数据
            Light mainLight = GetMainLight();
            float3 lightDir = normalize(mainLight.direction).xyz;

            //确保只在阴影通道的时候才进行稍微的偏移
            #if UNITY_PASS_SHADOWCASTER
            output.positionWS = float4(ApplyShadowBias(output.positionWS,output.normalWS,lightDir) , 1.0);
            #endif
            
            return output;
        }

        //用于更加简便的方式书写的封装函数
        inline geometryOutput GenerateGrassVertex(float3 vertexPositionOS , float width , float height ,float forward , float3 normalOS , float2 uv , float3x3 transformationMatrix)
        {

            float3 tangentPoint = float3(width , forward , height);

            //自生成法线
            //跟原来的差别很大！！！
            //原来的用的都是底部的顶点的法线，在计算光照的时候会造成法线的错误。
            float3 normalTS = float3(0,-1,forward);
            // float3 localNormalOS = mul( normalOS , transformationMatrix);
            float3 localNormalOS = mul( normalTS , transformationMatrix);

            float3 localPositionOS = vertexPositionOS + mul(tangentPoint , transformationMatrix);

            return VertexOutput(localPositionOS,uv,localNormalOS);
        }

        //几何着色器，Geometry→Vertex
        [maxvertexcount(BLADE_SEGMENTS * 2 + 1)]
        void geom(
            triangle Tess_Varyings input[3],
            inout TriangleStream<geometryOutput> triStream)
        {
            geometryOutput output;
            output = (geometryOutput)0;

            //参数传入
            float3 positionOS = input[0].positionOS;
            float3 positionWS = input[0].positionWS;
            float3 normalOS = input[0].normalOS;

            float4 tangentOS = input[0].tangentOS;
            float3 BinormalOS = cross(normalOS, tangentOS.xyz) * tangentOS.w;

            //随机宽高
            float height = (rand(positionOS.zyx) * 2 - 1) * _BladeHeightRandom + _BladeHeight  ;
            float width = (rand(positionOS.xzy) * 2 - 1) * _BladeWidthRandom + _BladeWidth ;
            float forward = rand(positionOS.yyz) * _BladeForward;

            //UV
            float2 uv = positionOS.xz * _WindDistortionMap_ST.xy + _WindDistortionMap_ST.zw + _WindFrequency.xy * _Time.y;

            //Wind Construct
            float2 windSample = SAMPLE_TEXTURE2D_LOD(_WindDistortionMap, sampler_WindDistortionMap, uv * 2 - 1, 0) * _WindStrength;
            float3 wind = normalize(float3(windSample.x,windSample.y,0.0));//wind Vector
            float3x3 windRotationMatrix = AngleAxis3x3(CUSTOM_PI * windSample,wind);

            //简单的交互效果——距离计算
            float3 dis = distance(_PositionMoving , positionWS);    //与顶点的半径距离
            float3 radiusFalloff = 1 - saturate(dis / _Radius);    //和顶点的半径衰减
            float3 sphereDisp = positionWS - _PositionMoving;  //移动位置指向顶点
            sphereDisp *= radiusFalloff * 0.5;//衰减距离
            sphereDisp = clamp(sphereDisp, -0.8, 0.8);

            //随机旋转角度矩阵
            float3x3 facingRotationMatrix = AngleAxis3x3(rand(positionOS + _RotateSeed.xyz ) * CUSTOM_TWO_PI, float3(0.0,0.0,1.0));

            //随机弯折矩阵
            float3x3 bendRotationMatrix = AngleAxis3x3(rand(positionOS + _RotateSeed.yzx) * CUSTOM_PI * _BendRotationRandom * 0.5 , float3(-1.0,0.0,0.0));

            //TBN矩阵
            float3x3 TBN_T2O = float3x3(tangentOS.xyz,BinormalOS,normalOS);//列向量排布

            //矩阵的混合（需考虑顺序）
            float3x3 transformationMatrix = mul(windRotationMatrix,mul(facingRotationMatrix,mul(bendRotationMatrix,TBN_T2O)));
            float3x3 transformationMatrixFacing = mul(facingRotationMatrix,TBN_T2O);//用于底部的两个顶点特殊处理，不让其风动和弯曲
            
 
            //三角形顶点的增加
            for(int i = 0; i < BLADE_SEGMENTS; i++)
            {
                float t = i / (float)BLADE_SEGMENTS;
                float segmentHeight = height * t;
                float segmentWidth = width * (1 - t);

                float segmentForward = forward * pow(t , _BladeCurve);

                //底部的两个顶点不动，也就是i = 0的情况
                float3x3 transformationMatrix_T = i == 0 ? transformationMatrixFacing : transformationMatrix;   

                //尝试直接修改顶点位置
                float3 newPositionOS = i == 0 ? positionOS : positionOS + sphereDisp  * t;

                triStream.Append(GenerateGrassVertex(newPositionOS , segmentWidth , segmentHeight , segmentForward , normalOS , float2(0.0,t) , transformationMatrix_T));//两个底部的顶点不做风动效果以及弯折
                triStream.Append(GenerateGrassVertex(newPositionOS , -segmentWidth , segmentHeight , segmentForward , normalOS , float2(1.0,t) , transformationMatrix_T));
            }
            //最后一个顶点的三角形
            triStream.Append(GenerateGrassVertex(positionOS + float3(sphereDisp.x * 1.5 , sphereDisp.y , sphereDisp.z * 1.5) , 0.0 , height , forward , normalOS , float2(0.5,1.0) , transformationMatrix));  
            triStream.RestartStrip();
        }

        //==========================================
        // 原始的顶点着色器
        //==========================================
        // Varyings vert_Common (Attributes input)
        // {
        //     Varyings output;

        //     output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
        //     output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
        //     output.positionOS = input.positionOS.xyz;
        //     output.normalOS  = input.normalOS;
        //     output.tangentOS = input.tangentOS;

        //     return output;
        // }


        //==========================================
        // 原始的片段着色器，Vertex→Fragment
        //==========================================
        half4 frag_Common (geometryOutput input,half facing:VFACE) : SV_Target
        {
            float3 normalWS = facing > 0 ? input.normalWS : -input.normalWS;

            //阴影数据
            float4 shadowCoord = input.shadowCoord;
            half shadow = MainLightRealtimeShadow(shadowCoord); 

            //光照数据
            Light mainLight = GetMainLight();
            float3 lightDir = normalize(mainLight.direction).xyz;

            float NdotL = saturate(dot(normalWS, lightDir)) * shadow;

            float3 ambient = SampleSH(normalWS);
            float4 lightTerm = float4(( NdotL * mainLight.color + ambient)  , 1.0);

            half4 color = lerp(_BottomColor, _TopColor * lightTerm , input.uv.y);

            return color ;

        }

        float4 frag_ShadowCaster (geometryOutput input) : SV_Target
        {
            float4 shadowCoord = input.shadowCoord;

            half shadow = MainLightRealtimeShadow(shadowCoord); 

            return shadow;
        }

        ENDHLSL

        Pass
        {
            Name "TessGeo_Grass"
            
            Tags 
            { 
                "LightMode" = "UniversalForward"
            }

            HLSLPROGRAM

            #pragma vertex vert_Tess
            #pragma hull hull_Tess
            #pragma domain domain_Tess
            #pragma geometry geom
            #pragma fragment frag_Common

            ENDHLSL
        }

        Pass
        {
            Tags
            {
                "LightMode" = "ShadowCaster"
            }

            HLSLPROGRAM

            #pragma vertex vert_Tess
            #pragma hull hull_Tess
            #pragma domain domain_Tess
            #pragma geometry geom
            #pragma fragment frag_ShadowCaster

            ENDHLSL

        }
    }
}
