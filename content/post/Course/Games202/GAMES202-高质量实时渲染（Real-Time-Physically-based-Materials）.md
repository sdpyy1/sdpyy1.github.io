+++date = '2025-10-19T14:01:31+08:00'
draft = false
title = 'GAMES202 高质量实时渲染（Real-Time Physically Based Materials）'
categories = ["学习笔记/GAMES202"]
tags = ["Games202"]
image = 'a798b632f6bc41f9b3e68453c8445fb7.png'
+++
# Micorfacet BRDF
![在这里插入图片描述](c1dccc9561914ba7b95432dc6463973e.png)
##  F项：Fresnel term
Fresnel项（Fresnel term）用于描述光在界面上反射的强度随入射角变化的现象。![在这里插入图片描述](a942291c496f4051afcc6bc9c1bfee1a.png)
对于绝缘体材质
![在这里插入图片描述](24c084765fcf425cb261b58e31062919.png)
对于导电材质
![在这里插入图片描述](84d396e30c41458ba4c209bd5fbd15f7.png)
Snell's Law（斯涅尔定律）描述的是光在两种介质交界面上传播时的折射行为
![在这里插入图片描述](bd8922dfc342400795f5ce0b9923ca1e.png)
如果分为RGB三个通道，三个通道有自己的折射率。
Rs：垂直偏振（s-polarized）反射率
Rp：平行偏振（p-polarized）反射率
因为自然光通常是非偏振光（即含有相等的 s 和 p 偏振分量），所以实际使用时我们取两者的平均来得到总反射率：两者通过平均得到Fresnel平均反射率。
R0是垂直入射下的反射率，可以通过两种介质的折射率获得，他是一个三通道。进一步可以用Schlick's Approximation来近似出θ角度下的反射率
![在这里插入图片描述](716e700e92d840d19efab4135f0672b6.png)
##  G项：shadowing-masking term（geometry term）
 为了解决微表面的自遮挡问题
 下图左边表示光线被遮挡（shadowing），右图是视线被遮挡（masking）
![在这里插入图片描述](a1cab8a818d549fdaf0e23ae01c4dd91.png)
如果没有G项，当视角和法线接近90°时，BRDF分母会接近0，所以BRDF会变得巨大，导致球体一圈变成白色
![在这里插入图片描述](96df9e6eed734ba786be60a79543dcbd.png)
常用的G项为The Smith shadowing-masking term
把shadowing和masking两种情况分开考虑
![在这里插入图片描述](63f9c6a0ac564809ae096ac1b4169215.png)
他是基于NDF的值来考虑G项的值的
![在这里插入图片描述](81a83552b89741ff82bf684bf4d805ba.png)
##  D项：Normal Distribution Function（NDF）
微表面上看法线方向并不是统一的
当法线分布更多在半程向量时，反射光强度更大

glossy和diffuse的表面法线分布情况，glossy的表面分布比较集中
![在这里插入图片描述](484fea8176da418d95c866902301b3b9.png)
有不同的模型来描述法线分布
- Benckmann、GGX
![在这里插入图片描述](48d1b5f20a9e4b3e9e5fae3e9d03deb1.png)
### Beckmann NDF
![在这里插入图片描述](668659b7e67a41d3ae097f312d6c5840.png)
两个系数来控制分布。阿尔法控制表面的粗糙程度。sita控制半程向量和法向量的夹角
![在这里插入图片描述](fcaaf1365ae04480898058b459efd763.png)
圆心是着色点，红色是微观法线。黑线是宏观着色点法线。他们的夹角就是sita，把红线延长到上面的一条线上。用tansita来定义分布
![在这里插入图片描述](0c66b599e9e84979ae8a1bf8cd62f768.png)
所以说Beckmann NDF是定义在tanθ上的高斯分布

### GGX NDF
它的尾巴比较长，如下图橙色尾巴很长。而beckmannNDF在90°时已经衰减为非常接近0。如果把高出定义为高光，那backmannNDF高光周围会迅速衰减。而GGX会缓慢衰减，形成光晕的效果
![在这里插入图片描述](05e5eaf5b5b14d468a527a63ac1b7930.png)
下图可以看出backmann高光周围比较尖锐。GGX比较平滑
![在这里插入图片描述](e7030edf588b48b7bed08c1a9bdc0fa7.png)
所以说GGX的长尾可以带来自然过渡的效果。

GGX的拓展
定义参数gamma,调整尾巴衰减速度
![在这里插入图片描述](d115f8cfb59e4f2aaa06ec4b94d7bcc0.png)

## Multiple Bounces
现在已经学习了BRDF的FGD三项的构成。但是这样渲染出来还有问题。随着roughness的增加，模型逐渐变暗了。下面一行是在做能量损失实验，说明roughness越大，能量损失越多了
 ![在这里插入图片描述](1b0727ccc208402092dfea9f7cd16812.png)
 这种能量损失体现在，越粗糙的表面法线分布更容易被挡住
![在这里插入图片描述](9ecc627afdcb47c7baf71af68be1b10c.png)
所以要考虑多次bounces，有相关的论文，但是对于实时渲染太慢了
![在这里插入图片描述](52d226e2c892483ea9f0a9faa370ea1e.png)
所以现在有了基于经验补全的方式，kulla-Conty Approximation
首先根据渲染方程，假设输入的L=1，计算输出的能量是多少
![在这里插入图片描述](2c8114e2323f4356849da2c38615a71c.png)
所以1-E(u0)就是损失的能量（E与观察方向有关系，所以不同的视角下损失能量是不一样的），最后补上这部分能量。
具体怎么算出来就不看了。最终损失能量依赖于观察方向和粗糙度两个变量。所以直接预**计算打表**即可。
![在这里插入图片描述](dfcfed8a53014f6fadc7a74794284d1e.png)
补充前后对比
![在这里插入图片描述](a798b632f6bc41f9b3e68453c8445fb7.png)
## LTC(Shading Microfacet Models using Linearly Transformed Cosines)
LTC 最初是由 Tobias Ritschel 等人在论文《LTC - A Fast and Efficient Approximation of Fresnel Terms and Distribution of Normal Vectors for Real-Time Rendering》提出的，它被设计为一种方法来 近似反射分布函数（BRDF）
Fresnel项 和 法线分布函数（例如 GGX）是微面模型的关键组成部分，这些函数非常复杂，计算成本较高。LTC 使用线性时间编码（Linear Time Coding）来近似这些复杂的分布，使得实时渲染时可以快速计算这些项。
综上LTC是一种对BRDF项的预计算

首先，它是有限制的。主要是在GGX的法线分布下、没有阴影、多边形光源
![请添加图片描述](66354821416b4c43bf12995a188ac243.png)
主要思想是任何BRDF lobe 都可以通过一个变换转化为一个余弦函数
![请添加图片描述](10747d8cb7744e25922901c727879a8c.png)
![请添加图片描述](7084778496db4a5082c09cb782a3528e.png)
实际实现比较复杂，课程没提到

# Disney’s Principled BRDF
首先介绍了为什么有了微表面BRDF还需要Disney的BRDF
![请添加图片描述](568ccf63308b491c899cc246bec4e1b7.png)
它被称为principled的BRDF，可以通过调整参数来达到想要的效果，所以他是艺术家友好的
![请添加图片描述](fce4ae67e9cb4e629e3ec23e8c0043c4.png)
介绍一下里边的名词
1. subsurface（次表面反射）：光线进入表面后并不会直接反射回去，而是穿透表面并在内部多次散射，最终可能以不同的方向从表面射出。
2. metallic（金属性）
3. specular（镜面）
4. specularTint（镜面颜色）：specularTint 是一个与 镜面反射（Specular Reflection）相关的参数，用来控制反射光的颜色如何与 材质本身的颜色混合。也就是说镜面反射光不是单纯的白色，而且受表面材质颜色的影响
5. anisotropic（各向异性）：述材料或表面在不同方向上具有不同物理特性的术语
6. sheen（沿着球的表面有绒毛雾化效果）
7. clearcoat（添加一层镀膜）

# Non-Photorealistic Rendering(NPR)   
## Outline Rendering 描边
先来看看有哪些Outline，B表示自己的边界，S表示两个面交界处形成的边界，C是折痕，M是材质边界
![请添加图片描述](ab26d2bd43da4b81a3a89d6a512edf31.png)
知道了边界，下来就需要描边，可以通过Shading或者图像处理来完成。首先来介绍Shading方法，哪些像素点是S边上呢，根据观察，就是法线与观察方向=之间夹角接近垂直的像素点。可以设置夹角的阈值，来改变边的粗细
![请添加图片描述](f792388c1b6c438d9f8348ee62c59d04.png)
另外就是外扩法，之前learnOpenGL里有
![请添加图片描述](69be7e2417394169b1600be2f94750d3.png)
另外看一下从图像上来处理
![请添加图片描述](f184962b02234ab88cd5988e16292580.png)
## Color blocks 色块效果
![请添加图片描述](5ad865728c1345a0a4c184eba96509d0.png)
直接把渲染结果量化，就是连续值变成离散
![请添加图片描述](c66c737ffa0046cdb39b5652d8204af2.png)
## Strokes Surface Stylization 素描效果
![请添加图片描述](6fcfdf86c2a347179a0ac8abe7ad9866.png)
![请添加图片描述](7402580507ca48f0a7b9d3b126ec466d.png)
