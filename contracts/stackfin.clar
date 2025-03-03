;; StackFin: DeFi Personal Loans Protocol

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-amount (err u101))
(define-constant err-insufficient-collateral (err u102))
(define-constant err-loan-not-found (err u103))
(define-constant err-already-funded (err u104))
(define-constant err-payment-failed (err u105))
(define-constant err-not-liquidatable (err u106))
(define-constant err-paused (err u107))

;; Data Variables
(define-data-var next-loan-id uint u1)
(define-data-var liquidation-threshold uint u150) ;; 150% collateral requirement
(define-data-var contract-paused bool false)

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
    start-height: uint,
    last-interest-calc: uint
  }
)

;; Private Functions
(define-private (calculate-interest (loan-id uint))
  (let
    (
      (loan (unwrap! (map-get? loans loan-id) err-loan-not-found))
      (blocks-passed (- block-height (get last-interest-calc loan)))
      (interest-per-block (/ (* (get amount loan) (get interest-rate loan)) (* u100 u144 u365)))
      (accrued-interest (* blocks-passed interest-per-block))
    )
    (ok accrued-interest)
  )
)

;; Public Functions
(define-public (set-contract-pause (paused bool))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set contract-paused paused)
    (print {event: "contract-pause-updated", paused: paused})
    (ok true)
  )
)

(define-public (request-loan (amount uint) (duration uint) (interest-rate uint))
  (let 
    (
      (loan-id (var-get next-loan-id))
      (required-collateral (/ (* amount u150) u100))
    )
    (asserts! (not (var-get contract-paused)) err-paused)
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
        start-height: block-height,
        last-interest-calc: block-height
      }
    )
    (var-set next-loan-id (+ loan-id u1))
    (print {event: "loan-requested", loan-id: loan-id, borrower: tx-sender})
    (ok loan-id)
  )
)

(define-public (fund-loan (loan-id uint))
  (let ((loan (unwrap! (map-get? loans loan-id) err-loan-not-found)))
    (asserts! (not (var-get contract-paused)) err-paused)
    (asserts! (is-none (get lender loan)) err-already-funded)
    (try! (stx-transfer? (get amount loan) tx-sender (get borrower loan)))
    (map-set loans loan-id 
      (merge loan { 
        lender: (some tx-sender),
        status: "ACTIVE"
      })
    )
    (print {event: "loan-funded", loan-id: loan-id, lender: tx-sender})
    (ok true)
  )
)

(define-public (make-payment (loan-id uint) (payment-amount uint))
  (let 
    (
      (loan (unwrap! (map-get? loans loan-id) err-loan-not-found))
      (interest (unwrap! (calculate-interest loan-id) err-payment-failed))
      (total-due (+ interest payment-amount))
      (new-paid-amount (+ (get paid-amount loan) payment-amount))
    )
    (asserts! (not (var-get contract-paused)) err-paused)
    (try! (stx-transfer? total-due tx-sender (unwrap! (get lender loan) err-loan-not-found)))
    (map-set loans loan-id 
      (merge loan {
        paid-amount: new-paid-amount,
        last-interest-calc: block-height,
        status: (if (>= new-paid-amount (get amount loan)) "COMPLETED" "ACTIVE")
      })
    )
    (print {event: "payment-made", loan-id: loan-id, amount: payment-amount, interest: interest})
    (ok true)
  )
)

(define-public (liquidate (loan-id uint))
  (let
    (
      (loan (unwrap! (map-get? loans loan-id) err-loan-not-found))
      (current-value (get collateral loan))
      (min-required (/ (* (get amount loan) (var-get liquidation-threshold)) u100))
    )
    (asserts! (< current-value min-required) err-not-liquidatable)
    (try! (as-contract (stx-transfer? current-value (as-contract tx-sender) (unwrap! (get lender loan) err-loan-not-found))))
    (map-set loans loan-id
      (merge loan {
        status: "LIQUIDATED",
        collateral: u0
      })
    )
    (print {event: "loan-liquidated", loan-id: loan-id, collateral: current-value})
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

(define-read-only (get-current-interest (loan-id uint))
  (calculate-interest loan-id)
)
