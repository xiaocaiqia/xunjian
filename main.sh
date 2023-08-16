#!/bin/bash

# 获取当前的日期和时间
CURRENT_TIMESTAMP=$(date +%F-%T)
export CURRENT_TIMESTAMP # 让这个变量对子脚本和函数可见

source ./bash/dis.sh
source ./bash/out.sh
source ./bash/nat.sh

# 主函数
main(){
	# 在脚本开头获取时间戳
	CURRENT_TIMESTAMP=$(date +%F-%T)

	# 定义需要的参数值
	local path="/data"
	local dis_ip="./ip/dis.ip"
	local out_ip="./ip/out.ip"
	local nat_ip="./ip/nat.ip"
	local sleep_time="2"
	local sleep_time_hcs="5"

	# 输出功能菜单
	printf "%15s移动4G3.0合成巡检脚本功能菜单\n"
	printf "%15s1.巡检dis服务器\n"
	printf "%15s2.巡检out服务器\n"
	printf "%15s3.巡检nat服务器\n"
	printf "%15s0.退出\n"
	printf "请输入功能编号：\n"

	# 读入用户输入的功能编号
	read -t 60 -p "功能编号：" num1

	# 根据用户输入执行不同的函数，并传递相应的参数
	case ${num1} in
		"1")
			# 巡检dis服务器
			dis_server "${path}" "${dis_ip}" "${sleep_time}" "${sleep_time_hcs}"
			;;
		"2")
			# 巡检out服务器
			out_server "${path}" "${out_ip}" "${sleep_time}" "${sleep_time_hcs}"
			;;
		"3")
			# 巡检nat服务器
			nat_server "${path}" "${nat_ip}" "${sleep_time}" "${sleep_time_hcs}"
			;;
		"0")
			# 退出程序
			exit
			;;
		*)
			# 用户输入错误的功能编号
			echo "请输入正确的功能编号:1,2,3,0"
			;;
	esac
}

# 调用主函数
main
