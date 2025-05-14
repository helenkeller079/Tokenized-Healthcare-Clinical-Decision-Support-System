;; Treatment Protocol Contract
;; Records evidence-based guidelines for medical treatments

(define-data-var admin principal tx-sender)

;; Protocol definitions
(define-map protocols
  { protocol-id: uint }
  {
    name: (string-utf8 64),
    condition: (string-utf8 64),
    version: uint,
    hash: (buff 32),
    creator: principal,
    creation-date: uint,
    status: uint,  ;; 0 = draft, 1 = active, 2 = deprecated
    evidence-level: uint  ;; 1-5 scale (5 being highest)
  }
)

;; Protocol steps
(define-map protocol-steps
  { protocol-id: uint, step-id: uint }
  {
    description: (string-utf8 256),
    order: uint,
    optional: bool,
    condition-logic: (string-utf8 128)
  }
)

;; Protocol endorsements
(define-map protocol-endorsements
  { protocol-id: uint, endorser: principal }
  {
    timestamp: uint,
    comments: (string-utf8 256)
  }
)

;; Protocol counter
(define-data-var protocol-counter uint u0)

;; Check if caller is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Create a new protocol
(define-public (create-protocol
    (name (string-utf8 64))
    (condition (string-utf8 64))
    (hash (buff 32))
    (evidence-level uint))
  (let ((new-id (+ (var-get protocol-counter) u1)))
    (asserts! (<= u1 evidence-level) (err u2))
    (asserts! (>= u5 evidence-level) (err u3))

    (var-set protocol-counter new-id)
    (map-set protocols
      {protocol-id: new-id}
      {
        name: name,
        condition: condition,
        version: u1,
        hash: hash,
        creator: tx-sender,
        creation-date: block-height,
        status: u0,  ;; draft by default
        evidence-level: evidence-level
      }
    )
    (ok new-id)
  )
)

;; Add a step to a protocol
(define-public (add-protocol-step
    (protocol-id uint)
    (description (string-utf8 256))
    (order uint)
    (optional bool)
    (condition-logic (string-utf8 128)))
  (let ((protocol (map-get? protocols {protocol-id: protocol-id})))
    (asserts! (is-some protocol) (err u404))
    (asserts! (is-eq (get creator (default-to {creator: tx-sender} protocol)) tx-sender) (err u403))
    (asserts! (is-eq (get status (default-to {status: u1} protocol)) u0) (err u400))

    (map-set protocol-steps
      {protocol-id: protocol-id, step-id: order}
      {
        description: description,
        order: order,
        optional: optional,
        condition-logic: condition-logic
      }
    )
    (ok true)
  )
)

;; Activate a protocol (admin or creator)
(define-public (activate-protocol (protocol-id uint))
  (let ((protocol (map-get? protocols {protocol-id: protocol-id})))
    (asserts! (is-some protocol) (err u404))
    (asserts! (or (is-admin)
                 (is-eq (get creator (default-to {creator: tx-sender} protocol)) tx-sender))
             (err u403))

    (map-set protocols
      {protocol-id: protocol-id}
      (merge (unwrap! protocol (err u404))
             {status: u1})
    )
    (ok true)
  )
)

;; Deprecate a protocol (admin or creator)
(define-public (deprecate-protocol (protocol-id uint))
  (let ((protocol (map-get? protocols {protocol-id: protocol-id})))
    (asserts! (is-some protocol) (err u404))
    (asserts! (or (is-admin)
                 (is-eq (get creator (default-to {creator: tx-sender} protocol)) tx-sender))
             (err u403))

    (map-set protocols
      {protocol-id: protocol-id}
      (merge (unwrap! protocol (err u404))
             {status: u2})
    )
    (ok true)
  )
)

;; Create a new version of a protocol
(define-public (create-protocol-version
    (protocol-id uint)
    (name (string-utf8 64))
    (condition (string-utf8 64))
    (hash (buff 32))
    (evidence-level uint))
  (let ((protocol (map-get? protocols {protocol-id: protocol-id}))
        (new-id (+ (var-get protocol-counter) u1)))
    (asserts! (is-some protocol) (err u404))
    (asserts! (or (is-admin)
                 (is-eq (get creator (default-to {creator: tx-sender} protocol)) tx-sender))
             (err u403))
    (asserts! (<= u1 evidence-level) (err u2))
    (asserts! (>= u5 evidence-level) (err u3))

    (var-set protocol-counter new-id)
    (map-set protocols
      {protocol-id: new-id}
      {
        name: name,
        condition: condition,
        version: (+ (get version (default-to {version: u0} protocol)) u1),
        hash: hash,
        creator: tx-sender,
        creation-date: block-height,
        status: u0,  ;; draft by default
        evidence-level: evidence-level
      }
    )
    (ok new-id)
  )
)

;; Endorse a protocol
(define-public (endorse-protocol
    (protocol-id uint)
    (comments (string-utf8 256)))
  (let ((protocol (map-get? protocols {protocol-id: protocol-id})))
    (asserts! (is-some protocol) (err u404))
    (asserts! (is-eq (get status (default-to {status: u0} protocol)) u1) (err u400))

    (map-set protocol-endorsements
      {protocol-id: protocol-id, endorser: tx-sender}
      {
        timestamp: block-height,
        comments: comments
      }
    )
    (ok true)
  )
)

;; Get protocol details
(define-read-only (get-protocol (protocol-id uint))
  (map-get? protocols {protocol-id: protocol-id})
)

;; Get protocol step
(define-read-only (get-protocol-step (protocol-id uint) (step-id uint))
  (map-get? protocol-steps {protocol-id: protocol-id, step-id: step-id})
)

;; Check if protocol is endorsed by a specific provider
(define-read-only (is-protocol-endorsed (protocol-id uint) (endorser principal))
  (is-some (map-get? protocol-endorsements {protocol-id: protocol-id, endorser: endorser}))
)

;; Transfer admin rights (admin only)
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err u403))
    (var-set admin new-admin)
    (ok true)
  )
)
