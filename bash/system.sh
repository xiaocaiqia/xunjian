#!/bin/bash

source ./bash/common_functions.sh   # 导入通用函数，如execute_commands

# system_disk_space 函数
# 功能：远程连接服务器，获取磁盘使用情况，并调用 log_output 输出到日志文件。
system_disk_space() {
    # 定义要检查的项目名称
    local check_items="disk_space"
    # 定义警告阈值
    local threshold=80
    # 定义要排除的挂载点，使用正则确保完全匹配
    local exclude_mounts=("^/mnt$" "^/other/mount1$" "^/other/mount2$")

    # 将排除的挂载点连接成一个正则表达式
    local exclude_pattern=$(IFS="|"; echo "${exclude_mounts[*]}")

    # 远程获取服务器的 df 信息并通过 awk 进行处理
    local awk_output=$(ssh ${ip} "df -m" | awk -v ip="$ip" -v check_items="$check_items" -v exclude="$exclude_pattern" '
    {
        # 如果不是第一行（标题行）、第二列为空、最后一列有值且不在排除列表中，则进行处理
        if (NR != 1 && $2 != "" && !($NF ~ exclude)) {
            printf "%s %s %s %s %s\n", ip, check_items, $1, $NF, $(NF-1)
        }
    }')

    # 调用 log_output 函数处理和输出结果
    log_output "$awk_output" "$threshold"
}


# system_date函数
# 功能：检查远程服务器的系统时间与当前服务器的时间差，并将结果输出到日志文件。
system_date(){
    # 定义要检查的项目名称
    local check_items="date"
    # 定义警告阈值
    local threshold=30

    # 使用Unix时间戳格式获取远程服务器的当前时间
    local remote_date=$(ssh ${ip} "date +%s")
    
    # 获取当前服务器的时间戳
    local local_date=$(date +%s)
    
    # 计算两个时间戳之间的差值，即远程服务器与当前服务器的时间差
    local time_diff=$((remote_date - local_date))
    
    # 取时间差的绝对值，确保差值为正数
    time_diff=${time_diff#-}

    # 格式化输出结果
    # 输出格式为：IP地址, 检查项目名称, NONE, NONE, 时间差值
    local formatted_output=$(printf "%s %s %s %s %ds\n" "$ip" "$check_items" "NONE" "NONE" "$time_diff")

    # 调用 log_output 函数处理输出结果
    # log_output函数会根据时间差与阈值比较，并将结果适当地输出到日志文件中
    log_output "$formatted_output" "$threshold"
}


# 定义sar命令开始时间
start_time="00:00:01"

# system_cpu函数
# 功能：检查远程服务器的CPU使用率，并将结果输出到日志文件。
system_cpu(){
    # 定义要检查的项目名称
    local check_items="cpu"
    # 定义警告阈值
    local threshold=80

    # 使用 LANG=C 确保远程命令的输出是非本地化的
    # 获取远程服务器的CPU使用率数据（从指定的开始时间至现在）
    local system_output=$(ssh ${ip} "LANG=C sar -u -s ${start_time}" | awk -v ip="$ip" -v check_items="$check_items" '
    {
        # 从第四行开始处理，因为之前的行可能包含其他不相关的信息（如标题行）
        if (NR >= 4){
            # 计算CPU使用率100% 减去空闲率
            use=(100-$NF)

            # 格式化输出数据，输出格式为: IP, 检查项目, NONE, 时间, 使用率
            printf "%s %s %s %s %d%%\n", ip, check_items, "NONE", $1, use
        }
    }')

    # 调用 log_output 函数处理输出结果
    # log_output 会根据阈值决定输出的颜色，并输出到适当的日志文件
    log_output "$system_output" "$threshold"
}

# system_mem函数
# 功能：检查远程服务器的内存使用率，并将结果输出到日志文件。
system_mem(){
    # 定义要检查的项目名称
    local check_items="mem"
    # 定义警告阈值
    local threshold=80

    # 使用sar命令获取内存使用情况
    local mem_info=$(ssh ${ip} "LANG=C sar -r -s ${start_time}")
    
    # 使用awk解析sar命令的输出
    local mem_usage=$(echo "$mem_info" | awk '
    {
        # 从sar输出中获取相关字段计算内存使用率
        if (NR >= 4){
            # 计算内存使用率
            use=($3-$5-$6)/($2+$3)*100
            
            # 格式化输出结果
            printf "%s %s %s %s %d%%\n", "'"${ip}"'", check_items, "NONE", $1, use
        }
    }')

    # 使用log_output函数处理并输出结果
    log_output "$mem_usage" "$threshold"
}

# system_disk_io函数
# 功能：检查远程服务器的磁盘IO使用率，并将结果输出到日志文件。
system_disk_io(){
    # 定义要检查的项目名称
    local check_items="disk_io"
    # 定义警告阈值
    local threshold=80

    # 使用sar命令获取磁盘IO情况
    local disk_io_info=$(ssh ${ip} "LANG=C sar -d -p -s ${start_time}")
    
    # 使用awk解析sar命令的输出
    local disk_io_usage=$(echo "$disk_io_info" | awk '
    {
        # 从sar输出中获取磁盘IO使用率
        if (NR >= 4){
            use=$10
            
            # 格式化输出结果
            printf "%s %s %s %s %d%%\n", "'"${ip}"'", check_items, $2, $1, use
        }
    }')

    # 使用log_output函数处理并输出结果
    log_output "$disk_io_usage" "$threshold"
}

# cpu_mem_io函数
# 功能：检查远程服务器是否安装了sysstat。如果已安装，则分别检查cpu、mem和disk_io的使用率。若未安装，则向日志中输出错误信息。
cpu_mem_io(){
    # 使用ssh远程查询是否安装了sysstat
    local sar_installed=$(ssh ${ip} "rpm -qa sysstat")

    # 判断是否安装了sysstat
    if [ -z "$sar_installed" ]; then
        # 如果没有安装sysstat，输出相关信息
        local no_sysstat_info=$(awk 'BEGIN {
            check_items="not_sysstat"
            # 格式化输出结果
            printf "%s %s %s %s %s\n", "'"${ip}"'", check_items, "NONE", "NONE", "100"
        }')

        # 使用log_output函数处理并输出结果，这里使用10作为阈值，确保红色显示
        log_output "$no_sysstat_info" "100"

    else
        # 如果安装了sysstat，则分别检查cpu、mem和disk_io的使用率
        system_cpu
        system_mem
        system_disk_io
    fi
}
