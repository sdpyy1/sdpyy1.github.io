+++
date = '2025-10-19T13:42:48+08:00'
draft = false
title = 'TinyRender开发记录 5 7'
categories = ["Projects/TinyRender"]
tags = ["渲染器开发","TinyRender"]
+++
# Lesson 5:  Gouraud shading
本节课实现了 Gouraud shading，对三角形每个顶点用法线求光照，进一步插值到内部像素，相比于phong，phong是要对每个内部像素都需要计算光照，这里简单处理就是默认为255，255，255的白光，计算顶点法线和光照方向的夹角（注意单位化和钝角处理)，得到cos直接乘以光照，就得到了每个顶点的变暗比例，之后再插值到各个像素，关键代码如下

```cpp
void Triangle::setShadingColor(Eigen::Vector3f lightDir) {
    lightDir.normalize();
    Vector3f basecolor = Vector3f(255,255,255);
    for (int i = 0; i < 3; ++i) {
        // 确保法线已归一化，并限制点积结果非负
        float intensity = std::max(0.0f, normal[i].normalized().dot(lightDir));
        color[i] = basecolor * intensity;
    }
}
```
因为我的MVP变换和课程设置不一致，所以角度不一样，下面展示 lightDir(1,-1,1)情况下的渲染
![在这里插入图片描述](778af6511c364147942ed5581d92eefc.png)
完整代码在（Gouraud-shading分支）：https://github.com/sdpyy1/CppLearn/tree/Gouraud-shading
# Lesson 6: Shaders for the software renderer
## phongShading
首先是进行了PhongShading，思路就是插值出每个像素的法向量、每个像素对应的原来的位置（即着色点的位置，需要在顶点着色器中提前存储）以及光源的位置、摄像机的位置来计算高光、漫反射以及加上环境光,主要代码如下（自己实现注意颜色值的变化，防止过曝）

```cpp
Eigen::Vector3f TGAColorToVector3f(const TGAColor& color) {
    float r = static_cast<float>(color.bgra[2]) / 255.0f;
    float g = static_cast<float>(color.bgra[1]) / 255.0f;
    float b = static_cast<float>(color.bgra[0]) / 255.0f;
    return Eigen::Vector3f(r, g, b);
}
// 将Eigen::Vector3f转换为TGAColor的函数
TGAColor Vector3fToTGAColor(const Eigen::Vector3f& vectorColor) {
    auto clamp = [](float v) { return std::max(0.0f, std::min(1.0f, v)); };
    unsigned char r = static_cast<unsigned char>(clamp(vectorColor.x()) * 255.0f);
    unsigned char g = static_cast<unsigned char>(clamp(vectorColor.y()) * 255.0f);
    unsigned char b = static_cast<unsigned char>(clamp(vectorColor.z()) * 255.0f);
    return TGAColor(r, g, b);
}
// blinnPhongShading
TGAColor blinnPhongShading(const TGAColor & kdColor,const Vector3f & point,const Vector3f & normal) {
    Eigen::Vector3f ka = Eigen::Vector3f(0.005, 0.005, 0.005);
    Eigen::Vector3f kd = TGAColorToVector3f(kdColor);
    Eigen::Vector3f ks = Eigen::Vector3f(0.7937, 0.7937, 0.7937);
    // 环境光强度
    Eigen::Vector3f amb_light_intensity{10, 10, 10};
    // 高光的指数，越大对角度越敏感
    float p = 150;
    // 计算点到光源的向量
    Eigen::Vector3f light_vec = lightDir - point;
    // 计算点到光源的距离
    float r = light_vec.norm();
    // 归一化从点到光源的向量
    Eigen::Vector3f light_dir = light_vec.normalized();
    // 漫反射
    Eigen::Vector3f diffuse = kd.cwiseProduct(lightIntensity / (r * r)) * std::max(0.0f, normal.dot(light_dir));
    // 高光反射
    // 计算从表面点到观察者的向量
    Eigen::Vector3f view_dir = (viewDir - point).normalized();
    // 计算半程向量
    Eigen::Vector3f halfVector = (light_dir + view_dir).normalized();
    Eigen::Vector3f specular = ks.cwiseProduct(lightIntensity / (r * r)) * std::pow(std::max(0.0f, normal.dot(halfVector)), p);
    Eigen::Vector3f all = diffuse + specular + ka.cwiseProduct(amb_light_intensity);
    return Vector3fToTGAColor(all);
}
```

## 法线贴图
法线贴图是通过使用 RGB 纹理的红色、绿色和蓝色分量来存储法线的 XYZ 分量，但是存储在法线贴图中的法线是模型坐标系下的法线坐标，如果模型在空间中发生了旋转，那法线位置就会发生变化，所以如果要用法线贴图，需要对法线变换到global坐标系下才行。另外不能简单地给法线左乘一个模型变换矩阵，解释及正确做法如下（也不是一定不行，有几种模型变换是不行滴）
![请添加图片描述](e302739d57b74492bfacc7d258946ea4.png)
下面使用法线贴图作为color得到的图片
![请添加图片描述](906cafb276b4449f84b6dd977052a20a.png)
下面使用法线贴图作为phongshading的法线来渲染光照，注意贴图范围是[-1，1]，而颜色通道是[0,1]，也就是拿到的材质颜色是[0,1]的，需要先转成[-1,1]才可以使用，关键代码如下

```cpp
            // 法线来自法线贴图
            Eigen::Vector3f barycentricNorm = TGAColorToVector3f(nm.getColor(texU,texV))*2-Vector3f{1,1,1};
```
对比直接使用插值的法线和使用贴图法线的效果区别，区别还是很明显的，使用法线贴图并没有增加模型的结构，但精细程度大大提升了
![请添加图片描述](7799600835494a2681ba86db3e992fbe.png)
![请添加图片描述](ffcc9426ad114d0da59ea8fac6c7ab0a.png)

## Specular mapping 高光贴图
在之前的设置中镜面反射系数是自己设置的，使用高光贴图就是用来获取这个参数

```cpp
    Eigen::Vector3f ks = Eigen::Vector3f(0.7937, 0.7937, 0.7937);

```
修改为从高光贴图中获得

```cpp
            // 高光系数来自高光贴图
            TGAColor specKd = spec.getColor(texU,texV);
```
最终效果如下，变化看不太出来了，主要是一些奇怪的高光点消失了
![请添加图片描述](411cee7014ba4c0d979bd4541e58a605.png)
## tangent space normal mapping ‌切线空间法线贴图
将法线方向存储在‌切线空间‌（Tangent Space）中，而非模型或世界空间。这种技术可以显著提升表面凹凸感，且对模型变形（如动画）更友好，首先解释一下切线空间
![请添加图片描述](94a52acdc6ca46d0978954dfed295449.png)
这个东西就是把法线存储在切线空间坐标下，如果需要法线就在着色器中，通过 ‌TBN矩阵‌（Tangent-Bitangent-Normal Matrix）将法线从切线空间转换到世界空间

**为什么有了法线贴图，还需要切线法线贴图呢？**
1. 普通法线贴图与特定的模型紧密绑定的，当模型的形状、朝向或者拓扑结构发生变化时，法线贴图可能就不再适用。切线空间是每个顶点局部的一个坐标系，它由切线（Tangent）、副切线（Bitangent）和法线（Normal）三个向量定义。切线空间法线贴图中的法向量是相对于每个顶点的切线空间而言的。这种表示方式使得法线贴图具有更好的可移植性，同一个切线空间法线贴图可以应用到不同形状和朝向的模型上，只要每个模型的切线空间能够正确计算，就可以得到正确的光照效果。
2. 切线空间法线贴图能够很好地支持模型变形。因为切线空间是随着顶点一起变形的，当模型发生变形时，切线空间也会相应地改变，而切线空间法线贴图中的法向量在新的切线空间中仍然能够正确表示表面的细节。所以，即使模型在动画过程中发生了变形，光照效果依然能够保持正确。

如果不对切线法线贴图进行转换，直接使用，效果如下哈哈哈
![请添加图片描述](62c2dbe29bab4549940aae2f6b33c04c.png)
获取到切线法线贴图后，需要左乘一个TBN矩阵，转为空间法线才能使用，第一列是三角形的切线，第二列是副切线，第三列是法线
![请添加图片描述](41e46c065dd2466d920e4337e581759b.png)
具体转化函数如下

```cpp
// 从切线法线转为法线
Eigen::Vector3f getNormalFromTangent(const Triangle& triangle, const Eigen::Vector3f& tangentSpaceNormal, const Eigen::Vector3f& barycentricNorm) {
    // 计算切线
    Eigen::Vector3f edge1 = triangle.globalCoords[1].head<3>() - triangle.globalCoords[0].head<3>();
    Eigen::Vector3f edge2 = triangle.globalCoords[2].head<3>() - triangle.globalCoords[0].head<3>();
    Eigen::Vector2f deltaUV1 = triangle.texCoords[1] - triangle.texCoords[0];
    Eigen::Vector2f deltaUV2 = triangle.texCoords[2] - triangle.texCoords[0];

    float f = 1.0f / (deltaUV1.x() * deltaUV2.y() - deltaUV2.x() * deltaUV1.y());

    Eigen::Vector3f tangent;
    tangent.x() = f * (deltaUV2.y() * edge1.x() - deltaUV1.y() * edge2.x());
    tangent.y() = f * (deltaUV2.y() * edge1.y() - deltaUV1.y() * edge2.y());
    tangent.z() = f * (deltaUV2.y() * edge1.z() - deltaUV1.y() * edge2.z());
    tangent.normalize();

    // 计算副切线
    Eigen::Vector3f bitangent;
    bitangent.x() = f * (-deltaUV2.x() * edge1.x() + deltaUV1.x() * edge2.x());
    bitangent.y() = f * (-deltaUV2.x() * edge1.y() + deltaUV1.x() * edge2.y());
    bitangent.z() = f * (-deltaUV2.x() * edge1.z() + deltaUV1.x() * edge2.z());
    bitangent.normalize();


    // 构建 TBN 矩阵
    Eigen::Matrix3f TBN;
    TBN.col(0) = tangent;
    TBN.col(1) = bitangent;
    TBN.col(2) = barycentricNorm;

    // 将切向法线转换到世界空间
    return TBN * tangentSpaceNormal;
}
```
最终用转化后的切线作为像素的切线得到的图片如下![请添加图片描述](376308674cff41d0a41f4933b97538c1.png)
# Lesson 7: Shadow mapping
简单理解就是把光源当作摄像机，重新渲染一遍场景，但只需要记录每个点离光源最近的点，也就是哪些点能被光源照到，在正式渲染时，判断一个点颜色时，先去刚才记录的光照缓存中查看该点是否能被光照到，来决定是否进行渲染
完成的做法是对于一个像素，先去找它原本在空间中的位置，紧接着做MVP变换和视口变换变到以光源为摄像机下的对应像素块的位置，判断该位置深度是否需要阴影，不需要阴影才去正常进行光照，我的简单做法是如果在阴影，就让光照最终结果*0.2,从而变暗，这里这样做只是为了效果好看，不过这个光照模型本身就是不准确的，我的做法并不特别准确，但是理解原理即可
整体实现代码如下，其他未展示文件可以在仓库中找到

```cpp
#include "thirdParty/tgaimage.h"
#include "model.h"
#include <vector>
#include <cmath>
#include "iostream"
using namespace std;
constexpr static int width  = 1000;
constexpr static int height = 1000;
float angleX = 0.0f;
float angleY = 0.0f;
float angleZ = 0.0f;
float tx = 0.0f;
float ty = 0.0f;
float tz = 0.0f;
float sx = 1.0f;
float sy = 1.0f;
float sz = 1.0f;
Eigen::Vector3f eye_pos{0,0,3};
Eigen::Vector3f eye_dir(0.0f, 0.0f, -1.0f);
Eigen::Vector3f up(0.0f, 1.0f, 0.0f);
float fovY = 45.0f;
float aspectRatio = 1.0f;
float near = 0.1f;
float far = 100.0f;
Eigen::Vector3f lightDir{1,1,0};
Eigen::Vector3f lightIntensity{5,5,5};
// 计算三角形面积，可能返回负数，表示背对屏幕
float signed_triangle_area(float ax, float ay, float bx, float by, float cx, float cy) {
    return .5f*((by-ay)*(bx+ax) + (cy-by)*(cx+bx) + (ay-cy)*(ax+cx));
}
Eigen::Vector3f TGAColorToVector3f(const TGAColor& color) {
    float r = static_cast<float>(color.bgra[2]) / 255.0f;
    float g = static_cast<float>(color.bgra[1]) / 255.0f;
    float b = static_cast<float>(color.bgra[0]) / 255.0f;
    return Eigen::Vector3f(r, g, b);
}
// 将Eigen::Vector3f转换为TGAColor的函数
TGAColor Vector3fToTGAColor(const Eigen::Vector3f& vectorColor) {
    auto clamp = [](float v) { return std::max(0.0f, std::min(1.0f, v)); };
    unsigned char r = static_cast<unsigned char>(clamp(vectorColor.x()) * 255.0f);
    unsigned char g = static_cast<unsigned char>(clamp(vectorColor.y()) * 255.0f);
    unsigned char b = static_cast<unsigned char>(clamp(vectorColor.z()) * 255.0f);
    return TGAColor(r, g, b);
}
// blinnPhongShading
TGAColor blinnPhongShading(const TGAColor & textureColor, const Vector3f & point, const Vector3f & normal,TGAColor specKd,bool isShadow) {
    // 环境光系数
    Eigen::Vector3f ka = Eigen::Vector3f(0.005, 0.005, 0.005);
    // 漫反射系数（来自材质贴图）
    Eigen::Vector3f kd = TGAColorToVector3f(textureColor);
    // 高光系数（来自高光贴图）
    Eigen::Vector3f ks = TGAColorToVector3f(specKd);
    Eigen::Vector3f amb_light_intensity{10, 10, 10};

    // 环境光强度
    // 高光的指数，越大对角度越敏感
    float p = 150;
    // 计算点到光源的向量
    Eigen::Vector3f light_vec = lightDir - point;
    // 计算点到光源的距离
    float r = light_vec.norm();
    // 归一化从点到光源的向量
    Eigen::Vector3f light_dir = light_vec.normalized();
    // 漫反射
    Eigen::Vector3f diffuse = kd.cwiseProduct(lightIntensity / (r * r)) * std::max(0.0f, normal.dot(light_dir));
    // 高光反射
    // 计算从表面点到观察者的向量
    Eigen::Vector3f view_dir = (eye_pos - point).normalized();
    // 计算半程向量
    Eigen::Vector3f halfVector = (light_dir + view_dir).normalized();
    Eigen::Vector3f specular = ks.cwiseProduct(lightIntensity / (r * r)) * std::pow(std::max(0.0f, normal.dot(halfVector)), p);
    Eigen::Vector3f all = diffuse + specular + ka.cwiseProduct(amb_light_intensity);
    if (isShadow){
        return Vector3fToTGAColor(all*0.2);
    }
    return Vector3fToTGAColor(all);
}
// 插值函数
Eigen::Vector3f interpolate(const Eigen::Vector3f& v0, const Eigen::Vector3f& v1, const Eigen::Vector3f& v2, double alpha, double beta, double gamma) {
    return alpha * v0 + beta * v1 + gamma * v2;
}
float interpolate(float v0, float v1, float v2, float alpha, float beta, float gamma) {
    return alpha * v0 + beta * v1 + gamma * v2;
}

// 从切线法线转为法线
Eigen::Vector3f getNormalFromTangent(const Triangle& triangle, const Eigen::Vector3f& tangentSpaceNormal, const Eigen::Vector3f& barycentricNorm) {
    // 计算切线
    Eigen::Vector3f edge1 = triangle.globalCoords[1].head<3>() - triangle.globalCoords[0].head<3>();
    Eigen::Vector3f edge2 = triangle.globalCoords[2].head<3>() - triangle.globalCoords[0].head<3>();
    Eigen::Vector2f deltaUV1 = triangle.texCoords[1] - triangle.texCoords[0];
    Eigen::Vector2f deltaUV2 = triangle.texCoords[2] - triangle.texCoords[0];

    float f = 1.0f / (deltaUV1.x() * deltaUV2.y() - deltaUV2.x() * deltaUV1.y());

    Eigen::Vector3f tangent;
    tangent.x() = f * (deltaUV2.y() * edge1.x() - deltaUV1.y() * edge2.x());
    tangent.y() = f * (deltaUV2.y() * edge1.y() - deltaUV1.y() * edge2.y());
    tangent.z() = f * (deltaUV2.y() * edge1.z() - deltaUV1.y() * edge2.z());
    tangent.normalize();

    // 计算副切线
    Eigen::Vector3f bitangent;
    bitangent.x() = f * (-deltaUV2.x() * edge1.x() + deltaUV1.x() * edge2.x());
    bitangent.y() = f * (-deltaUV2.x() * edge1.y() + deltaUV1.x() * edge2.y());
    bitangent.z() = f * (-deltaUV2.x() * edge1.z() + deltaUV1.x() * edge2.z());
    bitangent.normalize();


    // 构建 TBN 矩阵
    Eigen::Matrix3f TBN;
    TBN.col(0) = tangent;
    TBN.col(1) = bitangent;
    TBN.col(2) = barycentricNorm;

    // 将切向法线转换到世界空间
    return TBN * tangentSpaceNormal;
}

void shadow(Triangle &triangle,std::vector<std::vector<float>> *shadowBuffer){
    float ax = triangle.screenCoords[0].x();
    float ay = triangle.screenCoords[0].y();
    float bx = triangle.screenCoords[1].x();
    float by = triangle.screenCoords[1].y();
    float cx = triangle.screenCoords[2].x();
    float cy = triangle.screenCoords[2].y();
    int bbminx = std::floor(std::min(std::min(ax, bx), cx));
    int bbminy = std::ceil(std::min(std::min(ay, by), cy));
    int bbmaxx = std::floor(std::max(std::max(ax, bx), cx));
    int bbmaxy = std::ceil(std::max(std::max(ay, by), cy));
    float total_area = signed_triangle_area(ax, ay, bx, by, cx, cy);

    for (int x = bbminx; x <= bbmaxx; x++) {
        for (int y = bbminy; y <= bbmaxy; y++) {
            // 虽然可以把整个三角形直接剔除，但是我希望只是把屏幕外的像素剔除
            if (x < 0 || x >= width || y < 0 || y >= height) {
                continue;
            }
            float alpha = signed_triangle_area(x, y, bx, by, cx, cy) / total_area;
            float beta = signed_triangle_area(x, y, cx, cy, ax, ay) / total_area;
            float gamma = signed_triangle_area(x, y, ax, ay, bx, by) / total_area;
            if (alpha < 0 || beta < 0 || gamma < 0) continue; // 说明当前像素不在三角形内部
            float barycentricZ = interpolate(triangle.screenCoords[0].z(), triangle.screenCoords[1].z(),triangle.screenCoords[2].z(), alpha, beta, gamma);
            if (shadowBuffer->at(x).at(y) < barycentricZ) {
                shadowBuffer->at(x).at(y) = barycentricZ;
            }
        }
    }
}





// 绘制一个三角形
    void drawTriangle(Triangle &triangle, TGAImage &framebuffer, std::vector<std::vector<float>> *zBuffer, std::vector<std::vector<float>> *shadowBuffer,Texture &texture,
                 Texture &nm, Texture &spec, Texture &nm_tangent,Eigen::Matrix4f mvpForShadow) {
        float ax = triangle.screenCoords[0].x();
        float ay = triangle.screenCoords[0].y();
        float bx = triangle.screenCoords[1].x();
        float by = triangle.screenCoords[1].y();
        float cx = triangle.screenCoords[2].x();
        float cy = triangle.screenCoords[2].y();
        int bbminx = std::floor(std::min(std::min(ax, bx), cx));
        int bbminy = std::ceil(std::min(std::min(ay, by), cy));
        int bbmaxx = std::floor(std::max(std::max(ax, bx), cx));
        int bbmaxy = std::ceil(std::max(std::max(ay, by), cy));

        // 如果面积为负数，背对屏幕，被裁剪
        float total_area = signed_triangle_area(ax, ay, bx, by, cx, cy);
        if (total_area < 1) return;

#pragma omp parallel for
        for (int x = bbminx; x <= bbmaxx; x++) {
            for (int y = bbminy; y <= bbmaxy; y++) {
                // 虽然可以把整个三角形直接剔除，但是我希望只是把屏幕外的像素剔除
                if (x < 0 || x >= width || y < 0 || y >= height) {
                    continue;
                }
                float alpha = signed_triangle_area(x, y, bx, by, cx, cy) / total_area;
                float beta = signed_triangle_area(x, y, cx, cy, ax, ay) / total_area;
                float gamma = signed_triangle_area(x, y, ax, ay, bx, by) / total_area;
                if (alpha < 0 || beta < 0 || gamma < 0) continue; // 说明当前像素不在三角形内部
                float barycentricZ = interpolate(triangle.screenCoords[0].z(), triangle.screenCoords[1].z(),triangle.screenCoords[2].z(), alpha, beta, gamma);
                Eigen::Vector3f barycentricGlobalCoord = interpolate(triangle.globalCoords[0].head<3>(),triangle.globalCoords[1].head<3>(),triangle.globalCoords[2].head<3>(), alpha, beta,gamma);
                float texU = interpolate(triangle.texCoords[0].x(), triangle.texCoords[1].x(),triangle.texCoords[2].x(), alpha, beta, gamma);
                float texV = interpolate(triangle.texCoords[0].y(), triangle.texCoords[1].y(),triangle.texCoords[2].y(), alpha, beta, gamma);
                TGAColor texColor = texture.getColor(texU, texV);
                Eigen::Vector3f barycentricNorm = interpolate(triangle.normal[0], triangle.normal[1],triangle.normal[2], alpha, beta, gamma);
                // 法线来自法线贴图
//            Eigen::Vector3f barycentricNorm = TGAColorToVector3f(nm.getColor(texU,texV))*2-Vector3f{1,1,1};
                // 切线法线贴图
//                Eigen::Vector3f barycentricNmTangent =TGAColorToVector3f(nm_tangent.getColor(texU, texV)) * 2 - Vector3f{1, 1, 1};
//                barycentricNmTangent = getNormalFromTangent(triangle, barycentricNmTangent, barycentricNorm);
                // 高光系数来自高光贴图
                TGAColor specKd = spec.getColor(texU, texV);
                // zbuffer中缓存的渲染物体距离小于当前渲染物体的距离时，才覆盖渲染
                if (zBuffer->at(x).at(y) < barycentricZ) {
                    zBuffer->at(x).at(y) = barycentricZ;
                    // 阴影处理
                    // 1. 找到该像素对应物体在原空间的位置
                    Eigen::Vector4f locationInShaowBuffer = mvpForShadow * (barycentricGlobalCoord.homogeneous());
                    locationInShaowBuffer.x() /= locationInShaowBuffer.w();
                    locationInShaowBuffer.y() /= locationInShaowBuffer.w();
                    locationInShaowBuffer.z() /= locationInShaowBuffer.w();
                    locationInShaowBuffer.x() = 0.5*width*(locationInShaowBuffer.x()+1);
                    locationInShaowBuffer.y() = 0.5*height*(locationInShaowBuffer.y()+1);
                    bool isShadow = false;
                    // 在阴影中
                    if (locationInShaowBuffer.z() < shadowBuffer->at(locationInShaowBuffer.x()).at(locationInShaowBuffer.y())){
                        isShadow = true;
                    }
                    // 直接使用贴图
//                framebuffer.set(x,y, texture.getColor(texU,texV));
                    // 使用phongshading光照模型
                    framebuffer.set(x,y, blinnPhongShading(texColor,barycentricGlobalCoord,barycentricNorm,specKd,isShadow));
                    // 直接使用法线贴图
//                framebuffer.set(x,y, nm.getColor(texU,texV));
                    // 使用法线贴图的法线配合phongshading
//                framebuffer.set(x,y, blinnPhongShading(texColor,barycentricGlobalCoord,barycentricNorm,specKd));
                    // 使用切线法线贴图配合phongshaing
//                    framebuffer.set(x, y,blinnPhongShading(texColor, barycentricGlobalCoord, barycentricNmTangent, specKd));
                }
            }
        }
    }

    int main() {
        Model model("./obj/diablo3_pose/diablo3_pose.obj", "./obj/diablo3_pose/diablo3_pose_diffuse.tga");
        TGAImage framebuffer(width, height, TGAImage::RGB);
        // 定义一个zBuffer,并设置全部数据为最小负数
        auto *zBuffer = new std::vector<std::vector<float>>(width, std::vector<float>(height,std::numeric_limits<float>::lowest()));
        // 用于shadow
        auto *shadowBuffer = new std::vector<std::vector<float>>(width, std::vector<float>(height,std::numeric_limits<float>::lowest()));
        // 获取法线贴图
        Texture nm("./obj/diablo3_pose/diablo3_pose_nm.tga");
        Texture spec("./obj/diablo3_pose/diablo3_pose_spec.tga");
        Texture nm_tangent("./obj/diablo3_pose/diablo3_pose_nm_tangent.tga");

        // 首先先从光源位置渲染，来赋值shadowBuffer
        model.setModelTransformation(angleX, angleY, angleZ, tx, ty, tz, sx, sy, sz);
        model.setViewTransformation(lightDir*4, eye_dir, up);
        model.setProjectionTransformation(fovY, aspectRatio, near, far);
        // 获取所有变换矩阵
        Eigen::Matrix4f mvpForShadow = model.getMVP();
        for (Triangle triangle: model.triangleList) {
            // 坐标投影
            triangle.setScreenCoords(mvpForShadow, width, height);
            // 绘制三角形
            shadow(triangle, shadowBuffer);
        }


        // 转回正常视角，进行渲染
        model.setModelTransformation(angleX, angleY, angleZ, tx, ty, tz, sx, sy, sz);
        model.setViewTransformation(eye_pos, eye_dir, up);
        model.setProjectionTransformation(fovY, aspectRatio, near, far);
        // 获取所有变换矩阵
        Eigen::Matrix4f mvp = model.getMVP();

        // 遍历obj文件中的每个三角形
        for (Triangle triangle: model.triangleList) {
            // 坐标投影
            triangle.setScreenCoords(mvp, width, height);
            // 摄像机空间点转光源空间点的矩阵
            Eigen::Matrix4f viewToLightTrans = mvpForShadow * (mvp.inverse());
            // 绘制三角形
            drawTriangle(triangle, framebuffer, zBuffer,shadowBuffer, model.texture, nm, spec, nm_tangent,mvpForShadow);
        }
        framebuffer.write_tga_file("framebuffer.tga");
        delete (zBuffer);
        delete (shadowBuffer);
        return 0;
    }

```
最终呈现效果如下，很合理哈，因为右手并未被挡住，所以还是亮的
![请添加图片描述](4e40987343c54ccd8f85bb15ed75aaf5.png)
下图通过过曝来展示哪些像素被阴影化了，还是蛮合理的～
![请添加图片描述](94e11dd82b4a40e3a13075aaf915dd91.png)
在使用普通的材质贴图下效果比较好
![请添加图片描述](6bc2b6001d9a42d1834c05bd2a824915.png)




对于出现的不合理的黑色纹路解释来自别的博客：
> 原文链接：https://blog.csdn.net/qq_42987967/article/details/125011820
上述照片脖子部位下面有很明显的z-fighting痕迹，主要是因为浮点数精度不足导致的冲突(即当前的点可能索引到附近的点了，而附近的点的shadowbuffer值比该点大造成误判)，毕竟连续的像素位置很接近，则有的像素大于shadow map，有的则小于shadow map，从而产生了离散的显示。此处采用一个解决z-fighting问题的暴力解法，即对于每一个像素投影光源的z轴值都进行一个偏移，只要在该偏移位置不存在连续像素即可展示不错的画面。

我需要将最终比较的z值加一个很小的偏移量，瞬间这些黑色条纹就消失了～

```cpp
                if (locationInShadowBuffer.z()+0.005 < shadowBuffer->at(locationInShadowBuffer.x()).at(locationInShadowBuffer.y())){
                    isShadow = true;
                }
```

![请添加图片描述](23afe9a8003a44a788f6448c182b6b68.png)
ai给出的解释：这种现象叫做自阴影
- 深度图的精度限制‌：Shadow Mapping 需要从光源视角生成深度图（Shadow Map）。由于深度图的分辨率有限，物体表面在光源视角下的离散采样可能导致实际连续的几何表面在深度图中被“阶梯化”。当从摄像机视角比较深度时，同一表面的不同片段可能被错误判定为处于阴影中。
- 浮点数精度误差‌：深度值存储为浮点数，计算时可能因精度不足导致比较错误。例如，光源视角和摄像机视角的深度计算存在微小差异，导致同一位置被误判为“低于”深度图记录的深度，从而触发阴影。
