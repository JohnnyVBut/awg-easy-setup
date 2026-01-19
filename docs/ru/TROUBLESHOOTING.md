# Устранение неполадок

**Русский** | [English](../en/TROUBLESHOOTING.md)

## Проблемы с SSH

### Отказ в подключении
```bash
# Проверить статус SSH
systemctl status ssh

# Проверить прослушивание порта
ss -tuln | grep 9722

# Проверить UFW
sudo ufw status | grep 9722
```

**Решение:**
```bash
sudo systemctl start ssh
sudo ufw allow 9722/tcp
sudo ufw reload
```

### Permission Denied (publickey)
```bash
# Используйте пароль из вывода установки
ssh -p 9722 admino@SERVER_IP

# Затем добавьте свой ключ
cat ~/.ssh/id_rsa.pub | ssh -p 9722 admino@SERVER 'cat >> ~/.ssh/authorized_keys'
```

## Проблемы с VPN UI

### Нет доступа из VPN
```bash
# Проверить контейнер
docker ps | grep awg-easy

# Проверить логи
docker logs awg-easy

# Перезапустить контейнер
docker restart awg-easy
```

### UI доступен из Интернета (должен быть заблокирован)
```bash
# Применить блокировку вручную
sudo /usr/local/sbin/lock-awg-ui.sh

# Проверить
sudo iptables -S DOCKER-USER | grep 8888
```

### Забыли пароль UI
```bash
# Сгенерировать новый пароль
NEW_PASS=$(openssl rand -base64 24)
echo "Новый пароль: $NEW_PASS"

# Сгенерировать хеш
NEW_HASH=$(htpasswd -nbB admin "$NEW_PASS" | cut -d: -f2)

# Пересоздать контейнер с новым хешем
docker stop awg-easy
docker rm awg-easy
# Повторно выполнить docker run с -e PASSWORD_HASH="$NEW_HASH"
```

## Проблемы с контейнером

### Контейнер постоянно перезапускается
```bash
# Проверить логи
docker logs awg-easy

# Частые исправления:
# 1. Загрузить модуль
sudo modprobe wireguard

# 2. Исправить права
sudo chown -R $(whoami):$(whoami) ~/.awg-easy/
chmod 700 ~/.awg-easy/
```

## Проблемы VPN клиента

### Не удается подключиться
```bash
# На сервере:
# 1. Проверить брандмауэр
sudo ufw status | grep 54321

# 2. Проверить контейнер
docker ps | grep awg-easy
docker logs awg-easy

# 3. Проверить что endpoint в конфиге совпадает с IP сервера
```

### Подключен, но нет интернета
```bash
# Проверить IP forwarding
docker exec awg-easy sysctl net.ipv4.ip_forward
# Должно быть: 1

# Если нет:
docker restart awg-easy
```

### Медленная скорость
```bash
# Тест без VPN
speedtest

# Тест с VPN
sudo awg-quick up awg0
speedtest

# Попробуйте уменьшить MTU в конфиге:
# MTU = 1380
```

## Проблемы с брандмауэром

### UFW не сохраняется
```bash
# Включить UFW
sudo ufw enable

# Включить при загрузке
sudo systemctl enable ufw
```

### Заблокирован после смены порта
Через консоль:
```bash
# Вернуть порт 22
sudo nano /etc/ssh/sshd_config
# Изменить Port на 22
sudo systemctl restart ssh
sudo ufw allow 22/tcp
```

## Аварийное восстановление

### Полный сброс
```bash
# 1. Резервная копия конфигов
tar czf backup.tar.gz ~/.awg-easy/

# 2. Остановить контейнер
docker stop awg-easy
docker rm awg-easy

# 3. Сбросить брандмауэр
sudo ufw --force reset
sudo ufw enable

# 4. Повторно запустить скрипт установки
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/awg-easy-setup/main/setup.sh | sudo bash
```

## Диагностика

Собрать информацию о системе:
```bash
{
  echo "=== Система ==="
  uname -a
  lsb_release -a
  
  echo "=== Docker ==="
  docker version
  docker ps -a
  docker logs awg-easy --tail 50
  
  echo "=== Сеть ==="
  ip addr
  ss -tuln
  
  echo "=== Брандмауэр ==="
  sudo ufw status verbose
  sudo iptables -S DOCKER-USER
  
} > diagnostics.txt
```

## Получить помощь

- [GitHub Issues](https://github.com/YOUR_USERNAME/awg-easy-setup/issues)
- [GitHub Discussions](https://github.com/YOUR_USERNAME/awg-easy-setup/discussions)
