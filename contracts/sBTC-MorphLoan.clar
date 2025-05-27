;; sBTC-MorphLoan

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_NFT_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_LISTED (err u102))
(define-constant ERR_NOT_LISTED (err u103))
(define-constant ERR_INSUFFICIENT_VALUE (err u104))
(define-constant ERR_LOAN_NOT_FOUND (err u105))
(define-constant ERR_LOAN_DEFAULTED (err u106))
(define-constant ERR_LOAN_NOT_DUE (err u107))
(define-constant ERR_LOAN_CLOSED (err u108))

;; NFT Definition
(define-non-fungible-token dynamic-nft uint)

;; Data Maps
(define-map token-attributes
    { token-id: uint }
    {
        rarity: uint,
        power-level: uint,
        condition: uint,
        last-updated: uint
    }
)

(define-map loan-details
    { loan-id: uint }
    {
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
    }
)

(define-map token-loans 
    { token-id: uint }
    { loan-id: uint }
)

(define-map loan-listings
    { token-id: uint }
    {
        owner: principal,
        requested-amount: uint,
        min-duration: uint,
        max-interest: uint
    }
)

;; Variables
(define-data-var next-token-id uint u1)
(define-data-var next-loan-id uint u1)

;; Read-only functions
(define-read-only (get-token-attributes (token-id uint))
    (map-get? token-attributes { token-id: token-id })
)

(define-read-only (get-loan-details (loan-id uint))
    (map-get? loan-details { loan-id: loan-id })
)

(define-read-only (get-token-loan (token-id uint))
    (map-get? token-loans { token-id: token-id })
)

(define-read-only (get-loan-listing (token-id uint))
    (map-get? loan-listings { token-id: token-id })
)

;; Mint new NFT
(define-public (mint-nft (recipient principal))
    (let 
        ((token-id (var-get next-token-id)))
        
        ;; Mint NFT
        (try! (nft-mint? dynamic-nft token-id recipient))
        
        ;; Set initial attributes
        (map-set token-attributes
            { token-id: token-id }
            {
                rarity: u100,
                power-level: u100,
                condition: u100,
                last-updated: stacks-block-height
            }
        )
        
        ;; Increment token ID
        (var-set next-token-id (+ token-id u1))
        (ok token-id)
    )
)

;; List NFT for loan
(define-public (list-nft-for-loan 
    (token-id uint) 
    (requested-amount uint)
    (min-duration uint)
    (max-interest uint))
    
    (let ((owner (unwrap! (nft-get-owner? dynamic-nft token-id) ERR_NFT_NOT_FOUND)))
        ;; Checks
        (asserts! (is-eq tx-sender owner) ERR_NOT_AUTHORIZED)
        (asserts! (is-none (get-loan-listing token-id)) ERR_ALREADY_LISTED)
        
        ;; Create listing
        (map-set loan-listings
            { token-id: token-id }
            {
                owner: tx-sender,
                requested-amount: requested-amount,
                min-duration: min-duration,
                max-interest: max-interest
            }
        )
        (ok true)
    )
)

;; Offer loan
(define-public (offer-loan 
    (token-id uint)
    (amount uint)
    (interest-rate uint)
    (duration uint))
    
    (let 
        ((listing (unwrap! (get-loan-listing token-id) ERR_NOT_LISTED))
         (loan-id (var-get next-loan-id)))
        
        ;; Checks
        (asserts! (>= amount (get requested-amount listing)) ERR_INSUFFICIENT_VALUE)
        (asserts! (>= duration (get min-duration listing)) ERR_INSUFFICIENT_VALUE)
        (asserts! (<= interest-rate (get max-interest listing)) ERR_INSUFFICIENT_VALUE)
        
        ;; Transfer STX to borrower
        (try! (stx-transfer? amount tx-sender (get owner listing)))
        
        ;; Create loan
        (map-set loan-details
            { loan-id: loan-id }
            {
                borrower: (get owner listing),
                lender: tx-sender,
                token-id: token-id,
                amount: amount,
                interest-rate: interest-rate,
                duration: duration,
                start-block: stacks-block-height,
                status: u"active",
                missed-payments: u0,
                total-repaid: u0
            }
        )
        
        ;; Link token to loan
        (map-set token-loans { token-id: token-id } { loan-id: loan-id })
        
        ;; Remove listing
        (map-delete loan-listings { token-id: token-id })
        
        ;; Transfer NFT to contract
        (try! (nft-transfer? dynamic-nft token-id (get owner listing) (as-contract tx-sender)))
        
        ;; Increment loan ID
        (var-set next-loan-id (+ loan-id u1))
        (ok loan-id)
    )
)

;; Internal function to calculate payment
(define-private (calculate-payment (loan (tuple (amount uint) (interest-rate uint) (duration uint) (start-block uint))))
    (let
        ((total-amount (* (get amount loan) (+ u100 (get interest-rate loan))))
         (payment-per-block (/ total-amount (get duration loan))))
        payment-per-block
    )
)

(define-private (min-uint (a uint) (b uint))
    (if (<= a b) a b)
)

(define-private (max-uint (a uint) (b uint))
    (if (>= a b) a b)
)


;; Update NFT attributes
(define-private (update-nft-attributes (loan-id uint) (payment uint) (payment-due uint))
    (match (get-loan-details loan-id)
        loan-data (match (get-token-attributes (get token-id loan-data))
            token-data (begin
                (map-set token-attributes
                    { token-id: (get token-id loan-data) }
                    (merge token-data {
                        condition: (if (>= payment payment-due)
                            (min-uint u100 (+ (get condition token-data) u5))
                            (max-uint u1 (- (get condition token-data) u10))),
                        power-level: (if (>= payment payment-due)
                            (min-uint u100 (+ (get power-level token-data) u3))
                            (max-uint u1 (- (get power-level token-data) u7))),
                        last-updated: stacks-block-height
                    })
                )
                (ok true))
            ERR_NFT_NOT_FOUND)
        ERR_LOAN_NOT_FOUND)
)


;; Close loan
(define-public (close-loan (loan-id uint))
    (let
        ((loan (unwrap! (get-loan-details loan-id) ERR_LOAN_NOT_FOUND)))
        
        ;; Checks
        (asserts! (is-eq (get status loan) u"active") ERR_LOAN_CLOSED)
        (asserts! (>= (- stacks-block-height (get start-block loan)) (get duration loan)) ERR_LOAN_NOT_DUE)
        
        (if (>= (get total-repaid loan) (get amount loan))
            (begin
                ;; Return NFT to borrower
                (try! (as-contract (nft-transfer? 
                    dynamic-nft 
                    (get token-id loan) 
                    (as-contract tx-sender) 
                    (get borrower loan))))
                
                ;; Update loan status
                (map-set loan-details
                    { loan-id: loan-id }
                    (merge loan { status: u"completed" }))
                (ok true))
            
            (begin
                ;; Transfer NFT to lender
                (try! (as-contract (nft-transfer? 
                    dynamic-nft 
                    (get token-id loan) 
                    (as-contract tx-sender) 
                    (get lender loan))))
                
                ;; Update loan status
                (map-set loan-details
                    { loan-id: loan-id }
                    (merge loan { status: u"defaulted" }))
                (ok false))
        )
    )
)
