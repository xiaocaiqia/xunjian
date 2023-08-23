#!/bin/bash

source ./bash/system.sh

# 二级菜单函数
secondary_menu() {
    local servers=("$@") # 将传入的所有参数作为一个数组
    printf "二级巡检菜单\n"
    printf "%7s1.巡检系统资源\n"
    printf "%7s2.巡检hcs程序\n"
    printf "%7s3.巡检系统资源和hcs程序\n"
    printf "%7s0.返回上级菜单\n"
    printf "请输入功能编号："

    read -r option
    case $option in
        1)
            # 在这里添加巡检系统资源的代码
            for system_target_ip in ${servers[@]}; do
                system_disk_space "$system_target_ip"
                system_date "$system_target_ip"
                cpu_mem_io "$system_target_ip"
            done
            ;;
        2)
            # 在这里添加巡检hcs程序的代码
            echo "正在对以下服务器进行hcs程序巡检：${servers[@]}"
            ;;
        3)
            # 在这里添加巡检全部的代码
            echo "正在对以下服务器进行全部巡检：${servers[@]}"
            ;;
        0)
            return 0
            ;;
        *)
            echo "无效选项"
            ;;
    esac
}