# 使用 Ubuntu 作为基础镜像
FROM ubuntu:22.04

# 设置环境变量避免交互式安装
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# 安装必要的系统依赖
RUN apt-get update -y && \
    apt-get install -y \
        build-essential \
        libssl-dev \
        zip \
        pkg-config \
        wget \
        curl \
        cron \
        systemctl \
    && rm -rf /var/lib/apt/lists/*

# 创建 hopsignal 目录
RUN mkdir -p /home/hopsignal

# 设置工作目录
WORKDIR /home/hopsignal

# 下载 HopSignal 二进制文件
RUN wget -q -O /home/hopsignal/hopsignal https://www.hoptodesk.com/servers/hopsignal.fil && \
    chmod 755 hopsignal

# 创建 fedlist.txt
RUN touch fedlist.txt

# 创建 hopsignal.sh 脚本
RUN cat <<EOF > /home/hopsignal/hopsignal.sh
#!/bin/bash
cd /home/hopsignal

# 如果存在数据目录挂载，使用挂载的文件
if [ -d "/home/hopsignal/data" ]; then
    # 确保数据目录中的文件存在
    [ ! -f "/home/hopsignal/data/fedlist.txt" ] && touch /home/hopsignal/data/fedlist.txt

    # 使用数据目录中的文件
    ./hopsignal --ADDR 0.0.0.0:80 --FEDLIST /home/hopsignal/data/fedlist.txt --FEDADDR 0.0.0.0:82 --FEDPWD 123456789 --LOGFILE /home/hopsignal/data/hs.log
else
    # 使用本地文件
    ./hopsignal --ADDR 0.0.0.0:80 --FEDLIST fedlist.txt --FEDADDR 0.0.0.0:82 --FEDPWD 123456789 --LOGFILE hs.log
fi
EOF

# 创建监控脚本
RUN cat <<'EOF' > /home/hopsignal/hop-cron.sh
#!/bin/bash

# 确定日志文件路径
if [ -d "/home/hopsignal/data" ]; then
    LOG_FILE="/home/hopsignal/data/hs.log"
else
    LOG_FILE="/home/hopsignal/hs.log"
fi

FILESIZE=$(stat -c%s "$LOG_FILE" 2>/dev/null || echo "0")

# 当日志文件超过 100MB 时重启服务
if [ $FILESIZE -ge 100000000 ]; then
    echo "$(date): Log file size exceeded 100MB, restarting service"
    pkill -f hopsignal
    sleep 2
    /home/hopsignal/hopsignal.sh &
    exit
fi

# 检查 WebSocket 连接
TESTSOCKET=$(curl -s --max-time 5 -i -N -H "Connection: Upgrade" -H "Upgrade: websocket" -H "Host: 0.0.0.0:80" -H "Sec-WebSocket-Key: SGVsbG8sIHdvcmxkIQ==" -H "Sec-WebSocket-Version: 13" 0.0.0.0:80 2>/dev/null || echo "")

if [[ $TESTSOCKET == *"Switching"* ]]; then
    echo "$(date): WebSockets Online"
else
    echo "$(date): WebSockets Offline - Restarting service"
    pkill -f hopsignal
    sleep 2
    /home/hopsignal/hopsignal.sh &
fi
EOF

# 创建进程监控脚本
RUN cat <<'EOF' > /home/hopsignal/process-monitor.sh
#!/bin/bash
while true; do
    if ! pgrep -f hopsignal >/dev/null; then
        echo "$(date): HopSignal process not found - Starting service"
        /home/hopsignal/hopsignal.sh &
    fi
    sleep 60
done
EOF

# 创建启动脚本
RUN cat <<'EOF' > /home/hopsignal/start.sh
#!/bin/bash

# 启动 HopSignal 服务
echo "Starting HopSignal service..."
/home/hopsignal/hopsignal.sh &

# 等待服务启动
sleep 5

# 启动进程监控
echo "Starting process monitor..."
/home/hopsignal/process-monitor.sh &

# 启动定期检查（每分钟执行一次监控脚本）
echo "Starting health check monitor..."
while true; do
    /home/hopsignal/hop-cron.sh
    sleep 60
done
EOF

# 设置脚本权限
RUN chmod 755 /home/hopsignal/*.sh

# 暴露端口
EXPOSE 80 82

# 创建数据卷挂载点
VOLUME ["/home/hopsignal/data"]

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:80 || exit 1

# 启动服务
CMD ["/home/hopsignal/start.sh"]
