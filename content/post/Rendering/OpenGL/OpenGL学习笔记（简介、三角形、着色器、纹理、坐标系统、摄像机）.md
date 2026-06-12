+++date = '2025-10-19T13:48:28+08:00'
draft = false
title = 'OpenGL学习笔记（简介、三角形、着色器、纹理、坐标系统、摄像机）'
categories = ["图形API/OpenGL"]
tags = ["API学习","OpenGL"]
image = '3779db9d1ff84e66b075f0dd6d1edb90.png'
+++
# 简介
在学习完Games101，以及手撸一个软光栅之后，来学习一下OpenGL~
![请添加图片描述](f9253537c2ef440cabb73becf31daebf.png)
OpenGL常被视作提供图形操作函数的API，但其本质是由Khronos制定的规范（Specification），仅严格定义函数行为及输出标准，具体实现（如底层优化、硬件适配）由开发者（如显卡厂商）自行完成。
## 核心模式与立即渲染模式
OpenGL早期采用立即渲染模式（固定管线），简化了图形绘制但效率低且控制受限。随着版本迭代，OpenGL 3.2起废弃此模式，转向‌核心模式‌，强制使用现代函数并移除旧特性。核心模式虽需深入理解图形编程（如手动管理渲染流程），但显著提升了灵活性与性能，同时迫使开发者掌握底层细节，牺牲易用性换取更高效的硬件控制能力。
## 状态机
**OpenGL自身是一个巨大的状态机(State Machine)**：一系列的变量描述OpenGL此刻应当如何运行。OpenGL的状态通常被称为OpenGL上下文(Context)。我们通常使用如下途径去更改OpenGL状态：设置选项，操作缓冲。最后，我们使用当前OpenGL上下文来渲染。下面是一个例子

```cpp
    // 绑定opengl当前状态的vao
    GL_CALL(glBindVertexArray(vao));
    // 指定下一次属性设置在vao中的位置
    GL_CALL(glEnableVertexAttribArray(posAttrib));
```
当使用OpenGL的时候，我们会遇到一些状态设置函数(State-changing Function)，这类函数将会改变上下文。以及状态使用函数(State-using Function)，这类函数会根据当前OpenGL的状态执行一些操作。只要你记住OpenGL本质上是个大状态机，就能更容易理解它的大部分特性。

## 对象
在OpenGL中一个对象是指一些选项的集合，它代表OpenGL状态的一个子集。这块的解释还看不明白，等学习后再补充

## GLFW和GLAD
GLFW是一个专门针对OpenGL的C语言库，它提供了一些渲染物体所需的最低限度的接口。它允许用户创建OpenGL上下文、定义窗口参数以及处理用户输入，对我们来说这就够了。如果没有 GLFW 这样的库，**开发者需要自己针对不同的操作系统编写复杂的代码来创建窗口和处理用户输入**，这将大大增加开发的难度和工作量。使用 GLFW 可以简化这些底层的操作，让开发者能够更加专注于 OpenGL 的图形渲染部分，提高开发效率

由于 OpenGL 驱动版本众多，不同的显卡厂商和操作系统对 OpenGL 函数的实现可能会有所不同，而且 OpenGL 中的大多数函数的位置在编译时无法确定，需要在运行时查询。GLAD 的主要作用就是管理 OpenGL 的函数指针，它会根据当前的系统和显卡环境，动态地加载正确的 OpenGL 函数地址，并将这些函数地址保存在函数指针中，以便开发者在程序运行时能够正确地调用 OpenGL 函数。这样可以确保程序在不同的硬件和操作系统环境下都能正常运行，提高了程序的兼容性。

至于GLFW和glad的安装这里不会提及
# Hello OpenGL
⚠️两个头文件的导入顺序。GLAD的头文件包含了正确的OpenGL头文件（例如GL/gl.h），所以需要在其它依赖于OpenGL的头文件之前包含GLAD。
```cpp
#include <glad/glad.h>
#include <GLFW/glfw3.h>
int main()
{
    glfwInit();
    // 对GLFW的配置 版本号、次版本号、选择核心模式
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    return 0;
}
```
进一步利用GLFW进行窗口创建，并将OpenGL上下文设置到这个窗口上

```cpp
GLFWwindow* window = glfwCreateWindow(800, 600, "LearnOpenGL", NULL, NULL);
    if (window == nullptr){
        std::cout << "Failed to create GLFW window" << std::endl;
        glfwTerminate();
        return -1;
    }
    glfwMakeContextCurrent(window);
```
下一步就是用glad加载函数指针

```cpp
if (!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress))
    {
        std::cout << "Failed to initialize GLAD" << std::endl;
        return -1;
    }
```
紧接着需要提供渲染的窗口大小，这个就是进行视口变换时的依据

```cpp
// 前两个参数控制窗口左下角的位置。第三个和第四个参数控制渲染窗口的宽度和高度（像素）
glViewport(0, 0, 800, 600);
```
下面介绍回调函数

```cpp

void framebuffer_size_callback(GLFWwindow* window, int width, int height){
	// 当窗口大小变化时，重新调整视口
    glViewport(0, 0, width, height);
}
---
// 绑定窗口变化事件到framebuffer_size_callback这个函数
glfwSetFramebufferSizeCallback(window, framebuffer_size_callback);
```
最终就是渲染循环了，毕竟不只是渲染一幅图片

```cpp
while(!glfwWindowShouldClose(window))
{
    // 双缓冲
    glfwSwapBuffers(window);
    // 事件处理
    glfwPollEvents();
}
```
**双缓冲(Double Buffer)**
应用程序使用单缓冲绘图时可能会存在图像闪烁的问题。 这是因为生成的图像不是一下子被绘制出来的，而是按照从左到右，由上而下逐像素地绘制而成的。最终图像不是在瞬间显示给用户，而是通过一步一步生成的，这会导致渲染的结果很不真实。为了规避这些问题，我们应用双缓冲渲染窗口应用程序。前缓冲保存着最终输出的图像，它会在屏幕上显示；而所有的的渲染指令都会在后缓冲上绘制。当所有的渲染指令执行完毕后，我们交换(Swap)前缓冲和后缓冲，这样图像就立即呈显出来，之前提到的不真实感就消除了。

最后一件事，窗口关闭的处理

```cpp
glfwTerminate();
return 0;
```
渲染操作都是写在while循环中的，现在简单写一下清屏操作，并通过glClearColor设置清屏后显示的颜色
```cpp
glClearColor(0.2f, 0.3f, 0.3f, 1.0f);
glClear(GL_COLOR_BUFFER_BIT);
```
当前的完整代码如下

```cpp
在这里插入代码片//
// Created by 刘卓昊 on 2025/4/3.
//
#include <glad/glad.h>
#include <GLFW/glfw3.h>
#include <iostream>
void framebuffer_size_callback(GLFWwindow* window, int width, int height){
    std::cout << "Failed to create GLFW window" << std::endl;

    glViewport(0, 0, width, height);
}

int main()
{
    glfwInit();
    // 对GLFW的配置 版本号、次版本号、选择核心模式
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    GLFWwindow* window = glfwCreateWindow(800, 600, "LearnOpenGL", NULL, NULL);
    if (window == nullptr){
        std::cout << "Failed to create GLFW window" << std::endl;
        glfwTerminate();
        return -1;
    }
    glfwMakeContextCurrent(window);
    if (!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress)){
        std::cout << "Failed to initialize GLAD" << std::endl;
        return -1;
    }
    // 前两个参数控制窗口左下角的位置。第三个和第四个参数控制渲染窗口的宽度和高度（像素）
    glViewport(0, 0, 800, 600);
    glfwSetFramebufferSizeCallback(window, framebuffer_size_callback);
    while(!glfwWindowShouldClose(window))
    {
        // 双缓冲
        glfwSwapBuffers(window);
        // 事件处理
        glfwPollEvents();
        glClearColor(0.2f, 0.3f, 0.3f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
    }
    glfwTerminate();
    return 0;

}
```
运行结果如下图
![请添加图片描述](9da5745e7ea240c19847acfe15e4defe.png)
# Triangle 三角形
首先了解三个概念
顶点数组对象：Vertex Array Object，VAO
顶点缓冲对象：Vertex Buffer Object，VBO
元素缓冲对象：Element Buffer Object，EBO 或 索引缓冲对象 Index Buffer Object，IBO
## 顶点缓冲对象 VBO
OpenGL不是简单地把所有的3D坐标变换为屏幕上的2D像素；OpenGL仅当3D坐标在3个轴（x、y和z）上-1.0到1.0的范围内时才处理它。所有在这个范围内的坐标叫做标准化设备坐标(Normalized Device Coordinates)，此范围内的坐标最终显示在屏幕上（在这个范围以外的坐标则不会显示）。
这里为了简单，没有设置深度

```cpp
float vertices[] = {
    -0.5f, -0.5f, 0.0f,
     0.5f, -0.5f, 0.0f,
     0.0f,  0.5f, 0.0f
};
我们通过顶点缓冲对象(Vertex Buffer Objects, VBO)管理这个内存，它会在GPU内存（通常被称为显存）中储存大量顶点。使用这些缓冲对象的好处是我们可以一次性的发送一大批数据到显卡上，而不是每个顶点发送一次。从CPU把数据发送到显卡相对较慢，所以只要可能我们都要尝试尽量一次性发送尽可能多的数据。当数据发送至显卡的内存中后，顶点着色器几乎能立即访问顶点，这是个非常快的过程。
顶点缓冲对象是第一个接触的OpenGL对象，需要有一个独一无二的ID，通过glGenBuffers函数来生成一个带有缓冲ID的VBO对象。

```cpp
	// 就是unsigned int
    GLuint VBO;
    // 此函数会为VBO分配一个未使用的ID（例如 1, 2 等）但此时‌并未实际创建缓冲对象‌，仅预留了标识符
    glGenBuffers(1, &VBO);
    // 绑定到OpenGL上下文中，此时GPU才会真正分配内存
    glBindBuffer(GL_ARRAY_BUFFER, VBO);
```
从此刻起，我们对GL_ARRAY_BUFFER上的操作都属于对当前绑定的VBO进行操作。
 glBufferData是一个专门用来把用户定义的数据复制到当前绑定缓冲的函数。第一个参数是目标缓冲的类型：顶点缓冲对象当前绑定到GL_ARRAY_BUFFER目标上。第二个参数指定传输数据的大小(以字节为单位)；用一个简单的sizeof计算出顶点数据大小就行。第三个参数是我们希望发送的实际数据。至于第四个参数有三种情况：
- GL_STATIC_DRAW ：数据不会或几乎不会改变。
- GL_DYNAMIC_DRAW：数据会被改变很多。
- GL_STREAM_DRAW ：数据每次绘制时都会改变。

```cpp
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices),vertices,GL_STATIC_DRAW);
```
现在我们已经把顶点数据储存在显卡的内存中，用VBO这个顶点缓冲对象管理。下面我们会创建一个顶点着色器和片段着色器来真正处理这些数据。现在我们开始着手创建它们吧。

先简单来进行硬编码写一个简单的顶点着色器

```cpp
    const char * vertexShaderSource = "#version 330 core\n"
                                      "layout (location=0) in vec3 aPos;\n"
                                      "void main()\n"
                                      "{\n"
                                      "     gl_Position = vec4(aPos.x,aPos.y,aPos.z,1.0);\n"
                                      "}\0";
```
为了运行glsl，需要在运行时动态编译源代码。需要先创建着色器对象，并编译

```cpp
        // 创建着色器
    GLuint vertexShader = glCreateShader(GL_VERTEX_SHADER);
    // 源码添加在shader上
    glShaderSource(vertexShader,1,&vertexShaderSource, nullptr);
    // 编译源码
    glCompileShader(vertexShader);
```
如果想检查运行编译是否正确，以及报错信息也是比较麻烦

```cpp
    int  success;
    char infoLog[512];
    glGetShaderiv(vertexShader, GL_COMPILE_STATUS, &success);
    if(!success)
    {
        glGetShaderInfoLog(vertexShader, 512, nullptr, infoLog);
        std::cout << "ERROR::SHADER::VERTEX::COMPILATION_FAILED\n" << infoLog << std::endl;
    }
```

片段着色器操作类似，主要处理光栅化后每个像素的着色

```cpp
    const char * fragmentShaderSource = "#version 330 core\n"
                                        "out vec4 FragColor;\n"
                                        "\n"
                                        "void main()\n"
                                        "{\n"
                                        "    FragColor = vec4(1.0f, 0.5f, 0.2f, 1.0f);\n"
                                        "} ";
    unsigned int fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragmentShader, 1, &fragmentShaderSource, NULL);
    glCompileShader(fragmentShader);
```

最终还需要链接成一个程序

```cpp
    unsigned int shaderProgram;
    shaderProgram = glCreateProgram();
    glAttachShader(shaderProgram, vertexShader);
    glAttachShader(shaderProgram, fragmentShader);
    glLinkProgram(shaderProgram);
```

检查报错信息

```cpp
    glGetProgramiv(shaderProgram, GL_LINK_STATUS, &success);
    if(!success) {
        glGetProgramInfoLog(shaderProgram, 512, nullptr, infoLog);
    }
```
最后还需要use这个程序

```cpp
glUseProgram(shaderProgram);
```
## 顶点数组对象 VAO
顶点着色器允许我们指定任何以顶点属性为形式的输入。这使其具有很强的灵活性的同时，它还的确意味着我们必须手动指定输入数据的哪一个部分对应顶点着色器的哪一个顶点属性。所以，我们必须在渲染前指定OpenGL该如何解释顶点数据。顶点数据的解析方式如下
![在这里插入图片描述](a8f469ff544a410ebb439bf4007e898b.png)
我们需要告诉OpenGL如何解析顶点数据，比如紧密的字节序列的一段代表一个顶点的数据，但数据中可能不止顶点的位置，可能还有顶点的颜色之类的，需要告诉OpenGL一个顶点数据有多大，顶点位置的偏移量是多少（因为不一定一开始就是位置信息）

```cpp
glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
glEnableVertexAttribArray(0);
```
上边代码中的0就是之前写顶点着色器代码中的`(location=0)`
如果把这些状态配置存储在一个对象中，通过绑定他来启动该状态，这就是VAO。
顶点数组对象(Vertex Array Object, VAO)可以像顶点缓冲对象那样被绑定。VAO中存储的内容如下
![在这里插入图片描述](9700b335725f4e23888e3e6b77e2ea15.png)
VAO创建过程与VBO类似

```cpp
    GLuint VAO;
    glGenVertexArrays(1, &VAO);
    glBindVertexArray(VAO);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);
```
当创建并绑定好VAO和VBO后就可以进行渲染了
⚠️ 渲染函数要写到While循环里

```cpp
		// while中
        glDrawArrays(GL_TRIANGLES, 0, 3);
```

## 元素缓冲对象 EBO/ 索引缓冲对象 IEO
其实就是保存顶点的顺序，比如如果VAO中是这样的数据

```cpp
float vertices[] = {
    // 第一个三角形
    0.5f, 0.5f, 0.0f,   // 右上角
    0.5f, -0.5f, 0.0f,  // 右下角
    -0.5f, 0.5f, 0.0f,  // 左上角
    // 第二个三角形
    0.5f, -0.5f, 0.0f,  // 右下角
    -0.5f, -0.5f, 0.0f, // 左下角
    -0.5f, 0.5f, 0.0f   // 左上角
};
```
我们指定了右下角和左上角两次！一个矩形只有4个而不是6个顶点，这样就产生50%的额外开销。EBO是一个缓冲区，就像一个顶点缓冲区对象一样，它存储 OpenGL 用来决定要绘制哪些顶点的索引。

```cpp
float vertices[] = {
    0.5f, 0.5f, 0.0f,   // 右上角
    0.5f, -0.5f, 0.0f,  // 右下角
    -0.5f, -0.5f, 0.0f, // 左下角
    -0.5f, 0.5f, 0.0f   // 左上角
};

unsigned int indices[] = {
    // 注意索引从0开始! 
    // 此例的索引(0,1,2,3)就是顶点数组vertices的下标，
    // 这样可以由下标代表顶点组合成矩形

    0, 1, 3, // 第一个三角形
    1, 2, 3  // 第二个三角形
};
```
EBO创建和绑定方法与VBO基本一致

```cpp
    GLuint EBO;
    glGenBuffers(1, &EBO);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, EBO);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);
```
glDrawElements绘制的时候就不是直接绘制了，而是使用EBO获取索引来绘制

```cpp
        glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
```
**另外可以使用VAO中的数据来保存EBO。在绑定VAO时，绑定的最后一个元素缓冲区对象存储为VAO的元素缓冲区对象。然后，绑定到VAO也会自动绑定该EBO。**这步操作是自动进行的，但需要先绑定VAO。
如果想绘制线框模型可以用以下代码来决定是线框模型还是填充模型
```cpp
    glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
	glPolygonMode(GL_FRONT_AND_BACK, GL_FILL)
```
![在这里插入图片描述](11134fc29a754f1389844b984de9c27d.png)
# 着色器
在Hello Triangle教程中提到，着色器(Shader)是运行在GPU上的小程序。这些小程序为图形渲染管线的某个特定部分而运行。从基本意义上来说，着色器只是一种把输入转化为输出的程序。着色器也是一种非常独立的程序，因为它们之间不能相互通信；**它们之间唯一的沟通只有通过输入和输出**。
## GLSL
着色器是使用一种叫GLSL的类C语言写成的。GLSL是为图形计算量身定制的，它包含一些针对向量和矩阵操作的有用特性。
着色器的开头总是要声明版本，接着是输入和输出变量、uniform和main函数。每个着色器的入口点都是main函数，在这个函数中我们处理所有的输入变量，并将结果输出到输出变量中。
一个典型的着色器结构如下

```c
#version version_number
in type in_variable_name;
in type in_variable_name;
out type out_variable_name;
uniform type uniform_name;

void main()
{
  // 处理输入并进行一些图形操作
  ...
  // 输出处理过的结果到输出变量
  out_variable_name = weird_stuff_we_processed;
}
```
当我们特别谈论到顶点着色器的时候，每个输入变量也叫顶点属性(Vertex Attribute)，我们能声明的顶点属性是有上限的，它一般由硬件来决定。OpenGL确保至少有16个包含4分量的顶点属性可用

## 数据类型
基础数据类型有：int、float、double、uint、bool
另外还有向量
![在这里插入图片描述](20c34cd41a85478abebbfc402b9999ba.png)
向量可以有一些有趣的重组操作

```c
vec2 someVec;
vec4 differentVec = someVec.xyxx;
vec3 anotherVec = differentVec.zyw;
vec4 otherVec = someVec.xxxx + anotherVec.yxzy;
```
## 输入输出
GLSL定义了`in`和`out`关键字专门来实现这个目的。每个着色器使用这两个关键字设定输入和输出，只要一个输出变量与下一个着色器阶段的输入匹配，它就会传递下去。在顶点着色器和片段着色器有一些不同。
顶点着色器的输入特殊在，它从顶点数据中直接接收输入。为了定义顶点数据该如何管理，我们使用location这一元数据指定输入变量，这样我们才可以在CPU上配置顶点属性。例如`layout (location = 0)`，除此之外也可以这样设置

```cpp
	// 根据glsl的参数输入顺序来获取vao中数据定义的顺序
    GLint posAttrib = glGetAttribLocation(program, "aPos");
    GLint colorAttrib = glGetAttribLocation(program, "aColor");
    GLint  uvAttrib = glGetAttribLocation(program, "aUV");
```
这样设置的情况下，glsl就不要写location了

```cpp
    const char* vertexShaderSource = "#version 330 core\n"
                                     // "layout (location = 0) in vec3 aPos;\n"   // 输入位置1的3维坐标
                                     "in vec3 aPos;\n"   // 输入位置1的3维坐标(不指定位置版本，就按从头开始)
                                     // "layout (location = 1) in vec3 aColor;\n" // 输入位置2的颜色数据
//                                     "in vec3 aColor;\n" // 输入位置2的颜色数据(不指定位置版本，就是从上一个变量输入完成之后的3个数据)‘
                                     "in vec2 aUV;\n"
```

在片段着色器中，需要一个vec4颜色的输出变量，因为他的目的就是生成最终的颜色。如果你在片段着色器没有定义输出颜色，OpenGL会把你的物体渲染为黑色（或白色）。所以，如果我们打算从一个着色器向另一个着色器发送数据，我们必须在发送方着色器中声明一个输出，在接收方着色器中声明一个类似的输入。**当类型和名字都一样的时候，OpenGL就会把两个变量链接到一起，它们之间就能发送数据了（这是在链接程序对象时完成的）**，下面是一个例子，vertexColor变量就是从顶点着色器跑到片段着色器的

```cpp
// 顶点
#version 330 core
layout (location = 0) in vec3 aPos; // 位置变量的属性位置值为0

out vec4 vertexColor; // 为片段着色器指定一个颜色输出

void main()
{
    gl_Position = vec4(aPos, 1.0); // 注意我们如何把一个vec3作为vec4的构造器的参数
    vertexColor = vec4(0.5, 0.0, 0.0, 1.0); // 把输出变量设置为暗红色
}



//片段
#version 330 core
out vec4 FragColor;

in vec4 vertexColor; // 从顶点着色器传来的输入变量（名称相同、类型相同）

void main()
{
    FragColor = vertexColor;
}

```

## Uniform
uniform是全局的(Global)。全局意味着uniform变量必须在每个着色器程序对象中都是独一无二的，而且它可以被着色器程序的任意着色器在任意阶段访问。第二，无论你把uniform值设置成什么，uniform会一直保存它们的数据，直到它们被重置或更新。

```cpp
#version 330 core`在这里插入代码片`
out vec4 FragColor;

uniform vec4 ourColor; // 在OpenGL程序代码中设定这个变量

void main()
{
    FragColor = ourColor;
}
```
如果你声明了一个uniform却在GLSL代码中没用过，编译器会静默移除这个变量，导致最后编译出的版本中并不会包含它，这可能导致几个非常麻烦的错误，记住这点！

这个uniform现在还是空的；我们还没有给它添加任何数据，所以下面我们就做这件事。我们首先需要找到着色器中uniform属性的索引/位置值。当我们得到uniform的索引/位置值后，我们就可以更新它的值了。调用glUseProgram来设置uniform的值

```cpp
float timeValue = glfwGetTime();
float greenValue = (sin(timeValue) / 2.0f) + 0.5f;
int vertexColorLocation = glGetUniformLocation(shaderProgram, "ourColor");
glUseProgram(shaderProgram);
glUniform4f(vertexColorLocation, 0.0f, greenValue, 0.0f, 1.0f);
```

最后提一点，如果在VBO中不止位置属性，还有颜色属性如下图
![在这里插入图片描述](a52c8db1752f4ee5a85e0e34b2f6148b.png)
可以这样设置
```cpp
// 位置属性
glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(float), (void*)0);
glEnableVertexAttribArray(0);
// 颜色属性
glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(float), (void*)(3* sizeof(float)));
glEnableVertexAttribArray(1);
```
把原本的代码写在这里记录一下

```cpp
//
// Created by 刘卓昊 on 2025/4/3.
//
#include <glad/glad.h>
#include <GLFW/glfw3.h>
#include <iostream>
#include <valarray>

void framebuffer_size_callback(GLFWwindow* window, int width, int height){
    std::cout << "Failed to create GLFW window" << std::endl;
    glViewport(0, 0, width, height);
}
GLFWwindow * InitWindowAndFunc(){
    glfwInit();
    // 对GLFW的配置 版本号、次版本号、选择核心模式
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    GLFWwindow* window = glfwCreateWindow(800, 600, "LearnOpenGL", nullptr, nullptr);
    if (window == nullptr){
        std::cout << "Failed to create GLFW window" << std::endl;
        glfwTerminate();
        return nullptr;
    }
    glfwMakeContextCurrent(window);
    if (!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress)){
        std::cout << "Failed to initialize GLAD" << std::endl;
        return nullptr;
    }
    // 前两个参数控制窗口左下角的位置。第三个和第四个参数控制渲染窗口的宽度和高度（像素）
    glViewport(0, 0, 800, 600);
    glfwSetFramebufferSizeCallback(window, framebuffer_size_callback);
    return window;
}

int main()
{
    float vertices[] = {
            0.5f, 0.5f, 0.0f,   // 右上角
            0.5f, -0.5f, 0.0f,  // 右下角
            -0.5f, -0.5f, 0.0f, // 左下角
            -0.5f, 0.5f, 0.0f   // 左上角
    };

    unsigned int indices[] = {
            // 注意索引从0开始!
            // 此例的索引(0,1,2,3)就是顶点数组vertices的下标，
            // 这样可以由下标代表顶点组合成矩形

            0, 1, 3, // 第一个三角形
            1, 2, 3  // 第二个三角形
    };

    GLFWwindow * window = InitWindowAndFunc();

    // 创建一个ID
    GLuint VBO;
    // 此函数会为VBO分配一个未使用的ID（例如 1, 2 等），但此时‌并未实际创建缓冲对象‌，仅预留了标识符
    glGenBuffers(1, &VBO);
    // 绑定到OpenGL上下文中，此时GPU才会真正分配内存
    glBindBuffer(GL_ARRAY_BUFFER, VBO);
    //glBufferData是一个专门用来把用户定义的数据复制到当前绑定缓冲的函数。它的第一个参数是目标缓冲的类型：顶点缓冲对象当前绑定到GL_ARRAY_BUFFER目标上。第二个参数指定传输数据的大小(以字节为单位)；用一个简单的sizeof计算出顶点数据大小就行。第三个参数是我们希望发送的实际数据。
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices),vertices,GL_STATIC_DRAW);

    // 顶点着色器
    const char * vertexShaderSource = "#version 330 core\n"
                                      "layout (location=0) in vec3 aPos;\n"
                                      "void main()\n"
                                      "{\n"
                                      "     gl_Position = vec4(aPos.x,aPos.y,aPos.z,1.0);\n"
                                      "}\0";


    // 创建着色器
    GLuint vertexShader = glCreateShader(GL_VERTEX_SHADER);
    // 源码添加在shader上
    glShaderSource(vertexShader,1,&vertexShaderSource, nullptr);
    // 编译源码
    glCompileShader(vertexShader);
    int  success;
    char infoLog[512];
    glGetShaderiv(vertexShader, GL_COMPILE_STATUS, &success);
    if(!success)
    {
        glGetShaderInfoLog(vertexShader, 512, nullptr, infoLog);
        std::cout << "ERROR::SHADER::VERTEX::COMPILATION_FAILED\n" << infoLog << std::endl;
    }

    const char * fragmentShaderSource = "#version 330 core\n"
                                        "out vec4 FragColor;\n"
                                        "uniform vec4 ourColor; // 在OpenGL程序代码中设定这个变量\n"
                                        "\n"
                                        "void main()\n"
                                        "{\n"
                                        "    FragColor = ourColor;\n"
                                        "} ";
    unsigned int fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragmentShader, 1, &fragmentShaderSource, NULL);
    glCompileShader(fragmentShader);
    // 整合成一个程序
    unsigned int shaderProgram;
    shaderProgram = glCreateProgram();
    glAttachShader(shaderProgram, vertexShader);
    glAttachShader(shaderProgram, fragmentShader);
    glLinkProgram(shaderProgram);
    // 链接阶段报错处理
    glGetProgramiv(shaderProgram, GL_LINK_STATUS, &success);
    if(!success) {
        glGetProgramInfoLog(shaderProgram, 512, nullptr, infoLog);
    }
    // 设置使用
    glUseProgram(shaderProgram);

    // VAO
    GLuint VAO;
    glGenVertexArrays(1, &VAO);
    glBindVertexArray(VAO);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);

    // EBO
    GLuint EBO;
    glGenBuffers(1, &EBO);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, EBO);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);

//    glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
    while(!glfwWindowShouldClose(window))
    {
        // 双缓冲
        glfwSwapBuffers(window);
        // 事件处理
        glfwPollEvents();
        glClearColor(0.2f, 0.3f, 0.3f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
        // 更新uniform颜色
        float timeValue = glfwGetTime();
        float greenValue = sin(timeValue) / 2.0f + 0.5f;
        int vertexColorLocation = glGetUniformLocation(shaderProgram, "ourColor");
        glUniform4f(vertexColorLocation, 0.0f, greenValue, 0.0f, 1.0f);
        // 通过绑定好的VAO和VBO和EBO画三角形
        glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);

    }
    glfwTerminate();
    return 0;

}
```

下来给出一个封装的shader类

```cpp
//
// Created by Administrator on 2025/4/4.
//

#ifndef OPENGL_SHADER_H
#define OPENGL_SHADER_H

#include <glad/glad.h>
#include <string>
#include <fstream>
#include <sstream>
#include <iostream>

class Shader {
public:
    GLuint ID;
    Shader(const char*vertexPath, const char*fragmentPath);

    void use();
    // uniform工具函数
    void setBool(const std::string &name, bool value) const;
    void setInt(const std::string &name, int value) const;
    void setFloat(const std::string &name, float value) const;
    void setVec4f(const std::string &name, float v0, float v1, float v2, float v3) const;

};


#endif //OPENGL_SHADER_H

```

```cpp
//
// Created by Administrator on 2025/4/4.
//

#include "Shader.h"

Shader::Shader(const char *vertexPath, const char *fragmentPath) {
    // 1. 从文件路径中获取顶点/片段着色器
    std::string vertexCode;
    std::string fragmentCode;
    std::ifstream vShaderFile;
    std::ifstream fShaderFile;
    // 保证ifstream对象可以抛出异常：
    vShaderFile.exceptions (std::ifstream::failbit | std::ifstream::badbit);
    fShaderFile.exceptions (std::ifstream::failbit | std::ifstream::badbit);
    try{
        // 打开文件
        vShaderFile.open(vertexPath);
        fShaderFile.open(fragmentPath);
        std::stringstream vShaderStream, fShaderStream;
        // 读取文件的缓冲内容到数据流中
        vShaderStream << vShaderFile.rdbuf();
        fShaderStream << fShaderFile.rdbuf();
        // 关闭文件处理器
        vShaderFile.close();
        fShaderFile.close();
        // 转换数据流到string
        vertexCode   = vShaderStream.str();
        fragmentCode = fShaderStream.str();
    }catch(std::ifstream::failure e){
        std::cout << "ERROR::SHADER::FILE_NOT_READ" << std::endl;
    }
    const char* vShaderCode = vertexCode.c_str();
    const char* fShaderCode = fragmentCode.c_str();
    // 2. 编译着色器
    unsigned int vertex, fragment;
    int success;
    char infoLog[512];

    // 顶点着色器
    vertex = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vertex, 1, &vShaderCode, NULL);
    glCompileShader(vertex);
    // 打印编译错误（如果有的话）
    glGetShaderiv(vertex, GL_COMPILE_STATUS, &success);
    if(!success)
    {
        glGetShaderInfoLog(vertex, 512, NULL, infoLog);
        std::cout << "ERROR::SHADER::VERTEX::COMPILATION_FAILED\n" << infoLog << std::endl;
    };

    // 片段着色器
    fragment = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragment, 1, &fShaderCode, NULL);
    glCompileShader(fragment);
    // 打印编译错误（如果有的话）
    glGetShaderiv(fragment, GL_COMPILE_STATUS, &success);
    if(!success)
    {
        glGetShaderInfoLog(fragment, 512, NULL, infoLog);
        std::cout << "ERROR::SHADER::FRAGMENT::COMPILATION_FAILED\n" << infoLog << std::endl;
    }

    // 着色器程序
    ID = glCreateProgram();
    glAttachShader(ID, vertex);
    glAttachShader(ID, fragment);
    glLinkProgram(ID);
    // 打印连接错误（如果有的话）
    glGetProgramiv(ID, GL_LINK_STATUS, &success);
    if(!success)
    {
        glGetProgramInfoLog(ID, 512, NULL, infoLog);
        std::cout << "ERROR::SHADER::PROGRAM::LINKING_FAILED\n" << infoLog << std::endl;
    }
    // 删除着色器，它们已经链接到我们的程序中了，已经不再需要了
    glDeleteShader(vertex);
    glDeleteShader(fragment);
}

void Shader::use() {
    glUseProgram(ID);
}

void Shader::setBool(const std::string &name, bool value) const
{
    glUniform1i(glGetUniformLocation(ID, name.c_str()), (int)value);
}
void Shader::setInt(const std::string &name, int value) const
{
    glUniform1i(glGetUniformLocation(ID, name.c_str()), value);
}
void Shader::setFloat(const std::string &name, float value) const
{
    glUniform1f(glGetUniformLocation(ID, name.c_str()), value);
}

void Shader::setVec4f(const std::string &name, float v0, float v1, float v2, float v3) const {
    glUniform4f(glGetUniformLocation(ID, name.c_str()), v0, v1, v2, v3);
}

```
# 纹理
首先需要给每个顶点一个纹理坐标

```cpp
float texCoords[] = {
    0.0f, 0.0f, // 左下角
    1.0f, 0.0f, // 右下角
    0.5f, 1.0f  // 上中
};
```
纹理坐标的范围通常是从(0, 0)到(1, 1)，当我们设置成别的区域时，OpenGL通过参数调整有不同的表达方式
![在这里插入图片描述](7707378cde59404cbbc069c690a01ef7.png)
![在这里插入图片描述](407992d5f3524d3dbe8147d50ebb4da3.png)
可以对每个坐标轴的行为进行单独控制

```cpp
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_MIRRORED_REPEAT);
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_MIRRORED_REPEAT);
```
## 纹理过滤
首先介绍一个概念：纹理像素，打开一张图片的每个像素就是纹理像素。OpenGL以一个顶点设置的纹理坐标数据去查找纹理图像上的像素，然后进行采样提取纹理像素的颜色。当我需要渲染到一片很大的光栅时，每个像素点插值出来的纹理坐标没法直接对应纹理图片的一个像素（即纹理像素），比如纹理坐标为(0.1,0.1)时，如果原纹理图片是10x10的，这就表示第一行第一列的那个纹理像素的颜色作为该像素点的颜色（当然真实情况是0+0.5才是一个纹理像素的中心，这里只是便于理解），但是如果纹理坐标插值出来是(0.11,0.11)那就没法直接对应了，就需要特殊处理了。
OpenGL也有对于纹理过滤(Texture Filtering)的选项。纹理过滤有很多个选项，但是现在我们只讨论最重要的两种：GL_NEAREST和GL_LINEAR。

- GL_NEAREST（也叫邻近过滤，Nearest Neighbor Filtering）是OpenGL默认的纹理过滤方式，即选择离纹理坐标最接近的纹理像素的颜色![在这里插入图片描述](5240a00c5441403ead9bc90f14393f0c.png)
- GL_LINEAR（也叫线性过滤，(Bi)linear Filtering）它会基于纹理坐标附近的纹理像素，计算出一个插值，近似出这些纹理像素之间的颜色。一个纹理像素的中心距离纹理坐标越近，那么这个纹理像素的颜色对最终的样本颜色的贡献越大。下图中你可以看到返回的颜色是邻近像素的混合色![在这里插入图片描述](d0bfac55a4b0489da34e3ef6700441f7.png)
## Mipmap 多级渐远纹理
有些物体会很远，但其纹理会拥有与近处物体同样高的分辨率。比如一个物体光栅化后只占了2x2的像素，但他的纹理图片有10x10，它需要对一个跨过纹理很大部分的片段只拾取一个纹理颜色。**在小物体上这会产生不真实的感觉，更不用说对它们使用高分辨率纹理浪费内存的问题了。**
OpenGL使用一种叫做多级渐远纹理(Mipmap)的概念来解决这个问题，它简单来说就是一系列的纹理图像，后一个纹理图像是前一个的二分之一。多级渐远纹理背后的理念很简单：距观察者的距离超过一定的阈值，OpenGL会使用不同的多级渐远纹理，即最适合物体的距离的那个。由于距离远，解析度不高也不会被用户注意到。同时，多级渐远纹理另一加分之处是它的性能非常好。让我们看一下多级渐远纹理是什么样子的
![在这里插入图片描述](50ec627221ab4a6ea1b899401df4a188.png)
离摄像机距离较远的物体采样时，在小纹理上采样效果更好。对Mipmap的使用也有多种过滤方式
![在这里插入图片描述](8562e1db7e9246ac8e142c728b2ccfd1.png)
最后一种参数额外介绍一下`GL_LINEAR_MIPMAP_LINEAR`（三线性过滤），在最接近的两个mipmap上进行线性插值，最后混合结果，计算量时最大的
```cpp
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
```
第一行是对渲染物体小于纹理图片时，使用Mipmap，第二个是当渲染物体大于纹理图片时的设置
## 实际使用方式
stb_image.h是Sean Barrett的一个非常流行的单头文件图像加载库，下载源代码后使用方式如下
```cpp
#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"
```
首先加载一个纹理图片。这个函数首先接受一个图像文件的位置作为输入。接下来它需要三个int作为它的第二、第三和第四个参数，stb_image.h将会用图像的宽度、高度和颜色通道的个数填充这三个变量。我们之后生成纹理的时候会用到的图像的宽度和高度的。
```cpp
    int width, height, nrChannels;
    unsigned char *data = stbi_load("./assert/container.jpg", &width, &height, &nrChannels, 0);
```
对纹理的管理与之前那些Object类似，也得创建id

```cpp
    GLuint texture;
    glGenTextures(1, &texture);
```
紧接着也需要进行绑定，这样之后对纹理的设置都是设置绑定的纹理
```cpp
    glBindTexture(GL_TEXTURE_2D, texture);
```
下来就是把载入的图片生成纹理了，上边的绑定就是为了下边设置时不需要再考虑是给谁设置了
```cpp
glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, width, height, 0, GL_RGB, GL_UNSIGNED_BYTE, data);
glGenerateMipmap(GL_TEXTURE_2D);
// 释放掉图片数据，因为已经转移好了
stbi_image_free(data);
```
下来设置一下纹理的环绕和过滤方式

```cpp
// 为当前绑定的纹理对象设置环绕、过滤方式
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);   
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
```
这样就设置好纹理了，当然顶点数据还要额外存储纹理坐标，不然每个像素去纹理图哪个位置找还不知道，在VBO中存储顶点位置、颜色、纹理坐标，同时需要告诉VAO
```cpp
float vertices[] = {
//     ---- 位置 ----       ---- 颜色 ----     - 纹理坐标 -
     0.5f,  0.5f, 0.0f,   1.0f, 0.0f, 0.0f,   1.0f, 1.0f,   // 右上
     0.5f, -0.5f, 0.0f,   0.0f, 1.0f, 0.0f,   1.0f, 0.0f,   // 右下
    -0.5f, -0.5f, 0.0f,   0.0f, 0.0f, 1.0f,   0.0f, 0.0f,   // 左下
    -0.5f,  0.5f, 0.0f,   1.0f, 1.0f, 0.0f,   0.0f, 1.0f    // 左上
};
```
![在这里插入图片描述](0a221cd9d700401b983b1136b75ee4ff.png)
告诉VAO，纹理数据是如何存储的，即每个顶点数据站8个字节，纹理数据的偏移为6

```cpp
    glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)(6 * sizeof(float)));
    glEnableVertexAttribArray(2);
```
同时需要在顶点着色器中接收参数，接收了每个顶点的纹理坐标，并输出到片段着色器中
```cpp
#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aColor;
layout (location = 2) in vec2 aTexCoord;

out vec3 ourColor;
out vec2 TexCoord;

void main()
{
    gl_Position = vec4(aPos, 1.0);
    ourColor = aColor;
    TexCoord = aTexCoord;
}
```
片段着色器接收插值后的纹理坐标和纹理图片（uniform ）
texture是本身就有的函数，根据输入的纹理图片和纹理坐标，根据之前对纹理图片的设置进行采样
```cpp
#version 330 core
out vec4 FragColor;

in vec3 ourColor;
in vec2 TexCoord;

uniform sampler2D ourTexture;

void main()
{
    FragColor = texture(ourTexture, TexCoord);
}
```
现在只剩下在调用glDrawElements之前绑定纹理了，它会自动把纹理赋值给片段着色器的采样器

```cpp
glBindTexture(GL_TEXTURE_2D, texture);
glBindVertexArray(VAO);
glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
```

如果你的纹理代码不能正常工作或者显示是全黑，请继续阅读，并一直跟进我们的代码到最后的例子，它是应该能够工作的。在一些驱动中，必须要对每个采样器uniform都附加上纹理单元才可以，这个会在下面介绍。![在这里插入图片描述](6f714cdf11ce4b1493f3159dcbf25f13.png)
## 纹理单元
我们通过uniform设置的纹理，但是没有在代码中给他赋值呀。使用glUniform1i，我们可以给纹理采样器分配一个位置值，这样的话我们能够在一个片段着色器中设置多个纹理。一个纹理的默认纹理单元是0，它是默认的激活纹理单元，所以教程前面部分我们没有分配一个位置值。纹理单元的主要目的是让我们在着色器中可以使用多于一个的纹理。通过把纹理单元赋值给采样器，我们可以一次绑定多个纹理，只要我们首先激活对应的纹理单元。

```cpp
glActiveTexture(GL_TEXTURE0); // 在绑定纹理之前先激活纹理单元
glBindTexture(GL_TEXTURE_2D, texture);
```
激活纹理单元之后，绑定的纹理会绑定到激活的纹理单元。OpenGL至少保证有16个纹理单元供你使用，也就是说你可以激活从GL_TEXTURE0到GL_TEXTRUE15。

`就这块东西可以理解为一个像素点的颜色不一定只来自于一张纹理图，比如普通贴图、法线贴图、高光贴图共同配合才能完成一个很好的效果，具体例子可以看我之前的tinyrenderer相关博客的例子。https://blog.csdn.net/lzh804121985/article/details/146939272?spm=1001.2014.3001.5502（直接拉到最后看各种图片）`

当设置两个不同的纹理图时，要修改片段着色器的内容，这里就是混合两张纹理图的内容
```cpp
uniform sampler2D texture1;
uniform sampler2D texture2;

void main()
{
    FragColor = mix(texture(texture1, TexCoord), texture(texture2, TexCoord), 0.2);
}
```
因为这里定义的其实是两个采样器，而不是两个纹理，我觉得修改名字比较直观

```cpp
uniform sampler2D sampler1;
uniform sampler2D sampler2;

void main()
{
    FragColor = mix(texture(sampler1, TexCoord), texture(sampler2, TexCoord), 0.2);
}}
```
最后就需要指定每个sample对应的是哪个纹理单元了

```cpp
// 设置 Uniform（目的是给片段着色器中定义的两个采样器，告诉他们分别对应的是哪个纹理单元）
// glUniform1i(glGetUniformLocation(ourShader.ID, "texture1"), 0); // 手动设置
    ourShader.setInt("sampler1", 0);
    ourShader.setInt("sampler2", 1);
```
完整代码如下

```cpp
//
// Created by 刘卓昊 on 2025/4/3.
//
#include <glad/glad.h>
#include <GLFW/glfw3.h>
#include <iostream>

#include "Shader.h"
#define STB_IMAGE_IMPLEMENTATION
#include <stb_image.h>

#define GL_CALL(x) \
    do { \
        x; \
        GLenum error = glGetError(); \
        if (error != GL_NO_ERROR) { \
            std::cerr << "OpenGL error: " << error << " at " << __FILE__ << ":" << __LINE__ << std::endl; \
        } \
    } while (0)

void framebuffer_size_callback(GLFWwindow* window, int width, int height) {
    GL_CALL(glViewport(0, 0, width, height));
}

GLFWwindow * InitWindowAndFunc() {
    glfwInit();
    // 对GLFW的配置 版本号、次版本号、选择核心模式
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    GLFWwindow* window = glfwCreateWindow(800, 600, "LearnOpenGL", nullptr, nullptr);
    if (window == nullptr) {
        std::cout << "Failed to create GLFW window" << std::endl;
        glfwTerminate();
        return nullptr;
    }
    glfwMakeContextCurrent(window);
    if (!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress)) {
        std::cout << "Failed to initialize GLAD" << std::endl;
        return nullptr;
    }
    // 前两个参数控制窗口左下角的位置。第三个和第四个参数控制渲染窗口的宽度和高度（像素）
    GL_CALL(glViewport(0, 0, 800, 600));
    glfwSetFramebufferSizeCallback(window, framebuffer_size_callback);
    return window;
}

int main()
{
    float vertices[] = {
//     ---- 位置 ----       ---- 颜色 ----     - 纹理坐标 -
            0.5f,  0.5f, 0.0f,   1.0f, 0.0f, 0.0f,   1.0f, 1.0f,   // 右上
            0.5f, -0.5f, 0.0f,   0.0f, 1.0f, 0.0f,   1.0f, 0.0f,   // 右下
            -0.5f, -0.5f, 0.0f,   0.0f, 0.0f, 1.0f,   0.0f, 0.0f,   // 左下
            -0.5f,  0.5f, 0.0f,   1.0f, 1.0f, 0.0f,   0.0f, 1.0f    // 左上
    };

    unsigned int indices[] = {
            // 注意索引从0开始!
            // 此例的索引(0,1,2,3)就是顶点数组vertices的下标，
            // 这样可以由下标代表顶点组合成矩形

            0, 1, 3, // 第一个三角形
            1, 2, 3  // 第二个三角形
    };

    GLFWwindow * window = InitWindowAndFunc();
    // shader
    Shader ourShader("./shader/shader.vs", "./shader/shader.fs");
    // 创建Object的ID
    GLuint VBO, VAO, EBO;
    GL_CALL(glGenVertexArrays(1, &VAO));
    GL_CALL(glGenBuffers(1, &VBO));
    GL_CALL(glGenBuffers(1, &EBO));
    GL_CALL(glBindVertexArray(VAO));

    // 绑定到OpenGL上下文中，此时GPU才会真正分配内存
    GL_CALL(glBindBuffer(GL_ARRAY_BUFFER, VBO));
    //glBufferData是一个专门用来把用户定义的数据复制到当前绑定缓冲的函数。它的第一个参数是目标缓冲的类型：顶点缓冲对象当前绑定到GL_ARRAY_BUFFER目标上。第二个参数指定传输数据的大小(以字节为单位)；用一个简单的sizeof计算出顶点数据大小就行。第三个参数是我们希望发送的实际数据。
    GL_CALL(glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW));
    // EBO
    GL_CALL(glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, EBO));
    GL_CALL(glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW));

    // VAO
    GL_CALL(glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)0));
    GL_CALL(glEnableVertexAttribArray(0));
    GL_CALL(glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)(3 * sizeof(float))));
    GL_CALL(glEnableVertexAttribArray(1));
    GL_CALL(glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)(6 * sizeof(float))));
    GL_CALL(glEnableVertexAttribArray(2));

    // 纹理部分
    GLuint texture1, texture2;
    // 让加载的图片y轴反转
    stbi_set_flip_vertically_on_load(true);
    // 纹理单元 0
    GL_CALL(glActiveTexture(GL_TEXTURE0));
    int width, height, nrChannels;
    GL_CALL(glGenTextures(1, &texture1));
    GL_CALL(glBindTexture(GL_TEXTURE_2D, texture1));
    GL_CALL(glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT));
    GL_CALL(glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT));
    GL_CALL(glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR));
    GL_CALL(glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR));
    unsigned char *data1 = stbi_load("./assets/container.jpg", &width, &height, &nrChannels, 0);
    if (!data1){
        std::cout << "Failed to load texture" << std::endl;
    }
    GL_CALL(glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, width, height, 0, GL_RGB, GL_UNSIGNED_BYTE, data1));
    GL_CALL(glGenerateMipmap(GL_TEXTURE_2D));
    stbi_image_free(data1);

    // 纹理单元 1
    GL_CALL(glActiveTexture(GL_TEXTURE1));
    GL_CALL(glGenTextures(1, &texture2));
    GL_CALL(glBindTexture(GL_TEXTURE_2D, texture2));
    GL_CALL(glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT));
    GL_CALL(glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT));
    GL_CALL(glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR));
    GL_CALL(glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR));
    unsigned char *data2 = stbi_load("./assets/awesomeface.png", &width, &height, &nrChannels, 0);
    if (!data2){
        std::cout << "Failed to load texture" << std::endl;
    }
    GL_CALL(glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, data2));
    GL_CALL(glGenerateMipmap(GL_TEXTURE_2D));
    stbi_image_free(data2);

    ourShader.use();
    // 设置 Uniform（目的是给片段着色器中定义的两个采样器，告诉他们分别对应的是哪个纹理单元）
    GL_CALL(ourShader.setInt("sampler1", 0));
    GL_CALL(ourShader.setInt("sampler2", 1));

    while (!glfwWindowShouldClose(window))
    {
        // 清理窗口
        GL_CALL(glClearColor(0.2f, 0.3f, 0.3f, 1.0f));
        GL_CALL(glClear(GL_COLOR_BUFFER_BIT));

        // 绑定纹理
        GL_CALL(glActiveTexture(GL_TEXTURE0));
        GL_CALL(glBindTexture(GL_TEXTURE_2D, texture1));
        GL_CALL(glActiveTexture(GL_TEXTURE1));
        GL_CALL(glBindTexture(GL_TEXTURE_2D, texture2));
        // 激活着色器
        GL_CALL(ourShader.use());
        // 绑定VAO
        GL_CALL(glBindVertexArray(VAO));

        // 绘制
        GL_CALL(glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0));
        // 事件处理
        glfwPollEvents();
        // 双缓冲
        glfwSwapBuffers(window);
        // 解绑
        GL_CALL(glBindVertexArray(0));
        GL_CALL(glUseProgram(0));
    }
    glfwTerminate();
    return 0;
}
```
用Clion的一定要注意，要修改debug文件夹下的着色器代码才能生效。。。
最终图片
![在这里插入图片描述](dc5ed13b530e44679d80e4ca5ccd1ec7.png)

# 坐标系统
GLM是OpenGL Mathematics的缩写，它是一个只有头文件的库，也就是说我们只需包含对应的头文件就行了，不用链接和编译。GLM可以在它们的网站上下载。把头文件的根目录复制到你的includes文件夹，然后你就可以使用这个库了。![在这里插入图片描述](fe23d8750d70407eb6dc115cff7e2857.png)
OpenGL希望在每次顶点着色器运行后，我们可见的所有顶点都为标准化设备坐标(Normalized Device Coordinate, NDC)。也就是说，每个顶点的x，y，z坐标都应该在-1.0到1.0之间，超出这个坐标范围的顶点都将不可见。也就是说OpenGL顶点着色器执行完后，会对不在NDC范围内的点进行剔除。

games101学过很多了，MVP+透视除法+视口变换，让一个三维物体转为二维坐标
局部空间(Local Space，或者称为物体空间(Object Space))
世界空间(World Space)
观察空间(View Space，或者称为视觉空间(Eye Space))
裁剪空间(Clip Space)
屏幕空间(Screen Space)
![在这里插入图片描述](b4b0c904a8fc4e50b53cbb92f0d7193c.png)
对于局部空间、世界空间、观察空间这里就不做解释了

## 裁剪空间
在一个顶点着色器运行的最后，OpenGL期望所有的坐标都能落在一个特定的范围内，且任何在这个范围之外的点都应该被裁剪掉(Clipped)。被裁剪掉的坐标就会被忽略，所以剩下的坐标就将变为屏幕上可见的片段。这也就是裁剪空间(Clip Space)名字的由来。

`如果只是图元(Primitive)，例如三角形，的一部分超出了裁剪体积(Clipping Volume)，则OpenGL会重新构建这个三角形为一个或多个三角形让其能够适合这个裁剪范围。`
例如下图![在这里插入图片描述](b7d5175b000b4cd38003f482b4690d33.png)
一旦所有顶点被变换到裁剪空间，最终的操作——透视除法(Perspective Division)将会执行，在这个过程中我们将位置向量的x，y，z分量分别除以向量的齐次w分量。`透视除法是将4D裁剪空间坐标变换为3D标准化设备坐标的过程。这一步会在每一个顶点着色器运行的最后被自动执行。`
在OpenGL中只需要处理MVP矩阵，裁剪、透视除法和视口变换会自动处理。
来直接开干把！
1. 模型变换矩阵，通过将顶点坐标乘以这个模型矩阵，我们将该顶点坐标变换到世界坐标。我们的平面看起来就是在地板上，代表全局世界里的平面。
```cpp
glm::mat4 model;
model = glm::rotate(model, glm::radians(-55.0f), glm::vec3(1.0f, 0.0f, 0.0f));
```
2. 视图变换矩阵
3. 
```cpp
glm::mat4 view;
// 注意，我们将矩阵向我们要进行移动场景的反方向移动。
view = glm::translate(view, glm::vec3(0.0f, 0.0f, -3.0f));
```
4. 透视投影矩阵
```cpp
glm::mat4 projection;
projection = glm::perspective(glm::radians(45.0f), screenWidth / screenHeight, 0.1f, 100.0f);
```
把这些矩阵传入顶点着色器

```cpp
#version 330 core
layout (location = 0) in vec3 aPos;
...
uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

void main()
{
    // 注意乘法要从右向左读
    gl_Position = projection * view * model * vec4(aPos, 1.0);
    ...
}
```
整体如下
```cpp
    // 构建MVP矩阵
    auto model = glm::mat4(1.0f);
    auto view = glm::mat4(1.0f);
    auto projection = glm::mat4(1.0f);
    model = glm::rotate(model, glm::radians(-55.0f), glm::vec3(1.0f, 0.0f, 0.0f));
    view  = glm::translate(view, glm::vec3(0.0f, 0.0f, -3.0f));
    projection = glm::perspective(glm::radians(45.0f), (float)SCR_WIDTH / (float)SCR_HEIGHT, 0.1f, 100.0f);

    ourShader.setMat4("model", model);
    ourShader.setMat4("view", view);
    ourShader.setMat4("projection", projection);
```
setMat4是新添加的方法

```cpp
void Shader::setMat4(const std::string &name, const glm::mat4 &mat) const {
    glUniformMatrix4fv(
            glGetUniformLocation(ID, name.c_str()), // 获取Uniform位置
            1,                                      // 上传矩阵数量
            GL_FALSE,                               // 是否转置（GLM默认列主序，无需转置）
            glm::value_ptr(mat)                     // 使用GLM提供的指针获取方法
    );
}
```
现在图片躺下了
![在这里插入图片描述](3779db9d1ff84e66b075f0dd6d1edb90.png)
后边这个立方体就不做了，就是顶点都写进去，然后设置好VAO，之后在循环中修改MVP矩阵的M矩阵，他就转起来了，但目前还没有考虑Z-buffer。**GLFW会自动为你生成这样一个缓冲）**我们想要确定OpenGL真的执行了深度测试，首先我们要告诉OpenGL我们想要启用深度测试；它默认是关闭的。我们可以通过glEnable函数来开启深度测试。glEnable和glDisable函数允许我们启用或禁用某个OpenGL功能

```cpp
// 开启Z-buffer
glEnable(GL_DEPTH_TEST);

// 当模型发生变化时，需要在循环中清楚之前缓存的zbuffer
glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

```
# 摄像机
OpenGL本身没有摄像机(Camera)的概念，但我们可以通过把场景中的所有物体往相反方向移动的方式来模拟出摄像机，产生一种我们在移动的感觉，而不是场景在移动。在上一节中我们通过把所有物体向后平移3格，来模拟摄像机在(0,0,3)的位置上。

要定义一个摄像机，我们需要它在世界空间中的位置、观察的方向、一个指向它右侧的向量以及一个指向它上方的向量。实际上创建了一个三个单位轴相互垂直的、以摄像机的位置为原点的坐标系。
首先来指定一个摄像机位置

```cpp
glm::vec3 cameraPos = glm::vec3(0.0f, 0.0f, 3.0f);
```
摄像机的方向就指向场景的原点即可，相减就得到了摄像机的指向方向，但是取反转方向，也就是是指向+Z的，与摄像机的朝向相反
```cpp
glm::vec3 cameraTarget = glm::vec3(0.0f, 0.0f, 0.0f);
glm::vec3 cameraDirection = glm::normalize(cameraPos - cameraTarget);
```
之后还需要一个右向量作为x方向，可以通过上向量与指向方向叉乘得到
```cpp
// 上方向
glm::vec3 up = glm::vec3(0.0f, 1.0f, 0.0f); 
// 叉乘得右方向，表示x轴的正方向
glm::vec3 cameraRight = glm::normalize(glm::cross(up, cameraDirection));
```
最后y方向就可以通过上和右的叉乘得到

```cpp
glm::vec3 cameraUp = glm::cross(cameraDirection, cameraRight);
```
使用上面得到的x\y\z向量可以构建lookAt矩阵，可以用这个矩阵乘以任何向量来将其变换到摄像机坐标空间
![在这里插入图片描述](7624db84b8f64bb796dce3db216ecba2.png)

其中`R`是右向量，`U`是上向量，`D`是方向向量,`P`是摄像机位置向量,可以直接通过GLM生成这个矩阵

```cpp
glm::mat4 view;
view = glm::lookAt(glm::vec3(0.0f, 0.0f, 3.0f), 
           glm::vec3(0.0f, 0.0f, 0.0f), 
           glm::vec3(0.0f, 1.0f, 0.0f));
```
glm::LookAt函数需要一个位置、目标和上向量
如果我们在View矩阵构建时使用时间，就会让整个场景开始旋转

```cpp
        float camX = sin(glfwGetTime()) * radius;
        float camZ = cos(glfwGetTime()) * radius;
        glm::mat4 view;
        view = glm::lookAt(glm::vec3(camX, 0.0, camZ), glm::vec3(0.0, 0.0, 0.0), glm::vec3(0.0, 1.0, 0.0));
```
## 自由移动

```cpp
glm::vec3 cameraPos   = glm::vec3(0.0f, 0.0f,  3.0f);
glm::vec3 cameraFront = glm::vec3(0.0f, 0.0f, -1.0f);
glm::vec3 cameraUp    = glm::vec3(0.0f, 1.0f,  0.0f);
view = glm::lookAt(cameraPos, cameraPos + cameraFront, cameraUp);
```
通过上边参数控制，就用这些vec3来控制lookAt矩阵的生成了，下来就用监听来绑定按键修改参数，就是改变Pos来实现的

```cpp
void processInput(GLFWwindow *window)
{
    float cameraSpeed = 0.05f; // adjust accordingly
    if (glfwGetKey(window, GLFW_KEY_W) == GLFW_PRESS)
        cameraPos += cameraSpeed * cameraFront;
    if (glfwGetKey(window, GLFW_KEY_S) == GLFW_PRESS)
        cameraPos -= cameraSpeed * cameraFront;
    if (glfwGetKey(window, GLFW_KEY_A) == GLFW_PRESS)
        cameraPos -= glm::normalize(glm::cross(cameraFront, cameraUp)) * cameraSpeed;
    if (glfwGetKey(window, GLFW_KEY_D) == GLFW_PRESS)
        cameraPos += glm::normalize(glm::cross(cameraFront, cameraUp)) * cameraSpeed;
}
```

这里设置一个固定的移动速度是有bug的，因为每一帧处理一次移动，如果硬件比较好的条件下，帧数高，速度就会快一点。图形程序和游戏通常会跟踪一个时间差(Deltatime)变量，它储存了渲染上一帧所用的时间。我们把所有速度都去乘以deltaTime值

```cpp
float deltaTime = 0.0f; // 当前帧与上一帧的时间差
float lastFrame = 0.0f; // 上一帧的时间
float currentFrame = glfwGetTime();
deltaTime = currentFrame - lastFrame;
lastFrame = currentFrame;
void processInput(GLFWwindow *window)
{
  float cameraSpeed = 2.5f * deltaTime;
  ...
}
```
## 视角移动
为了能够改变视角，我们需要根据鼠标的输入改变cameraFront向量。这里需要一点三角学的知识

**欧拉角**：俯仰角(Pitch)、偏航角(Yaw)和滚转角(Roll)，每个欧拉角都有一个值来表示，把三个角结合起来我们就能够计算3D空间中任何的旋转向量了。
![在这里插入图片描述](85618c60be234d378ff1a082524831e3.png)
假设我们现在在XZ屏幕，往Y偏移就是俯仰角
![在这里插入图片描述](576a97d4b1ab4883bd1d505db7889e64.png)
假设俯仰角为pitch
```cpp
direction.y = sin(glm::radians(pitch)); // 注意我们先把角度转为弧度
direction.x = cos(glm::radians(pitch));
direction.z = cos(glm::radians(pitch));
```

对偏航角的处理一个道理
![在这里插入图片描述](7844b537be3f49abb8f38e7615bf9754.png)
通过俯仰角的计算已经知道了斜边长是cos(pitch)，一结合，就得如果已知俯仰角和偏航角，就可以知道(x,y,z)坐标了
```cpp
direction.x = cos(glm::radians(pitch)) * cos(glm::radians(yaw)); // 译注：direction代表摄像机的前轴(Front)，这个前轴是和本文第一幅图片的第二个摄像机的方向向量是相反的
direction.y = sin(glm::radians(pitch));
direction.z = cos(glm::radians(pitch)) * sin(glm::radians(yaw));
```
偏航角和俯仰角是通过鼠标（或手柄）移动获得的，水平的移动影响偏航角，竖直的移动影响俯仰角。它的原理就是，储存上一帧鼠标的位置，在当前帧中我们当前计算鼠标位置与上一帧的位置相差多少。如果水平/竖直差别越大那么俯仰角或偏航角就改变越大，也就是摄像机需要移动更多的距离。
首先让光标消失

```cpp
glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_DISABLED);
```
之后注册一个鼠标移动监听的回调

```cpp
void mouse_callback(GLFWwindow* window, double xpos, double ypos);
glfwSetCursorPosCallback(window, mouse_callback);
```
我们必须在程序存储上一帧鼠标的位置，再看这一帧的变化，计算出角度进而计算出摄像机位置，修改LookAt矩阵

```cpp
void mouse_callback(GLFWwindow* window, double xpos, double ypos)
{
    if(firstMouse)
    {
        lastX = xpos;
        lastY = ypos;
        firstMouse = false;
    }

    float xoffset = xpos - lastX;
    float yoffset = lastY - ypos;
    lastX = xpos;
    lastY = ypos;

    float sensitivity = 0.05;
    xoffset *= sensitivity;
    yoffset *= sensitivity;

    yaw   += xoffset;
    pitch += yoffset;

    if(pitch > 89.0f)
        pitch = 89.0f;
    if(pitch < -89.0f)
        pitch = -89.0f;

    glm::vec3 front;
    front.x = cos(glm::radians(yaw)) * cos(glm::radians(pitch));
    front.y = sin(glm::radians(pitch));
    front.z = sin(glm::radians(yaw)) * cos(glm::radians(pitch));
    cameraFront = glm::normalize(front);
}
```
另外场景的放大缩小可以通过控制透视矩阵的fov来控制
最后提供一个封装好的摄像机类

```cpp
#ifndef CAMERA_H
#define CAMERA_H

#include <glad/glad.h>
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>

// Defines several possible options for camera movement. Used as abstraction to stay away from window-system specific input methods
enum Camera_Movement {
    FORWARD,
    BACKWARD,
    LEFT,
    RIGHT
};

// Default camera values
const float YAW         = -90.0f;
const float PITCH       =  0.0f;
const float SPEED       =  2.5f;
const float SENSITIVITY =  0.1f;
const float ZOOM        =  45.0f;


// An abstract camera class that processes input and calculates the corresponding Euler Angles, Vectors and Matrices for use in OpenGL
class Camera
{
public:
    // camera Attributes
    glm::vec3 Position;
    glm::vec3 Front;
    glm::vec3 Up;
    glm::vec3 Right;
    glm::vec3 WorldUp;
    // euler Angles
    float Yaw;
    float Pitch;
    // camera options
    float MovementSpeed;
    float MouseSensitivity;
    float Zoom;

    // constructor with vectors
    Camera(glm::vec3 position = glm::vec3(0.0f, 0.0f, 0.0f), glm::vec3 up = glm::vec3(0.0f, 1.0f, 0.0f), float yaw = YAW, float pitch = PITCH) : Front(glm::vec3(0.0f, 0.0f, -1.0f)), MovementSpeed(SPEED), MouseSensitivity(SENSITIVITY), Zoom(ZOOM)
    {
        Position = position;
        WorldUp = up;
        Yaw = yaw;
        Pitch = pitch;
        updateCameraVectors();
    }
    // constructor with scalar values
    Camera(float posX, float posY, float posZ, float upX, float upY, float upZ, float yaw, float pitch) : Front(glm::vec3(0.0f, 0.0f, -1.0f)), MovementSpeed(SPEED), MouseSensitivity(SENSITIVITY), Zoom(ZOOM)
    {
        Position = glm::vec3(posX, posY, posZ);
        WorldUp = glm::vec3(upX, upY, upZ);
        Yaw = yaw;
        Pitch = pitch;
        updateCameraVectors();
    }

    // returns the view matrix calculated using Euler Angles and the LookAt Matrix
    glm::mat4 GetViewMatrix()
    {
        return glm::lookAt(Position, Position + Front, Up);
    }

    // processes input received from any keyboard-like input system. Accepts input parameter in the form of camera defined ENUM (to abstract it from windowing systems)
    void ProcessKeyboard(Camera_Movement direction, float deltaTime)
    {
        float velocity = MovementSpeed * deltaTime;
        if (direction == FORWARD)
            Position += Front * velocity;
        if (direction == BACKWARD)
            Position -= Front * velocity;
        if (direction == LEFT)
            Position -= Right * velocity;
        if (direction == RIGHT)
            Position += Right * velocity;
    }

    // processes input received from a mouse input system. Expects the offset value in both the x and y direction.
    void ProcessMouseMovement(float xoffset, float yoffset, GLboolean constrainPitch = true)
    {
        xoffset *= MouseSensitivity;
        yoffset *= MouseSensitivity;

        Yaw   += xoffset;
        Pitch += yoffset;

        // make sure that when pitch is out of bounds, screen doesn't get flipped
        if (constrainPitch)
        {
            if (Pitch > 89.0f)
                Pitch = 89.0f;
            if (Pitch < -89.0f)
                Pitch = -89.0f;
        }

        // update Front, Right and Up Vectors using the updated Euler angles
        updateCameraVectors();
    }

    // processes input received from a mouse scroll-wheel event. Only requires input on the vertical wheel-axis
    void ProcessMouseScroll(float yoffset)
    {
        Zoom -= (float)yoffset;
        if (Zoom < 1.0f)
            Zoom = 1.0f;
        if (Zoom > 45.0f)
            Zoom = 45.0f;
    }

private:
    // calculates the front vector from the Camera's (updated) Euler Angles
    void updateCameraVectors()
    {
        // calculate the new Front vector
        glm::vec3 front;
        front.x = cos(glm::radians(Yaw)) * cos(glm::radians(Pitch));
        front.y = sin(glm::radians(Pitch));
        front.z = sin(glm::radians(Yaw)) * cos(glm::radians(Pitch));
        Front = glm::normalize(front);
        // also re-calculate the Right and Up vector
        Right = glm::normalize(glm::cross(Front, WorldUp));  // normalize the vectors, because their length gets closer to 0 the more you look up or down which results in slower movement.
        Up    = glm::normalize(glm::cross(Right, Front));
    }
};
#endif
```
最终能运行的整体代码

```cpp
//
// Created by 刘卓昊 on 2025/4/3.
//
#include <glad/glad.h>
#include <GLFW/glfw3.h>
#include <iostream>

#include "Shader.h"
#define STB_IMAGE_IMPLEMENTATION
#include <stb_image.h>
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtc/type_ptr.hpp>
#include "camera.h"
#define GL_CALL(x) \
    do { \
        x; \
        GLenum error = glGetError(); \
        if (error != GL_NO_ERROR) { \
            std::cerr << "OpenGL error: " << error << " at " << __FILE__ << ":" << __LINE__ << std::endl; \
        } \
    } while (0)
void framebuffer_size_callback(GLFWwindow* window, int width, int height);
void mouse_callback(GLFWwindow* window, double xpos, double ypos);
void scroll_callback(GLFWwindow* window, double xoffset, double yoffset);
void processInput(GLFWwindow *window);

const unsigned int SCR_WIDTH = 800;
const unsigned int SCR_HEIGHT = 600;
// camera
Camera camera(glm::vec3(0.0f, 0.0f, 3.0f));
float lastX = SCR_WIDTH / 2.0f;
float lastY = SCR_HEIGHT / 2.0f;
bool firstMouse = true;

// timing
float deltaTime = 0.0f;	// time between current frame and last frame
float lastFrame = 0.0f;


GLFWwindow * InitWindowAndFunc() {
    glfwInit();
    // 对GLFW的配置 版本号、次版本号、选择核心模式
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    GLFWwindow* window = glfwCreateWindow(800, 600, "LearnOpenGL", nullptr, nullptr);
    if (window == nullptr) {
        std::cout << "Failed to create GLFW window" << std::endl;
        glfwTerminate();
        return nullptr;
    }
    glfwMakeContextCurrent(window);
    if (!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress)) {
        std::cout << "Failed to initialize GLAD" << std::endl;
        return nullptr;
    }
    // 前两个参数控制窗口左下角的位置。第三个和第四个参数控制渲染窗口的宽度和高度（像素）
    GL_CALL(glViewport(0, 0, SCR_WIDTH, SCR_HEIGHT));
    glfwSetFramebufferSizeCallback(window, framebuffer_size_callback);
    glfwSetCursorPosCallback(window, mouse_callback);
    glfwSetScrollCallback(window, scroll_callback);
    glfwSetScrollCallback(window, scroll_callback);

    return window;
}


int main()
{
    float vertices[] = {
//     ---- 位置 ----       ---- 颜色 ----     - 纹理坐标 -
            0.5f,  0.5f, 0.0f,   1.0f, 0.0f, 0.0f,   1.0f, 1.0f,   // 右上
            0.5f, -0.5f, 0.0f,   0.0f, 1.0f, 0.0f,   1.0f, 0.0f,   // 右下
            -0.5f, -0.5f, 0.0f,   0.0f, 0.0f, 1.0f,   0.0f, 0.0f,   // 左下
            -0.5f,  0.5f, 0.0f,   1.0f, 1.0f, 0.0f,   0.0f, 1.0f    // 左上
    };

    unsigned int indices[] = {
            // 注意索引从0开始!
            // 此例的索引(0,1,2,3)就是顶点数组vertices的下标，
            // 这样可以由下标代表顶点组合成矩形

            0, 1, 3, // 第一个三角形
            1, 2, 3  // 第二个三角形
    };

    GLFWwindow * window = InitWindowAndFunc();
    // shader
    Shader ourShader("./shader/shader.vs", "./shader/shader.fs");
    // 创建Object的ID
    GLuint VBO, VAO, EBO;
    GL_CALL(glGenVertexArrays(1, &VAO));
    GL_CALL(glGenBuffers(1, &VBO));
    GL_CALL(glGenBuffers(1, &EBO));
    GL_CALL(glBindVertexArray(VAO));

    // 绑定到OpenGL上下文中，此时GPU才会真正分配内存
    GL_CALL(glBindBuffer(GL_ARRAY_BUFFER, VBO));
    //glBufferData是一个专门用来把用户定义的数据复制到当前绑定缓冲的函数。它的第一个参数是目标缓冲的类型：顶点缓冲对象当前绑定到GL_ARRAY_BUFFER目标上。第二个参数指定传输数据的大小(以字节为单位)；用一个简单的sizeof计算出顶点数据大小就行。第三个参数是我们希望发送的实际数据。
    GL_CALL(glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW));
    // EBO
    GL_CALL(glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, EBO));
    GL_CALL(glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW));

    // VAO
    GL_CALL(glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)0));
    GL_CALL(glEnableVertexAttribArray(0));
    GL_CALL(glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)(3 * sizeof(float))));
    GL_CALL(glEnableVertexAttribArray(1));
    GL_CALL(glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, 8 * sizeof(float), (void*)(6 * sizeof(float))));
    GL_CALL(glEnableVertexAttribArray(2));

    // 纹理部分
    GLuint texture1, texture2;
    // 让加载的图片y轴反转
    stbi_set_flip_vertically_on_load(true);
    // 纹理单元 0
    GL_CALL(glActiveTexture(GL_TEXTURE0));
    int width, height, nrChannels;
    GL_CALL(glGenTextures(1, &texture1));
    GL_CALL(glBindTexture(GL_TEXTURE_2D, texture1));
    GL_CALL(glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT));
    GL_CALL(glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT));
    GL_CALL(glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR));
    GL_CALL(glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR));
    unsigned char *data1 = stbi_load("./assets/container.jpg", &width, &height, &nrChannels, 0);
    if (!data1){
        std::cout << "Failed to load texture" << std::endl;
    }
    GL_CALL(glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, width, height, 0, GL_RGB, GL_UNSIGNED_BYTE, data1));
    GL_CALL(glGenerateMipmap(GL_TEXTURE_2D));
    stbi_image_free(data1);

    // 纹理单元 1
    GL_CALL(glActiveTexture(GL_TEXTURE1));
    GL_CALL(glGenTextures(1, &texture2));
    GL_CALL(glBindTexture(GL_TEXTURE_2D, texture2));
    GL_CALL(glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT));
    GL_CALL(glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT));
    GL_CALL(glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR));
    GL_CALL(glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR));
    unsigned char *data2 = stbi_load("./assets/awesomeface.png", &width, &height, &nrChannels, 0);
    if (!data2){
        std::cout << "Failed to load texture" << std::endl;
    }
    GL_CALL(glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, data2));
    GL_CALL(glGenerateMipmap(GL_TEXTURE_2D));
    stbi_image_free(data2);

    ourShader.use();
    // 设置 Uniform（目的是给片段着色器中定义的两个采样器，告诉他们分别对应的是哪个纹理单元）
    GL_CALL(ourShader.setInt("sampler1", 0));
    GL_CALL(ourShader.setInt("sampler2", 1));

    // 光标消失
    glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_DISABLED);


    while (!glfwWindowShouldClose(window))
    {
        float currentFrame = static_cast<float>(glfwGetTime());
        deltaTime = currentFrame - lastFrame;
        lastFrame = currentFrame;
        processInput(window);
        // 清理窗口
        GL_CALL(glClearColor(0.2f, 0.3f, 0.3f, 1.0f));
        GL_CALL(glClear(GL_COLOR_BUFFER_BIT));

        // 绑定纹理
        GL_CALL(glActiveTexture(GL_TEXTURE0));
        GL_CALL(glBindTexture(GL_TEXTURE_2D, texture1));
        GL_CALL(glActiveTexture(GL_TEXTURE1));
        GL_CALL(glBindTexture(GL_TEXTURE_2D, texture2));
        // 激活着色器
        GL_CALL(ourShader.use());

        // 构建MVP矩阵
        auto model = glm::mat4(1.0f);
        auto view = glm::mat4(1.0f);
        auto projection = glm::mat4(1.0f);
        model = glm::rotate(model, glm::radians(-55.0f), glm::vec3(1.0f, 0.0f, 0.0f));
        view = camera.GetViewMatrix();
        projection = glm::perspective(glm::radians(camera.Zoom), (float)SCR_WIDTH / (float)SCR_HEIGHT, 0.1f, 100.0f);
        ourShader.setMat4("model", model);
        ourShader.setMat4("view", view);
        ourShader.setMat4("projection", projection);
        // 绑定VAO
        GL_CALL(glBindVertexArray(VAO));
        // 绘制
        GL_CALL(glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0));
        // 事件处理
        glfwPollEvents();
        // 双缓冲
        glfwSwapBuffers(window);
        // 解绑
        GL_CALL(glBindVertexArray(0));
        GL_CALL(glUseProgram(0));
    }
    glfwTerminate();
    return 0;
}
// process all input: query GLFW whether relevant keys are pressed/released this frame and react accordingly
// ---------------------------------------------------------------------------------------------------------
void processInput(GLFWwindow *window)
{
    if (glfwGetKey(window, GLFW_KEY_ESCAPE) == GLFW_PRESS)
        glfwSetWindowShouldClose(window, true);
    if (glfwGetKey(window, GLFW_KEY_W) == GLFW_PRESS)
        camera.ProcessKeyboard(FORWARD, deltaTime);
    if (glfwGetKey(window, GLFW_KEY_S) == GLFW_PRESS)
        camera.ProcessKeyboard(BACKWARD, deltaTime);
    if (glfwGetKey(window, GLFW_KEY_A) == GLFW_PRESS)
        camera.ProcessKeyboard(LEFT, deltaTime);
    if (glfwGetKey(window, GLFW_KEY_D) == GLFW_PRESS)
        camera.ProcessKeyboard(RIGHT, deltaTime);
}

// glfw: whenever the window size changed (by OS or user resize) this callback function executes
// ---------------------------------------------------------------------------------------------
void framebuffer_size_callback(GLFWwindow* window, int width, int height)
{
    // make sure the viewport matches the new window dimensions; note that width and
    // height will be significantly larger than specified on retina displays.
    glViewport(0, 0, width, height);
}


// glfw: whenever the mouse moves, this callback is called
// -------------------------------------------------------
void mouse_callback(GLFWwindow* window, double xposIn, double yposIn)
{
    float xpos = static_cast<float>(xposIn);
    float ypos = static_cast<float>(yposIn);

    if (firstMouse)
    {
        lastX = xpos;
        lastY = ypos;
        firstMouse = false;
    }

    float xoffset = xpos - lastX;
    float yoffset = lastY - ypos; // reversed since y-coordinates go from bottom to top

    lastX = xpos;
    lastY = ypos;

    camera.ProcessMouseMovement(xoffset, yoffset);
}

// glfw: whenever the mouse scroll wheel scrolls, this callback is called
// ----------------------------------------------------------------------
void scroll_callback(GLFWwindow* window, double xoffset, double yoffset)
{
    camera.ProcessMouseScroll(static_cast<float>(yoffset));
}
```
