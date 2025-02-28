;; StackFin: DeFi Personal Loans Protocol

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-amount (err u101))
(define-constant err-insufficient-collateral (err u102))
(define-constant err-loan-not-found (err u103))
(define-constant err-already-funded (err u104))
(define-constant err-payment-failed (err u105))

;; Data Variables
(define-data-var next-loan-id uint u1)
(define-data-var liquidation-threshold uint u150) ;; 150% collateral requirement

;; Data Maps
(define-map loans
  uint 
  {
    borrower: principal,
    amount: uint,
    duration: uint,
    interest-rate: uint,
    collateral: uint,
    lender: (optional principal),
    status: (string-ascii 20),
    paid-amount: uint,
    start-height: uint
  }
)

;; Public Functions
(define-public (request-loan (amount uint) (duration uint) (interest-rate uint))
  (let 
    (
      (loan-id (var-get next-loan-id))
      (required-collateral (/ (* amount u150) u100))
    )
    (try! (stx-transfer? required-collateral tx-sender (as-contract tx-sender)))
    (map-set loans loan-id
      {
        borrower: tx-sender,
        amount: amount,
        duration: duration,
        interest-rate: interest-rate,
        collateral: required-collateral,
        lender: none,
        status: "REQUESTED",
        paid-amount: u0,
        start-height: block-height
      }
    )
    (var-set next-loan-id (+ loan-id u1))
    (ok loan-id)
  )
)

(define-public (fund-loan (loan-id uint))
  (let ((loan (unwrap! (map-get? loans loan-id) err-loan-not-found)))
    (asserts! (is-none (get lender loan)) err-already-funded)
    (try! (stx-transfer? (get amount loan) tx-sender (get borrower loan)))
    (map-set loans loan-id 
      (merge loan { 
        lender: (some tx-sender),
        status: "ACTIVE"
      })
    )
    (ok true)
  )
)

(define-public (make-payment (loan-id uint) (payment-amount uint))
  (let 
    (
      (loan (unwrap! (map-get? loans loan-id) err-loan-not-found))
      (new-paid-amount (+ (get paid-amount loan) payment-amount))
    )
    (try! (stx-transfer? payment-amount tx-sender (unwrap! (get lender loan) err-loan-not-found)))
    (map-set loans loan-id 
      (merge loan {
        paid-amount: new-paid-amount,
        status: (if (>= new-paid-amount (get amount loan)) "COMPLETED" "ACTIVE")
      })
    )
    (ok true)
  )
)

;; Read Only Functions
(define-read-only (get-loan-info (loan-id uint))
  (ok (unwrap! (map-get? loans loan-id) err-loan-not-found))
)

(define-read-only (get-required-collateral (amount uint))
  (ok (/ (* amount (var-get liquidation-threshold)) u100))
)
