# Vaihe 1: Domain controller (AD, DNS, DHCP)

Tässä vaiheessa rakensin Windows Server -virtuaalikoneen, joka toimii domain controllerina sekä DNS- ja DHCP-palvelimena eristetyssä labraverkossa.

> Pohjana käytin vaiheittaista ohjetta. Kirjoita jokaisen vaiheen "Mitä tapahtui" -kohta omin sanoin, kun olet tehnyt vaiheen. Se on dokumentin tärkein osa.

## Verkkosuunnitelma

| Asia | Arvo |
| --- | --- |
| Domain | lab.local |
| NetBIOS-nimi | LAB |
| Palvelin | DC01 |
| Verkko | 192.168.50.0/24 |
| DC01:n IP | 192.168.50.10 |
| DNS | 192.168.50.10 |
| DHCP-alue | 192.168.50.100–200 |

## 1. Hyper-V ja labraverkko

**Komennot**

```powershell
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
New-VMSwitch -Name "LabNet" -SwitchType Internal
New-NetIPAddress -InterfaceAlias "vEthernet (LabNet)" -IPAddress 192.168.50.1 -PrefixLength 24
New-NetNat -Name "LabNAT" -InternalIPInterfaceAddressPrefix 192.168.50.0/24
```

**Mitä tapahtui:**
_Kirjoita tähän omin sanoin: mitä kukin komento teki ja miksi sisäinen kytkin on parempi kuin kotiverkkoon kytketty._

## 2. Virtuaalikoneen luonti

**Asetukset:** Generation 2, 4 GB RAM, 2 prosessoria, 60 GB levy, ISO: Windows Server 2022 Evaluation.

**Mitä tapahtui:**
_Miksi Generation 2? Mitä tapahtui, kun käynnistit koneen ensimmäisen kerran?_

## 3. Serverin asennus, nimi ja IP

```powershell
Set-TimeZone -Id "FLE Standard Time"
Rename-Computer -NewName "DC01" -Restart
New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 192.168.50.10 -PrefixLength 24 -DefaultGateway 192.168.50.1
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses 192.168.50.10
```

**Mitä tapahtui:**
_Miksi domain controllerilla pitää olla kiinteä IP? Miksi sen DNS osoittaa itseensä?_

## 4. Active Directory ja DNS

```powershell
Install-WindowsFeature -Name AD-Domain-Services, DNS -IncludeManagementTools
Install-ADDSForest -DomainName "lab.local" -DomainNetbiosName "LAB" -InstallDns
```

**Tarkistus:** `Get-ADDomain`, `dcdiag /q`, `Get-Service ADWS, DNS, KDC, Netlogon`

**Mitä tapahtui:**
_Mikä on forest ja domain? Mitä DSRM-salasana on? Mitä dcdiag tarkistaa?_

## 5. DHCP

```powershell
Install-WindowsFeature DHCP -IncludeManagementTools
Add-DhcpServerSecurityGroup
Add-DhcpServerInDC -DnsName "DC01.lab.local" -IPAddress 192.168.50.10
Add-DhcpServerv4Scope -Name "LabScope" -StartRange 192.168.50.100 -EndRange 192.168.50.200 -SubnetMask 255.255.255.0 -State Active
Set-DhcpServerv4OptionValue -ScopeId 192.168.50.0 -DnsServer 192.168.50.10 -DnsDomain "lab.local" -Router 192.168.50.1
```

**Mitä tapahtui:**
_Miksi DHCP-palvelin pitää valtuuttaa Active Directoryssä? Mitä scope-asetukset (option) antavat asiakkaille?_

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
