# Dev_skill

Claude Code, Codex ve Orca üzerinde kontrollü geliştirme orkestrasyonu için dört skill içerir:

- `dev-skill-orchestrator`: plan doğrulama, puanlama, routing, worktree ve kullanıcı kapıları
- `dev-skill-developer`: kapsamla sınırlı geliştirme
- `dev-skill-tester`: salt-okunur test ve kanıt raporu
- `dev-skill-reviewer`: keşif, hata teşhisi ve final review

## Kurulum

GitHub deposu yayınlandıktan sonra tek PowerShell komutu kullanılacaktır:

```powershell
irm https://raw.githubusercontent.com/alitasbas07/Dev_skill/main/Install-DevSkill.ps1 | iex
```

Yerel kaynaktan kurulum:

```powershell
.\Install-DevSkill.ps1 -SourcePath .
```

Kurucu ana kopyayı `%USERPROFILE%\.agents\skills` altında tutar. Claude ve Codex skill klasörlerine junction oluşturur. Var olan aynı adlı skill'ler silinmez; tarihli yedeğe taşınır.

## Doğrulama

```powershell
.\Validate-DevSkill.ps1
.\Test-DevSkill.ps1
```

## Güvenlik sınırları

- Agent commit veya merge yapmaz.
- Commit yalnızca kullanıcı açıkça izin verirse yapılabilir.
- Merge hiçbir zaman agent tarafından yapılmaz.
- Aynı hata için en fazla üç düzeltme denemesi vardır.
- Kritik advisor modelleri kullanıcı onayı olmadan kullanılmaz.
