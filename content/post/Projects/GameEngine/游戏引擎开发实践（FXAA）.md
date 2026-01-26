+++
date = '2026-01-25T16:21:06+08:00'
draft = true
title = '游戏引擎开发实践（FXAA）'
+++

# 边缘检测

> 计算当前处理的像素点和周围像素点的亮度对比值，FXAA 通过确定水平和垂直方向上像素点的亮度差，来计算对比值。当对比度值较大时，我们认为需要进行抗锯齿处理。

实现比较容易，计算上下左右中间五个像素，求亮度，之后取最大值和最小值，如果差距过小，就当作不是边界，直接返回原数据

```c++
//////////////////////////////////////////// 1. 求亮度差 ////////////////////////////////////////////
vec2 texCoords = (vec2(invocID) + 0.5f) / vec2(textureSize);
float up = RGBtoLuminance(texture(sampler2D(historyTexture, SAMPLER[0]), texCoords + stepUV * Kernel_Map[1]).xyz);
float down = RGBtoLuminance(texture(sampler2D(historyTexture, SAMPLER[0]), texCoords + stepUV * Kernel_Map[7]).xyz);
float left = RGBtoLuminance(texture(sampler2D(historyTexture, SAMPLER[0]), texCoords + stepUV * Kernel_Map[3]).xyz);
float right = RGBtoLuminance(texture(sampler2D(historyTexture, SAMPLER[0]), texCoords + stepUV * Kernel_Map[5]).xyz);
float center = RGBtoLuminance(texture(sampler2D(historyTexture, SAMPLER[0]), texCoords).xyz);

float maxLum = max(center, max(max(up, down), max(left, right)));
float minLum = min(center, min(min(up, down), min(left, right)));
float Contrast =  maxLum - minLum;
if(Contrast < max(EDGE_THRESHOLD_MIN, maxLum * EDGE_THRESHOLD_MAX)) {
    vec4 outcolor = texture(sampler2D(historyTexture, SAMPLER[0]), texCoords);
    return;
}    
imageStore(out_texture, invocID, vec4(1,0,0,1));
```

看看效果，可以看到大部分点都认为是不需要进行处理的地方

![image-20260125230544796](image-20260125230544796.png)

## 基于亮度的混合系数计算

> 一方面考虑亮度差，另一方面考虑距离（对角线上的像素距离中心像素远一些）

![image-20260125231320673](image-20260125231320673.png)

```c++
//////////////////////////////////////////// 2. 计算基于亮度的混合系数计算 ////////////////////////////////////////////

float Filter = 2.0 * (N + E + S + W) + NE + NW + SE + SW;
Filter = Filter / 12.0;

Filter = abs(Filter - M);
Filter = saturate(Filter / Contrast);

float PixelBlend = smoothstep(0.0, 1.0, Filter);
PixelBlend = PixelBlend * PixelBlend;
```

### 计算混合方向与混合

> 锯齿的方向不一定一样，通过亮度差异来计算锯齿方向

![img](v2-355db30e96f383134fb2fb9babf16cc0_1440w.jpg)

计算完偏移方向后，最终采样点就往锯齿方向偏移，偏移量就是上一步获得的权重

```c++
    //////////////////////////////////////////// 3. 计算锯齿方向并混合 ////////////////////////////////////////////
    float Vertical = abs(N + S - 2 * M) * 2+ abs(NE + SE - 2 * E) + abs(NW + SW - 2 * W);
    float Horizontal = abs(E + W - 2 * M) * 2 + abs(NE + NW - 2 * N) + abs(SE + SW - 2 * S);
    bool IsHorizontal = Vertical > Horizontal;  // 垂直方向上亮度变化大，说明锯齿是水平的
    vec2 PixelStep = IsHorizontal ? vec2(0, stepUV.y) : vec2(stepUV.x, 0);
    float Positive = abs((IsHorizontal ? N : E) - M);
    float Negative = abs((IsHorizontal ? S : W) - M);
    if(Positive < Negative) PixelStep = -PixelStep;   // PixelStep往亮度大方向移动

    vec4 outcolor = texture(sampler2D(historyTexture, SAMPLER[0]), texCoords + PixelStep * PixelBlend);
```

