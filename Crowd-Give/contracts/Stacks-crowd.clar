
;; Community Crowdfunding Platform Smart Contract
;; A decentralized platform enabling users to create fundraising campaigns
;; and receive peer-to-peer donations with transparent fee management.
;; Features include campaign lifecycle management, automatic fee collection,
;; donation tracking, and administrative controls for platform governance.

;;  ERROR CONSTANTS 
(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-CAMPAIGN-DOES-NOT-EXIST (err u101))
(define-constant ERR-CAMPAIGN-HAS-EXPIRED (err u102))
(define-constant ERR-INVALID-DONATION-AMOUNT (err u103))
(define-constant ERR-INVALID-CAMPAIGN-DURATION (err u104))
(define-constant ERR-CANNOT-DONATE-TO-OWN-CAMPAIGN (err u105))
(define-constant ERR-CAMPAIGN-ALREADY-INACTIVE (err u106))
(define-constant ERR-INSUFFICIENT-CONTRACT-BALANCE (err u107))
(define-constant ERR-STX-TRANSFER-FAILED (err u108))
(define-constant ERR-INVALID-TARGET-AMOUNT (err u109))
(define-constant ERR-INVALID-FEE-RATE (err u110))

;;  PLATFORM CONSTANTS 
(define-constant platform-administrator tx-sender)
(define-constant maximum-fee-rate-basis-points u1000) ;; 10% maximum
(define-constant minimum-campaign-duration-blocks u144) ;; ~1 day
(define-constant maximum-campaign-duration-blocks u144000) ;; ~100 days
(define-constant basis-points-denominator u10000)

;;  DATA VARIABLES 
(define-data-var next-campaign-identifier uint u1)
(define-data-var platform-fee-rate-basis-points uint u250) ;; 2.5%
(define-data-var total-platform-donations-received uint u0)
(define-data-var total-active-campaigns uint u0)

;;  DATA MAPS 

;; Primary campaign storage
(define-map fundraising-campaigns
  { campaign-identifier: uint }
  {
    campaign-creator: principal,
    campaign-title: (string-ascii 64),
    campaign-description: (string-ascii 256),
    fundraising-target-amount: uint,
    current-raised-amount: uint,
    campaign-end-block-height: uint,
    campaign-is-currently-active: bool,
    campaign-creation-block-height: uint,
    total-number-of-donors: uint
  }
)

;; Individual donation records
(define-map individual-donation-records
  { campaign-identifier: uint, donor-principal: principal }
  {
    total-donated-amount: uint,
    last-donation-block-height: uint,
    number-of-donations: uint
  }
)

;; Aggregated user statistics per campaign
(define-map donor-campaign-contribution-totals
  { campaign-identifier: uint, donor-principal: principal }
  uint
)

;; Campaign creator statistics
(define-map creator-campaign-statistics
  principal
  {
    total-campaigns-created: uint,
    total-amount-raised-across-campaigns: uint,
    active-campaigns-count: uint
  }
)

;;  UTILITY FUNCTIONS 

;; Calculate platform fee from donation amount
(define-private (compute-platform-fee-amount (donation-amount uint))
  (/ (* donation-amount (var-get platform-fee-rate-basis-points)) basis-points-denominator)
)
;; Calculate net amount after platform fee deduction
(define-private (compute-net-donation-amount (donation-amount uint))
  (- donation-amount (compute-platform-fee-amount donation-amount))
)

;; Check if current block height is within campaign duration
(define-private (is-campaign-currently-active (campaign-identifier uint))
  (match (map-get? fundraising-campaigns { campaign-identifier: campaign-identifier })
    campaign-details (and 
      (get campaign-is-currently-active campaign-details)
      (<= stacks-block-height (get campaign-end-block-height campaign-details))
    )
    false
  )
)

;; Update donor's total contribution to specific campaign
(define-private (update-donor-campaign-total (campaign-identifier uint) (donor-principal principal) (additional-amount uint))
  (let ((current-total (get-donor-campaign-total campaign-identifier donor-principal)))
    (map-set donor-campaign-contribution-totals 
      { campaign-identifier: campaign-identifier, donor-principal: donor-principal }
      (+ current-total additional-amount)
    )
  )
)

;; Update creator statistics
(define-private (update-creator-statistics (creator-principal principal) (amount-raised uint) (is-new-campaign bool))
  (let ((current-stats (get-creator-statistics creator-principal)))
    (map-set creator-campaign-statistics
      creator-principal
      {
        total-campaigns-created: (+ (get total-campaigns-created current-stats) (if is-new-campaign u1 u0)),
        total-amount-raised-across-campaigns: (+ (get total-amount-raised-across-campaigns current-stats) amount-raised),
        active-campaigns-count: (get active-campaigns-count current-stats)
      }
    )
  )
)

;;  READ-ONLY FUNCTIONS 

;; Retrieve complete campaign information
(define-read-only (get-campaign-details (campaign-identifier uint))
  (map-get? fundraising-campaigns { campaign-identifier: campaign-identifier })
)

;; Get donor's contribution record for specific campaign
(define-read-only (get-donation-record (campaign-identifier uint) (donor-principal principal))
  (map-get? individual-donation-records { campaign-identifier: campaign-identifier, donor-principal: donor-principal })
)

;; Get donor's total contribution to campaign
(define-read-only (get-donor-campaign-total (campaign-identifier uint) (donor-principal principal))
  (default-to u0 (map-get? donor-campaign-contribution-totals 
    { campaign-identifier: campaign-identifier, donor-principal: donor-principal }))
)

;; Get creator's overall statistics
(define-read-only (get-creator-statistics (creator-principal principal))
  (default-to 
    { total-campaigns-created: u0, total-amount-raised-across-campaigns: u0, active-campaigns-count: u0 }
    (map-get? creator-campaign-statistics creator-principal)
  )
)

;; Get current platform metrics
(define-read-only (get-platform-metrics)
  {
    next-campaign-id: (var-get next-campaign-identifier),
    current-fee-rate: (var-get platform-fee-rate-basis-points),
    total-donations: (var-get total-platform-donations-received),
    active-campaigns: (var-get total-active-campaigns),
    contract-balance: (stx-get-balance (as-contract tx-sender)),
    current-block-height: stacks-block-height
  }
)

;; Calculate fees for given amount
(define-read-only (calculate-donation-breakdown (donation-amount uint))
  (let ((platform-fee (compute-platform-fee-amount donation-amount)))
    {
      gross-donation: donation-amount,
      platform-fee: platform-fee,
      net-to-creator: (- donation-amount platform-fee),
      fee-rate-basis-points: (var-get platform-fee-rate-basis-points)
    }
  )
)

;; Check campaign status and eligibility
(define-read-only (get-campaign-status (campaign-identifier uint))
  (match (get-campaign-details campaign-identifier)
    campaign-details 
    {
      exists: true,
      is-active: (is-campaign-currently-active campaign-identifier),
      time-remaining: (if (> (get campaign-end-block-height campaign-details) stacks-block-height)
                         (- (get campaign-end-block-height campaign-details) stacks-block-height)
                         u0),
      funding-progress: (if (> (get fundraising-target-amount campaign-details) u0)
                           (/ (* (get current-raised-amount campaign-details) u100) 
                              (get fundraising-target-amount campaign-details))
                           u0)
    }
    { exists: false, is-active: false, time-remaining: u0, funding-progress: u0 }
  )
)

;; Get current Stacks block height
(define-read-only (get-current-block-height)
  stacks-block-height
)

;;  CAMPAIGN MANAGEMENT FUNCTIONS 

;; Create new fundraising campaign
(define-public (launch-fundraising-campaign 
  (campaign-title (string-ascii 64))
  (campaign-description (string-ascii 256))
  (fundraising-target-amount uint)
  (campaign-duration-blocks uint)
)
  (let (
    (new-campaign-identifier (var-get next-campaign-identifier))
    (campaign-end-block-height (+ stacks-block-height campaign-duration-blocks))
    (current-creator-stats (get-creator-statistics tx-sender))
  )
    ;; Input validation
    (asserts! (> fundraising-target-amount u0) ERR-INVALID-TARGET-AMOUNT)
    (asserts! (>= campaign-duration-blocks minimum-campaign-duration-blocks) ERR-INVALID-CAMPAIGN-DURATION)
    (asserts! (<= campaign-duration-blocks maximum-campaign-duration-blocks) ERR-INVALID-CAMPAIGN-DURATION)
    
    ;; Create campaign record
    (map-set fundraising-campaigns
      { campaign-identifier: new-campaign-identifier }
      {
        campaign-creator: tx-sender,
        campaign-title: campaign-title,
        campaign-description: campaign-description,
        fundraising-target-amount: fundraising-target-amount,
        current-raised-amount: u0,
        campaign-end-block-height: campaign-end-block-height,
        campaign-is-currently-active: true,
        campaign-creation-block-height: stacks-block-height,
        total-number-of-donors: u0
      }
    )
    
    ;; Update platform counters
    (var-set next-campaign-identifier (+ new-campaign-identifier u1))
    (var-set total-active-campaigns (+ (var-get total-active-campaigns) u1))
    
    ;; Update creator statistics
    (update-creator-statistics tx-sender u0 true)
    
    (ok new-campaign-identifier)
  )
)

;; Deactivate campaign (creator only)
(define-public (deactivate-campaign (campaign-identifier uint))
  (let ((campaign-details (unwrap! (get-campaign-details campaign-identifier) ERR-CAMPAIGN-DOES-NOT-EXIST)))
    ;; Authorization check
    (asserts! (is-eq tx-sender (get campaign-creator campaign-details)) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (get campaign-is-currently-active campaign-details) ERR-CAMPAIGN-ALREADY-INACTIVE)
    
    ;; Deactivate campaign
    (map-set fundraising-campaigns
      { campaign-identifier: campaign-identifier }
      (merge campaign-details { campaign-is-currently-active: false })
    )
    
    ;; Update active campaigns counter
    (var-set total-active-campaigns (- (var-get total-active-campaigns) u1))
    
    (ok true)
  )
)

;;  DONATION FUNCTIONS 

;; Process donation to campaign
(define-public (contribute-to-campaign (campaign-identifier uint) (donation-amount uint))
  (let (
    (campaign-details (unwrap! (get-campaign-details campaign-identifier) ERR-CAMPAIGN-DOES-NOT-EXIST))
    (platform-fee-amount (compute-platform-fee-amount donation-amount))
    (net-donation-amount (compute-net-donation-amount donation-amount))
    (campaign-creator (get campaign-creator campaign-details))
    (current-raised-amount (get current-raised-amount campaign-details))
    (existing-donation-record (get-donation-record campaign-identifier tx-sender))
  )
    ;; Validation checks
    (asserts! (> donation-amount u0) ERR-INVALID-DONATION-AMOUNT)
    (asserts! (is-campaign-currently-active campaign-identifier) ERR-CAMPAIGN-HAS-EXPIRED)
    (asserts! (not (is-eq tx-sender campaign-creator)) ERR-CANNOT-DONATE-TO-OWN-CAMPAIGN)
    
    ;; Execute STX transfers
    (unwrap! (stx-transfer? donation-amount tx-sender (as-contract tx-sender)) ERR-STX-TRANSFER-FAILED)
    (unwrap! (as-contract (stx-transfer? net-donation-amount tx-sender campaign-creator)) ERR-STX-TRANSFER-FAILED)
    
    ;; Update campaign raised amount and donor count
    (map-set fundraising-campaigns
      { campaign-identifier: campaign-identifier }
      (merge campaign-details { 
        current-raised-amount: (+ current-raised-amount net-donation-amount),
        total-number-of-donors: (if (is-none existing-donation-record)
                                   (+ (get total-number-of-donors campaign-details) u1)
                                   (get total-number-of-donors campaign-details))
      })
    )
    
    ;; Update or create donation record
    (map-set individual-donation-records
      { campaign-identifier: campaign-identifier, donor-principal: tx-sender }
      (match existing-donation-record
        existing-record {
          total-donated-amount: (+ (get total-donated-amount existing-record) donation-amount),
          last-donation-block-height: stacks-block-height,
          number-of-donations: (+ (get number-of-donations existing-record) u1)
        }
        {
          total-donated-amount: donation-amount,
          last-donation-block-height: stacks-block-height,
          number-of-donations: u1
        }
      )
    )
    
    ;; Update aggregated totals
    (update-donor-campaign-total campaign-identifier tx-sender donation-amount)
    (update-creator-statistics campaign-creator net-donation-amount false)
    
    ;; Update platform metrics
    (var-set total-platform-donations-received (+ (var-get total-platform-donations-received) donation-amount))
    
    (ok { 
      donation-processed: donation-amount, 
      amount-to-creator: net-donation-amount, 
      platform-fee-collected: platform-fee-amount,
      new-campaign-total: (+ current-raised-amount net-donation-amount)
    })
  )
)

;;  ADMINISTRATIVE FUNCTIONS 

;; Withdraw accumulated platform fees
(define-public (withdraw-platform-fees (withdrawal-amount uint))
  (begin
    (asserts! (is-eq tx-sender platform-administrator) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (<= withdrawal-amount (stx-get-balance (as-contract tx-sender))) ERR-INSUFFICIENT-CONTRACT-BALANCE)
    
    (unwrap! (as-contract (stx-transfer? withdrawal-amount tx-sender platform-administrator)) ERR-STX-TRANSFER-FAILED)
    (ok withdrawal-amount)
  )
)

;; Update platform fee rate
(define-public (update-platform-fee-rate (new-fee-rate-basis-points uint))
  (begin
    (asserts! (is-eq tx-sender platform-administrator) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (<= new-fee-rate-basis-points maximum-fee-rate-basis-points) ERR-INVALID-FEE-RATE)
    
    (var-set platform-fee-rate-basis-points new-fee-rate-basis-points)
    (ok new-fee-rate-basis-points)
  )
)

;; Emergency campaign control
(define-public (emergency-toggle-campaign (campaign-identifier uint))
  (let ((campaign-details (unwrap! (get-campaign-details campaign-identifier) ERR-CAMPAIGN-DOES-NOT-EXIST)))
    (asserts! (is-eq tx-sender platform-administrator) ERR-UNAUTHORIZED-ACCESS)
    
    (let ((new-status (not (get campaign-is-currently-active campaign-details))))
      (map-set fundraising-campaigns
        { campaign-identifier: campaign-identifier }
        (merge campaign-details { campaign-is-currently-active: new-status })
      )
      
      ;; Update active campaigns counter
      (var-set total-active-campaigns 
        (if new-status 
          (+ (var-get total-active-campaigns) u1)
          (- (var-get total-active-campaigns) u1)
        )
      )
      
      (ok new-status)
    )
  )
)