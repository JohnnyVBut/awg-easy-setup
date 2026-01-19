# Troubleshooting Guide

[Русская версия](../ru/TROUBLESHOOTING.md) | **English**

## SSH Issues

### Connection Refused
```bash
# Check SSH status
systemctl status ssh

# Check port listening
ss -tuln | grep 9722

# Check UFW
sudo ufw status | grep 9722
```

**Fix:**
```bash
sudo systemctl start ssh
sudo ufw allow 9722/tcp
sudo ufw reload
```

### Permission Denied (publickey)
```bash
# Use password from setup output
ssh -p 9722 admino@SERVER_IP

# Then add your key
cat ~/.ssh/id_rsa.pub | ssh -p 9722 admino@SERVER 'cat >> ~/.ssh/authorized_keys'
```

## VPN UI Issues

### Cannot Access from VPN
```bash
# Check container running
docker ps | grep awg-easy

# Check logs
docker logs awg-easy

# Restart container
docker restart awg-easy
```

### UI Accessible from Internet (Should Be Blocked)
```bash
# Apply lockdown manually
sudo /usr/local/sbin/lock-awg-ui.sh

# Verify
sudo iptables -S DOCKER-USER | grep 8888
```

### Forgot UI Password
```bash
# Generate new password
NEW_PASS=$(openssl rand -base64 24)
echo "New password: $NEW_PASS"

# Generate hash
NEW_HASH=$(htpasswd -nbB admin "$NEW_PASS" | cut -d: -f2)

# Recreate container with new hash
docker stop awg-easy
docker rm awg-easy
# Re-run docker run command with -e PASSWORD_HASH="$NEW_HASH"
```

## Container Issues

### Container Keeps Restarting
```bash
# Check logs
docker logs awg-easy

# Common fixes:
# 1. Load module
sudo modprobe wireguard

# 2. Fix permissions
sudo chown -R $(whoami):$(whoami) ~/.awg-easy/
chmod 700 ~/.awg-easy/
```

## VPN Client Issues

### Cannot Connect
```bash
# On server:
# 1. Check firewall
sudo ufw status | grep 54321

# 2. Check container
docker ps | grep awg-easy
docker logs awg-easy

# 3. Verify config endpoint matches server IP
```

### Connected but No Internet
```bash
# Check IP forwarding
docker exec awg-easy sysctl net.ipv4.ip_forward
# Should be: 1

# If not:
docker restart awg-easy
```

### Slow Speed
```bash
# Test without VPN
speedtest

# Test with VPN
sudo awg-quick up awg0
speedtest

# Try reducing MTU in config:
# MTU = 1380
```

## Firewall Issues

### UFW Not Persisting
```bash
# Enable UFW
sudo ufw enable

# Enable on boot
sudo systemctl enable ufw
```

### Locked Out After Port Change
Via console:
```bash
# Revert to port 22
sudo nano /etc/ssh/sshd_config
# Change Port to 22
sudo systemctl restart ssh
sudo ufw allow 22/tcp
```

## Emergency Recovery

### Complete Reset
```bash
# 1. Backup configs
tar czf backup.tar.gz ~/.awg-easy/

# 2. Stop container
docker stop awg-easy
docker rm awg-easy

# 3. Reset firewall
sudo ufw --force reset
sudo ufw enable

# 4. Re-run setup script
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/awg-easy-setup/main/setup.sh | sudo bash
```

## Diagnostics

Collect system info:
```bash
{
  echo "=== System ==="
  uname -a
  lsb_release -a
  
  echo "=== Docker ==="
  docker version
  docker ps -a
  docker logs awg-easy --tail 50
  
  echo "=== Network ==="
  ip addr
  ss -tuln
  
  echo "=== Firewall ==="
  sudo ufw status verbose
  sudo iptables -S DOCKER-USER
  
} > diagnostics.txt
```

## Getting Help

- [GitHub Issues](https://github.com/YOUR_USERNAME/awg-easy-setup/issues)
- [GitHub Discussions](https://github.com/YOUR_USERNAME/awg-easy-setup/discussions)
