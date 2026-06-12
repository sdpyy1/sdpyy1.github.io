+++date = '2025-10-19T14:20:40+08:00'
draft = false
title = 'OpenGLRender开发记录（3）：后处理Pass（大气渲染）'
categories = ["Projects/OpenGL渲染器"]
tags = ["渲染器开发","OpenGLRender","OpenGL"]
image = '025e7da8dd62453095a4739f7c3d15ed.png'
+++
# 大气渲染
## 渲染方法分析
![请添加图片描述](55e17d90959d44a9b5a55d89fb02d6a2.png)
光如何与Participating Media Particles（包括小粒子（气体分子），大粒子（气溶胶、水滴、烟雾）） 交互？
- 吸收
- 外散射
- 自发光
- 内散射
![请添加图片描述](ab8a5edb87fe46e8af1ba0222bed318a.png)
M点为着色点，那从P点看向M点时，需要计算两个值（1）**Transmittance**(透光度):有多少光能透过来(2) **Scattering**：粒子会把来自各个方向的光散射到观察方向
![请添加图片描述](f2ceb0e7af2248c1a21442839c4559b9.png)
## 真实大气物理
太阳光由不同波长的光组成，人眼把这些波长光的组合定义成了白色而已
![请添加图片描述](6fde5a562a3240e4a7fdbcef10d7c62b.png)
大气中包含两种粒子：气体分子一般小于这些光的波长，其他的气溶胶大于这些波长
![请添加图片描述](6e6096be052e4f2485be21ea8ebcf5d2.png)
有两种完全不同的散射模型来末说这两种粒子的散射
![请添加图片描述](560c3a5ec0b644d3a48a06331a1f1ab0.png)
 
### 瑞利散射 Rayleigh Scattering （针对气体分子）
散射特点：对波长敏感，短波长（蓝光）更容易被散射，所以天空是蓝色。
各种波长光散射形状差不多，但是强度不同，各个方向上散射大致相同
![请添加图片描述](d3afafea17f54e31861513b63192af3b.png)
具体的模型公式有两部分，前半部分是各种系数、后半部分是模型形状（花生形状）。公式表达含义是在在散射方向 θ上的散射光强，它与光的波长、海拔高度有关
![请添加图片描述](31f41d3de1e742e0965de3791e0f17fd.png)
直观理解天空为什么是蓝色，太阳直射时，大量的蓝光被散射开来，红光散射比较弱。太阳落山时，大量的蓝光散射到了太空和地面，红光的散射效果体现了出来
![请添加图片描述](cf3bc303c42b45088912b2448fac59c8.png)
### 米氏散射 Mie scattering （针对大分子）
米氏散射对波长依赖弱 → 散射几乎不偏色，所以雾和云看起来白色或灰色
所有波长的光一视同仁，但是不同的散射方向能力有巨大差异
奇怪的形状。
![请添加图片描述](0c91ffff137b4299b4e6a89be0e0ff47.png)
![请添加图片描述](d0bfdd32879246e6853957e43d733e9b.png)
![请添加图片描述](255d8eedeeee4547b84758f97a4eea2d.png)
### 光的吸收
这两种气体会吸收光，但模型过于复杂，在渲染中假设他们均匀分布
![请添加图片描述](1d31945b45f846bb87737725157e3639.png)
## 单次散射和多次散射
单次散射只考虑太阳光到一个粒子后散射到摄像机
多次散射就是考虑一个粒子散射到另一个粒子这样不停散射最终到达摄像机
![请添加图片描述](21e08dd48b654638a5d1e50058570a09.png)
主要看山的背面，多次散射才能表达出这种感觉
![请添加图片描述](9ba65d1cd6644e6ea8a76e85f023defc.png)
## 大气渲染实践
###  瑞利散射和米氏散射建模
参考别的论文，他们是用h = 0时求出的解作为基准，用一个高度衰减函数进行高度衰减。函数都有两部分，一部分求解散射系数一部分求解相函数
瑞利散射：

```cpp
vec3 RayleighCoefficient(in AtmosphereParameter param, float h)
{
    const vec3 sigma = vec3(5.802, 13.558, 33.1) * 1e-6;
    float H_R = param.RayleighScatteringScalarHeight;
    float rho_h = exp(-(h / H_R));
    return sigma * rho_h;
}

float RayleighPhase(in AtmosphereParameter param, float cos_theta)
{
    return (3.0 / (16.0 * 3.14159265)) * (1.0 + cos_theta * cos_theta);
}
```
米氏散射多一个g，用来控制米氏散射的形状

```cpp

vec3 MieCoefficient(AtmosphereParameter param, float h)
{
    const vec3 sigma = vec3(3.996e-6);
    float H_M = param.MieScatteringScalarHeight;
    float rho_h = exp(-(h / H_M));
    return sigma * rho_h;
}

float MiePhase(AtmosphereParameter param, float cos_theta)
{
    float g = param.MieAnisotropy;

    float a = 3.0 / (8.0 * 3.14159265);
    float b = (1.0 - g * g) / (2.0 + g * g);
    float c = 1.0 + cos_theta * cos_theta;
    float d = pow(1.0 + g * g - 2.0 * g * cos_theta, 1.5);

    return a * b * (c / d);
}
```
散射结果，将两种散射结果相加，得到太阳光被一个粒子散射到摄像机的三色比例

```cpp
vec3 Scattering(AtmosphereParameter param, vec3 p, vec3 lightDir, vec3 viewDir)
{
    float cos_theta = dot(lightDir, viewDir);

    float h = length(p) - param.PlanetRadius;
    vec3 rayleigh = RayleighCoefficient(param, h) * RayleighPhase(param, cos_theta);
    vec3 mie = MieCoefficient(param, h) * MiePhase(param, cos_theta);

    return rayleigh + mie;
}
```
## 吸收建模
瑞利散射没有吸收，米氏有吸收，另外大气中的臭氧也有吸收效应

```cpp
vec3 MieAbsorption(AtmosphereParameter param, float h)
{
    const vec3 sigma = vec3(4.4e-6);
    float H_M = param.MieScatteringScalarHeight;
    float rho_h = exp(-(h / H_M));
    return sigma * rho_h;
}

vec3 OzoneAbsorption(AtmosphereParameter param, float h)
{
    const vec3 sigma_lambda = vec3(0.650, 1.881, 0.085) * 1e-6;
    float center = param.OzoneLevelCenterHeight;
    float width = param.OzoneLevelWidth;
    float rho = max(0.0, 1.0 - abs(h - center) / width);
    return sigma_lambda * rho;
}
```
## 透光率
透光率与经过的路径和吸收有关，由于每个点的吸收不同，所以采样处理
![请添加图片描述](5e93becb036f43c69a7719acdcd1ae23.png)

```cpp
vec3 Transmittance(in AtmosphereParameter param, vec3 p1, vec3 p2)
{
    const int N_SAMPLE = 32;

    vec3 dir = normalize(p2 - p1);
    float distance = length(p2 - p1);
    float ds = distance / float(N_SAMPLE);
    vec3 sum = vec3(0.0);
    vec3 p = p1 + dir * ds * 0.5;

    for(int i = 0; i < N_SAMPLE; i++)
    {
        float h = length(p) - param.PlanetRadius;

        vec3 scattering = RayleighCoefficient(param, h) + MieCoefficient(param, h);
        vec3 absorption = OzoneAbsorption(param, h) + MieAbsorption(param, h);
        vec3 extinction = scattering + absorption;

        sum += extinction * ds;
        p += dir * ds;
    }

    // 计算透光率
    return exp(-sum);
}
```
## 单次散射
首先要有一个光线与球体求交的计算

```cpp
float RayIntersectSphere(vec3 center, float radius, vec3 rayStart, vec3 rayDir)
{
    float OS = length(center - rayStart);
    float SH = dot(center - rayStart, rayDir);
    float OH = sqrt(OS * OS - SH * SH);

    // 射线未击中球体
    if(OH > radius) return -1.0;

    float PH = sqrt(radius * radius - OH * OH);

    // 使用最小正距离
    float t1 = SH - PH;
    float t2 = SH + PH;
    float t = (t1 < 0.0) ? t2 : t1;

    return t;
}
```
对于单次散射而言，从摄像机位置RM获得每一个采样点，每一个采样点进行光照计算，最后汇总	
![在这里插入图片描述](09f8735a0ed04a82a164dfca191dc5c1.png)

```cpp
vec3 singleScatterSkyColor(vec3 camPosInPlanet, AtmosphereParameter param, vec3 viewDir){
    vec3 lightDir = normalize(-lightPos);
    int N_SAMPLE = 16;
    float dstToPlanet = RayIntersectSphere(vec3(0,0,0), param.PlanetRadius, camPosInPlanet, viewDir);
    float dstToAtmosphere = RayIntersectSphere(vec3(0,0,0), param.PlanetRadius + param.AtmosphereHeight, camPosInPlanet, viewDir);
    // 还没实现别的渲染，纯黑的，先不判断
//    if(dstToPlanet > 0.0 || dstToAtmosphere < 0.0){
//        return vec3(0);
//    }
    float stepSize = dstToAtmosphere / float(N_SAMPLE);
    vec3 testPoint = camPosInPlanet;
    vec3 color = vec3(0);
    for (int i =0; i<N_SAMPLE; i++) {
        // 太阳方向rayMarching的距离
        float disToLight = RayIntersectSphere(vec3(0,0,0), param.PlanetRadius + param.AtmosphereHeight, testPoint, lightDir);
        // 太阳到采样点之间的透光率
        vec3 tramsmittanceLightToTest = Transmittance(param,testPoint + lightDir * disToLight,testPoint);
        // 散射光比例
        vec3 scattering = Scattering(param, testPoint, lightDir, viewDir);
        // 摄像机到采样点之间的透光度
        vec3 tramsmittanceTestToCam = Transmittance(param,testPoint,camPosInPlanet);
        // 采样点的光照计算。// TODO：需要把太阳光放大很多倍才有比较亮的效果（因为ToneMapping压黑的）
        vec3 inScattering = tramsmittanceLightToTest * scattering * tramsmittanceTestToCam  * stepSize * lightColor * 4;
        testPoint += viewDir * stepSize;
        color += inScattering;
    }
    float cosAngle = dot(viewDir, lightDir);
    if(cosAngle > cos(0.02)) {
        // 视线指向太阳圆盘
        color += Transmittance(param, lightPos + vec3(0,param.PlanetRadius + param.AtmosphereHeight,0), camPosInPlanet) * lightColor;
    }
    return color;
}
```

## 透射率预计算
对于T2，因为每次都是固定在一个方向上进行透射率累加，所以一边计算一边缓存即可，不用每次都从头开始计算透射率，主要来看T1的预计算（因为每次计算太阳光到采样点的透射率都是一个全新的方向，不能利用之前的数据）
地球是圆的，大气层具有对称性，所以左右晃动不会影响透射率
![请添加图片描述](d876678d9886498c98e821aa14e3e99b.png)
也就是说，对于某一高度的着色点，不同方向上的透射率只和天顶角有关。高度和天顶角两个参数就能确定透射率。（待实现，可参考https://zhuanlan.zhihu.com/p/595576594）

## 展示
![请添加图片描述](d8f2037921a14f98b2f3349d4ea4d7aa.png)


![请添加图片描述](eccc71af70bb4589a8e954f8adcaf499.png)

![请添加图片描述](025e7da8dd62453095a4739f7c3d15ed.png)
这里还有一点点遮挡关系没有出来，不过不是重点
![请添加图片描述](2620c8616a784ec08d4b970669011ba4.png)

## 多重散射
![请添加图片描述](9d7d4eb1114643fc8aeb6b856a534ad7.png)
就像渲染方程，除了来自光源的直接光照+散射，场景中其他方向的粒子也会散射，也会对着色点有贡献，所以要积分获得整个球面上所有方向上的贡献之和，同时还有大量预计算这就做到了多重散射。这块的实现暂时放弃，同样可参考https://zhuanlan.zhihu.com/p/595576594
![请添加图片描述](0a0ce02d672f445cb8ba76594ac0869a.png)



