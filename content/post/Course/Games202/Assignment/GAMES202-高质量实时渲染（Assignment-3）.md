+++date = '2025-10-19T14:05:15+08:00'
draft = false
title = 'GAMES202 高质量实时渲染（Assignment 3）'
categories = ["学习笔记/GAMES202"]
tags = ["Games202"]
image ='8a13212a6c85436f925ee5f06d474564.png'
+++
# 作业介绍

首先看一下整体渲染流程
1. 绘制光源
2. 绘制shadowMap
3. diffuse、depth、normal、shadow、worldPos五个GBuffer信息
4. 最后利用上边的信息来真正进行渲染
```cpp
        // Draw light
        light.meshRender.mesh.transform.translate = light.entity.lightPos;
        light.meshRender.draw(this.camera, null, updatedParamters);

        // Shadow pass
        gl.bindFramebuffer(gl.FRAMEBUFFER, light.entity.fbo);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
        for (let i = 0; i < this.shadowMeshes.length; i++) {
            this.shadowMeshes[i].draw(this.camera, light.entity.fbo, updatedParamters);
            // this.shadowMeshes[i].draw(this.camera);
        }
        // return;

        // Buffer pass
        gl.bindFramebuffer(gl.FRAMEBUFFER, this.camera.fbo);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
        for (let i = 0; i < this.bufferMeshes.length; i++) {
            this.bufferMeshes[i].draw(this.camera, this.camera.fbo, updatedParamters);
            // this.bufferMeshes[i].draw(this.camera);
        }
        // return

        // Camera pass
        for (let i = 0; i < this.meshes.length; i++) {
            this.meshes[i].draw(this.camera, null, updatedParamters);
        }
```

# 直接光照
## EvalDiffuse(wi, wo, uv)
通过入射方向、出射方向、漫反射率纹理图uv坐标来计算BRDF的返回值，因为是计算diffuse的BRDF，所以它是一个常数
![请添加图片描述](e0c05229f5d34dec824183f4ab1e7831.png)
分母π保证了反射光的总能量不超过入射光能量
```cpp
vec3 EvalDiffuse(vec3 wi, vec3 wo, vec2 uv) {
  vec3 albedo = GetGBufferDiffuse(uv);
  vec3 normal = GetGBufferNormalWorld(uv);
  // 这里把cos项和BRDF项放在一起了
  float cosTheta = max(0,dot(normal,wi));
  return albedo * cosTheta * INV_PI;
}
```
这样就得到了渲染方程中的BRDF项
## EvalDirectionalLight(vec2 uv)
这里需要计算一个着色点的直接光照项（需要通过shadowMap来考虑阴影）

```cpp
vec3 EvalDirectionalLight(vec2 uv) {
    vec3 Le = GetGBufferuShadow(uv) * uLightRadiance;
  return Le;
}
```
其中GetGBufferuShadow方法返回的就是Visbility项，它在上一轮渲染中存储了每个像素的可见性信息
```cpp
float GetGBufferuShadow(vec2 uv) {
  float visibility = texture2D(uGShadow, uv).x;
  return visibility;
}
```

最后修改main函数，它还做了伽马矫正
```cpp
void main() {
  float s = InitRand(gl_FragCoord.xy);

  vec3 L = vec3(0.0);
  vec3 color = vec3(0.0);
  vec3 worldPos = vPosWorld.xyz;
  vec2 screenUV = GetScreenCoordinate(vPosWorld.xyz);
  vec3 wi = normalize(uLightDir);
  vec3 wo = normalize(uCameraPos - worldPos);

  // 直接光照
  L = EvalDiffuse(wi, wo, screenUV) * EvalDirectionalLight(screenUV);
  // gamma矫正
  color = pow(clamp(L, vec3(0.0), vec3(1.0)), vec3(1.0 / 2.2));
  gl_FragColor = vec4(vec3(color.rgb), 1.0);
}
```
我的电脑是mac，根据网上只有mac电脑会出下如下问题，根据视角移动会不断变换出错的位置
![请添加图片描述](92a237ad23cd47488788aec57d8651c8.png)
我们先把可见性设置为1，避免阴影生成，看看是什么情况
![请添加图片描述](4570536737ad40bbbc4876c1a143b807.png)
举个例子：假设地板深度值为0.5001，上方模型为0.5002。在16位深度缓冲区中，两者可能被四舍五入为相同值（如0.500），导致GPU随机选择显示其中一个67。此时地板可能因浮点舍入误差被误判为更小Z值，从而错误覆盖模型。

NDC坐标下的Z值并不是线性的，越靠近近平面的地方，精度越高，远的地方精度越低，参考下图
![请添加图片描述](8a42179c646f4909b9e669cde3b3c24c.png)
所以说当我把摄像机离得特别近时，这种问题慢慢就得到了缓解，因为接近近平面精度比较高![请添加图片描述](6be026bd8d2c4581a20316d792f8d7c9.png)
所以说这种问题的一种解决思路就是调整远近平面的距离，越小，精度高的范围越大，出现z-fighting可能性越低

```cpp
	// Add camera
	// const camera = new THREE.PerspectiveCamera(75, gl.canvas.clientWidth / gl.canvas.clientHeight, 1e-3, 1000);
	const camera = new THREE.PerspectiveCamera(75, gl.canvas.clientWidth / gl.canvas.clientHeight, 5e-2, 1e2);
```
![请添加图片描述](f1ace066ff5b458788b4ce3aa208e4f4.png)
为了验证这一说法的正确性，我们拉远镜头，就看出来这种问题又出现了，说明远处z值精度小
![请添加图片描述](22a169d0eeaa40cc94ecbe3e99d95195.png)
不过这种解决方案只适合玩具，调整NF参数属于是把整个项目的东西都改了，还有一种解决思路就是在有这种重叠放置的地方进行手动偏移

# 间接光照

## bool RayMarch(vec3 ori, vec3 dir, out vec3 hitPos)
这一步需要实现linear RayMarch，通过一条光线，求出击中点的坐标
![请添加图片描述](eb10b273434e4a0eb31474188f438ff5.png)
基本思路就是从着色点沿着光照方向每次向前一小步，查看这一点对应的深度值，并于深度缓冲中的深度值做比较，如果这一点深度值比深度缓冲中深度值大了，说明他已经处于可见物体的内部

```cpp
bool RayMarch(vec3 ori, vec3 dir, out vec3 hitPos) {
  const int totalStepTimes = 60;
  const float threshold = 0.0001;
  float step = 0.05;
  vec3 stepDir = normalize(dir) * step;
  vec3 curPos = ori;
  for(int i = 0; i < totalStepTimes; i++) {
    vec2 screenUV = GetScreenCoordinate(curPos);
    float rayDepth = GetDepth(curPos);
    float gBufferDepth = GetGBufferDepth(screenUV);

    // 已经在可见物体内部
    if(rayDepth > gBufferDepth + threshold){
      hitPos = curPos;
      return true;
    }
    curPos += stepDir;
  }
}
```
现在已经有方法对光线求交了，下面就来实现间接光照

```cpp
void main() {
  float s = InitRand(gl_FragCoord.xy);

  vec3 worldPos = vPosWorld.xyz;
  vec2 screenUV = GetScreenCoordinate(vPosWorld.xyz);
  vec3 wi = normalize(uLightDir);
  vec3 wo = normalize(uCameraPos - worldPos);
  vec3 normal = GetGBufferNormalWorld(screenUV);
  // 着色点的直接光照
  vec3 L = vec3(0.0);
  L = EvalDiffuse(wi, wo, screenUV) * EvalDirectionalLight(screenUV);

  // 着色点的间接光照
  vec3 L_ind = vec3(0.0);
  for(int i = 0; i < SAMPLE_NUM; i++){
    float pdf;
    vec3 localDir = SampleHemisphereCos(s, pdf);
    vec3 b1, b2;
    // 通过空间法线得到两个切线，从而建立切线空间坐标系
    LocalBasis(normal, b1, b2);
    // 通过BTN矩阵将局部坐标系转为世界坐标系
    vec3 dir = normalize(mat3(b1, b2, normal) * localDir);

    vec3 hit_pos = vec3(0.0);
    // 向采样方向发出光线
    if(RayMarch(worldPos, dir, hit_pos)){
      vec2 hitScreenUV = GetScreenCoordinate(hit_pos);
      // 通过蒙特卡洛积分来近似渲染方程的积分值
      L_ind += EvalDiffuse(dir, wo, screenUV) / pdf * EvalDiffuse(wi, dir, hitScreenUV) * EvalDirectionalLight(hitScreenUV);
    }
  }

  L_ind /= float(SAMPLE_NUM);
  L = L + L_ind;

  vec3 color = pow(clamp(L, vec3(0.0), vec3(1.0)), vec3(1.0 / 2.2));
  gl_FragColor = vec4(vec3(color.rgb), 1.0);
}
```
方块场景
![请添加图片描述](372eb00a41b34955af630e0346de9097.png)

洞穴场景渲染
![请添加图片描述](8a13212a6c85436f925ee5f06d474564.png)
只渲染间接光
![请添加图片描述](5c587b5eb47841c4bbbf97b90cec6805.png)
所以SSR我理解也是在做光线追踪，但只利用了屏幕空间的信息，也就是真正被渲染的位置的信息，被覆盖掉的着色点是不会考虑的，这当然要比直接做光线追踪快很多。课程后边有实时光线渲染，目前还不知道如何实现的。

目前从方块场景能看出一些问题
按照目前的一次弹射渲染逻辑，理论上阴影的颜色就应该是黑色（因为即使有击中点，这一点计算出来的直接光照也必然是黑色），而现在有点漏光了![请添加图片描述](a25ffa0da8e947a18dcce31ebc5baa7b.png)
说明它判断击中点时，判断了B4位置的颜色，而实际上，它直接穿过了模型，打到了模型的正面，说明步长太大了。参考其他博客的解决思路
>https://zhuanlan.zhihu.com/p/668194020
>代码的思路跟前面的差不多，每一次步进时，判断下一步位置的深度与gBuffer的深度的关系，如果下一步的位置在gBuffer的前面（nextDepth<gDepth），则可以步进。如果下一步的深度没有gBuffer的深，就判断一下深度相差多少，有没有给定的阈值大。如果比阈值大，那么就直接返回 false ，否则，这个时候就可以执行SSR了。先让当前位置步进一个step，返回给 hitPos ，然后返回真。
```cpp
bool RayMarch(vec3 ori, vec3 dir, out vec3 hitPos) {
  const float EPS = 1e-2;
  const int totalStepTimes = 20;
  const float threshold = 0.1;
  bool result = false, firstIn = false;
  float step = 0.8;
  vec3 curPos = ori;
  vec3 nextPos;
  for(int i = 0; i < totalStepTimes; i++) {
    nextPos = curPos+dir*step;
    vec2 uvScreen = GetScreenCoordinate(curPos);
    if(any(bvec4(lessThan(uvScreen, vec2(0.0)), greaterThan(uvScreen, vec2(1.0))))) break;
    if(GetDepth(nextPos) < GetGBufferDepth(GetScreenCoordinate(nextPos))){
      curPos += dir * step;
      if(firstIn) step *= 0.5;
      continue;
    }
    firstIn = true;
    if(step < EPS){
      float s1 = GetGBufferDepth(GetScreenCoordinate(curPos)) - GetDepth(curPos) + EPS;
      float s2 = GetDepth(nextPos) - GetGBufferDepth(GetScreenCoordinate(nextPos)) + EPS;
      if(s1 < threshold && s2 < threshold){
        hitPos = curPos + 2.0 * dir * step * s1 / (s1 + s2);
        result = true;
      }
      break;
    }
    if(firstIn) step *= 0.5;
  }
  return result;
}
```
使用大佬的优化算法，帧数一下就起来了

下面再介绍一下光线求交的加速方法，就是为深度图设置MipMap，上一层存入下一层4个像素的最小深度，也就是离屏幕更近的距离，如果一条光线在上一层中比最小距离更近，那它肯定不会在下一层中相交于物体，这样就可以省去很多if

具体的代码需要涉及到OpenGL如何生成这样的纹理，或者可能根本不支持这种mipmap，毕竟默认的mipmap并不是存最小值，而是平均值，可能需要自己写入缓存然后保存FBO，然后把它当作一张纹理来使用。我就不写了，目前阶段以学习理论为主