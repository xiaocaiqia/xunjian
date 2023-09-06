#!/bin/bash

# 获取当前的日期和时间
CURRENT_TIMESTAMP=$(date +%F-%T)
export CURRENT_TIMESTAMP # 让这个变量对子脚本和函数可见

source ./bash/common_functions.sh
source ./bash/secondary_menu.sh

# 主函数
main(){
	#初始化函数
	initialize

	# 初始化三类服务器的数组
	dis_servers=()
	out_servers=()
	nat_servers=()

	# 读取 server_type.cfg 文件
	while IFS= read -r line; do
	    if [[ $line == *"_TYPE=DIS"* ]]; then
        	ip=${line%%_*} # 提取 IP 地址
        	dis_servers+=("$ip")
    	elif [[ $line == *"_TYPE=OUT"* ]]; then
	        ip=${line%%_*} # 提取 IP 地址
        	out_servers+=("$ip")
    	elif [[ $line == *"_TYPE=NAT"* ]]; then
	        ip=${line%%_*} # 提取 IP 地址
        	nat_servers+=("$ip")
    	fi
	done < "bash/server_type.cfg"

	# 输出功能菜单
	echo ""
	printf "移动4G3.0合成巡检脚本功能菜单\n"
	printf "%7s1.巡检dis服务器\n"
	printf "%7s2.巡检out服务器\n"
	printf "%7s3.巡检nat服务器\n"
	printf "%7s4.巡检所有服务器\n"
	printf "%7s0.退出\n"
	printf "请输入功能编号：\n"

	# 读入用户输入的功能编号
	read -t 60 -p "功能编号：" option

	# 根据用户输入执行不同的函数，并传递相应的参数
	case ${option} in
		"1")
			# 巡检dis服务器
			secondary_menu "${dis_servers[@]}"
			;;
		"2")
			# 巡检out服务器
			secondary_menu "${out_servers[@]}"
			;;
		"3")
			# 巡检nat服务器
			secondary_menu "${nat_servers[@]}"
			;;
		"4")
			# 巡检所有服务器
			all_servers=("${dis_servers[@]}" "${out_servers[@]}" "${nat_servers[@]}")
        	secondary_menu "${all_servers[@]}"
			;;
		"0")
			# 退出程序
			exit 0
			;;
		*)
			# 用户输入错误的功能编号
			echo "无效选项"
			;;
	esac
}

# 调用主函数
main



