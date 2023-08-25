#!/bin/bash

check_hcsserver() {
    local server_ip=$1
    local log_path=$2
    local cfg_path=$3

    local -a check_result=($(check_log_refresh_time "$server_ip" "$log_path"))

    # 使用 log_output 函数输出到日志（假设你已经定义了这个函数）
    log_output "${check_result[0]}" "${check_result[1]}" "${check_result[2]}" "${check_result[3]}" "${check_result[4]}" "${check_result[5]}"
}


check_log_refresh_time() {
    local server_ip=$1
    local log_path=$2
    local check_items="log_refresh_time"

    # 获取日志文件名称和进程名称
    local log_file_name=$(basename "$log_path")
    local proc_name=$(basename "$(dirname "$(dirname "$log_path")")")

    # 使用 ssh 命令在远程服务器上获取日志最后修改时间和当前时间，然后计算时间差（这里使用秒为单位）
    local last_mod_time=$(ssh "$server_ip" "stat -c %Y '$log_path'")
    local current_time=$(ssh "$server_ip" "date +%s")
    local time_diff=$((current_time - last_mod_time))

    # 判断是否应视为 error 日志（这里简单地判断时间差是否大于 600 秒）
    local is_error=0
    if [ "$time_diff" -gt 600 ]; then
        is_error=1
    fi

    # 构建返回数组
    local -a result_array=("$server_ip" "$check_items" "$proc_name" "$log_file_name" "$time_diff" "$is_error")
    echo "${result_array[@]}"
}



