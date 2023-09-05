# 移动4G3.0合成巡检脚本

## 目录

- [简介](#简介)
- [环境要求](#环境要求)
- [依赖文件](#依赖文件)
- [主要功能](#主要功能)
- [配置文件](#配置文件)
- [使用方法](#使用方法)
- [运行流程](#运行流程)
  - [初始化](#初始化)
  - [服务器分类](#服务器分类)
  - [功能菜单](#功能菜单)
  - [二级菜单](#二级菜单)
- [巡检日志字段说明](#巡检日志字段说明)
- [问题](#问题)

## 简介

该脚本用于巡检不同类型的服务器（DIS、OUT、NAT）以及服务器上运行的各种程序。它提供了一个用户友好的菜单界面，允许用户选择巡检的服务器类型和巡检内容。

## 环境要求

- Linux 系统
- Bash 4.0 或更高版本
- SSH 免密码登录（用于远程巡检）

## 依赖文件

- `main.sh`: 主脚本文件
- `ip.txt`: 包含需要巡检的服务器 IP 地址
- `cmcc_hcs.cfg`: 合成程序（hcs）的配置文件
- `./bash/secondary_menu.sh`: 二级菜单脚本
- `./bash/common_functions.sh`: 公共函数脚本
- `./bash/system.sh`: 系统资源巡检脚本
- `./bash/hcs.sh`: 合成程序巡检脚本

## 主要功能

- CPU使用率检查
- 内存使用率检查
- 磁盘空间检查
- 磁盘IO检查
- 系统时间检查
- 日志文件检查
- 监听端口状态检查
- Redis 连接检查
- 落地文件检查

## 配置文件

- `cmcc_hcs.cfg`: 包含合成程序（hcs）的各种配置信息，如日志路径、配置文件路径等。只需根据现网环境修改 `BASE_PATH` 配置项即可。
- `ip.txt`：包含需要巡检的ip或host，每个ip或host使用换行符分隔。

## 使用方法

1. 确保 `cmcc_hcs.cfg` 文件与 `ip.txt` 文件配置正确。
2. 运行 `main.sh` 脚本。
3. 根据提示，选择需要巡检的服务器类型。
4. 在二级菜单中，选择需要巡检的内容。

## 运行流程

### 初始化

- 获取当前的日期和时间。
- 初始化 `./bash/server_type.cfg` 文件。
- 初始化 `./bash/items_config.cfg` 文件。

### 服务器分类

- 从 `./bash/server_type.cfg` 文件中读取服务器信息。
- 根据服务器类型（DIS、OUT、NAT）分类。

### 功能菜单

- 提供一个主菜单，允许用户选择巡检的服务器类型。
- 根据用户选择，调用相应的二级菜单函数。

### 二级菜单

- 提供一个二级菜单，允许用户选择巡检内容（系统资源、合成程序或两者）。
- 根据用户选择，执行相应的巡检任务。

## 巡检日志字段说明

|时间|IP|日志级别|检查项类型|自定义1|自定义2|巡检结果|
|-|-|-|-|-|-|-|
||||disk_space|文件系统|挂载目录|使用率|
||||date|NONE|NONE|时差|
||||cpu|NONE|检查时间|使用率|
||||mem|NONE|检查时间|使用率|
||||disk_io|磁盘分区|检查时间|使用率|
||||not_sysstat|NONE|NONE|NONE|
||||Log_Refresh_Time|程序名|日志文件名|时差|
||||Log_Errors|程序名|日志文件名|最新一条error日志或空|
||||SDTP_Path|程序名|hcsserver落地目录|文件数|
||||SDTP_Move_Path|程序名|hcsdis转移目录|文件数量,文件大小|
||||HCSOut_Directory|程序名|hcsout落地目录|文件数量,文件大小|
||||HCSNat_Directory|程序名|hcsnat落地目录|文件数量,文件大小|
||||Listening|程序名|IP:端口|监听端口的建联数|
||||Redis_Connection|程序名|IP:端口|ESTABLISHED/CLOSED|
||||Redis_Connections_Match|程序名|Mismatch/Match|监听端口建联数vs主动与redis建联数|
||||Output_Connection|程序名|IP:端口|ESTABLISHED/CLOSED|
||||Total_Output|程序名|Total_Output|总输出建联数|

## 问题

1. 初始化也要考虑做成并行执行
