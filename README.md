# Sui NFT & Marketplace Modules

English version (Türkçe versiyon için: [README_TR.md](README_TR.md))

## Overview

This Move package provides:

- An NFT collection module `sui_nft::sui_nft` implementing a capped-supply collectible called **The Savage Pet** with on‑chain metadata & dynamic attributes.
- A marketplace module `sui_nft::marketplace` that allows placing, listing, buying, delisting, withdrawing NFTs and withdrawing marketplace profits with configurable creator royalties.

## Key Features

### NFT Module (`sui_nft`)

- Fixed max supply (7777) enforced on mint.
- Per‑address mint limit (currently 3) tracked via a registry table.
- Rich metadata: name, description, image URL, arbitrary key/value attributes stored in `VecMap<String,String>`.
- Display object initialization for wallet / explorer rendering.
- Mint & burn events (`TheSavagePetMintEvent`, `TheSavagePetBurnEvent`).
- AdminCap for privileged (burn) and potential future admin actions.

### Marketplace Module (`marketplace`)

- Store NFTs inside a shared `Marketplace` object before/during listing.
- Place only, list after; or place & list in a single transaction.
- Update listing price, delist, withdraw (retrieve) NFT if not sold.
- Purchase flow with change handling on overpayment.
- Automatic royalty distribution to `@creator` (3%).
- Marketplace statistics: total items, sales count, volume, accumulated profits.
- Profit withdrawal restricted to holder of `AdminCap` (from the NFT module).
- Comprehensive events (created, placed, listed, delisted, sold, withdrawn, profits withdrawn).

## Named Addresses

Defined in `Move.toml`:

```
[addresses]
sui_nft = "0x0"
creator = "0x11d683215fa8073400fb6071148ab2f7b5799a1c0a963df01a11e7350a3de141"
```

Adjust `creator` before publishing if needed.

## Package Structure

```
sources/
  sui_nft.move        # NFT collection logic
  marketplace.move    # Marketplace logic
```

Build artifacts appear under `build/` after compilation.

## Events Summary

| Event                   | Purpose                                              |
| ----------------------- | ---------------------------------------------------- |
| `TheSavagePetMintEvent` | Emitted on NFT mint (id, name, owner)                |
| `TheSavagePetBurnEvent` | Emitted on burn                                      |
| `MarketplaceCreated`    | Marketplace initialization                           |
| `NFTPlaced`             | NFT stored in marketplace (not necessarily for sale) |
| `NFTListed`             | NFT listed with price                                |
| `NFTDelisted`           | Listing removed                                      |
| `NFTSold`               | Successful sale with buyer & seller                  |
| `NFTWithdrawn`          | Owner withdrew NFT from marketplace                  |
| `ProfitsWithdrawn`      | Admin withdrew marketplace profits                   |

## Public Entry Points (Core)

### NFT Module

| Function                                                                                                | Description                                                                                                                                                       |
| ------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `mint(registry, name, image_url, attribute_keys, attribute_values, ctx)`                                | Mints new NFT; asserts supply & per-address limits (supply hardcoded; per-address currently not enforced in code provided for attributes table—future extension). |
| `burn(admin_cap, nft, ctx)`                                                                             | Burns an NFT (admin only).                                                                                                                                        |
| Getters (`get_nft_details`, `get_nft_id`, `get_nft_name`, `get_nft_attributes`, `get_multiple_nft_ids`) | Read helpers.                                                                                                                                                     |

### Marketplace Module

| Function                                                                                                                                                                                                                                    | Description                                                   |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| `place_nft(marketplace, nft, ctx)`                                                                                                                                                                                                          | Move NFT into marketplace (not for sale yet).                 |
| `list_nft(marketplace, nft_id, price, ctx)`                                                                                                                                                                                                 | List already placed NFT.                                      |
| `place_and_list_nft(marketplace, nft, price, ctx)`                                                                                                                                                                                          | Convenience combined action.                                  |
| `delist_nft(marketplace, nft_id, ctx)`                                                                                                                                                                                                      | Remove listing (keep NFT stored).                             |
| `purchase_nft(marketplace, nft_id, payment, ctx)`                                                                                                                                                                                           | Buy listed NFT; handles royalty & change. Returns NFT object. |
| `withdraw_nft(marketplace, nft_id, ctx)`                                                                                                                                                                                                    | Owner retrieves unlisted NFT.                                 |
| `update_listing_price(marketplace, nft_id, new_price, ctx)`                                                                                                                                                                                 | Change listing price.                                         |
| `withdraw_profits(admin_cap, marketplace, amount_opt, ctx)`                                                                                                                                                                                 | Withdraw some/all accumulated profits.                        |
| Query helpers (`is_nft_in_marketplace`, `is_nft_listed`, `get_listing_price`, `get_listing_info`, `get_nft_owner`, `get_marketplace_stats`, `get_profits_amount`, `calculate_royalty`, `calculate_seller_amount`, `get_royalty_percentage`) | Read helpers.                                                 |

## Build & Test

Prerequisites: Installed Sui CLI (>= latest devnet), correct network config.

### Build

```bash
sui move build
```

### Run Unit / E2E Tests

```bash
sui move test
```

## Publish

Set (or keep) your desired addresses in `Move.toml` then:

```bash
sui client publish --gas-budget 200000000
```

Record the resulting package ID; update README if sharing publicly.

## Example Flows

### 1. Mint an NFT

(Assuming you have the shared `TheSavagePetRegistry` and your account holds `AdminCap`, as produced in `init`):

```bash
# Call mint (adapt to actual function visibility & JSON args form for client)
# Example (pseudo):
sui client call \
  --package <PKG_ID> \
  --module sui_nft \
  --function mint \
  --args <REGISTRY_OBJECT_ID> "My Pet" "https://example.com/pet.png" '["rarity","element"]' '["legendary","fire"]' \
  --gas-budget 100000000
```

### 2. Place & List NFT

```bash
sui client call \
  --package <PKG_ID> \
  --module marketplace \
  --function place_and_list_nft \
  --args <MARKETPLACE_ID> <NFT_OBJECT_ID> 100000000 \
  --gas-budget 100000000
```

### 3. Purchase NFT

```bash
# Provide a Coin<SUI> with at least the listing price
sui client call \
  --package <PKG_ID> \
  --module marketplace \
  --function purchase_nft \
  --args <MARKETPLACE_ID> <NFT_ID> <COIN_OBJECT_ID> \
  --gas-budget 100000000
```

(Adjust invocation syntax if using the JSON-RPC or SDK.)

## Royalty Logic

Royalty = `price * 3 / 100`, sent to the address bound to `@creator`. Seller receives `price - royalty`. Any leftover (rare edge) stays in marketplace profits.

## Security / Considerations

- Ensure `CREATOR` & `AdminCap` custody is secure.
- Currently, per-address mint count variable exists in registry (`addresses_minted`) but mint logic does not yet enforce `max_mint_per_address`. Consider adding a check & increment for Sybil resistance.
- Marketplace does not prevent reentrancy by design due to Move's object semantics; still audit for logic errors before mainnet deployment.

## Extensibility Ideas

- Add bid/auction system.
- Enforce per-address mint limit.
- Add metadata update (admin) or freeze flag.
- Off-chain indexing via events already supported.

## License

Add your chosen license (e.g., MIT) in this section.

## Disclaimer

Code is provided as-is; audit before production use.

---

Contributions & issues welcome.
