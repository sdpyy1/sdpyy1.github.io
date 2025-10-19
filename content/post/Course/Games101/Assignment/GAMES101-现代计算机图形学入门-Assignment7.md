+++
date = '2025-10-19T13:32:46+08:00'
draft = false
title = 'GAMES101 现代计算机图形学入门 Assignment7'
categories = ["Course/Games101","Assignment"]
tags = ["课程作业","Games101"]
+++
# 作业介绍
![在这里插入图片描述](ef43e9abf6c7485d9bf566a59479ed6f.png)
本次作业只需要实现渲染方程，首先需要理解渲染公式
![请添加图片描述](4360789f62274e29b3aabdfd7a0a1f6a.png)
其次需要知道利用蒙特卡洛公式求积分的方法
![在这里插入图片描述](dfd9a34a85914eafbc58030d1c602839.png)
求渲染公式的积分部分需要在半球面采样，为了提高准确度，换元为在光源面积上采样
![在这里插入图片描述](7918f9a7ec6b42919cb6a28ed9f7765e.png)

在作业中也给出了伪代码
![在这里插入图片描述](e25213988c684054883bfe579bb423e0.png)

# 代码实现
>代码参考https://zhuanlan.zhihu.com/p/606074595

注释写的很清楚了

```cpp
Vector3f Scene::castRay(const Ray& ray, int depth) const
{
    Vector3f hitColor = this->backgroundColor;
    // 获取光线ray与场景中物体的交点
    Intersection shade_point_inter = Scene::intersect(ray);
    // 如果有交点
    if (shade_point_inter.happened){
        // 交点坐标
        Vector3f p = shade_point_inter.coords;
        // 从摄像机到点P的方向
        Vector3f wo = ray.direction;
        // p点的法线
        Vector3f N = shade_point_inter.normal;
        Vector3f L_dir(0), L_indir(0);

        //光照的采样 获取位置和概率密度函数
        Intersection light_point_inter;
        float pdf_light;
        sampleLight(light_point_inter, pdf_light);
        //Get x,ws,NN,emit from inter
        // 光照采样点的坐标
        Vector3f x = light_point_inter.coords;
        // 从点P到光照采样点的方向
        Vector3f ws = normalize(x-p);
        // 光照采样点的法线
        Vector3f NN = light_point_inter.normal;
        // ？
        Vector3f emit = light_point_inter.emit;
        // 点p到光照采样点的距离
        float distance_pTox = (x - p).norm();
        //创建从p->采样点的光照
        Vector3f p_deviation = (dotProduct(ray.direction, N) < 0) ?
                               p + N * EPSILON :
                               p - N * EPSILON ;

        Ray ray_pTox(p_deviation, ws);
        //判断是否中间有别的物体挡住了
        Intersection blocked_point_inter = Scene::intersect(ray_pTox);
        // 如果没有被挡住就算一次L
        if (abs(distance_pTox - blocked_point_inter.distance < 0.01 ))
        {
            L_dir = emit * shade_point_inter.m->eval(wo, ws, N) * dotProduct(ws, N) * dotProduct(-ws, NN) / (distance_pTox * distance_pTox * pdf_light);
        }
        // 俄罗斯轮盘赌来停止递归
        float ksi = get_random_float();
        if (ksi < RussianRoulette)
        {
            // 采样获得wi方向来进一步递归
            Vector3f wi = normalize(shade_point_inter.m->sample(wo, N));
            // 创建对应的光线
            Ray ray_pTowi(p_deviation, wi);
            //光线碰到了不发光的物体，需要递归处理
            Intersection bounce_point_inter = Scene::intersect(ray_pTowi);
            // 如果光线碰到了物体就需要递归处理了
            if (bounce_point_inter.happened && !bounce_point_inter.m->hasEmission())
            {
                float pdf = shade_point_inter.m->pdf(wo, wi, N);
                if(pdf> EPSILON)
                    L_indir = castRay(ray_pTowi, depth + 1) * shade_point_inter.m->eval(wo, wi, N) * dotProduct(wi, N) / (pdf *RussianRoulette);
            }
        }
        // 结合直接光照和间接光照获得该点的颜色值
        hitColor = shade_point_inter.m->getEmission() + L_dir + L_indir;
    }
    return hitColor;
}
```
