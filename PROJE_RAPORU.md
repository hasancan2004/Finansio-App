# Finansio - Proje Genel Raporu

**Tarih:** 2024  
**Proje Türü:** Flutter Mobil Uygulama  
**Versiyon:** 1.0.0+1  
**SDK:** Flutter ^3.8.1

---

## 📋 Proje Özeti

**Finansio**, kişisel finans yönetimi için geliştirilmiş modern bir Flutter uygulamasıdır. Kullanıcıların gelir ve giderlerini takip edebileceği, kategorilere göre organize edebileceği, bütçe planlaması yapabileceği ve detaylı raporlar alabileceği kapsamlı bir finans yönetim çözümüdür.

---

## 🏗️ Mimari ve Teknoloji Stack

### **Frontend Framework**
- **Flutter** (SDK ^3.8.1)
- **Material Design 3** (Material You)
- **Riverpod** (State Management - v2.5.1)

### **Veritabanı**
- **Drift** (v2.18.0) - Type-safe SQLite wrapper
- **SQLite** (sqflite + sqlite3_flutter_libs)
- **Schema Version:** 2 (Budgets tablosu eklendi)

### **Ana Bağımlılıklar**
- `flutter_riverpod: ^2.5.1` - State management
- `drift: ^2.18.0` - Veritabanı ORM
- `fl_chart: ^0.68.0` - Grafik görselleştirme
- `intl: ^0.20.2` - Tarih/para formatlama
- `shared_preferences: ^2.5.3` - Yerel ayar saklama
- `introduction_screen: ^3.0.3` - Onboarding ekranı
- `package_info_plus: ^4.0.0` - Uygulama bilgisi

### **Geliştirme Araçları**
- `drift_dev: ^2.18.0` - Code generation
- `build_runner: ^2.7.0` - Build tool
- `flutter_lints: ^5.0.0` - Linting kuralları

---

## 📁 Proje Yapısı

```
lib/
├── data/
│   ├── app_database.dart      # Veritabanı şeması ve işlemleri
│   └── app_database.g.dart     # Generated code
├── model/
│   ├── summary.dart            # Özet veri modelleri
│   └── tx_filter.dart          # Filtre modelleri
├── providers/
│   ├── providers.dart          # Ana state providers
│   ├── budget_providers.dart   # Bütçe state yönetimi
│   ├── reports.dart            # Rapor provider'ları
│   └── theme_provider.dart     # Tema yönetimi
├── screens/
│   ├── main.dart               # Uygulama giriş noktası
│   ├── home_screen.dart        # Ana ekran
│   ├── add_tx_screen.dart     # İşlem ekleme/düzenleme
│   ├── budgets_screen.dart     # Bütçe yönetimi
│   ├── categories_screen.dart  # Kategori yönetimi
│   ├── reports_screen.dart     # Raporlar ve grafikler
│   ├── settings_screen.dart    # Ayarlar
│   ├── bottom_nav.dart         # Alt navigasyon
│   ├── onboarding_screen.dart  # İlk açılış tanıtımı
│   └── filtered_tx_list_screen.dart # Filtrelenmiş liste
├── widgets/
│   ├── glass_container.dart    # Glassmorphism container
│   ├── empty_state.dart        # Boş durum widget'ı
│   ├── tx_filter_sheet.dart    # Filtre bottom sheet
│   └── tx_search_delegate.dart # Arama delegate
└── view/
    └── budget_page.dart         # Bütçe görünümü
```

**Toplam Dart Dosyası:** 23 dosya

---

## 🗄️ Veritabanı Şeması

### **Tablolar**

#### 1. **Categories** (Kategoriler)
- `id` (INTEGER, Primary Key, Auto Increment)
- `name` (TEXT) - Kategori adı
- `colorHex` (TEXT) - Renk kodu (varsayılan: #CCCCCC)

#### 2. **Transactions** (İşlemler)
- `id` (INTEGER, Primary Key, Auto Increment)
- `amount` (REAL) - Tutar (+ gelir, - gider)
- `note` (TEXT, Nullable) - Not
- `categoryId` (INTEGER, Foreign Key → Categories.id)
- `date` (DATETIME) - İşlem tarihi (varsayılan: şu an)

#### 3. **Budgets** (Bütçeler)
- `id` (INTEGER, Primary Key, Auto Increment)
- `categoryId` (INTEGER, Foreign Key → Categories.id)
- `year` (INTEGER) - Yıl (YYYY)
- `month` (INTEGER) - Ay (1-12)
- `amount` (REAL) - Bütçe tutarı
- **Unique Constraint:** (categoryId, year, month)

### **Seed Data**
İlk açılışta otomatik oluşturulan kategoriler:
- Yemek (#FF7043)
- Ulaşım (#42A5F5)
- Fatura (#AB47BC)
- Maaş (#66BB6A)

---

## 🎨 Kullanıcı Arayüzü Özellikleri

### **Tasarım Sistemi**
- **Material Design 3** (Material You)
- **Glassmorphism** efektleri (GlassContainer widget'ı)
- **Gradient** arka planlar
- **Poppins** font ailesi (Regular, SemiBold)
- **Neon glass** kartlar (rapor ekranında)

### **Tema Özellikleri**
- **3 Tema Modu:**
  - Sistem teması (otomatik)
  - Açık tema
  - Koyu tema
- **5 Vurgu Rengi:**
  - Mavi (#1565C0) - Varsayılan
  - Mor (#7E57C2)
  - Yeşil (#2E7D32)
  - Teal (#00897B)
  - Turuncu (#F57C00)

### **Lokalizasyon**
- **Desteklenen Diller:**
  - Türkçe (TR) - Varsayılan
  - İngilizce (US)
- Para birimi: Türk Lirası (₺)

---

## 📱 Ekranlar ve Özellikler

### **1. Onboarding Screen**
- İlk açılışta gösterilen tanıtım ekranı
- `SharedPreferences` ile "görüldü" durumu takibi

### **2. Home Screen (Ana Ekran)**
**Özellikler:**
- ✅ İşlem listesi (canlı stream)
- ✅ Gelir/Gider/Net özet kartı
- ✅ Hızlı filtreler (Tümü, Bu Ay, Geçen Ay)
- ✅ Tarih aralığı seçimi
- ✅ Arama (not + kategori adı)
- ✅ Swipe-to-delete (işlem silme)
- ✅ İşlem düzenleme (tap to edit)
- ✅ Floating Action Button (yeni işlem)

**Menü Seçenekleri:**
- Bütçeler (limit aşıldı uyarısı ile)
- Raporlar
- Filtre
- Tarih Aralığı
- Kategoriler
- Ayarlar

### **3. Add Transaction Screen**
- Gelir/Gider ekleme/düzenleme
- Kategori seçimi
- Tutar girişi
- Not ekleme
- Tarih seçimi

### **4. Budgets Screen (Bütçe Yönetimi)**
**Özellikler:**
- ✅ Aylık bütçe takibi
- ✅ Kategori bazlı bütçe limitleri
- ✅ Progress bar (harcama ilerlemesi)
- ✅ Limit aşımı uyarıları
- ✅ Bütçe ekleme/düzenleme/silme
- ✅ Ay navigasyonu (önceki/sonraki)
- ✅ Kalan bütçe gösterimi

**Durum Göstergeleri:**
- 🟢 Takip Ediliyor (0-80%)
- 🟠 Uyarı (80-100%)
- 🔴 Limit Aşıldı (>100%)

### **5. Categories Screen (Kategori Yönetimi)**
**Özellikler:**
- ✅ Kategori listesi
- ✅ Kategori ekleme/düzenleme
- ✅ Renk seçimi (12 renk paleti)
- ✅ Swipe-to-delete
- ✅ Benzersiz isim kontrolü
- ✅ Renk önizleme

### **6. Reports Screen (Raporlar)**
**Grafikler ve Analizler:**
- 📊 **Kategori Dağılımı (Pasta Grafik)**
  - Giderlerin kategori bazında dağılımı
  - Tıklanabilir (kategori detayına gider)
  - Yüzde gösterimi
  
- 📈 **Aylık Trend (Stacked Bar Chart)**
  - Son 6 ay gelir/gider karşılaştırması
  - Tıklanabilir (ay detayına gider)
  
- 📉 **Aylık Trend (Line Chart)**
  - Gelir ve gider eğrileri
  - Smooth curve animasyonları
  
- 📊 **Kategori Karşılaştırma (Bar Chart)**
  - Seçilebilir kategoriler
  - Çoklu kategori karşılaştırması
  
- 💡 **Otomatik İçgörüler**
  - Net durum analizi
  - En büyük kategori tespiti

**Filtreler:**
- Bu Ay
- Geçen Ay
- Tümü

### **7. Settings Screen (Ayarlar)**
**Özellikler:**
- Tema modu seçimi
- Vurgu rengi seçimi
- Uygulama bilgisi

### **8. Filtered Transaction List Screen**
- Filtrelenmiş işlem listesi
- Kategori veya tarih bazlı filtreleme

---

## 🔍 Filtreleme ve Arama Sistemi

### **Filtre Seçenekleri**
1. **Hızlı Filtreler:**
   - Tümü
   - Bu Ay
   - Geçen Ay

2. **Gelişmiş Filtreler:**
   - Tarih aralığı (özel)
   - Kategori
   - Min/Max tutar
   - Arama sorgusu (not + kategori adı)

3. **Sıralama:**
   - Tarihe göre (artan/azalan)
   - Tutara göre (artan/azalan)

### **Arama Özellikleri**
- Not içeriğinde arama
- Kategori adında arama
- Gerçek zamanlı sonuçlar
- Arama temizleme butonu

---

## 📊 Raporlama ve Analiz

### **Özet Metrikleri**
- **Gelir Toplamı** (pozitif işlemler)
- **Gider Toplamı** (negatif işlemlerin mutlak değeri)
- **Net Durum** (gelir - gider)

### **Grafik Türleri**
1. **Pie Chart** - Kategori dağılımı
2. **Stacked Bar Chart** - Aylık gelir/gider
3. **Line Chart** - Trend analizi
4. **Bar Chart** - Kategori karşılaştırması

### **Veri Görselleştirme**
- **fl_chart** kütüphanesi kullanımı
- İnteraktif grafikler (tıklanabilir)
- Tooltip'ler
- Renk kodlu kategoriler
- Responsive tasarım

---

## 🎯 State Management (Riverpod)

### **Provider Yapısı**

#### **Global Providers:**
- `dbProvider` - Veritabanı instance'ı
- `txFilterProvider` - İşlem filtresi
- `globalDateRangeProvider` - Tarih aralığı
- `searchQueryProvider` - Arama sorgusu
- `categoryIdFilterProvider` - Kategori filtresi
- `minAmountFilterProvider` / `maxAmountFilterProvider` - Tutar filtreleri
- `sortByProvider` / `sortOrderProvider` - Sıralama

#### **Stream Providers:**
- `txStreamProvider` - Canlı işlem listesi
- `summaryProvider` - Özet hesaplamaları
- `budgetStatusesProvider` - Bütçe durumları
- `categoryPieProvider` - Kategori pasta grafik verisi
- `monthlyTrendProvider` - Aylık trend verisi

#### **Theme Providers:**
- `themeModeProvider` - Tema modu (light/dark/system)
- `accentColorProvider` - Vurgu rengi

---

## 🛠️ Veritabanı İşlemleri

### **Kategori İşlemleri**
- `allCategories()` - Tüm kategoriler
- `watchCategories()` - Canlı kategori stream'i
- `addCategory()` - Yeni kategori
- `updateCategory()` - Kategori güncelleme
- `deleteCategory()` - Kategori silme
- `categoryNameExists()` - İsim kontrolü

### **İşlem İşlemleri**
- `addTransaction()` - Yeni işlem
- `updateTransaction()` - İşlem güncelleme
- `deleteTransaction()` - İşlem silme
- `watchTransactions()` - Filtrelenmiş canlı stream
- `filteredTransactions()` - Tek seferlik filtreli liste

### **Bütçe İşlemleri**
- `upsertBudget()` - Bütçe ekleme/güncelleme
- `deleteBudget()` - Bütçe silme
- `watchBudgetStatuses()` - Canlı bütçe durumları
- `fetchBudgetStatusFor()` - Tekil bütçe durumu

### **Rapor İşlemleri**
- `fetchSummaryTotals()` - Gelir/gider/net toplamları
- `sumExpensesByCategory()` - Kategori bazlı gider toplamları
- `monthlyTotals()` - Aylık toplamlar (son N ay)
- `fetchDailyTotals()` - Günlük toplamlar
- `fetchCategoryTotals()` - Kategori toplamları

---

## 🎨 Widget Kütüphanesi

### **Özel Widget'lar**

1. **GlassContainer**
   - Glassmorphism efekti
   - Özelleştirilebilir opacity
   - Border radius desteği
   - Gradient arka plan

2. **EmptyState**
   - Boş durum gösterimi
   - İkon + başlık + açıklama
   - Opsiyonel aksiyon butonu

3. **TxFilterSheet**
   - Bottom sheet filtre paneli
   - Gelişmiş filtreleme seçenekleri

4. **TxSearchDelegate**
   - Material arama delegate
   - Gerçek zamanlı sonuçlar

---

## 🔐 Veri Güvenliği ve Kalıcılık

### **Veri Saklama**
- **SQLite** veritabanı (yerel)
- **SharedPreferences** (ayarlar)
- Veritabanı dosyası: `finansio.db`
- Konum: Uygulama doküman dizini

### **Migration Stratejisi**
- Schema version: **2**
- v1 → v2: Budgets tablosu eklendi
- Otomatik migration desteği

---

## 📦 Platform Desteği

### **Desteklenen Platformlar**
- ✅ **Android** (minSdk: 21)
- ✅ **iOS**
- ✅ **Web**
- ✅ **Windows**
- ✅ **Linux**
- ✅ **macOS**

### **Platform Özel Özellikler**
- Android: Native splash screen
- iOS: Native splash screen
- Launcher icons yapılandırılmış

---

## 🧪 Test Durumu

- **Test Dosyası:** `test/widget_test.dart` (varsayılan)
- **Test Kapsamı:** Temel widget testi mevcut
- **Not:** Kapsamlı test suite henüz eklenmemiş

---

## 📈 Performans ve Optimizasyon

### **Optimizasyonlar**
- ✅ Stream-based reactive updates
- ✅ Lazy database initialization
- ✅ Efficient SQL queries (JOIN kullanımı)
- ✅ Auto-dispose providers
- ✅ Image asset optimization

### **Kod Kalitesi**
- ✅ Type-safe database queries (Drift)
- ✅ Linting kuralları aktif (flutter_lints)
- ✅ Code generation (build_runner)
- ✅ Material Design 3 best practices

---

## 🚀 Özellikler Özeti

### **Temel Özellikler**
- ✅ Gelir/Gider takibi
- ✅ Kategori yönetimi
- ✅ İşlem ekleme/düzenleme/silme
- ✅ Filtreleme ve arama
- ✅ Tarih bazlı filtreleme

### **Gelişmiş Özellikler**
- ✅ Bütçe yönetimi ve takibi
- ✅ Limit aşımı uyarıları
- ✅ Detaylı raporlar ve grafikler
- ✅ Çoklu grafik görselleştirme
- ✅ Otomatik içgörüler

### **Kullanıcı Deneyimi**
- ✅ Modern glassmorphism tasarım
- ✅ Tema desteği (light/dark/system)
- ✅ Özelleştirilebilir vurgu renkleri
- ✅ Onboarding ekranı
- ✅ Swipe gestures
- ✅ Responsive tasarım

---

## 🔮 Gelecek Geliştirmeler (Öneriler)

### **Potansiyel Özellikler**
1. **Veri Yedekleme:**
   - Cloud sync (Firebase/Backend)
   - Export/Import (CSV, JSON)
   - Yedekleme ve geri yükleme

2. **Gelişmiş Raporlar:**
   - PDF export
   - Email gönderimi
   - Daha fazla grafik türü

3. **Bildirimler:**
   - Bütçe limiti uyarıları
   - Düzenli harcama hatırlatıcıları

4. **Çoklu Para Birimi:**
   - Para birimi dönüştürme
   - Çoklu hesap desteği

5. **Hedefler:**
   - Tasarruf hedefleri
   - Harcama limitleri

6. **İstatistikler:**
   - Ortalama harcamalar
   - Trend analizleri
   - Tahminler

---

## 📝 Kod İstatistikleri

- **Toplam Dart Dosyası:** 23
- **Ana Ekranlar:** 9
- **Provider Dosyaları:** 4
- **Widget Dosyaları:** 4
- **Model Dosyaları:** 2
- **Veritabanı Tabloları:** 3

---

## 🎓 Teknik Notlar

### **Kullanılan Pattern'ler**
- **Provider Pattern** (Riverpod)
- **Repository Pattern** (AppDatabase)
- **Stream-based Architecture**
- **Reactive Programming**

### **Best Practices**
- ✅ Separation of Concerns
- ✅ Type Safety (Drift)
- ✅ Reactive State Management
- ✅ Material Design Guidelines
- ✅ Clean Code Principles

---

## 📞 Proje Bilgileri

**Proje Adı:** Finansio  
**Açıklama:** Kişisel bütçe ve harcama takibi uygulaması  
**Versiyon:** 1.0.0+1  
**Durum:** Aktif Geliştirme  
**Lisans:** Private (publish_to: 'none')

---

## ✅ Sonuç

Finansio, modern Flutter teknolojileri kullanılarak geliştirilmiş, kullanıcı dostu arayüzü ve güçlü özellikleriyle kapsamlı bir kişisel finans yönetim uygulamasıdır. Proje, iyi organize edilmiş bir kod yapısına, type-safe veritabanı işlemlerine ve modern UI/UX tasarımına sahiptir.

**Güçlü Yönler:**
- ✅ Modern ve şık kullanıcı arayüzü
- ✅ Güçlü veritabanı yapısı
- ✅ Kapsamlı raporlama sistemi
- ✅ Esnek filtreleme ve arama
- ✅ Bütçe takip sistemi
- ✅ Çoklu platform desteği

**Geliştirilebilir Alanlar:**
- Test coverage artırılabilir
- Cloud sync eklenebilir
- Daha fazla grafik türü eklenebilir
- Export/Import özellikleri eklenebilir

---

*Rapor Tarihi: 2024*  
*Hazırlayan: AI Assistant*

