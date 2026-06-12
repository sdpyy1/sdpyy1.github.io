+++date = '2025-10-19T13:52:28+08:00'
draft = false
title = 'OpenGL学习笔记（HDR、泛光）'
categories = ["图形API/OpenGL"]
tags = ["API学习","OpenGL"]
image = '3f35480e680a4948bb8b80386c384e22.png'
+++
# HDR
**一句话理解就是不要让颜色限制到0-1.先拓展到很大的范围，最后再通过某种映射回到0-1，这样不同颜色的区分度就会变大。**
大量片段的颜色值都非常接近1.0，在很大一个区域内每一个亮的片段都有相同的白色。这损失了很多的细节，使场景看起来非常假。![请添加图片描述](892e74f91617493388600ffd17eed15f.png)
一个更好的方案是让颜色暂时超过1.0，然后将其转换至0.0到1.0的区间内，从而防止损失细节。

显示器被限制为只能显示值为0.0到1.0间的颜色，但是在光照方程中却没有这个限制。通过使片段的颜色超过1.0，我们有了一个更大的颜色范围，这也被称作HDR(High Dynamic Range, 高动态范围)

HDR渲染和其很相似，我们允许用更大范围的颜色值渲染从而获取大范围的黑暗与明亮的场景细节，最后将所有HDR值转换成在[0.0, 1.0]范围的LDR(Low Dynamic Range,低动态范围)。转换HDR值到LDR值得过程叫做色调映射(Tone Mapping)

在OpenGL中通过设置帧缓冲的颜色分量的不同格式来让颜色值不限制在0-1之间。
默认的帧缓冲默认一个颜色分量只占用8位(bits)。当使用一个使用32位每颜色分量的浮点帧缓冲时(使用GL_RGB32F 或者GL_RGBA32F)，我们需要四倍的内存来存储这些颜色。所以除非你需要一个非常高的精确度，32位不是必须的，使用GLRGB16F就足够了。

当存储好颜色后，不能直接将这个FBO渲染到屏幕上，因为又会被限制在0-1之间，需要先进行色调映射，最简单的色调映射算法是**Reinhard色调映射**，它涉及到分散整个HDR颜色值到LDR颜色值上，所有的值都有对应。

# 泛光
让发光的东西更像在发光的技术。

这种光流，或发光效果，是通过一种叫做泛光(Bloom)的后期处理效果来实现的。泛光使场景中所有明亮的区域都具有类似发光的效果
![请添加图片描述](421e3d982b0a44ce8a5d4e81bffcbc4b.png)

我们来一步一步解释这个处理过程。我们在场景中渲染一个带有4个立方体形式不同颜色的明亮的光源。带有颜色的发光立方体的亮度在1.5到15.0之间。如果我们将其渲染至HDR颜色缓冲，场景看起来会是这样的：

![请添加图片描述](e7348be688de4a11bdb82f6621e8a977.png)
我们得到这个HDR颜色缓冲纹理，提取所有超出一定亮度的fragment。这样我们就会获得一个只有fragment超过了一定阈限的颜色区域：
![请添加图片描述](c320932193f9426d92f57048a3c93175.png)
我们将这个超过一定亮度阈限的纹理进行模糊处理。泛光效果的强度很大程度上是由模糊过滤器的范围和强度决定的。![请添加图片描述](1b24536f1e5a4d1e9c8fef3f07d90f43.png)
最终的被模糊化的纹理就是我们用来获得发出光晕效果的东西。这个已模糊的纹理要添加到原来的HDR场景纹理之上。由于模糊滤镜的作用，明亮的区域在宽度和高度上都得到了扩展，因此场景中的明亮区域看起来会发光或流光。![请添加图片描述](91ee97aa61ea45d2adc9229b44913cd6.png)
一个FBO可以挂在两个颜色缓冲附件

```cpp
layout (location = 0) out vec4 FragColor;
layout (location = 1) out vec4 BrightColor;
```
输出颜色时通过不同条件写入到不同的颜色缓冲中
```cpp
#version 330 core
layout (location = 0) out vec4 FragColor;
layout (location = 1) out vec4 BrightColor;

[...]

void main()
{            
    [...] // first do normal lighting calculations and output results
    FragColor = vec4(lighting, 1.0f);
    // Check whether fragment output is higher than threshold, if so output as brightness color
    float brightness = dot(FragColor.rgb, vec3(0.2126, 0.7152, 0.0722));
    if(brightness > 1.0)
        BrightColor = vec4(FragColor.rgb, 1.0);
}
```
有了两个颜色缓冲，我们就有了一个正常场景的图像和一个提取出的亮区的图像。这些都在一个渲染步骤中完成。

![请添加图片描述](3f35480e680a4948bb8b80386c384e22.png)
## 高斯模糊
介绍一个高级点的模糊处理器
高斯模糊基于高斯曲线，高斯曲线通常被描述为一个钟形曲线，中间的值达到最大化，随着距离的增加，两边的值不断减少。高斯曲线在数学上有不同的形式，但是通常是这样的形状
![请添加图片描述](d6f3aae0352b4016bddf0d37e03a6235.png)
其实就是滤波核的权重不一样了～
我们可以从二维高斯曲线方程中获得权重。然而这个过程有个问题，就是很快会消耗极大的性能。以一个32×32的模糊kernel为例，我们必须对每个fragment从一个纹理中采样1024次！

幸运的是，高斯方程有个非常巧妙的特性，它允许我们把二维方程分解为两个更小的方程：一个描述水平权重，另一个描述垂直权重。我们首先用水平权重在整个纹理上进行水平模糊，然后在经改变的纹理上进行垂直模糊。利用这个特性，结果是一样的，但是可以节省难以置信的性能，因为我们现在只需做32+32次采样，不再是1024了！这叫做两步高斯模糊。
水平模糊一次、垂直模糊一次，就避免了每个像素单独处理的麻烦
![请添加图片描述](ac23e4a98a6641e39f85f76e32ddf249.png)
## 把两个纹理混合
其实就是两张纹理相加～

```cpp
#version 330 core
out vec4 FragColor;
in vec2 TexCoords;

uniform sampler2D scene;
uniform sampler2D bloomBlur;
uniform float exposure;

void main()
{             
    const float gamma = 2.2;
    vec3 hdrColor = texture(scene, TexCoords).rgb;      
    vec3 bloomColor = texture(bloomBlur, TexCoords).rgb;
    hdrColor += bloomColor; // additive blending
    // tone mapping
    vec3 result = vec3(1.0) - exp(-hdrColor * exposure);
    // also gamma correct while we're at it       
    result = pow(result, vec3(1.0 / gamma));
    FragColor = vec4(result, 1.0f);
}
```
