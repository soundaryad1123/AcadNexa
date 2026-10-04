-- =============================================================================
-- AcadNexa — Database Schema Specification (PostgreSQL 16+)
-- Multi-Tenant IoT-Integrated Campus Management & Academic System
-- =============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =============================================================================
-- HELPER FUNCTIONS & TRIGGERS
-- =============================================================================

-- Automatic updated_at timestamp trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = clock_timestamp();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- 1. COLLEGES (Root Multi-Tenant Entity)
-- =============================================================================
CREATE TABLE IF NOT EXISTS colleges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(63) NOT NULL UNIQUE,
    domain VARCHAR(255) UNIQUE,
    contact_email VARCHAR(255),
    subscription_tier VARCHAR(32) NOT NULL DEFAULT 'standard'
        CHECK (subscription_tier IN ('trial', 'standard', 'enterprise')),
    status VARCHAR(20) NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'suspended', 'archived')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

DROP TRIGGER IF EXISTS trg_colleges_updated_at ON colleges;
CREATE TRIGGER trg_colleges_updated_at
    BEFORE UPDATE ON colleges
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- 2. DEPARTMENTS
-- =============================================================================
CREATE TABLE IF NOT EXISTS departments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    college_id UUID NOT NULL
        REFERENCES colleges(id) ON DELETE CASCADE,
    name VARCHAR(150) NOT NULL,
    code VARCHAR(20) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT uq_departments_college_code UNIQUE (college_id, code)
);

CREATE INDEX IF NOT EXISTS idx_departments_college ON departments(college_id);

DROP TRIGGER IF EXISTS trg_departments_updated_at ON departments;
CREATE TRIGGER trg_departments_updated_at
    BEFORE UPDATE ON departments
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- 3. USERS (Students, Faculty, College Admins)
-- =============================================================================
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    college_id UUID NOT NULL
        REFERENCES colleges(id) ON DELETE CASCADE,
    department_id UUID
        REFERENCES departments(id) ON DELETE SET NULL,
    email VARCHAR(255) NOT NULL,
    password_hash TEXT NOT NULL,
    full_name VARCHAR(150) NOT NULL,
    role VARCHAR(20) NOT NULL
        CHECK (role IN ('ADMIN', 'FACULTY', 'STUDENT')),
    identifier_number VARCHAR(64),
    status VARCHAR(20) NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'inactive', 'suspended')),
    last_login_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT uq_users_college_email UNIQUE (college_id, email),
    CONSTRAINT uq_users_college_identifier UNIQUE (college_id, identifier_number)
);

CREATE INDEX IF NOT EXISTS idx_users_college_role ON users(college_id, role);
CREATE INDEX IF NOT EXISTS idx_users_college_dept ON users(college_id, department_id);

DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- 4. HARDWARE NODES (IoT RFID/NFC Readers & Class Scanners)
-- =============================================================================
CREATE TABLE IF NOT EXISTS hardware_nodes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    college_id UUID NOT NULL
        REFERENCES colleges(id) ON DELETE CASCADE,
    node_code VARCHAR(64) NOT NULL,
    name VARCHAR(128) NOT NULL,
    room_number VARCHAR(64),
    mac_address VARCHAR(32),
    api_key_hash VARCHAR(255) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'maintenance', 'offline')),
    last_heartbeat TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT uq_hardware_nodes_college_code UNIQUE (college_id, node_code)
);

CREATE INDEX IF NOT EXISTS idx_hardware_nodes_college_status ON hardware_nodes(college_id, status);

DROP TRIGGER IF EXISTS trg_hardware_nodes_updated_at ON hardware_nodes;
CREATE TRIGGER trg_hardware_nodes_updated_at
    BEFORE UPDATE ON hardware_nodes
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- 5. SMART ID PROFILES (ENT-02: RFID / NFC Tag Assignment)
-- =============================================================================
CREATE TABLE IF NOT EXISTS smart_id_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    college_id UUID NOT NULL
        REFERENCES colleges(id) ON DELETE CASCADE,
    user_id UUID NOT NULL
        REFERENCES users(id) ON DELETE CASCADE,
    card_uid VARCHAR(64) NOT NULL,
    card_type VARCHAR(32) NOT NULL DEFAULT 'MIFARE_CLASSIC',
    status VARCHAR(20) NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'suspended', 'lost', 'expired')),
    issued_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    assigned_by UUID
        REFERENCES users(id) ON DELETE SET NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT uq_smart_id_college_user UNIQUE (college_id, user_id),
    CONSTRAINT uq_smart_id_college_card UNIQUE (college_id, card_uid)
);

CREATE INDEX IF NOT EXISTS idx_smart_id_lookup ON smart_id_profiles(college_id, card_uid, status);
CREATE INDEX IF NOT EXISTS idx_smart_id_user ON smart_id_profiles(college_id, user_id);

DROP TRIGGER IF EXISTS trg_smart_id_profiles_updated_at ON smart_id_profiles;
CREATE TRIGGER trg_smart_id_profiles_updated_at
    BEFORE UPDATE ON smart_id_profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- 6. COURSES (Curriculum & Academic Subjects)
-- =============================================================================
CREATE TABLE IF NOT EXISTS courses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    college_id UUID NOT NULL
        REFERENCES colleges(id) ON DELETE CASCADE,
    department_id UUID
        REFERENCES departments(id) ON DELETE SET NULL,
    code VARCHAR(32) NOT NULL,
    name VARCHAR(255) NOT NULL,
    credits INT NOT NULL DEFAULT 3 CHECK (credits >= 0),
    semester INT NOT NULL CHECK (semester BETWEEN 1 AND 12),
    status VARCHAR(20) NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'inactive', 'archived')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT uq_courses_college_code UNIQUE (college_id, code)
);

CREATE INDEX IF NOT EXISTS idx_courses_college_dept ON courses(college_id, department_id, semester);

DROP TRIGGER IF EXISTS trg_courses_updated_at ON courses;
CREATE TRIGGER trg_courses_updated_at
    BEFORE UPDATE ON courses
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- 7. COURSE ENROLLMENTS (Student Course & Lab Batch Registrations)
-- =============================================================================
CREATE TABLE IF NOT EXISTS course_enrollments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    college_id UUID NOT NULL
        REFERENCES colleges(id) ON DELETE CASCADE,
    student_id UUID NOT NULL
        REFERENCES users(id) ON DELETE CASCADE,
    course_id UUID NOT NULL
        REFERENCES courses(id) ON DELETE CASCADE,
    batch_name VARCHAR(32) NOT NULL DEFAULT 'ALL',
    academic_year VARCHAR(32) NOT NULL,
    enrolled_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT uq_enrollments_college_student_course UNIQUE (college_id, student_id, course_id, academic_year)
);

CREATE INDEX IF NOT EXISTS idx_enrollments_student ON course_enrollments(college_id, student_id);
CREATE INDEX IF NOT EXISTS idx_enrollments_course ON course_enrollments(college_id, course_id, batch_name);

-- =============================================================================
-- 8. TIMETABLES (ENT-04: Master Theory & Lab Scheduling)
-- =============================================================================
CREATE TABLE IF NOT EXISTS timetables (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    college_id UUID NOT NULL
        REFERENCES colleges(id) ON DELETE CASCADE,
    department_id UUID
        REFERENCES departments(id) ON DELETE SET NULL,
    course_id UUID NOT NULL
        REFERENCES courses(id) ON DELETE CASCADE,
    faculty_id UUID NOT NULL
        REFERENCES users(id) ON DELETE RESTRICT,
    session_type VARCHAR(32) NOT NULL DEFAULT 'THEORY'
        CHECK (session_type IN ('THEORY', 'LAB', 'SEMINAR', 'TUTORIAL')),
    room_number VARCHAR(64) NOT NULL,
    batch_name VARCHAR(32) NOT NULL DEFAULT 'ALL',
    day_of_week INT NOT NULL
        CHECK (day_of_week BETWEEN 1 AND 7), -- 1 = Monday, 7 = Sunday
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    academic_year VARCHAR(32) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT chk_timetables_time_valid CHECK (end_time > start_time)
);

CREATE INDEX IF NOT EXISTS idx_timetables_faculty ON timetables(college_id, faculty_id, day_of_week);
CREATE INDEX IF NOT EXISTS idx_timetables_course ON timetables(college_id, course_id, batch_name);
CREATE INDEX IF NOT EXISTS idx_timetables_room ON timetables(college_id, room_number, day_of_week, start_time);

DROP TRIGGER IF EXISTS trg_timetables_updated_at ON timetables;
CREATE TRIGGER trg_timetables_updated_at
    BEFORE UPDATE ON timetables
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- 9. ATTENDANCE LOGS (ENT-03: Real-Time IoT Scans & Manual Overrides)
-- =============================================================================
CREATE TABLE IF NOT EXISTS attendance_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    college_id UUID NOT NULL
        REFERENCES colleges(id) ON DELETE CASCADE,
    user_id UUID NOT NULL
        REFERENCES users(id) ON DELETE CASCADE,
    timetable_id UUID
        REFERENCES timetables(id) ON DELETE SET NULL,
    hardware_node_id UUID
        REFERENCES hardware_nodes(id) ON DELETE SET NULL,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    source VARCHAR(32) NOT NULL DEFAULT 'IOT_SCAN'
        CHECK (source IN ('IOT_SCAN', 'MANUAL_OVERRIDE', 'MOBILE_QR')),
    status VARCHAR(20) NOT NULL DEFAULT 'PRESENT'
        CHECK (status IN ('PRESENT', 'ABSENT', 'LATE', 'EXCUSED')),
    verified_by UUID
        REFERENCES users(id) ON DELETE SET NULL,
    remarks TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

CREATE INDEX IF NOT EXISTS idx_attendance_user ON attendance_logs(college_id, user_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_attendance_timetable ON attendance_logs(college_id, timetable_id, timestamp);
CREATE INDEX IF NOT EXISTS idx_attendance_timestamp ON attendance_logs(college_id, timestamp DESC);

-- =============================================================================
-- 10. ASSESSMENT RECORDS (ENT-05: Scores, Midterms, Practicals & Evaluations)
-- =============================================================================
CREATE TABLE IF NOT EXISTS assessment_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    college_id UUID NOT NULL
        REFERENCES colleges(id) ON DELETE CASCADE,
    student_id UUID NOT NULL
        REFERENCES users(id) ON DELETE CASCADE,
    course_id UUID NOT NULL
        REFERENCES courses(id) ON DELETE CASCADE,
    timetable_id UUID
        REFERENCES timetables(id) ON DELETE SET NULL,
    assessment_type VARCHAR(32) NOT NULL
        CHECK (assessment_type IN ('MIDTERM', 'FINAL', 'LAB_VIVA', 'ASSIGNMENT', 'QUIZ', 'PROJECT')),
    assessment_name VARCHAR(128) NOT NULL,
    score NUMERIC(5,2) NOT NULL CHECK (score >= 0),
    max_score NUMERIC(5,2) NOT NULL CHECK (max_score > 0),
    evaluated_by UUID NOT NULL
        REFERENCES users(id) ON DELETE RESTRICT,
    evaluated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT chk_assessment_score_lte_max CHECK (score <= max_score)
);

CREATE INDEX IF NOT EXISTS idx_assessments_student ON assessment_records(college_id, student_id, course_id);
CREATE INDEX IF NOT EXISTS idx_assessments_course ON assessment_records(college_id, course_id, assessment_type);
CREATE INDEX IF NOT EXISTS idx_assessments_evaluator ON assessment_records(college_id, evaluated_by);

DROP TRIGGER IF EXISTS trg_assessment_records_updated_at ON assessment_records;
CREATE TRIGGER trg_assessment_records_updated_at
    BEFORE UPDATE ON assessment_records
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- 11. ALERTS (ENT-06: Broadcast Notices & Urgent Communications)
-- =============================================================================
CREATE TABLE IF NOT EXISTS alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    college_id UUID NOT NULL
        REFERENCES colleges(id) ON DELETE CASCADE,
    department_id UUID
        REFERENCES departments(id) ON DELETE SET NULL,
    author_id UUID NOT NULL
        REFERENCES users(id) ON DELETE RESTRICT,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    target_role VARCHAR(20) NOT NULL DEFAULT 'ALL'
        CHECK (target_role IN ('ALL', 'FACULTY', 'STUDENT', 'ADMIN')),
    priority VARCHAR(20) NOT NULL DEFAULT 'NORMAL'
        CHECK (priority IN ('LOW', 'NORMAL', 'HIGH', 'URGENT')),
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

CREATE INDEX IF NOT EXISTS idx_alerts_lookup ON alerts(college_id, target_role, department_id, created_at DESC);

DROP TRIGGER IF EXISTS trg_alerts_updated_at ON alerts;
CREATE TRIGGER trg_alerts_updated_at
    BEFORE UPDATE ON alerts
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- 12. ROW-LEVEL SECURITY (RLS) POLICIES
-- =============================================================================

ALTER TABLE departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE hardware_nodes ENABLE ROW LEVEL SECURITY;
ALTER TABLE smart_id_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE course_enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE timetables ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE assessment_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE alerts ENABLE ROW LEVEL SECURITY;

-- Dynamic Tenant Scoped Isolation Policies (using app.current_college_id session variable)
DO $$
DECLARE
    tbl text;
BEGIN
    FOR tbl IN
        SELECT unnest(ARRAY[
            'departments', 'users', 'hardware_nodes', 'smart_id_profiles',
            'courses', 'course_enrollments', 'timetables', 'attendance_logs',
            'assessment_records', 'alerts'
        ])
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS tenant_isolation_policy ON %I', tbl);
        EXECUTE format(
            'CREATE POLICY tenant_isolation_policy ON %I AS RESTRICTIVE USING (college_id = NULLIF(current_setting(''app.current_college_id'', true), '''')::uuid)',
            tbl
        );
    END LOOP;
END $$;
