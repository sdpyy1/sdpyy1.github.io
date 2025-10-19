+++
date = '2025-10-19T14:03:49+08:00'
draft = false
title = 'GAMES202 高质量实时渲染（Assignment 1）'
categories = ["Course/Games202","Assignment"]
tags = ["课程作业","Games202"]
+++
# Homework1
## shadow Map
首先需要完成MVP矩阵的构造，在这里的mvp用来表示如果一个模型在shadowmap视角下的位置

```cpp
    CalcLightMVP(translate, scale) {
        let lightMVP = mat4.create();
        let modelMatrix = mat4.create();
        let viewMatrix = mat4.create();
        let projectionMatrix = mat4.create();

        // Model transform
        mat4.translate(modelMatrix,modelMatrix,translate);
        mat4.scale(modelMatrix,modelMatrix,scale);
        // View transform
        mat4.lookAt(viewMatrix, this.lightPos, this.focalPoint, this.lightUp);
        // Projection transform
        mat4.ortho(projectionMatrix, -100,100,-100,100,0.1,400); // 实测far要得400可以覆盖到整个平面
        mat4.multiply(lightMVP, projectionMatrix, viewMatrix);
        mat4.multiply(lightMVP, lightMVP, modelMatrix);
        return lightMVP;
    }
```
他在顶点着色器中使用，目的是传递每个顶点位置在光源视角下坐标`  vPositionFromLight = uLightMVP * vec4(aVertexPosition, 1.0);
`
在片段着色器中，先实现比较的函数

```cpp
float useShadowMap(sampler2D shadowMap, vec4 shadowCoord){
  // shadowmap中存储的深度
  float lightDepth = unpack(texture2D(shadowMap, shadowCoord.xy));
  // 着色点深度
  float shadowDepth = shadowCoord.z;
  float visibility = 1.0;
  // 被挡住了
  if (shadowDepth > lightDepth) {
    visibility = 0.0;
  }
  return visibility;
}
```
在主函数中，需要先对光源坐标处理一下，因为它是经过透视投影处理后的NDC坐标，而shadowMap上取值其实需要的是UV坐标（0，1）之间，所以需要先转到[0,1]之间
⚠️：透视除法在透视投影时才需要，我看别的博客都写了，其实是不需要的
```cpp
  float visibility = 1.0;
  // 透视投影时才需要
  // vec3 shadowCoord = vPositionFromLight.xyz / vPositionFromLight.w;
  vec3 shadowCoord = (vPositionFromLight.xyz+1.0)/2.0;
  visibility = useShadowMap(uShadowMap, vec4(shadowCoord, 1.0));
```
![请添加图片描述](2512767e2eb04bca806c3d6c4f27f50d.png)
居然没出现自阴影问题，我们手动创建一个，首先光源位置修改在engine.js中`lightPos`

```cpp
	// Add lights
	// light - is open shadow map == true
	let lightPos = [0, 90, 80];
	let focalPoint = [0, 0, 0];
	let lightUp = [0, 1, 0]
	const directionLight = new DirectionalLight(5000, [1, 1, 1], lightPos, focalPoint, lightUp, true, renderer.gl);
	renderer.addLight(directionLight);
```
把光源变斜一点，就会发现场景从远到近逐渐出现自阴影现象
y = 40
![请添加图片描述](0fc12ecbe085466282cdd9000f85a9cc.png)
y=30![请添加图片描述](d87e3c12019a442ba4111897ea288b43.png)
y=20
![请添加图片描述](cc230e1ed77440258c7c9b21d6c3406b.png)
y=10这时候整个地板都出错了
![请添加图片描述](7e891f865178491baf2e906dd1291639.png)
加一个自偏移，就解决了

```cpp
  if (shadowDepth  > lightDepth + 0.01) {
    visibility = 0.0;
  }
```
![请添加图片描述](b6fab18e30604f9492873f8c479b1fa2.png)
下面是偏移量改为0.05的效果，效果就太差了，偏移量应该根据光照的角度动态调整
![请添加图片描述](09ff707a0adc4aa3a0d37cc2777b38da.png)

走样的情况，下面就用PCF来解决～
![请添加图片描述](443c67a5eeb94f5192ba4e0d6dd8255a.png)
## PCF(Percentage Closer Filter)
简单理解就是不只判断shadowmap的一个位置，而是一圈位置的平均。
作业中提供了两种采样，它的作用就是减少计算量，没必要真的一个一个便利来取均值，偏移记录在了`vec2 poissonDisk[NUM_SAMPLES];`
下面是我的实现
```cpp
float PCF(sampler2D shadowMap, vec4 coords) {
  poissonDiskSamples(coords.xy);
  // 采样数
  float numSamples = 0.0;
  // 没有遮挡的采样数
  float numUnBlock = 0.0;
  // 过滤核大小
  float filterSize = 5.0;
  float mapSize = 2048.0;
  // 过滤核范围
  float filterRange = filterSize / mapSize;
  for(int i = 0;i<NUM_SAMPLES;i++){
    vec2 samplexCoor = coords.xy + poissonDisk[i] * filterRange;
    // 采样时可能会越界
    if(samplexCoor.x > 0.0 && samplexCoor.x < 1.0 && samplexCoor.y > 0.0 && samplexCoor.y < 1.0) {
      numSamples++;
      if(useShadowMap(shadowMap,vec4(samplexCoor,coords.z,1.0)) == 1.0) {
        numUnBlock++;
      }
    }
  }
  return numUnBlock/numSamples;
}
```
锯齿位置的变化（过滤核大小为5）
![请添加图片描述](6aa19964fb46400ca8f117b43734a99c.png)
当改为20时
![请添加图片描述](1cbe62a143964f31bb42e77527909ef0.png)
改为100时，出现了大量噪点
![请添加图片描述](7d9e0921010a4dd4a35671a4cba27684.png)

## PCSS(Percentage Closer Soft Shadow)
用PCF来做软阴影，一句话来说就是动态修改过滤核的尺寸，达到不同的因子区域不同的软硬程度

第一步需要在一定范围内搜索深度比着色点进的点，从而得到一个平均深度

```cpp
float findBlocker( sampler2D shadowMap,  vec2 uv, float zReceiver ) {
	int numSamples = 0;
  float sumDepth = 0.0;
  float searchSize = 15.0;
  float mapSize = 2048.0;
  float searchRange = searchSize / mapSize;
  for( int i = 0; i < BLOCKER_SEARCH_NUM_SAMPLES; i ++ ) {
    vec2 sampleCoor = uv + poissonDisk[i] * searchRange;
    // 采样时可能会越界
    if(sampleCoor.x > 0.0 && sampleCoor.x < 1.0 && sampleCoor.y > 0.0 && sampleCoor.y < 1.0) {
      float depth = unpack(texture2D(shadowMap, sampleCoor));
      if(depth < zReceiver) {
        sumDepth += depth;
        numSamples++;
      }
    }
  }
  if(numSamples > 0) {
    return sumDepth / float(numSamples);
  } else {
    return zReceiver;
  }
}
```
下来就计算半影尺寸并把它作为过滤核尺寸来进行PCF

```cpp
float PCSS(sampler2D shadowMap, vec4 coords){
  uniformDiskSamples(coords.xy);
  // STEP 1: avgblocker depth
  float avgBlockerDepth = findBlocker(shadowMap, coords.xy, coords.z);
  // STEP 2: penumbra size
  // 假设光源尺寸为50
  float Wlight = 50.0;
  float penumbraSize = (coords.z - avgBlockerDepth) * Wlight / avgBlockerDepth;
  // STEP 3: filtering
  // 把半影尺寸当做过滤核大小
  return PCF(shadowMap, coords,penumbraSize);
}
```
光源尺寸越大，阴影软硬区分程度越大，因为计算出的过滤核尺寸区分度越大
Wlight = 50
![请添加图片描述](19ecfe67f62c49c098cdda6bb944ce6f.png)
Wlight = 100
![请添加图片描述](d62c51f4d6764bfbbbcf7eafca8d191a.png)
设置过小时，反而看不出什么效果
![请添加图片描述](531daca67f0242c6abba44c1e5a88603.png)
