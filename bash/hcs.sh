#!/bin/bash

check_hcsserver() {
    local server_ip=$1
    local log_path=$2
    local cfg_path=$3

    # 首先检查日志刷新时间
    check_log_refresh_time "$server_ip" "$log_path"

    # 然后检查日志错误
    check_log_for_errors "$server_ip" "$log_path"
}

check_hcsdis() {
    local server_ip=$1
    local log_path=$2
    local cfg_path=$3

    # 首先检查日志刷新时间
    check_log_refresh_time "$server_ip" "$log_path"

    # 然后检查日志错误
    check_log_for_errors "$server_ip" "$log_path"
}

check_hcs_redis_server() {
    local server_ip=$1
    local log_path=$2
    local cfg_path=$3

    # 首先检查日志刷新时间
    check_log_refresh_time "$server_ip" "$log_path"

    # 然后检查日志错误
    check_log_for_errors "$server_ip" "$log_path"
}

check_hcscore() {
    local server_ip=$1
    local log_path=$2
    local cfg_path=$3

    # 首先检查日志刷新时间
    check_log_refresh_time "$server_ip" "$log_path"

    # 然后检查日志错误
    check_log_for_errors "$server_ip" "$log_path"
}

check_hcsout() {
    local server_ip=$1
    local log_path=$2
    local cfg_path=$3

    # 首先检查日志刷新时间
    check_log_refresh_time "$server_ip" "$log_path"

    # 然后检查日志错误
    check_log_for_errors "$server_ip" "$log_path"
}

check_hcsnat() {
    local server_ip=$1
    local log_path=$2
    local cfg_path=$3

    # 首先检查日志刷新时间
    check_log_refresh_time "$server_ip" "$log_path"

    # 然后检查日志错误
    check_log_for_errors "$server_ip" "$log_path"
}

check_hcsredis_nat_server() {
    local server_ip=$1
    local log_path=$2
    local cfg_path=$3

    # 首先检查日志刷新时间
    check_log_refresh_time "$server_ip" "$log_path"

    # 然后检查日志错误
    check_log_for_errors "$server_ip" "$log_path"
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
    local is_error="INFO"
    if [ "$time_diff" -gt 600 ]; then
        is_error="ERROR"
    fi

    log_output "$server_ip" "$check_items" "$proc_name" "$log_file_name" "${time_diff}s" "$is_error"
}


# 用于检查日志中是否有错误（包含“ERROR”关键字）的行的函数
check_log_for_errors() {
    local server_ip=$1
    local log_path=$2
    local check_items="log_errors"

    # 获取日志文件名称和进程名称
    local log_file_name=$(basename "$log_path")
    local proc_name=$(basename "$(dirname "$(dirname "$log_path")")")

    # 使用 ssh 和 grep 在远程服务器上搜索包含 "ERROR" 的行，并取最后一行
    local last_error_line=$(ssh "$server_ip" "grep 'ERROR' '$log_path' | tail -n 1")

    # 使用base64对last_error_line进行编码
    local encoded_last_error_line="BASE64:$(echo -n "[$last_error_line]" | base64)"

    # 判断是否应标记为错误
    local is_error="INFO"
    if [ -n "$last_error_line" ]; then
        is_error="ERROR"
    fi

    log_output "$server_ip" "$check_items" "$proc_name" "$log_file_name" "$encoded_last_error_line" "$is_error"
}



