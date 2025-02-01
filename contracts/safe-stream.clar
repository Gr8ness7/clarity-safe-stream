;; SafeStream Insurance Protocol

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-unauthorized (err u100))
(define-constant err-invalid-amount (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-no-coverage (err u103))
(define-constant err-invalid-claim (err u104))

;; Data Variables
(define-map coverage
  { policyholder: principal }
  {
    amount: uint,
    threshold: uint,
    premium: uint,
    start-block: uint,
    end-block: uint,
    active: bool
  }
)

(define-map claims 
  { claim-id: uint }
  {
    policyholder: principal,
    amount: uint,
    status: (string-ascii 20),
    block: uint
  }
)

(define-data-var next-claim-id uint u0)
(define-data-var protocol-balance uint u0)

;; Public Functions
(define-public (purchase-coverage (amount uint) (threshold uint) (duration uint))
  (let
    (
      (premium (calculate-premium amount threshold duration))
      (start-block block-height)
      (end-block (+ block-height duration))
    )
    (if (>= (stx-get-balance tx-sender) premium)
      (begin
        (try! (stx-transfer? premium tx-sender (as-contract tx-sender)))
        (map-set coverage
          { policyholder: tx-sender }
          {
            amount: amount,
            threshold: threshold,
            premium: premium,
            start-block: start-block,
            end-block: end-block,
            active: true
          }
        )
        (ok true)
      )
      err-insufficient-balance
    )
  )
)

(define-public (submit-claim (income uint))
  (let
    (
      (user-coverage (unwrap! (map-get? coverage {policyholder: tx-sender}) err-no-coverage))
      (claim-id (var-get next-claim-id))
    )
    (if (and
          (get active user-coverage)
          (<= income (get threshold user-coverage))
          (<= block-height (get end-block user-coverage))
        )
      (begin
        (map-set claims
          { claim-id: claim-id }
          {
            policyholder: tx-sender,
            amount: (get amount user-coverage),
            status: "pending",
            block: block-height
          }
        )
        (var-set next-claim-id (+ claim-id u1))
        (ok claim-id)
      )
      err-invalid-claim
    )
  )
)

;; Read Only Functions
(define-read-only (get-coverage (policyholder principal))
  (map-get? coverage {policyholder: policyholder})
)

(define-read-only (get-claim (claim-id uint))
  (map-get? claims {claim-id: claim-id})
)

(define-read-only (calculate-premium (amount uint) (threshold uint) (duration uint))
  ;; Premium calculation logic would go here
  ;; This is a simplified version
  (/ (* amount duration) u10000)
)
