# Dev_skill

Dev_skill; Orca, Claude Code ve Codex ile plan tabanlı geliştirme görevlerini kontrollü şekilde yönetmek için hazırlanmış bir skill paketidir.

Sistem planları doğrular, görevin zorluk ve risk seviyesini belirler, uygun agent rollerini yönlendirir, test ve review sonuçlarını takip eder. Orca; worktree, terminal, session ve izlenebilirlik katmanı olarak kullanılmaya devam eder.

## İçerdiği skill'ler

- `dev-skill-orchestrator`: plan doğrulama, puanlama, model routing, worktree yönetimi ve kullanıcı onay kapıları
- `dev-skill-developer`: kendisine verilen kapsam içinde minimum kod değişikliğini yapar
- `dev-skill-tester`: kodu değiştirmeden testleri çalıştırır ve kanıt raporlar
- `dev-skill-reviewer`: kod keşfi, hata teşhisi ve final review gerçekleştirir

## Nasıl çalışır?

1. Kullanıcı görev adını, plan klasörünü ve varsa ClickUp veya Flowdo görevini verir.
2. Orchestrator yerel planları görev aracıyla karşılaştırır.
3. Her faz için zorluk ve risk puanı oluşturulur.
4. Her görev için ayrı branch ve Orca worktree hazırlanır.
5. Developer yalnızca kendisine verilen kapsamı geliştirir.
6. Tester testleri çalıştırır ve sonucu manager'a raporlar.
7. Hata varsa reviewer sebebi inceler ve developer'a düzeltme görevi verilir.
8. Aynı fazda en fazla üç düzeltme denemesi yapılır.
9. Başarılı geliştirme cross-model review sonrasında kullanıcı onayına sunulur.
10. Kullanıcı açıkça izin vermeden commit atılmaz; agent hiçbir zaman merge yapmaz.

Tek aktif görevde orchestrator aynı zamanda task manager rolünü üstlenir. Aynı konuşmada ikinci görev açılırsa orchestrator yalnızca koordinatör olur ve her görev için ayrı task manager ile worktree kullanılır.

## Gereksinimler

- Windows PowerShell 5.1 veya PowerShell 7+
- Git
- GitHub CLI (`gh`)
- GitHub CLI oturumu: `gh auth login`
- Orca
- Claude Code
- Codex CLI

## Kurulum

Depo private olduğu için GitHub CLI oturumunun açık olması gerekir. Kurulum reposunu klonlamadan tek PowerShell komutuyla başlatılır:

```powershell
& ([scriptblock]::Create((gh api repos/alitasbas07/Dev_skill/contents/Install-DevSkill.ps1 --jq '.content | @base64d' | Out-String)))
```

Komut kurulum paketini geçici klasöre indirir ve işlem tamamlandığında geçici dosyaları siler. Projenin içine `Dev_skill` repository klasörü eklenmez.

Kurucu önce kurulum kapsamını sorar:

- `Global`: skill'ler bilgisayardaki tüm projelerde kullanılabilir.
- `Project`: Windows Explorer tarzı klasör seçim ekranı açılır; seçilen projeye kurulur.

Global kurulum:

- skill'lerin ana kopyasını `%USERPROFILE%\.agents\skills` altında tutar;
- Claude için `%USERPROFILE%\.claude\skills` bağlantılarını oluşturur;
- Codex için `%USERPROFILE%\.codex\skills` bağlantılarını oluşturur;
- mevcut aynı adlı skill'leri silmeden tarihli yedeğe taşır.

Proje kurulumu:

- `<proje>\.agents\skills` klasörüne Orca ve ortak agent skill'lerini kopyalar;
- `<proje>\.claude\skills` klasörüne Claude Code skill'lerini kopyalar;
- `<proje>\.codex\skills` klasörüne Codex skill'lerini kopyalar;
- gerçek dosyalar kullandığı için bu klasörler istenirse Git'e eklenip ekiple paylaşılabilir.

Kurulumu soru sormadan çalıştırmak için:

```powershell
$installer = gh api repos/alitasbas07/Dev_skill/contents/Install-DevSkill.ps1 --jq '.content | @base64d' | Out-String
$script = [scriptblock]::Create($installer)
& $script -Scope Global
& $script -Scope Project -ProjectPath "C:\projeler\uygulama"
```

Kurulumdan sonra Orca, Claude Code ve Codex oturumlarını yeniden başlatın.

## Kullanım örneği

```text
Kural bazlı ödeme geçidi geliştirmesi
C:\proje\.todo\kural-bazli-odeme-gecidi
içindeki planları ve ClickUp karşılığını doğrula, geliştirmeye başla.
```

Orchestrator kullanıcı cevaplarına her zaman görev adıyla başlar:

```text
Görev: Kural bazlı ödeme geçidi
```

## Güncelleme

Kurulum komutunu yeniden çalıştırın. Mevcut skill'ler tarihli yedeğe taşınır ve güncel sürüm kurulur:

```powershell
& ([scriptblock]::Create((gh api repos/alitasbas07/Dev_skill/contents/Install-DevSkill.ps1 --jq '.content | @base64d' | Out-String)))
```

## Doğrulama

Skill yapısını ve PowerShell dosyalarını kontrol etmek için:

```powershell
.\Validate-DevSkill.ps1
```

Kurucuyu gerçek kullanıcı skill klasörlerine dokunmadan izole ortamda test etmek için:

```powershell
.\Test-DevSkill.ps1
```

## Temel kurallar

- Bir görev, bir branch ve bir worktree kullanır.
- Agent commit için kullanıcı onayı bekler.
- Agent hiçbir zaman merge yapmaz.
- Plan dışı kapsam eklenmez.
- Aynı hata için en fazla üç düzeltme denemesi yapılır.
- Kritik advisor modelleri kullanıcı onayı olmadan kullanılmaz.
- Test, geliştirme ve review kanıtları ayrı raporlanır.
- Runtime logları proje reposuna yazılmaz.
