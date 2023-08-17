#!/bin/bash

# 如果这个脚本被直接执行而不是被source，那么退出。
[[ "$0" == "${BASH_SOURCE[0]}" ]] && { echo "请不要直接执行这个脚本"; exit 1; }


# execute_commands 函数
# 功能：对每个IP执行指定的命令，并在每次执行完一组命令后休眠指定的时间。
execute_commands(){
    # 参数1: IP 文件
    # 参数2: 休眠时间
    # 参数3: hcs程序路径
    # 参数4及以后: 要执行的函数

    local ip_file="$1"           # IP文件路径
    local sleep_duration="$2"   # 休眠时间
    local ps_hcs_path="$3"      # hcs程序路径
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
# 功能：处理传入的数据，判断是否超过阈值，并以适当的颜色输出到日志文件。
log_output() {
    # 参数1: system的输出
    # 参数2: 阈值
    local system_output="$1"
    local threshold="$2"

    # 定义颜色
    local RED="\033[31m"
    local GREEN="\033[32m"
    local NONE="\033[0m"

    # 定义日志目录和文件路径
    local LOG_DIR="./log"
    local xunjian_log="${LOG_DIR}/xunjian_log_${CURRENT_TIMESTAMP}"
    local xunjian_error_log="${LOG_DIR}/xunjian_error_log_${CURRENT_TIMESTAMP}"

    # 处理每一行的 awk 输出
    while IFS= read -r line; do
        # 将每行分成数组
        IFS=' ' read -r -a parts <<< "$line"
        # 获取使用率，去除 '%' 字符
        local use_num="${parts[4]//[^0-9]/}"

        # 默认为绿色字体和日志文件
        local target_log="$xunjian_log"
        local color="$GREEN"
        
        # 如果使用率超过阈值则先输出到全量日志文件，然后选择红色字体和错误日志文件
        if (( $use_num > $threshold )); then
            printf "[%s] %-15s%-15s%-30s%-30s${color}%s${NONE}\n" \
               "$(date '+%Y-%m-%d %H:%M:%S')" "${parts[0]}" "${parts[1]}" "${parts[2]}" "${parts[3]}" "${parts[4]}" >> "$target_log"
            target_log="$xunjian_error_log"
            color="$RED"
        fi

        # 格式化输出到相应的日志文件
        printf "[%s] %-15s%-15s%-30s%-30s${color}%s${NONE}\n" \
               "$(date '+%Y-%m-%d %H:%M:%S')" "${parts[0]}" "${parts[1]}" "${parts[2]}" "${parts[3]}" "${parts[4]}" >> "$target_log"
    done <<< "$system_output"
}

# 存储的配置文件路径
OUTPUT_CFG="./bash/server_type.cfg"

# 检查是否需要初始化
initialize() {
    # 检查$OUTPUT_CFG是否存在
    if [[ ! -f $OUTPUT_CFG ]]; then
        echo "正在初始化..."
        touch $OUTPUT_CFG    # 创建配置文件
        get_server_type
        echo "初始化完成。"
    else
        echo "$OUTPUT_CFG 文件已存在，无需初始化。"
    fi
    display_statistics
}

# 函数：获取服务器上的进程并确定服务器类型
get_server_type() {
    # 导入配置文件
    source ./bash/cmcc_hcs.cfg

    for target_ip in "${IP_ARRAY[@]}"; do
        # 通过远程命令获取所有需要的进程信息
        local processes=$(ssh "${target_ip}" "ps -ef | grep ${BASE_PATH}" | grep -vE 'grep|xunjian|hcsmonit|cp ' | awk '{print $8}' | awk -F'/' '{print $NF, $(NF-2)}')
    
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
        if grep -q "${target_ip}_TYPE=" $OUTPUT_CFG; then
            sed -i "s|${target_ip}_TYPE=.*|${target_ip}_TYPE=${server_type}|g" $OUTPUT_CFG
            sed -i "s|${target_ip}_PROCESSES=.*|${target_ip}_PROCESSES=${proc_names}|g" $OUTPUT_CFG
            sed -i "s|${target_ip}_LOG_PATHS=.*|${target_ip}_LOG_PATHS=${log_paths%,}|g" $OUTPUT_CFG
            sed -i "s|${target_ip}_CFG_PATHS=.*|${target_ip}_CFG_PATHS=${cfg_paths%,}|g" $OUTPUT_CFG
        else
            echo "${target_ip}_TYPE=${server_type}" >> $OUTPUT_CFG
            echo "${target_ip}_PROCESSES=${proc_names}" >> $OUTPUT_CFG
            echo "${target_ip}_LOG_PATHS=${log_paths%,}" >> $OUTPUT_CFG
            echo "${target_ip}_CFG_PATHS=${cfg_paths%,}" >> $OUTPUT_CFG
        fi
    done
}


# 函数：根据进程名称确定服务器类型
determine_server_type() {
    local processes="$1"
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
    # 定义关联数组
    declare -A server_types process_combinations individual_processes

    # 读取 OUTPUT_CFG 文件内容
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
    done < "$OUTPUT_CFG"

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





# 根据巡检日志打印巡检结果到屏幕
print_result(){
	cat ${xunjian_log}|sort|awk '{print $2,$3,$4,$5,$6}'|awk 'BEGIN {
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
		cat ${xunjian_error_log}|awk 'BEGIN {
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

