# Step 3: File server and permissions

In this step I set up a file server on DC01 where each group has its own folder, and controlled access with NTFS permissions and security groups.

## Plan

| Folder               | Share             | Who has access          |
| -------------------- | ----------------- | ----------------------- |
| `C:\Shares\Myynti`   | `\\DC01\Myynti`   | `Myynti` group (Modify) |
| `C:\Shares\Talous`   | `\\DC01\Talous`   | `Talous` group (Modify) |
| `C:\Shares\Yhteinen` | `\\DC01\Yhteinen` | `Domain Users` (Modify) |

In this lab the file server runs on DC01 simply because the is no more room for a third VM on my pc. In a real situation a separate server would be used.

Two permission layers decide who gets in: **share permissions** (only for access over the network) and **NTFS permissions** (on the folder itself). The stricter one wins. I gave the share a broad permission and controlled access with NTFS permissions, so the rules are in one place.

## 1. File Server role and folders

I added the **File Server** role in Server Manager (_Manage → Add Roles and Features → File and Storage Services → File and iSCSI Services → File Server_) and created the three folders under `C:\Shares` in File Explorer. I put a test text file in each folder.

![File Server role installed](images/file-server-role.png)

**What happened:**

<!-- In your own words: what does the role add, and why create a separate C:\Shares folder? -->

## 2. NTFS permissions

For each folder: right-click → _Properties → Security → Advanced_.

1. _Disable inheritance_ and choose _Convert inherited permissions into explicit permissions_.
2. Remove the entries that are not needed (`Users`, `Authenticated Users`). Keep `Administrators` and `SYSTEM`.
3. _Add → Select a principal_ and enter the group: `Myynti`, `Talous`, or `Domain Users` for the shared folder.
4. Give the group **Modify**, applied to _This folder, subfolders and files_.

![NTFS permissions on the Myynti folder](images/ntfs-myynti.png)

**What happened:**

<!-- Why disable inheritance? Why give permissions to groups and not to single users? Why keep Administrators and SYSTEM? -->

## 3. SMB shares

In Server Manager: _File and Storage Services → Shares → Tasks → New Share… → SMB Share - Quick_. I chose the folder path, named the share after the folder and enabled **access-based enumeration**, so users do not see folders they cannot open. I left the NTFS permissions from step 2 unchanged.

![Share list in Server Manager](images/smb-shares.png)

**What happened:**

<!-- What is the difference between share permissions and NTFS permissions? What does access-based enumeration do? -->

## 4. Mapping drives with Group Policy

I created a GPO `Map Network Drives`, linked it to the `Kayttajat` OU and added three drive maps under _User Configuration → Preferences → Windows Settings → Drive Maps_:

| Drive | Share             | Item-level targeting    |
| ----- | ----------------- | ----------------------- |
| `S:`  | `\\DC01\Myynti`   | Security group `Myynti` |
| `T:`  | `\\DC01\Talous`   | Security group `Talous` |
| `Y:`  | `\\DC01\Yhteinen` | none                    |

![Drive Maps with item-level targeting](images/gpo-drive-maps.png)

**What happened:**

<!-- Why is item-level targeting needed? What is the difference between a Group Policy Preference and a normal policy setting? -->

## 5. Testing

I signed in on CLIENT01 as two users and checked the drives. Run `gpupdate /force` and sign out and in again after changes.

| User           | `S:` Myynti     | `T:` Talous     | `Y:` Yhteinen   |
| -------------- | --------------- | --------------- | --------------- |
| Matti (Myynti) | <!-- yes/no --> | <!-- yes/no --> | <!-- yes/no --> |
| Maija (Talous) | <!-- yes/no --> | <!-- yes/no --> | <!-- yes/no --> |

![Matti's drives](images/matti-drives.png)
![Maija's drives](images/maija-drives.png)

I also used _Properties → Security → Advanced → Effective Access_ on the folders to check what each user can do.

**What happened:**

<!-- Did it work on the first try? What did you see when Matti tried to open the Talous share? -->

## Problems I ran into

<!-- Only write down what really happened to you. Use this format for each case: -->

### <!-- Short title, e.g. "Drive did not map for Maija" -->

- **Symptom:** <!-- what you saw -->
- **Cause:** <!-- what it turned out to be -->
- **Fix:** <!-- what you did -->

<!-- Common candidates, if they happened to you: a user sees a drive only after signing out and in again after a group change; the drive is not mapped because the user is not in the right OU; a red X on the drive when DC01 is off. -->

## What I learned

- <!-- 2-4 points in your own words. Things to think about: why permissions go to groups, why the stricter permission wins, what happens when a user's group membership changes. -->

## Appendix: the same with PowerShell

<!-- Delete this section if you did not run these commands. -->

```powershell
Install-WindowsFeature -Name FS-FileServer -IncludeManagementTools
New-Item -ItemType Directory -Path "C:\Shares\Myynti", "C:\Shares\Talous", "C:\Shares\Yhteinen" -Force

icacls "C:\Shares\Myynti" /inheritance:r
icacls "C:\Shares\Myynti" /grant "LAB\Myynti:(OI)(CI)M" "BUILTIN\Administrators:(OI)(CI)F" "NT AUTHORITY\SYSTEM:(OI)(CI)F"

New-SmbShare -Name "Myynti" -Path "C:\Shares\Myynti" -FullAccess "Authenticated Users" -FolderEnumerationMode AccessBased
```
