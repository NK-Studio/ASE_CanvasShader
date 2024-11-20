Shader /*ase_name*/"Hidden/UI/Canvas UI"/*end*/
{
    Properties
    {
        [PerRendererData] _MainTex ("Sprite Texture", 2D) = "white" {}
        _Color ("Tint", Color) = (1,1,1,1)

        [HideInInspector]_StencilComp ("Stencil Comparison", Float) = 8
        [HideInInspector]_Stencil ("Stencil ID", Float) = 0
        [HideInInspector]_StencilOp ("Stencil Operation", Float) = 0
        [HideInInspector]_StencilWriteMask ("Stencil Write Mask", Float) = 255
        [HideInInspector]_StencilReadMask ("Stencil Read Mask", Float) = 255
        [HideInInspector]_ColorMask ("Color Mask", Float) = 15
        [HideInInspector]_ClipRect("ClipRect", Vector) = (0, 0, 0, 0)
        [HideInInspector]_UIMaskSoftnessX("UIMaskSoftnessX", Float) = 1
        [HideInInspector]_UIMaskSoftnessY("UIMaskSoftnessY", Float) = 1


        [Toggle(UNITY_UI_ALPHACLIP)] _UseUIAlphaClip ("Use Alpha Clip", Float) = 0

        /*ase_props*/
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalPipeline"
            "RenderType"="Transparent"
            "Queue"="Transparent"
            // DisableBatching: <None>
            "ShaderGraphShader"="true"
            "ShaderGraphTargetId"="UniversalCanvasSubTarget"
            "IgnoreProjector"="True"
            "PreviewType"="Plane"
            "CanUseSpriteAtlas"="True"
        }

        Stencil
        {
            Ref [_Stencil]
            Comp [_StencilComp]
            Pass [_StencilOp]
            ReadMask [_StencilReadMask]
            WriteMask [_StencilWriteMask]
        }

        Cull Off
        Lighting Off
        ZWrite Off
        ZTest [unity_GUIZTestMode]
        Blend One OneMinusSrcAlpha
        ColorMask [_ColorMask]

        /*ase_pass*/
        Pass
        {
            /*ase_main_pass*/
            Name "Default"
            Tags
            {
                // LightMode: <None>
            }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0

            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"
            #include_with_pragmas "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRenderingKeywords.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRendering.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DBuffer.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Debug/Debugging3D.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceData.hlsl"

            #pragma multi_compile_local _ UNITY_UI_CLIP_RECT
            #pragma multi_compile_local _ UNITY_UI_ALPHACLIP
            
            /*ase_pragma*/

            struct Attributes
            {
                float4 positionOS : POSITION;
                float4 color : COLOR;
                float2 texcoord : TEXCOORD0;
                /*ase_vdata:p=p;uv0=tc0.xy;c=c*/
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float4 color : COLOR;
                float2 texcoord : TEXCOORD0;
                float4 positionWS : TEXCOORD1;
                float4 mask : TEXCOORD2;
                /*ase_interp(3,):sp=sp.xyzw;uv0=tc0.xy;c=c;uv1=tc1.xyzw*/
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _Color;
                float4 _ClipRect;
                float4 _MainTex_ST;
                float _UIMaskSoftnessX;
                float _UIMaskSoftnessY;
            CBUFFER_END

            TEXTURE2D(_MainTex);
            /*ase_globals*/

            //UGUI has no keyword for when a renderer has "bloom", so its nessecary to hardcore it here, like all the base UI shaders.
            half4 _TextureSampleAdd;

            Varyings vert(Attributes input /*ase_vert_input*/)
            {
                Varyings output;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                /*ase_vert_code:input=Attributes;output=Varyings*/

                input.positionOS.xyz += /*ase_vert_out:Offset;Float3*/ float3(0, 0, 0) /*end*/;

                float4 vPosition = TransformObjectToHClip(input.positionOS.xyz);
                output.positionWS = input.positionOS;
                output.positionCS = vPosition;

                float2 pixelSize = vPosition.w;
                pixelSize /= float2(1, 1) * abs(mul((float2x2)UNITY_MATRIX_P, _ScreenParams.xy));

                float4 clampedRect = clamp(_ClipRect, -2e10, 2e10);
                float2 maskUV = (input.positionOS.xy - clampedRect.xy) / (clampedRect.zw - clampedRect.xy);
                output.texcoord = input.texcoord;
                output.mask = float4(input.positionOS.xy * 2 - clampedRect.xy - clampedRect.zw,
                    0.25 / (0.25 * half2(_UIMaskSoftnessX, _UIMaskSoftnessY) + abs(pixelSize.xy)));

                output.color = input.color * _Color;
                return output;
            }

            float4 frag(Varyings input /*ase_frag_input*/) : SV_Target
            {
                //Round up the alpha color coming from the interpolator (to 1.0/256.0 steps)
                //The incoming alpha could have numerical instability, which makes it very sensible to
                //HDR color transparency blend, when it blends with the world's texture.
                const half alphaPrecision = half(0xff);
                const half invAlphaPrecision = half(1.0 / alphaPrecision);
                input.color.a = round(input.color.a * alphaPrecision) * invAlphaPrecision;

                /*ase_frag_code:input=Varyings*/

                half4 color = /*ase_frag_out:Color;Float4;0;-1;input.color*/float4(0.5, 0.5, 0.5, 1) + _TextureSampleAdd
                    /*end*/;

                #ifdef UNITY_UI_CLIP_RECT
                half2 m = saturate((_ClipRect.zw - _ClipRect.xy - abs(input.mask.xy)) * input.mask.zw);
                color.a *= m.x * m.y;
                #endif

                #ifdef UNITY_UI_ALPHACLIP
                clip (color.a - 0.001);
                #endif

                color.rgb *= color.a;

                return color;
            }
            ENDHLSL
        }
    }
    CustomEditor "ASEMaterialInspector"
}