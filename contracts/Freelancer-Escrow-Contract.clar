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
(define-constant err-already-rated (err u109))
(define-constant err-invalid-rating (err u110))
(define-constant err-portfolio-exists (err u111))
(define-constant err-portfolio-not-found (err u112))
(define-constant err-invalid-skill (err u113))
(define-constant err-escrow-not-completed (err u114))
(define-constant err-already-verified (err u115))
(define-constant err-invalid-portfolio-data (err u116))

(define-constant status-pending u1)
(define-constant status-funded u2)
(define-constant status-submitted u3)
(define-constant status-approved u4)
(define-constant status-disputed u5)
(define-constant status-cancelled u6)
(define-constant status-completed u7)

(define-constant schedule-type-none u0)
(define-constant schedule-type-fixed u1)
(define-constant schedule-type-milestone u2)

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

(define-map user-ratings
    { user: principal }
    {
        total-score: uint,
        rating-count: uint,
        average-rating: uint,
    }
)

(define-map escrow-ratings
    {
        escrow-id: uint,
        rater: principal,
    }
    {
        rating: uint,
        comment: (string-ascii 200),
        rated-at: uint,
    }
)

(define-map payment-schedules
    { escrow-id: uint }
    {
        schedule-type: uint,
        total-payments: uint,
        payment-amount: uint,
        payment-interval: uint,
        next-payment-block: uint,
        payments-released: uint,
        auto-release-enabled: bool,
    }
)

(define-map payment-history
    {
        escrow-id: uint,
        payment-index: uint,
    }
    {
        amount: uint,
        released-at: uint,
        released-by: (optional principal),
        auto-released: bool,
    }
)

(define-map freelancer-portfolios
    { freelancer: principal }
    {
        bio: (string-utf8 500),
        skills: (list 20 (string-utf8 50)),
        portfolio-items: (list 10 {
            title: (string-utf8 100),
            description: (string-utf8 300),
            project-url: (optional (string-utf8 200))
        }),
        total-verified-skills: uint,
        profile-created-at: uint,
    }
)

(define-map skill-verifications
    { freelancer: principal, skill: (string-utf8 50), verifier: principal }
    {
        escrow-id: uint,
        verified-at: uint,
        endorsement-note: (optional (string-utf8 200)),
    }
)

(define-map skill-verification-counts
    { freelancer: principal, skill: (string-utf8 50) }
    { count: uint }
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

(define-read-only (get-user-rating (user principal))
    (default-to {
        total-score: u0,
        rating-count: u0,
        average-rating: u0,
    }
        (map-get? user-ratings { user: user })
    )
)

(define-read-only (get-escrow-rating
        (escrow-id uint)
        (rater principal)
    )
    (map-get? escrow-ratings {
        escrow-id: escrow-id,
        rater: rater,
    })
)

(define-read-only (get-payment-schedule (escrow-id uint))
    (map-get? payment-schedules { escrow-id: escrow-id })
)

(define-read-only (get-payment-history
        (escrow-id uint)
        (payment-index uint)
    )
    (map-get? payment-history {
        escrow-id: escrow-id,
        payment-index: payment-index,
    })
)

(define-read-only (is-payment-due (escrow-id uint))
    (match (get-payment-schedule escrow-id)
        schedule-data (and
            (get auto-release-enabled schedule-data)
            (<= (get next-payment-block schedule-data) stacks-block-height)
            (< (get payments-released schedule-data)
                (get total-payments schedule-data)
            )
        )
        false
    )
)

(define-read-only (get-portfolio (freelancer principal))
    (map-get? freelancer-portfolios { freelancer: freelancer })
)

(define-read-only (get-skill-verification-count 
        (freelancer principal)
        (skill (string-utf8 50))
    )
    (default-to u0 (get count (map-get? skill-verification-counts {
        freelancer: freelancer,
        skill: skill,
    })))
)

(define-read-only (has-skill-verification
        (freelancer principal)
        (skill (string-utf8 50))
        (verifier principal)
    )
    (is-some (map-get? skill-verifications {
        freelancer: freelancer,
        skill: skill,
        verifier: verifier,
    }))
)

(define-read-only (get-verified-skills (freelancer principal))
    (match (get-portfolio freelancer)
        portfolio-data {
            skills: (get skills portfolio-data),
            total-verified: (get total-verified-skills portfolio-data),
        }
        { skills: (list), total-verified: u0 }
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

(define-public (create-payment-schedule
        (escrow-id uint)
        (schedule-type uint)
        (total-payments uint)
        (payment-interval uint)
        (auto-release bool)
    )
    (let (
            (escrow-data (unwrap! (get-escrow escrow-id) err-not-found))
            (amount (get amount escrow-data))
            (payment-amount (/ amount total-payments))
        )
        (asserts! (is-eq tx-sender (get client escrow-data)) err-unauthorized)
        (asserts! (is-eq (get status escrow-data) status-pending)
            err-invalid-status
        )
        (asserts! (> total-payments u0) err-invalid-amount)
        (asserts! (> payment-interval u0) err-invalid-amount)
        (asserts! (<= schedule-type schedule-type-milestone) err-invalid-amount)
        (asserts! (is-none (get-payment-schedule escrow-id)) err-already-exists)

        (map-set payment-schedules { escrow-id: escrow-id } {
            schedule-type: schedule-type,
            total-payments: total-payments,
            payment-amount: payment-amount,
            payment-interval: payment-interval,
            next-payment-block: u0,
            payments-released: u0,
            auto-release-enabled: auto-release,
        })

        (ok true)
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

        (match (get-payment-schedule escrow-id)
            schedule-data (map-set payment-schedules { escrow-id: escrow-id }
                (merge schedule-data { next-payment-block: (+ stacks-block-height (get payment-interval schedule-data)) })
            )
            true
        )

        (map-set escrows { escrow-id: escrow-id }
            (merge escrow-data {
                status: status-funded,
                funded-at: (some stacks-block-height),
            })
        )

        (ok true)
    )
)

(define-public (release-scheduled-payment (escrow-id uint))
    (let (
            (escrow-data (unwrap! (get-escrow escrow-id) err-not-found))
            (schedule-data (unwrap! (get-payment-schedule escrow-id) err-not-found))
            (freelancer (get freelancer escrow-data))
            (payment-amount (get payment-amount schedule-data))
            (current-payments (get payments-released schedule-data))
            (platform-fee (calculate-platform-fee payment-amount))
            (net-payment (- payment-amount platform-fee))
        )
        (asserts! (is-eq (get status escrow-data) status-funded)
            err-invalid-status
        )
        (asserts! (< current-payments (get total-payments schedule-data))
            err-invalid-status
        )
        (asserts!
            (or
                (is-eq tx-sender (get client escrow-data))
                (and
                    (get auto-release-enabled schedule-data)
                    (<= (get next-payment-block schedule-data)
                        stacks-block-height
                    )
                )
            )
            err-unauthorized
        )

        (try! (as-contract (stx-transfer? net-payment tx-sender freelancer)))
        (try! (as-contract (stx-transfer? platform-fee tx-sender contract-owner)))

        (map-set payment-history {
            escrow-id: escrow-id,
            payment-index: current-payments,
        } {
            amount: payment-amount,
            released-at: stacks-block-height,
            released-by: (if (is-eq tx-sender (get client escrow-data))
                (some tx-sender)
                none
            ),
            auto-released: (and
                (get auto-release-enabled schedule-data)
                (<= (get next-payment-block schedule-data) stacks-block-height)
            ),
        })

        (let ((new-payments-released (+ current-payments u1)))
            (if (is-eq new-payments-released (get total-payments schedule-data))
                (map-set escrows { escrow-id: escrow-id }
                    (merge escrow-data {
                        status: status-completed,
                        completed-at: (some stacks-block-height),
                    })
                )
                (map-set payment-schedules { escrow-id: escrow-id }
                    (merge schedule-data {
                        payments-released: new-payments-released,
                        next-payment-block: (+ stacks-block-height
                            (get payment-interval schedule-data)
                        ),
                    })
                )
            )
        )

        (ok true)
    )
)

(define-public (toggle-auto-release (escrow-id uint))
    (let (
            (escrow-data (unwrap! (get-escrow escrow-id) err-not-found))
            (schedule-data (unwrap! (get-payment-schedule escrow-id) err-not-found))
        )
        (asserts! (is-eq tx-sender (get client escrow-data)) err-unauthorized)
        (asserts! (is-eq (get status escrow-data) status-funded)
            err-invalid-status
        )

        (map-set payment-schedules { escrow-id: escrow-id }
            (merge schedule-data { auto-release-enabled: (not (get auto-release-enabled schedule-data)) })
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

(define-public (rate-user
        (escrow-id uint)
        (rating uint)
        (comment (string-ascii 200))
    )
    (let (
            (escrow-data (unwrap! (get-escrow escrow-id) err-not-found))
            (client (get client escrow-data))
            (freelancer (get freelancer escrow-data))
            (rated-user (if (is-eq tx-sender client)
                freelancer
                client
            ))
            (existing-rating (get-escrow-rating escrow-id tx-sender))
            (current-user-rating (get-user-rating rated-user))
            (current-total (get total-score current-user-rating))
            (current-count (get rating-count current-user-rating))
        )
        (asserts! (is-eq (get status escrow-data) status-completed)
            err-invalid-status
        )
        (asserts!
            (or
                (is-eq tx-sender client)
                (is-eq tx-sender freelancer)
            )
            err-unauthorized
        )
        (asserts! (and (>= rating u1) (<= rating u5)) err-invalid-rating)
        (asserts! (is-none existing-rating) err-already-rated)

        (map-set escrow-ratings {
            escrow-id: escrow-id,
            rater: tx-sender,
        } {
            rating: rating,
            comment: comment,
            rated-at: stacks-block-height,
        })

        (let (
                (new-total (+ current-total rating))
                (new-count (+ current-count u1))
                (new-average (/ new-total new-count))
            )
            (map-set user-ratings { user: rated-user } {
                total-score: new-total,
                rating-count: new-count,
                average-rating: new-average,
            })
        )

        (ok true)
    )
)

(define-public (create-portfolio
        (bio (string-utf8 500))
        (skills (list 20 (string-utf8 50)))
        (portfolio-items (list 10 {
            title: (string-utf8 100),
            description: (string-utf8 300),
            project-url: (optional (string-utf8 200))
        }))
    )
    (begin
        (asserts! (is-none (get-portfolio tx-sender)) err-portfolio-exists)
        (asserts! (> (len bio) u0) err-invalid-portfolio-data)
        (asserts! (> (len skills) u0) err-invalid-portfolio-data)
        (asserts! (<= (len skills) u20) err-invalid-portfolio-data)
        (asserts! (<= (len portfolio-items) u10) err-invalid-portfolio-data)

        (map-set freelancer-portfolios { freelancer: tx-sender } {
            bio: bio,
            skills: skills,
            portfolio-items: portfolio-items,
            total-verified-skills: u0,
            profile-created-at: stacks-block-height,
        })

        (ok true)
    )
)

(define-public (update-portfolio
        (bio (string-utf8 500))
        (skills (list 20 (string-utf8 50)))
        (portfolio-items (list 10 {
            title: (string-utf8 100),
            description: (string-utf8 300),
            project-url: (optional (string-utf8 200))
        }))
    )
    (let (
            (existing-portfolio (unwrap! (get-portfolio tx-sender) err-portfolio-not-found))
        )
        (asserts! (> (len bio) u0) err-invalid-portfolio-data)
        (asserts! (> (len skills) u0) err-invalid-portfolio-data)
        (asserts! (<= (len skills) u20) err-invalid-portfolio-data)
        (asserts! (<= (len portfolio-items) u10) err-invalid-portfolio-data)

        (map-set freelancer-portfolios { freelancer: tx-sender } {
            bio: bio,
            skills: skills,
            portfolio-items: portfolio-items,
            total-verified-skills: (get total-verified-skills existing-portfolio),
            profile-created-at: (get profile-created-at existing-portfolio),
        })

        (ok true)
    )
)

(define-public (add-skill-verification
        (escrow-id uint)
        (freelancer principal)
        (skill (string-utf8 50))
        (endorsement-note (optional (string-utf8 200)))
    )
    (let (
            (escrow-data (unwrap! (get-escrow escrow-id) err-not-found))
            (portfolio-data (unwrap! (get-portfolio freelancer) err-portfolio-not-found))
            (existing-verification (map-get? skill-verifications {
                freelancer: freelancer,
                skill: skill,
                verifier: tx-sender,
            }))
            (current-count (get-skill-verification-count freelancer skill))
        )
        (asserts! (is-eq tx-sender (get client escrow-data)) err-unauthorized)
        (asserts! (is-eq freelancer (get freelancer escrow-data)) err-unauthorized)
        (asserts! (is-eq (get status escrow-data) status-completed) err-escrow-not-completed)
        (asserts! (> (len skill) u0) err-invalid-skill)
        (asserts! (<= (len skill) u50) err-invalid-skill)
        (asserts! (is-none existing-verification) err-already-verified)
        
        ;; Verify that the skill is in the freelancer's skills list
        (asserts! (is-some (index-of (get skills portfolio-data) skill)) err-invalid-skill)

        (map-set skill-verifications {
            freelancer: freelancer,
            skill: skill,
            verifier: tx-sender,
        } {
            escrow-id: escrow-id,
            verified-at: stacks-block-height,
            endorsement-note: endorsement-note,
        })

        (map-set skill-verification-counts {
            freelancer: freelancer,
            skill: skill,
        } {
            count: (+ current-count u1),
        })

        ;; Update total verified skills count in portfolio
        (if (is-eq current-count u0)
            (map-set freelancer-portfolios { freelancer: freelancer }
                (merge portfolio-data {
                    total-verified-skills: (+ (get total-verified-skills portfolio-data) u1),
                })
            )
            true
        )

        (ok true)
    )
)
