+++
date = '2025-12-26T16:52:18+08:00'
draft = true
title = '面试（cpp）'
+++

# 基础

## 内存对齐

> 未特殊说明时，按结构体中size最大的成员对齐（若有double成员，按8字节对齐。）
>
> 字节对齐目的是让访问一些大字节类型时可以按照它的字节的整数倍地址访问，比如一个double放在后边，那他前边的类型就会被填充为8的整数倍

```c++
struct AStruct {
	char a;
	uint32_t b;
	char c;
}; // sizeof = 12,因为第二个是4字节，为了访问时能以整数倍内存访问它，每个成员都填充为4字节

struct structB {
	char a;
	char c;
	uint32_t b;
}; // sizeof = 8   a和c可以放在同一个4字节内

struct structC {
	double a;
	char c;
	uint32_t b;
}; // sizeof =16, 8字节对齐，c占4字节，b占4字节组成第二个0字节


std::cout << alignof(structC) << std::endl;  // 输出对齐方式

```

## new和malloc

> malloc只做一件事，分配指定大小的内存`void* malloc(size_t size);`
>
> 而new创建内存后还会调用构造函数进行构造，delete也会进行析构
>
> 所以new是malloc的封装版，为了CPP构造和删除类实例时自动执行构造和析构函数

## 指针常量和常量指针

> 首先注意64位电脑上指针是8字节，一直以为是4字节。。。。

> 可以把(const int) * 这样来看，说明这个指针在指向一个const int的类型，它的内容肯定不能改
>
> int * (const ptr)   本质是int * 的指针，但是被const修饰，也就是指向不能改
> 太绕了，感觉过两天就忘了（事实是已经记过很多次了😄） 
>
> 总之看const右边是谁，谁就不能动，右边是int 数据不能改，右边是具体的ptr，ptr不能改指向

```c++
void PtrConstAndConstPtr()
{
	int a = 10;
	int b = 20;
	// const修饰指针，常量指针，可以修改指向，但不能修改内容
	const int* ptr = &a;
	ptr = &b; // 可以
	//*ptr = 20; // 不行

	// const修饰变量，指针常量，可以修改内容，但不能修改指针
	int* const ptr2 = &a;
	// ptr2 = &b;  不行
	*ptr2 = 20;
    std::cout << *ptr2 << std::endl;
}
```

## Struct和Class的区别

> struct默认是公有的，Class默认是私有的，继承也是这样

## Static

> 不在类内的情况：
>
> 不加static的全局变量和函数，可以在不同的文件中使用，比如两个.c文件`add_executable(test file1.c file2.c)`
>
> 加了static，只能在自己文件中访问
>
> `static int a;` 会自动初始化为0
>
> 函数内的static也会一直存在在静态区/全局区



> 类内的static：
>
> 类内定义，必须在类外初始化（这样设计：多个文件include了这个类的头文件，不希望都创建一份static，而是交给某一个具体的cpp文件单独进行一次初始化，不然每个包含的cpp都会有一个static变，导致重复定义）



## Const

> 不在类内的情况：
>
> const形参的函数，可以传const也可以传普通的
>
> 全局函数不能加const修饰符

> 类内的const:
>
> const成员变量：不能在类定义外部初始化，必须用初始化列表进行初始化（C11 可以直接在定义位置初始化）
>
> const成员函数：不能调用非const函数 `const int constFunc() {`是修饰返回值的，` int constFunc() const {`才是修饰这个函数的（内部可以使用普通的成员变量，但是不允许修改，除非这个变量被标记为mutable）

## 顶层和底层const

> 顶层const：修饰对象本身是个常量
>
> 底层const: 修饰对象所指向的数据是一个常量

## 初始化与赋值

> ```c++
> Class A;
> Class B = A;  // 这是初始化操作，会走拷贝构造函数
> Class C;
> C = A; // 这是赋值操作，会走重载的=逻辑，如果Class没有实现就会报错
> ```
>

## C++有几种构造函数

> C++类构造顺序是  父类构造->成员变量构造->构造函数

1. 默认构造
2. 带参数构造
3. 拷贝构造（注意需要在列表初始化中指定成员的拷贝构造，否则成员变量仍然走默认构造）、
4. 移动构造（自定义了拷贝构造，就不会默认生成移动构造了），移动构造的设计思路是转移other的数据，而不是拷贝他们，比如`	std::string anotherStr = std::move(str);`
5. 委托构造（交给其他构造器来执行）

## std::move和std::forward

std::move用于把左值转为右值引用

std::forward用于完美转发，比如如果我传入一个左值引用，就调用拷贝构造，如果是右值引用就调用移动构造，保证不会改变语义

```cpp

class Product {
public:
	Product() {
		print("默认构造");
	}
	Product(const Product & other) {
		print("拷贝构造");
	}
	Product(Product&& other) {
		print("移动构造");
	}
};

// 比如这个模板函数，可以自动处理左值和右值，相当于构造Product时自动根据是左值还是右值来选择拷贝构造还是移动构造
template<typename... Args>
std::unique_ptr<Product> createProduct(Args&&... args) {
	return std::make_unique<Product>(std::forward<Args>(args)...);
}

int main(){
	Product p;
	auto p1 = createProduct(p);
	auto p2 = createProduct(std::move(p));
}

// 打印
默认构造
拷贝构造     // 说明左值走拷贝
移动构造 	 // 说明右值走移动

// 如果不使用std::forward就会都走拷贝函数
```

## volatile

> 用来表示一个变量是易变的，每次用到这个变量的值的适合都要去重新读取这个变量的值，而不是读寄存器内的缓存数据，防止把多线程都会使用的变量装进CPU缓存

## explicit

> ```c++
> void funcNeedProduct(Product a) {
> 
> }
> class Product{
>    explicit Product(int a) {
> 	// explicit会阻止隐式转换
> 	// funcNeedProduct(10);   比如这里需要product但是传入10，隐式转换就会走这个构造，添加了explicit就不行了
> 	} 
> }
> 
> ```

## new的不同类型

> 普通的new
>
> ```c++
> try {
>     char* p = new char[10e11];
> }
> catch (std::bad_alloc & ex)   // new失败会抛出异常
> {
>     print(ex.what());
> }
> ```

> 无异常的new
>
> ```c++
> try {
> 	char* p = new(std::nothrow) char[10e11];   // 这样写后就不会抛出异常，而是返回nullptr
> }
> catch (std::bad_alloc & ex)
> {
> 	print(ex.what());
> }
> ```

> placement new
>
> 在一块已经存在的内存上分配对象，而不是调用一块新的，主要用途是反复使用一块内存来构建不同的对象
>
> ```c++
> void* someMemory = malloc(sizeof(100));
> Person* aPerson = new(someMemory) Person;
> 
> //delete aPerson;  // delete会释放空间，但这块空间不是aPerson申请的，会出现问题，不能这样用
> aPerson::~Person() // 手动析构即可
> 
> ```

## C++ 的异常处理机制 **try-catch-throw**

> throw 还能直接throw一个普通类型
>
> ```c++
> try {
> 	if (n == 0) {
> 		throw 0.1;
> 	}
> 	int a = m / n;
> }
> catch (double a) {  // 接收throw的double
> 	print("double");
> }  	
> catch (...) {  // 捕获任何类型
>     print("other");
> }
> 
> 
> void f() noexcept {  // 指明函数内不会抛出异常，如果抛出了直接中断程序，而不是往栈上传递   编译器可以基于 noexcept 做优化（如不生成异常处理表）
> void f() noexcept(false) {  // 指明可能抛出异常
>     
> void ExceptionFunc() throw(int,double){  // 指明抛出异常的类型
> 
> ```
>
> ![image-20260101141259274](image-20260101141259274.png)
>
> 一些内建的异常类型

## 静态变量的初始化时机

1. 全局静态变量：编译期就初始化好放在文件的特定位置
2. 类中的静态变量：同上
3. 函数中的静态变量：第一次调用时进行初始化

## C++ 类成员在定义处初始化 vs 构造函数初始化列表，哪种方式更快？

初始化列表更快

1️⃣ 成员定义处初始化（In-class member initializer）

```
struct A {
    int x = 5;
    std::string s = "hello";
};
A a;
```

- 编译器会把初始化“转化”为构造函数内的赋值操作
- 对于**内置类型（int, double…）**：
  - 直接初始化常量 → 编译期常量，生成的代码和初始化列表差不多
  - **性能差别几乎可以忽略**
- 对于**类类型（std::string, std::vector…）**：
  - 默认先调用默认构造函数初始化
  - 然后再执行赋值（赋值构造或拷贝） → 会多一次构造/赋值开销
  - 也就是可能比列表初始化慢一点

------

2️⃣ 构造函数初始化列表（Constructor initializer list）

```
struct A {
    int x;
    std::string s;
    A() : x(5), s("hello") {}
};
```

- **直接初始化成员对象**，没有先默认构造再赋值
- 对于类类型 → **比在类定义处初始化快**（避免多余默认构造）
- 对于内置类型 → 差别可以忽略

## ## C++的四种强制转换

1. `reinterpret_cast`：对二进制数据的重新解释，将一段内存的二进制位**原封不动**地解释为另一种类型
2. `const_cast`：只负责修改const、volatile这两个限定符，**不会改变变量的类型、内存布局或二进制值**，用处是给一个指针移除const或者添加const

```c++
	int num1 = 100;
	const int* ptr = &num1;
	//&ptr = 11; //  不可以 因为是常量指针
	int* non_const_ptr = const_cast<int*>(ptr);  // 转成普通指针后就行了
	*non_const_ptr = 200;
	print(num1);
```

3. `static_cast`：转换的合法性由编译器在编译阶段判断，运行时不检查，在继承关系中用于向上转换（安全），向下转换（不安全，没有动态类型检查 ，因为每个子类都有自己独有的东西，但是并不会报错，会输出垃圾值）、基本数据类型之间的转换、空指针类型转换
4. `dynamic_cast`:**唯一支持运行时类型检查**的转换方式。转换时会通过 “运行时类型信息（RTTI）” 判断实际对象类型，而非仅做编译时语法检查，如果向下转换不合法会返回空指针，an'quan
