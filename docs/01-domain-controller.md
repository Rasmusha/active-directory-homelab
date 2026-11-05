# Part 1: Domain controller (AD, DNS, DHCP)

In this part I build a Windows Server virtual machine, which works as domain controller, DNS server and DHCP server in an isolated internal network. I will use both the desktop environment and powershell to manage windows server, to learn both.

## Network plan

| Setting         | Value                         |
| --------------- | ----------------------------- |
| Domain          | lab.local                     |
| NetBIOS name    | LAB                           |
| Server name     | DC01                          |
| Network         | 192.168.50.0/24               |
| DC01 IP address | 192.168.50.10                 |
| DNS server      | 192.168.50.10                 |
| DHCP scope      | 192.168.50.100–192.168.50.200 |

## 1. Hyper-V ja lab network

**Commands**

```powershell
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
New-VMSwitch -Name "LabNet" -SwitchType Internal
New-NetIPAddress -InterfaceAlias "vEthernet (LabNet)" -IPAddress 192.168.50.1 -PrefixLength 24
New-NetNat -Name "LabNAT" -InternalIPInterfaceAddressPrefix 192.168.50.0/24

```

In the first part I enabled Hyper-V, which is used to create virtual machines. After that I created an internal switch called `labNet`, gave the host an address on it (192.168.50.1) and set up NAT.
An Internal switch was created for a couple of reasons:

- **Network isolation:**The lab networks DHCP server might mess with my home network and give wrong addresses to my home devices. An internal switch keeps that traffic inside the lab.
- **Security:** The VMs can access the internet through the host PC(NAT), but the VMs can't be accessed from outside.

### What I learned

- Had to learn about NAT and when and why it is needed.
- Was not that familiar with Hyper-V before this lab. I had used it and was somewhat familiar with virtualization before, but this lab made me dig deeper on this topic.
- Creating a internal virtual switch was also a new thing for me. I also hadn't actually created any networks before this outside cisco packet tracer.

## 2. Creating a VM

**Configuration:** Generation 2, 4 GB RAM, 2 processors, 60 GB disk, ISO: Windows Server 2025.

```powershell
New-VM -Name "DC01" -Generation 2 -MemoryStartupBytes 4GB -NewVHDPath "C:\VMs\DC01\DC01.vhdx" -NewVHDSizeBytes 60GB -SwitchName "LabNet" -Path "C:\VMs"
Set-VMProcessor -VMName "DC01" -Count 2
Add-VMDvdDrive -VMName "DC01" -Path "C:\ISO\WindowsServer2025.iso"
```

I created a virtual machine named DC01 and connected it to the `LabNet` switch. I chose:

- **Generation 2:** the modern virtual machine type, with UEFI boot. It is required for Windows 11 later and supports current Windows Server versions.
- **4 GB RAM and 2 processors:** enough for a domain controller in a small lab, and leaves memory for the client VM on a 16 GB host.
- **60 GB disk:** a virtual disk file that only grows as data is written.

```powershell
$dvd = Get-VMDvdDrive -VMName "DC01"
Set-VMFirmware -VMName "DC01" -FirstBootDevice $dvd
```

The DVD drive with the Windows Server ISO is set as the first boot device, so the VM starts the installer.

```powershell
Start-VM -Name "DC01"
vmconnect.exe localhost "DC01"
```

Next I launched the VM and installed Windows Server 2025 on it.

### What I learned

- I have created some virtual machines before this lab, but they were linux machines, so creating a windows one was new. Also was not familiar with Windows Server.
- Had to make some decisions regardign the specs of the virtual machine

## 3. Installing the server, name and IP

Then I set the timezone and renamed the computer.

```powershell
Set-TimeZone -Id "FLE Standard Time"
Rename-Computer -NewName "DC01" -Restart
```

After the restart I gave the server a static IP address and pointed its DNS setting to itself:

```powershell
New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 192.168.50.10 -PrefixLength 24 -DefaultGateway 192.168.50.1
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses 192.168.50.10
```

**Why:**

- **DNS points to itself:** DC01 will become the DNS server for the domain in the next step. Active Directory depends on DNS to work.
- **Time zone:** Active Directory logins (Kerberos) fail if clocks differ too much, so the time must be correct.

### What I learned

- Learned how much the correct timezone means for AD to work.
- Giving a static IP address was also a new thing and learning about the importance of a fixed address.
- Pointing DNS setting to itself seemed weird at first, but made complete sense after a while.
- AD and DNS are closely connected.

## 4. Active Directory ja DNS

In this part I installed the AD DS and DNS roles.

```powershell
Install-WindowsFeature -Name AD-Domain-Services, DNS -IncludeManagementTools
```

Next I created a domain called `lab.local` and made DC01 its domain controller.

```powershell
Install-ADDSForest -DomainName "lab.local" -DomainNetbiosName "LAB" -InstallDns
```

**Checking:** `Get-ADDomain`, `dcdiag /q`, `Get-Service ADWS, DNS, KDC, Netlogon`

### What I learned

- Learned more about AD DS and its role in the AD system.
- Learned about AD domains and how they function.

## 5. DHCP

Next I installed the DHCP role and created its security groups. After that I restarted the DHCP service so the groups take effect.

```powershell
Install-WindowsFeature DHCP -IncludeManagementTools
Add-DhcpServerSecurityGroup
Restart-Service dhcpserver
```

Next I authorized the DHCP server, created the address scope and set the options the clients receive together with their address (DNS server, domain name and gateway).

```powershell
Add-DhcpServerInDC -DnsName "DC01.lab.local" -IPAddress 192.168.50.10
Add-DhcpServerv4Scope -Name "LabScope" -StartRange 192.168.50.100 -EndRange 192.168.50.200 -SubnetMask 255.255.255.0 -State Active
Set-DhcpServerv4OptionValue -ScopeId 192.168.50.0 -DnsServer 192.168.50.10 -DnsDomain "lab.local" -Router 192.168.50.1
```

### What I learned

-

## 6. Käyttäjät ja asiakkaan liittäminen domainiin

Katso skripti [scripts/New-LabUsers.ps1](../scripts/New-LabUsers.ps1).

```powershell
Add-Computer -DomainName "lab.local" -Credential "LAB\Administrator" -Restart
```

**Mitä tapahtui:**
_Onnistuiko kirjautuminen domain-käyttäjällä? Mitä virheitä tuli ja miten korjasit ne? Lisää ratkaisut kansioon troubleshooting/._

## Kuvakaappaukset

Tallenna kuvat kansioon `screenshots/` ja linkitä ne tähän, esimerkiksi:

```markdown
![DHCP-alue](../screenshots/dhcp-scope.png)
```

Hyviä kuvia: Active Directory Users and Computers, DHCP-alue, `ipconfig /all` asiakkaalta, onnistunut domain-kirjautuminen.
