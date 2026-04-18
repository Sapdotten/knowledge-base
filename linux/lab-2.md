# Отчет по лабораторной работе № 2
**Студент:** Семенова А.П.
**Группа:** 6411-100503D

## Среда выполнения
*   **Гипервизор:** VMware.
*   **ОС:** Ubuntu Server 22.04 LTS.
*   **Диски:** Основной (25 ГБ) + 3 диска по 5 ГБ (для RAID 5) + 1 диск 5 ГБ (для расширения).

---

## Часть 1

### Задание 1. Развёртывание ВМ
Создана ВМ, подключены 4 дополнительных виртуальных диска.
(Скриншота разделов не осталось, простите...)

### Задание 2. SSH по ключу
1.  `ssh-keygen -t rsa` — генерация пары ключей на хосте.
2.  `ssh-copy-id sapdotten@192.168.192.132` — копирование публичного ключа на сервер.
3.  `sudo nano /etc/ssh/sshd_config` — редактирование конфига.
    *   `PasswordAuthentication no`
    *   `PubkeyAuthentication yes`
4.  `sudo systemctl restart ssh` — перезапуск сервиса.


### Задание 3. Сеть (netplan)
1.  `sudo nano /etc/netplan/50-cloud-init.yaml`
2.  `sudo netplan apply`
**Конфигурация (`/etc/netplan/50-cloud-init.yaml`):**
```yaml
network:
  version: 2
  ethernets:
    ens33:
      dhcp4: no
      addresses: [192.168.192.132/24]
      gateway4: 192.168.192.2
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]
```
*   `dhcp4: no`: отключение автоматического получения IP.
*   `addresses`: список статических адресов с маской.
*   `gateway4`: шлюз по умолчанию.
![alt text](./attachments/image.png)
![alt text](./attachments/image-1.png)


### Задание 4. Конфигурация дисков

```bash
lsblk -f
```
![alt text](./attachments/image-2.png)
Обнаружены пустые диски `/dev/sdb`, `/dev/sdc`, `/dev/sdd`

### Задание 5. RAID 5
```bash
sudo mdadm --create --verbose /dev/md0 --level=5 --raid-devices=3 /dev/sdb /dev/sdc /dev/sdd
```
**Флаги/Параметры:**
*   `--create`: создание нового массива.
*   `--verbose`: подробный вывод процесса.
*   `--level=5`: уровень RAID 5.
*   `--raid-devices=3`: количество активных устройств.
 
![alt text](./attachments/image-3.png)
![alt text](./attachments/image-5.png)

### Задание 6. LVM и монтирование `/raid/0`
1.  `sudo pvcreate /dev/md0` — создание физического тома.
2.  `sudo vgcreate semenova /dev/md0` — создание группы томов.
3.  `sudo lvcreate -l 100%FREE -n lv0 semenova` — создание логического тома на всё место.
4.  `sudo mkfs.ext4 /dev/semenova/lv0` — форматирование в ext4.
5.  `sudo mkdir -p /raid/0` — создание точки монтирования.
6.  `sudo blkid /dev/ivanov/lv0` - получение uuid файловой системы для монтирования.
7.  `sudo nano /etc/fstab` - настройка постоянного монтирования:
    ```
    UUID=abe01fd6-3fc8-4b3c-8b9e-c5b98568ec15  /raid/0  ext4  defaults,nofail  0  2
    ```
8. `sudo mount -a` - монтирование файловых системы, указанных в /etc/fstab.
9. `df -h /raid/0` - проврка монтирования.

![alt text](<./attachments/Screenshot 2026-04-11 140128.png>)
![alt text](<./attachments/Screenshot 2026-04-11 140334.png>)
![alt text](./attachments/image-6.png)
![alt text](<./attachments/Screenshot 2026-04-11 140642.png>)


### Задание 7. Расширение RAID и LVM
**Выполненные команды:**
1.  Подключен 4-й диск (`/dev/sde`) в гипервизоре.
2.  `sudo mdadm /dev/md0 --add /dev/sde` — добавление диска в массив.
3.  `sudo pvresize /dev/md0` — расширение PV.
4.  `sudo lvextend -l +100%FREE /dev/semenova/lv0` — расширение LV.
5.  `sudo resize2fs /dev/semenova/lv0` — расширение файловой системы.

![alt text](<./attachments/Screenshot 2026-04-11 142819.png>)
![alt text](./attachments/image-7.png)
![alt text](<./attachments/Screenshot 2026-04-11 143036.png>)
![alt text](<./attachments/Screenshot 2026-04-11 143104.png>)

### Задание 9. NFS
1.  `sudo mkdir -p /raid/0/backup`
2.  `sudo chown nobody:nogroup /raid/0/backup`
3.  `sudo chmod 777 /raid/0/backup`
4.  `sudo apt install -y nfs-kernel-server`
5.  Редактирование `/etc/exports`:
    ```
    /raid/0/backup *(rw,sync,no_subtree_check)
    ```
6.  `sudo exportfs -ra`
7.  `sudo systemctl restart nfs-kernel-server`
8.  `sudo exportfs -v`

![alt text](./attachments/image-8.png)


### Задание 10. Cron и бэкап
1.  Создание скрипта `~/backup.sh`:
    ```bash
    #!/bin/bash
    rsync -av /home/sapdotten/ /raid/0/backup/
    ```
2.  `chmod +x ~/backup.sh`
3.  `crontab -e` добавлена строка:
    ```
    */2 * * * * /home/sapdotten/backup.sh >> /tmp/backup.log 2>&1
    ```
    *   `rsync -av`: архивный режим (-a) с подробным выводом (-v). Сохраняет права и время.
    *   `*/2 * * * *`: запуск каждую 2-ю минуту.
    *   `>> /tmp/backup.log 2>&1`: перенаправление stdout и stderr в лог-файл.

Проверка:
```bash
ls -la /raid/0/backup/
cat /tmp/backup.log
```
![alt text](./attachments/image-9.png)
![alt text](./attachments/image-10.png)

---

## Часть 2

### Задания 11–13. iptables и ufw
**Цель:** Настройка фильтрации трафика.

**Задание 11 (iptables):**
1.  `sudo iptables -A INPUT -p tcp --dport 22 -j DROP` — блокировка SSH.
2.  `sudo iptables -A INPUT -p icmp -j DROP` — блокировка Ping.
3.  `sudo iptables -A INPUT -s 10.0.2.2 -j DROP` — блокировка IP хоста.
4.  
![alt text](<./attachments/Screenshot 2026-04-18 083319.png>)

**Задание 12 (Удаление):**
```bash
sudo iptables -D INPUT 1
```
![alt text](<./attachments/Screenshot 2026-04-18 083409.png>)

**Задание 13 (ufw):**
1.  `sudo ufw enable`
2.  `sudo ufw deny 22/tcp`
3.  `sudo ufw deny from 192.168.192.2`
4.  `sudo ufw allow 139/tcp`
5.  `sudo ufw allow 445/tcp`
6.  `sudo ufw allow 1194/udp`

![alt text](./attachments/image-11.png)

### Задания 14–16. Мониторинг
**Задание 14 (ss, nc):**
1.  `ss -tuln` — просмотр слушающих портов.
    *   `-t`: TCP, `-u`: UDP, `-l`: listening, `-n`: numeric (не резолвить имена).
2.  `nc -zv localhost 22` — проверка доступности порта.
    *   `-z`: scan for listening daemons, `-v`: verbose.
    *   
![alt text](<./attachments/Screenshot 2026-04-18 084409.png>)

**Задание 15 (tcpdump):**
1.  `sudo tcpdump -i any -w /tmp/capture.pcap port 22 or icmp`
    *   `-i any`: все интерфейсы.
    *   `-w`: запись в файл.
    *   `port 22 or icmp`: фильтр по порту или протоколу.

![alt text](<./attachments/Screenshot 2026-04-18 085046.png>)


**Задание 16 (iptraf-ng):**
1.  `sudo iptraf-ng` — запуск интерактивного монитора.
![alt text](<./attachments/Screenshot 2026-04-18 085548.png>)



### Задание 17. Второй интерфейс
В гипервизоре добавлен адаптер 2 (Host-only/Internal).
**Конфигурация netplan (`/etc/netplan/50-cloud-init.yaml`):**
```yaml
network:
  version: 2
  ethernets:
    ens33:
      dhcp4: no
      addresses: [192.168.192.132/24]
      gateway4: 192.168.192.2
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]
    ens37:
      dhcp4: no
      addresses: [172.23.0.7/24]

```
`sudo netplan apply` - применить изменения

![alt text](<./attachments/Screenshot 2026-04-18 090344.png>)



### Задание 18. Порты Samba в UFW
Порты 139 и 445 уже открыты в задании 13.

### Задание 19. OpenVPN
1.  Установка `openvpn easy-rsa`.
2.  Генерация PKI: `./easyrsa init-pki`, `./easyrsa build-ca nopass`, `./easyrsa build-server-full server nopass`, `./easyrsa gen-dh`, `openvpn --genkey --secret pki/ta.key`.
3.  Копирование ключей в `/etc/openvpn/`.
4.  Создание `/etc/openvpn/server.conf`:
    ```conf
    port 1194
    proto udp
    dev tun
    ca ca.crt
    cert server.crt
    key server.key
    dh dh.pem
    server 10.8.0.0 255.255.255.0
    ifconfig-pool-persist ipp.txt
    keepalive 10 120
    comp-lzo
    user nobody
    group nogroup
    persist-key
    persist-tun
    status openvpn-status.log
    verb 3
    tls-auth ta.key 0
    push "route 172.23.0.0 255.255.255.0"
    ```
5.  Запуск: `sudo systemctl start openvpn@server`.

Демонстрация подключения:

    ![alt text](<./attachments/Screenshot 2026-04-18 182728.png>)

    Конфиг клиента:
    ```yaml
    client
    dev tun
    proto udp
    remote 192.168.192.132 1194 # IP твоей ВМ (первый интерфейс)
    resolv-retry infinite
    nobind
    user nobody
    group nogroup
    persist-key
    persist-tun
    comp-lzo
    verb 3
    <ca>
    -----BEGIN CERTIFICATE-----
    MIIDRTCCAi2gAwIBAgIUHgHXzfF6FniMkxVvMfmDHF72zG0wDQYJKoZIhvcNAQEL
    BQAwFDESMBAGA1UEAwwJc2FwZG90dGVuMB4XDTI2MDQxODA1MTEwNFoXDTM2MDQx
    NTA1MTEwNFowFDESMBAGA1UEAwwJc2FwZG90dGVuMIIBIjANBgkqhkiG9w0BAQEF
    AAOCAQ8AMIIBCgKCAQEAx5IjxnipdKXIcCAP2t9UWkGQbHsBE/IbvNxvGUoWH2Zr
    bhoDNi9R6maIEQXUtDHbxmM3S6e0NuI3p+zmGw0ncVCuCqYpin1gzzbj1nesOi+h
    wkK7eGo6mFppSKiX+YtOM81K5jElnmFdXNPTrPkGC8hdG3l4asSdM9ttyCwkxIip
    y90CiwA7qhSkmsj+VcRmRXdZIpJNjyedTvos16IySz8o/TV5Z7GZwm9ROvbDI+5x
    ZSUubsaApRk6VZBsKMBbESLtr9jV5sYD0W4fflORSvTgClM/Gdo451f21LgdYUUL
    cDXvq/CM9003JsFQATX+1XDVHM1uSQrOm/nEsnKkEQIDAQABo4GOMIGLMAwGA1Ud
    EwQFMAMBAf8wHQYDVR0OBBYEFBb8bpJtLJCmCn4ijaAvt8dJxGyxME8GA1UdIwRI
    MEaAFBb8bpJtLJCmCn4ijaAvt8dJxGyxoRikFjAUMRIwEAYDVQQDDAlzYXBkb3R0
    ZW6CFB4B183xehZ4jJMVbzH5gxxe9sxtMAsGA1UdDwQEAwIBBjANBgkqhkiG9w0B
    AQsFAAOCAQEAZv1p0zB7ckndZSAuNBF3Cb0WidXd4g842BRE3qaJAvIptZIPi+5O
    WK80LlzFHknHgCuQOQQ2m0WlQllgaXA0zLTKIKBTbdnMgOs3WmFMKUIGhZeK2L6G
    CXcoOHJ0WcK6mKFUuUo9oFptHtE21qX4JRCVvSTy+0qywD0sjcDkSWjDxgsRkNsW
    7mFlfYRr4DWFO0MrOeJUR4e0lGTVeyB0pFgeBYvno3ol3F1XpeeFzWwHEsfa8kTo
    6JexUDXTm2nQEq4BBgWeHvtXxBQMmQxHzlAZSOiquDYmM4V9zKPelzckToxs1gDw
    UCVrDdegVKUEcOXXgHEi5Rcx2rP6amNmIw==
    -----END CERTIFICATE-----
    </ca>
    <cert>
    -----BEGIN CERTIFICATE-----
    MIIDUTCCAjmgAwIBAgIQZ2+jXSisXVN4/N6zlbB5TzANBgkqhkiG9w0BAQsFADAU
    MRIwEAYDVQQDDAlzYXBkb3R0ZW4wHhcNMjYwNDE4MDUxNDE1WhcNMjgwNzIxMDUx
    NDE1WjASMRAwDgYDVQQDDAdjbGllbnQxMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8A
    MIIBCgKCAQEAl+37Oms1o20oQXihbxKDJZeCe4lEQ2SL1vMSmVw3K9OViE3DfMxN
    uhkDtdVI0HBEt/1tbcYs7oU9Oh6mwmgZUhhte6krXhfaAbb1NaoPOjQyMANmOA/V
    PYffBFzkyM3bjMAghQZkhWrV/SBmdXUFS7Hmc7cw4YeIz1KH/l3f/4GwJn1NNpin
    Co+KSzEv09BYJWmkMz+7cRJBvaz6457+eDdOaEi7Dw29EjoY8elRYiQqm8sInvo/
    LKSZRNzFVdgr3wik6wJE4xoxIHJTe9UQDy6XhdNgxW2h/zJZERW4+YIuQmasCZYb
    1Crex/++feUGGaGaGpNqxjIPCOvbftXu+wIDAQABo4GgMIGdMAkGA1UdEwQCMAAw
    HQYDVR0OBBYEFEh1b6Prv2fLEl5cgBc/O1O3K6poME8GA1UdIwRIMEaAFBb8bpJt
    LJCmCn4ijaAvt8dJxGyxoRikFjAUMRIwEAYDVQQDDAlzYXBkb3R0ZW6CFB4B183x
    ehZ4jJMVbzH5gxxe9sxtMBMGA1UdJQQMMAoGCCsGAQUFBwMCMAsGA1UdDwQEAwIH
    gDANBgkqhkiG9w0BAQsFAAOCAQEAdwjXQVOYKF66u/8H9c9zNs8mL2knUvoQ0VDh
    VKjGYrCEE2NI67dBUAg9VCtXzVWhpcy20bktO1bdg1ICwkIxNODZIwUuHbXZdqiS
    InqnUly/hV0OwRAJf/czSSww2A2vHPfSv6BBvTh2+MfMDXA5awP1LiZwmoOfnJBt
    n+9DUN//4n2Y87e4OPg2VpbUdX/Ig7dc4Vy6k/MfVKPTrdxvfmlu9X6nS+xaETmX
    Ker1bual0ANzUultD2CtU9HnNHGArfXnWLwepyb7m1JMSHe6GdTYI/wyCeaYdRxw
    y7U/b0uZ7Kqqs4UNqLV7evXlzFtbklA+s2JFOFnKjUf5cBmuiw==
    -----END CERTIFICATE-----
    </cert>
    <key>
    -----BEGIN PRIVATE KEY-----
    MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCX7fs6azWjbShB
    eKFvEoMll4J7iURDZIvW8xKZXDcr05WITcN8zE26GQO11UjQcES3/W1txizuhT06
    HqbCaBlSGG17qSteF9oBtvU1qg86NDIwA2Y4D9U9h98EXOTIzduMwCCFBmSFatX9
    IGZ1dQVLseZztzDhh4jPUof+Xd//gbAmfU02mKcKj4pLMS/T0FglaaQzP7txEkG9
    rPrjnv54N05oSLsPDb0SOhjx6VFiJCqbywie+j8spJlE3MVV2CvfCKTrAkTjGjEg
    clN71RAPLpeF02DFbaH/MlkRFbj5gi5CZqwJlhvUKt7H/7595QYZoZoak2rGMg8I
    69t+1e77AgMBAAECggEADHV77wF7B5OHA+oe4EXrXU98aCG3PbORctIXdLNxjsrY
    w1xlKzxxz1CyfjHRuSN2by7Sz3gQl+Ad8kCF5QFhD4YTTFsbbv7pEM+ZHN/SRIVN
    QaS1uDk21RyUTFOggLBo+woyYIDys1eHLtfTryQmiAY8Y2w4D6FBYIcLF0VJfjaw
    XgbtOnBNkEA0v14pRSY//sW78LtIevHoCxQ3OGu6ZSIQ0mI8mmxdKmd+F42AA8SL
    wZWOY0zYUax9k/fvP4mLWfccablBAPQ0x9ZLmcXYGDp6pXhNJ8pTe+L99c2OBbZ2
    TSGUH81cZh8/Yy0YRPxQiesHEyPtkxMLLBNEKmyiMQKBgQDKuUCZTE+azQjxuD6f
    +YY+0IAhp1y0qgmdmkEbgnIK+8icj78RaFzKK+6Cwp9tYygycU08Pq4/ftmzX8AK
    shX46bipIEpTbPYot81tZDAoDYbfCYym0Xe3POKJtYWNZWORyJ1+R2Uc3m/XS015
    9FAptpIXyvxPJrOJuaMnm9NpGQKBgQC/226QMDPNk1NDQBnMNLCFSOO6aiKz6mAh
    ERHs+PicPk/UhIpo2oSzYgxea1Og5iPs0qvowcKsNzGFYgPy++AJ/BofmsBS6Q4m
    Wj0+Hcyrwxm67t6uIqqcXAkAbiXHzgTriRT/5puvpHffgIwv5GxQvsrONx9Kakog
    r3/RxJTXMwKBgQCTt00U5wASYlikGYa4ds+VMcRLwXHRyxzalC3g57pFupXBTxUA
    kDUcs8pFyZ71zAzcRKbswRei+MGU7K44nO9ZwqRlyDugcoMjxFqR3TEh3klqd8Df
    RT6gbGL9ySEZmMlmzvHDtC4/TO3dyOcZeCZ5XqkxYR1cZ2znbDcwg2EW8QKBgAFt
    uN0J/tjBCBWwHIEQw1+6szdoIuoEDMMyRVfmYrOHI0EJ2538QpCzYjQxyGWiURIq
    X21URAbUQmIj4LOmfHyWi/tAQ75aTeirM1mLD0MYKNDjhnT1fR+877Q5Hb7nIdI/
    KxDcvrwIFXxskJ6qrMPNJ+VxM6JyOCsWI3WEaTdRAoGAVZ5+6zYOCUylcks9waRx
    TPQ156odIc53XpN4jdp0vWl9o8P6s/DA2QlyEsr1h9gDrYbNLKtrJHxjkXiC8ee3
    IkQGPkakhf6XBEQVvdKClBTqzYPfVuXsWemN4Cps7vFccOooJlpet3RmFYDqi+d6
    4H8b9giXE3XJ6jQp9ib0rfc=
    -----END PRIVATE KEY-----
    </key>
    <tls-auth>
    #
    # 2048 bit OpenVPN static key
    #
    -----BEGIN OpenVPN Static key V1-----
    9dbcfa9225d9165cd64f3aa9f431f437
    07da4c45157027d9c5e4cdb57a53a4c8
    e093e5c211baa5992e863e8686c84b83
    1cb6ced1595d9e8b81a60c837dcb2bd4
    bd6154a12e86294c972d8796348d5404
    dcff07ff8e068a0d173f5a9aea1ef48e
    7e4158e1bc9bb38ffbe87d31f7315cd1
    f2d78000976179b1fa41de7ac22e909e
    0bcbfeba95a38f311b80dacad465550c
    9242f5fa9514cfedee6d1e28953428a2
    b01879601968c9f5835a418b2ba89f92
    53eb5af0c657221b7c96b4f4251ee4e4
    f42a992bcf60ccb2bd7099326e7d65b3
    2f96ceb274fd6a4415c3893557ec70ac
    1b716b446787539c4e6a53537d83d708
    b99c1e5009a450bf3fac99ab3404e407
    -----END OpenVPN Static key V1-----
    </tls-auth>
    key-direction 1
    ```

![alt text](./attachments/image-12.png)

### Задание 20. Samba
1.  `sudo apt install samba -y`
2.  `sudo mkdir -p /srv/samba/share`
3.  Настройка `/etc/samba/smb.conf`:
    ```ini
    [share]
    path = /srv/samba/share
    browseable = yes
    read only = no
    guest ok = yes
    create mask = 0777
    directory mask = 0777
    force user = nobody
    force group = nogroup
    ```
4.  `sudo systemctl restart smbd`
5.  `echo "Test" > /srv/samba/share/test.txt`

![alt text](<./attachments/Screenshot 2026-04-18 194616.png>)

### Задание 21. Проброс портов в VPN
**Цель:** Доступ к Samba из сети VPN.
**Выполненные команды:**
1.  Включение форвардинга: `echo 'net.ipv4.ip_forward=1' | sudo tee -a /etc/sysctl.conf && sudo sysctl -p`.
2.  Правила iptables:
    ```bash
    sudo iptables -A FORWARD -i tun0 -o ens37 -p tcp --dport 139 -d 172.23.0.7 -j ACCEPT
    sudo iptables -A FORWARD -i tun0 -o ens37 -p tcp --dport 445 -d 172.23.0.7 -j ACCEPT
    sudo iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
    sudo iptables -t nat -A POSTROUTING -o ens37 -j MASQUERADE
    ```
3.  Сохранение: `sudo netfilter-persistent save`.

![alt text](<./attachments/Screenshot 2026-04-18 194701.png>)
![alt text](<./attachments/Screenshot 2026-04-18 194919.png>)
![alt text](<./attachments/Screenshot 2026-04-18 203054.png>)

Проверка доступности адреса с хоста:

![alt text](<./attachments/Screenshot 2026-04-18 203617.png>)

Сетевая папка в проводнике хоста:

![alt text](<./attachments/Screenshot 2026-04-18 203702.png>)


Уставший котик:

![alt text](./attachments/image-13.png)
