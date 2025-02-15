百人做作业专用



unity fur shader ：[Sorumi/UnityFurShader: 🐈 Fur shader for Unity. (github.com)](https://github.com/Sorumi/UnityFurShader)



### 3.1.1 深度测试





基于模版测试的扩展进行的作业

-  描边
  - [Unity Shader: 理解Stencil buffer并将它用于一些实战案例（描边，多边形填充，反射区域限定，阴影体shadow volume阴影渲染）_unity stencil buffer-CSDN博客](https://blog.csdn.net/liu_if_else/article/details/86316361)
  - [【Unity URP】2种描边方案：模板测试和正面剔除_unity urp 描边-CSDN博客](https://blog.csdn.net/qq_41835314/article/details/129963711)
- 多边形填充
- 反射区域控制
- Shadow volume阴影渲染



#### Stencil与描边



##### 基于stencil的描边

![image-20250209160143460](https://raw.githubusercontent.com/nininias/image-repo/main/img/image-20250209160143460.png)

- 第一个pass

  - ```C
                Name "ForwardLit"
                Tags {
                    "LightMode"="SRPDefaultUnlit"
                }
                
                // 剔除操作 
                // Blend [_SrcBlend][_DstBlend]
                // ZWrite[_ZWrite]
                // Cull[_CullMode0]
              
                Stencil {
                    Ref 2           // 给模板刷值
                    Comp Always     // 始终渲染
                    Pass Replace       // 通过Comp测试，且把当前的Ref值2写入Stencil Buffer中
                }
    ```

- 第二个Pass

  - ```c
                Name "Outline"
                Tags {
                    "LightMode"="UniversalForward"
                }
              
                // // 剔除
                // Cull [_CullMode1] // Cull Front
              
                Stencil {
                    Ref 2
                    Comp NotEqual // 不相等才通过，那么相等的都会被pass，所以着色区域不会做任何渲染，因为前面着色区域Ref都是2
                    Pass Keep     // Stencil Buffer默认值是0，所以其他地方就保留啦
                }
    ```



###### **外扩方法**

-  **1.基于模型空间的法线外扩**

  - ![image-20250209160346838](https://raw.githubusercontent.com/nininias/image-repo/main/img/image-20250209160346838.png)
  - 效果![image-20250209160414272](https://raw.githubusercontent.com/nininias/image-repo/main/img/image-20250209160414272.png)
  - 因为透视效果，产生的描边也有近大远小的透视感
    - <img src="https://raw.githubusercontent.com/nininias/image-repo/main/img/image-20250209160541846.png" alt="image-20250209160541846" style="zoom:50%;" />
    - ![image-20250209164036415](https://raw.githubusercontent.com/nininias/image-repo/main/img/image-20250209164036415.png)

- **2.基于裁剪空间的法线外扩**

  - ```c
                v2f vert(a2v v) {
                    v2f o;
              
                    // 1.模型空间下膨胀
                    v.positionOS.xyz += v.normalOS * _OutlineStrength * 0.01;
                    // VertexPositionInputs vertexPos = GetVertexPositionInputs(v.positionOS.xyz);
                    // o.positionCS = vertexPos.positionCS;
                    // or:
                    o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
              
                    #ifdef _FIXED_ON
              
                    // 2.裁剪空间
                    VertexNormalInputs normalPos = GetVertexNormalInputs(v.normalOS.xyz);
                    float2 normalCS = TransformWorldToHClipDir(normalPos.normalWS).xy; // 世界空间->裁剪空间，只留下xy，不要z的
                    o.positionCS.xy += normalCS * _OutlineStrength * 0.01 * o.positionCS.w;
              
                    #endif
                    
                    return o;
                }
    ```

    - 遇到个问题，很奇怪。外扩法线它不会向着Z轴进行外扩。

  - 在裁剪空间进行法线外扩（感觉效果大差不差）

  - ![image-20250209163945969](D:/TyporaImage/image-20250209163945969.png)![image-20250209164008732](https://raw.githubusercontent.com/nininias/image-repo/main/img/image-20250209164008732.png)<img src="https://raw.githubusercontent.com/nininias/image-repo/main/img/image-20250209163914886.png" alt="image-20250209163914886" style="zoom:50%;" />



当希望近一点的距离可以粗一点，但是太远不要黑乎乎一片时，需要控制`o.positionCS.w`的值。然后可以实现对远处描边的自定义控制。

- 因为这个w的值是和屏幕尺寸有关的<img src="https://raw.githubusercontent.com/nininias/image-repo/main/img/image-20250209170134938.png" alt="image-20250209170134938" style="zoom:50%;" />
  - 手动对W进行钳制<img src="https://raw.githubusercontent.com/nininias/image-repo/main/img/image-20250209172724812.png" alt="image-20250209172724812" style="zoom:67%;" />
  - 不断地调整钳制值，可以自定义远处的描边强度，而不影响近处的，![动画](https://raw.githubusercontent.com/nininias/image-repo/main/img/%E5%8A%A8%E7%94%BB-1739093448701-1.gif)
- 当我没有乘`o.positionCS.w`时，离的很远的时候几乎看不到外轮廓线了（模型空间）
  - ![image-20250209172340714](https://raw.githubusercontent.com/nininias/image-repo/main/img/image-20250209172340714.png)
- 当我乘了`o.positionCS.w`时，离的很远的时候还是可以保持看到轮廓线，而且好像离得远轮廓线反而大。因为W的值是[Near,Far]。相机越远的时候，值越大。带来的效果就可以是离得远的时候放大外轮廓线。（模型空间）
  - ![image-20250209172417819](https://raw.githubusercontent.com/nininias/image-repo/main/img/image-20250209172417819.png)



**可以发现，使用stencial的方法只能实现外轮廓描边。对于内部细节的描边是没有的。**



##### 基于双Pass的几何描边

- 思路是按照之前的Shader入门精要进行调整的，也是基于模型空间。
- 也可以做到远近的描边粗细更改——`o.positionCS.w`
  - ![image-20250209173656492](https://raw.githubusercontent.com/nininias/image-repo/main/img/image-20250209173656492.png)



##### 外扩方式的法线缺点

本身是基于法线的，所以一定会遇到这些情况：

- 凹下去的物体：描边会很奇怪

- 低模：比如一个立方体、法线过渡剧烈的角落，描边会断
- 如果穿透模型，会发现内部一片死黑<img src="https://raw.githubusercontent.com/nininias/image-repo/main/img/image-20250209180825700.png" alt="image-20250209180825700" style="zoom:25%;" />

针对低模这个问题，需要对模型做额外的法线平滑处理，这里可以单独写一个脚本，定义成组件之后有针对性地去平滑法线，这里就不在扩展了。



#### 多边形填充

*感觉可以用来做一些接触才发光的东西，比如热成像*



##### ASE实现多Pass

​	为了实现多边形填充的很多个pass，需要在此学习多pass的使用方法。https://blog.csdn.net/liweizhao/article/details/133719840

1. 复制粘贴一个并改名<img src="https://raw.githubusercontent.com/nininias/image-repo/main/img/image-20250210113942626.png" alt="image-20250210113942626" style="zoom:50%;" />
2. 找到里面的pass，有个额外的pass<img src="https://raw.githubusercontent.com/nininias/image-repo/main/img/image-20250210114037892.png" alt="image-20250210114037892" style="zoom: 33%;" />
3. 对一整个进行复制粘贴，然后结尾加上`/*ase_pass_end*/`（尝试了加了和没加没啥区别）![image-20250210114131787](https://raw.githubusercontent.com/nininias/image-repo/main/img/image-20250210114131787.png)
4. 然后就会多出来了。需要几个就重复几次。根据需要我额外创建了三个pass![image-20250210114346536](https://raw.githubusercontent.com/nininias/image-repo/main/img/image-20250210114346536.png)



##### 多边形填充

- 根据代码进行还原。

  - ```C
    Shader "Unlit/PolygonsBeta"
    {
        Properties
        {
            _MainTex ("Texture", 2D) = "white" {}
        }
        SubShader
        {
            Tags { "RenderType"="Opaque" }
            LOD 100
    
            CGINCLUDE
            #include "UnityCG.cginc"
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };
    
            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };
    
            sampler2D _MainTex;
            float4 _MainTex_ST;
            
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }
            ENDCG
    
            Pass
            {
                Stencil {
                    Ref 0           //0-255
                    Comp always     //default:always
                    Pass IncrWrap       //default:keep
                    Fail keep       //default:keep
                    ZFail IncrWrap  //default:keep
                }
    
                CGPROGRAM
                #pragma vertex vert
                #pragma fragment frag
                // make fog work
                #pragma multi_compile_fog
    
                fixed4 frag (v2f i) : SV_Target
                {
                    // sample the texture
                    fixed4 col = tex2D(_MainTex, i.uv);
                    // apply fog
                    UNITY_APPLY_FOG(i.fogCoord, col);
                    return fixed4(0,0,0,0);
                }
                ENDCG
            }
            
            Pass
            {
                Stencil {
                    Ref 2           //0-255
                    Comp Equal     //default:always
                    Pass keep       //default:keep
                    Fail keep       //default:keep
                    ZFail keep  //default:keep
                }
                CGPROGRAM
                #pragma vertex vert
                #pragma fragment frag
                // make fog work
                #pragma multi_compile_fog
                
                #include "UnityCG.cginc"
    
                fixed4 frag (v2f i) : SV_Target
                {
                    // sample the texture
                    fixed4 col = tex2D(_MainTex, i.uv);
                    // apply fog
                    UNITY_APPLY_FOG(i.fogCoord, col);
                    return fixed4(0.2,0.2,0.2,1);
                }
                ENDCG
            }
    
            Pass
            {
                Stencil {
                    Ref 3          //0-255
                    Comp equal     //default:always
                    Pass keep   //default:keep
                    Fail keep      //default:keep
                    ZFail keep  //default:keep
                }
                CGPROGRAM
                #pragma vertex vert
                #pragma fragment frag
                // make fog work
                #pragma multi_compile_fog
                
                #include "UnityCG.cginc"
    
                fixed4 frag (v2f i) : SV_Target
                {
                    // sample the texture
                    fixed4 col = tex2D(_MainTex, i.uv);
                    // apply fog
                    UNITY_APPLY_FOG(i.fogCoord, col);
                    return fixed4(0.6,0.6,0.6,1);
                }
                ENDCG
            }
    
            Pass
            {
                Stencil {
                    Ref 4          //0-255
                    Comp equal     //default:always
                    Pass keep   //default:keep
                    Fail keep      //default:keep
                    ZFail keep  //default:keep
                }
                CGPROGRAM
                #pragma vertex vert
                #pragma fragment frag
                // make fog work
                #pragma multi_compile_fog
                
                #include "UnityCG.cginc"
    
                fixed4 frag (v2f i) : SV_Target
                {
                    // sample the texture
                    fixed4 col = tex2D(_MainTex, i.uv);
                    // apply fog
                    UNITY_APPLY_FOG(i.fogCoord, col);
                    return fixed4(1,1,1,1);
                }
                ENDCG
            }
        }
    }
    
    ```

  - **实现方法**：

    - 三个pass均开启双面显示
    - 第一个pass按照代码设置，并且修改`LightMode = SRPDefaultUnlit`，由`Pass1`动态修改`Ref`值
      - ![image-20250210132121145](https://raw.githubusercontent.com/nininias/image-repo/main/img/image-20250210132121145.png)
    - 第二个Pass，`LightMode = UniversalForward`,由`Pass2`动态修改`Ref`值
      - ![image-20250210132216605](https://raw.githubusercontent.com/nininias/image-repo/main/img/image-20250210132216605.png)
    - 第三个Pass，`LightMode = UniversalForwardOnly`，由`Pass3`动态修改`Ref`值

- **在URP的环境下发现一个问题，如果是同样的LightMode，有些Pass不会被渲染**

  - ![image-20250210124529835](https://raw.githubusercontent.com/nininias/image-repo/main/img/image-20250210124529835.png)
  - 这在之前[Unity URP中的Single-Pass到底是什么_unity singlepass-CSDN博客](https://blog.csdn.net/wang568270833/article/details/109426645)找到问题所在。
  - **解决方法：**
    - 为不同的Pass的Tags设置不同的LightMode。（实际上也没那么多可以设置的）
  - **完成效果：**
    - 修改三个值方便观察不同的stencil的ref值带来的穿插影响
    - 两个穿插表现为黄色，三个穿插表现为浅蓝色。
    - ![image-20250210132007338](https://raw.githubusercontent.com/nininias/image-repo/main/img/image-20250210132007338.png)



#### 反射区域的裁定

此用法主要是辅助一个反射shader，可以比较简单的模拟出一个镜面效果。

感觉用处好像不太大



####  阴影体shadow volume阴影渲染

我发现如果我不把颜色写入到FrameBuffer里面，用ColorMask遮罩遮住，就会出现这种情况：![image-20250210141836983](https://raw.githubusercontent.com/nininias/image-repo/main/img/image-20250210141836983.png)

包括如果使它透明。好像实现不了，保留了。





### 3.1.2 Z-Test（深度测试）

#### 1、三个立方体遮挡

![img](https://raw.githubusercontent.com/nininias/image-repo/main/img/1624715632826-1531c1ec-eb98-4745-923d-725dc92c1284-1739171814860-1.webp)

<img src="https://raw.githubusercontent.com/nininias/image-repo/main/img/image-20250210152923481.png" alt="image-20250210152923481" style="zoom:67%;" />

![image-20250210152914391](https://raw.githubusercontent.com/nininias/image-repo/main/img/image-20250210152914391.png)

<img src="https://raw.githubusercontent.com/nininias/image-repo/main/img/image-20250210153033124.png" alt="image-20250210153033124" style="zoom:67%;" />

<img src="https://raw.githubusercontent.com/nininias/image-repo/main/img/image-20250210153126727.png" alt="image-20250210153126727" style="zoom:67%;" />

<img src="https://raw.githubusercontent.com/nininias/image-repo/main/img/image-20250210153150643.png" alt="image-20250210153150643" style="zoom:67%;" />

<img src="https://raw.githubusercontent.com/nininias/image-repo/main/img/image-20250210153233163.png" alt="image-20250210153233163" style="zoom:67%;" />





#### 2、X-Ray

##### 实现方法①

- **负责渲染的部分**

  - `RenderType = Transparent`，`Queue = Transparent`
  - `Blend SrcAlpha One`(做特效用的叠加光)
  - `Cull Back`
  - `ZWrite Off` `ZTest GEqual`
  - ![image-20250210155236014](https://raw.githubusercontent.com/nininias/image-repo/main/img/image-20250210155236014.png)

- **另一个部分**

  - 保持默认

    ```C
    Blend One Zero, One Zero
    ZWrite On
    ZTest LEqual
    ```

- **效果**

  - ![动画](https://raw.githubusercontent.com/nininias/image-repo/main/img/%E5%8A%A8%E7%94%BB-1739174144861-3.gif)



##### 实现方法②

参考[Unity URP一分钟实现遮挡透视_urp 透视-CSDN博客](https://blog.csdn.net/farcor_cn/article/details/116197865)

原理差不多



#### 3、Depth Fade

**Depth Fade的代码**

```c
float4 screenPos10 = IN.ase_texcoord3;
float4 ase_screenPosNorm10 = screenPos10 / screenPos10.w;	//转化为标准化的屏幕空间坐标，将齐次坐标转换为非齐次坐标，进行投影变换，从而得到标准化的屏幕空间坐标。
ase_screenPosNorm10.z = ( UNITY_NEAR_CLIP_VALUE >= 0 ) ? ase_screenPosNorm10.z : ase_screenPosNorm10.z * 0.5 + 0.5;//判断近裁剪平面，如果有值就保持，否则进行归一化处理。将[-1,1]转换到[0,1]
float screenDepth10 = LinearEyeDepth(SHADERGRAPH_SAMPLE_SCENE_DEPTH( ase_screenPosNorm10.xy ),_ZBufferParams);//将深度缓冲区的非线性值转换为线性观察空间深度（单位为世界空间距离）
float distanceDepth10 = saturate( abs( ( screenDepth10 - LinearEyeDepth( ase_screenPosNorm10.z,_ZBufferParams ) ) / ( 1.0 ) ) );//表示当前像素与背景之间的距离比例，0 表示完全贴合，1 表示达到最大距离。
float3 temp_cast_0 = (( 1.0 - distanceDepth10 )).xxx;
```

- ASE的`Depth Fade`节点实现<img src="https://raw.githubusercontent.com/nininias/image-repo/main/img/image-20241120173125226.png" alt="image-20241120173125226" style="zoom:33%;" />，但是对于渲染次序以及混合模式得调对。
  - 大概的意思就是，通过将场景深度与物体深度做差，并且限制到[0,1]，可以实现在相交的部分出现值。
  - 需要能够通过深度测试但是关闭深度写入。需要处于透明的渲染队列：`ZTest Off ` `“RenderType” = "Transparent"` `"Queue"="Transparent"`
- <img src="https://raw.githubusercontent.com/nininias/image-repo/main/img/image-20241120173154145-1739258157660-1.png" alt="image-20241120173154145" style="zoom:50%;" />——可以实现类似原神的元素视野效果，它会对接触到的物体表面设定值为1



#### 4、使用深度做一个水体渲染

水体渲染在第五章的时候会重新进行知识的完整归纳，所以这里只是先进行简单的模拟深度。

![image-20250211150640465](https://raw.githubusercontent.com/nininias/image-repo/main/img/image-20250211150640465.png)

![image-20250211150742380](https://raw.githubusercontent.com/nininias/image-repo/main/img/image-20250211150742380.png)

- 实现步骤：
  - 因为重建世界坐标需要深度，与背景进行对比，因此要求关闭深度写入，并且开启不透明度序列，以及不透明的渲染样式：`ZTest Off ` `“RenderType” = "Transparent"` `"Queue"="Transparent"`
  - ![image-20250211151122558](D:/TyporaImage/image-20250211151122558.png)![image-20250211151135115](https://raw.githubusercontent.com/nininias/image-repo/main/img/image-20250211151135115.png)

- 可以尝试添加焦散，浮沫，波纹，反射，菲涅尔等。
  - 对于完整的学习我会向这位大佬一样[[Unity/URP学习\]风格化水体渲染(一)_unity urp水面-CSDN博客](https://blog.csdn.net/Phantom1516/article/details/128762607)
  - 因为使用到了根据深度重建世界坐标的知识点，可能需要参考[【unity shader/风格化水表面渲染/基础笔记】urp代码版01-水面与水底的深度判断_urp 水渲染-CSDN博客](https://blog.csdn.net/qq_43544518/article/details/128747765)
  - 等后面学到水体渲染的时候会对这个根据深度重建世界坐标重新学习，届时会回顾shader入门精要



### 3.3 曲面细分与几何着色器 大规模草渲染



#### **曲面细分代码初尝试**

参考：[Unity渲染基础：URP下曲面细分的实现 - 知乎 (zhihu.com)](https://zhuanlan.zhihu.com/p/359999755)

![img](https://raw.githubusercontent.com/nininias/image-repo/main/img/v2-f2533a10993773785a1b1ce226e796c9_1440w.jpg)

**效果**

- <img src="https://raw.githubusercontent.com/nininias/image-repo/main/img/image-20250212163051148.png" alt="image-20250212163051148" style="zoom:33%;" />
- ![动画](https://raw.githubusercontent.com/nininias/image-repo/main/img/%E5%8A%A8%E7%94%BB-1739349828608-3.gif)
  - 直接从Unity新建的球
  - 简单的演示效果
  - 可以细分更多的三角面
  - 细分之后可以添加置换贴图，对物体进行真实的顶线修改
- ![动画](https://raw.githubusercontent.com/nininias/image-repo/main/img/%E5%8A%A8%E7%94%BB-1739350133709-5.gif)
  - 通过调整数值可以变化曲面细分的数量
  - 支持动态调整置换贴图的强度

**代码**

```c#
Shader "Stardy/URP/Text/3.3 Test_Tessellation"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        [Space(20)]
        [Header(Tessellation)]
        _TessFactor("Tess Factor",Range(1,64)) = 4
        _Displacement("Displacement", Range(0, 1)) = 0.1
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

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        CBUFFER_START(UnityPerMaterial)
        uniform float4 _MainTex_ST;
        uniform float _TessFactor;
        uniform float _Displacement;
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
        [domain("tri")]
        [outputcontrolpoints(3)]
        [patchconstantfunc("patchConstantFunc")]
        [outputtopology("triangle_cw")]
        [partitioning("integer")]
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

            OUT.edge[0] = OUT.edge[1] = OUT.edge[2] = _TessFactor;
            OUT.inside = _TessFactor;

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
            float3 normalOS = patch[0].normalOS * barycentricCoordinates.x + 
                              patch[1].normalOS * barycentricCoordinates.y + 
                              patch[2].normalOS * barycentricCoordinates.z;


            //根据重心坐标进行位置和UV的插值
            float4 positionOS = patch[0].positionOS * barycentricCoordinates.x + 
                                patch[1].positionOS * barycentricCoordinates.y + 
                                patch[2].positionOS * barycentricCoordinates.z;

            float2 uv = patch[0].uv * barycentricCoordinates.x + 
                        patch[1].uv * barycentricCoordinates.y + 
                        patch[2].uv * barycentricCoordinates.z;

             //置换贴图替换
             float displacement = SAMPLE_TEXTURE2D_LOD(_MainTex, sampler_MainTex, uv, 0).r * _Displacement;


             positionOS.xyz += displacement * normalOS;

             OUT.positionOS = positionOS;
             OUT.uv = uv;
             OUT.normalOS = normalOS;


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

```



##### **代码解析**

###### 	**1. `#pragma target 4.6`**

使用细分时的最低着色器目标级别为4.6。如果我们不手动设置，Unity将发出警告并自动使用该级别



###### 	**2. `#pragma`的声明要多两个阶段**

`#pragma hull hull_Tess`    和   `#pragma domain domain_Tess` ,接下来会对这两个阶段进行完善



###### 	**3. 顶点细分着色器**

```C
TessControlPoint vert_Tess(Attributes IN)
        {
            TessControlPoint OUT;
            OUT.positionOS = IN.positionOS;
            OUT.uv = IN.texcoord;
            OUT.normalOS = IN.normalOS;
            return OUT;
        }
```

- 将原始顶点的位置，纹理坐标和法线等需要的数据进行简单的传递给`TessControlPoint`。

- 不再像以前那样负责把顶点坐标从ObjectSpace转换到ClipSpace，或是贴图UV转换等工作，此处只是简单地将`Attributes`中的数据传递给曲面细分阶段的`ControlPoint`。

- `ControlPoint`的结构体如下：

  - ```c
    struct TessControlPoint //这个结构体作为Hull Shader的输入/输出控制点
    {
                float4 positionOS : INTERNALTESSPOS;    //曲面细分专用语义，标记这个位置数据将参与细分计算
                float2 uv         : TEXCOORD0;
                float3 normalOS   : NORMAL;
                // float4 color : COLOR;
    };
    ```

    - 对于物体空间位置信息，需要用专用的语义`INTERNALTESSPOS`注明

- `Attribute`的结构体如下：

  - ```C
    //structs
            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 texcoord   : TEXCOORD0;
                float3 normalOS   : NORMAL;
            };
    ```

    - **在`Varyings`结构体里面**，对于裁切空间的`positionCS`，会使用`SV_POSITION`语义进行特别注明：`float4 positionCS  : SV_POSITION;`

  - 对比可见，两者结构体几乎相同，只是`ControlPoint`中的`vertex`使用`INTERNALTESSPOS`代替`POSITION`语意，否则编译器会报位置语义的重用

  

###### 	        **4. Hull着色器**

- 细分阶段，确定如何细分补丁

```c
        //主要的壳着色器，可以处理三角形，四边形或等值线。我们必须告诉它必须使用什么表面并提供必要的数据。这是 hull 程序的工作。
		//仅仅函数声明是不行的，编译器会报错，要求我们指定详细的参数，
        [domain("tri")]
        [outputcontrolpoints(3)]    
        [patchconstantfunc("patchConstantFunc")]   //补丁常量函数，与Hull并行运行的子阶段 
        [outputtopology("triangle_cw")]
        [partitioning("integer")]   
        TessControlPoint hull_Tess(
            InputPatch<TessControlPoint, 3> patch,  //向Hull 程序传递曲面补丁的参数
            uint id : SV_OutputControlPointID)
        {
            return patch[id];
        }
```

- `[domain("tri")] `：指定patch的类型，可选的有：`tri`(三角形)、`quad`（四边形）、`isoline`(线段)
- `[outputcontrolpoints(3)]`：指定输出的控制点的数量（每个图元），不一定与输入数量相同，也可以新增控制点。此处设置为3，是明确地告诉编译器每个补丁输出三个控制点
- `[patchconstantfunc("patchConstantFunc")] `：指定补丁常数函数。GPU必须知道应将补丁切成多少部分。这不是一个恒定值，每个补丁可能有所不同。必须提供一个评估此值的函数，称为补丁常数函数（Patch Constant Functions），与Hull并行运行的子阶段
- `[outputtopology("triangle_cw")] `： 输出拓扑结构。当GPU创建新三角形时，它需要知道我们是否要按顺时针或逆时针定义它们。有三种：`triangle_cw`（顺时针环绕三角形）、`triangle_ccw`（逆时针环绕三角形）、`line`（线段）。
- `[partitioning("integer")]`：分割模式，起到告知GPU应该如何分割补丁的作用呢，共有三种：`integer`（硬分割），`fractional_even`（软渐变分割），`fractional_odd`（软渐变分割）。`TessControlPoint hull_Tess(InputPatch<TessControlPoint, 3> patch,uint id : SV_OutputControlPointID)`:InputPatch参数是向Hull 程序传递曲面补丁的参数。Patch是网格顶点的集合。必须指定顶点的数据格式。
  - 在处理三角形时，每个补丁将包含三个顶点，此数量必须指定为`InputPatch`的第二个模板参数，所以第二个参数设置为3。
  - Hull程序的工作是将所需的顶点数据传递到细分阶段。尽管向其提供了整个补丁，但该函数一次仅应输出一个顶点。补丁中的每个顶点都会调用一次它，并带有一个附加参数，该参数指定应该使用哪个控制点（顶点）。该参数是具有`SV_OutputControlPointID`语义的无符号整数。



###### 	**5. 补丁常数函数（Patch Constant Function）**

```C
        TessFactors patchConstantFunc(InputPatch<TessControlPoint, 3> patch)
        {
            TessFactors OUT;
            OUT.edge[0] = OUT.edge[1] = OUT.edge[2] = _TessFactor;
            OUT.inside = _TessFactor;
            return OUT;
        }
```

- 决定Patch的属性是如何细分的。
  - 这意味着它每个Patch仅被调用一次，而不是每个控制点被调用一次。这就是为什么它被称为常量函数，在整个Patch中都是常量的原因。
  - 这里的`InputPatch`是输入
- `edge[3]`：控制三角形每条边的细分因子
- `inside`：控制内部区域的细分密度
- **这是决定曲面细分程度的==核心控制点==**

**输出的结构体：**

```C
struct TessFactors	//细分因子
        {
            float edge[3] : SV_TessFactor;	//三个细分因子
            float inside  : SV_InsideTessFactor;	//第四个细分因子
        };      
```

- 为了**确定如何细分三角形**，GPU使用了四个细分因子。三角形面片的每个边缘都有一个因数。三角形的内部也有一个因素。三个边缘向量必须作为具有`SV_TessFactor`语义的float数组传递。内部因素使用`SV_InsideTessFactor`语义
  - 实际上，此功能是与HullProgram并行运行的子阶段。<img src="https://raw.githubusercontent.com/nininias/image-repo/main/img/v2-d4a32cb71db01807810331a66dfd53eb_1440w.jpg" alt="img" style="zoom: 50%;" />



######          **6. Domain着色器**

- **已知如何细分补丁，评估结果并生成最终三角形的顶点。**

```c
Varyings vert_AfterTess(DomainAttributes IN)
{
            Varyings OUT;
            OUT.positionWS = TransformObjectToWorld(IN.positionOS);
            OUT.positionCS = TransformWorldToHClip(OUT.positionWS);
            OUT.uv = IN.uv;
            OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);
            return OUT;
}

[domain("tri")]
DomainAttributes domain_Tess(
            TessFactors factors,
            OutputPatch<TessControlPoint, 3> patch,
            float3 barycentricCoordinates : SV_DomainLocation)
{
            DomainAttributes OUT;
            OUT = (DomainAttributes)0;
            //根据重心坐标插入法线数据
float3 normalOS = patch[0].normalOS * barycentricCoordinates.x + 
                  patch[1].normalOS * barycentricCoordinates.y + 
                  patch[2].normalOS * barycentricCoordinates.z;
            //根据重心坐标进行位置和UV的插值
float4 positionOS = patch[0].positionOS * barycentricCoordinates.x + 
                    patch[1].positionOS * barycentricCoordinates.y + 
                    patch[2].positionOS * barycentricCoordinates.z;
float2 uv = patch[0].uv * barycentricCoordinates.x + 
            patch[1].uv * barycentricCoordinates.y + 
            patch[2].uv * barycentricCoordinates.z;
             //置换贴图替换
             float displacement = SAMPLE_TEXTURE2D_LOD(_MainTex, sampler_MainTex, uv, 0).r * _Displacement;
             positionOS.xyz += displacement * normalOS;
             OUT.positionWS = TransformObjectToWorld(positionOS.xyz);
             OUT.positionCS = TransformWorldToHClip(OUT.positionWS);
             OUT.uv = uv;
             OUT.normalWS = TransformObjectToWorldNormal(normalOS);
            return OUT;
}
```

- 每个顶点都会调用一次Domain着色器。
  - 计算量很大，而且所有的顶点信息都会在这里重新计算，最后将顶点坐标转换到投影空间。
- **解析**
  - `OutputPatch`，是输出补丁，即生成补丁。
  - `[domain("tri")]`：Hull着色器和Domain着色器都作用于相同的域，即三角形。通过domain属性再次发出信号
  - `TessFactors factors`：**由`patchConstantFunc`补丁常数函数输入**，细分参数
  - `OutputPatch<TessControlPoint, 3> patch`：由Hull着色器传入Patch数据，**尖括号的第二个参数与Hull着色器中的`InputPatch`对应**。
  - `SV_DomainLocation`：由曲面细分阶段阶段传入的顶点位置信息。
- **说明**
  - Hull只是确定补丁的细分方式，不会产生任何新的顶点。
    - 但是**它会为这些顶点提供重心坐标。**
      - `[domain("tri")]`提供重心坐标，用于三角形细分
      - `[domain("quad")]`提供UV坐标[0,1]，用于四边形细分
      - `[domain("isoline")]`提供UV坐标，用于曲线细分
    - 使用这些坐标来导出最终顶点，取决于Domain着色器。为了使之成为可能，**每个顶点都会调用一次域函数，并为其提供重心坐标。**
  - **经过了Domain之后，就有了新的顶点**，之后这些新生成的顶点会被发送到几何着色器或者是光栅化插值器。但我们不应该让它来替代顶点着色器，因为**此阶段之后的几何程序或插值器需要Varyings数据，而不是Attributes。**
    - 因此我们的解决办法是，让Domain着色器接管原始顶点的程序的指责。
      - 即，结尾调用新写的顶点着色器`AfterTessVertProgram`。



##### 总结

- **三个结构体**
  - `TessControlPoint`给Hull Shader输入输出，以及作为patch的参数
  - `TessFactors`定义细分因子在补丁常数函数被用来定义细分方式
  - `DomainAttributes`用来Domain Shader真正的生成顶点，并且传回给顶点着色器
    - 也可以自行调用顶点着色器，保证传出来的是`Varyings`
- **一个函数**
  - `patchConstantFunc`对顶点的如何细分，对结构体`TessFactors`操作
    - 需传入`InputPatch`，并且指定输出定点数：`(InputPatch<TessControlPoint, 3> patch)`
- **两个shader**
  - `TessControlPoint hull`：定义细分的方式，但是不进行细分。
    - **传入**
      - 补丁的参数`InputPatch<TessControlPoint, 3> patch`，
      - 新生成的控制点的ID：`uint id : SV_OutputControlPointID`
    - 需要很多**前置设置**
      - `[domain("tri")]`：指定patch类型
      - `[outputcontrolpoints(3)] `：指定每个图元输出的控制点的数量。
      - `[patchconstantfunc("patchConstantFunc")]`：指定面片常数函数。
      - `[outputtopology("triangle_cw")]`：指定输出拓扑结构。
      - `[partitioning("integer")]`：指定分割模式。
  - `domain`：按照Hull Shader提供的规则，生成顶点。
    - **传入**
      - `TessFactors factors`：由`patchConstantFunc`函数指定的细分因子
      - `OutputPatch<TessControlPoint, 3> patch`：Hull传过来的patch数据，第二个参数需要和`InputPatch`相对应。
      - `float3 barycentricCoordinates : SV_DomainLocation`：三角形类型的`SV_DomainLocation`还会带有重心坐标
    - **前置设置**
      - `[domain("tri")]`：指定patch类型





#### **几何着色器代码初尝试**

​	**用几何着色器稍微移动一下物体，达到一种不改变网格而移动网格顶点的效果**



**前置知识**

![img](https://raw.githubusercontent.com/nininias/image-repo/main/img/v2-4a762aa411bad55ebe504c2ac5494dba_1440w.jpg)

​	**几何着色器阶段（Geometry Shader）**位于顶点和片段阶段之间。GS会调用单个图元作为输入，并可能会输出多个，也可能不输出图元。

​	应用：输入顶点，然后对这些顶点做处理。可以删除，移动或生成顶点。

- 可以按照某种规律生成顶点，比如拿来做**草**



**效果**

![动画](https://raw.githubusercontent.com/nininias/image-repo/main/img/%E5%8A%A8%E7%94%BB-1739371127805-11.gif)



**代码**

```c
Shader "Stardy/URP/Text/3.3 Test_GES"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _NormalControl ("Normal Control", float) = 0.5
    }
    SubShader
    {

        Tags 
        { 
            "RenderType"="Opaque" 
            "RenderPipeline" = "UniversalRenderPipeline"
        }
        
        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"


        struct Attributes
        {
            float4 positionOS : POSITION;
            float3 normalOS   : NORMAL;
        };

        struct Varyings
        {
            float4 positionOS : SV_POSITION;
            float3 normalOS   : NORMAL;
        };

        //-------------new code-------------
        struct GeometryOutput
        {
            float4 positionCS : SV_POSITION;
            float3 normalOS   : TEXCOORD0;
        };



        CBUFFER_START(UnityPerMaterial)
        uniform float4 _Color;
        uniform float _NormalControl;
        CBUFFER_END

        Varyings vert_Common (Attributes IN)
        {
            Varyings OUT;

            OUT.positionOS = IN.positionOS;
            OUT.normalOS = IN.normalOS;

            return OUT;
        }

        //-------------new code-------------
        [maxvertexcount(3)]
        void geom(
            triangle Varyings IN[3],
            inout TriangleStream<GeometryOutput> stream)
        {
            GeometryOutput OUT;

            //通过扩展几何创建新三角形
            for(int i = 0; i < 3; i++)
            {   
                float4 positionEXT = IN[i].positionOS + float4(IN[i].normalOS * _NormalControl ,1.0);
                OUT.positionCS = TransformObjectToHClip(positionEXT);
                OUT.positionCS += float4(IN[i].normalOS * _NormalControl ,1.0);
                OUT.normalOS = IN[i].normalOS;
                stream.Append(OUT);   //这是什么？
            }
            stream.RestartStrip();//这是什么？
        }

        half4 frag_Common (GeometryOutput IN) : SV_Target
        {
            return _Color * float4(abs(IN.normalOS), 1.0);
        }

        ENDHLSL

        Pass
        {
            Name "GES_Pass"
            Cull Off
            Tags
            {
                "LightMode" = "UniversalForward"
            }
            HLSLPROGRAM
            #pragma vertex vert_Common
            #pragma fragment frag_Common
            #pragma geometry geom

            ENDHLSL
        }
    }
}
```



##### **1. 目标着色器版本**

`#pragma target 4.0 `仅当目标着色器模型为4.0或更高版本时才支持几何着色器。



##### 2. 声明函数

自定义函数名，只需要声明了之后，编译调用(`geometry`)它即可。

```C
#pragma geometry geom	//函数的调用

……
[maxvertexcount(3)]
        void geom(
            triangle Varyings IN[3],
            inout TriangleStream<GeometryOutput> stream)
        {
            GeometryOutput OUT;

            //通过扩展几何创建新三角形
            for(int i = 0; i < 3; i++)
            {   
                float4 positionEXT = IN[i].positionOS + float4(IN[i].normalOS * _NormalControl ,1.0);
                OUT.positionCS = TransformObjectToHClip(positionEXT);
                OUT.positionCS += float4(IN[i].normalOS * _NormalControl ,1.0);
                OUT.normalOS = IN[i].normalOS;
                stream.Append(OUT); //每个Append()调用生成一个新顶点
            }
            stream.RestartStrip();
        }
```

- `[maxvertexcount(3)]`：表示输出顶点数的最大值。因为我们正在处理三角形，所以每次调用总是输出三个顶点。

- `triangle Varyings IN[3]`：`triangle`表示我们正在处理的原始数据，在这里是三角形，其他类型还有`line`和`point`。**必须在输入类型之前指定。**

  - 由于三角形每个都有三个顶点，因此我们正在研究三个结构的数组。必须明确定义它。

- `inout TriangleStream<GeometryOutput> stream`：由于几何着色器可以输出的顶点数量各不相同，因此我们没有统一的返回类型。

  - 相反，**几何着色器将写入图元流**。在例子中，它是一个`TriangleStream`，其他的类型还有`PointStream`、`LineStream`，**必须将其指定为==inout==参数**。
  - `stream.Append(OUT)`写流。每次调用Append，就会添加一个顶点到当前正在构建的图元中。
    - 例如，如果处理一个点并想生成一个三角形，就需要调用Append三次，每次传入一个顶点。
  - ` stream.RestartStrip();`结束该图元，生成新图元。
    - 比如，添加了三个顶点形成一个三角形后，调用`RestartStrip`来结束这个三角形，接下来的Append调用会开始构建新的图元，三角形或线条。

- `GeometryOutput`的代码：

  - ```C
    struct GeometryOutput
            {
                float4 positionCS : SV_POSITION;
                float3 normalOS   : TEXCOORD0;
            };
    ```



##### 总结

- **一个函数直接调用**
  - `#pragma geometry geom`：调用
  - **函数**
    - `[maxvertexcount(3)]`前置顶点数量设置
    - **传入**
      - `triangle Varyings IN[3]`：处理对象和结构体
      - `inout TriangleStream<GeometryOutput> stream`:输入输出的流，通过`stream.Append(OUT);`进行加流，加入对应泛型里的结构体。`stream.Append`方法用于将新的顶点添加到输出流中。



---



#### 曲面细分+几何着色器生成交互草案例

参考：[Unity Grass 着色器教程 (roystan.net)](https://roystan.net/articles/grass-shader/)

[菜鸡都能学会的Unity草地shader - 知乎 (zhihu.com)](https://zhuanlan.zhihu.com/p/433385999)

1. **几何着色器生成一个简单的三角形**

   - <img src="https://raw.githubusercontent.com/nininias/image-repo/main/img/image-20250213140854482.png" alt="image-20250213140854482" style="zoom:33%;" />

     ```c
     //----------geo Shader ---------
     [maxvertexcount(3)]
             void geom(
                 triangle Varyings input[3] ,
                 inout TriangleStream<geometryOutput> triStream)
             {
                 geometryOutput output;
                 output = (geometryOutput)0;
                 output.positionCS = TransformObjectToHClip(float4(0.5, 0, 0 , 1));
                 triStream.Append(output);
                 output.positionCS = TransformObjectToHClip(float4(-0.5, 0, 0 , 1));
                 triStream.Append(output);
                 output.positionCS = TransformObjectToHClip(float4(0, 1, 0 , 1));
                 triStream.Append(output);              
             }
     ```

   - 为了使得原本的物体的网格能够显示出来，需要对物体原有的三角形进行遍历

     - 先`[maxvertexcount(6)]`改为6个

     - 然后添加

       ```C
       //----------geo Shader ---------
       //保留原始三角形
       for(int i = 0; i < 3; i++)
       {
                       output.positionCS = input[i].positionCS;
                       output.positionWS = input[i].positionWS;
                       triStream.Append(output);
       }
       triStream.RestartStrip();
       ```

   - 保持这个小三角形而不显示原来的网格

2. **分散三角形**

   - 计算的时候没有用原始的顶点位置作为三角形的起始位置，所以很多很多个顶点的三角形都长到了一起

     - 加入偏倚解决此问题<img src="https://raw.githubusercontent.com/nininias/image-repo/main/img/image-20250213142801322.png" alt="image-20250213142801322" style="zoom:25%;" />

     - ```C
       output.positionCS = TransformObjectToHClip(input[0].positionOS + float3(0.5, 0, 0 ));
       output.positionCS = TransformObjectToHClip(input[0].positionOS + float3(-0.5, 0, 0 ));
       output.positionCS = TransformObjectToHClip(input[0].positionOS + float3(0, 1, 0 ));
       ```

     - 只在平面上看上去是对的，它的形状都是固定朝向<img src="https://raw.githubusercontent.com/nininias/image-repo/main/img/image-20250213143019066.png" alt="image-20250213143019066" style="zoom: 33%;" />（圆柱）

3. **转换到切线空间**

   - 我们需要让三角形长在顶点上，并且能够在mesh的所处的空间生长

     - 自行构建一个TBN矩阵，然后右乘（发现左乘的时候方向反过来了）

     - ```C
       //----------geo Shader ---------
       
       //用来定义生成草叶的位置，封装函数方便重复调用
       inline geometryOutput VertexOutput(float3 positionOS,float2 uv)
       {
       geometryOutput output;
       output.positionCS = TransformObjectToHClip(positionOS);
       output.positionWS = TransformObjectToWorld(positionOS);
       output.uv = uv;
       return output;
       }
       
       float3 positionOS = input[0].positionOS;
       float3 normalOS = input[0].normalOS;
       float4 tangentOS = input[0].tangentOS;
       float3 BinormalOS = normalize(cross(normalOS, tangentOS.xyz) * tangentOS.w);	//乘切线的W判断方向用
       
       float3x3 TBN_T2O = float3x3(tangentOS.xyz,BinormalOS,normalOS);//列向量排布
       triStream.Append(VertexOutput(positionOS + mul(float3(0.5,0.0,0.0) , TBN_T2O) , float2(0.0,0.0)));
       triStream.Append(VertexOutput(positionOS + mul(float3(-0.5,0.0,0.0) , TBN_T2O) , float2(1.0,0.0)));
       triStream.Append(VertexOutput(positionOS + mul(float3(0.0,0.0,1.0) , TBN_T2O) , float2(0.5,1.0))); 
       ```

       - 写了一个额外的内置函数，方便重复调用
       - UV用来后面做渐变
         - UV长这样，逆时针三角形：<img src="https://raw.githubusercontent.com/nininias/image-repo/main/img/grass-uv.png" alt="img" style="zoom:33%;" />

     - 然后用UV来lerp输出颜色

       - <img src="https://raw.githubusercontent.com/nininias/image-repo/main/img/image-20250213152313913.png" alt="image-20250213152313913" style="zoom:25%;" />

       - ```C
         half4 frag_Common (geometryOutput input) : SV_Target
         {
         return lerp(_BottomColor, _TopColor, input.uv.y);
         }
         ```

4. **随机数的应用**

   - **随机数生成**

     ```C
     //随机数生成函数——输出[0,1]
     inline float rand(float3 co)
     {
     return frac(sin(dot(co.xyz, float3(12.9898,78.233,45.5432))) * 43758.5453);
     }
     ```

     - 后面再乘个2π，

   - **轴旋转矩阵**

     ```c
     //围绕轴旋转矩阵——罗德里格斯旋转矩阵
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
     ```

   - **应用随机旋转轴**

     ```C
     //----------geo Shader ---------
     
     //随机旋转角度
     float3x3 facingRotationMatrix = AngleAxis3x3(rand(positionOS + _RotateSeed.xyz) * CUSTOM_TWO_PI, float3(0.0,0.0,1.0));
     //随机旋转矩阵和TBN矩阵相乘（需考虑顺序，这里是右乘）
     float3x3 transformationMatrix = mul(facingRotationMatrix,TBN_T2O);
     
     triStream.Append(VertexOutput(positionOS + mul(float3(0.5,0.0,0.0) , transformationMatrix) , float2(0.0,0.0)));
     ```

   - **应用随机弯折**

     ```C
     //----------geo Shader ---------
     
     float3x3 bendRotationMatrix = AngleAxis3x3(rand(positionOS + _RotateSeed.yzx) * CUSTOM_PI * _BendRotationRandom * 0.5 , float3(-1.0,0.0,0.0));
     
     //矩阵的混合（需考虑顺序）
     float3x3 transformationMatrix = mul(bendRotationMatrix,mul(facingRotationMatrix,TBN_T2O));
     ```

   - **应用随机高度宽度**

     ```c
     //----------geo Shader ---------
     //随机宽高
     float height = (rand(positionOS.xyz) * 2 - 1) * _BladeHeightRandom + _BladeHeight  ;
     float width = (rand(positionOS.xyz) * 2 - 1) * _BladeWidthRandom + _BladeWidth ;
     
     //逆时针三角形
     triStream.Append(VertexOutput(positionOS + mul(float3(-width,0.0,0.0) , transformationMatrix) , float2(0.0,0.0)));
     triStream.Append(VertexOutput(positionOS + mul(float3(width,0.0,0.0) , transformationMatrix) , float2(1.0,0.0)));
     triStream.Append(VertexOutput(positionOS + mul(float3(0.0,0.0,height) , transformationMatrix) , float2(0.5,1.0))); 
     ```

   - **效果**

     - <img src="https://raw.githubusercontent.com/nininias/image-repo/main/img/image-20250213163035926.png" alt="image-20250213163035926" style="zoom:33%;" />
     - 每个顶点有**随机朝向，随机宽度，随机高度**
     - 下一步增加顶点

5. **曲面细分增加顶点**

   - <img src="https://raw.githubusercontent.com/nininias/image-repo/main/img/image-20250213204500585.png" alt="image-20250213204500585" style="zoom:33%;" />

   - 把之前的曲面细分的代码复制粘贴过来，主要是生成更多的顶点。

     - ```c
       
       struct Tess_Attributes
       {
           float4 positionOS : POSITION;
           float2 texcoord   : TEXCOORD0;
           float3 normalOS   : NORMAL;
           float4 tangentOS  : TANGENT;
       };
       struct Tess_Varyings
       {
           float4 positionCS : SV_POSITION;
           float3 positionWS : TEXCOORD0;
           float3 positionOS : TEXCOORD1;
           float2 uv         : TEXCOORD2;
           float3 normalOS   : TEXCOORD3;
           float4 tangentOS  : TEXCOORD4;
       };
       
       struct Tess_ControlPoint //这个结构体作为Hull Shader的输入/输出控制点
       {
           float4 positionOS : INTERNALTESSPOS;  
           float2 uv         : TEXCOORD0;
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
           float2 uv         : TEXCOORD1;
           float3 normalOS   : TEXCOORD2;
           float4 tangentOS  : TEXCOORD3;
       };
       
       Tess_ControlPoint vert_Tess(Tess_Attributes IN)
               {
                   Tess_ControlPoint OUT;
                   OUT.positionOS = IN.positionOS;
                   OUT.uv = IN.texcoord;
                   OUT.normalOS = IN.normalOS;
                   OUT.tangentOS = IN.tangentOS;
                   return OUT;
               }
       
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
       ```

     - 因为对结构进行了调整，所以需要复制粘贴新的结构体，并且把原始的`Attributes`结构体，`Varyings`结构体以及原始的顶点着色器`vert_Common`注释掉，使用Tesselation的`Tess_Attributes`结构体，`Tess_Varyings`结构体和`vert_Tess`顶点着色器。

     - `void geom(triangle Varyings input[3],inout TriangleStream<geometryOutput> triStream)` 里面的`Varyings `结构体修改成曲面细分传过来的`Tess_Varyings`结构体

     - 此时的编译修改为：

       ```C
       #pragma vertex vert_Tess	//曲面细分的顶点shader
       #pragma hull hull_Tess	//Hull→Domain
       #pragma domain domain_Tess	//Domain→Geometry
       #pragma geometry geom	//Geometry→Vertex
       #pragma fragment frag_Common	//保持原版的片元着色器
       ```

   - **效果**

     - ![动画](https://raw.githubusercontent.com/nininias/image-repo/main/img/%E5%8A%A8%E7%94%BB-1739451423843-1.gif)

6. **添加风动效果**

   - ```C
      //UV
     float2 uv = positionOS.xz * _WindDistortionMap_ST.xy + _WindDistortionMap_ST.zw + _WindFrequency.xy * _Time.y;
     //Wind Construct
     float2 windSample = SAMPLE_TEXTURE2D_LOD(_WindDistortionMap, sampler_WindDistortionMap, uv * 2 - 1, 0) * _WindStrength;
     float3 wind = normalize(float3(windSample.x,windSample.y,0.0));//wind Vector
     float3x3 windRotationMatrix = AngleAxis3x3(CUSTOM_PI * windSample,wind);
     
     //矩阵的混合（需考虑顺序）
     float3x3 transformationMatrix = mul(windRotationMatrix,mul(facingRotationMatrix,mul(bendRotationMatrix,TBN_T2O)));
     float3x3 transformationMatrixFacing = mul(facingRotationMatrix,TBN_T2O);//用于底部的两个顶点特殊处理，不让其风动和弯曲
     
     triStream.Append(VertexOutput(positionOS + mul(float3(-width,0.0,0.0) , transformationMatrixFacing) , float2(0.0,0.0)));//两个底部的顶点不做风动效果以及弯折
     triStream
         .Append(VertexOutput(positionOS + mul(float3(width,0.0,0.0) , transformationMatrixFacing) , float2(1.0,0.0)));
     ```

     - 因为不能让底部的两个顶点受到风动，因此对于它俩采用不同的矩阵，并且加入到`triStream.Append`中
     - 采样了一张`_WindDistortionMap`<img src="https://raw.githubusercontent.com/nininias/image-repo/main/img/v2-1b2e2456e538b2a83ecfcb3b5c56a3b6_r.jpg" alt="v2-1b2e2456e538b2a83ecfcb3b5c56a3b6_r" style="zoom:25%;" />
     - **效果**
       - ![动画](https://raw.githubusercontent.com/nininias/image-repo/main/img/%E5%8A%A8%E7%94%BB-1739504355509-2.gif)

7. **草叶的曲率，多片草叶**

   - <img src="https://raw.githubusercontent.com/nininias/image-repo/main/img/grass-construction.gif" alt="img" style="zoom:25%;" />

   - **代码**

      - ```C
         for(int i = 0; i < BLADE_SEGMENTS; i++)
         {
         float t = i / (float)BLADE_SEGMENTS;
         float segmentHeight = height * t;
         float segmentWidth = width * (1 - t);
         //底部的两个顶点不动，也就是i = 0的情况
         float3x3 transformationMatrix_T = i == 0 ? transformationMatrixFacing : transformationMatrix;
         triStream.Append(GenerateGrassVertex(positionOS , segmentWidth , segmentHeight , float2(0.0,t) , transformationMatrix_T));//两个底部的顶点不做风动效果以及弯折
         triStream.Append(GenerateGrassVertex(positionOS , -segmentWidth , segmentHeight , float2(1.0,t) , transformationMatrix_T));
         }
         //最后一个顶点的三角形
         triStream.Append(GenerateGrassVertex(positionOS , 0.0 , height , float2(0.5,1.0) , transformationMatrix)); 
         ```

         - 在三角形Stream之前，我们使用一个**for循环**来增加顶点：
           - 循环的每一次迭代都会增加两个顶点：一个是左边，一个是右边。
           - 在顶部完成后，我们将在叶片的顶端添加最后一个顶点。
             - 在uv上，它实际上是从下往上的矩形。而顶点的生成上，因为是宽高发生了变化，所以看上去好像向内收缩了一样。
         - 目前还缺少一个轴向的信息，前后的Z轴的信息，我们拿来做弯曲用。

   - **效果**

      - ![image-20250214134943105](https://raw.githubusercontent.com/nininias/image-repo/main/img/image-20250214134943105.png)


   - **弯曲**

     - 新增一个构造函数，添加了新的参数`Forward`

       - ```C
         inline geometryOutput GenerateGrassVertex(float3 vertexPositionOS , float width , float height ,float forward , float2 uv , float3x3 transformationMatrix)
                 {
                     float3 tangentPoint = float3(width , forward , height);
         
                     float3 localPositionOS = vertexPositionOS + mul(tangentPoint , transformationMatrix);
                     return VertexOutput(localPositionOS,uv);
                 }
         ```

     - 修改一下原来的函数

       - ```C
         // Add as new properties.
         _BladeForward("Blade Forward Amount", Float) = 0.38
         _BladeCurve("Blade Curvature Amount", Range(1, 4)) = 2
         
         …
         
         // Add to the CGINCLUDE block.
         float _BladeForward;
         float _BladeCurve;
         
         …
         
         // Add inside the geometry shader, below the line declaring float width.
         float forward = rand(pos.yyz) * _BladeForward;
         
         …
         
         // 这个写到循环里面去
         float segmentForward = pow(t, _BladeCurve) * forward;
         
         …
         
         // Modify the GenerateGrassVertex calls inside the loop.
         triStream.Append(GenerateGrassVertex(pos, segmentWidth, segmentHeight, segmentForward, float2(0, t), transformMatrix));
         triStream.Append(GenerateGrassVertex(pos, -segmentWidth, segmentHeight, segmentForward, float2(1, t), transformMatrix));
         
         …
         
         // Modify the GenerateGrassVertex calls outside the loop.
         triStream.Append(GenerateGrassVertex(pos, 0, height, forward, float2(0.5, 1), transformationMatrix));
         ```

       - **效果**

         - ![image-20250214141248546](https://raw.githubusercontent.com/nininias/image-repo/main/img/image-20250214141248546.png)
           - 可以看到已经有段落式弯曲的感觉了

8. **光照与阴影**

   - 新建了一个pass即可投影

      - ```C
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
                     #pragma fragment frag_Common
                     #pragma multi_compile_shadowcaster
         
                     ENDHLSL
         
                 }
         ```

         ![image-20250214154834705](https://raw.githubusercontent.com/nininias/image-repo/main/img/image-20250214154834705.png)

   - **接收阴影**

      - 额

      - **效果**

         - ![image-20250214170820006](https://raw.githubusercontent.com/nininias/image-repo/main/img/image-20250214170820006.png)

            - 可以正确的接收和投射阴影了
            - 但是自己对自己的遮挡，使得它产生了一个个条纹![img](https://raw.githubusercontent.com/nininias/image-repo/main/img/shadow-bias.gif)

         - **解决方法**

            - ```C
               //在VertexOutput的Return的上面，对其进行阴影偏移
               //光照数据
               Light mainLight = GetMainLight();
               float3 lightDir = normalize(mainLight.direction).xyz;
               
               //确保只在阴影通道的时候才进行稍微的偏移
               #if UNITY_PASS_SHADOWCASTER
               output.positionWS = float4(ApplyShadowBias(output.positionWS,output.normalWS,lightDir) , 1.0);
               #endif
               ```

            - **效果**

               - <img src="https://raw.githubusercontent.com/nininias/image-repo/main/img/image-20250214175419007.png" alt="image-20250214175419007" style="zoom:33%;" />

   - **光照计算**

      - **计算需要确保法线的正确。**

         - 运用之前底部顶点的法线给所有的点：<img src="https://raw.githubusercontent.com/nininias/image-repo/main/img/image-20250214181516316.png" alt="image-20250214181516316" style="zoom:25%;" />

            ```C
            return VertexOutput(localPositionOS,uv,normalOS);	//直接return传过来的法线数据
            ```

            - 每个顶点都是同样的发现数据

         - 为每一个顶点设置相同的数据，然后统一应用原来的旋转缩放矩阵：<img src="https://raw.githubusercontent.com/nininias/image-repo/main/img/image-20250214181648344.png" alt="image-20250214181648344" style="zoom:25%;" />

            - 每个顶点有各自的法线数据，接下来才能正确的计算光照

      - 最后直接进行光照计算即可

         - ```C
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
            ```

9. **最终效果**

   - ![动画](https://raw.githubusercontent.com/nininias/image-repo/main/img/%E5%8A%A8%E7%94%BB-1739529747483-8.gif)

   - **最终代码**

      - `CustomTess.HLSL`

         - ```c
            #ifndef CUSTOM_UNIVERSAL_PIPELINE_TESSELLATION_SHADER
            #define CUSTOM_UNIVERSAL_PIPELINE_TESSELLATION_SHADER
            
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
            
            
            //==========================================
            // 曲面细分数据结构
            //==========================================
            
            struct Tess_Attributes
            {
                float4 positionOS : POSITION;
                float2 texcoord   : TEXCOORD0;
                float3 normalOS   : NORMAL;
                float4 tangentOS  : TANGENT;
            };
            struct Tess_Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 positionOS : TEXCOORD1;
                float2 uv         : TEXCOORD2;
                float3 normalOS   : TEXCOORD3;
                float4 tangentOS  : TEXCOORD4;
            };
            
            struct Tess_ControlPoint //这个结构体作为Hull Shader的输入/输出控制点
            {
                float4 positionOS : INTERNALTESSPOS;  
                float2 uv         : TEXCOORD0;
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
                float2 uv         : TEXCOORD1;
                float3 normalOS   : TEXCOORD2;
                float4 tangentOS  : TEXCOORD3;
            };
            
            #endif
            ```

      - `TessGeo_Grass.Shader`

         - ```C
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
                    uniform float4 _PositionMoving;
                    CBUFFER_END
            
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
                            triStream.Append(GenerateGrassVertex(positionOS , segmentWidth , segmentHeight , segmentForward , normalOS , float2(0.0,t) , transformationMatrix_T));//两个底部的顶点不做风动效果以及弯折
                            triStream.Append(GenerateGrassVertex(positionOS , -segmentWidth , segmentHeight , segmentForward , normalOS , float2(1.0,t) , transformationMatrix_T));
                        }
                        //最后一个顶点的三角形
                        triStream.Append(GenerateGrassVertex(positionOS , 0.0 , height , forward , normalOS , float2(0.5,1.0) , transformationMatrix));  
                        
                    }
            
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
                        #pragma multi_compile_shadowcaster
            
                        
            
                        ENDHLSL
            
                    }
                }
            }
            ```

10. **与草的交互**

   - 参考与草的交互：[BIRP - 具有交互性的草地几何着色器 |Patreon 公司](https://www.patreon.com/posts/grass-geometry-1-40090373)

   - **核心代码**

      - ```C
         //_PositionMoving是从CPU端传入过来的物体的位置
         //简单的交互效果——距离计算
         float3 dis = distance(_PositionMoving , positionWS);    //与顶点的半径距离
         float3 radiusFalloff = 1 - saturate(dis / _Radius);    //和顶点的半径衰减
         float3 sphereDisp = positionWS - _PositionMoving;  //移动位置指向顶点
         sphereDisp *= radiusFalloff  * 0.5;//衰减距离，乘0.5效果好一点
         sphereDisp = clamp(sphereDisp, -0.8, 0.8);
         ```

         - 对顶点交互的位置进行影响区域界定

      - 然后组装到传入过去的物体位置即可

         - ```C
            //-----写在for循环里面
            //尝试直接修改顶点位置
            float3 newPositionOS = i == 0 ? positionOS : positionOS + sphereDisp  * t;//两个底部的顶点不做风动效果以及弯折
            triStream.Append(GenerateGrassVertex(newPositionOS , segmentWidth , segmentHeight , segmentForward , normalOS , float2(0.0,t) , transformationMatrix_T));
            triStream.Append(GenerateGrassVertex(newPositionOS , -segmentWidth , segmentHeight , segmentForward , normalOS , float2(1.0,t) , transformationMatrix_T));
            ```

      - **C#端简单的代码**

         - ```c#
            void Update()
                {
                    Shader.SetGlobalVector("_PositionMoving", transform.position);
                }
            ```

      - **效果演示**

         - ![动画](https://raw.githubusercontent.com/nininias/image-repo/main/img/动画-1739631306888-1.gif)

11. **做得更好**

    - 可以对于水体应用曲面细分，可以增加距离因素。根据距离动态调整`Tessellation Factor`



#### 曲面细分生成交互雪地案例

参考基础实现：[URP-Shader案例三：雪地轨迹效果 - 知乎 (zhihu.com)](https://zhuanlan.zhihu.com/p/369110873)

1. 完整的实现曲面细分效果，并且确保能够读取**Albedo贴图**，**法线贴图**以及**Displacement贴图**

2. **完成一个可以针对不同的uv纹理坐标距离，进行相应的绘制的Shader**

   - 代码

     ```c#
                 float4 frag (v2f i) : SV_Target
                 {
                     float4 col = _MainTex.Sample(smp, i.uv);
                     float draw = pow(saturate(1 - distance(i.uv, _Coordinate.xy)), _DrawStength);
                     float4 drawCol = _Color * draw;
                     return col + drawCol;
                 }
     ```

3. **编辑C#代码**进行数据传递

   - 代码

     ```C#
     using System.Collections;
     using System.Collections.Generic;
     using UnityEngine;
     public class DrawTrack : MonoBehaviour
     {
         [SerializeField] private Material DrawMat;
         [SerializeField] private Material LandMat;
         private RenderTexture TrackRT;
         private Transform m_LastPos = null;
         public float DrawStength = 1.0f;
         public Color DrawColor = Color.white;
         void Start()
         {
             m_LastPos = transform;
             TrackRT = new RenderTexture(2048, 2048, 0, RenderTextureFormat.Default);
         }
         // Update is called once per frame
         void Update()
         {
             DrawMat.SetFloat("_DrawStength", DrawStength); //设置绘制强度
             DrawMat.SetColor("_Color", DrawColor); //设置绘制颜色
             if (Physics.Raycast(transform.position, Vector3.down, out RaycastHit hit, 10)) //z轴向下射线检测地面
             {
                 DrawMat.SetVector("_Coordinate", new Vector4(hit.textureCoord.x, hit.textureCoord.y, 0, 0)); //设置纹理坐标
                 RenderTexture tmp = RenderTexture.GetTemporary(TrackRT.width, TrackRT.height, 0, RenderTextureFormat.Default); //创建临时渲染纹理
                 Graphics.Blit(TrackRT, tmp);
                 Graphics.Blit(tmp, TrackRT, DrawMat); //绘制轨迹
                 RenderTexture.ReleaseTemporary(tmp); //释放临时渲染纹理
                 LandMat.SetTexture("_SunkenMap", TrackRT); //设置纹理贴图
             }
             m_LastPos.position = transform.position;
         }
     }
     
     ```

4. **实现效果**

   - ![动画](https://raw.githubusercontent.com/nininias/image-repo/main/img/动画-1739628316724-5.gif)

5. **不足**

   - 我没有做对于碰撞物的体积检测
   - 雪地是初步的渲染效果，不真实

6. **做得更好**

   - [Unity-雪地效果的实现 - 知乎 (zhihu.com)](https://zhuanlan.zhihu.com/p/110447928)——这篇文章讲了绘制更多的通道，根据计算后的深度值图，进行两次轮廓线检测，采用的是最基本简单的sobel算子，然后用g和b通道分别存储其颜色。这样做的目的是，可以根据最后的深度图的不同通道，将雪地分为基本雪面（无颜色值）、凸起部分（g通道）、侧边（b通道）、凹陷底部（a通道）四个部分。通过卷积核对图像的处理，拓宽边缘等方法。<img src="https://raw.githubusercontent.com/nininias/image-repo/main/img/v2-e32657dcc00c83b1ba91a0581fc148ee_1440w.jpg" alt="img" style="zoom:25%;" />
   - [Unity动态雪地（沙地） - 知乎 (zhihu.com)](https://zhuanlan.zhihu.com/p/353196002)——这篇文章提到了使用Compute Shader的方式实现，对象是人物，提到了双摄像头的动态捕捉。而且是面向于3A大作里面的雪地实现思路。<img src="https://raw.githubusercontent.com/nininias/image-repo/main/img/v2-807d19ff3760142752b2f4f2635c76b0_r.jpg" alt="img" style="zoom: 33%;" />
   - [入门图形学：雪地特效（一）_unity雪地-CSDN博客](https://blog.csdn.net/yinhun2012/article/details/119983949)——很适合新手，很详细的提到了从顶部摄像机的照射，根据体积的下陷，而且有完整的代码。![在这里插入图片描述](https://raw.githubusercontent.com/nininias/image-repo/main/img/e5cb75aeeed108b9ec12875405c0c3dc.gif)
   - [unity雪景渲染适合作为毕业设计吗？ - 知乎 (zhihu.com)](https://www.zhihu.com/question/687741199/answer/4973003160)——甚至能拿来当毕设？

7. **完整代码**

   - 太长了不放了……有机会上传到Github自取吧
