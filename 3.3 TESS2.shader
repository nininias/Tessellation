Shader "Study/URP/Text/3.3 Test_Tessellation2"
{
    Properties
    {
        [Space(20)]
        [Header(Tessellation)]
        _TessFactor("Tess Factor",Range(1,64)) = 4
    }
    SubShader
    {
        Tags 
        { 
            "RenderType"="Opaque" 
            "RenderPipeline" = "UniversalRenderPipeline"
        }

        HLSLINCLUDE

        //include
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        //pragmas
        //新增加了hull，domain和标注需要tessellation
        #pragma target 4.6     //使用细分时的最低着色器目标级别为4.6。如果我们不手动设置，Unity将发出警告并自动使用该级别。但我一开始用的是4.5也没有报错


        CBUFFER_START(UnityPerMaterial)
        uniform float _TessFactor;
        CBUFFER_END


        //structs
        struct Attributes
        {
            float4 positionOS : POSITION;
            float2 texcoord   : TEXCOORD0;
            float3 normalOS   : NORMAL;
        };

        struct Varyings
        {
            float4 positionCS : SV_POSITION;
            float3 positionWS : TEXCOORD0;
            float2 uv         : TEXCOORD1;
            float3 normalWS   : TEXCOORD2;
        };

        //---------------new----------------
        //新增加了Domain属性
        struct DomainAttributes
        {
            float4 positionOS : TEXCOORD0;
            float2 uv         : TEXCOORD1;
            float3 normalOS   : NORMAL;
        };

        //---------------new----------------
        struct TessControlPoint //这个结构体作为Hull Shader的输入/输出控制点
        {
            float4 positionOS : INTERNALTESSPOS;    //曲面细分专用语义，标记这个位置数据将参与细分计算
            float2 uv         : TEXCOORD0;
            float3 normalOS   : NORMAL;
            // float4 color : COLOR;
        };


        //---------------new----------------
        struct TessFactors  //细分因子
        {
            float edge[3] : SV_TessFactor;  //三个细分因子
            float inside  : SV_InsideTessFactor;    //第四个细分因子
        };         

        //---------------new----------------
        // 顶点着色器，此时只是将Attributes里的数据递交给曲面细分阶段
        TessControlPoint vert_Tess(Attributes IN)
        {
            TessControlPoint OUT;
            OUT.positionOS = IN.positionOS;
            OUT.uv = IN.texcoord;
            OUT.normalOS = IN.normalOS;
            return OUT;
        }


        //---------------new----------------
        //主要的壳着色器，可以处理三角形，四边形或等值线。我们必须告诉它必须使用什么表面并提供必要的数据。这是 hull 程序的工作。
        [domain("tri")]      //指定patch的类型
        [outputcontrolpoints(3)]    //指定输出的控制点的数量（每个图元），不一定与输入数量相同，也可以新增控制点。此处设置为3，是明确地告诉编译器每个补丁输出三个控制点
        [patchconstantfunc("patchConstantFunc")]    //指定面片常数函数。
        [outputtopology("triangle_cw")] //输出拓扑结构。当GPU创建新三角形时，它需要知道我们是否要按顺时针或逆时针定义它们。有三种：triangle_cw（顺时针环绕三角形）、triangle_ccw（逆时针环绕三角形）、line（线段）。
        [partitioning("integer")]   //分割模式，起到告知GPU应该如何分割补丁的作用。硬分割
        TessControlPoint hull_Tess(
            InputPatch<TessControlPoint, 3> patch,  //向Hull 程序传递曲面补丁的参数
            uint id : SV_OutputControlPointID)
        {
            return patch[id];
        }

        //---------------new----------------
        TessFactors patchConstantFunc(InputPatch<TessControlPoint, 3> patch)    //决定了Patch的属性是如何被细分的，每个Patch调用一次
        {
            TessFactors OUT;

            OUT.edge[0] = OUT.edge[1] = OUT.edge[2] = _TessFactor;  //控制三角形每条边的细分数量
            OUT.inside = _TessFactor;   //控制内部边的细分数量

            return OUT;
        }

        //---------------new----------------
        //让domain传给几何程序与插值器的数据仍然是Varyings结构体
        //但是得写在domain_Tess前面，不然会报错
        Varyings vert_AfterTess(DomainAttributes IN)
        {
            Varyings OUT;

            OUT.positionWS = TransformObjectToWorld(IN.positionOS);
            OUT.positionCS = TransformWorldToHClip(OUT.positionWS);
            OUT.uv = IN.uv;
            OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);

            return OUT;
        }

        //---------------new----------------
        [domain("tri")]
        Varyings domain_Tess(
            TessFactors factors,    //由patchConstantFunc函数生成的细分因子
            OutputPatch<TessControlPoint, 3> patch,     //Hull着色器传入的patch数据。第二个参数需要和InputPatch第二个参数对应
            float3 barycentricCoordinates : SV_DomainLocation)  //由曲面细分阶段阶段传入的顶点位置信息
        {
            DomainAttributes OUT;
            //初始化OUT
            OUT = (DomainAttributes)0;

            //根据重心坐标插入法线数据
            OUT.normalOS = patch[0].normalOS * barycentricCoordinates.x + 
                              patch[1].normalOS * barycentricCoordinates.y + 
                              patch[2].normalOS * barycentricCoordinates.z;


            //根据重心坐标进行位置和UV的插值
            OUT.positionOS = patch[0].positionOS * barycentricCoordinates.x + 
                                patch[1].positionOS * barycentricCoordinates.y + 
                                patch[2].positionOS * barycentricCoordinates.z;

            OUT.uv = patch[0].uv * barycentricCoordinates.x + 
                        patch[1].uv * barycentricCoordinates.y + 
                        patch[2].uv * barycentricCoordinates.z;

            return vert_AfterTess(OUT);
        }

        float4 frag_Tess(Varyings IN) : SV_Target
        {
            // 简单显示法线方向
            return float4(IN.normalWS * 0.5 + 0.5, 1.0);
        }

        
        ENDHLSL
        
        Pass
        {
            Name "TESSPass"
            Tags 
            {
                "LightMode" = "UniversalForward"
            }
            HLSLPROGRAM

            #pragma vertex vert_Tess
            #pragma fragment frag_Tess
            #pragma hull hull_Tess    // 声明hull shader
            #pragma domain domain_Tess  // 声明domain shader

            ENDHLSL
        }
    }
}
