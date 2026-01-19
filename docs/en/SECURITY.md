# Security Model

[Русская версия](../ru/SECURITY.md) | **English**

## Defense Layers

### Layer 1: SSH Hardening
- Port: 9722 (non-standard)
- Auth: Public keys only
- Root login: Disabled
- Password auth: Disabled

### Layer 2: UFW Firewall
```
Allow: 9722/tcp (SSH)
Allow: 54321/udp (AmneziaWG)
Allow from 10.8.0.0/24: 8888/tcp (UI)
Deny: 8888/tcp (Internet)
```

### Layer 3: iptables DOCKER-USER
Prevents Docker from bypassing UFW:
```bash
iptables -I DOCKER-USER -s 10.8.0.0/24 -p tcp --dport 8888 -j ACCEPT
iptables -A DOCKER-USER -p tcp --dport 8888 -j DROP
```

### Layer 4: Container Capabilities
- Capabilities: NET_ADMIN, SYS_MODULE only
- No privileged mode
- No unnecessary access

## Security Phases

### Bootstrap (30-60 sec)
- UI exposed to Internet
- Bcrypt-protected random password
- Minimal exposure window

### Production (indefinite)
- UI accessible ONLY from VPN
- iptables + systemd persistence
- Zero trust enforcement

## Threat Model

### Protects Against:
✅ SSH brute-force  
✅ Unauthorized UI access  
✅ Port scanning  
✅ VPN config leaks  

### Does NOT Protect Against:
❌ Stolen SSH key  
❌ AmneziaWG 0-day vulnerabilities  
❌ Physical server access  
❌ Compromised VPN client  
❌ DDoS attacks  

## Best Practices

1. **Backup SSH keys** securely
2. **Update regularly**: `apt update && apt upgrade`
3. **Monitor logs**: `journalctl -u ssh`, `docker logs awg-easy`
4. **Rotate VPN clients** monthly
5. **Use strong passphrases** for key encryption

## Audit Checklist

```bash
# SSH config
sudo sshd -T | grep -E 'port|password|root'

# Firewall
sudo ufw status numbered
sudo iptables -S DOCKER-USER

# Container
docker inspect awg-easy | jq '.[0].HostConfig.CapAdd'

# Port scan (external)
nmap -p- YOUR_SERVER_IP
```

## Persistence Mechanism

Systemd service ensures DOCKER-USER rules survive reboots:

```bash
systemctl status lock-awg-ui.service
```

Script: `/usr/local/sbin/lock-awg-ui.sh`  
Service: `/etc/systemd/system/lock-awg-ui.service`

## Incident Response

If compromised:

1. **Immediate**: `sudo ufw deny from any`
2. **Stop VPN**: `docker stop awg-easy`
3. **Preserve logs**: `journalctl > /tmp/logs.txt`
4. **Analyze**: Check auth logs, processes, connections
5. **Rebuild**: Fresh server + redeploy script

## References

- [AmneziaWG Security](https://github.com/amnezia-vpn/amneziawg/blob/master/README.md)
- [Docker Security](https://docs.docker.com/engine/security/)
- [SSH Hardening - Mozilla](https://infosec.mozilla.org/guidelines/openssh)
