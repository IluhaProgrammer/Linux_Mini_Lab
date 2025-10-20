# 🧠 DevSecOps Lab — Полная Практика (Одна ВМ, Namespace, DHCP, NAT, Backup)

### Версия: Ubuntu 25.10 (Desktop / VMware NAT)
**Автор:** 159NoScam 
**Направление развития:** DevSecOps / Автоматизация инфраструктуры  
**Дата обновления:** Октябрь 2025  

---

## 🚀 Описание проекта

Этот проект — полноценная лаборатория **DevSecOps-практики**, реализованная **внутри одной виртуальной машины** (Ubuntu 25.10).  
В ней симулируется мини-инфраструктура, включающая:

- изолированные сетевые пространства (`namespace`),
- DHCP-сервер и NAT-маршрутизацию,
- системный firewall на `iptables`,
- безопасное подключение по SSH-ключам,
- автоматическое резервное копирование через `rsync` и `cron`,
- архивирование логов через `tar`.

Цель проекта — отработать на практике навыки **DevOps + Security**, полностью на локальной машине.

---

## 🧩 Архитектура

```
┌───────────────────────────┐
│       Основная ВМ         │
│ ┌───────────────────────┐ │
│ │ Namespace: vm2        │ │
│ │  - Интерфейс veth1    │ │
│ │  - DHCP IP            │ │
│ │  - SSH → Основная ВМ  │ │
│ └───────────────────────┘ │
│                           │
│ veth0 <--> veth1 (связка) │
│ DHCP + NAT + Firewall     │
│ NGINX + Backups (/backups)│
└───────────────────────────┘
```

**Основная ВМ** — выполняет роль хоста (DHCP, NAT, Firewall, Nginx, хранилище бэкапов).  
**Namespace vm2** — эмулирует вторую ВМ (система-клиент, которая делает бэкапы и подключается по SSH).

---

## ⚙️ Основные компоненты

### 🔹 Сеть и DHCP
- Создание пары интерфейсов `veth0` и `veth1` для связи между основным пространством и namespace.  
- DHCP-сервер (`isc-dhcp-server`) раздаёт IP-адреса в подсети `192.168.50.0/24`.  
- NAT через `iptables` позволяет namespace выходить в Интернет через интерфейс основной ВМ.  

### 🔹 Безопасность и Firewall
- Реализован через `iptables` (без использования `ufw`).  
- Политика по умолчанию — `INPUT DROP`, разрешено только:
  - Локальный трафик (`lo`),
  - Установленные соединения (`ESTABLISHED, RELATED`),
  - Порты `22` (SSH) и `80` (HTTP).  
- Настройки сохраняются через `netfilter-persistent`.  

### 🔹 SSH-доступ
- В `vm2` создаётся пара SSH-ключей (`ed25519`).  
- Публичный ключ копируется на основную ВМ.  
- После этого `vm2` может подключаться к `192.168.50.1` без пароля.  
- Используется для передачи данных при бэкапе.  

### 🔹 Резервное копирование (rsync)
- Используется `rsync` для синхронизации `/etc/` из `vm2` на основную ВМ.  
- Передача идёт по SSH, используя ранее сгенерированный ключ.  
- Каталог для бэкапов: `/backups/etc`.  
- Работает инкрементно — копируются только изменения, что экономит время и трафик.  

### 🔹 Автоматизация через cron
- Настраивается cron-задача, которая **каждый день в 2:00 ночи** выполняет резервное копирование.  
- Логи выполнения пишутся в `/var/log/backup-rsync.log`.  
- Команда запускается с правами `root` через `sudo crontab -e`.  

### 🔹 Архивирование логов (tar)
- Ежедневно архивируются системные логи из `/var/log` в каталог `/backups/logs/`.  
- Архивы именуются по дате, например:
  ```
  /backups/logs/logs_2025-10-20.tar.gz
  ```

---

## 📂 Структура каталогов

```
/backups/
├── etc/              # Конфигурационные бэкапы
├── logs/             # Архивы логов (tar.gz)
└── backup-rsync.log  # Лог выполнения rsync
```

---

## 🔑 Основные команды для проверки

```bash
# Проверка IP внутри namespace
sudo ip netns exec vm2 ip a

# Проверка доступа в интернет
sudo ip netns exec vm2 ping -c 3 8.8.8.8

# Проверка nginx и ssh на основной ВМ
sudo ss -tulpn | grep -E '22|80'

# Ручной запуск резервного копирования
sudo ip netns exec vm2 rsync -azhAX -e "ssh -i /home/ubuntu/.ssh/id_ed25519" /etc/ ubuntu@192.168.50.1:/backups/etc/

# Просмотр логов cron-задачи
sudo tail -n 50 /var/log/backup-rsync.log

# Проверка архивов
ls -lh /backups/etc/
ls -lh /backups/logs/
```

---

## 🧰 Используемые инструменты

| Категория | Инструмент | Назначение |
|-----------|-------------|------------|
| Сеть | `ip`, `ip netns`, `isc-dhcp-server` | Создание namespace и DHCP |
| Безопасность | `iptables`, `netfilter-persistent` | NAT, Firewall |
| Резервное копирование | `rsync`, `ssh` | Передача данных по ключу |
| Автоматизация | `cron` | Планировщик заданий |
| Архивирование | `tar`, `gzip` | Архивация логов |
| Веб-сервис | `nginx` | Проверка работоспособности |
| Мониторинг | `ss`, `ping` | Проверка сетевых сервисов |

---

## 🧠 Философия DevSecOps

> “Безопасность — это не настройка, а культура.  
> Автоматизация — не цель, а инструмент надёжности.”

Данный проект учит мыслить как **DevSecOps-инженер**:

- всё должно быть **автоматизировано и воспроизводимо**,  
- минимальные права и открытые порты,  
- безопасный доступ — только по ключам,  
- мониторинг и аудит каждого действия,  
- надёжные резервные копии и их контроль.  

---

## 🌱 Пути развития (Roadmap)

Если ты освоил эту лабораторию — вот твои **следующие уровни роста**:

### 🧩 Уровень 2 — Наблюдаемость
- Установи **Prometheus + Node Exporter** для метрик.  
- Добавь **Grafana Loki** для централизованного сбора логов.  

### 🔐 Уровень 3 — Безопасность
- Настрой **Fail2Ban**, **AppArmor** или **SELinux**.  
- Добавь `auditd` для контроля изменений в системе.  

### 🧬 Уровень 4 — Автоматизация и IaC
- Перепиши сценарий на **Ansible**.  
- Используй **Terraform** с локальными провайдерами.  
- Вынеси vm2 в **Docker-контейнер**.  

### ☁️ Уровень 5 — Облако и CI/CD
- Разверни аналогичную среду в **AWS / Azure / GCP**.  
- Настрой CI/CD с **GitHub Actions**.  
- Сохраняй бэкапы в **S3 / MinIO**.  

---

## 🧾 Лицензия

**MIT License** — свободно используй, изучай и модифицируй проект под свои задачи.  

---

## 👨‍💻 Автор

Создано инженером, который сочетает **DevOps-практики** и **безопасность систем** (DevSecOps mindset).  
Проект предназначен для тех, кто хочет:

- понимать работу сетей и Linux-инфраструктуры,  
- внедрять безопасную автоматизацию,  
- проектировать отказоустойчивые системы с нуля.  

> “Если ты можешь построить безопасную инфраструктуру на одной ВМ —  
> ты сможешь управлять ею в любой облачной среде.”

---

## 💬 Контакты и вклад

Pull Request’ы, идеи и улучшения приветствуются!  
Будет особенно интересно добавить:
- расширенные firewall-правила,  
- автоматизацию с systemd timers,  
- поддержку контейнеров и кластеров.

---

# Команды для выполнения этого проекта поочередности

``` bash
sudo ip netns add vm2
sudo ip link add veth0 type veth peer name veth1
sudo ip link set veth1 netns vm2

sudo ip addr add 192.168.50.1/24 dev veth0
sudo ip link set veth0 up

sudo ip netns exec vm2 ip link set lo up
sudo ip netns exec vm2 ip link set veth1 up

# PART 1 — DHCP SERVER

sudo apt update
sudo apt install -y isc-dhcp-server

sudo tee /etc/dhcp/dhcpd.conf <<EOF
default-lease-time 3600;
max-lease-time 7200;
authoritative;

subnet 192.168.50.0 netmask 255.255.255.0 {
    range 192.168.50.100 192.168.50.200;
    option routers 192.168.50.1;
    option domain-name-servers 8.8.8.8, 1.1.1.1;
}
EOF

sudo sed -i 's|INTERFACESv4=""|INTERFACESv4="veth0"|' /etc/default/isc-dhcp-server
sudo systemctl restart isc-dhcp-server
sudo systemctl enable isc-dhcp-server

sudo ip netns exec vm2 dhclient veth1
sudo ip netns exec vm2 ip a

# PART 2 — NAT + INTERNET

sudo sysctl -w net.ipv4.ip_forward=1

sudo apt install -y iptables iptables-persistent

sudo iptables -t nat -A POSTROUTING -s 192.168.50.0/24 -o end33 -j MASQUERADE
sudo iptables -A FORWARD -i end33 -o veth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i veth0 -o end33 -j ACCEPT

sudo netfilter-persistent save

# PART 3 — FIREWALL (iptables, no ufw)

sudo iptables -F INPUT
sudo iptables -P INPUT DROP
sudo iptables -P OUTPUT ACCEPT

sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT

sudo netfilter-persistent save

# PART 4 — SSH KEYS (vm2 -> main)

sudo ip netns exec vm2 mkdir -p /home/ubuntu/.ssh
sudo ip netns exec vm2 ssh-keygen -t ed25519 -f /home/ubuntu/.ssh/id_ed25519 -N ""
sudo ip netns exec vm2 ssh-keyscan 192.168.50.1 >> /home/ubuntu/.ssh/known_hosts

# copy key to main vm
sudo ip netns exec vm2 ssh-copy-id -i /home/ubuntu/.ssh/id_ed25519.pub ubuntu@192.168.50.1

# PART 5 — NGINX (service check)

sudo apt install -y nginx
sudo systemctl enable --now nginx

# PART 6 — BACKUP VIA RSYNC

sudo mkdir -p /backups/etc
sudo chown ubuntu:ubuntu /backups/etc

sudo ip netns exec vm2 rsync -azhAX -e "ssh -i /home/ubuntu/.ssh/id_ed25519" \
/etc/ ubuntu@192.168.50.1:/backups/etc/

# PART 7 — CRON

( sudo crontab -l 2>/dev/null; echo \
'0 2 * * * /usr/bin/rsync -azhAX --delete /etc/ /backups/etc/ >> /var/log/backup-rsync.log 2>&1' ) \
| sudo crontab -

# PART 8 — TAR LOG ARCHIVES

sudo mkdir -p /backups/logs
sudo tar -czvf /backups/logs/logs_$(date +%F).tar.gz /var/log

# PART 9 — CHECKS

sudo ip netns exec vm2 ping -c 2 8.8.8.8
sudo ss -tulpn | grep -E '22|80'
ls -lh /backups/etc/
ls -lh /backups/logs/
sudo ip netns exec vm2 ssh ubuntu@192.168.50.1 "hostname"

```

✅ **Тестировано:** Ubuntu 25.10  
✅ **Состояние:** Стабильная версия  
✅ **Назначение:** Практическая DevSecOps-лаборатория  
✅ **Следующий шаг:** Автоматизация через Ansible  
