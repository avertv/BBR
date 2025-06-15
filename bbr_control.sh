#!/bin/bash

# Проверка прав root
if [ "$(id -u)" != "0" ]; then
    echo "Этот скрипт должен быть запущен с правами root (sudo)."
    exit 1
fi

# Проверка версии ядра и поддержки BBR
check_bbr_support() {
    KERNEL_VERSION=$(uname -r)
    echo "Версия ядра: $KERNEL_VERSION"

    # Проверка наличия модулей BBR и fq
    if grep -q "CONFIG_TCP_CONG_BBR=m\|CONFIG_TCP_CONG_BBR=y" /boot/config-$KERNEL_VERSION && \
       grep -q "CONFIG_NET_SCH_FQ=m\|CONFIG_NET_SCH_FQ=y" /boot/config-$KERNEL_VERSION; then
        echo "Ядро поддерживает BBR и fq."
    else
        echo "Ошибка: Ядро не поддерживает BBR или fq. Требуется ядро версии 4.9 или выше."
        exit 1
    fi
}

# Проверка текущего состояния BBR
check_bbr_status() {
    CURRENT_QDISC=$(sysctl -n net.core.default_qdisc)
    CURRENT_CONGESTION=$(sysctl -n net.ipv4.tcp_congestion_control)

    echo "Текущий qdisc: $CURRENT_QDISC"
    echo "Текущий алгоритм управления перегрузкой: $CURRENT_CONGESTION"

    if [ "$CURRENT_CONGESTION" = "bbr" ] && [ "$CURRENT_QDISC" = "fq" ]; then
        echo "BBR уже включен."
        BBR_ENABLED=1
    else
        echo "BBR не включен."
        BBR_ENABLED=0
    fi
}

# Включение BBR
enable_bbr() {
    echo "Включение BBR..."

    # Добавление параметров в /etc/sysctl.conf
    if ! grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf; then
        echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    fi
    if ! grep -q "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf; then
        echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    fi

    # Применение изменений
    sysctl -p > /dev/null
    echo "BBR успешно включен."
}

# Выключение BBR
disable_bbr() {
    echo "Выключение BBR..."

    # Замена BBR на cubic и fq на fq_codel
    sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
    echo "net.core.default_qdisc=fq_codel" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=cubic" >> /etc/sysctl.conf

    # Применение изменений
    sysctl -p > /dev/null
    echo "BBR успешно выключен. Используется cubic и fq_codel."
}

# Проверка доступных алгоритмов управления перегрузкой
check_available_congestion() {
    echo "Доступные алгоритмы управления перегрузкой TCP:"
    cat /proc/sys/net/ipv4/tcp_available_congestion_control
}

# Меню
echo "Скрипт для управления BBR на Ubuntu 24.04.2 LTS"
echo "---------------------------------------------"
check_bbr_support
check_bbr_status
check_available_congestion
echo "---------------------------------------------"
echo "Выберите действие:"
echo "1) Включить BBR"
echo "2) Выключить BBR"
echo "3) Выход"
read -p "Введите номер (1-3): " choice

case $choice in
    1)
        enable_bbr
        check_bbr_status
        ;;
    2)
        disable_bbr
        check_bbr_status
        ;;
    3)
        echo "Выход из скрипта."
        exit 0
        ;;
    *)
        echo "Неверный выбор. Выход."
        exit 1
        ;;
esac
