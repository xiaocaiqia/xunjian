#!/bin/bash

source ./bash/system.sh
source ./bash/hcs.sh


# 二级菜单函数
secondary_menu() {
    local servers=("$@") # 将传入的所有参数作为一个数组

    # 导入最大并行进程数配置max_jobs
    source ./bash/cmcc_hcs.cfg
    # 用于跟踪正在运行的进程数的文件
    local counter_file="./.counter_file.txt"
    echo 0 > $counter_file

    printf "二级巡检菜单\n"
    printf "%7s1.巡检系统资源\n"
    printf "%7s2.巡检合成程序\n"
    printf "%7s3.巡检系统资源和hcs程序\n"
    printf "%7s0.返回上级菜单\n"
    printf "请输入功能编号："

    read -r option
    case $option in
        1)
            for system_target_ip in ${servers[@]}; do
                run_job "do_system_work $system_target_ip" $counter_file
            done
            wait
            print_result
            ;;
        2)
            for system_target_ip in ${servers[@]}; do
                run_job "check_hcs_programs $system_target_ip" $counter_file
            done
            wait
            print_result
            ;;
        3)
            for system_target_ip in ${servers[@]}; do
                run_job "do_system_work $system_target_ip" $counter_file
                run_job "check_hcs_programs $system_target_ip" $counter_file
            done
            wait
            print_result
            ;;
        0)
            return 0
            ;;
        *)
            echo "无效选项"
            ;;
    esac
}

# 启动任务的函数
run_job() {
    local cmd="$1"
    local counter_file="$2"

    while true; do
        local running_jobs=$(< $counter_file)
        if (( running_jobs < max_jobs )); then
            (
                $cmd

                # 任务完成，递减计数器
                local current_count=$(< $counter_file)
                local new_count=$((current_count - 1))
                echo $new_count > $counter_file
            ) &
            
            # 递增计数器
            local new_count=$((running_jobs + 1))
            echo $new_count > $counter_file

            break
        else
            sleep 1
        fi
    done
}

# 工作函数
do_system_work() {
    local system_target_ip="$1"
    echo "正在巡检服务器：$system_target_ip, 巡检类型：系统资源"
    system_disk_space "$system_target_ip"
    system_date "$system_target_ip"
    cpu_mem_io "$system_target_ip"
}
