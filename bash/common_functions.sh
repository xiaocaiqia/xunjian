#!/bin/bash

# 仅允许该脚本被source执行
if [[ "$0" == "${BASH_SOURCE[0]}" ]]; then
    echo "请不要直接执行这个脚本"
    exit 1
fi

initialize_environment() {
    local current_timestamp=$(date +%Y%m%d%H%M%S)
    local log_dir="./log"
    xunjian_log="${log_dir}/${current_timestamp}.log"
    xunjian_error_log="${log_dir}/${current_timestamp}_error.log"

    mkdir -p "$log_dir"

    export xunjian_log
    export xunjian_error_log

}

initialize_environment

# log_output 函数
# 功能：处理传入的数据，判断是否超过阈值，输出到日志文件。
log_output() {
    local server_ip="$1"
    local check_items="$2"
    local proc_name="$3"
    local log_file_name="$4"
    local time_diff="$5"
    local log_level="$6"  # 这里接受 "INFO" 或 "ERROR"

    # 创建一个锁文件
    local lock_file="./my_log_lock"

    # 检查是否包含 BASE64: 前缀，并进行解码
    if [[ $time_diff == BASE64:* ]]; then
        time_diff=$(echo -n "${time_diff:7}" | base64 --decode)
    fi

    # 判断第6个参数是否为空
    if [ -z "$log_level" ]; then
        return
    fi

    # 使用 printf 对各字段进行格式化，并通过 flock 加锁
    (
        flock -x 200
        printf "[%s]   %-9s%-20s%-30s%-30s%-45s%-10s\n" \
               "$(date '+%Y-%m-%d %H:%M:%S')" "[$log_level]" "$server_ip" "$check_items" "$proc_name" "$log_file_name" "$time_diff" >> "$xunjian_log"

        # 如果是错误，也输出到错误日志
        if [ "$log_level" == "ERROR" ]; then
            printf "[%s]   %-9s%-20s%-30s%-30s%-45s%-10s\n" \
                "$(date '+%Y-%m-%d %H:%M:%S')" "[$log_level]" "$server_ip" "$check_items" "$proc_name" "$log_file_name" "$time_diff" >> "$xunjian_error_log"
        fi
    ) 200> $lock_file
}



# 检查是否需要初始化
initialize() {
    local output_cfg="./bash/server_type.cfg"
    local items_cfg_file="./bash/items_config.cfg"
    # 检查$output_cfg是否存在
    if [[ ! -f $output_cfg ]]; then
        echo "正在初始化${output_cfg}..."
        touch $output_cfg    # 创建配置文件
        get_server_type
        
        echo "${output_cfg}初始化完成。"
    else
        echo "$output_cfg 文件已存在，无需初始化。"
    fi
    if [[ ! -f $items_cfg_file ]]; then
        echo "正在初始化${items_cfg_file}..."
        touch $items_cfg_file    # 创建配置文件
        get_and_save_config
        echo "${items_cfg_file}初始化完成。"
    else
        echo "$items_cfg_file 文件已存在，无需初始化。"
    fi
    echo ""
    display_statistics
}

# 函数：获取服务器上的进程并确定服务器类型
get_server_type() {
    # 导入配置文件
    local cmcc_hcs_config="./cmcc_hcs.cfg"
    source "$cmcc_hcs_config"
    local ip_array=()

    while read -r line; do
        if [[ $line =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
            IP_ARRAY+=("$line")
        fi
    done < ip.txt

    for target_ip in "${IP_ARRAY[@]}"; do
        # 通过远程命令获取所有需要的进程信息
        local processes=$(ssh "${target_ip}" "ps -ef | grep ${BASE_PATH}/" | grep -vE 'grep|xunjian|hcsmonit|cp ' | awk '{print $8}' | awk -F'/' '{print $NF, $(NF-2)}')
    
        local proc_names=""
        local server_type="UNKNOWN"
        local log_paths=""
        local cfg_paths=""

        # 遍历获取的进程列表，检查其对应的日志路径是否存在
        while IFS=' ' read -r process proc_path; do
            local log_path_var="${process}_log_path"
        
            # 只处理存在于配置文件中的进程
            if [ -n "${!log_path_var}" ]; then
                proc_names="${proc_names}${process},"
                log_paths="${log_paths}${BASE_PATH}/${proc_path}/${!log_path_var},"
                local cfg_path_var="${process}_cfg_path"
                cfg_paths="${cfg_paths}${BASE_PATH}/${proc_path}/${!cfg_path_var},"
            fi
        done <<< "$processes"

        proc_names=${proc_names%,}  # 删除最后的逗号

        # 根据进程名称确定服务器类型
        server_type=$(determine_server_type "$proc_names")

        # 如果配置文件中已存在相关的变量，则使用sed更新这些变量
        # 如果不存在，则直接追加新内容
        if grep -q "${target_ip}_TYPE=" $output_cfg; then
            sed -i "s|${target_ip}_TYPE=.*|${target_ip}_TYPE=${server_type}|g" $output_cfg
            if [ -n "$proc_names" ]; then  # -n 测试变量是否非空
                sed -i "s|${target_ip}_PROCESSES=.*|${target_ip}_PROCESSES=${proc_names}|g" $output_cfg
                sed -i "s|${target_ip}_LOG_PATHS=.*|${target_ip}_LOG_PATHS=${log_paths%,}|g" $output_cfg
                sed -i "s|${target_ip}_CFG_PATHS=.*|${target_ip}_CFG_PATHS=${cfg_paths%,}|g" $output_cfg
            fi
            
        else
            echo "${target_ip}_TYPE=${server_type}" >> $output_cfg
            if [ -n "$proc_names" ]; then  # -n 测试变量是否非空
                echo "${target_ip}_PROCESSES=${proc_names}" >> $output_cfg
                echo "${target_ip}_LOG_PATHS=${log_paths%,}" >> $output_cfg
                echo "${target_ip}_CFG_PATHS=${cfg_paths%,}" >> $output_cfg
            fi

        fi

    done
}


# 函数：根据进程名称确定服务器类型
determine_server_type() {
    local processes="${1:-}"
    local result_server_type

    if [[ $processes == *"hcsdis"* ]]; then
        if [[ $processes == *"hcs_redis_server"* ]]; then
            result_server_type="DIS_WITH_REDIS"
        else
            result_server_type="DIS"
        fi
    elif [[ $processes == *"hcsnat"* ]]; then
        if [[ $processes == *"hcsredis_nat_server"* ]]; then
            result_server_type="NAT_WITH_REDISNAT"
        else
            result_server_type="NAT"
        fi
    elif [[ $processes == *"hcsout"* ]]; then
        result_server_type="OUT"
    else
        result_server_type="UNKNOWN"
    fi

    echo "$result_server_type"
}


display_statistics() {
    local output_cfg="./bash/server_type.cfg"
    # 定义关联数组
    declare -A server_types process_combinations individual_processes

    # 读取 output_cfg 文件内容
    while IFS="=" read -r key value; do
        # 根据服务器类型统计
        if [[ $key == *_TYPE ]]; then
            server_types[$value]=$(( ${server_types[$value]} + 1 ))
        elif [[ $key == *_PROCESSES ]]; then
            # 对进程名进行排序
            IFS=',' read -ra procs <<< "$value"
            sorted_procs=$(echo "${procs[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ')
            sorted_procs=${sorted_procs// /,}
            sorted_procs=${sorted_procs%,}  # 移除末尾的逗号

            # 为进程组合计数
            process_combinations[$sorted_procs]=$(( ${process_combinations[$sorted_procs]} + 1 ))

            # 对单个进程进行计数
            for proc in "${procs[@]}"; do
                individual_processes[$proc]=$(( ${individual_processes[$proc]} + 1 ))
            done
        fi
    done < "$output_cfg"

    # 输出统计结果
    echo "服务器总数: ${#server_types[@]}"
    echo ""

    echo "各类型服务器及其数量:"
    for type in "${!server_types[@]}"; do
        echo "- $type: ${server_types[$type]}"
    done
    echo ""

    echo "进程及其数量:"
    for proc in "${!individual_processes[@]}"; do
        echo "- $proc: ${individual_processes[$proc]}"
    done
    echo ""

    echo "进程组合及其对应的服务器数量:"
    for proc_combination in "${!process_combinations[@]}"; do
        echo "- $proc_combination: ${process_combinations[$proc_combination]}"
    done
}



check_hcs_programs() {
    local server_ip="$1"  # 将传入的所有参数作为一个数组
    local output_cfg="./bash/server_type.cfg"
    declare -A SERVER_INFO

    while read -r line; do
        IFS='=' read -ra PARTS <<< "$line"
        SERVER_INFO["${PARTS[0]}"]="${PARTS[1]}"
    done < $output_cfg


    # 获取服务器类型，进程，日志和配置文件路径
    local server_type=${SERVER_INFO["${server_ip}_TYPE"]}
    IFS=',' read -ra server_processes <<< "${SERVER_INFO["${server_ip}_PROCESSES"]}"
    IFS=',' read -ra log_paths <<< "${SERVER_INFO["${server_ip}_LOG_PATHS"]}"
    IFS=',' read -ra cfg_paths <<< "${SERVER_INFO["${server_ip}_CFG_PATHS"]}"

    echo ""
    echo "正在巡检服务器：$server_ip, 类型：$server_type"

    # 循环遍历每个进程以进行巡检
    for index in "${!server_processes[@]}"; do
        local proc=${server_processes[$index]}
        local log_path=${log_paths[$index]}
        local cfg_path=${cfg_paths[$index]}

        echo "正在巡检进程：$proc, 日志路径：$log_path, 配置文件路径：$cfg_path"

        # 调用与进程名匹配的函数来进行巡检
        # 假设有一个名为 check_hcsserver 的函数用于检查 hcsserver 进程
        if [ -n "$proc" ]; then
            function_name="check_$proc"
            if [ "$(type -t $function_name)" = "function" ]; then
                $function_name "$server_ip" "$log_path"
            else
                echo "警告：没有找到用于检查 $proc 的函数"
            fi
        fi
    done

}


# 函数：从远程服务器的指定的cfg文件获取指定的配置项
get_remote_config_value() {
    local ip=$1
    local cfg_file=$2
    local config_item=$3

    # 判断是否特定的配置项
    if [ "$config_item" == "output.server" ] && [[ $cfg_file == *hcsdis* ]]; then
        # 修改 cfg_file 的名称
        local modified_cfg_file="${cfg_file/hcsdis_myself.cfg/hcsdis_output.cfg}"
        # 检查 modified_cfg_file 文件中是否有以有效 IP 地址开头的行
        local ip_line_exists=$(ssh $ip "grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}' $modified_cfg_file" | tr '\n' '|')

        # 去掉最后一个管道符（如果有的话）
        ip_line_exists=${ip_line_exists%|}

        # 根据是否找到了 IP 地址开头的行来返回值
        if [ -n "$ip_line_exists" ]; then
            echo "$ip_line_exists"
            return
        fi
    fi

    # 判断是否特定的配置项
    if [ "$config_item" == "hcscore_output.cfg" ]; then
        # 修改 cfg_file 的名称
        local modified_cfg_file="${cfg_file/hcscore_myself.cfg/hcscore_output.cfg}"
        # 检查 modified_cfg_file 文件中是否有以有效 IP 地址开头的行
        local ip_line_exists=$(ssh $ip "grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}' $modified_cfg_file" | awk -F '|' '{print $1":"$2}' | tr '\n' '|')

        # 去掉最后一个管道符（如果有的话）
        ip_line_exists=${ip_line_exists%|}

        # 根据是否找到了 IP 地址开头的行来返回值
        if [ -n "$ip_line_exists" ]; then
            echo "$ip_line_exists"
            return
        fi
    fi

    # 其他情况，获取指定配置项的值
    local config_value=$(ssh $ip "cat $cfg_file" | awk -F'= *' -v item="$config_item" '{gsub(/^[ \t]+|[ \t]+$/, "", $1); if ($1 == item) print $2}')
    echo "$config_value"
}




# 函数：将获取到的信息保存到新的cfg文件
save_to_new_cfg() {
    local ip=$1
    local process_name=$2
    local config_item_name=$3
    local config_value=$4

    local items_cfg_file="./bash/items_config.cfg"
    echo "${ip}_${process_name}_${config_item_name}=${config_value}" >> $items_cfg_file
}

# 函数：从server_type.cfg获取进程和相应的配置文件路径
get_server_info() {
    local ip=$1
    local cfg_file="./bash/server_type.cfg"
    
    local processes=$(awk -F= -v ip="$ip" '$1 == ip"_PROCESSES" {print $2}' $cfg_file)
    local cfg_paths=$(awk -F= -v ip="$ip" '$1 == ip"_CFG_PATHS" {print $2}' $cfg_file)

    echo "$processes"
    echo "$cfg_paths"
}

# 函数：从cmcc_hcs.cfg获取指定进程的配置项
get_hcs_items() {
    local process_name=$1
    local cmcc_hcs_file="./cmcc_hcs.cfg"
    source $cmcc_hcs_file
    
    local var_name="${process_name}_items"
    echo ${!var_name}
}


# 主函数：获取并保存配置信息
get_and_save_config() {

    source ./cmcc_hcs.cfg
    # 从 server_type.cfg 获取所有 IP 地址
    local all_ips=$(awk -F= '/_TYPE/ {split($1, a, "_"); print a[1]}' bash/server_type.cfg | sort -u)

    # 遍历每一个 IP 地址
    for ip in $all_ips; do
        read -r processes cfg_paths <<< $(get_server_info $ip)

        # 分割字符串为数组
        IFS=',' read -ra process_array <<< "$processes"
        IFS=',' read -ra cfg_path_array <<< "$cfg_paths"

        # 遍历进程和相应的配置文件路径
        for index in "${!process_array[@]}"; do
            process="${process_array[index]}"
            cfg_path="${cfg_path_array[index]}"
      
            # 获取此进程在 cmcc_hcs.cfg 中定义的需要检查的配置项
            hcs_items=$(get_hcs_items $process)
      
            # 分割 hcs_items 为数组
            IFS=',' read -ra hcs_items_array <<< "$hcs_items"
      
            # 遍历需要检查的配置项
            for item in "${hcs_items_array[@]}"; do
                # 获取远程服务器上的配置项的值
                config_value=$(get_remote_config_value $ip $cfg_path $item)
                cfg_process=$(echo "$cfg_path"  | awk -F '/' '{print $(NF-2)}')
                # 保存到新的 cfg 文件
                save_to_new_cfg $ip $cfg_process $item $config_value
            done
        done
    done
}


# 根据巡检日志打印巡检结果到屏幕
print_result(){
    # 定义颜色
    RED="\033[31m"
    GREEN="\033[32m"
    NONE="\033[0m"

	cat ${xunjian_log}|sort|awk '{print $4,$5,$6,$7,$8}'|awk 'BEGIN {
	}
	!a[$1$3]++{
		if($2~"hcs")
			hcs_type[$1]=hcs_type[$1]" "$3
	}
	!a[$1]++{
		host_num++
		ip[host_num]=$1
	}
	END {
		for (i=1;i<=host_num;i++){
			b=ip[i]
			if (!hcs_type_num[hcs_type[b]]){
				num++
				type[num]=hcs_type[b]
			}
			hcs_type_num[hcs_type[b]]++
		}
		for (i=1;i<=num;i++) {
			if (type[i]!="")
				printf "'"${GREEN}"'%s:%s'"${NONE}"'\n",type[i],hcs_type_num[type[i]]
			else
				printf "'"${GREEN}"'%s:%s'"${NONE}"'\n"," NONE",hcs_type_num[type[i]]
		}
	}'
	if [ -e ${xunjian_error_log} ]
	then
		cat ${xunjian_error_log}|sort|awk '{print $4,$5,$6,$7,$8}'|awk 'BEGIN {
		}
		!a[$1]++{
			host_num++
			ip[host_num]=$1
		}
		!a[$1$2]++{
			error[$1]=error[$1]" "$2
		}
		{
			if($2=="hcs")
				hcs_type[$1]=hcs_type[$1]" "$3
		}
		END {
			for (i=1;i<=host_num;i++){
				b=ip[i]
				printf "'"${RED}"'%s,%s'"${NONE}"'\n",b,error[b]
			}
		}'
	fi
}

