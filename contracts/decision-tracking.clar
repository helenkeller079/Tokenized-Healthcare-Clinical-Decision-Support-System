;; Decision Tracking Contract
;; Records clinical choices and decision-making processes

(define-data-var admin principal tx-sender)

;; Clinical decisions
(define-map clinical-decisions
  { decision-id: uint }
  {
    patient-id: principal,
    provider-id: principal,
    protocol-id: uint,
    timestamp: uint,
    decision-hash: (buff 32),
    rationale: (string-utf8 256),
    deviation-reason: (optional (string-utf8 256))
  }
)

;; Decision counter
(define-data-var decision-counter uint u0)

;; Decision steps
(define-map decision-steps
  { decision-id: uint, step-id: uint }
  {
    protocol-step-id: uint,
    completed: bool,
    timestamp: uint,
    notes: (string-utf8 256)
  }
)

;; Check if caller is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Record a clinical decision
(define-public (record-decision
    (patient-id principal)
    (protocol-id uint)
    (decision-hash (buff 32))
    (rationale (string-utf8 256))
    (deviation-reason (optional (string-utf8 256))))
  (let ((new-id (+ (var-get decision-counter) u1)))
    ;; Note: In a real implementation, we would check if the provider has access to the patient data
    ;; and if the protocol exists and is active

    (var-set decision-counter new-id)
    (map-set clinical-decisions
      {decision-id: new-id}
      {
        patient-id: patient-id,
        provider-id: tx-sender,
        protocol-id: protocol-id,
        timestamp: block-height,
        decision-hash: decision-hash,
        rationale: rationale,
        deviation-reason: deviation-reason
      }
    )
    (ok new-id)
  )
)

;; Record a decision step
(define-public (record-decision-step
    (decision-id uint)
    (protocol-step-id uint)
    (completed bool)
    (notes (string-utf8 256)))
  (let ((decision (map-get? clinical-decisions {decision-id: decision-id})))
    (asserts! (is-some decision) (err u404))
    (asserts! (is-eq (get provider-id (default-to {provider-id: tx-sender} decision)) tx-sender) (err u403))

    (map-set decision-steps
      {decision-id: decision-id, step-id: protocol-step-id}
      {
        protocol-step-id: protocol-step-id,
        completed: completed,
        timestamp: block-height,
        notes: notes
      }
    )
    (ok true)
  )
)

;; Update a decision step
(define-public (update-decision-step
    (decision-id uint)
    (step-id uint)
    (completed bool)
    (notes (string-utf8 256)))
  (let ((decision (map-get? clinical-decisions {decision-id: decision-id}))
        (step (map-get? decision-steps {decision-id: decision-id, step-id: step-id})))
    (asserts! (is-some decision) (err u404))
    (asserts! (is-some step) (err u404))
    (asserts! (is-eq (get provider-id (default-to {provider-id: tx-sender} decision)) tx-sender) (err u403))

    (map-set decision-steps
      {decision-id: decision-id, step-id: step-id}
      (merge (unwrap! step (err u404))
             {
               completed: completed,
               timestamp: block-height,
               notes: notes
             })
    )
    (ok true)
  )
)

;; Get decision details
(define-read-only (get-decision (decision-id uint))
  (map-get? clinical-decisions {decision-id: decision-id})
)

;; Get decision step
(define-read-only (get-decision-step (decision-id uint) (step-id uint))
  (map-get? decision-steps {decision-id: decision-id, step-id: step-id})
)

;; Get decisions for a patient
(define-read-only (get-patient-decisions (patient-id principal))
  ;; Note: In a real implementation, we would need to iterate through all decisions
  ;; or use an index to find decisions for a specific patient
  ;; This is a simplified version that doesn't actually return all decisions
  (map-get? clinical-decisions {decision-id: u0})
)

;; Get decisions by a provider
(define-read-only (get-provider-decisions (provider-id principal))
  ;; Note: In a real implementation, we would need to iterate through all decisions
  ;; or use an index to find decisions by a specific provider
  ;; This is a simplified version that doesn't actually return all decisions
  (map-get? clinical-decisions {decision-id: u0})
)

;; Transfer admin rights (admin only)
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err u403))
    (var-set admin new-admin)
    (ok true)
  )
)
