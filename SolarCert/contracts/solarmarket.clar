;; Define constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-invalid-token (err u102))
(define-constant err-expired (err u103))
(define-constant err-not-owner (err u104))
(define-constant err-invalid-input (err u105))

;; Define data maps for REC tokens and management
(define-map validators principal bool)
(define-map tokens 
    uint ;; token-id
    {
        owner: principal,
        generator: principal,
        mwh-amount: uint,
        generation-time: uint, ;; block height
        expiration-time: uint, ;; block height
        location: (string-ascii 50),
        technology: (string-ascii 20),
        device-id: (string-ascii 34),
        validated: bool
    }
)

(define-map token-owners 
    principal 
    (list 500 uint)) ;; List of token IDs owned by address

(define-map transfer-logs
    { token-id: uint, log-index: uint } ;; Composite key
    { from: principal, to: principal, timestamp: uint })

(define-map log-counters uint uint) ;; Maps token-id to current log index

(define-data-var last-token-id uint u0)

;; Authorization functions
(define-public (register-validator (validator principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (not (is-eq validator contract-owner)) err-invalid-input) ;; Prevent owner from being validator
        (asserts! (not (default-to false (map-get? validators validator))) err-invalid-input) ;; Check if already registered
        (ok (map-set validators validator true))))

(define-public (remove-validator (validator principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (default-to false (map-get? validators validator)) err-invalid-input) ;; Check if validator exists
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
            (expiration-time (+ block-height u144)) ;; Set to ~24 hours for testing
        )
        ;; Input validation
        (asserts! (default-to false (map-get? validators tx-sender)) err-not-authorized)
        (asserts! (not (is-eq generator tx-sender)) err-invalid-input) ;; Generator cannot be validator
        (asserts! (validate-mwh-amount mwh-amount) err-invalid-input)
        (asserts! (validate-location location) err-invalid-input)
        (asserts! (validate-technology technology) err-invalid-input)
        (asserts! (validate-device-id device-id) err-invalid-input)
        
        ;; Create new token after validation
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
        
        ;; Update last token ID
        (var-set last-token-id token-id)
        (ok token-id)
    )
)

;; Simple transfer function with transfer logging
(define-public (transfer (token-id uint) (recipient principal))
    (match (map-get? tokens token-id)
        token
        (begin
            (asserts! (is-eq (get owner token) tx-sender) err-not-owner)
            (asserts! (not (is-token-expired token-id)) err-expired)
            (asserts! (not (is-eq recipient tx-sender)) err-invalid-input) ;; Cannot transfer to self
            (asserts! (not (is-eq recipient (get generator token))) err-invalid-input) ;; Cannot transfer back to generator
            (map-set tokens token-id (merge token {owner: recipient}))
            ;; Log the transfer
            (log-transfer token-id (get owner token) recipient)
            (ok true))
        err-invalid-token))

;; Log transfer helper
(define-private (log-transfer (token-id uint) (from principal) (to principal))
    (let (
            (current-index (default-to u0 (map-get? log-counters token-id)))
            (new-index (mod (+ current-index u1) u100)) ;; Circular buffer from 0 to 99
        )
        ;; Store the log entry with composite key {token-id, log-index: new-index}
        (map-set transfer-logs { token-id: token-id, log-index: new-index }
            { from: from, to: to, timestamp: block-height })
        ;; Update the log counter for this token-id
        (map-set log-counters token-id new-index)))

;; Read-only functions
(define-read-only (get-token (token-id uint))
    (map-get? tokens token-id))

(define-read-only (is-validator (address principal))
    (default-to false (map-get? validators address)))

(define-read-only (is-token-expired (token-id uint))
    (match (map-get? tokens token-id)
        token (> block-height (get expiration-time token))
        false))

;; Function to get the latest log index for a token
(define-read-only (get-log-count (token-id uint))
    (default-to u0 (map-get? log-counters token-id)))

;; Function to get a specific transfer log entry
(define-read-only (get-transfer-log (token-id uint) (log-index uint))
    (map-get? transfer-logs { token-id: token-id, log-index: log-index }))

;; Input validation functions
(define-private (validate-mwh-amount (amount uint))
    (and (> amount u0) (<= amount u1000000))) ;; Max 1 million MWh per token

(define-private (validate-location (loc (string-ascii 50)))
    (and 
        (> (len loc) u0)
        (<= (len loc) u50)))

(define-private (validate-technology (tech (string-ascii 20)))
    (and 
        (> (len tech) u0)
        (<= (len tech) u20)))

(define-private (validate-device-id (id (string-ascii 34)))
    (and 
        (> (len id) u0)
        (<= (len id) u34)))
