+++
date = '2025-11-13T20:22:40+08:00'
draft = false
title = 'UE源码学习（RHI）'
categories = ["Engines/UE"]
tags = ["UE源码"]
+++

# FRHIResource

> /** The base type of RHI resources. */

~~~c++
const ERHIResourceType ResourceType; // 说明了那些被认为是RHI资源
enum ERHIResourceType : uint8
{
	RRT_None,

	RRT_SamplerState,
	RRT_RasterizerState,
	RRT_DepthStencilState,
	RRT_BlendState,
	RRT_VertexDeclaration,
	RRT_VertexShader,
	RRT_MeshShader,
	RRT_AmplificationShader,
	RRT_PixelShader,
	RRT_GeometryShader,
	RRT_RayTracingShader,
	RRT_ComputeShader,
	RRT_GraphicsPipelineState,
	RRT_ComputePipelineState,
	RRT_RayTracingPipelineState,
	RRT_BoundShaderState,
	RRT_UniformBufferLayout,
	RRT_UniformBuffer,
	RRT_Buffer,
	RRT_Texture,
	// @todo: texture type unification - remove these
	RRT_Texture2D,
	RRT_Texture2DArray,
	RRT_Texture3D,
	RRT_TextureCube,
	// @todo: texture type unification - remove these
	RRT_TextureReference,
	RRT_TimestampCalibrationQuery,
	RRT_GPUFence,
	RRT_RenderQuery,
	RRT_RenderQueryPool,
	RRT_Viewport,
	RRT_UnorderedAccessView,
	RRT_ShaderResourceView,
	RRT_RayTracingAccelerationStructure,
	RRT_RayTracingShaderBindingTable,
	RRT_StagingBuffer,
	RRT_CustomPresent,
	RRT_ShaderLibrary,
	RRT_PipelineBinaryLibrary,
	RRT_ShaderBundle,
	RRT_WorkGraphShader,
	RRT_WorkGraphPipelineState,
	RRT_StreamSourceSlot,
	RRT_ResourceCollection,

	RRT_Num
};

~~~

`ERHIResourceType` 枚举包含的资源类型可归纳为以下大类：

1. 渲染状态资源（管线状态配置类）
2. 着色器及相关资源（各类着色器程序与绑定布局类）
3. 缓冲与数据存储资源（数据载体及布局描述类）
4. 纹理及纹理访问资源（图像数据及访问接口类）
5. 光线追踪专用资源（光线追踪加速与绑定类）
6. 查询与同步资源（GPU/CPU 交互及数据查询类）
7. 其他辅助资源（视口、自定义呈现、资源集合等）

这里的每个实现都用子类实现

```c++
class FRHIUniformBuffer : public FRHIResource
#if ENABLE_RHI_VALIDATION
	, public RHIValidation::FUniformBufferResource
#endif
{
public:
	FRHIUniformBuffer() = delete;
    ...
}
```

再进一步就到了具体API的子类

```c++
class FVulkanUniformBuffer : public FRHIUniformBuffer
{
public:
	FVulkanUniformBuffer(FVulkanDevice& Device, const FRHIUniformBufferLayout* InLayout, const void* Contents, EUniformBufferUsage InUsage, EUniformBufferValidation Validation);
	virtual ~FVulkanUniformBuffer();
	...
}
```

其他资源都一样的继承思路

这套架构已经简单实现

# FDynamicRHI

> 类似创建操作(上下文无关操作)是在FDynamicRHI，上下文有关的操作（也就是在固定生命周期内执行的操作）是在IRHICommandContext

一些图形渲染场景的操作API都定义在这里，创建shader、更新纹理等等

```c++
/** The interface which is implemented by the dynamically bound RHI. */
class FDynamicRHI
{
public:
	using FRHICalcTextureSizeResult = ::FRHICalcTextureSizeResult;

	/** Declare a virtual destructor, so the dynamic RHI can be deleted without knowing its type. */
	RHI_API virtual ~FDynamicRHI();

	/** Initializes the RHI; separate from IDynamicRHIModule::CreateRHI so that GDynamicRHI is set when it is called. */
	virtual void Init() = 0;

	/** Called after the RHI is initialized; before the render thread is started. */
	virtual void PostInit() {}

	/** Shutdown the RHI; handle shutdown and resource destruction before the RHI's actual destructor is called (so that all resources of the RHI are still available for shutdown). */
	virtual void Shutdown() = 0;

	virtual const TCHAR* GetName() = 0;

	virtual ERHIInterfaceType GetInterfaceType() const { return ERHIInterfaceType::Hidden; }
	virtual FDynamicRHI* GetNonValidationRHI() { return this; }

	/** Called after PostInit to initialize the pixel format info, which is needed for some commands default implementations */
	void InitPixelFormatInfo(const TArray<uint32>& PixelFormatBlockBytesIn)
	{
		PixelFormatBlockBytes = PixelFormatBlockBytesIn;
	}

	/////// RHI Methods

	RHI_API virtual void RHIEndFrame_RenderThread(FRHICommandListImmediate& RHICmdList);

	struct FRHIEndFrameArgs
	{
		// Increments once per call to RHIEndFrame
		uint32 FrameNumber;

#if WITH_RHI_BREADCRUMBS
		const TRHIPipelineArray<FRHIBreadcrumbNode*>& GPUBreadcrumbs;
#endif
	};
	virtual void RHIEndFrame(const FRHIEndFrameArgs& Args) = 0;

	// FlushType: Thread safe
	virtual FSamplerStateRHIRef RHICreateSamplerState(const FSamplerStateInitializerRHI& Initializer) = 0;

	// FlushType: Thread safe
	virtual FRasterizerStateRHIRef RHICreateRasterizerState(const FRasterizerStateInitializerRHI& Initializer) = 0;

	// FlushType: Thread safe
	virtual FDepthStencilStateRHIRef RHICreateDepthStencilState(const FDepthStencilStateInitializerRHI& Initializer) = 0;

	// FlushType: Thread safe
	virtual FBlendStateRHIRef RHICreateBlendState(const FBlendStateInitializerRHI& Initializer) = 0;

	// FlushType: Wait RHI Thread
	virtual FVertexDeclarationRHIRef RHICreateVertexDeclaration(const FVertexDeclarationElementList& Elements) = 0;

	// FlushType: Wait RHI Thread
	virtual FPixelShaderRHIRef RHICreatePixelShader(TArrayView<const uint8> Code, const FSHAHash& Hash) = 0;

	// FlushType: Wait RHI Thread
	virtual FVertexShaderRHIRef RHICreateVertexShader(TArrayView<const uint8> Code, const FSHAHash& Hash) = 0;

	// FlushType: Wait RHI Thread
	virtual FGeometryShaderRHIRef RHICreateGeometryShader(TArrayView<const uint8> Code, const FSHAHash& Hash) = 0;

	// FlushType: Wait RHI Thread
	virtual FMeshShaderRHIRef RHICreateMeshShader(TArrayView<const uint8> Code, const FSHAHash& Hash)
      
    ...
}
```



封装了渲染所需的核心资源创建与管理逻辑，包括：

- 缓冲（顶点缓冲、索引缓冲、常量缓冲等）的创建 / 更新 / 销毁；
- 纹理（2D 纹理、立方体贴图等）的加载 / 格式转换 / 内存管理；
- 渲染管线状态（着色器、混合状态、深度测试等）的配置与绑定；
- 绘制命令（Draw Call）的提交与执行。

# FRHICommand

> UE的命令是用链表串起来的

```c++
struct FRHICommandBase
{
	FRHICommandBase* Next = nullptr;  // 命令是链表连起来的
	virtual void ExecuteAndDestruct(FRHICommandListBase& CmdList) = 0; // 具体执行方法
};

// 封装了lambda来执行命令
template <typename RHICmdListType, typename LAMBDA>
struct TRHILambdaCommand final : public FRHICommandBase
{
	LAMBDA Lambda;
#if CPUPROFILERTRACE_ENABLED
	const TCHAR* Name;
#endif

	TRHILambdaCommand(LAMBDA&& InLambda, const TCHAR* InName)
		: Lambda(Forward<LAMBDA>(InLambda))
#if CPUPROFILERTRACE_ENABLED
		, Name(InName)
#endif
	{}

	void ExecuteAndDestruct(FRHICommandListBase& CmdList) override final
	{
		TRACE_CPUPROFILER_EVENT_SCOPE_TEXT_ON_CHANNEL(Name, RHICommandsChannel);
		Lambda(*static_cast<RHICmdListType*>(&CmdList));
		Lambda.~LAMBDA();
	}
};
```

FRHICommand继承Base后只添加了一个函数 （调用命令）

```c++
template<typename TCmd, typename NameType = FUnnamedRhiCommand>
struct FRHICommand : public FRHICommandBase
{
	void ExecuteAndDestruct(FRHICommandListBase& CmdList) override final
	{
		LLM_SCOPE_BYNAME(TEXT("RHIMisc/CommandList/ExecuteAndDestruct"));
		TRACE_CPUPROFILER_EVENT_SCOPE_ON_CHANNEL_STR(NameType::TStr(), RHICommandsChannel);

		TCmd* ThisCmd = static_cast<TCmd*>(this);
		ThisCmd->Execute(CmdList);   // 调用命令
		ThisCmd->~TCmd(); // 释放命令
	}
};
```

再下一层就是各种具体命令 比如FRHICommandSetShaderParameters、FRHICommandSetViewport等等，每个具体命令都有一个Execute方法

```c++
void FRHICommandDrawPrimitive::Execute(FRHICommandListBase& CmdList)
{
	RHISTAT(DrawPrimitive);
	INTERNAL_DECORATOR(RHIDrawPrimitive)(BaseVertexIndex, NumPrimitives, NumInstances);
}

void FRHICommandDrawIndexedPrimitive::Execute(FRHICommandListBase& CmdList)
{
	RHISTAT(DrawIndexedPrimitive);
	INTERNAL_DECORATOR(RHIDrawIndexedPrimitive)(IndexBuffer, BaseVertexIndex, FirstInstance, NumVertices, StartIndex, NumPrimitives, NumInstances);
}

void FRHICommandSetBlendFactor::Execute(FRHICommandListBase& CmdList)
{
	RHISTAT(SetBlendFactor);
	INTERNAL_DECORATOR(RHISetBlendFactor)(BlendFactor);
}

void FRHICommandSetStreamSource::Execute(FRHICommandListBase& CmdList)
{
	RHISTAT(SetStreamSource);
	INTERNAL_DECORATOR(RHISetStreamSource)(StreamIndex, VertexBuffer, Offset);
}

void FRHICommandSetViewport::Execute(FRHICommandListBase& CmdList)
{
	RHISTAT(SetViewport);
	INTERNAL_DECORATOR(RHISetViewport)(MinX, MinY, MinZ, MaxX, MaxY, MaxZ);
}
```

再下面就是各个API具体的实现了

# FRHICommandList

主要看两个指针

```c++
class FRHICommandListBase{
    protected:
	FRHICommandBase*    Root            = nullptr;  // 命令链表的起始
	FRHICommandBase**   CommandLink     = nullptr; // 命令结束的位置，用于添加新命令
}

// 新建一个命令的流程
FORCEINLINE_DEBUGGABLE void* AllocCommand(int32 AllocSize, int32 Alignment)
{
    checkSlow(!IsExecuting());
    checkfSlow(!Bypass(), TEXT("Invalid attempt to record commands in bypass mode."));
    FRHICommandBase* Result = (FRHICommandBase*) MemManager.Alloc(AllocSize, Alignment);  // 内存中申请空间
    ++NumCommands;
    *CommandLink = Result; 
    CommandLink = &Result->Next;  // 其实就是链表添加一个尾结点的操作
    return Result;
}
```

Base下一层FRHIComputeCommandList

```c++
class FRHIComputeCommandList : public FRHICommandListBase{}
```

再下一层才是FRHICommandList。听了UE的RHI介绍视频，我觉得这样设计是因为渲染Queue可以进行渲染命令也可以是计算命令（我现在自己的项目的ComputeShader都是放在渲染Queue中进行的）。是有包含关系的。

```c++
class FRHICommandList : public FRHIComputeCommandList
```

再下一层是立即模式

```c++
class FRHICommandListImmediate : public FRHICommandList
```

还有一个Context的系列，里边也是一些命令的接口，Context的执行就需要用到上边的FRHICommand

```c++
class IRHICommandContext : public IRHIComputeContext
```

> 再进到API层面还有封装

