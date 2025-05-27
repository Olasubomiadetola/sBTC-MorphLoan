
# sBTC-MorphLoan -  Dynamic NFT-Backed Loan Smart Contract

A Clarity smart contract for managing **loans backed by dynamic NFTs** on the Stacks blockchain. These NFTs update their attributes in real-time based on borrower repayment performance. The contract enables NFT holders to collateralize assets, receive loans, and gain or lose NFT value depending on payment behavior.

---

## 🔍 Overview

This contract allows:

* **Minting Dynamic NFTs** with initial attributes.
* **Listing NFTs for Loans** with customizable loan terms.
* **Offering Loans** by matching listed NFTs with a lender's proposal.
* **Repayment Tracking** and NFT attribute adjustment based on payment behavior.
* **Closing Loans** with proper asset return or collateral forfeiture.

This supports decentralized, reputation-based lending using on-chain, behavior-reactive NFTs.

---

## 🧱 Features

* ✅ NFT minting with initial attributes (`rarity`, `power-level`, `condition`)
* ✅ Loan listing system with customizable terms
* ✅ Secure loan offering and STX transfer
* ✅ Automatic collateral NFT transfer and custody
* ✅ Real-time NFT attribute updates based on repayments
* ✅ On-time vs. missed payment attribute effects
* ✅ Defaulted loan NFT claim by lenders
* ✅ Fully on-chain logic using Clarity

---

## 🧬 Data Structures

### 📦 Token Attributes

```clarity
(define-map token-attributes { token-id: uint } {
  rarity: uint,
  power-level: uint,
  condition: uint,
  last-updated: uint
})
```

### 💸 Loan Details

```clarity
(define-map loan-details { loan-id: uint } {
  borrower: principal,
  lender: principal,
  token-id: uint,
  amount: uint,
  interest-rate: uint,
  duration: uint,
  start-block: uint,
  status: (string-utf8 20),
  missed-payments: uint,
  total-repaid: uint
})
```

### 📋 Loan Listings

```clarity
(define-map loan-listings { token-id: uint } {
  owner: principal,
  requested-amount: uint,
  min-duration: uint,
  max-interest: uint
})
```

---

## 🛠️ Core Functions

### ✅ Mint NFT

```clarity
(mint-nft (recipient principal))
```

Mints a new dynamic NFT with base attributes (100 rarity, power, condition) and assigns it to a recipient.

---

### 📥 List NFT for Loan

```clarity
(list-nft-for-loan (token-id uint) (requested-amount uint) (min-duration uint) (max-interest uint))
```

Creates a loan listing for an NFT, specifying minimum acceptable terms.

---

### 💰 Offer Loan

```clarity
(offer-loan (token-id uint) (amount uint) (interest-rate uint) (duration uint))
```

A lender offers a loan to a listed NFT. On acceptance, STX is transferred and NFT is escrowed.

---

### 🔄 Update Attributes (Internal)

```clarity
(update-nft-attributes (loan-id uint) (payment uint) (payment-due uint))
```

Modifies the NFT’s `condition` and `power-level` based on payment performance. Rewards timely payment, penalizes missed ones.

---

### 🔚 Close Loan

```clarity
(close-loan (loan-id uint))
```

Finalizes the loan:

* If fully repaid: returns NFT to borrower.
* If defaulted: gives NFT to lender and marks loan as defaulted.

---

## 🚫 Error Codes

| Code   | Meaning             |
| ------ | ------------------- |
| `u100` | Not authorized      |
| `u101` | NFT not found       |
| `u102` | Already listed      |
| `u103` | Not listed          |
| `u104` | Insufficient value  |
| `u105` | Loan not found      |
| `u106` | Loan defaulted      |
| `u107` | Loan not due yet    |
| `u108` | Loan already closed |

---

## 🔐 Security Considerations

* Only NFT owners can list NFTs.
* NFTs are held in escrow by the contract during the loan period.
* All state transitions (loan creation, repayment, completion) are immutable and on-chain.

---
