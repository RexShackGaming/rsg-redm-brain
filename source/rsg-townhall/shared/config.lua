Config = {}

-- Database -----------------------------------------------------------------
-- true  = tables are created automatically on start
-- false = import install.sql manually
Config.AutoDatabase = true

-- Town Hall clerk (NPC) -------------------------------------------------------
-- Clerks are placed in game by an admin with /createtownhall and stored in the database.
Config.NpcModel = 'a_m_m_valtownfolk_01'
Config.NpcScenario = 'WORLD_HUMAN_STAND_WAITING' -- set to nil/false for no scenario
Config.SpawnDistance = 60.0     -- clerk spawns when the player is this close
Config.TargetDistance = 2.5     -- rsg-target interaction distance
Config.ServerDistance = 12.0    -- server only accepts Town Hall requests this close to a clerk
Config.CloseDistance = 8.0      -- UI closes automatically when the player walks further than this

-- Commands (admin placement) ---------------------------------------------------
Config.Commands = {
    create = 'createtownhall',  -- /createtownhall [name]
    remove = 'removetownhall',  -- removes the nearest clerk (within 5m)
}

-- Permissions -----------------------------------------------------------------
-- rsg-core permission level that can post/review ANY job and manage the manager list.
Config.AdminPermission = 'admin'
-- Players whose active job is a boss grade may post and review vacancies for their own job.
Config.AllowBossManagement = true
-- Only admins may post vacancies for boss grades (isboss) when true.
Config.RestrictBossGrades = true
-- Managers (the list admins maintain in the Manage tab) are an add-on for a government job.
-- Set to a job name (e.g. 'government'): manager entries only work while the player holds that job,
-- so a manager can post for every job (scope '*') or a single job without being its boss.
-- Set to false/nil: manager entries work for anyone on the list.
-- Bosses never need to be on the list: with AllowBossManagement they can post for their own job by default.
Config.ManagerJob = 'government'
-- A reviewer may never approve/reject their own application when false.
Config.AllowSelfReview = false

-- Jobs ------------------------------------------------------------------------
-- Jobs that may be posted. Empty = any job from the database (multijob_jobs).
Config.PostableJobs = {}
-- Jobs that can never be posted.
Config.BlockedJobs = { 'unemployed' }
Config.MaxOpenPostingsPerJob = 5

-- Applications ----------------------------------------------------------------
Config.MaxActiveApplications = 3     -- pending applications per player
Config.ReapplyCooldownHours = 24     -- wait after a rejection before re-applying to the same vacancy (0 = none)
Config.RequireFeedback = true        -- reviewer must write feedback for approve and reject
Config.MinFeedbackLength = 5
Config.MaxCustomQuestions = 5        -- extra questions the poster may add

-- On approval ---------------------------------------------------------------
-- Applicant must be online to be approved (the job is given immediately).
Config.BypassMaxJobs = false         -- ignore the multijob max job limit
Config.SetActiveJobOnApproval = false -- also switch the applicant's active job to the new one

-- Vacancies -----------------------------------------------------------------
Config.MaxSlots = 10                  -- seats per vacancy
-- Days a poster can pick (0 = never expires), per role. First match wins:
--   admin   : players with Config.AdminPermission
--   jobs    : per vacancy job, e.g. jobs = { police = { 7, 14 } }
--   manager : players on the manager list (Config.ManagerJob)
--   boss    : bosses posting for their own job
--   default : used when the role has no list
-- A plain list such as { 0, 3, 7, 14, 30 } is still accepted and applies to everyone.
Config.ExpiryOptions = {
    admin   = { 0, 3, 7, 14, 30, 60 },
    manager = { 3, 7, 14, 30, 60 },
    boss    = { 3, 7, 14, 30 },
    jobs    = {},
    default = { 3, 7, 14, 30 },
}
Config.DefaultExpiryDays = 14         -- used when reopening a vacancy
Config.ExpiryCheckMinutes = 5         -- how often expired vacancies are closed

-- Messages, editing, fees, blacklist, templates ---------------------------------
Config.AllowMessages = true           -- applicant and reviewers can exchange short messages while an application is open
Config.MaxMessages = 30               -- per application
Config.AllowEditApplication = true    -- applicants can change their answers while the application is still open
Config.ApplicationFee = 0             -- money taken when applying (0 = free)
Config.RefundFeeWhenClosed = true     -- refund the fee if the vacancy closes, fills or expires before a decision
Config.ApplicationFeeAccount = 'cash' -- 'cash' or 'bank'
Config.AllowBlacklist = true          -- reviewers can bar a citizen from one job (or all jobs, admins/all-job managers)
Config.MaxTemplates = 10              -- saved vacancy templates per poster
Config.ExpiryWarnHours = 24           -- warn the poster this long before a vacancy closes (0 = off)

-- Applications: extra steps ---------------------------------------------------
Config.AllowOfflineApproval = true    -- approve offline applicants; the job is granted on their next login
Config.AllowInterviews = true         -- reviewers can invite an applicant to an interview before deciding

-- Resigning ------------------------------------------------------------------
Config.AllowResign = true             -- players can resign from jobs in the "My Jobs" tab
Config.ResignCooldownHours = 24       -- wait before applying for the same job again (0 = none)

-- Prerequisites ----------------------------------------------------------------
-- Items a poster may require applicants to carry (rsg-inventory item names). Empty = no item prerequisites.
Config.PrerequisiteItems = {}
Config.MaxPrerequisiteItems = 3
Config.AllowJobPrerequisites = true   -- "must already hold job X at rank Y or higher" (promotion paths)

-- Text limits (characters) -------------------------------------------------------
Config.Limits = {
    title = 60,
    description = 1500,
    requirements = 1000,
    question = 120,
    answer = 1000,
    feedback = 600,
    label = 60,
    message = 300,
}

-- Standard application questions ------------------------------------------------
-- label = locale key. type = 'textarea' or 'text'. required defaults to true.
Config.Questions = {
    { label = 'q_why_job',     type = 'textarea', required = true,  max = 800 },
    { label = 'q_experience',  type = 'textarea', required = true,  max = 800 },
    { label = 'q_background',  type = 'textarea', required = false, max = 800 },
    { label = 'q_availability', type = 'text',    required = true,  max = 200 },
}

-- Push-to-talk ----------------------------------------------------------------
-- While the UI is open, game controls are blocked but push-to-talk still works.
Config.AllowPushToTalkWhileOpen = true
Config.PushToTalkControls = {
    0x4BC9DABB, -- INPUT_PUSH_TO_TALK
}
