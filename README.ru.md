# AWG-Easy Setup Script

🔒 Автоматизированное развертывание защищенного AmneziaWG VPN сервера на Ubuntu/Debian

**Русский** | [English](README.md)

## Быстрая установка

**⚠️ Выполняйте только на чистом сервере!**

### Рекомендуется: Установка одной командой (скачивание → запуск)

```bash
curl -fsSL https://raw.githubusercontent.com/JohnnyVBut/awg-easy-setup/main/install1.sh -o /tmp/awg-setup.sh && sudo bash /tmp/awg-setup.sh
```

**Или с wget:**

```bash
wget -qO /tmp/awg-setup.sh https://raw.githubusercontent.com/JohnnyVBut/awg-easy-setup/main/install1.sh && sudo bash /tmp/awg-setup.sh
```

### Альтернатива: Ручная проверка

```bash
# Скачать скрипт
curl -fsSL https://raw.githubusercontent.com/JohnnyVBut/awg-easy-setup/main/install1.sh -o /tmp/awg-setup.sh

# Проверить синтаксис
bash -n /tmp/awg-setup.sh

# Просмотреть содержимое (опционально)
less /tmp/awg-setup.sh

# Запустить установку
sudo bash /tmp/awg-setup.sh
```

## Что делает скрипт

✅ Обновляет систему и устанавливает Docker  
✅ Создает защищенного sudo-пользователя  
✅ Настраивает SSH (только ключи, нестандартный порт)  
✅ Разворачивает AmneziaWG VPN контейнер  
✅ **Автоматически создает первого VPN клиента через API**  
✅ **Показывает QR код и одноразовую ссылку в терминале**  
✅ **Автоматически блокирует веб-интерфейс после настройки**  

## Безопасность

- SSH: только публичные ключи, порт 9722, root отключен
- VPN UI: доступен **только из VPN** (10.72.254.0/24)
- Случайные пароли для всех аккаунтов
- UFW + iptables DOCKER-USER защита

## Системные требования

- Ubuntu 20.04+ или Debian 11+ (протестировано на Ubuntu 22.04 и 24.04)
- Минимум 1GB RAM
- Root доступ
- Чистая установка (рекомендуется)
- Интернет соединение для установки пакетов

## Процесс установки

### Шаг 1: Запрос имени пользователя (10 секунд)
```
[3/12] Creating a sudo user (you have 10 seconds to type a name)...
Enter new username (10s timeout): _
```
Введите имя или подождите таймаут → по умолчанию `admino`

### Шаг 2: Автоматическое создание VPN клиента (НОВОЕ!)
```
[9/12] Creating first VPN client via API...
→ Authenticating...
✓ Authenticated successfully
→ Creating VPN client...
✓ Client created successfully
✓ Client ID: 4acaf6ff-8d16-4edf-96ef-560f5885be53
→ Generating one-time download link...
✓ One-time link generated

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ ПЕРВЫЙ VPN КЛИЕНТ СОЗДАН!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Скачать конфиг (ОДНОРАЗОВАЯ ССЫЛКА - исчезает после скачивания):
  http://YOUR_IP:8888/cnf/abc123def456...

QR Code (отсканируйте в мобильном приложении AmneziaWG


):
█████████████████████████████████
███ ▄▄▄▄▄ █▀█ █▄▄▀▄█ ▄▄▄▄▄ ███
███ █   █ █▀▀▀ ▀ ▄ █ █   █ ███
...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Действия:**
1. **Отсканируйте QR код** в мобильном приложении AmneziaWG, ИЛИ
2. **Перейдите по одноразовой ссылке** чтобы скачать конфиг
3. **⚠️ Сохраните ссылку сразу** - она исчезнет после первого скачивания!

### Шаг 3: Доступ к веб-интерфейсу (опционально)
```
>>> TEMPORARY Web UI access is OPEN to the Internet.
    You can also access Web UI at:
    URL:  http://YOUR_IP:8888
    User: admin
    Pass: [ПОКАЗАН В ВЫВОДЕ]

Press ENTER to lock the Web UI to VPN-only access...
```

**Опционально:** Вы можете создать дополнительных клиентов через веб-интерфейс перед его блокировкой.

### Шаг 4: Сохранение учетных данных
```
==================== SUMMARY ====================
 User:                    admino
 User password:           [СЛУЧАЙНЫЙ ПАРОЛЬ]
 Root password:           [СЛУЧАЙНЫЙ ПАРОЛЬ]
 SSH:                     port 9722
 Web UI password:         [СЛУЧАЙНЫЙ ПАРОЛЬ]
=================================================
Press any key to reboot the host...
```

**⚠️ КРИТИЧНО:** Скопируйте весь вывод перед перезагрузкой!

### Шаг 4: Подключение после перезагрузки

```bash
# SSH подключение с новым портом:
ssh -p 9722 admino@YOUR_SERVER_IP

# Если ключ не импортировался, используйте "User password" из вывода
```

## После установки

### Доступ к веб-интерфейсу из VPN
```bash
# Сначала подключитесь к VPN, затем откройте (или свой адрес сервера из VPN подсети(если меняли при установке) - по умолчанию 10.72.254.1):
http://10.72.254.1:8888
```

### Проверка установки
```bash
# Статус контейнера
docker ps | grep awg-easy

# Логи VPN
docker logs awg-easy

# Правила брандмауэра
sudo ufw status verbose
sudo iptables -S DOCKER-USER

# Systemd юнит
systemctl status lock-awg-ui.service
```

## Документация

- [Полная инструкция](docs/ru/INSTALLATION.md)
- [Модель безопасности](docs/ru/SECURITY.md)
- [Устранение неполадок](docs/ru/TROUBLESHOOTING.md)
- [Настройка клиентов](docs/ru/CLIENTS.md)

## Архитектура

```
Internet
   │
   ├─[SSH:9722/tcp]──────────► sshd (pubkey only, no root)
   │
   ├─[AWG:54321/udp]─────────► Docker:awg-easy (AmneziaWG)
   │                                    │
   │                                    ├─ VPN: 10.8.0.0/24
   │                                    └─ UI: 8888/tcp
   │
   └─[UI:8888/tcp]─────X─────► DOCKER-USER chain
                         │             │
                         │             ├─ ACCEPT from 10.8.0.0/24
                         │             └─ DROP from *
                         │
                     [VPN tunnel]
                         │
                         └────────────► http://10.8.0.1:8888
```

## Философия безопасности

### Защита в глубину
- **Уровень 1**: Усиление SSH (нестандартный порт, только ключи)
- **Уровень 2**: Брандмауэр UFW на хосте
- **Уровень 3**: iptables DOCKER-USER (предотвращение обхода Docker)
- **Уровень 4**: Ограничение возможностей контейнера

### Нулевое доверие для VPN UI
- **Фаза начальной загрузки** (30-60 сек): UI доступен с bcrypt-защищенным случайным паролем
- **Продакшн фаза**: UI доступен ТОЛЬКО из VPN подсети
- **Персистентность**: Systemd обеспечивает сохранение правил после перезагрузки

## Альтернативные методы установки

### Из конкретного релиза
```bash
curl -fsSL https://github.com/JohnnyVBut/awg-easy-setup/releases/download/v1.0.0/setup.sh -o /tmp/awg-setup.sh && sudo bash /tmp/awg-setup.sh
```

### Клонирование репозитория
```bash
git clone https://github.com/JohnnyVBut/awg-easy-setup.git
cd awg-easy-setup
sudo bash setup.sh
```

## Модель угроз

### Защищает от:
✅ Bruteforce атак на SSH  
✅ Несанкционированного доступа к VPN UI  
✅ Сканирования портов (nmap)  
✅ Эксплуатации уязвимостей UI из Интернета  
✅ Утечки конфигураций VPN  

### НЕ защищает от:
❌ Скомпрометированного SSH приватного ключа  
❌ 0-day уязвимостей в AmneziaWG kernel модуле  
❌ Физического доступа к серверу  
❌ Атак через скомпрометированного VPN клиента  
❌ DDoS атак на AmneziaWG порт (54321/udp)  

## Вклад в проект

Вклад приветствуется! Пожалуйста:
1. Сделайте fork репозитория
2. Создайте feature ветку
3. Отправьте pull request

## Лицензия

MIT License - см. [LICENSE](LICENSE)

## Поддержка

- 🐛 [Сообщить о проблеме](https://github.com/JohnnyVBut/awg-easy-setup/issues)
- 💬 [Обсуждения](https://github.com/JohnnyVBut/awg-easy-setup/discussions)

## Благодарности

- [AmneziaWG](https://github.com/amnezia-vpn/amneziawg) - Улучшенный протокол WireGuard с обфускацией трафика
- [AmneziaVPN](https://amnezia.org/) - VPN клиент с поддержкой AmneziaWG
- [WireGuard](https://www.wireguard.com/) - Оригинальный быстрый современный VPN протокол
- [awg-easy](https://github.com/gennadykataev/awg-easy) - Веб-интерфейс для AmneziaWG

---

**⚠️ Уведомление о безопасности:** Этот скрипт изменяет критические системные настройки. Всегда проверяйте код перед запуском на production серверах.
