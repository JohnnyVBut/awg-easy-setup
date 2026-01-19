# Руководство по установке

**Русский** | [English](../en/INSTALLATION.md)

## Быстрый старт

### Рекомендуется: Установка одной командой

```bash
curl -fsSL https://raw.githubusercontent.com/JohnnyVBut/awg-easy-setup/main/setup.sh -o /tmp/awg-setup.sh && sudo bash /tmp/awg-setup.sh
```

**Или с wget:**

```bash
wget -qO /tmp/awg-setup.sh https://raw.githubusercontent.com/JohnnyVBut/awg-easy-setup/main/setup.sh && sudo bash /tmp/awg-setup.sh
```

### Альтернатива: Ручная проверка

```bash
# Скачать скрипт
curl -fsSL https://raw.githubusercontent.com/JohnnyVBut/awg-easy-setup/main/setup.sh -o /tmp/awg-setup.sh

# Проверить синтаксис
bash -n /tmp/awg-setup.sh

# Просмотреть содержимое (опционально)
less /tmp/awg-setup.sh

# Запустить установку
sudo bash /tmp/awg-setup.sh
```

## Требования

- Ubuntu 20.04+ или Debian 11+
- Минимум 1GB RAM
- Root доступ
- Рекомендуется чистая установка

## Этапы установки

### 1. Обновление системы [1-2/11]
Скрипт обновляет пакеты и устанавливает Docker из официального репозитория.

### 2. Создание пользователя [3/11]
10-секундный запрос имени (по умолчанию `admino`).

### 3. Настройка SSH [4-6/11]
- Генерирует Ed25519 ключи
- Импортирует authorized_keys из root
- Усиливает конфиг SSH (порт 9722, только ключи)

### 4. Настройка брандмауэра [7/11]
Открывает порты SSH (9722/tcp) и AmneziaWG (54321/udp).

### 5. Развертывание контейнера [8/11]
Запускает контейнер awg-easy с временным доступом к UI.

**КРИТИЧНО**: Создайте VPN клиента перед нажатием ENTER!

### 6. Блокировка UI [9/11]
Ограничивает веб-интерфейс доступом только из VPN (10.8.0.0/24).

### 7. Сводка и перезагрузка [10-11/11]
Отображает учетные данные и перезагружает сервер.

## После установки

```bash
# Подключение по SSH
ssh -p 9722 admino@YOUR_SERVER_IP

# Проверка статуса
docker ps | grep awg-easy
sudo ufw status
sudo iptables -S DOCKER-USER
```

## Проверка

```bash
# Тест блокировки UI (должен быть таймаут)
curl --max-time 5 http://YOUR_SERVER_IP:8888

# Подключитесь к VPN, затем тест (должно работать)
curl http://10.8.0.1:8888
```

## Объяснение методов установки

### Метод 1: Установка одной командой (рекомендуется)

```bash
curl -fsSL https://raw.githubusercontent.com/JohnnyVBut/awg-easy-setup/main/setup.sh -o /tmp/awg-setup.sh && sudo bash /tmp/awg-setup.sh
```

**Почему этот метод:**
- ✅ Одна команда copy-paste
- ✅ Надежное выполнение (из файла, избегает проблем парсинга shell)
- ✅ Скрипт полностью скачивается перед выполнением
- ✅ Работает одинаково на всех системах

**Как это работает:**
1. Скачивает скрипт в `/tmp/awg-setup.sh`
2. Запускается только если скачивание успешно (оператор `&&`)
3. Выполняется из файловой системы (не через pipe)

### Метод 2: Клонирование репозитория

```bash
git clone https://github.com/JohnnyVBut/awg-easy-setup.git
cd awg-easy-setup
sudo bash setup.sh
```

**Когда использовать:**
- Нужен полный доступ к репозиторию
- Требуется изменить скрипты
- Создание кастомного развертывания

### Метод 3: Конкретный релиз

```bash
curl -fsSL https://github.com/JohnnyVBut/awg-easy-setup/releases/download/v1.0.0/setup.sh -o /tmp/awg-setup.sh && sudo bash /tmp/awg-setup.sh
```

**Когда использовать:**
- Production развертывания
- Нужны воспроизводимые установки
- Привязка к проверенной версии

## Следующие шаги

- [Настройка клиентов AmneziaVPN](CLIENTS.md)
- [Модель безопасности](SECURITY.md)
- [Устранение неполадок](TROUBLESHOOTING.md)
