+++
date = '2026-01-24T00:41:52+08:00'
draft = true
title = 'UE源码学习（延迟渲染管线）'
+++

# UE的渲染器源码

FSceneRenderer  渲染器的核心父类

```c++
class FSceneRenderer : public FSceneRendererBase
{
    /** The scene being rendered. */
	FScene* Scene = nullptr;
    
}
```

FDeferredShadingSceneRenderer  延迟渲染器

```c++
class FDeferredShadingSceneRenderer : public FSceneRenderer
{
public:
// 这里定义了各自Pass的渲染流程。如下各自各样的Render，他们的第一个参数都是Builder，也能说明他们用于构建RDG
static void RenderBasePass(		FRDGBuilder& GraphBuilder,
void RenderSingleLayerWater(		FRDGBuilder& GraphBuilder,
void RenderOcclusion(		FRDGBuilder& GraphBuilder,
bool RenderHzb(		FRDGBuilder& GraphBuilder,
void RenderFog(		FRDGBuilder& GraphBuilder,
void RenderDistanceFieldLighting(
    
// 最核心的接口，此处用于把全部流程串起来
virtual void Render(FRDGBuilder& GraphBuilder) override;

```

```c++
void FDeferredShadingSceneRenderer::Render(FRDGBuilder& GraphBuilder){
    	
    // 1. 更新场景资源
    Scene->UpdateAllPrimitiveSceneInfos(GraphBuilder, true);
	
}

```

## 1. UpdateAllPrimitiveSceneInfos  更新场景

> `FScene::UpdateAllPrimitiveSceneInfos`的主要作用是删除、增加、更新CPU侧的图元数据，且同步到GPU端。其中GPU的图元数据存在两种方式：

图元数据有两种存放模式：

1. 每个图元独有一个Uniform Buffer。在shader中需要访问图元的数据时从该图元的Uniform Buffer中获取即可。这种结构简单易理解，兼容所有FeatureLevel的设备。但是会增加CPU和GPU的IO，降低GPU的Cache命中率。
2. 使用Texture2D或StructuredBuffer的GPU Scene，所有图元的数据按规律放置到此。在shader中需要访问图元的数据时需要从GPU Scene中对应的位置读取数据。需要SM5支持，实现难度高，不易理解，但可减少CPU和GPU的IO，提升GPU Cache命中率，可更好地支持光线追踪和GPU Driven Pipeline。

虽然以上访问的方式不一样，但shader中已经做了封装，使用者不需要区分是哪种形式的Buffer，只需使用以下方式：在`// Engine\Shaders\Private\SceneData.ush`中有定义PrimitiveSceneData有哪些数据

```c++
GetPrimitiveData(PrimitiveId).xxx;
```



```c++
// 	Experimental::TRobinHoodHashSet<FPrimitiveSceneInfo*> AddedPrimitiveSceneInfos;
//  Experimental::TRobinHoodHashSet<FPrimitiveSceneInfo*> RemovedPrimitiveSceneInfos;

void FScene::UpdateAllPrimitiveSceneInfos(FRDGBuilder& GraphBuilder, bool bAsyncCreateLPIs){
    // 首先会给图元进行排序，以便
    
    
    // 1. 处理图元删除
   	// 从源码能看出，它的图元数据是存在一个TArray中的，它删除一个图元时要把其他图元挪到前边的，这里用了一个提高效率的小技巧
    // 先计算一下前缀和，表示每种类型图元的数量
    // PrimitiveSceneProxies[0,0,0,6,6,6,6,6,2,2,2,2,1,1,1,7,4,8]
    // TypeOffsetTable[3,8,12,15,16,17,18]
    
	// 比如移动X，利用TypeOffsetTable来快速移动图元，这样就不用一个一个移动了
    // PrimitiveSceneProxies[0,0,0,6,X,6,6,6,2,2,2,2,1,1,1,7,4,8]
    // PrimitiveSceneProxies[0,0,0,6,6,6,6,6,X,2,2,2,1,1,1,7,4,8]
    // PrimitiveSceneProxies[0,0,0,6,6,6,6,6,2,2,2,X,1,1,1,7,4,8]
    // PrimitiveSceneProxies[0,0,0,6,6,6,6,6,2,2,2,1,1,1,X,7,4,8]
    // PrimitiveSceneProxies[0,0,0,6,6,6,6,6,2,2,2,1,1,1,7,X,4,8]
    // PrimitiveSceneProxies[0,0,0,6,6,6,6,6,2,2,2,1,1,1,7,4,X,8]
    // PrimitiveSceneProxies[0,0,0,6,6,6,6,6,2,2,2,1,1,1,7,4,8,X]
    
    // 2. 处理新增图元
    // 增加图元示意图：先将被增加的元素放置列表末尾，然后依次和相同类型的末尾交换。
    // PrimitiveSceneProxies[0,0,0,6,6,6,6,6,2,2,2,2,1,1,1,7,4,8,6]
    // PrimitiveSceneProxies[0,0,0,6,6,6,6,6,6,2,2,2,1,1,1,7,4,8,2]
    // PrimitiveSceneProxies[0,0,0,6,6,6,6,6,6,2,2,2,2,1,1,7,4,8,1]
    // PrimitiveSceneProxies[0,0,0,6,6,6,6,6,6,2,2,2,2,1,1,1,4,8,7]
    // PrimitiveSceneProxies[0,0,0,6,6,6,6,6,6,2,2,2,2,1,1,1,7,8,4]
    // PrimitiveSceneProxies[0,0,0,6,6,6,6,6,6,2,2,2,2,1,1,1,7,4,8]
    
    
    // 3. 处理Transform更新
    for (const auto& Transform : UpdatedTransforms)

    
}
```

