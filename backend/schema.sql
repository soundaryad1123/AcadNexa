-- =============================================================================
-- AcadNexa — Database Schema Specification (PostgreSQL 16+)
-- Multi-Tenant Campus Management & Academic System
-- Target Database: postgres > acadnexa_db > schemas > public
-- =============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =============================================================================
-- 1. HELPER FUNCTIONS & TRIGGERS
-- =============================================================================

-- Automatic updated_at timestamp trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = clock_timestamp();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop legacy IoT & Smart ID card tables if they exist
DROP TABLE IF EXISTS hardware_nodes CASCADE;
DROP TABLE IF EXISTS smart_id_profiles CASCADE;
DROP TABLE IF EXISTS tenants CASCADE;


-- =============================================================================
-- 2. COLLEGES (Root Multi-Tenant Entity)
-- =============================================================================
CREATE TABLE IF NOT EXISTS colleges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    code VARCHAR(32) NOT NULL UNIQUE,
    slug VARCHAR(64) NOT NULL UNIQUE,
    domain VARCHAR(255) UNIQUE,
    contact_email VARCHAR(255) NOT NULL,
    contact_phone VARCHAR(32),
    address TEXT,
    subscription_tier VARCHAR(32) NOT NULL DEFAULT 'enterprise'
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
-- 3. DEPARTMENTS
-- =============================================================================
CREATE TABLE IF NOT EXISTS departments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    college_id UUID NOT NULL
        REFERENCES colleges(id) ON DELETE CASCADE,
    name VARCHAR(150) NOT NULL,
    code VARCHAR(20) NOT NULL,
    head_of_department VARCHAR(150),
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
-- 4. USERS (Master Authentication & User Accounts)
-- =============================================================================
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    college_id UUID NOT NULL
        REFERENCES colleges(id) ON DELETE CASCADE,
    department_id UUID
        REFERENCES departments(id) ON DELETE SET NULL,
    email VARCHAR(255) NOT NULL,
    password_hash TEXT NOT NULL DEFAULT crypt('Password@123', gen_salt('bf')),
    full_name VARCHAR(150) NOT NULL,
    phone_number VARCHAR(32),
    role VARCHAR(20) NOT NULL
        CHECK (role IN ('ADMIN', 'FACULTY', 'STUDENT')),
    status VARCHAR(20) NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'inactive', 'suspended')),
    avatar_url TEXT,
    last_login_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT uq_users_college_email UNIQUE (college_id, email)
);

CREATE INDEX IF NOT EXISTS idx_users_college_role ON users(college_id, role);
CREATE INDEX IF NOT EXISTS idx_users_college_dept ON users(college_id, department_id);

DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- 5. ADMINS (College Administrative Profiles)
-- =============================================================================
CREATE TABLE IF NOT EXISTS admins (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE
        REFERENCES users(id) ON DELETE CASCADE,
    college_id UUID NOT NULL
        REFERENCES colleges(id) ON DELETE CASCADE,
    admin_level VARCHAR(32) NOT NULL DEFAULT 'SUPER_ADMIN'
        CHECK (admin_level IN ('SUPER_ADMIN', 'DEAN', 'REGISTRAR', 'HOD')),
    office_location VARCHAR(128),
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

CREATE INDEX IF NOT EXISTS idx_admins_college ON admins(college_id);

-- =============================================================================
-- 6. FACULTY (Professors, Instructors & Staff Profiles)
-- =============================================================================
CREATE TABLE IF NOT EXISTS faculty (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE
        REFERENCES users(id) ON DELETE CASCADE,
    college_id UUID NOT NULL
        REFERENCES colleges(id) ON DELETE CASCADE,
    department_id UUID NOT NULL
        REFERENCES departments(id) ON DELETE CASCADE,
    employee_code VARCHAR(64) NOT NULL,
    designation VARCHAR(100) NOT NULL,
    qualification VARCHAR(150),
    specialization VARCHAR(255),
    cabin_room VARCHAR(64),
    hire_date DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT uq_faculty_college_code UNIQUE (college_id, employee_code)
);

CREATE INDEX IF NOT EXISTS idx_faculty_college_dept ON faculty(college_id, department_id);

DROP TRIGGER IF EXISTS trg_faculty_updated_at ON faculty;
CREATE TRIGGER trg_faculty_updated_at
    BEFORE UPDATE ON faculty
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- 7. STUDENTS (Enrolled Student Profiles & Academics)
-- =============================================================================
CREATE TABLE IF NOT EXISTS students (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE
        REFERENCES users(id) ON DELETE CASCADE,
    college_id UUID NOT NULL
        REFERENCES colleges(id) ON DELETE CASCADE,
    department_id UUID NOT NULL
        REFERENCES departments(id) ON DELETE CASCADE,
    roll_number VARCHAR(64) NOT NULL,
    registration_no VARCHAR(64) NOT NULL,
    current_semester INT NOT NULL CHECK (current_semester BETWEEN 1 AND 12),
    current_year INT NOT NULL CHECK (current_year BETWEEN 1 AND 6),
    section VARCHAR(10) NOT NULL DEFAULT 'A',
    batch_year VARCHAR(32) NOT NULL DEFAULT '2023-2027',
    cgpa NUMERIC(4,2) DEFAULT 8.50 CHECK (cgpa >= 0.0 AND cgpa <= 10.0),
    admission_date DATE NOT NULL DEFAULT CURRENT_DATE,
    guardian_name VARCHAR(150),
    guardian_phone VARCHAR(32),
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT uq_students_college_roll UNIQUE (college_id, roll_number),
    CONSTRAINT uq_students_college_regno UNIQUE (college_id, registration_no)
);

CREATE INDEX IF NOT EXISTS idx_students_college_dept ON students(college_id, department_id, current_semester);

DROP TRIGGER IF EXISTS trg_students_updated_at ON students;
CREATE TRIGGER trg_students_updated_at
    BEFORE UPDATE ON students
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- 8. COURSES (Curriculum Subjects)
-- =============================================================================
CREATE TABLE IF NOT EXISTS courses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    college_id UUID NOT NULL
        REFERENCES colleges(id) ON DELETE CASCADE,
    department_id UUID NOT NULL
        REFERENCES departments(id) ON DELETE CASCADE,
    code VARCHAR(32) NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    credits INT NOT NULL DEFAULT 3 CHECK (credits >= 0),
    semester INT NOT NULL CHECK (semester BETWEEN 1 AND 12),
    course_type VARCHAR(32) NOT NULL DEFAULT 'CORE'
        CHECK (course_type IN ('CORE', 'ELECTIVE', 'LAB', 'PROJECT')),
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
-- 9. COURSE ENROLLMENTS (Student Course Registrations)
-- =============================================================================
CREATE TABLE IF NOT EXISTS course_enrollments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    college_id UUID NOT NULL
        REFERENCES colleges(id) ON DELETE CASCADE,
    student_id UUID NOT NULL
        REFERENCES students(id) ON DELETE CASCADE,
    course_id UUID NOT NULL
        REFERENCES courses(id) ON DELETE CASCADE,
    semester INT NOT NULL,
    academic_year VARCHAR(32) NOT NULL DEFAULT '2025-2026',
    enrolled_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    status VARCHAR(20) NOT NULL DEFAULT 'ENROLLED'
        CHECK (status IN ('ENROLLED', 'DROPPED', 'COMPLETED')),
    CONSTRAINT uq_enrollments_student_course_year UNIQUE (student_id, course_id, academic_year)
);

CREATE INDEX IF NOT EXISTS idx_enrollments_student ON course_enrollments(student_id);
CREATE INDEX IF NOT EXISTS idx_enrollments_course ON course_enrollments(course_id);

-- =============================================================================
-- 10. COURSE MATERIALS (Notes, Slides, Syllabus, Lab Manuals)
-- =============================================================================
CREATE TABLE IF NOT EXISTS course_materials (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    college_id UUID NOT NULL
        REFERENCES colleges(id) ON DELETE CASCADE,
    course_id UUID NOT NULL
        REFERENCES courses(id) ON DELETE CASCADE,
    uploaded_by UUID NOT NULL
        REFERENCES users(id) ON DELETE RESTRICT,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    material_type VARCHAR(32) NOT NULL DEFAULT 'PDF'
        CHECK (material_type IN ('PDF', 'SLIDES', 'ASSIGNMENT', 'LAB_MANUAL', 'VIDEO', 'SYLLABUS')),
    file_url TEXT NOT NULL,
    file_size_kb INT DEFAULT 2048,
    unit_module INT DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

CREATE INDEX IF NOT EXISTS idx_materials_course ON course_materials(course_id);

DROP TRIGGER IF EXISTS trg_course_materials_updated_at ON course_materials;
CREATE TRIGGER trg_course_materials_updated_at
    BEFORE UPDATE ON course_materials
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- 11. ACADEMIC CALENDAR (Exams, Events, Holidays, Semesters)
-- =============================================================================
CREATE TABLE IF NOT EXISTS academic_calendar (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    college_id UUID NOT NULL
        REFERENCES colleges(id) ON DELETE CASCADE,
    event_title VARCHAR(255) NOT NULL,
    event_type VARCHAR(32) NOT NULL
        CHECK (event_type IN ('EXAM', 'HOLIDAY', 'FESTIVAL', 'WORKSHOP', 'ADMISSION', 'SEMESTER_START', 'SEMESTER_END', 'RESULT')),
    description TEXT,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    is_holiday BOOLEAN NOT NULL DEFAULT false,
    target_audience VARCHAR(32) NOT NULL DEFAULT 'ALL'
        CHECK (target_audience IN ('ALL', 'STUDENTS', 'FACULTY')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT chk_calendar_dates CHECK (end_date >= start_date)
);

CREATE INDEX IF NOT EXISTS idx_calendar_dates ON academic_calendar(college_id, start_date, end_date);

-- =============================================================================
-- 12. ANNOUNCEMENTS (Broadcast Notices & Alerts)
-- =============================================================================
CREATE TABLE IF NOT EXISTS announcements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    college_id UUID NOT NULL
        REFERENCES colleges(id) ON DELETE CASCADE,
    department_id UUID
        REFERENCES departments(id) ON DELETE SET NULL,
    author_id UUID NOT NULL
        REFERENCES users(id) ON DELETE RESTRICT,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    category VARCHAR(32) NOT NULL DEFAULT 'GENERAL'
        CHECK (category IN ('GENERAL', 'ACADEMIC', 'EXAM', 'EVENT', 'PLACEMENT', 'URGENT')),
    target_role VARCHAR(20) NOT NULL DEFAULT 'ALL'
        CHECK (target_role IN ('ALL', 'FACULTY', 'STUDENT', 'ADMIN')),
    priority VARCHAR(20) NOT NULL DEFAULT 'NORMAL'
        CHECK (priority IN ('LOW', 'NORMAL', 'HIGH', 'URGENT')),
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

CREATE INDEX IF NOT EXISTS idx_announcements_target ON announcements(college_id, target_role, created_at DESC);

DROP TRIGGER IF EXISTS trg_announcements_updated_at ON announcements;
CREATE TRIGGER trg_announcements_updated_at
    BEFORE UPDATE ON announcements
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- 13. TIMETABLE (Master Class & Lab Scheduling)
-- =============================================================================
CREATE TABLE IF NOT EXISTS timetable (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    college_id UUID NOT NULL
        REFERENCES colleges(id) ON DELETE CASCADE,
    department_id UUID NOT NULL
        REFERENCES departments(id) ON DELETE CASCADE,
    course_id UUID NOT NULL
        REFERENCES courses(id) ON DELETE CASCADE,
    faculty_id UUID NOT NULL
        REFERENCES faculty(id) ON DELETE RESTRICT,
    day_of_week INT NOT NULL CHECK (day_of_week BETWEEN 1 AND 7), -- 1=Mon .. 7=Sun
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    room_number VARCHAR(64) NOT NULL,
    section VARCHAR(10) NOT NULL DEFAULT 'A',
    session_type VARCHAR(32) NOT NULL DEFAULT 'THEORY'
        CHECK (session_type IN ('THEORY', 'LAB', 'SEMINAR', 'TUTORIAL')),
    semester INT NOT NULL CHECK (semester BETWEEN 1 AND 12),
    academic_year VARCHAR(32) NOT NULL DEFAULT '2025-2026',
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT chk_timetable_time CHECK (end_time > start_time)
);

CREATE INDEX IF NOT EXISTS idx_timetable_lookup ON timetable(college_id, department_id, semester, day_of_week);

DROP TRIGGER IF EXISTS trg_timetable_updated_at ON timetable;
CREATE TRIGGER trg_timetable_updated_at
    BEFORE UPDATE ON timetable
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- 14. ATTENDANCE (Student Session Logs & Tracking)
-- =============================================================================
CREATE TABLE IF NOT EXISTS attendance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    college_id UUID NOT NULL
        REFERENCES colleges(id) ON DELETE CASCADE,
    student_id UUID NOT NULL
        REFERENCES students(id) ON DELETE CASCADE,
    course_id UUID NOT NULL
        REFERENCES courses(id) ON DELETE CASCADE,
    timetable_id UUID
        REFERENCES timetable(id) ON DELETE SET NULL,
    attendance_date DATE NOT NULL DEFAULT CURRENT_DATE,
    status VARCHAR(20) NOT NULL DEFAULT 'PRESENT'
        CHECK (status IN ('PRESENT', 'ABSENT', 'LATE', 'EXCUSED')),
    marked_by UUID
        REFERENCES users(id) ON DELETE SET NULL,
    verification_mode VARCHAR(32) NOT NULL DEFAULT 'MANUAL'
        CHECK (verification_mode IN ('MANUAL', 'PORTAL', 'FACULTY_ENTRY', 'QR_CODE')),
    remarks VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT uq_student_course_date_timetable UNIQUE (student_id, course_id, attendance_date, timetable_id)
);

CREATE INDEX IF NOT EXISTS idx_attendance_student ON attendance(student_id, course_id, attendance_date);

-- =============================================================================
-- 15. GRADES (Internal CIE, Lab Viva, Quizzes & Final Exam Marks)
-- =============================================================================
CREATE TABLE IF NOT EXISTS grades (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    college_id UUID NOT NULL
        REFERENCES colleges(id) ON DELETE CASCADE,
    student_id UUID NOT NULL
        REFERENCES students(id) ON DELETE CASCADE,
    course_id UUID NOT NULL
        REFERENCES courses(id) ON DELETE CASCADE,
    faculty_id UUID NOT NULL
        REFERENCES faculty(id) ON DELETE RESTRICT,
    assessment_type VARCHAR(32) NOT NULL
        CHECK (assessment_type IN ('INTERNAL_1', 'INTERNAL_2', 'ASSIGNMENT', 'LAB_VIVA', 'QUIZ', 'FINAL_EXAM')),
    assessment_name VARCHAR(128) NOT NULL,
    marks_obtained NUMERIC(5,2) NOT NULL CHECK (marks_obtained >= 0),
    max_marks NUMERIC(5,2) NOT NULL CHECK (max_marks > 0),
    grade_letter VARCHAR(5),
    grade_point NUMERIC(4,2),
    semester INT NOT NULL,
    academic_year VARCHAR(32) NOT NULL DEFAULT '2025-2026',
    remarks TEXT,
    evaluated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT chk_marks_lte_max CHECK (marks_obtained <= max_marks)
);

CREATE INDEX IF NOT EXISTS idx_grades_student ON grades(student_id, course_id);

DROP TRIGGER IF EXISTS trg_grades_updated_at ON grades;
CREATE TRIGGER trg_grades_updated_at
    BEFORE UPDATE ON grades
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- 16. CONVENIENCE ANALYTICAL VIEWS
-- =============================================================================

-- Complete Student Details
CREATE OR REPLACE VIEW view_students AS
SELECT 
    s.id AS student_id,
    u.id AS user_id,
    c.id AS college_id,
    c.name AS college_name,
    d.id AS department_id,
    d.name AS department_name,
    d.code AS department_code,
    u.full_name,
    u.email,
    u.phone_number,
    s.roll_number,
    s.registration_no,
    s.current_semester,
    s.current_year,
    s.section,
    s.batch_year,
    s.cgpa,
    s.guardian_name,
    s.guardian_phone,
    u.status
FROM students s
JOIN users u ON s.user_id = u.id
JOIN colleges c ON s.college_id = c.id
JOIN departments d ON s.department_id = d.id;

-- Complete Faculty Details
CREATE OR REPLACE VIEW view_faculty AS
SELECT 
    f.id AS faculty_id,
    u.id AS user_id,
    c.id AS college_id,
    c.name AS college_name,
    d.id AS department_id,
    d.name AS department_name,
    d.code AS department_code,
    u.full_name,
    u.email,
    u.phone_number,
    f.employee_code,
    f.designation,
    f.qualification,
    f.specialization,
    f.cabin_room,
    f.hire_date,
    u.status
FROM faculty f
JOIN users u ON f.user_id = u.id
JOIN colleges c ON f.college_id = c.id
JOIN departments d ON f.department_id = d.id;

-- Master Timetable View
CREATE OR REPLACE VIEW view_active_timetable AS
SELECT 
    t.id AS timetable_id,
    c.name AS college_name,
    d.name AS department_name,
    co.code AS course_code,
    co.name AS course_name,
    u.full_name AS faculty_name,
    t.day_of_week,
    CASE t.day_of_week
        WHEN 1 THEN 'Monday'
        WHEN 2 THEN 'Tuesday'
        WHEN 3 THEN 'Wednesday'
        WHEN 4 THEN 'Thursday'
        WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
        ELSE 'Sunday'
    END AS day_name,
    t.start_time,
    t.end_time,
    t.room_number,
    t.section,
    t.session_type,
    t.semester,
    t.academic_year
FROM timetable t
JOIN colleges c ON t.college_id = c.id
JOIN departments d ON t.department_id = d.id
JOIN courses co ON t.course_id = co.id
JOIN faculty f ON t.faculty_id = f.id
JOIN users u ON f.user_id = u.id;

-- Student Attendance Percentage Summary View
CREATE OR REPLACE VIEW view_student_attendance_summary AS
SELECT 
    s.id AS student_id,
    s.roll_number,
    u.full_name AS student_name,
    co.code AS course_code,
    co.name AS course_name,
    COUNT(a.id) AS total_classes,
    COUNT(CASE WHEN a.status IN ('PRESENT', 'LATE') THEN 1 END) AS attended_classes,
    ROUND(
        (COUNT(CASE WHEN a.status IN ('PRESENT', 'LATE') THEN 1 END)::NUMERIC / NULLIF(COUNT(a.id), 0)) * 100, 
        2
    ) AS attendance_percentage
FROM students s
JOIN users u ON s.user_id = u.id
JOIN attendance a ON s.id = a.student_id
JOIN courses co ON a.course_id = co.id
GROUP BY s.id, s.roll_number, u.full_name, co.code, co.name;
