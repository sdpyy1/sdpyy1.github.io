+++
date = '2025-10-19T13:50:26+08:00'
draft = false
title = 'OpenGL学习笔记（Blinn Phong、伽马矫正、阴影）'
categories = ["Rendering/OpenGL"]
tags = ["API学习","OpenGL"]
image = 'e876017653874542a3d6dcca727f0a04.png'
+++
# Blinn-Phong
PhongShading不仅对真实光照有很好的近似，而且性能也很高。但是它的镜面反射会在一些情况下出现问题，特别是物体反光度很低时，会导致大片（粗糙的）高光区域。下面这张图展示了当p为1.0时地板会出现的效果：
![在这里插入图片描述](80b55f8646e1467b93cff1b9ecd6641f.png)
上图高光区域的边缘有明显的断层，出现这个问题的原因是观察向量和反射向量间的夹角不能大于90度。如果点积的结果为负数，镜面光分量会变为0.0。所以90°的地方明显的断层
下图就是这个角度大于90°的情况
![在这里插入图片描述](17f69751f1204ff794a2dca51ed20f25.png)
1977年，James F. Blinn在风氏着色模型上加以拓展，引入了Blinn-Phong着色模型。Blinn-Phong模型与风氏模型非常相似，但是它对镜面光模型的处理上有一些不同，让我们能够解决之前提到的问题。Blinn-Phong模型不再依赖于反射向量，而是采用了所谓的半程向量(Halfway Vector)，即光线与视线夹角一半方向上的一个单位向量。当半程向量与法线向量越接近时，镜面光分量就越大。
![在这里插入图片描述](398be4c82dcc40c3ac582bff364dcc7b.png)
用光线与实现夹角的半程向量与法线夹角来表示镜面光强度。当视线正好与（现在不需要的）反射向量对齐时，半程向量就会与法线完美契合。所以当观察者视线越接近于原本反射光线的方向时，镜面高光就会越强。现在，不论观察者向哪个方向看，半程向量与表面法线之间的夹角都不会超过90度（除非光源在表面以下）。

**Blinn-Phong与风氏模型唯一的区别就是，Blinn-Phong测量的是法线与半程向量之间的夹角，而风氏模型测量的是观察方向与反射向量间的夹角。**
![在这里插入图片描述](7ddd6ea90d13401ab06f552c82d0fe6a.png)
除此之外还有一个小区别，就是半程向量与表面法线的夹角通常会小于观察与反射向量的夹角。所以，如果你想获得和风氏着色类似的效果，就必须在使用Blinn-Phong模型时将镜面反光度设置更高一点。通常我们会选择风氏着色时反光度分量的2到4倍。
![在这里插入图片描述](70d5962e69104f79b5e52d6fef8ad105.png)
Blinn-Phong着色的一个附加好处是，它比Phong着色性能更高，因为我们不必计算更加复杂的反射向量了。
# Gamma矫正
## Gamma
设备输出亮度 = 输入电压的Gamma次幂
![在这里插入图片描述](bf6ee5e130a444f8a4a063e839d1a8ef.png)
第一行表示人眼感知色阶，第二行是物理的色阶。
人眼对暗色的分辨能力远超亮色，那么在有限的计算机颜色中（256个色阶），亮色和暗色均匀分布的话，那亮色部分就会精度过剩而暗色部分就会精度不足。如何解决这个问题？进行 Gamma 矫正。 

人的视觉系统对光照强度的反应并不是线性的，这意味着一个线性变化的光强，人眼感知起来却并非如此。

![在这里插入图片描述](1d50ec9cae5d4c4e8d01ed8dcf3d1709.png)
y=x的电线表示Gamma为1的理想状态，当我们输出一个值为(0.5,0.0,0.0)的颜色时，显示器输出的实际颜色为(0.218,0.0,0.0)  就是0.5的2.2次幂。如果我们把设置的颜色翻倍变为（1，0，0）实际上显示器的输出翻了4.5倍不止。

这块我感觉他解释的很乱，不如直接说人眼的gamma是1/2.2，显示器的gamma是2.2，刚好抵消了

为什么看起来"正常"：
人眼恰好需要约4.5倍的物理亮度变化才能感知"2倍亮度"
显示器的Gamma 2.2 ≈ 补偿了人眼的非线性感知
最终达到"所见即所得"的效果

因为颜色是根据显示器的输出配置的，所以线性空间中的所有中间(照明)计算在物理上都是不正确的。随着更多先进的照明算法的引入，这一点变得更加明显，如下图所示：
![在这里插入图片描述](96a5a493dfe64ebda901f9fb55096ddb.png)
如果没有适当地纠正这个显示器伽马，照明看起来是错误的，艺术家将很难获得逼真和好看的结果。解决方案正是应用伽马校正。

## Gamma矫正
Gamma校正(Gamma Correction)的思路是在最终的颜色输出到显示器之前先将Gamma的倒数作用到颜色上。就是让一个颜色变得更亮之后输出到显示器又会变暗，刚好抵消了~

我们来看另一个例子。还是那个暗红色(0.5,0.0,0.0)。在将颜色显示到显示器之前，我们先对颜色应用Gamma校正曲线。线性的颜色显示在显示器上相当于降低了2.2
次幂的亮度，所以倒数就是1/2.2次幂。Gamma校正后的暗红色就会成为(0.73,0.0,0.0)。校正后的颜色接着被发送给显示器，最终显示出来的颜色是(0.5,0.0,0.0)。你会发现使用了Gamma校正，显示器最终会显示出我们在应用中设置的那种线性的颜色。

基于gamma2.2的颜色空间叫做sRGB颜色空间。每个显示器的gamma曲线都有所不同，但是gamma2.2在大多数显示器上表现都不错。

## 实现方法
1. 使用OpenGL内建的sRGB帧缓冲。
开启即可
```cpp
glEnable(GL_FRAMEBUFFER_SRGB);
```
不开矫正效果
![在这里插入图片描述](14ab11ba1f9e43658f14890c44421222.png)
开启矫正
![在这里插入图片描述](7de60a5b6a2e42248ba6f0d61815deb4.png)
明显亮了很多，这也就是在抵消显示器让颜色变暗的情况。
使用这种方法要注意，他是输出到屏幕之前进行的矫正，如果你提前进行了矫正，那后续操作就全错了。

2. 自己在像素着色器中进行gamma校正w。

```cpp
void main()
{
    // 在线性空间做炫酷的光照效果
    [...]
    // 应用伽马矫正
    float gamma = 2.2;
    fragColor.rgb = pow(fragColor.rgb, vec3(1.0/gamma));
}
```
## sRGB纹理
显示器显示颜色时使用了gamma曲线（约2.2），这意味着：你看到的颜色 ≠ 内存中的数值
![在这里插入图片描述](6af533da32a246499c36ad61e5de058e.png)
典型错误场景：
当你在渲染管线中：
① 加载sRGB纹理（已经gamma校正）
② 进行光照计算（应该在线性空间）
③ 输出到显示器（又自动gamma校正）
→ 实际发生了两次gamma校正 → 画面过亮

也就是说sRGB纹理它已经被gamma矫正过了，渲染完成后不需要再进行gamma矫正。

所以可以先转为线性颜色计算后，再统一进行gamma矫正
为了转为线性的颜色，可以使用特定的纹理创建函数

```bash
glTexImage2D(GL_TEXTURE_2D, 0, GL_SRGB, width, height, 0, GL_RGB, GL_UNSIGNED_BYTE, image);
```
这个函数会自动把sRGB纹理转为线性空间，正常进行计算后统一进行gamma矫正并输出
## 衰减
伽马校正的另一个不同之处在于光照衰减。在真实的物理世界中，光衰减与光源距离的平方成反比。
```bash
float attenuation = 1.0 / (distance * distance);
```
然而当我们使用这个衰减公式时，衰减效果总是过于强烈
如果我们使用这个方程，而且不进行gamma校正，显示在监视器上的衰减方程实际上将变成$(1.0/distance^2)^{2.2}$,所以进行了强烈的衰减。


总而言之，gamma校正使你可以在线性空间中进行操作。因为线性空间更符合物理世界，大多数物理公式现在都可以获得较好效果，比如真实的光的衰减。你的光照越真实，使用gamma校正获得漂亮的效果就越容易。这也正是为什么当引进gamma校正时，建议只去调整光照参数的原因。
# 阴影
## shadow mapping
这个在我的tinyrenderer中实现过。这里额外提到了把摄像机角度生成的zbuffer存储在纹理中。我们管储存在纹理中的所有这些深度值，叫做深度贴图（depth map）或阴影贴图。
首先创建一个有三个正方形的场景

```bash
int main(){
    // 初始化窗口
    GLFWwindow * window = InitWindowAndFunc();
    stbi_set_flip_vertically_on_load(true);
    // 启用深度测试
    glEnable(GL_DEPTH_TEST);


    // shader
    Shader shader("./shader/base.vert", "./shader/base.frag");
    // 纹理
    unsigned int planeDiffuse = loadTexture("./assets/diffuse.png");
    unsigned int cubeDiffuse = loadTexture("./assets/container.jpg");

    // 地板
    float planeVertices[] = {
            // positions            // normals         // texcoords
            25.0f, -0.5f,  25.0f,  0.0f, 1.0f, 0.0f,  25.0f,  0.0f,
            -25.0f, -0.5f,  25.0f,  0.0f, 1.0f, 0.0f,   0.0f,  0.0f,
            -25.0f, -0.5f, -25.0f,  0.0f, 1.0f, 0.0f,   0.0f, 25.0f,

            25.0f, -0.5f,  25.0f,  0.0f, 1.0f, 0.0f,  25.0f,  0.0f,
            -25.0f, -0.5f, -25.0f,  0.0f, 1.0f, 0.0f,   0.0f, 25.0f,
            25.0f, -0.5f, -25.0f,  0.0f, 1.0f, 0.0f,  25.0f, 25.0f
    };
    // plane VAO
    unsigned int planeVBO,planeVAO;
    glGenVertexArrays(1, &planeVAO);
    glGenBuffers(1, &planeVBO);
    glBindVertexArray(planeVAO);
    glBindBuffer(GL_ARRAY_BUFFER, planeVBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(planeVertices), planeVertices, GL_STATIC_DRAW);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)(3 * sizeof(float)));
    glEnableVertexAttribArray(2);
    glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)(6 * sizeof(float)));
    glBindVertexArray(0);

    while (!glfwWindowShouldClose(window))
    {
        // 清理窗口
        glClearColor(0.05f, 0.05f, 0.05f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        glm::mat4 projection = glm::perspective(glm::radians(45.0f), (float)SCR_WIDTH / (float)SCR_HEIGHT, 0.1f, 1000.0f);
        glm::mat4 view = camera.GetViewMatrix();;

        shader.use();
        glBindVertexArray(planeVAO);
        shader.setMat4("projection", projection);
        shader.setMat4("view", view);
        shader.setMat4("model", glm::mat4(1.0));
        shader.setInt("diffuse_texture1", 0);
        glBindTexture(GL_TEXTURE_2D, planeDiffuse);
        glDrawArrays(GL_TRIANGLES, 0, 6);


        glBindTexture(GL_TEXTURE_2D, cubeDiffuse);
        // cubes
        glm::mat4 model = glm::mat4(1.0f);
        model = glm::mat4(1.0f);
        model = glm::translate(model, glm::vec3(0.0f, 1.5f, 0.0));
        model = glm::scale(model, glm::vec3(0.5f));
        shader.setMat4("model", model);
        renderCube();
        model = glm::mat4(1.0f);
        model = glm::translate(model, glm::vec3(2.0f, 0.0f, 1.0));
        model = glm::scale(model, glm::vec3(0.5f));
        shader.setMat4("model", model);
        renderCube();
        model = glm::mat4(1.0f);
        model = glm::translate(model, glm::vec3(-1.0f, 0.0f, 2.0));
        model = glm::rotate(model, glm::radians(60.0f), glm::normalize(glm::vec3(1.0, 0.0, 1.0)));
        model = glm::scale(model, glm::vec3(0.25));
        shader.setMat4("model", model);
        renderCube();







        // 事件处理
        glfwPollEvents();
        // 双缓冲
        glfwSwapBuffers(window);
        processFrameTimeForMove();
        processInput(window);

    }
    glfwTerminate();

    return 0;
};


void renderCube()
{
    // initialize (if necessary)
    if (cubeVAO == 0)
    {
        float vertices[] = {
                // back face
                -1.0f, -1.0f, -1.0f,  0.0f,  0.0f, -1.0f, 0.0f, 0.0f, // bottom-left
                1.0f,  1.0f, -1.0f,  0.0f,  0.0f, -1.0f, 1.0f, 1.0f, // top-right
                1.0f, -1.0f, -1.0f,  0.0f,  0.0f, -1.0f, 1.0f, 0.0f, // bottom-right
                1.0f,  1.0f, -1.0f,  0.0f,  0.0f, -1.0f, 1.0f, 1.0f, // top-right
                -1.0f, -1.0f, -1.0f,  0.0f,  0.0f, -1.0f, 0.0f, 0.0f, // bottom-left
                -1.0f,  1.0f, -1.0f,  0.0f,  0.0f, -1.0f, 0.0f, 1.0f, // top-left
                // front face
                -1.0f, -1.0f,  1.0f,  0.0f,  0.0f,  1.0f, 0.0f, 0.0f, // bottom-left
                1.0f, -1.0f,  1.0f,  0.0f,  0.0f,  1.0f, 1.0f, 0.0f, // bottom-right
                1.0f,  1.0f,  1.0f,  0.0f,  0.0f,  1.0f, 1.0f, 1.0f, // top-right
                1.0f,  1.0f,  1.0f,  0.0f,  0.0f,  1.0f, 1.0f, 1.0f, // top-right
                -1.0f,  1.0f,  1.0f,  0.0f,  0.0f,  1.0f, 0.0f, 1.0f, // top-left
                -1.0f, -1.0f,  1.0f,  0.0f,  0.0f,  1.0f, 0.0f, 0.0f, // bottom-left
                // left face
                -1.0f,  1.0f,  1.0f, -1.0f,  0.0f,  0.0f, 1.0f, 0.0f, // top-right
                -1.0f,  1.0f, -1.0f, -1.0f,  0.0f,  0.0f, 1.0f, 1.0f, // top-left
                -1.0f, -1.0f, -1.0f, -1.0f,  0.0f,  0.0f, 0.0f, 1.0f, // bottom-left
                -1.0f, -1.0f, -1.0f, -1.0f,  0.0f,  0.0f, 0.0f, 1.0f, // bottom-left
                -1.0f, -1.0f,  1.0f, -1.0f,  0.0f,  0.0f, 0.0f, 0.0f, // bottom-right
                -1.0f,  1.0f,  1.0f, -1.0f,  0.0f,  0.0f, 1.0f, 0.0f, // top-right
                // right face
                1.0f,  1.0f,  1.0f,  1.0f,  0.0f,  0.0f, 1.0f, 0.0f, // top-left
                1.0f, -1.0f, -1.0f,  1.0f,  0.0f,  0.0f, 0.0f, 1.0f, // bottom-right
                1.0f,  1.0f, -1.0f,  1.0f,  0.0f,  0.0f, 1.0f, 1.0f, // top-right
                1.0f, -1.0f, -1.0f,  1.0f,  0.0f,  0.0f, 0.0f, 1.0f, // bottom-right
                1.0f,  1.0f,  1.0f,  1.0f,  0.0f,  0.0f, 1.0f, 0.0f, // top-left
                1.0f, -1.0f,  1.0f,  1.0f,  0.0f,  0.0f, 0.0f, 0.0f, // bottom-left
                // bottom face
                -1.0f, -1.0f, -1.0f,  0.0f, -1.0f,  0.0f, 0.0f, 1.0f, // top-right
                1.0f, -1.0f, -1.0f,  0.0f, -1.0f,  0.0f, 1.0f, 1.0f, // top-left
                1.0f, -1.0f,  1.0f,  0.0f, -1.0f,  0.0f, 1.0f, 0.0f, // bottom-left
                1.0f, -1.0f,  1.0f,  0.0f, -1.0f,  0.0f, 1.0f, 0.0f, // bottom-left
                -1.0f, -1.0f,  1.0f,  0.0f, -1.0f,  0.0f, 0.0f, 0.0f, // bottom-right
                -1.0f, -1.0f, -1.0f,  0.0f, -1.0f,  0.0f, 0.0f, 1.0f, // top-right
                // top face
                -1.0f,  1.0f, -1.0f,  0.0f,  1.0f,  0.0f, 0.0f, 1.0f, // top-left
                1.0f,  1.0f , 1.0f,  0.0f,  1.0f,  0.0f, 1.0f, 0.0f, // bottom-right
                1.0f,  1.0f, -1.0f,  0.0f,  1.0f,  0.0f, 1.0f, 1.0f, // top-right
                1.0f,  1.0f,  1.0f,  0.0f,  1.0f,  0.0f, 1.0f, 0.0f, // bottom-right
                -1.0f,  1.0f, -1.0f,  0.0f,  1.0f,  0.0f, 0.0f, 1.0f, // top-left
                -1.0f,  1.0f,  1.0f,  0.0f,  1.0f,  0.0f, 0.0f, 0.0f  // bottom-left
        };
        glGenVertexArrays(1, &cubeVAO);
        glGenBuffers(1, &cubeVBO);
        // fill buffer
        glBindBuffer(GL_ARRAY_BUFFER, cubeVBO);
        glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
        // link vertex attributes
        glBindVertexArray(cubeVAO);
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)0);
        glEnableVertexAttribArray(1);
        glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)(3 * sizeof(float)));
        glEnableVertexAttribArray(2);
        glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)(6 * sizeof(float)));
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glBindVertexArray(0);
    }
    // render Cube
    glBindVertexArray(cubeVAO);
    glDrawArrays(GL_TRIANGLES, 0, 36);
    glBindVertexArray(0);
}

```
![在这里插入图片描述](eb3e4fd9b21c4d4aa5681c401566dd8d.png)
下来就是生成阴影贴图了

第一步需要使用自定义帧缓冲生成深度贴图

```bash
GLuint depthMapFBO;
glGenFramebuffers(1, &depthMapFBO);
```
下面生成一张空纹理图，因为我们只关心深度值，我们要把纹理格式指定为GL_DEPTH_COMPONENT
```bash
    GLuint depthMap;
    glGenTextures(1, &depthMap);
    glBindTexture(GL_TEXTURE_2D, depthMap);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_DEPTH_COMPONENT,
                 SHADOW_WIDTH, SHADOW_HEIGHT, 0, GL_DEPTH_COMPONENT, GL_FLOAT, NULL);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
```
把纹理图挂载到自定义帧缓冲中
然而，不包含颜色缓冲的帧缓冲对象是不完整的，所以我们需要显式告诉OpenGL我们不适用任何颜色数据进行渲染。我们通过将调用glDrawBuffer和glReadBuffer把读和绘制缓冲设置为GL_NONE来做这件事。
```bash
glBindFramebuffer(GL_FRAMEBUFFER, depthMapFBO);
glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, depthMap, 0);
glDrawBuffer(GL_NONE);
glReadBuffer(GL_NONE);
glBindFramebuffer(GL_FRAMEBUFFER, 0);
```
这里光源视角下设置的是平行光，所以直接用正交投影即可

```bash
GLfloat near_plane = 1.0f, far_plane = 7.5f;
glm::mat4 lightProjection = glm::ortho(-10.0f, 10.0f, -10.0f, 10.0f, near_plane, far_plane);
```
下面为了渲染是从光源角度的渲染，所以要修改视图矩阵

```bash
glm::mat4 lightView = glm::lookAt(glm::vec3(-2.0f, 4.0f, -1.0f), glm::vec3(0.0f, 0.0f, 0.0f), glm::vec3(0.0f, 1.0f, 0.0f));
```
两者结合就得到了一个光空间的变换矩阵，他能将每个世界空间坐标转变为光源视角下的坐标

用于渲染的shader非常简单

```bash
#version 330 core
layout (location = 0) in vec3 position;

uniform mat4 lightSpaceMatrix;
uniform mat4 model;

void main()
{
    gl_Position = lightSpaceMatrix * model * vec4(position, 1.0f);
}
```
片段着色器什么都不用干，但是它默认就会进行深度测试，会存储深度缓冲

```bash
#version 330 core

void main()
{
    // gl_FragDepth = gl_FragCoord.z;
}
```
在自定义缓冲下进行渲染后，就存入了深度缓存的信息
```bash
        // 切换到光源视角下
        glm::mat4 lightProjection, lightView;
        glm::mat4 lightSpaceMatrix;
        float near_plane = 1.0f, far_plane = 7.5f;
        lightProjection = glm::ortho(-10.0f, 10.0f, -10.0f, 10.0f, near_plane, far_plane);
        lightView = glm::lookAt(lightPos, glm::vec3(0.0f), glm::vec3(0.0, 1.0, 0.0));
        lightSpaceMatrix = lightProjection * lightView;
        depthShader.use();
        depthShader.setMat4("lightSpaceMatrix", lightSpaceMatrix);
        glViewport(0, 0, SHADOW_WIDTH, SHADOW_HEIGHT);
        glBindFramebuffer(GL_FRAMEBUFFER, depthMapFBO);
        glClear(GL_DEPTH_BUFFER_BIT);
        // cubes
        glm::mat4 model = glm::mat4(1.0f);
        model = glm::mat4(1.0f);
        model = glm::translate(model, glm::vec3(0.0f, 1.5f, 0.0));
        model = glm::scale(model, glm::vec3(0.5f));
        depthShader.setMat4("model", model);
        renderCube();
        model = glm::mat4(1.0f);
        model = glm::translate(model, glm::vec3(2.0f, 0.0f, 1.0));
        model = glm::scale(model, glm::vec3(0.5f));
        depthShader.setMat4("model", model);
        renderCube();
        model = glm::mat4(1.0f);
        model = glm::translate(model, glm::vec3(-1.0f, 0.0f, 2.0));
        model = glm::rotate(model, glm::radians(60.0f), glm::normalize(glm::vec3(1.0, 0.0, 1.0)));
        model = glm::scale(model, glm::vec3(0.25));
        depthShader.setMat4("model", model);
        renderCube();
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
```
![在这里插入图片描述](e876017653874542a3d6dcca727f0a04.png)
## 渲染阴影
首先在顶点着色器，我们要记录每个顶点在光源视角下的位置FragPosLightSpace 

```c
#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aNormal;
layout (location = 2) in vec2 aTexCoords;

out vec2 TexCoords;

out VS_OUT {
    vec3 FragPos;
    vec3 Normal;
    vec2 TexCoords;
    vec4 FragPosLightSpace;
} vs_out;

uniform mat4 projection;
uniform mat4 view;
uniform mat4 model;
uniform mat4 lightSpaceMatrix;

void main()
{
    // 世界坐标
    vs_out.FragPos = vec3(model * vec4(aPos, 1.0));
    vs_out.Normal = transpose(inverse(mat3(model))) * aNormal;
    vs_out.TexCoords = aTexCoords;
    // 在光源视角下的裁剪空间坐标
    vs_out.FragPosLightSpace = lightSpaceMatrix * vec4(vs_out.FragPos, 1.0);
    gl_Position = projection * view * model * vec4(aPos, 1.0);
}
```
在片段着色器中，通过是否在阴影中来修改是否需要高光和漫反射光，如果在阴影中，则设置为0

```bash
#version 330 core
out vec4 FragColor;

in VS_OUT {
    vec3 FragPos;
    vec3 Normal;
    vec2 TexCoords;
    vec4 FragPosLightSpace;
} fs_in;

uniform sampler2D diffuseTexture;
uniform sampler2D shadowMap;

uniform vec3 lightPos;
uniform vec3 viewPos;

float ShadowCalculation(vec4 fragPosLightSpace)
{
    [...]
}

void main()
{           
    vec3 color = texture(diffuseTexture, fs_in.TexCoords).rgb;
    vec3 normal = normalize(fs_in.Normal);
    vec3 lightColor = vec3(1.0);
    // Ambient
    vec3 ambient = 0.15 * color;
    // Diffuse
    vec3 lightDir = normalize(lightPos - fs_in.FragPos);
    float diff = max(dot(lightDir, normal), 0.0);
    vec3 diffuse = diff * lightColor;
    // Specular
    vec3 viewDir = normalize(viewPos - fs_in.FragPos);
    vec3 reflectDir = reflect(-lightDir, normal);
    float spec = 0.0;
    vec3 halfwayDir = normalize(lightDir + viewDir);  
    spec = pow(max(dot(normal, halfwayDir), 0.0), 64.0);
    vec3 specular = spec * lightColor;    
    // 计算阴影
    float shadow = ShadowCalculation(fs_in.FragPosLightSpace);       
    vec3 lighting = (ambient + (1.0 - shadow) * (diffuse + specular)) * color;    

    FragColor = vec4(lighting, 1.0f);
}
```
计算方法如下
首先根据像素位置对应记录的光源坐标下的NDC坐标（注意要手动进行透视除法,切换到[0,1]范围。在深度贴图中用NDC坐标当作UV坐标去采样，得到该点最近的深度值，然后与该点的深度值进行比较
```bash
float ShadowCalculation(vec4 fragPosLightSpace)
{
    // 手动进行透视除法，转为NDC坐标
    vec3 projCoords = fragPosLightSpace.xyz / fragPosLightSpace.w;
    // 变换到[0,1]的范围
    projCoords = projCoords * 0.5 + 0.5;
    // 取得最近点的深度(使用[0,1]范围下的fragPosLight当坐标)
    float closestDepth = texture(shadowMap, projCoords.xy).r; 
    // 取得当前片段在光源视角下的深度
    float currentDepth = projCoords.z;
    // 检查当前片段是否在阴影中  大离的近
    float shadow = currentDepth > closestDepth  ? 1.0 : 0.0;
    return shadow;
}
```
最终渲染出来为
![在这里插入图片描述](ec23146a7988471eac1562ab0f3a55ea.png)
## 改进阴影贴图
目前的渲染是有问题的
![在这里插入图片描述](9b67b4e4af314ddcbb4731c8bc394490.png)
地板四边形渲染出一大块交替黑线。这种阴影贴图的不真实感叫做阴影失真(Shadow Acne)，下图解释了成因：

![在这里插入图片描述](f30bde087beb4cdd8f3eccbe48e731ae.png)
阴影贴图受限于分辨率，在离光源很远的情况下，多个片段在深度贴图的同一个位置进行了采样。
我们可以用一个叫做阴影偏移（shadow bias）的技巧来解决这个问题，我们简单的对表面的深度（或深度贴图）应用一个偏移量，这样片段就不会被错误地认为在表面之下了。
![在这里插入图片描述](4c0f83e599714eb480a6cb62aee55f36.png)

```bash
    float bias = 0.005;
    float shadow = currentDepth - bias > closestDepth  ? 1.0 : 0.0;
```
还有更好的方法是自适应的偏移量
```bash
float bias = max(0.05 * (1.0 - dot(normal, lightDir)), 0.005);
```
但是当偏移量过大时，也会出现悬浮效果。这个阴影失真叫做悬浮(Peter Panning)，因为物体看起来轻轻悬浮在表面之上
![在这里插入图片描述](b58afd2b109f4069968b3a00e8976841.png)
下边这幅是正常的，很明显能感觉到上图的错误
![在这里插入图片描述](17998b82d1fa42cfabb958e8eac56982.png)


我们可以使用一个叫技巧解决大部分的Peter panning问题：当渲染深度贴图时候使用正面剔除（front face culling）你也许记得在面剔除教程中OpenGL默认是背面剔除。我们要告诉OpenGL我们要剔除正面。

因为我们只需要深度贴图的深度值，对于实体物体无论我们用它们的正面还是背面都没问题。使用背面深度不会有错误，因为阴影在物体内部有错误我们也看不见。

```bash
glCullFace(GL_FRONT);
RenderSceneToDepthMap();
glCullFace(GL_BACK); // 不要忘记设回原先的culling face
```
另外还有一个问题是光锥不可见的区域一律被任务处于阴影中了
![在这里插入图片描述](9eaddf39f05c4518b56315e998a87144.png)

也就是说有些纹理坐标超出了深度贴图的范围，我们可以修改贴图的环绕参数，将超出部分的深度值全部设置为1，这样，贴图外永远都不在阴影中

```bash
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);
GLfloat borderColor[] = { 1.0, 1.0, 1.0, 1.0 };
glTexParameterfv(GL_TEXTURE_2D, GL_TEXTURE_BORDER_COLOR, borderColor);
```
但这样处理只解决了一块阴影

![在这里插入图片描述](5a705f04981c468f9c299d0b080855e3.png)

仍有一部分是黑暗区域。那里的坐标超出了光的正交视锥的远平面。你可以看到这片黑色区域总是出现在光源视锥的极远处。

当一个点比光的远平面还要远时，它的投影坐标的z坐标大于1.0。这种情况下，GL_CLAMP_TO_BORDER环绕方式不起作用，因为我们把坐标的z元素和深度贴图的值进行了对比；它总是为大于1.0的z返回true。

直接强制让z值大于1的位置（在远平面外的点）设置不在阴影中
![在这里插入图片描述](c9c42b30315549b2a66f3386bb802aca.png)
## PCF
目前的阴影表面仍有锯齿
![在这里插入图片描述](a03bd6a415e343c894a7ffa0bf416d51.png)

因为深度贴图有一个固定的分辨率，多个片段对应于一个纹理像素。结果就是多个片段会从深度贴图的同一个深度值进行采样，这几个片段便得到的是同一个阴影，这就会产生锯齿边。

你可以通过增加深度贴图的分辨率的方式来降低锯齿块，也可以尝试尽可能的让光的视锥接近场景。

另一个（并不完整的）解决方案叫做PCF（percentage-closer filtering），这是一种多个不同过滤方式的组合，它产生柔和阴影，使它们出现更少的锯齿块和硬边。核心思想是从深度贴图中多次采样，每一次采样的纹理坐标都稍有不同。每个独立的样本可能在也可能不再阴影中。所有的次生结果接着结合在一起，进行平均化，我们就得到了柔和阴影。

```bash
float ShadowCalculation(vec4 fragPosLightSpace)
{
    // perform perspective divide
    vec3 projCoords = fragPosLightSpace.xyz / fragPosLightSpace.w;
    // Transform to [0,1] range
    projCoords = projCoords * 0.5 + 0.5;
    // Get closest depth value from light's perspective (using [0,1] range fragPosLight as coords)
    float closestDepth = texture(shadowMap, projCoords.xy).r;
    // Get depth of current fragment from light's perspective
    float currentDepth = projCoords.z;
    // Calculate bias (based on depth map resolution and slope)
    vec3 normal = normalize(fs_in.Normal);
    vec3 lightDir = normalize(lightPos - fs_in.FragPos);
    float bias = max(0.05 * (1.0 - dot(normal, lightDir)), 0.005);
    // Check whether current frag pos is in shadow
    // float shadow = currentDepth - bias > closestDepth  ? 1.0 : 0.0;
    // PCF
    float shadow = 0.0;
    vec2 texelSize = 1.0 / textureSize(shadowMap, 0);
    for(int x = -1; x <= 1; ++x)
    {
        for(int y = -1; y <= 1; ++y)
        {
            float pcfDepth = texture(shadowMap, projCoords.xy + vec2(x, y) * texelSize).r;
            shadow += currentDepth - bias > pcfDepth  ? 1.0 : 0.0;
        }
    }
    shadow /= 9.0;

    // Keep the shadow at 0.0 when outside the far_plane region of the light's frustum.
    if(projCoords.z > 1.0)
    shadow = 0.0;

    return shadow;
}
```
![在这里插入图片描述](7e6a7ecf9ce3475084c2aa30ba876d8a.png)
正交 vs 投影
在渲染深度贴图的时候，正交(Orthographic)和投影(Projection)矩阵之间有所不同。正交投影矩阵并不会将场景用透视图进行变形，所有视线/光线都是平行的，这使它对于定向光来说是个很好的投影矩阵。然而透视投影矩阵，会将所有顶点根据透视关系进行变形，结果因此而不同。下图展示了两种投影方式所产生的不同阴影区域：
![在这里插入图片描述](29e896e7050e488b89c89191c59d0711.png)
如果使用的是透视投影，在使用深度贴图时，需要先将深度转为线性深度

```bash
float LinearizeDepth(float depth)
{
    float z = depth * 2.0 - 1.0; // Back to NDC 
    return (2.0 * near_plane * far_plane) / (far_plane + near_plane - z * (far_plane - near_plane));
}
```

后续对于阴影的优化放在Games202课程作业一中进行~

另外第二章点阴影就是在一个向四面八方发射光的点光源的阴影渲染，实现就是参考天空盒类似的6个面的shadowmap来实现