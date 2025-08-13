# Sui NFT & Marketplace Modülleri

Türkçe sürüm (English version: [README.md](README.md))

## Genel Bakış

Bu Move paketi iki ana modül sağlar:

- NFT koleksiyon modülü `sui_nft::sui_nft`: **The Savage Pet** adlı, maksimum arzı sınırlı, zincir üstü metadata ve dinamik attribute destekli koleksiyon.
- Marketplace modülü `sui_nft::marketplace`: NFT'leri yerleştirme, listeleme, satın alma, listeden kaldırma, geri çekme ve pazar kârlarını çekme işlevleri; otomatik yaratıcı (royalty) ödemesi içerir.

## Öne Çıkan Özellikler

### NFT Modülü (`sui_nft`)

- Sabit maksimum arz (7777) – mint sırasında doğrulanır.
- Adres başına maksimum mint limiti alanı (3) – tablo tutuluyor; (mevcut kodda henüz doğrulama uygulanmamış, ileride eklenebilir).
- Zengin metadata: ad, açıklama, görüntü URL, key/value şeklinde isteğe bağlı attribute'lar (`VecMap<String,String>`).
- Wallet / explorer gösterimi için Display nesnesi kurulumu.
- Mint & burn event'leri (`TheSavagePetMintEvent`, `TheSavagePetBurnEvent`).
- Ayrıcalıklı işlemler için `AdminCap` (örn. burn).

### Marketplace Modülü (`marketplace`)

- NFT'ler satışa çıkmadan önce paylaşılan `Marketplace` objesine konur.
- İstersen sadece yerleştir, sonra listele; veya tek işlemde yerleştir & listele.
- Fiyat güncelleme, listeden kaldırma, NFT geri çekme.
- Satın alma akışı: fazla ödeme varsa para üstü iadesi.
- Otomatik %3 royalty `@creator` adresine gönderilir.
- İstatistikler: toplam item, satış adedi, toplam hacim, biriken kâr.
- Kâr çekme işlemi `AdminCap` sahibi ile sınırlı.
- Zengin event seti (oluşturma, yerleştirme, listeleme, delist, satış, geri çekme, kâr çekme).

## Named Address'ler

`Move.toml` içeriği:

```
[addresses]
sui_nft = "0x0"
creator = "0x11d683215fa8073400fb6071148ab2f7b5799a1c0a963df01a11e7350a3de141"
```

Yayınlamadan önce `creator` adresini ihtiyaca göre güncelleyin.

## Dizin Yapısı

```
sources/
  sui_nft.move        # NFT koleksiyon mantığı
  marketplace.move    # Marketplace mantığı
```

Derleme çıktıları `build/` altında oluşur.

## Event Özeti

| Event                   | Amaç                                              |
| ----------------------- | ------------------------------------------------- |
| `TheSavagePetMintEvent` | Mint işlemi (id, ad, sahip)                       |
| `TheSavagePetBurnEvent` | Burn işlemi                                       |
| `MarketplaceCreated`    | Marketplace başlatıldı                            |
| `NFTPlaced`             | NFT marketplace içine kondu (satışta olmayabilir) |
| `NFTListed`             | NFT fiyatla listelendi                            |
| `NFTDelisted`           | Liste kaldırıldı                                  |
| `NFTSold`               | Başarılı satış (alıcı & satıcı)                   |
| `NFTWithdrawn`          | Sahibi NFT'yi geri aldı                           |
| `ProfitsWithdrawn`      | Admin marketplace kârı çekti                      |

## Başlıca Public Fonksiyonlar

### NFT Modülü

| Fonksiyon                                                                                                  | Açıklama                                                                      |
| ---------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| `mint(registry, name, image_url, attribute_keys, attribute_values, ctx)`                                   | Yeni NFT basar; arz sınırı doğrulanır (adres başı limit mantığı eklenebilir). |
| `burn(admin_cap, nft, ctx)`                                                                                | NFT yakma (sadece admin).                                                     |
| Getter'lar (`get_nft_details`, `get_nft_id`, `get_nft_name`, `get_nft_attributes`, `get_multiple_nft_ids`) | Okuma yardımcıları.                                                           |

### Marketplace Modülü

| Fonksiyon                                                                                                                                                                                                                              | Açıklama                                                               |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| `place_nft(marketplace, nft, ctx)`                                                                                                                                                                                                     | NFT'yi marketplace içine koyar.                                        |
| `list_nft(marketplace, nft_id, price, ctx)`                                                                                                                                                                                            | Zaten konmuş NFT'yi listeler.                                          |
| `place_and_list_nft(marketplace, nft, price, ctx)`                                                                                                                                                                                     | Tek adımda yerleştir + listele.                                        |
| `delist_nft(marketplace, nft_id, ctx)`                                                                                                                                                                                                 | Satış listesinden kaldırır (NFT içeride kalır).                        |
| `purchase_nft(marketplace, nft_id, payment, ctx)`                                                                                                                                                                                      | Listelenmiş NFT'yi satın alır; royalty & para üstü yönetir. NFT döner. |
| `withdraw_nft(marketplace, nft_id, ctx)`                                                                                                                                                                                               | Sahibi listede olmayan NFT'yi geri alır.                               |
| `update_listing_price(marketplace, nft_id, new_price, ctx)`                                                                                                                                                                            | Fiyat günceller.                                                       |
| `withdraw_profits(admin_cap, marketplace, amount_opt, ctx)`                                                                                                                                                                            | Marketplace kârını (tam / kısmi) çeker.                                |
| Sorgular (`is_nft_in_marketplace`, `is_nft_listed`, `get_listing_price`, `get_listing_info`, `get_nft_owner`, `get_marketplace_stats`, `get_profits_amount`, `calculate_royalty`, `calculate_seller_amount`, `get_royalty_percentage`) | Okuma yardımcıları.                                                    |

## Derleme ve Test

Önkoşul: Sui CLI kurulu (güncel devnet veya uygun ağ), network ayarları yapılmış.

### Derleme

```bash
sui move build
```

### Test Çalıştırma

```bash
sui move test
```

## Yayınlama (Publish)

`Move.toml` içindeki adresleri ayarladıktan sonra:

```bash
sui client publish --gas-budget 200000000
```

Çıkan paket ID'sini kaydedin.

## Örnek Akışlar

### 1. NFT Mint

(Shared `TheSavagePetRegistry` ve hesabınızda `AdminCap` olduğu varsayımıyla):

```bash
sui client call \
  --package <PKG_ID> \
  --module sui_nft \
  --function mint \
  --args <REGISTRY_OBJECT_ID> "Benim Petim" "https://example.com/pet.png" '["rarity","element"]' '["legendary","fire"]' \
  --gas-budget 100000000
```

### 2. NFT Yerleştir & Listele

```bash
sui client call \
  --package <PKG_ID> \
  --module marketplace \
  --function place_and_list_nft \
  --args <MARKETPLACE_ID> <NFT_OBJECT_ID> 100000000 \
  --gas-budget 100000000
```

### 3. NFT Satın Alma

```bash
sui client call \
  --package <PKG_ID> \
  --module marketplace \
  --function purchase_nft \
  --args <MARKETPLACE_ID> <NFT_ID> <COIN_OBJECT_ID> \
  --gas-budget 100000000
```

(Syntax, JSON-RPC veya SDK kullanımında farklılaşabilir.)

## Royalty Mantığı

Royalty = `fiyat * 3 / 100` ve `@creator` adresine gönderilir. Satıcı net olarak `fiyat - royalty` alır. Herhangi bir kalan tutar marketplace kârlarında kalır.

## Güvenlik / Dikkat Edilecekler

- `CREATOR` ve `AdminCap` saklama güvenliği kritik.
- Adres başı mint limiti alanı var fakat doğrulama kodu eklenmeli (spam / Sybil azaltma).
- Marketplace Move nesne semantiği sayesinde reentrancy riskini azaltır fakat mainnet öncesi audit önerilir.

## Genişletme Fikirleri

- Teklif / açık artırma sistemi.
- Adres başı mint limiti enforcement.
- Metadata güncelleme veya kilitleme (freeze) özelliği.
- Event tabanlı off-chain indeksleyici entegrasyonu (hazır).

## Lisans

Seçtiğiniz lisansı bu bölüme ekleyin (örn. MIT).

## Sorumluluk Reddi (Disclaimer)

Kod olduğu gibi sağlanmıştır; üretim ortamına almadan önce denetleyin (audit).

---

Katkılar ve sorun bildirimleri memnuniyetle karşılanır.
