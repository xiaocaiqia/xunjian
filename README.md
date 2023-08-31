# 移动4G3.0合成巡检脚本

## 目录

- [问题](#问题)
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


## 问题

1. 初始化也要考虑做成并行执行

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


