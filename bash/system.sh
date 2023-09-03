#!/bin/bash

source ./bash/common_functions.sh   # 导入通用函数，如execute_commands

# system_disk_space 函数
# 功能：远程连接服务器，获取磁盘使用情况，并调用 log_output 输出到日志文件。
system_disk_space() {
    local ip="$1"  # 使用传入的参数设置本地变量ip
    # 定义要检查的项目名称
    local check_items="disk_space"
    # 定义警告阈值
    local threshold=80
    # 导入要排除的挂载点exclude_mounts
    source ./bash/cmcc_hcs.cfg
    

    # 将排除的挂载点连接成一个正则表达式
    local exclude_pattern=$(IFS="|"; echo "${exclude_mounts[*]}")

    # 远程获取服务器的 df 信息并通过 awk 进行处理
    local awk_output=$(ssh ${ip} "df -m" | awk -v ip="$ip" -v check_items="$check_items" -v exclude="$exclude_pattern" -v threshold="$threshold" '
    {
        # 如果不是第一行（标题行）、第二列为空、最后一列有值且不在排除列表中，则进行处理
        if (NR != 1 && $2 != "" && !($NF ~ exclude)) {

            # 移除 '%' 以将使用率转换为整数
            gsub(/%/, "", $(NF-1))

            # 判断是否超出阈值
            if ($(NF-1) > threshold) {
                log_level="ERROR"
            } else {
                log_level="INFO"
            }
            printf "%s %s %s %s %d%% %s===", ip, check_items, $1, $NF, $(NF-1), log_level
        }
}')

    # 将 awk 输出转换为数组
    IFS=$'===' read -ra lines <<< "$awk_output"

    for line in "${lines[@]}"; do
        IFS=' ' read -ra parts <<< "$line"
        log_output "${parts[0]}" "${parts[1]}" "${parts[2]}" "${parts[3]}" "${parts[4]}" "${parts[5]}"
    done
}


# system_date函数
# 功能：检查远程服务器的系统时间与当前服务器的时间差，并将结果输出到日志文件。
system_date(){
    local ip="$1"  # 使用传入的参数设置本地变量ip
    # 定义要检查的项目名称
    local check_items="date"
    # 定义警告阈值
    local threshold=30
    # 初始级别设置为INFO
    local log_level="INFO"

    # 使用Unix时间戳格式获取远程服务器的当前时间
    local remote_date=$(ssh ${ip} "date +%s")
    
    # 获取当前服务器的时间戳
    local local_date=$(date +%s)
    
    # 计算两个时间戳之间的差值，即远程服务器与当前服务器的时间差
    local time_diff=$((remote_date - local_date))
    
    # 取时间差的绝对值，确保差值为正数
    time_diff=${time_diff#-}

    if [ $time_diff -gt $threshold ]; then
        log_level="ERROR"
    fi

    log_output "$ip" "$check_items" "NONE" "NONE" "${time_diff}s" "$log_level"
}


# 定义sar命令开始时间
start_time="00:00:01"

# system_cpu函数
# 功能：检查远程服务器的CPU使用率，并将结果输出到日志文件。
system_cpu(){
    local ip="$1"  # 使用传入的参数设置本地变量ip
    # 定义要检查的项目名称
    local check_items="cpu"
    # 定义警告阈值
    local threshold=80

    # 使用 LANG=C 确保远程命令的输出是非本地化的
    # 获取远程服务器的CPU使用率数据（从指定的开始时间至现在）
    local awk_output=$(ssh ${ip} "LANG=C sar -u -s ${start_time}" | awk -v ip="$ip" -v check_items="$check_items" -v threshold="$threshold" '
    {
        # 从第四行开始处理，因为之前的行可能包含其他不相关的信息（如标题行）
        if (NR >= 4){
            # 计算CPU使用率100% 减去空闲率
            use=(100-$NF)
            if (use > threshold) {
                log_level="ERROR"
            } else {
                log_level="INFO"
            }
            printf "%s %s %s %s %d%% %s===", ip, check_items, "NONE", $1, use, log_level
        }
    }')

    IFS=$'===' read -ra lines <<< "$awk_output"
    for line in "${lines[@]}"; do
        IFS=' ' read -ra parts <<< "$line"
        log_output "${parts[0]}" "${parts[1]}" "${parts[2]}" "${parts[3]}" "${parts[4]}" "${parts[5]}"
    done
}

# system_mem函数
# 功能：检查远程服务器的内存使用率，并将结果输出到日志文件。
system_mem(){
    local ip="$1"  # 使用传入的参数设置本地变量ip
    # 定义要检查的项目名称
    local check_items="mem"
    # 定义警告阈值
    local threshold=80

    # 使用sar命令获取内存使用情况
    local awk_output=$(ssh ${ip} "LANG=C sar -r -s ${start_time}" | awk -v ip="$ip" -v check_items="$check_items" -v threshold="$threshold" '
    {
        if (NR >= 4){
            use=($3-$5-$6)/($2+$3)*100
            if (use > threshold) {
                log_level="ERROR"
            } else {
                log_level="INFO"
            }
            printf "%s %s %s %s %d%% %s===", ip, check_items, "NONE", $1, use, log_level
        }
    }')

    IFS=$'===' read -ra lines <<< "$awk_output"
    for line in "${lines[@]}"; do
        IFS=' ' read -ra parts <<< "$line"
        log_output "${parts[0]}" "${parts[1]}" "${parts[2]}" "${parts[3]}" "${parts[4]}" "${parts[5]}"
    done
}

# system_disk_io函数
# 功能：检查远程服务器的磁盘IO使用率，并将结果输出到日志文件。
system_disk_io(){
    local ip="$1"  # 使用传入的参数设置本地变量ip
    # 定义要检查的项目名称
    local check_items="disk_io"
    # 定义警告阈值
    local threshold=80

    # 使用sar命令获取磁盘IO情况
    local awk_output=$(ssh ${ip} "LANG=C sar -d -p -s ${start_time}" | awk -v ip="$ip" -v check_items="$check_items" -v threshold="$threshold" '
    {
        if (NR >= 4){
            use=$10
            if (use > threshold) {
                log_level="ERROR"
            } else {
                log_level="INFO"
            }
            printf "%s %s %s %s %d%% %s===", ip, check_items, $2, $1, use, log_level
        }
    }')

    IFS=$'===' read -ra lines <<< "$awk_output"
    for line in "${lines[@]}"; do
        IFS=' ' read -ra parts <<< "$line"
        log_output "${parts[0]}" "${parts[1]}" "${parts[2]}" "${parts[3]}" "${parts[4]}" "${parts[5]}"
    done
}

# cpu_mem_io函数
# 功能：检查远程服务器是否安装了sysstat。如果已安装，则分别检查cpu、mem和disk_io的使用率。若未安装，则向日志中输出错误信息。
cpu_mem_io(){
    local ip="$1"  # 使用传入的参数设置本地变量ip
    # 使用ssh远程查询是否安装了sysstat
    local sar_installed=$(ssh ${ip} "rpm -qa sysstat")

    # 判断是否安装了sysstat
    if [ -z "$sar_installed" ]; then
        # 如果没有安装sysstat，输出相关信息
        local no_sysstat_info=$(awk 'BEGIN {
            check_items="not_sysstat"
            # 格式化输出结果
            printf "%s %s %s %s %s %s===", "'"${ip}"'", check_items, "NONE", "NONE", "NONE", "ERROR"
        }')

        IFS=$'===' read -ra lines <<< "$no_sysstat_info"
    for line in "${lines[@]}"; do
        IFS=' ' read -ra parts <<< "$line"
        log_output "${parts[0]}" "${parts[1]}" "${parts[2]}" "${parts[3]}" "${parts[4]}" "${parts[5]}"
    done

    else
        # 如果安装了sysstat，则分别检查cpu、mem和disk_io的使用率
        system_cpu $ip
        system_mem $ip
        system_disk_io $ip
    fi
}
