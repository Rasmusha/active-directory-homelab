<#
.SYNOPSIS
    Luo käyttäjiä Active Directoryyn CSV-tiedostosta.

.DESCRIPTION
    Lukee CSV-tiedoston (sarakkeet: GivenName, Surname, Group), luo jokaiselle
    käyttäjän OU=Kayttajat-yksikköön ja lisää hänet annettuun ryhmään.
    Salasana kysytään ajon alussa, eikä sitä tallenneta mihinkään.

.EXAMPLE
    .\New-LabUsers.ps1 -CsvPath .\users.csv.sample

.NOTES
    Aja domain controllerilla (DC01) järjestelmänvalvojana.
    Testaa ensin vain yhdellä rivillä ja ota checkpoint ennen massa-ajoa.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$CsvPath,

    [string]$DomainDN = "DC=lab,DC=local",
    [string]$UpnSuffix = "lab.local"
)

Import-Module ActiveDirectory

$password = Read-Host -AsSecureString "Anna alkuperäinen salasana kaikille luotaville käyttäjille"
$userOU = "OU=Kayttajat,$DomainDN"

foreach ($row in Import-Csv -Path $CsvPath) {
    $sam = ("{0}.{1}" -f $row.GivenName, $row.Surname).ToLower()

    if (Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue) {
        Write-Warning "Käyttäjä $sam on jo olemassa, ohitetaan."
        continue
    }

    if ($PSCmdlet.ShouldProcess($sam, "Luo käyttäjä")) {
        New-ADUser `
            -Name "$($row.GivenName) $($row.Surname)" `
            -GivenName $row.GivenName `
            -Surname $row.Surname `
            -SamAccountName $sam `
            -UserPrincipalName "$sam@$UpnSuffix" `
            -Path $userOU `
            -AccountPassword $password `
            -ChangePasswordAtLogon $true `
            -Enabled $true

        if ($row.Group) {
            Add-ADGroupMember -Identity $row.Group -Members $sam
        }
        Write-Host "Luotu: $sam ($($row.Group))"
    }
}
