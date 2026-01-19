# Модель безопасности

**Русский** | [English](../en/SECURITY.md)

## Уровни защиты

### Уровень 1: Усиление SSH
- Порт: 9722 (нестандартный)
- Аутентификация: Только публичные ключи
- Root логин: Отключен
- Пароли: Отключены

### Уровень 2: Брандмауэр UFW
```
Разрешено: 9722/tcp (SSH)
Разрешено: 54321/udp (AmneziaWG)
Разрешено из 10.8.0.0/24: 8888/tcp (UI)
Запрещено: 8888/tcp (Интернет)
```

### Уровень 3: iptables DOCKER-USER
Предотвращает обход UFW со стороны Docker:
```bash
iptables -I DOCKER-USER -s 10.8.0.0/24 -p tcp --dport 8888 -j ACCEPT
iptables -A DOCKER-USER -p tcp --dport 8888 -j DROP
```

### Уровень 4: Возможности контейнера
- Capabilities: только NET_ADMIN, SYS_MODULE
- Без привилегированного режима
- Без лишнего доступа

## Фазы безопасности

### Начальная загрузка (30-60 сек)
- UI доступен из Интернета
- Случайный пароль с bcrypt
- Минимальное окно экспозиции

### Продакшн (бессрочно)
- UI доступен ТОЛЬКО из VPN
- iptables + systemd персистентность
- Принцип нулевого доверия

## Модель угроз

### Защищает от:
✅ Bruteforce SSH  
✅ Несанкционированный доступ к UI  
✅ Сканирование портов  
✅ Утечка конфигураций VPN  

### НЕ защищает от:
❌ Украденный SSH ключ  
❌ 0-day уязвимости AmneziaWG  
❌ Физический доступ к серверу  
❌ Скомпрометированный VPN клиент  
❌ DDoS атаки  

## Лучшие практики

1. **Сохраняйте SSH ключи** в безопасном месте
2. **Регулярно обновляйте**: `apt update && apt upgrade`
3. **Мониторьте логи**: `journalctl -u ssh`, `docker logs awg-easy`
4. **Ротация VPN клиентов** ежемесячно
5. **Используйте сильные пароли** для шифрования ключей

## Чеклист аудита

```bash
# Конфиг SSH
sudo sshd -T | grep -E 'port|password|root'

# Брандмауэр
sudo ufw status numbered
sudo iptables -S DOCKER-USER

# Контейнер
docker inspect awg-easy | jq '.[0].HostConfig.CapAdd'

# Сканирование портов (внешнее)
nmap -p- YOUR_SERVER_IP
```

## Механизм персистентности

Systemd сервис обеспечивает сохранение правил DOCKER-USER после перезагрузки:

```bash
systemctl status lock-awg-ui.service
```

Скрипт: `/usr/local/sbin/lock-awg-ui.sh`  
Сервис: `/etc/systemd/system/lock-awg-ui.service`

## Реагирование на инциденты

При компрометации:

1. **Немедленно**: `sudo ufw deny from any`
2. **Остановить VPN**: `docker stop awg-easy`
3. **Сохранить логи**: `journalctl > /tmp/logs.txt`
4. **Анализ**: Проверить логи аутентификации, процессы, соединения
5. **Восстановление**: Чистый сервер + повторное развертывание

## Ссылки

- [Безопасность AmneziaWG](https://github.com/amnezia-vpn/amneziawg/blob/master/README.md)
- [Безопасность Docker](https://docs.docker.com/engine/security/)
- [Усиление SSH - Mozilla](https://infosec.mozilla.org/guidelines/openssh)
