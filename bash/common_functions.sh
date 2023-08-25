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

# execute_commands 函数
# 功能：对每个IP执行指定的命令，并在每次执行完一组命令后休眠指定的时间。
execute_commands(){

    local ip_file="${1:-default_ip_file}"       # IP文件路径
    local sleep_duration="${2:-0}"              # 休眠时间
    local ps_hcs_path="${3:-default_path}"      # hcs程序路径
    shift 3                     # 移除前三个参数，后面的参数都是要执行的函数
    local commands=("$@")       # 获取所有要执行的函数为一个数组

    # 对每个IP执行指定的命令
    for ip in $(cat "$ip_file"); do
        for cmd in "${commands[@]}"; do
            $cmd &              # 并行执行每个命令
        done
        sleep $sleep_duration  # 每次执行完一组命令后的休眠时间
    done
    wait                       # 等待所有并行命令完成
    print_result               # 输出结果
}


# log_output 函数
# 功能：处理传入的数据，判断是否超过阈值，输出到日志文件。
log_output() {
    local server_ip="$1"
    local check_items="$2"
    local proc_name="$3"
    local log_file_name="$4"
    local time_diff="$5"
    local log_level="$6"  # 这里接受 "INFO" 或 "ERROR"

    # 使用 printf 对各字段进行格式化
    printf "[%s][%-6s]   %-20s%-20s%-30s%-30s%-10s\n" \
           "$(date '+%Y-%m-%d %H:%M:%S')" "$log_level" "$server_ip" "$check_items" "$proc_name" "$log_file_name" "$time_diff" >> "$xunjian_log"

    # 如果是错误，也输出到错误日志
    if [ "$log_level" == "ERROR" ]; then
        printf "[%s][%-6s]   %-20s%-20s%-30s%-30s%-10s\n" \
               "$(date '+%Y-%m-%d %H:%M:%S')" "$log_level" "$server_ip" "$check_items" "$proc_name" "$log_file_name" "$time_diff" >> "$xunjian_error_log"
    fi
}



# 检查是否需要初始化
initialize() {
    local output_cfg="./bash/server_type.cfg"
    # 检查$output_cfg是否存在
    if [[ ! -f $output_cfg ]]; then
        echo "正在初始化..."
        touch $output_cfg    # 创建配置文件
        get_server_type
        echo "初始化完成。"
    else
        echo "$output_cfg 文件已存在，无需初始化。"
    fi
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
            sed -i "s|${target_ip}_PROCESSES=.*|${target_ip}_PROCESSES=${proc_names}|g" $output_cfg
            sed -i "s|${target_ip}_LOG_PATHS=.*|${target_ip}_LOG_PATHS=${log_paths%,}|g" $output_cfg
            sed -i "s|${target_ip}_CFG_PATHS=.*|${target_ip}_CFG_PATHS=${cfg_paths%,}|g" $output_cfg
        else
            echo "${target_ip}_TYPE=${server_type}" >> $output_cfg
            echo "${target_ip}_PROCESSES=${proc_names}" >> $output_cfg
            echo "${target_ip}_LOG_PATHS=${log_paths%,}" >> $output_cfg
            echo "${target_ip}_CFG_PATHS=${cfg_paths%,}" >> $output_cfg
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
            # 为进程组合计数
            process_combinations[$value]=$(( ${process_combinations[$value]} + 1 ))

            # 对单个进程进行计数
            IFS=',' read -ra procs <<< "$value"
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
    local servers=("$@")  # 将传入的所有参数作为一个数组
    local output_cfg="./bash/server_type.cfg"
    declare -A SERVER_INFO

    while read -r line; do
        IFS='=' read -ra PARTS <<< "$line"
        SERVER_INFO["${PARTS[0]}"]="${PARTS[1]}"
    done < $output_cfg

    for server_ip in "${servers[@]}"; do
        # 获取服务器类型，进程，日志和配置文件路径
        local server_type=${SERVER_INFO["${server_ip}_TYPE"]}
        IFS=',' read -ra server_processes <<< "${SERVER_INFO["${server_ip}_PROCESSES"]}"
        IFS=',' read -ra log_paths <<< "${SERVER_INFO["${server_ip}_LOG_PATHS"]}"
        IFS=',' read -ra cfg_paths <<< "${SERVER_INFO["${server_ip}_CFG_PATHS"]}"

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
                    $function_name "$server_ip" "$log_path" "$cfg_path"
                else
                    echo "警告：没有找到用于检查 $proc 的函数"
                fi
            fi
        done
    done
}



# 根据巡检日志打印巡检结果到屏幕
print_result(){
    # 定义颜色
    RED="\033[31m"
    GREEN="\033[32m"
    NONE="\033[0m"

	cat ${xunjian_log}|sort|awk '{print $3,$4,$5,$6,$7}'|awk 'BEGIN {
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
		cat ${xunjian_error_log}|sort|awk '{print $3,$4,$5,$6,$7}'|awk 'BEGIN {
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

