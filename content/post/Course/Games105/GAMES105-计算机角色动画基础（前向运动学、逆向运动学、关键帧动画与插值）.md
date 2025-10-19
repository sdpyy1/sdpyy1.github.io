+++
date = '2025-10-19T14:25:28+08:00'
draft = false
title = 'GAMES105 计算机角色动画基础（前向运动学、逆向运动学、关键帧动画与插值）'
categories = ["Course/Games105"]
tags = ["课程笔记","Games105"]
image = '9cd6da17016c4d8bb0a71ba5e8f44d0c.png'
+++
# 前向运动学
## 单链
每个关节的局部坐标系与全局坐标系重合

![在这里插入图片描述](30420a057d4b48d1ac427d38c5392200.png)

父关节的旋转会让子关节也跟着旋转
![在这里插入图片描述](487d233707f2467eb57598a1f1b105e9.png)
子关节的朝向就是夫关节朝向乘以自身的旋转
![在这里插入图片描述](c5ef766273b74f7798dcde2d2431193f.png)
只旋转R0时,Q1在Q0的局部坐标系下的坐标并不会变一直是l0,如果想求Q1的世界坐标,就是父关节的世界坐标加朝向*l0
![在这里插入图片描述](26526c4801494c039050d004bac0e624.png)
这一套东西就是用传播来更新,比如Q4的局部坐标系的某一个点,可以算出他在Q3的局部坐标系的位置,Q3的位置又能计算出他在Q2的位置,最终得到这个点在Q0的位置,最终再换算到世界坐标系,就得到了Q4局部坐标系下某一点在全局坐标系下的位置
这块比较好理解
![在这里插入图片描述](a3dd2947738740b8a3ed38487aace030.png)
BVH文件,用欧拉角表示旋转
![在这里插入图片描述](68e64229085948d2ac4ae0eae284d160.png)

```python
HIERARCHY
ROOT RootJoint  // 主结点
{
    OFFSET   0.000000   0.000000   0.000000
    CHANNELS 6 Xposition Yposition Zposition Xrotation Yrotation Zrotation // 主节点的位置和旋转信息
    JOINT lHip // 主关节内的子关节
    {
        OFFSET   0.100000  -0.051395   0.000000 // 子关节相对于主关节局部坐标系的偏移量
        CHANNELS 3 Xrotation Yrotation Zrotation // 欧拉角表示的旋转
        JOINT lKnee // 子关节的子关节 一层一层嵌套
        {
            OFFSET   0.000000  -0.410000   0.000000
            CHANNELS 3 Xrotation Yrotation Zrotation
            JOINT lAnkle
            {
                OFFSET   0.000000  -0.390000   0.000000
                CHANNELS 3 Xrotation Yrotation Zrotation
                JOINT lToeJoint
                {
                    OFFSET   0.000000  -0.050000   0.130000
                    CHANNELS 3 Xrotation Yrotation Zrotation
                    End Site
                    {
                        OFFSET   0.010000   0.002000   0.060000
                    }
                }
            }
        }
    }
```
一行MOTION信息按照上边给的关节顺序和通道数给出一帧的旋转信息
```python
  1.471305   0.917570   2.607916   0.000000   0.000000   0.000000   0.000000   0.000000   0.000000   0.000000   0.000000   0.000000   0.000000   0.000000   0.000000   0.000000   0.000000   0.000000   0.000000   0.000000   0.000000   0.000000   0.000000   0.000000   0.000000   0.000000   0.000000   0.000000   0.000000   0.000000   0.000000   0.000000   0.000000   0.000000   0.000000   0.000000   0.000000   0.000000   0.000000   0.000000   0.000000   0.000000   0.000000   0.000000  45.000000   0.000000   0.000000   0.000000   0.000000   0.000000   0.000000   0.000000   0.000000   0.000000   0.000000   0.000000 -45.000000   0.000000   0.000000   0.000000   0.000000   0.000000   0.000000

```

## 前向运动学作业
### 1. 解析BVH文件
BVH存储的是每个关节相对于父关节的旋转(欧拉角)和位置偏移
```python
def part1_calculate_T_pose(bvh_file_path):
    """
    输入： bvh 文件路径
    输出:
        joint_name: List[str]，字符串列表，包含着所有关节的名字
        joint_parent: List[int]，整数列表，包含着所有关节的父关节的索引,根节点的父关节索引为-1
        joint_offset: np.ndarray，形状为(M, 3)的numpy数组，包含着所有关节的偏移量
    """
    joint_name = []
    joint_parent = []
    joint_offset = []
    parent_stack = []  # 用于跟踪当前关节的父级层次
    current_parent = -1  # 根节点的父节点索引为-1

    # 读取BVH文件内容
    with open(bvh_file_path, 'r') as f:
        lines = [line.strip() for line in f if line.strip()]

    # 定位层次结构部分（HIERARCHY到MOTION之间的内容）
    hierarchy_start = None
    hierarchy_end = None
    for i, line in enumerate(lines):
        if line.upper() == 'HIERARCHY':
            hierarchy_start = i + 1
        elif line.upper() == 'MOTION' and hierarchy_start is not None:
            hierarchy_end = i
            break

    if hierarchy_start is None or hierarchy_end is None:
        raise ValueError("BVH文件格式错误，未找到层次结构或运动数据部分")

    # 解析层次结构
    for line in lines[hierarchy_start:hierarchy_end]:
        tokens = line.split()
        if not tokens:
            continue

        if tokens[0].upper() == 'ROOT':
            # 处理根节点
            joint_name.append(tokens[1])
            joint_parent.append(-1)
            parent_stack.append(len(joint_name) - 1)
            current_parent = len(joint_name) - 1

        elif tokens[0].upper() == 'JOINT':
            # 处理子关节
            joint_name.append(tokens[1])
            joint_parent.append(current_parent)
            parent_stack.append(len(joint_name) - 1)
            current_parent = len(joint_name) - 1

        elif tokens[0].upper() == 'OFFSET':
            # 处理偏移量（T姿态下的位置偏移）
            offset = np.array([float(tokens[1]), float(tokens[2]), float(tokens[3])])
            joint_offset.append(offset)

        elif tokens[0].upper() == 'END' and tokens[1].upper() == 'SITE':
            # 处理末端节点
            end_joint_name = f"{joint_name[current_parent]}_end"
            joint_name.append(end_joint_name)
            joint_parent.append(current_parent)
            parent_stack.append(len(joint_name) - 1)
            current_parent = len(joint_name) - 1

        elif tokens[0] == '}':
            # 层级结束，返回上一级父节点
            if parent_stack:
                parent_stack.pop()
                current_parent = parent_stack[-1] if parent_stack else -1

    # 转换为numpy数组
    joint_offset = np.array(joint_offset)

    return joint_name, joint_parent, joint_offset
```
![在这里插入图片描述](b4c4695c429a408d894e4cac371cbc93.png)
### 2. 前向运动学计算
读入BVH文件中每一帧的动作数据, 计算每个关节在世界坐标系下的旋转和位置。

```python
def part2_forward_kinematics(joint_name, joint_parent, joint_offset, motion_data, frame_id):
    """请填写以下内容
    输入: part1 获得的关节名字，父节点列表，偏移量列表
        motion_data: np.ndarray，形状为(N,X)的numpy数组，其中N为帧数，X为Channel数
        frame_id: int，需要返回的帧的索引
    输出:
        joint_positions: np.ndarray，形状为(M, 3)的numpy数组，包含着所有关节的全局位置
        joint_orientations: np.ndarray，形状为(M, 4)的numpy数组，包含着所有关节的全局旋转(四元数)
    Tips:
        1. joint_orientations的四元数顺序为(x, y, z, w)
        2. from_euler时注意使用大写的XYZ
    """
    bone_num = len(joint_name)

    # 记录所有关节的全局位置
    joint_positions = np.empty((bone_num, 3))
    # 记录所有关节的全局旋转(四元数)
    joint_orientations = np.empty((bone_num, 4))
    # 一帧的所有旋转数据和主关节的位置信息
    motion_data_oneFrame = motion_data[frame_id]

    # 主关节的位置信息
    joint_positions[0] = motion_data_oneFrame[:3]
    # 主关节的旋转(从欧拉角转为四元数)
    joint_orientations[0] = R.from_euler('XYZ', motion_data_oneFrame[3:6], degrees=True).as_quat()

    frame_count = 1
    for i in range(1, bone_num):
        # 当前关节的父关节id
        p = joint_parent[i]
        cur_rotate = None
        if joint_name[i].endswith('_end'):
            # _end表示一条关节链的终点位置
            cur_rotate = R.from_euler('XYZ', [0., 0., 0.], degrees=True)
        else:
            cur_rotate = R.from_euler('XYZ', motion_data_oneFrame[3 + frame_count * 3: 6 + frame_count * 3],
                                      degrees=True)
            frame_count += 1

        # 父关节的旋转信息
        p_orient = R.from_quat(joint_orientations[p])
        # 当前位置的旋转 = 父关节的旋转 * 当前关节的旋转
        joint_orientations[i] = (p_orient * cur_rotate).as_quat()
        # 当前位置 = 父关节的全局位置 + 父关节的旋转 * 当前关节在父关节旋转方向上的偏移
        joint_positions[i] = joint_positions[p] + np.dot(R.from_quat(joint_orientations[p]).as_matrix(),
                                                         joint_offset[i])

    return joint_positions, joint_orientations

```

### 3. 运动重定向
读入一个A-Pose的文件, 将A-pose的bvh重定向到T-pose上
意思是 骨骼信息来自T-pose,但是一帧的旋转信息来自A-pose的文件. 
`    retarget_motion_data = part3_retarget_func(T_pose_bvh_path, A_pose_bvh_path)
`用来把A-pose给出的旋转信息重定向到T-pose的骨骼上. 处理办法就是遍历到肩膀肘手腕时要额外处理旋转信息

```python
def part3_retarget_func(T_pose_bvh_path, A_pose_bvh_path):
    """
    将 A-pose的bvh重定向到T-pose上
    输入: 两个bvh文件的路径
    输出: 
        motion_data: np.ndarray，形状为(N,X)的numpy数组，其中N为帧数，X为Channel数。retarget后的运动数据
    Tips:
        两个bvh的joint name顺序可能不一致哦(
        as_euler时也需要大写的XYZ
    """

    def index_bone_to_channel(index, flag):
        if flag == 't':
            end_bone_index = end_bone_index_t
        else:
            end_bone_index = end_bone_index_a
        for i in range(len(end_bone_index)):
            if end_bone_index[i] > index:
                return index - i
        return index - len(end_bone_index)

    def get_t2a_offset(bone_name):
        l_bone = ['lShoulder', 'lElbow', 'lWrist']
        r_bone = ['rShoulder', 'rElbow', 'rWrist']
        if bone_name in l_bone:
            return R.from_euler('XYZ', [0., 0., 45.], degrees=True)
        if bone_name in r_bone:
            return R.from_euler('XYZ', [0., 0., -45.], degrees=True)
        return R.from_euler('XYZ', [0., 0., 0.], degrees=True)

    motion_data = load_motion_data(A_pose_bvh_path)

    t_name, t_parent, t_offset = part1_calculate_T_pose(T_pose_bvh_path)
    a_name, a_parent, a_offset = part1_calculate_T_pose(A_pose_bvh_path)

    end_bone_index_t = []
    for i in range(len(t_name)):
        if t_name[i].endswith('_end'):
            end_bone_index_t.append(i)

    end_bone_index_a = []
    for i in range(len(a_name)):
        if a_name[i].endswith('_end'):
            end_bone_index_a.append(i)

    for m_i in range(len(motion_data)):
        frame = motion_data[m_i]
        cur_frame = np.empty(frame.shape[0])
        cur_frame[:3] = frame[:3]
        for t_i in range(len(t_name)):
            cur_bone = t_name[t_i]
            a_i = a_name.index(t_name[t_i])
            if cur_bone.endswith('_end'):
                continue
            channel_t_i = index_bone_to_channel(t_i, 't')
            channel_a_i = index_bone_to_channel(a_i, 'a')

            # retarget
            local_rotation = frame[3 + channel_a_i * 3: 6 + channel_a_i * 3]
            if cur_bone in ['lShoulder', 'lElbow', 'lWrist', 'rShoulder', 'rElbow', 'rWrist']:
                p_bone_name = t_name[t_parent[t_i]]
                Q_pi = get_t2a_offset(p_bone_name)
                Q_i = get_t2a_offset(cur_bone)
                local_rotation = (Q_pi * R.from_euler('XYZ', local_rotation, degrees=True) * Q_i.inv()).as_euler('XYZ',
                                                                                                                 degrees=True)
            cur_frame[3 + channel_t_i * 3: 6 + channel_t_i * 3] = local_rotation

        motion_data[m_i] = cur_frame

    return motion_data

```
![在这里插入图片描述](9cd6da17016c4d8bb0a71ba5e8f44d0c.png)
# 逆向运动学
已知运动结果求每一个关节的旋转
![在这里插入图片描述](523c2740ff8a489bbf301e897f189a11.png)
IK问题可以有解、无解、多解
![在这里插入图片描述](5e31c5f9ee3d4b41bcbe530f51958de1.png)
## 双关节问题
下图两个虚线圆的交点就是关节1应该去的位置，到达后旋转关节1，肯定能让关节2到达指定位置
![在这里插入图片描述](09191a1412b7413cb8b4b24f031951c3.png)

另外一种思路：
![在这里插入图片描述](9ee2f77744404313b353f6b4e0be5ba9.png)
1. 移动关节1，让0-2的距离= 0到x的距离
![在这里插入图片描述](dff6e1244c5e4a85a1e318edc2404993.png)
再旋转关节0即可
![在这里插入图片描述](e3984243737a40ee8295c55bd1c75fc2.png)
在三维下绕着0x为轴旋转即可
![在这里插入图片描述](46d4bc76f25f46fa9198e4e6408ad15a.png)
## 多关节最优化问题
只考虑末端点到达指定位置的问题，建模成 **通过各个关节的旋转，得到末端点位置的这个函数**
![在这里插入图片描述](f42d20f408024c66b807662f62c181c2.png)
求解问题就是：就是找到各关节的旋转使得目标点位置-公式求解的末端点位置=0
这个方程有没有根 ![在这里插入图片描述](a83a39c75e6d44b28505bc38fe51b669.png)
等价的可以转化为一个优化问题，优化问题取极值
![在这里插入图片描述](8d0ddd126ff34be3ad0ba4905bf04f05.png)
![在这里插入图片描述](daaebb3f845246a19d2ff1c00482f0d6.png)
求解问题到这里就变成了函数求极值的问题
![在这里插入图片描述](59f12c68be1f4f8ca5caf06bc19e5b46.png)
### 优化问题下降方法
#### 1. 循环坐标下降法 CCD
认为参数的坐标轴方向为下降方向，不断交换坐标轴。 其实就是每次只更新一个参数（一个旋转角度）
![在这里插入图片描述](7bab171e461a44c3bdc96608ae6d92cc.png)
CCD放在IK来解释就是每次只旋转一个关节
下图就是只旋转3，让3-4朝向正确（也就是寻找了x离目标位置最近的位置）
![在这里插入图片描述](b8103f4217204a0eb70cc6f78da8302d.png)

下一步旋转关节2
![在这里插入图片描述](aaf51c0f1d8e4c7a88014c5f9cecb5c1.png)
依此类推
![在这里插入图片描述](b31cd73e4a4b4100b70025bdf97d8cf0.png)
之后再回到4关节进行循环
![在这里插入图片描述](8d495bf0c26e49e3b095a8899fe78f78.png)
#### 2.  梯度下降（雅可比转置法）
CCD没有考虑到目标函数的性质，直接找负梯度方向就可以更快的下降
![在这里插入图片描述](a1bb1fda63424be8a95f5ee62979d73b.png)
也就是说每个参数的更新方向都是下降最快的方向![在这里插入图片描述](e4ebf4f5fe21425f82803dda0393847b.png)
参数的更新公式
![在这里插入图片描述](3c958e0be7a347f098c0f43a1badccab.png)
红色的这一项是控制梯度更新是往正方向还是负方向（因为下降过头还得回来）
![在这里插入图片描述](d5cbec56d7f04707b1036b396aef142f.png)
前边梯度的倒数构成的矩阵也可以叫做雅可比矩阵（f对每个参数求导的结果组成的矩阵）
![在这里插入图片描述](086df6c95162428c814ec88e36cf060a.png)
下降梯度法也可以就雅可比转置法。
对于IK问题，他输出是一个点，是三维的输出（x,y,z）所以雅可比矩阵应该是三维的
![在这里插入图片描述](b45b38c520104f5ba5bd8bcd6365baff.png)
![在这里插入图片描述](0d7028d05b824fc08e40b90d524b2c45.png)
##### 雅可比矩阵计算方法
1. 调库！！！
2. 有限差分（用前向运动学运动依次来获得数据填充矩阵，看不懂。。。。）
![在这里插入图片描述](0bdd5647b2a84cc19081b7e3a4e65443.png)
3. 几何方法
（针对单自由度关节）这里应该是当一个关节旋转一个很小的角度时，把罗德里格斯旋转公式求出目标点，取极限求出来的就是雅可比矩阵的一项
![在这里插入图片描述](9ca61d9917d745799f1546d4cd652f48.png)
（针对ball 3自由度的关节）很难理解的，选择不理解，知道是可以的就行
![在这里插入图片描述](346ecc4e5d2545a58626414074e7df36.png)
![在这里插入图片描述](b04f38a3641c4be99b353d7ae8b9e9fc.png)
#### 3.  高斯-牛顿法
最优化学过。。忘了，这里选择不回忆
![在这里插入图片描述](6a1ebe08306a44dba0156749759741cc.png)
![在这里插入图片描述](aff67403181642ca985180be00ce10e7.png)
#### 4.  雅可比逆方法
。。。听个响![](33850882bb744ab6a7088f7923a5b08e.png)
听个。。
![在这里插入图片描述](21260fddf90a4ea385c6696d49e9d117.png)

## 角色的IK
更复杂的优化问题。 每个目标点都对应上一节一个优化目标，最后相加。还需要加一个正则项，约束各个关节的旋转
![在这里插入图片描述](3ac34f45d8f5453385d3d1406f6c5851.png)
## 逆向运动学作业
def load_motion_data(bvh_file_path):
    """part2 辅助函数，读取bvh文件"""
    with open(bvh_file_path, 'r') as f:
        lines = f.readlines()
        for i in range(len(lines)):
            if lines[i].startswith('Frame Time'):
                break
        motion_data = []
        for line in lines[i + 1:]:
            data = [float(x) for x in line.split()]
            if len(data) == 0:
                break
            motion_data.append(np.array(data).reshape(1, -1))
        motion_data = np.concatenate(motion_data, axis=0)
    return motion_data


def rotation_matrix(a, b):
    a = a / np.linalg.norm(a)
    b = b / np.linalg.norm(b)
    n = np.cross(a, b)
    # 旋转矩阵是正交矩阵，矩阵的每一行每一列的模，都为1；并且任意两个列向量或者任意两个行向量都是正交的。
    # n=n/np.linalg.norm(n)
    # 计算夹角
    cos_theta = np.dot(a, b)
    sin_theta = np.linalg.norm(n)
    theta = np.arctan2(sin_theta, cos_theta)
    # 构造旋转矩阵
    c = np.cos(theta)
    s = np.sin(theta)
    v = 1 - c
    rotation_matrix = np.array([[n[0] * n[0] * v + c, n[0] * n[1] * v - n[2] * s, n[0] * n[2] * v + n[1] * s],
                                [n[0] * n[1] * v + n[2] * s, n[1] * n[1] * v + c, n[1] * n[2] * v - n[0] * s],
                                [n[0] * n[2] * v - n[1] * s, n[1] * n[2] * v + n[0] * s, n[2] * n[2] * v + c]])
    return rotation_matrix


def inv_safe(data):
    # return R.from_quat(data).inv()
    if np.allclose(data, [0, 0, 0, 0]):
        return np.eye(3)
    else:
        return np.linalg.inv(R.from_quat(data).as_matrix())


def from_quat_safe(data):
    # return R.from_quat(data)
    if np.allclose(data, [0, 0, 0, 0]):
        return np.eye(3)
    else:
        return R.from_quat(data).as_matrix()


def part1_inverse_kinematics(meta_data, joint_positions, joint_orientations, target_pose):
    """
    完成函数，计算逆运动学
    输入:
        meta_data: 为了方便，将一些固定信息进行了打包，见上面的meta_data类
        joint_positions: 当前的关节位置，是一个numpy数组，shape为(M, 3)，M为关节数
        joint_orientations: 当前的关节朝向，是一个numpy数组，shape为(M, 4)，M为关节数
        target_pose: 目标位置，是一个numpy数组，shape为(3,)
    输出:
        经过IK后的姿态
        joint_positions: 计算得到的关节位置，是一个numpy数组，shape为(M, 3)，M为关节数
        joint_orientations: 计算得到的关节朝向，是一个numpy数组，shape为(M, 4)，M为关节数
    """
    path, path_name, path1, path2 = meta_data.get_path_from_root_to_end()
    parent_idx = meta_data.joint_parent
    # local_rotation是用于最后计算不在链上的节点
    no_caled_orientation = copy.deepcopy(joint_orientations)
    local_rotation = [
        R.from_matrix(inv_safe(joint_orientations[parent_idx[i]]) * from_quat_safe(joint_orientations[i])).as_quat() for
        i
        in range(len(joint_orientations))]
    local_rotation[0] = R.from_matrix(from_quat_safe(joint_orientations[0])).as_quat()
    local_position = [joint_positions[i] - joint_positions[parent_idx[i]] for i
                      in range(len(joint_orientations))]
    local_position[0] = joint_positions[0]

    path_end_id = path1[0]  ## lWrist_end 就是手掌 只是加了end不叫hand而已
    for k in range(0, 300):
        # k：循环次数
        # 正向的，path1是从手到root之前
        for idx in range(0, len(path1)):
            # idx：路径上的第几个节点了，第0个是手，最后一个是root
            path_joint_id = path1[idx]

            vec_to_end = joint_positions[path_end_id] - joint_positions[path_joint_id]
            vec_to_target = target_pose - joint_positions[path_joint_id]
            # 获取end->target的旋转矩阵
            # debug
            # rot_matrix=rotation_matrix(np.array([1,0,0]),np.array([1,1,0]))
            rot_matrix = rotation_matrix(vec_to_end, vec_to_target)

            # 计算前的朝向。这个朝向实际上是累乘到父节点的
            initial_orientation = from_quat_safe(joint_orientations[path_joint_id])
            # 旋转矩阵，格式换算
            rot_matrix_R = R.from_matrix(rot_matrix).as_matrix()
            # 计算后的朝向
            calculated_orientation = rot_matrix_R.dot(initial_orientation)
            # 写回结果列表
            joint_orientations[path_joint_id] = R.from_matrix(calculated_orientation).as_quat()

            # 子节点的朝向也会有所变化
            # idx-1 就是当前节点的下一个更接近尾端的节点，一直向前迭代到1
            for i in range(idx - 1, 0, -1):
                path_joint_id = path1[i]
                # 遍历路径后的节点,都乘上旋转
                joint_orientations[path_joint_id] = R.from_matrix(
                    rot_matrix_R.dot(from_quat_safe(joint_orientations[path_joint_id]))).as_quat()

            path_joint_id = path1[idx]
            # 修改子节点的位置
            for i in range(idx - 1, -1, -1):
                # path_joint_id=path1[i]
                # 节点id
                next_joint_id = path1[i]
                # 指向下个节点的向量
                vec_to_next = joint_positions[next_joint_id] - joint_positions[path_joint_id]
                # 左乘，改变向量
                calculated_vec_to_next_dir = rot_matrix.dot(vec_to_next)
                # 防止长度不对
                calculated_vec_to_next = calculated_vec_to_next_dir / np.linalg.norm(
                    calculated_vec_to_next_dir) * np.linalg.norm(vec_to_next)
                # 还原回去
                joint_positions[next_joint_id] = calculated_vec_to_next + joint_positions[path_joint_id]

        # path2是从脚到root，所以要倒着
        # debug
        # for idx in range(len(path2)-1,len(path2)-3,-1): # len(path2)-1 --> 0
        for idx in range(len(path2) - 1, 0, -1):  # len(path2)-1 --> 0
            path_joint_id = path2[idx]
            parient_joint_id = max(parent_idx[path_joint_id], 0)

            vec_to_end = joint_positions[path_end_id] - joint_positions[path_joint_id]
            vec_to_target = target_pose - joint_positions[path_joint_id]
            # 获取end->target的旋转矩阵
            # debug
            # rot_matrix=rotation_matrix(np.array([0.72,0.35,0]),np.array([0.5,0.35,0]))
            # rot_matrix=np.linalg.inv(rot_matrix)
            rot_matrix = rotation_matrix(vec_to_end, vec_to_target)

            # 计算前的朝向。注意path2是反方向的，要改父节点才行
            initial_orientation = from_quat_safe(joint_orientations[path_joint_id])
            # 旋转矩阵，格式换算
            rot_matrix_R = R.from_matrix(rot_matrix).as_matrix()
            # 计算后的朝向
            calculated_orientation = rot_matrix_R.dot(initial_orientation)
            # 写回结果列表
            joint_orientations[path_joint_id] = R.from_matrix(calculated_orientation).as_quat()

            # 其他节点的朝向也会有所变化
            for i in range(idx + 1, len(path2)):
                path_joint_id = path2[i]
                joint_orientations[path_joint_id] = R.from_matrix(
                    rot_matrix_R.dot(from_quat_safe(joint_orientations[path_joint_id]))).as_quat()

            # idx-1 就是当前节点的下一个更接近尾端的节点，一直向前迭代到1
            for i in range(len(path1) - 1, 0, -1):
                path_joint_id = path1[i]
                # 遍历路径后的节点,都乘上旋转
                joint_orientations[path_joint_id] = R.from_matrix(
                    rot_matrix_R.dot(from_quat_safe(joint_orientations[path_joint_id]))).as_quat()

            path_joint_id = path2[max(idx - 1, 0)]
            # 修改父节点，或者说更靠近手的那些节点的位置
            # path2上的
            for i in range(idx, len(path2)):
                # path_joint_id=path1[i]
                # 节点id
                prev_joint_id = path2[i]
                # 指向上一个节点的向量
                vec_to_next = joint_positions[prev_joint_id] - joint_positions[path_joint_id]
                # 左乘，改变向量
                calculated_vec_to_next_dir = rot_matrix.dot(vec_to_next)
                # 防止长度不对
                calculated_vec_to_next = calculated_vec_to_next_dir / np.linalg.norm(
                    calculated_vec_to_next_dir) * np.linalg.norm(vec_to_next)
                # 还原回去
                joint_positions[prev_joint_id] = joint_positions[path_joint_id] + calculated_vec_to_next
            # path1上的
            for i in range(len(path1) - 1, -1, -1):
                # path_joint_id=path1[i]
                # 节点id
                prev_joint_id = path1[i]
                # 指向上一个节点的向量
                vec_to_next = joint_positions[prev_joint_id] - joint_positions[path_joint_id]
                # 左乘，改变向量
                calculated_vec_to_next_dir = rot_matrix.dot(vec_to_next)
                # 防止长度不对
                calculated_vec_to_next = calculated_vec_to_next_dir / np.linalg.norm(
                    calculated_vec_to_next_dir) * np.linalg.norm(vec_to_next)
                # 还原回去
                joint_positions[prev_joint_id] = calculated_vec_to_next + joint_positions[path_joint_id]

        # debug
        # rot_matrix=rotation_matrix(np.array([1,0,0]),np.array([1,0,1]))
        # joint_orientations[0]=R.from_matrix(rot_matrix).as_quat()
        # joint_orientations[1]=R.from_matrix(rot_matrix).as_quat()
        joint_orientations[path_end_id] = joint_orientations[path1[1]]
        cur_dis = np.linalg.norm(joint_positions[path_end_id] - target_pose)
        if cur_dis < 0.01:
            break
    print("距离", cur_dis, "迭代了", k, "次")
    # 更新不在链上的节点
    for k in range(len(joint_orientations)):
        if k in path:
            pass
        elif k == 0:
            # 要单独处理，不然跟节点的-1就会变成从最后一个节点开始算
            pass
        else:
            # 先获取局部旋转
            # 这里如果直接存的就是矩阵就会有问题？
            local_rot_matrix = R.from_quat(local_rotation[k]).as_matrix()
            # 再获取我们已经计算了的父节点的旋转
            parent_rot_matrix = from_quat_safe(joint_orientations[parent_idx[k]])
            # 乘起来
            # re=local_rot_matrix.dot(parent_rot_matrix)
            re = parent_rot_matrix.dot(local_rot_matrix)
            joint_orientations[k] = R.from_matrix(re).as_quat()

            # 父节点没旋转的时候是：
            initial_o = from_quat_safe(no_caled_orientation[parent_idx[k]])
            # 父节点的旋转*delta_orientation=子节点旋转
            # 反求delta_orientation
            delta_orientation = np.dot(re, np.linalg.inv(initial_o))
            # 父节点的位置加原本基础上的旋转
            joint_positions[k] = joint_positions[parent_idx[k]] + delta_orientation.dot(local_position[k])

    return joint_positions, joint_orientations












# 关键帧插值
给出一系列离散的值后，寻找一个f(x),首先满足已有的点都在f(x)上，另外要能计算其他的未给出的x的f(x)
![在这里插入图片描述](4ab8167d086641ae88099a898c09df2e.png)
## 梯度函数
![在这里插入图片描述](c009bf351cde4c5fb7bb4a1e77f171a2.png)
也可以是离当前点最近的点的值作为f(x)
![在这里插入图片描述](f5df7d93340e407fb4ed42fb0e09eebc.png)

## 线性插值函数
直接用直线连接已知点
![在这里插入图片描述](406f498e5b85496cac6c4e98ba6e49dc.png)
![在这里插入图片描述](15117e860a2142ac9245283827ace5cc.png)
### 线性插值的平滑性
![在这里插入图片描述](d51108c9114540598f2f95a026d9388f.png)
![在这里插入图片描述](deb1999fb8824fef9509505dba7418bb.png)
## 多项式插值 Polynomial Interpolation 
![在这里插入图片描述](5ddbccd8457e4d459972ecffc786d58a.png)
计算参数就是把已知点带进去
![在这里插入图片描述](d372c045005b4bdbb0bb6d60f171b9c4.png)
然后用矩阵求解。 这里就能看出需要多少个采样点
![在这里插入图片描述](18e43c512d2346d9a17e8ae3bdafa8e7.png)
把矩阵求逆就可以求出参数a
![在这里插入图片描述](b7ad98fd79554f44a457f438aac0a76b.png)

**Runge's phenomenon**：当使用等距节点对某些光滑函数进行高次多项式插值时，随着插值多项式次数的增加，多项式在区间端点附近会出现剧烈的振荡，导致插值误差不仅不减小，反而会急剧增大，最终完全偏离原函数。
下图靠近两边的点中间插值出现了非常巨大的震荡（原因是接近1时，x的高次方会变得很大，如果还是使用**等距插值**就会出问题）
![在这里插入图片描述](01cf9890b6474a47a01f866482512ae6.png)
## 样条插值 Spline Interpolation
只在单独几个采样点上用低阶多项式插值
![在这里插入图片描述](fcd34f02bada4671bacb8287547a5cd1.png)
常用的是Cubic Splines （三次样条插值）
![在这里插入图片描述](3fab4c877b7b47a7bbb8057296033dad.png)
计算时只需要相邻的两个采样点计算依次多项式参数。
如果总采样点是N+1，那一共有N段，每段都是一个三次多项式。每个多项式4个未知参数。所以一共有4N个未知参数。
![在这里插入图片描述](4790b9f7979c487f803d56a18b773c99.png)
2个采样点信息没办法求出4个未知数。样条采样引入了别的规则。
1. 两段之间的采样点的在两个多项式的导数相同
2. 二阶导也相同
3. 对整条曲线的边缘点的一阶二阶导数一些额外限制



## 三次埃尔米特样条 Cubic Hermite Splines
**Cubic Splines问题是只要移动一个点，都可能发生整条曲线的变化，求解也比较昂贵**

Cubic Hermite Splines的做法是除了给出两个采样点外，还需要额外告诉两个点的导数

![在这里插入图片描述](ad7da6c9a3b54b8d8e10b14875a936cc.png)
总结就是 4个方程4个未知数
![在这里插入图片描述](431e38372bf44abaa65f519f88fad3d0.png)
![在这里插入图片描述](f243ca6de7ea4264840c08951b771522.png)
矩阵的逆都一步到位了，一次矩阵乘法就直接求解4个位置系数
![在这里插入图片描述](9f814d58223a4ccfb2b3fa816ffdd56c.png)
还可以把多项式直接写出矩阵形式
![在这里插入图片描述](91e86cc0e00d461d9a3ba6f0041721c5.png)
## 旋转的插值
旋转的四种表示方法：
- 旋转矩阵
- 欧拉角
- 轴角
- 四元数

下面两种旋转表达旋转速度插值不是恒定的
![在这里插入图片描述](72fbd1c6d1c74e8ca344732c2c35fe8e.png)
用四元数的slerp来恒定速度（但线性插值并单位化四元数来插值不恒定）