(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-status (err u103))
(define-constant err-insufficient-funds (err u104))
(define-constant err-already-exists (err u105))
(define-constant err-expired (err u106))
(define-constant err-not-expired (err u107))
(define-constant err-invalid-amount (err u108))

(define-constant status-pending u1)
(define-constant status-funded u2)
(define-constant status-submitted u3)
(define-constant status-approved u4)
(define-constant status-disputed u5)
(define-constant status-cancelled u6)
(define-constant status-completed u7)

(define-data-var next-escrow-id uint u1)
(define-data-var platform-fee-rate uint u250)

(define-map escrows
    { escrow-id: uint }
    {
        client: principal,
        freelancer: principal,
        amount: uint,
        status: uint,
        description: (string-ascii 500),
        deadline: uint,
        created-at: uint,
        funded-at: (optional uint),
        submitted-at: (optional uint),
        completed-at: (optional uint),
    }
)

(define-map escrow-milestones
    {
        escrow-id: uint,
        milestone-id: uint,
    }
    {
        description: (string-ascii 200),
        amount: uint,
        status: uint,
        due-date: uint,
    }
)

(define-map dispute-info
    { escrow-id: uint }
    {
        raised-by: principal,
        reason: (string-ascii 500),
        raised-at: uint,
        resolved: bool,
        resolution: (optional (string-ascii 500)),
    }
)

(define-map user-balances
    { user: principal }
    { balance: uint }
)

(define-read-only (get-escrow (escrow-id uint))
    (map-get? escrows { escrow-id: escrow-id })
)

(define-read-only (get-user-balance (user principal))
    (default-to u0 (get balance (map-get? user-balances { user: user })))
)

(define-read-only (get-platform-fee-rate)
    (var-get platform-fee-rate)
)

(define-read-only (calculate-platform-fee (amount uint))
    (/ (* amount (var-get platform-fee-rate)) u10000)
)

(define-read-only (get-milestone
        (escrow-id uint)
        (milestone-id uint)
    )
    (map-get? escrow-milestones {
        escrow-id: escrow-id,
        milestone-id: milestone-id,
    })
)

(define-read-only (get-dispute (escrow-id uint))
    (map-get? dispute-info { escrow-id: escrow-id })
)

(define-read-only (is-expired (escrow-id uint))
    (match (get-escrow escrow-id)
        escrow-data (> stacks-block-height (get deadline escrow-data))
        false
    )
)

(define-public (create-escrow
        (freelancer principal)
        (amount uint)
        (description (string-ascii 500))
        (deadline uint)
    )
    (let (
            (escrow-id (var-get next-escrow-id))
            (current-height stacks-block-height)
        )
        (asserts! (> amount u0) err-invalid-amount)
        (asserts! (> deadline current-height) err-invalid-amount)
        (asserts! (not (is-eq tx-sender freelancer)) err-unauthorized)

        (map-set escrows { escrow-id: escrow-id } {
            client: tx-sender,
            freelancer: freelancer,
            amount: amount,
            status: status-pending,
            description: description,
            deadline: deadline,
            created-at: current-height,
            funded-at: none,
            submitted-at: none,
            completed-at: none,
        })

        (var-set next-escrow-id (+ escrow-id u1))
        (ok escrow-id)
    )
)

(define-public (fund-escrow (escrow-id uint))
    (let (
            (escrow-data (unwrap! (get-escrow escrow-id) err-not-found))
            (amount (get amount escrow-data))
        )
        (asserts! (is-eq tx-sender (get client escrow-data)) err-unauthorized)
        (asserts! (is-eq (get status escrow-data) status-pending)
            err-invalid-status
        )
        (asserts! (not (is-expired escrow-id)) err-expired)

        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))

        (map-set escrows { escrow-id: escrow-id }
            (merge escrow-data {
                status: status-funded,
                funded-at: (some stacks-block-height),
            })
        )

        (ok true)
    )
)

(define-public (submit-work (escrow-id uint))
    (let ((escrow-data (unwrap! (get-escrow escrow-id) err-not-found)))
        (asserts! (is-eq tx-sender (get freelancer escrow-data)) err-unauthorized)
        (asserts! (is-eq (get status escrow-data) status-funded)
            err-invalid-status
        )
        (asserts! (not (is-expired escrow-id)) err-expired)

        (map-set escrows { escrow-id: escrow-id }
            (merge escrow-data {
                status: status-submitted,
                submitted-at: (some stacks-block-height),
            })
        )

        (ok true)
    )
)

(define-public (approve-work (escrow-id uint))
    (let (
            (escrow-data (unwrap! (get-escrow escrow-id) err-not-found))
            (amount (get amount escrow-data))
            (freelancer (get freelancer escrow-data))
            (platform-fee (calculate-platform-fee amount))
            (freelancer-payment (- amount platform-fee))
        )
        (asserts! (is-eq tx-sender (get client escrow-data)) err-unauthorized)
        (asserts! (is-eq (get status escrow-data) status-submitted)
            err-invalid-status
        )

        (try! (as-contract (stx-transfer? freelancer-payment tx-sender freelancer)))
        (try! (as-contract (stx-transfer? platform-fee tx-sender contract-owner)))

        (map-set escrows { escrow-id: escrow-id }
            (merge escrow-data {
                status: status-completed,
                completed-at: (some stacks-block-height),
            })
        )

        (ok true)
    )
)

(define-public (reject-work (escrow-id uint))
    (let (
            (escrow-data (unwrap! (get-escrow escrow-id) err-not-found))
            (amount (get amount escrow-data))
            (client (get client escrow-data))
        )
        (asserts! (is-eq tx-sender (get client escrow-data)) err-unauthorized)
        (asserts! (is-eq (get status escrow-data) status-submitted)
            err-invalid-status
        )

        (try! (as-contract (stx-transfer? amount tx-sender client)))

        (map-set escrows { escrow-id: escrow-id }
            (merge escrow-data { status: status-cancelled })
        )

        (ok true)
    )
)

(define-public (raise-dispute
        (escrow-id uint)
        (reason (string-ascii 500))
    )
    (let ((escrow-data (unwrap! (get-escrow escrow-id) err-not-found)))
        (asserts!
            (or
                (is-eq tx-sender (get client escrow-data))
                (is-eq tx-sender (get freelancer escrow-data))
            )
            err-unauthorized
        )
        (asserts!
            (or
                (is-eq (get status escrow-data) status-funded)
                (is-eq (get status escrow-data) status-submitted)
            )
            err-invalid-status
        )

        (map-set dispute-info { escrow-id: escrow-id } {
            raised-by: tx-sender,
            reason: reason,
            raised-at: stacks-block-height,
            resolved: false,
            resolution: none,
        })

        (map-set escrows { escrow-id: escrow-id }
            (merge escrow-data { status: status-disputed })
        )

        (ok true)
    )
)

(define-public (resolve-dispute
        (escrow-id uint)
        (resolution (string-ascii 500))
        (award-to-freelancer bool)
    )
    (let (
            (escrow-data (unwrap! (get-escrow escrow-id) err-not-found))
            (dispute-data (unwrap! (get-dispute escrow-id) err-not-found))
            (amount (get amount escrow-data))
            (client (get client escrow-data))
            (freelancer (get freelancer escrow-data))
            (platform-fee (calculate-platform-fee amount))
            (net-amount (- amount platform-fee))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-eq (get status escrow-data) status-disputed)
            err-invalid-status
        )
        (asserts! (not (get resolved dispute-data)) err-invalid-status)

        (if award-to-freelancer
            (begin
                (try! (as-contract (stx-transfer? net-amount tx-sender freelancer)))
                (try! (as-contract (stx-transfer? platform-fee tx-sender contract-owner)))
                (map-set escrows { escrow-id: escrow-id }
                    (merge escrow-data {
                        status: status-completed,
                        completed-at: (some stacks-block-height),
                    })
                )
            )
            (begin
                (try! (as-contract (stx-transfer? amount tx-sender client)))
                (map-set escrows { escrow-id: escrow-id }
                    (merge escrow-data { status: status-cancelled })
                )
            )
        )

        (map-set dispute-info { escrow-id: escrow-id }
            (merge dispute-data {
                resolved: true,
                resolution: (some resolution),
            })
        )

        (ok true)
    )
)

(define-public (cancel-escrow (escrow-id uint))
    (let (
            (escrow-data (unwrap! (get-escrow escrow-id) err-not-found))
            (amount (get amount escrow-data))
            (client (get client escrow-data))
        )
        (asserts! (is-eq tx-sender (get client escrow-data)) err-unauthorized)
        (asserts! (is-eq (get status escrow-data) status-pending)
            err-invalid-status
        )

        (map-set escrows { escrow-id: escrow-id }
            (merge escrow-data { status: status-cancelled })
        )

        (ok true)
    )
)

(define-public (emergency-release (escrow-id uint))
    (let (
            (escrow-data (unwrap! (get-escrow escrow-id) err-not-found))
            (amount (get amount escrow-data))
            (freelancer (get freelancer escrow-data))
            (platform-fee (calculate-platform-fee amount))
            (net-amount (- amount platform-fee))
        )
        (asserts! (is-eq tx-sender (get freelancer escrow-data)) err-unauthorized)
        (asserts! (is-eq (get status escrow-data) status-funded)
            err-invalid-status
        )
        (asserts! (is-expired escrow-id) err-not-expired)

        (try! (as-contract (stx-transfer? net-amount tx-sender freelancer)))
        (try! (as-contract (stx-transfer? platform-fee tx-sender contract-owner)))

        (map-set escrows { escrow-id: escrow-id }
            (merge escrow-data {
                status: status-completed,
                completed-at: (some stacks-block-height),
            })
        )

        (ok true)
    )
)

(define-public (set-platform-fee-rate (new-rate uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (<= new-rate u1000) err-invalid-amount)
        (var-set platform-fee-rate new-rate)
        (ok true)
    )
)

(define-public (withdraw-platform-fees
        (amount uint)
        (recipient principal)
    )
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (try! (as-contract (stx-transfer? amount tx-sender recipient)))
        (ok true)
    )
)
