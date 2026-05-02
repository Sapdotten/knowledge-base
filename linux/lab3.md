# Лабораторная работа №3.

**Студент:** Семенова А.П  
**Группа** 6411

## 1. Среда выполнения

- **Хост:** Fedora release 42 (Adams)
- **Гипервизор:** KVM/QEMU, libvirt
- **Гостевая ОС:** Ubuntu Server 22.04 LTS
- **IP гостевой ВМ:** 192.168.122.250
- **Пользователь ВМ:** user

---

## 2. Задание 1. Подготовка хоста KVM

Установка пакетов и запуск сервисов на хосте Fedora.

**Команды:**
```bash
sudo dnf install @virtualization -y
sudo systemctl enable --now virtqemud.socket virtqemud.service
```
![alt text](<./attachments/Screenshot From 2026-05-02 01-36-07.png>)



---

## 3. Задание 2. Гостевая ВМ

Создание виртуальной машины с Ubuntu Server.

**Команда создания:**
```bash
sudo virt-install \
--name ubuntu-lab \
--ram 2048 \
--vcpus 2 \
--disk path=/var/lib/libvirt/images/ubuntu_vm.qcow2,format=qcow2 \
--cdrom /var/lib/libvirt/images/ubuntu-22.04.5-live-server-amd64.iso \
--os-variant ubuntu22.04 \
--network network=default \
--graphics vnc,listen=0.0.0.0 \
--noautoconsole
```
![alt text](<./attachments/Screenshot From 2026-05-02 01-43-46.png>)
![alt text](<./attachments/Screenshot From 2026-05-02 01-44-40.png>)
![alt text](<./attachments/Screenshot From 2026-05-02 03-24-11.png>)

---

## 4. Задания 3–4. Пользователь `user` и SSH

Создание пользователя и настройка доступа по ключу.

**Создание пользователя (если не создан при установке):**
```bash
sudo adduser user
sudo usermod -aG sudo user
```

**Генерация ключа на хосте и копирование:**
```bash
ssh-keygen -t ed25519 -f ~/.ssh/lab_key -N ""
ssh-copy-id -i ~/.ssh/lab_key.pub user@192.168.122.250
```

![alt text](<./attachments/Screenshot From 2026-05-02 03-25-38.png>)

**Настройка `sshd_config` (фрагмент):**
```text
PasswordAuthentication no
PubkeyAuthentication yes
```

**Перезапуск SSH:**
```bash
sudo systemctl restart ssh
```

![alt text](<./attachments/Screenshot From 2026-05-02 03-31-21.png>)

---

## 5. Задание 5. Конфигурация гостевой ВМ

Информация о ресурсах системы.

**Выводы команд:**

`lscpu`:

![alt text](<./attachments/Screenshot From 2026-05-02 03-32-17.png>)

`free -h`:

![alt text](<./attachments/Screenshot From 2026-05-02 03-32-28.png>)

`lsblk`:

![alt text](<./attachments/Screenshot From 2026-05-02 03-32-41.png>)

`df -h`

![alt text](<./attachments/Screenshot From 2026-05-02 03-32-54.png>)

`ip a`:

![alt text](<./attachments/Screenshot From 2026-05-02 03-33-04.png>)

`ip r`:

![alt text](<./attachments/Screenshot From 2026-05-02 03-33-13.png>)

**Описание:**
ВМ имеет 2 vCPU, 2 ГБ RAM, основной диск vda (~20 ГБ). Сетевой интерфейс enp1s0 получил IP 192.168.122.250 через DHCP.

---

## 6. Задание 6. Дополнительный диск

Подключение второго диска объемом 10 ГБ.

**На хосте:**
```bash
qemu-img create -f qcow2 /var/lib/libvirt/images/extra_disk.qcow2 10G
sudo virsh attach-disk ubuntu-lab /var/lib/libvirt/images/extra_disk.qcow2 vdb --cache none --subdriver qcow2 --persistent
```
![alt text](<./attachments/Screenshot From 2026-05-02 03-35-54.png>)
![alt text](<./attachments/Screenshot From 2026-05-02 03-36-15.png>)

**В госте:**

![alt text](<./attachments/Screenshot From 2026-05-02 03-36-39-1.png>)

---

## 7. Задание 7. Разметка и монтирование `/disk`

Разметка GPT, создание FS ext4 и монтирование.

**Команды:**
```bash
sudo parted /dev/vdb mklabel gpt
sudo parted /dev/vdb mkpart primary ext4 0% 100%
sudo mkfs.ext4 /dev/vdb1
sudo mkdir /disk
sudo mount /dev/vdb1 /disk
```
**Настройка `/etc/fstab`:**
```text
UUID=[ВАШ_UUID] /disk ext4 defaults 0 2
```
![alt text](<./attachments/Screenshot From 2026-05-02 03-37-35-1.png>)
![alt text](<./attachments/Screenshot From 2026-05-02 03-38-01.png>)
![alt text](<./attachments/Screenshot From 2026-05-02 03-39-29.png>)

**Проверка:**
```bash
findmnt /disk
```

![alt text](<./attachments/Screenshot From 2026-05-02 03-39-44.png>)

---

## 8. Задание 8. Права на `/disk`

Настройка прав для пользователя `user`.

**Команды:**
```bash
sudo chown user:user /disk
sudo chmod 755 /disk
```

**Тест:**
```bash
su - user
touch /disk/testfile
ls -l /disk/testfile
```

![alt text](<./attachments/Screenshot From 2026-05-02 03-40-35.png>)

---

## 9. Задание 9. Docker

Установка и проверка Docker.

**Установка:**
```bash
sudo apt install docker.io -y
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
```

**Проверка (`hello-world`):**
```bash
docker run hello-world
```

![alt text](<./attachments/Screenshot From 2026-05-02 04-31-27.png>)

---

## 10. Задание 10. Nginx в контейнере

Запуск веб-сервера с персональной страницей.

**Подготовка контента:**
```bash
mkdir -p /disk/www
echo "<h1>ФАМИЛИЯ_СТУДЕНТА</h1>" > /disk/www/index.html
```

**Запуск контейнера:**
```bash
docker run -d --name nginx-lab -p 80:80 -v /disk/www:/usr/share/nginx/html nginx
```

![alt text](<./attachments/Screenshot From 2026-05-02 04-34-32.png>)

**Проверка с хоста:**
```bash
curl http://192.168.122.250
```

![alt text](<./attachments/Screenshot From 2026-05-02 04-35-08.png>)

---

## 11. Выводы

В ходе лабораторной работы была развернута инфраструктура виртуализации на базе KVM в Fedora. Создана гостевая ВМ Ubuntu Server, настроен безопасный доступ по SSH-ключам. Освоены навыки управления дисковыми устройствами (подключение, разметка GPT, монтирование). Установлен Docker, запущен контейнеризированный веб-сервер Nginx с пробросом портов и монтированием тома с хоста.

**Основные трудности:**
1. Проблемы с правами доступа к файлам образов в домашней директории пользователя (решено переносом в `/var/lib/libvirt/images`).
2. Отсутствие интернета в гостевой ВМ из-за ограничений firewalld на хосте (решено добавлением прямых правил маскарадинга и форварда через `firewall-cmd --direct`).
```

