;; SafeStream Insurance Protocol

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-unauthorized (err u100))
(define-constant err-invalid-amount (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-no-coverage (err u103))
(define-constant err-invalid-claim (err u104))
(define-constant err-invalid-params (err u105))

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

;; Private Functions
(define-private (validate-parameters (amount uint) (threshold uint) (duration uint))
  (and
    (> amount u0)
    (< amount u1000000000)
    (> threshold u0)
    (<= threshold amount)
    (>= duration u144)
    (<= duration u52560)
  )
)

;; Public Functions
(define-public (purchase-coverage (amount uint) (threshold uint) (duration uint))
  (let
    (
      (premium (calculate-premium amount threshold duration))
      (start-block block-height)
      (end-block (+ block-height duration))
    )
    (asserts! (validate-parameters amount threshold duration) err-invalid-params)
    (if (>= (stx-get-balance tx-sender) premium)
      (begin
        (try! (stx-transfer? premium tx-sender (as-contract tx-sender)))
        (var-set protocol-balance (+ (var-get protocol-balance) premium))
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
    (asserts! (get active user-coverage) err-invalid-claim)
    (asserts! (<= block-height (get end-block user-coverage)) err-invalid-claim)
    (asserts! (<= income (get threshold user-coverage)) err-invalid-claim)
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
)

(define-public (process-claim (claim-id uint))
  (let
    (
      (claim (unwrap! (map-get? claims {claim-id: claim-id}) err-invalid-claim))
      (payout-amount (get amount claim))
    )
    (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
    (asserts! (is-eq (get status claim) "pending") err-invalid-claim)
    (asserts! (<= payout-amount (var-get protocol-balance)) err-insufficient-balance)
    
    (try! (as-contract (stx-transfer? payout-amount tx-sender (get policyholder claim))))
    (var-set protocol-balance (- (var-get protocol-balance) payout-amount))
    
    (map-set claims
      { claim-id: claim-id }
      (merge claim { status: "paid" })
    )
    (ok true)
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
  (let
    (
      (base-rate u100)
      (risk-factor (/ (* threshold u10000) amount))
      (duration-factor (/ duration u144))
    )
    (* (/ (* amount base-rate) u10000) (+ duration-factor u1))
  )
)
