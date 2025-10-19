+++
date = '2025-10-19T13:24:41+08:00'
draft = false
title = 'GAMES101 现代计算机图形学入门 Assignment6'
categories = ["Course/Games101","Assignment"]
tags = ["课程作业"]
+++
# 作业介绍
在上次作业中，每一次计算光线交点时，都需要与场景中所有的物体进行求交运行，这显然是不合理的，这次作业用BVH划分后进行加速
![在这里插入图片描述](https://i-blog.csdnimg.cn/direct/bace7e32a04640d08dbcb3b7ba95b6d5.png)
# 预处理
需要根据上次作业的内容以及这次作业对代码结构的调整，写入eye ray计算方法和三角形与光线求交，下面给出具体代码
`void Renderer::Render(const Scene& scene)`中，光线被定义成了一个类，填入参数
```cpp
        for (uint32_t i = 0; i < scene.width; ++i) {
            // generate primary ray direction
            float x = (2 * (i + 0.5) / (float)scene.width - 1) *
                      imageAspectRatio * scale;
            float y = (1 - 2 * (j + 0.5) / (float)scene.height) * scale;
            Vector3f dir = Vector3f(x, y, -1); // Don't forget to normalize this direction!
            dir = normalize(dir);
            Ray ray(eye_pos, dir);
            framebuffer[m++] = scene.castRay(ray, 0);
        }
```
`inline Intersection Triangle::getIntersection(Ray ray)`中，交点定义为了一个类，填入参数即可

```cpp
    // TODO find ray triangle intersection
    inter.normal = normal;
    inter.coords = ray(t_tmp);
    inter.distance = t_tmp;
    inter.happened = true;
    inter.m = m;
    inter.obj = this;
```
# Bounds3::IntersectP
这里就需要完成光线与包围盒是否相交的操作，我这里代码并没用后两个参数，AABB的好处就是平面法向量很简单，一个点和一个法向量确定一个平面，再联立光线参数方程，就可以解出来t（这个方法比较垃圾，下面有更好的方法）

```cpp
inline bool Bounds3::IntersectP(const Ray& ray, const Vector3f& invDir,
                                const std::array<int, 3>& dirIsNeg) const
{
    // invDir: ray direction(x,y,z), invDir=(1.0/x,1.0/y,1.0/z), use this because Multiply is faster that Division
    // dirIsNeg: ray direction(x,y,z), dirIsNeg=[int(x>0),int(y>0),int(z>0)], use this to simplify your logic
    // TODO test if ray bound intersects
    // xyz方向的法向量
    Vector3f nX(1,0,0);
    Vector3f nY(0,1,0);
    Vector3f nZ(0,0,1);
    // x方向两个t
    float tx1 = dotProduct(pMin-ray.origin,nX)/ dotProduct(ray.direction,nX);
    float tx2 = dotProduct(pMax-ray.origin,nX)/ dotProduct(ray.direction,nX);
    // y方向两个t
    float ty1 = dotProduct(pMin-ray.origin,nY)/ dotProduct(ray.direction,nY);
    float ty2 = dotProduct(pMax-ray.origin,nY)/ dotProduct(ray.direction,nY);
    // z方向两个t
    float tz1 = dotProduct(pMin-ray.origin,nZ)/ dotProduct(ray.direction,nZ);
    float tz2 = dotProduct(pMax-ray.origin,nZ)/ dotProduct(ray.direction,nZ);
    // 保证1<2
    if (tx1 > tx2){
        float temp = tx1;
        tx1 = tx2;
        tx2 = temp;
    }
    if (ty1 > ty2){
        float temp = ty1;
        ty1 = ty2;
        ty2 = temp;
    }
    if (tz1 > tz2){
        float temp = tz1;
        tz1 = tz2;
        tz2 = temp;
    }
    float maxEnter = std::max(tx1,std::max(ty1,tz1));
    float minExit = std::min(tx2,std::min(ty2,tz2));
    return minExit > 0 && maxEnter <= minExit;
}
```
看了别人的解答，我这个确实比较垃，直接根据x轴上光线起点与对面的距离再除以x方向上的光的速度，就可以得到t了（速度就是光线的方向向量的x分量）
>https://zhuanlan.zhihu.com/p/545253020
```cpp
inline bool Bounds3::IntersectP(const Ray& ray, const Vector3f& invDir,
                                const std::array<int, 3>& dirIsNeg) const
{
    // invDir: ray direction(x,y,z), invDir=(1.0/x,1.0/y,1.0/z), use this because Multiply is faster that Division
    // 计算进入x,y,z截面的最早和最晚时间

    float t_min_x = (pMin.x - ray.origin.x) * invDir[0];
    float t_min_y = (pMin.y - ray.origin.y) * invDir[1];
    float t_min_z = (pMin.z - ray.origin.z) * invDir[2];
    float t_max_x = (pMax.x - ray.origin.x) * invDir[0];
    float t_max_y = (pMax.y - ray.origin.y) * invDir[1];
    float t_max_z = (pMax.z - ray.origin.z) * invDir[2];
    // dirIsNeg: ray direction(x,y,z), dirIsNeg=[int(x>0),int(y>0),int(z>0)], use this to simplify your logic
    // 如果方向是负的，就交换最早和最晚时间
    if (!dirIsNeg[0])
    {
        float t = t_min_x;
        t_min_x = t_max_x;
        t_max_x = t;
    }
    if (!dirIsNeg[1])
    {
        float t = t_min_y;
        t_min_y = t_max_y;
        t_max_y = t;
    }
    if (!dirIsNeg[2])
    {
        float t = t_min_z;
        t_min_z = t_max_z;
        t_max_z = t;
    }
    // 小小取其大，大大取其小
    float t_enter = std::max(t_min_x, std::max(t_min_y, t_min_z));
    float t_exit = std::min(t_max_x, std::min(t_max_y, t_max_z));
    // TODO test if ray bound intersects
    // 检测包围盒是否存在
    if (t_exit>=0&&t_enter<t_exit)
    {
        return true;
    }
    else
    {
        return false;
    }
}
```
# BVHAccel::getIntersection
BVH树构建好后，通过树上的遍历，找到离光源最近的物体的交点，代码其实就是二叉树的遍历
```cpp
Intersection BVHAccel::getIntersection(BVHBuildNode* node, const Ray& ray) const
{
    // TODO Traverse the BVH to find intersection
    std::array<int,3> dirIsNeg;
    dirIsNeg[0] = (ray.direction[0]>0);
    dirIsNeg[1] = (ray.direction[1]>0);
    dirIsNeg[2] = (ray.direction[2]>0);
    Intersection inter;
    if (!node->bounds.IntersectP(ray, ray.direction_inv, dirIsNeg)){
        return inter;
    }
    if(node->left == nullptr && node->right == nullptr){
        return node->object->getIntersection(ray);
    }
    Intersection leftInter = getIntersection(node->left, ray);
    Intersection rightInter = getIntersection(node->right, ray);
    // 返回离光源最近的
    return leftInter.distance < rightInter.distance ? leftInter : rightInter;
}
```
最终运行代码得到如图结果
![在这里插入图片描述](https://i-blog.csdnimg.cn/direct/7685e3c05ceb40d686c8997f9b6dab10.png)
# 其他代码
## BVH树的构造
BVH在分叉中点选取时，参考的是物体包围盒质心（Centroid）在质心包围盒（Centroid Bounds）最大延伸轴上的排序位置
```cpp
// 构建BVH树
BVHBuildNode* BVHAccel::recursiveBuild(std::vector<Object*> objects)
{
    BVHBuildNode* node = new BVHBuildNode();

    // Compute bounds of all primitives in BVH node
    Bounds3 bounds;
    // 获取当前层所有物体的包围盒
    for (int i = 0; i < objects.size(); ++i)
        bounds = Union(bounds, objects[i]->getBounds());
    // 只有一个物体了，就设置叶子节点
    if (objects.size() == 1) {
        // Create leaf _BVHBuildNode_
        node->bounds = objects[0]->getBounds();
        node->object = objects[0];
        node->left = nullptr;
        node->right = nullptr;
        return node;
    }
    // 有两个物体，就设置左右两个叶子节点
    else if (objects.size() == 2) {
        node->left = recursiveBuild(std::vector{objects[0]});
        node->right = recursiveBuild(std::vector{objects[1]});

        node->bounds = Union(node->left->bounds, node->right->bounds);
        return node;
    }
    // 正常情况就找中间的物体，然后分成左右两部分，再进行递归
    else {
        Bounds3 centroidBounds;
        for (int i = 0; i < objects.size(); ++i)
            centroidBounds =
                Union(centroidBounds, objects[i]->getBounds().Centroid());
        int dim = centroidBounds.maxExtent();
        switch (dim) {
        case 0:
            std::sort(objects.begin(), objects.end(), [](auto f1, auto f2) {
                return f1->getBounds().Centroid().x <
                       f2->getBounds().Centroid().x;
            });
            break;
        case 1:
            std::sort(objects.begin(), objects.end(), [](auto f1, auto f2) {
                return f1->getBounds().Centroid().y <
                       f2->getBounds().Centroid().y;
            });
            break;
        case 2:
            std::sort(objects.begin(), objects.end(), [](auto f1, auto f2) {
                return f1->getBounds().Centroid().z <
                       f2->getBounds().Centroid().z;
            });
            break;
        }

        auto beginning = objects.begin();
        auto middling = objects.begin() + (objects.size() / 2);
        auto ending = objects.end();

        auto leftshapes = std::vector<Object*>(beginning, middling);
        auto rightshapes = std::vector<Object*>(middling, ending);

        assert(objects.size() == (leftshapes.size() + rightshapes.size()));

        node->left = recursiveBuild(leftshapes);
        node->right = recursiveBuild(rightshapes);

        node->bounds = Union(node->left->bounds, node->right->bounds);
    }

    return node;
}
```
