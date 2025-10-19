+++
date = '2025-10-19T14:00:35+08:00'
draft = false
title = 'GAMES202 高质量实时渲染（Real-Time Global Illumination）'
categories = ["Course/Games202"]
tags = ["课程笔记","Games202"]
+++
![请添加图片描述](https://i-blog.csdnimg.cn/direct/78996c31c1b04f5eae5269c1d6756086.png)
 简单理解就是已经被照亮的点作为光源再去照亮别的点
![请添加图片描述](https://i-blog.csdnimg.cn/direct/aa2c09da489f4288808aa9af1f4fc213.png)

# 在3D空间的全局光照
## Reflective Shadow Maps（RSM） 
用非直接光照照亮点p需要什么：
1. 那些点被光源直接照亮（从shadowMap中得到）
2. 其他点对点p的贡献是什么
![请添加图片描述](https://i-blog.csdnimg.cn/direct/789badb3ea1447e7be3f08235557ba93.png)
	 shadowMap中每个纹素就是一个面光源（因为shadowMap描述的就是那些地方被直接照到），紧接着要求p点的间接光照其实就是求shadowMap每个纹素代表的面光源对p点的贡献
	
把纹素作为面光源来求渲染方程![请添加图片描述](https://i-blog.csdnimg.cn/direct/b1aba486555a4511bb14e750381231f9.png)![请添加图片描述](https://i-blog.csdnimg.cn/direct/474b13e5a0ca4d9da12c7c9abc5387b7.png)
现在问题就是从纹素反射出来的Radiance如何计算

1. BRDF项在当前场景中认为是diffuse的
![请添加图片描述](https://i-blog.csdnimg.cn/direct/370d725f018f4338ac513d7cc5e0874c.png)
2. BRDF可以认为是出射的Radiance与入射的irradiance的比例，所以L可以算出
![请添加图片描述](https://i-blog.csdnimg.cn/direct/d48ebf44454f4d858a7734014dc2d2ee.png)
这样写的好处是带入渲染方程后把dA项消掉了，这样就不需要patch的面积大小了，公式就变成了
![请添加图片描述](https://i-blog.csdnimg.cn/direct/9bd48f54de9048638db79731b15805c5.png)
有几个问题：
3. V项没了，因为计算量太大，要计算对于每个着色点从任何一个纹素看向着色点是否被遮挡
4.  方程下边变成4次方，是论文作者对距离衰减做了平方衰减处理，课程中说这是错的，应该是平方，如果说错了直播吃键盘😄（看到第9节课，老师真吃键盘了）
 
 有一些纹素一定不会对着色点有贡献 1. 可见性 2. 方向 3. 距离
![请添加图片描述](https://i-blog.csdnimg.cn/direct/c4456044a9cc4795be040b04487755c4.png)
这个问题就引出了这篇论文的假设，如何知道那些纹素离着色点比较近，论文中认为在shaowMap上比较近，那么世界坐标下就离的比较近（大胆的假设）![请添加图片描述](https://i-blog.csdnimg.cn/direct/3647b13dc46d496ba7d5aa63f555a220.png)
RSM需要存储的东西
![请添加图片描述](https://i-blog.csdnimg.cn/direct/4691c26e05fe46c195c34d823642dd78.png)
RSM在工业界通常用在手电筒![请添加图片描述](https://i-blog.csdnimg.cn/direct/1c7c92698d714a6cac0ca5d004b64cc3.png)
RSM的优点：
1. 易于实现
缺点：
1. 直接光源有多少就得有多少张shadowMap
2. 可见行没法做
3. 很多的假设
4. 采样率和质量的tradeoff
![请添加图片描述](https://i-blog.csdnimg.cn/direct/f6fbb270566c424daf7e3a0cbdde3f9a.png)
## Light Propagation Volumes (LPV)
关键点：Radiance沿直线传播时不会发生变化z
关键做法：把整个场景体积进行切割，成为一个个体素（类比纹素）
下图红色箭头就是间接光照的来源，就是求黄色点接收到的红色radiance的计算
![请添加图片描述](https://i-blog.csdnimg.cn/direct/2fd97894c5514c76b66407796bd15ce2.png)
步骤：
1. 那些点接收到了直接光照
2. 把这些点放在场景到的一个网格中

3. 在网格中传播radiance
![请添加图片描述](https://i-blog.csdnimg.cn/direct/966136cd35304efc8a6af1bf0507518f.png)
通过RSM得到一系列虚拟光源
![请添加图片描述](https://i-blog.csdnimg.cn/direct/37bb32b97d4a4264a1daa2f40c5ec2e1.png)
对场景划分3D网格（可以使用3D纹理，定义每个UV是3D空间的哪个网格）
计算一个格子中向任何方向上的radiance是多少，并用SH压缩，LPV需要存储场景中每个体素（voxel）的辐射度分布，直接存储全方向的辐射度会导致内存爆炸。通过SH投影（通常用2阶或3阶），可将6D的光照函数压缩为少量系数（如9个或16个），极大降低内存需求。
这一步我理解就是把每个次级光源都归为了每个网格的属性，这里记录了每个网格向各个方向的Radiance
![请添加图片描述](https://i-blog.csdnimg.cn/direct/ae5fdbf29cf74f25b2ef695cf1ed74a8.png)
一个格子的radiance向上下左右方向进行传播，这一步结束后每个格子的radiance就都记录好了
![请添加图片描述](https://i-blog.csdnimg.cn/direct/a7ff006c9d0f4b04b2490c9dde74c8f2.png)
对于一个着色点来说，就可以直接使用当前格子接受到的Radiance来计算间接光照了
![请添加图片描述](https://i-blog.csdnimg.cn/direct/4065c3b52123461c86c47f818868fcdb.png)
但是有问题，墙的一边不可能照亮墙的另一边，那把一堵墙放在同一个网格中，那计算着色时墙两边的Radiance都会被考虑，就会出现漏光
![请添加图片描述](https://i-blog.csdnimg.cn/direct/ce86dd9217cc4335a6be27fabf77d8ca.png)
这样就会出现漏光现象，这就要考虑网格划分粒度了 
![请添加图片描述](https://i-blog.csdnimg.cn/direct/00005e4e479d4e18ad8e06298b36210e.png)
 ## Voxel Global Illumination (VXGI)
把整个场景网格化，想象成MC用方块搭起来的场景，并做了层级处理，比如上一层的一个格子在下一次划分为8个格子，最终建立起一颗树
![请添加图片描述](https://i-blog.csdnimg.cn/direct/833a236299854a6095942f118b28b821.png)
第一步：用RSM的方法找到直接光照的网格，并记录每个网格接收到的光源的入射方向和法线，并更新到各个层级，高层级整合低层级的光源入射方向和法线
![请添加图片描述](https://i-blog.csdnimg.cn/direct/c16217c988254f6483fa9f2bb6e19bfe.png)
开始着色：
对于glossy的着色点，光源到达后会反射为一个圆锥的范围
从着色点发射锥体，沿锥体轴线步进采样。看场景中那些体素在椎体范围内，那它就对该着色点有贡献（这是利用光路可逆的思想，反过来这些碰到的体素就会通过椎体射到着色点）
![请添加图片描述](https://i-blog.csdnimg.cn/direct/c9b988666964493c9a7de9f92622f192.png)
对于diffuse的着色点
![请添加图片描述](https://i-blog.csdnimg.cn/direct/61906060646c451ea4507355c81d049c.png)
![请添加图片描述](https://i-blog.csdnimg.cn/direct/8b3469f01c7546d088ef523d2d9597d7.png)
# 在屏幕空间的全局光照
屏幕空间：只使用屏幕信息，对图像进行后期处理 

## Screen Space Ambient Occlusion（SSAO）
 ![请添加图片描述](https://i-blog.csdnimg.cn/direct/56bc741125b449aeb02dcb7691457023.png)
一种全局光照的近似
key diea 1：
- 不知道间接光照，假设为一个常数
- 但不是所有方向都能接收到，会被别的物体挡住![请添加图片描述](https://i-blog.csdnimg.cn/direct/91ab1bf16ed347ce8f6a49dec439081f.png)显然AO的环境光更好
![请添加图片描述](https://i-blog.csdnimg.cn/direct/4aa8c4784dea406687ddf64cf70cfdc9.png)
经典从渲染方程中解释
![请添加图片描述](https://i-blog.csdnimg.cn/direct/f97c2f56c99243c0928e57f99cb7133e.png)
把V项拆出去了，拆出去的（蓝色）项就像当于把四面八方的可见行进行了平均，剩下的（橙色）项中L项在SSAO中已经假设为常数，另外还假设BRDF是diffuse的，所以全是常数了
![请添加图片描述](https://i-blog.csdnimg.cn/direct/cbdf6a3b5ade4bfa91f88e43bdef746c.png)
其中cossita还没解释
![请添加图片描述](https://i-blog.csdnimg.cn/direct/fe152b585bab4a6cb848b69c823abc63.png)
 用cos项把球面上的积分转为圆面上的积分（把立体角的面积投影到底面圆上进行积分）
![请添加图片描述](https://i-blog.csdnimg.cn/direct/4ea39dbe9d82466bbb29d4b4d6c62f8e.png)
数学结束，SSAO就是把间接光当常数、BRDF也是diffuse的
![请添加图片描述](https://i-blog.csdnimg.cn/direct/e2559823e91b41d498df2568ba8fef70.png)
 理论分析结束，现在问题就是如何在屏幕空间求一个着色点四面八方看哪些地方被挡住了
 SSAO假设任何一个着色点在周围半径为R的球中进行采样，每个点与对应像素的zbuffer进行比较，如果大，说明这个点被挡住了就是红色
 ![请添加图片描述](https://i-blog.csdnimg.cn/direct/a2ae51e1e3074681afe946734ca315e7.png)
  但是上图有一个点判断错了
  ![请添加图片描述](https://i-blog.csdnimg.cn/direct/8b7b0125d751451c84405fdce82bfe1e.png)
用一整个球来采样还有问题，墙体内部的点不需要考虑，只需要半球采样即可

采样越多越准确
AO做法是先低采样得到AO
![请添加图片描述](https://i-blog.csdnimg.cn/direct/bb3cb2f09f44419aa22db16b12ba2773.png)
然后进行模糊
![请添加图片描述](https://i-blog.csdnimg.cn/direct/7311644636be470bacf2a14f92c2465f.png)
SSAO的一个问题是会出现假遮挡现象，因为在摄像机视角下，看着被遮挡了，但实际上两者距离是很远的 ![请添加图片描述](https://i-blog.csdnimg.cn/direct/892c0a689792446bb1b561513c12f82e.png)
进一步有技术叫HBAO，只考虑一定范围内的遮挡

## Screen Space Directional Occlusion(SSDO)
是对SSAO的提升，SSAO考虑间接光照是是一样的，但是通过RSM，我们是可以求出间接光照的 

下图看出AO只是简单的变暗，而DO考虑的反射物的颜色，让阴影变蓝了

 ![请添加图片描述](https://i-blog.csdnimg.cn/direct/b41c74d2bb4d41c18c1ab0f4f4b06ab8.png)


![请添加图片描述](https://i-blog.csdnimg.cn/direct/e9e995b1cba644f6b023dbb2c8684d44.png)
与SSAO想法相反，DO认为如果打出去的光线没有物体挡住，那它才应该没有间接光照的贡献，只有直接光照的贡献，反而打到的物体才会反射回来光
![请添加图片描述](https://i-blog.csdnimg.cn/direct/336fbc7a6a6349a693aa486c7d80ff5f.png)
实际做法也和SSAO一样，半球面采样，使用Zbuffer来判断采样点是否被挡住，下图ABD点都得到是被遮挡了
![请添加图片描述](https://i-blog.csdnimg.cn/direct/a382ce63d49e4a8c8a0232fe4adea01d.png)
考虑ABD的间接光照对C点的贡献 
![请添加图片描述](https://i-blog.csdnimg.cn/direct/b08750c3b5dd4533a955928233ee4b81.png)
DO也有假遮挡问题，A点没有被挡住，但是从视角上看是被挡住了，所以被认为对C点有间接光照贡献
![请添加图片描述](https://i-blog.csdnimg.cn/direct/0f27d6026c204318a9e54c6c9068a38a.png) 
![请添加图片描述](https://i-blog.csdnimg.cn/direct/eea45304538e4028b024dc72f2de4f51.png)
只能做小范围的全局光照
![请添加图片描述](https://i-blog.csdnimg.cn/direct/1fa9977788964ba2978dec28287d5817.png)

## Screen Space Reflection（SSR）
在屏幕空间中做光线追踪
现在在屏幕空间已经有了红框的东西，现在SSR就只需要加上白框的东西
![请添加图片描述](https://i-blog.csdnimg.cn/direct/31ca9120b8ef4113b05d7b14191249e7.png)
SSR的思路
![请添加图片描述](https://i-blog.csdnimg.cn/direct/0f08d604d2fa441faf9b66cf8e4d6026.png)
 Linear Raymarch
 目标是找到光线与场景的交点
 - 选定步长，每走一步检查深度
![请添加图片描述](https://i-blog.csdnimg.cn/direct/0a60e020e18f413786e47b675285d3db.png)
 还有加速方法，首先对zbuffer生成mipmap
 但与常规mipmap不相同，上一层级的一个像素是下一层级4个像素的最小值，而不是平均值
![请添加图片描述](https://i-blog.csdnimg.cn/direct/20ee35ebb76147ce955c078cd4d13adb.png)
存最小值的目的就是，如果一个光线与上层不相交，那下层更不用考虑了，因为下层离得更远
![请添加图片描述](https://i-blog.csdnimg.cn/direct/7231499200974ea9a07c253f3694367d.png)
算法为首先走一步，每交点，就胆子大一点就在上一层一口气走两步，还没交点走4步，有交点了再慢慢走
![请添加图片描述](https://i-blog.csdnimg.cn/direct/8126d41b85f94e1086ceffc2d4c2279e.png)
SSR也有问题，因为屏幕空间只有最前面的数据，所以藏在背后的但是反射出来应该能看见的物体就渲染不出来了
![请添加图片描述](https://i-blog.csdnimg.cn/direct/2b4fcc662dc14ea3aa48ea820c3b0a31.png)![请添加图片描述](https://i-blog.csdnimg.cn/direct/38327ccdb1a14357b7aa1a52ebcc9e86.png)
