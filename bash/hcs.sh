#!/bin/bash

# 函数：检查 hcsserver 程序
check_hcsserver() {
    local server_ip=$1
    local log_path=$2
    local cfg_path="bash/items_config.cfg"  # 这里硬编码了配置文件路径

    # 获取IP, 端口和落地目录
    local ip=$(awk -F "=" -v key="${server_ip}_hcsserver_hcsserver.serverip" '$1==key {print $2}' "$cfg_path")
    local port=$(awk -F "=" -v key="${server_ip}_hcsserver_hcsserver.port" '$1==key {print $2}' "$cfg_path")
    local savedir=$(awk -F "=" -v key="${server_ip}_hcsserver_hcsserver.savedir" '$1==key {print $2}' "$cfg_path")

    if [ -z "$ip" ] || [ -z "$port" ] || [ -z "$savedir" ]; then
        echo "错误：无法获取服务器 $server_ip 的所有必需配置"
        return 1
    fi

    # 首先检查日志刷新时间
    check_log_refresh_time "$server_ip" "$log_path"

    # 然后检查日志错误
    check_log_for_errors "$server_ip" "$log_path"

    # 使用SSH来检查远程服务器的端口和连接状态
    local port_status=$(ssh "$server_ip" "netstat -ntlp | grep -q \"$ip:$port.*LISTEN\"; echo $?")
    local connections=$(ssh "$server_ip" "netstat -anp | grep 'hcsserver' | grep \"$ip:$port\" | grep 'ESTABLISHED' | wc -l")

    if [ "$port_status" -eq 0 ] && [ "$connections" -ge 1 ]; then
        log_output "$server_ip" "Probe_Listening" "hcsserver" "$ip:$port" "$connections" "INFO"
    else
        log_output "$server_ip" "Probe_Listening" "hcsserver" "$ip:$port" "$connections" "ERROR"
    fi

    # 检查远程服务器上落地目录下的文件数量
    local file_count=$(ssh "$server_ip" "ls -1 \"$savedir\" 2>/dev/null | wc -l")
    if [ "$file_count" -le 10 ]; then
        log_output "$server_ip" "SDTP_Path" "hcsserver" "$savedir" "$file_count" "INFO"
    else
        log_output "$server_ip" "SDTP_Path" "hcsserver" "$savedir" "$file_count" "ERROR"
    fi
}



check_hcsdis() {
    local server_ip=$1
    local log_path=$2
    local cfg_path="bash/items_config.cfg"  # 配置文件路径

    # 首先检查日志刷新时间
    check_log_refresh_time "$server_ip" "$log_path"

    # 然后检查日志错误
    check_log_for_errors "$server_ip" "$log_path"

    # Redis 监听端口检查
    local redis_listen_host=$(awk -F "=" -v key="${server_ip}_hcsdis_redis.listen.host" '$1==key {print $2}' "$cfg_path")
    local redis_listen_port=$(awk -F "=" -v key="${server_ip}_hcsdis_redis.listen.port" '$1==key {print $2}' "$cfg_path")
    local redis_listen_status=$(ssh "$server_ip" "netstat -ntlp | grep -q \"$redis_listen_host:$redis_listen_port.*LISTEN\"; echo $?")
    local redis_listen_connections=$(ssh "$server_ip" "netstat -anp | grep \"$redis_listen_host:$redis_listen_port\" | grep 'hcsdis' | grep 'ESTABLISHED' | wc -l")

    if [ "$redis_listen_status" -eq 0 ]; then
        log_output "$server_ip" "Redis_Listening" "hcsdis" "$redis_listen_host:$redis_listen_port" "$redis_listen_connections" "INFO"
    else
        log_output "$server_ip" "Redis_Listening" "hcsdis" "$redis_listen_host:$redis_listen_port" "Not_Listening" "ERROR"
    fi

    # Redis 服务器建链状态检查
    local redis_server=$(awk -F "=" -v key="${server_ip}_hcsdis_redis.server" '$1==key {print $2}' "$cfg_path")
    local redis_connections=$(parse_connection_item "$redis_server")
    local total_redis_connections=0

    for conn in $redis_connections; do
        local conn_status=$(ssh "$server_ip" "netstat -anp | grep 'hcsdis' | grep \"$conn\" | grep 'ESTABLISHED' | wc -l")
        total_redis_connections=$((total_redis_connections + conn_status))

        if [ "$conn_status" -ge 1 ]; then
            log_output "$server_ip" "Redis_Connection" "hcsdis" "$conn" "$conn_status" "INFO"
        else
            log_output "$server_ip" "Redis_Connection" "hcsdis" "$conn" "$conn_status" "ERROR"
        fi
    done

    if [ "$redis_listen_connections" -ne "$total_redis_connections" ]; then
        log_output "$server_ip" "Redis_Connections_Match" "hcsdis" "Mismatch" "${redis_listen_connections}vs${total_redis_connections}" "ERROR"
    else
        log_output "$server_ip" "Redis_Connections_Match" "hcsdis" "Match" "${redis_listen_connections}vs${total_redis_connections}" "INFO"
    fi

    # SDTP 文件移动路径检查
    local sdtp_move_path=$(awk -F "=" -v key="${server_ip}_hcsdis_sdtp.file.move.path" '$1==key {print $2}' "$cfg_path")
    local sdtp_file_count=$(ssh "$server_ip" "find \"$sdtp_move_path\" -mmin -10 -type f | wc -l")
    local sdtp_file_size=$(ssh "$server_ip" "find \"$sdtp_move_path\" -mmin -10 -type f -exec du -c {} + | tail -n 1 | awk '{print \$1}'")

    if [ "$sdtp_file_count" -gt 0 ]; then
        log_output "$server_ip" "SDTP_Move_Path" "hcsdis" "$sdtp_move_path" "Count:$sdtp_file_count,Size:${sdtp_file_size}K" "INFO"
    else
        log_output "$server_ip" "SDTP_Move_Path" "hcsdis" "$sdtp_move_path" "Count:0" "ERROR"
    fi

    # 输出服务器建链状态检查
    local output_server=$(awk -F "=" -v key="${server_ip}_hcsdis_output.server" '$1==key {print $2}' "$cfg_path")
    local output_connections=$(parse_connection_item "$output_server")
    for conn in $output_connections; do
        local conn_status=$(ssh "$server_ip" "netstat -anp | grep 'hcsdis' | grep \"$conn\" | grep 'ESTABLISHED' | wc -l")
        if [ "$conn_status" -ge 1 ]; then
            log_output "$server_ip" "Output_Connection" "hcsdis" "$conn" "$conn_status" "INFO"
        else
            log_output "$server_ip" "Output_Connection" "hcsdis" "$conn" "$conn_status" "ERROR"
        fi
    done
}

check_hcs_redis_server() {
    local server_ip=$1
    local log_path=$2
    local cfg_path="bash/items_config.cfg"  # 这里硬编码了配置文件路径

    # 首先检查日志刷新时间
    check_log_refresh_time "$server_ip" "$log_path"

    # 然后检查日志错误
    check_log_for_errors "$server_ip" "$log_path"
}

check_hcscore() {
    local server_ip=$1
    local log_path=$2
    local cfg_path="bash/items_config.cfg"  # 这里硬编码了配置文件路径

    # 首先检查日志刷新时间
    check_log_refresh_time "$server_ip" "$log_path"

    # 然后检查日志错误
    check_log_for_errors "$server_ip" "$log_path"

    # Redis 监听端口检查
    local redis_listen_host=$(awk -F "=" -v key="${server_ip}_hcscore_redis.listen.host" '$1==key {print $2}' "$cfg_path")
    local redis_listen_port=$(awk -F "=" -v key="${server_ip}_hcscore_redis.listen.port" '$1==key {print $2}' "$cfg_path")
    local redis_listen_status=$(ssh "$server_ip" "netstat -ntlp | grep -q \"$redis_listen_host:$redis_listen_port.*LISTEN\"; echo $?")
    local redis_listen_connections=$(ssh "$server_ip" "netstat -anp | grep \"$redis_listen_host:$redis_listen_port\" | grep 'hcscore' | grep 'ESTABLISHED' | wc -l")

    if [ "$redis_listen_status" -eq 0 ]; then
        log_output "$server_ip" "Redis_Listening" "hcscore" "$redis_listen_host:$redis_listen_port" "$redis_listen_connections" "INFO"
    else
        log_output "$server_ip" "Redis_Listening" "hcscore" "$redis_listen_host:$redis_listen_port" "Not_Listening" "ERROR"
    fi

    # Redis 服务器建链状态检查
    local redis_server=$(awk -F "=" -v key="${server_ip}_hcscore_redis.server" '$1==key {print $2}' "$cfg_path")
    local redis_connections=$(parse_connection_item "$redis_server")
    local total_redis_connections=0

    for conn in $redis_connections; do
        local conn_status=$(ssh "$server_ip" "netstat -anp | grep \"$conn\" | grep 'hcscore' | grep 'ESTABLISHED' | wc -l")
        total_redis_connections=$((total_redis_connections + conn_status))

        if [ "$conn_status" -ge 1 ]; then
            log_output "$server_ip" "Redis_Connection" "hcscore" "$conn" "$conn_status" "INFO"
        else
            log_output "$server_ip" "Redis_Connection" "hcscore" "$conn" "$conn_status" "ERROR"
        fi
    done

    if [ "$redis_listen_connections" -ne "$total_redis_connections" ]; then
        log_output "$server_ip" "Redis_Connections_Match" "hcscore" "Mismatch" "${redis_listen_connections}vs${total_redis_connections}" "ERROR"
    else
        log_output "$server_ip" "Redis_Connections_Match" "hcscore" "Match" "${redis_listen_connections}vs${total_redis_connections}" "INFO"
    fi

    # hcscore server 监听端口检查
    local hcscore_server_host=$(awk -F "=" -v key="${server_ip}_hcscore_server.host" '$1==key {print $2}' "$cfg_path")
    local hcscore_server_ports=$(awk -F "=" -v key="${server_ip}_hcscore_server.port" '$1==key {print $2}' "$cfg_path")
    local hcscore_server_connections=$(parse_connection_item "$hcscore_server_host:$hcscore_server_ports")
    local total_hcscore_established_connections=0  # 正常建链数

    for conn in $hcscore_server_connections; do
        local conn_status=$(ssh "$server_ip" "netstat -ntlp | grep -q \"$conn.*LISTEN\"; echo $?")
        local established_connections=$(ssh "$server_ip" "netstat -anp | grep \"$conn\" | grep 'hcscore' | grep 'ESTABLISHED' | wc -l")  # 统计 ESTABLISHED 状态的连接数

        if [ "$conn_status" -eq 0 ]; then
            log_output "$server_ip" "HCScore_Listening" "hcscore" "$conn" "Listening" "INFO"
        else
            log_output "$server_ip" "HCScore_Listening" "hcscore" "$conn" "Not_Listening" "ERROR"
        fi
    done

    # 输出总的 ESTABLISHED 连接数
    if [ "$total_hcscore_established_connections" -gt 0 ]; then
        log_output "$server_ip" "HCScore_Listening_Established" "hcscore" "Listening_Established" "$total_hcscore_established_connections" "INFO"
    else
        log_output "$server_ip" "HCScore_Listening_Established" "hcscore" "Listening_Established" "0" "ERROR"
    fi
    # 新增：HCScore 输出建链状态检查
    local hcscore_output=$(awk -F "=" -v key="${server_ip}_hcscore_hcscore_output.cfg" '$1==key {print $2}' "$cfg_path")
    local hcscore_output_connections=$(parse_connection_item "$hcscore_output")
    local total_hcscore_output_connections=0  # 正常建链数
    
    for conn in $hcscore_output_connections; do
        local conn_status=$(ssh "$server_ip" "netstat -anp | grep \"$conn\" | grep 'hcscore' | grep 'ESTABLISHED' | wc -l")
        total_hcscore_output_connections=$((total_hcscore_output_connections + conn_status))
        
        if [ "$conn_status" -ge 1 ]; then
            log_output "$server_ip" "HCScore_Output_Connection" "hcscore" "$conn" "$conn_status" "INFO"
        else
            log_output "$server_ip" "HCScore_Output_Connection" "hcscore" "$conn" "$conn_status" "ERROR"
        fi
    done
}

check_hcsout() {
    local server_ip=$1
    local log_path=$2
    local cfg_path="bash/items_config.cfg"  # 这里硬编码了配置文件路径

    # 首先检查日志刷新时间
    check_log_refresh_time "$server_ip" "$log_path"

    # 然后检查日志错误
    check_log_for_errors "$server_ip" "$log_path"
}

check_hcsnat() {
    local server_ip=$1
    local log_path=$2
    local cfg_path="bash/items_config.cfg"  # 这里硬编码了配置文件路径

    # 首先检查日志刷新时间
    check_log_refresh_time "$server_ip" "$log_path"

    # 然后检查日志错误
    check_log_for_errors "$server_ip" "$log_path"
}

check_hcsredis_nat_server() {
    local server_ip=$1
    local log_path=$2
    local cfg_path="bash/items_config.cfg"  # 这里硬编码了配置文件路径

    # 首先检查日志刷新时间
    check_log_refresh_time "$server_ip" "$log_path"

    # 然后检查日志错误
    check_log_for_errors "$server_ip" "$log_path"
}


check_log_refresh_time() {
    local server_ip=$1
    local log_path=$2
    local check_items="Log_Refresh_Time"

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
    local check_items="Log_Errors"

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


# 函数：解析连接项，格式：ip:端口,端口,端口|ip:端口,端口,端口
# 返回一个包含 "ip:端口" 格式的数组
parse_connection_item() {
    local item_value="$1"
    local -a results

    # 拆分多组连接配置
    IFS="|" read -ra multiple_pairs <<< "$item_value"

    for pair in "${multiple_pairs[@]}"; do
        # 获取 IP 和端口
        local ip="${pair%%:*}"
        local ports="${pair##*:}"

        # 是否有多个端口
        if [[ "$ports" == *","* ]]; then
            IFS="," read -ra port_array <<< "$ports"
            for port in "${port_array[@]}"; do
                results+=("$ip:$port")
            done
        else
            results+=("$ip:$ports")
        fi
    done

    # 输出结果数组
    for result in "${results[@]}"; do
        echo "$result"
    done
}



