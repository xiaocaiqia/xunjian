#!/bin/bash

source ./bash/system.sh
source ./bash/hcs.sh

# 二级菜单函数
secondary_menu() {
    local servers=("$@") # 将传入的所有参数作为一个数组
    local sleep_duration=2
    printf "二级巡检菜单\n"
    printf "%7s1.巡检系统资源\n"
    printf "%7s2.巡检合成程序\n"
    printf "%7s3.巡检系统资源和hcs程序\n"
    printf "%7s0.返回上级菜单\n"
    printf "请输入功能编号："

    read -r option
    case $option in
        1)
            # 在这里添加巡检系统资源的代码
            for system_target_ip in ${servers[@]}; do
                echo ""
                echo "正在巡检服务器：$system_target_ip, 巡检类型：系统资源"
                system_disk_space "$system_target_ip" &
                system_date "$system_target_ip" &
                cpu_mem_io "$system_target_ip" &
                sleep $sleep_duration
            done
            wait                       # 等待所有并行命令完成
            print_result               # 输出结果
            ;;
        2)
            # 在这里添加巡检hcs程序的代码
            check_hcs_programs "${servers[@]}"
            wait                       # 等待所有并行命令完成
            print_result               # 输出结果
            ;;
        3)
            # 在这里添加巡检全部的代码
            for system_target_ip in ${servers[@]}; do
                echo ""
                echo "正在巡检服务器：$system_target_ip, 巡检类型：系统资源"
                system_disk_space "$system_target_ip"
                system_date "$system_target_ip"
                cpu_mem_io "$system_target_ip"
            done
            check_hcs_programs "${servers[@]}"
            wait                       # 等待所有并行命令完成
            print_result               # 输出结果
            ;;
        0)
            return 0
            ;;
        *)
            echo "无效选项"
            ;;
    esac
}