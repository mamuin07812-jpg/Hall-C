-- Candidate additive D1 migration for the registration OTP proof flow.
-- Apply only after reviewing the production D1 schema and explicit authorization.
-- Existing OTP challenges remain legacy-compatible with purpose = NULL.
ALTER TABLE otp_challenges
ADD COLUMN purpose TEXT
CHECK (purpose IS NULL OR purpose IN ('student.register', 'teacher.register'));
