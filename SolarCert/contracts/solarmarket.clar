;; renewable-energy-certificates.clar

;; Define constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-invalid-token (err u102))
(define-constant err-expired (err u103))

;; Define data maps for REC tokens and management
(define-map validators principal bool)
(define-map tokens 
    uint  ;; token-id
    {
        owner: principal,
        generator: principal,
        mwh-amount: uint,
        generation-time: uint,  ;; block height
        expiration-time: uint,  ;; block height
        location: (string-ascii 50),
        technology: (string-ascii 20),
        device-id: (string-ascii 34),
        validated: bool
    }
)

(define-map token-owners 
    principal 
    (list 500 uint))  ;; List of token IDs owned by address

(define-data-var last-token-id uint u0)

;; Authorization functions
(define-public (register-validator (validator principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (map-set validators validator true))))

(define-public (remove-validator (validator principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (map-set validators validator false))))

;; Core REC token functions
(define-public (mint-rec
    (generator principal)
    (mwh-amount uint)
    (location (string-ascii 50))
    (technology (string-ascii 20))
    (device-id (string-ascii 34)))
    (let
        (
            (token-id (+ (var-get last-token-id) u1))
            (expiration-time (+ block-height u144)) ;; Set to ~24 hours for testing, adjust as needed
        )
        ;; Verify caller is authorized validator
        (asserts! (default-to false (map-get? validators tx-sender)) err-not-authorized)
        
        ;; Create new token
        (map-set tokens token-id {
            owner: generator,
            generator: generator,
            mwh-amount: mwh-amount,
            generation-time: block-height,
            expiration-time: expiration-time,
            location: location,
            technology: technology,
            device-id: device-id,
            validated: true
        })
        
        ;; Update owner's token list
        (match (map-get? token-owners generator)
            owned-tokens (map-set token-owners generator (unwrap! (as-max-len? (append owned-tokens token-id) u500) err-invalid-token))
            (map-set token-owners generator (list token-id))
        )
        
        ;; Update last token ID
        (var-set last-token-id token-id)
        (ok token-id)
    )
)

;; Read-only functions
(define-read-only (get-token (token-id uint))
    (map-get? tokens token-id)
)

(define-read-only (get-owner-tokens (owner principal))
    (map-get? token-owners owner)
)

(define-read-only (is-validator (address principal))
    (default-to false (map-get? validators address))
)

(define-read-only (is-token-expired (token-id uint))
    (match (map-get? tokens token-id)
        token (> block-height (get expiration-time token))
        true
    )
)

;; Add new constants
(define-constant err-not-owner (err u104))
(define-constant err-transfer-failed (err u105))

;; Helper function to remove token from owner's list
(define-private (remove-token (token-id uint) (token-list (list 500 uint)))
    (filter remove-token-filter token-list)
    (where remove-token-filter (tid uint) (not (is-eq tid token-id)))
)

;; Transfer functions
(define-public (transfer-rec (token-id uint) (recipient principal))
    (let
        (
            (token (unwrap! (map-get? tokens token-id) err-invalid-token))
            (sender-tokens (unwrap! (map-get? token-owners tx-sender) err-not-owner))
        )
        ;; Verify ownership and token validity
        (asserts! (is-eq (get owner token) tx-sender) err-not-owner)
        (asserts! (not (is-token-expired token-id)) err-expired)
        
        ;; Update token ownership
        (map-set tokens token-id (merge token {owner: recipient}))
        
        ;; Remove token from sender's list
        (map-set token-owners tx-sender 
            (remove-token token-id sender-tokens))
        
        ;; Add token to recipient's list
        (match (map-get? token-owners recipient)
            owned-tokens (map-set token-owners recipient 
                (unwrap! (as-max-len? (append owned-tokens token-id) u500) 
                    err-transfer-failed))
            (map-set token-owners recipient (list token-id))
        )
        
        (ok true)
    )
)

;; Batch transfer function
(define-public (transfer-rec-batch 
    (transfers (list 20 {token-id: uint, recipient: principal})))
    (fold check-and-transfer transfers (ok true))
)

;; Helper function for batch transfer
(define-private (check-and-transfer
    (transfer {token-id: uint, recipient: principal})
    (previous-result (response bool uint)))
    (match previous-result
        prev-ok (transfer-rec 
            (get token-id transfer)
            (get recipient transfer))
        prev-err previous-result
    )
)

;; Read-only functions for transfer history
(define-map transfer-history
    uint  ;; token-id
    (list 20 {
        from: principal,
        to: principal,
        time: uint
    })
)

(define-public (record-transfer 
    (token-id uint) 
    (from principal) 
    (to principal))
    (let
        (
            (current-history (default-to (list) (map-get? transfer-history token-id)))
        )
        (map-set transfer-history token-id
            (unwrap! (as-max-len? 
                (append current-history {
                    from: from,
                    to: to,
                    time: block-height
                }) 
                u20) 
                err-transfer-failed))
        (ok true)
    )
)

;; Additional read-only functions
(define-read-only (get-transfer-history (token-id uint))
    (map-get? transfer-history token-id)
)

(define-read-only (validate-transfer 
    (token-id uint) 
    (sender principal) 
    (recipient principal))
    (let
        (
            (token (unwrap! (map-get? tokens token-id) (ok false)))
        )
        (and
            (is-eq (get owner token) sender)
            (not (is-token-expired token-id))
            (not (is-eq sender recipient))
        )
    )
)

(define-read-only (get-token-details (token-id uint))
    (match (map-get? tokens token-id)
        token (some {
            owner: (get owner token),
            generator: (get generator token),
            mwh-amount: (get mwh-amount token),
            generation-time: (get generation-time token),
            expiration-time: (get expiration-time token),
            location: (get location token),
            technology: (get technology token),
            device-id: (get device-id token),
            validated: (get validated token),
            is-expired: (> block-height (get expiration-time token))
        })
        none
    )
)