+++
date = '2025-11-24T10:49:27+08:00'
draft = false
title = '要学的太多'
+++

# Pass

## TODO

- ClipmapPass: 是一个基于光线追踪（Ray Tracing）的体素化（Voxelization）渲染通道，它的核心任务是高效地为体素化全局光照（VXGI）系统构建和更新一个动态的、多层次的体素场景表示

- ClusterLightingPass:光照剔除 **（2025.11.24 拿捏原理、待整合）**

- DDGIPass：一点进度没有（**2025.12.12 青春版完结，但是没做一些工程化的内容，比如ReLocation**）
- ExposurePass：自动曝光（**2025.12.14 完成**）

- FXAA、TAA：抗锯齿得来点进度啊（**2025.12.7 TAA完成**）
- GizmoPass：画在屏幕上的Debug信息不急(**虽然不急但是很有意思，提前完成了 2025.11.30 完成**)
- GPUCullingPass：GPU-Driven管线(Working.......)（**2025.12.18日完成视锥、阴影的Mesh剔除工作， 遮挡剔除还没写**）
- PathTracingPass：啊，把这东西搬到实时管线么。。。，可能只是研究API怎么用（因为是分帧更新，所以不影响实时渲染管线的工作，**2025.12.13 搭建PathTracing完成，但是应该是还有问题，有些像素会过曝）**
- ReprojectionPass：这个好像就是TAA用的motionVector的实现，待研究（**2025.12.7 这东西因为除了TAA别的地方也会用到，所以单独拿出来了，我先自代码还是在TAA代码中**）
- ReSTIRDIPass：高效地计算场景中的直接光照（Direct Illumination），代替光照pass？
- SSSR:更牛逼的SSR? 在 SSR 基础上引入 随机采样（Stochastic Sampling）和 时空域滤波（Temporal + Spatial Filtering），以低采样率实现高质量软反射
- Surface CachePass：优化模型的Pass？
- SVGFPass：在不模糊图像细节（如边缘、纹理）的前提下，高效地去除蒙特卡洛渲染中的噪声，应该是配合上边的ReSTIRDIPass
- VolumetricFogPass：一直还没做过

