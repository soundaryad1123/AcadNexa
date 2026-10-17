--
-- PostgreSQL database dump
--


-- Dumped from database version 16.15
-- Dumped by pg_dump version 16.15

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET search_path = public, extensions;
SELECT pg_catalog.set_config('search_path', 'public, extensions', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto;
SET search_path TO public, extensions;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = clock_timestamp();
    RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: academic_calendar; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.academic_calendar (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    college_id uuid NOT NULL,
    event_title character varying(255) NOT NULL,
    event_type character varying(32) NOT NULL,
    description text,
    start_date date NOT NULL,
    end_date date NOT NULL,
    is_holiday boolean DEFAULT false NOT NULL,
    target_audience character varying(32) DEFAULT 'ALL'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    CONSTRAINT academic_calendar_event_type_check CHECK (((event_type)::text = ANY ((ARRAY['EXAM'::character varying, 'HOLIDAY'::character varying, 'FESTIVAL'::character varying, 'WORKSHOP'::character varying, 'ADMISSION'::character varying, 'SEMESTER_START'::character varying, 'SEMESTER_END'::character varying, 'RESULT'::character varying])::text[]))),
    CONSTRAINT academic_calendar_target_audience_check CHECK (((target_audience)::text = ANY ((ARRAY['ALL'::character varying, 'STUDENTS'::character varying, 'FACULTY'::character varying])::text[]))),
    CONSTRAINT chk_calendar_dates CHECK ((end_date >= start_date))
);


--
-- Name: admins; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admins (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    college_id uuid NOT NULL,
    admin_level character varying(32) DEFAULT 'SUPER_ADMIN'::character varying NOT NULL,
    office_location character varying(128),
    created_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    CONSTRAINT admins_admin_level_check CHECK (((admin_level)::text = ANY ((ARRAY['SUPER_ADMIN'::character varying, 'DEAN'::character varying, 'REGISTRAR'::character varying, 'HOD'::character varying])::text[])))
);


--
-- Name: announcements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.announcements (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    college_id uuid NOT NULL,
    department_id uuid,
    author_id uuid NOT NULL,
    title character varying(255) NOT NULL,
    content text NOT NULL,
    category character varying(32) DEFAULT 'GENERAL'::character varying NOT NULL,
    target_role character varying(20) DEFAULT 'ALL'::character varying NOT NULL,
    priority character varying(20) DEFAULT 'NORMAL'::character varying NOT NULL,
    expires_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    updated_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    CONSTRAINT announcements_category_check CHECK (((category)::text = ANY ((ARRAY['GENERAL'::character varying, 'ACADEMIC'::character varying, 'EXAM'::character varying, 'EVENT'::character varying, 'PLACEMENT'::character varying, 'URGENT'::character varying])::text[]))),
    CONSTRAINT announcements_priority_check CHECK (((priority)::text = ANY ((ARRAY['LOW'::character varying, 'NORMAL'::character varying, 'HIGH'::character varying, 'URGENT'::character varying])::text[]))),
    CONSTRAINT announcements_target_role_check CHECK (((target_role)::text = ANY ((ARRAY['ALL'::character varying, 'FACULTY'::character varying, 'STUDENT'::character varying, 'ADMIN'::character varying])::text[])))
);


--
-- Name: attendance; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.attendance (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    college_id uuid NOT NULL,
    student_id uuid NOT NULL,
    course_id uuid NOT NULL,
    timetable_id uuid,
    attendance_date date DEFAULT CURRENT_DATE NOT NULL,
    status character varying(20) DEFAULT 'PRESENT'::character varying NOT NULL,
    marked_by uuid,
    verification_mode character varying(32) DEFAULT 'MANUAL'::character varying NOT NULL,
    remarks character varying(255),
    created_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    CONSTRAINT attendance_status_check CHECK (((status)::text = ANY ((ARRAY['PRESENT'::character varying, 'ABSENT'::character varying, 'LATE'::character varying, 'EXCUSED'::character varying])::text[]))),
    CONSTRAINT attendance_verification_mode_check CHECK (((verification_mode)::text = ANY ((ARRAY['MANUAL'::character varying, 'RFID'::character varying, 'BIOMETRIC'::character varying, 'QR_CODE'::character varying, 'PORTAL'::character varying])::text[])))
);


--
-- Name: colleges; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.colleges (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying(255) NOT NULL,
    code character varying(32) NOT NULL,
    slug character varying(64) NOT NULL,
    domain character varying(255),
    contact_email character varying(255) NOT NULL,
    contact_phone character varying(32),
    address text,
    subscription_tier character varying(32) DEFAULT 'enterprise'::character varying NOT NULL,
    status character varying(20) DEFAULT 'active'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    updated_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    CONSTRAINT colleges_status_check CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'suspended'::character varying, 'archived'::character varying])::text[]))),
    CONSTRAINT colleges_subscription_tier_check CHECK (((subscription_tier)::text = ANY ((ARRAY['trial'::character varying, 'standard'::character varying, 'enterprise'::character varying])::text[])))
);


--
-- Name: course_enrollments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.course_enrollments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    college_id uuid NOT NULL,
    student_id uuid NOT NULL,
    course_id uuid NOT NULL,
    semester integer NOT NULL,
    academic_year character varying(32) DEFAULT '2025-2026'::character varying NOT NULL,
    enrolled_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    status character varying(20) DEFAULT 'ENROLLED'::character varying NOT NULL,
    CONSTRAINT course_enrollments_status_check CHECK (((status)::text = ANY ((ARRAY['ENROLLED'::character varying, 'DROPPED'::character varying, 'COMPLETED'::character varying])::text[])))
);


--
-- Name: course_materials; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.course_materials (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    college_id uuid NOT NULL,
    course_id uuid NOT NULL,
    uploaded_by uuid NOT NULL,
    title character varying(255) NOT NULL,
    description text,
    material_type character varying(32) DEFAULT 'PDF'::character varying NOT NULL,
    file_url text NOT NULL,
    file_size_kb integer DEFAULT 2048,
    unit_module integer DEFAULT 1,
    created_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    updated_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    CONSTRAINT course_materials_material_type_check CHECK (((material_type)::text = ANY ((ARRAY['PDF'::character varying, 'SLIDES'::character varying, 'ASSIGNMENT'::character varying, 'LAB_MANUAL'::character varying, 'VIDEO'::character varying, 'SYLLABUS'::character varying])::text[])))
);


--
-- Name: courses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.courses (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    college_id uuid NOT NULL,
    department_id uuid NOT NULL,
    code character varying(32) NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    credits integer DEFAULT 3 NOT NULL,
    semester integer NOT NULL,
    course_type character varying(32) DEFAULT 'CORE'::character varying NOT NULL,
    status character varying(20) DEFAULT 'active'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    updated_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    CONSTRAINT courses_course_type_check CHECK (((course_type)::text = ANY ((ARRAY['CORE'::character varying, 'ELECTIVE'::character varying, 'LAB'::character varying, 'PROJECT'::character varying])::text[]))),
    CONSTRAINT courses_credits_check CHECK ((credits >= 0)),
    CONSTRAINT courses_semester_check CHECK (((semester >= 1) AND (semester <= 12))),
    CONSTRAINT courses_status_check CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'inactive'::character varying, 'archived'::character varying])::text[])))
);


--
-- Name: departments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.departments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    college_id uuid NOT NULL,
    name character varying(150) NOT NULL,
    code character varying(20) NOT NULL,
    head_of_department character varying(150),
    created_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    updated_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL
);


--
-- Name: faculty; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.faculty (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    college_id uuid NOT NULL,
    department_id uuid NOT NULL,
    employee_code character varying(64) NOT NULL,
    designation character varying(100) NOT NULL,
    qualification character varying(150),
    specialization character varying(255),
    cabin_room character varying(64),
    hire_date date DEFAULT CURRENT_DATE NOT NULL,
    created_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    updated_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL
);


--
-- Name: grades; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.grades (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    college_id uuid NOT NULL,
    student_id uuid NOT NULL,
    course_id uuid NOT NULL,
    faculty_id uuid NOT NULL,
    assessment_type character varying(32) NOT NULL,
    assessment_name character varying(128) NOT NULL,
    marks_obtained numeric(5,2) NOT NULL,
    max_marks numeric(5,2) NOT NULL,
    grade_letter character varying(5),
    grade_point numeric(4,2),
    semester integer NOT NULL,
    academic_year character varying(32) DEFAULT '2025-2026'::character varying NOT NULL,
    remarks text,
    evaluated_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    created_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    updated_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    CONSTRAINT chk_marks_lte_max CHECK ((marks_obtained <= max_marks)),
    CONSTRAINT grades_assessment_type_check CHECK (((assessment_type)::text = ANY ((ARRAY['INTERNAL_1'::character varying, 'INTERNAL_2'::character varying, 'ASSIGNMENT'::character varying, 'LAB_VIVA'::character varying, 'QUIZ'::character varying, 'FINAL_EXAM'::character varying])::text[]))),
    CONSTRAINT grades_marks_obtained_check CHECK ((marks_obtained >= (0)::numeric)),
    CONSTRAINT grades_max_marks_check CHECK ((max_marks > (0)::numeric))
);


--
-- Name: students; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.students (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    college_id uuid NOT NULL,
    department_id uuid NOT NULL,
    roll_number character varying(64) NOT NULL,
    registration_no character varying(64) NOT NULL,
    current_semester integer NOT NULL,
    current_year integer NOT NULL,
    section character varying(10) DEFAULT 'A'::character varying NOT NULL,
    batch_year character varying(32) DEFAULT '2023-2027'::character varying NOT NULL,
    cgpa numeric(4,2) DEFAULT 8.50,
    admission_date date DEFAULT CURRENT_DATE NOT NULL,
    guardian_name character varying(150),
    guardian_phone character varying(32),
    created_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    updated_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    CONSTRAINT students_cgpa_check CHECK (((cgpa >= 0.0) AND (cgpa <= 10.0))),
    CONSTRAINT students_current_semester_check CHECK (((current_semester >= 1) AND (current_semester <= 12))),
    CONSTRAINT students_current_year_check CHECK (((current_year >= 1) AND (current_year <= 6)))
);


--
-- Name: timetable; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.timetable (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    college_id uuid NOT NULL,
    department_id uuid NOT NULL,
    course_id uuid NOT NULL,
    faculty_id uuid NOT NULL,
    day_of_week integer NOT NULL,
    start_time time without time zone NOT NULL,
    end_time time without time zone NOT NULL,
    room_number character varying(64) NOT NULL,
    section character varying(10) DEFAULT 'A'::character varying NOT NULL,
    session_type character varying(32) DEFAULT 'THEORY'::character varying NOT NULL,
    semester integer NOT NULL,
    academic_year character varying(32) DEFAULT '2025-2026'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    updated_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    CONSTRAINT chk_timetable_time CHECK ((end_time > start_time)),
    CONSTRAINT timetable_day_of_week_check CHECK (((day_of_week >= 1) AND (day_of_week <= 7))),
    CONSTRAINT timetable_semester_check CHECK (((semester >= 1) AND (semester <= 12))),
    CONSTRAINT timetable_session_type_check CHECK (((session_type)::text = ANY ((ARRAY['THEORY'::character varying, 'LAB'::character varying, 'SEMINAR'::character varying, 'TUTORIAL'::character varying])::text[])))
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    college_id uuid NOT NULL,
    department_id uuid,
    email character varying(255) NOT NULL,
    password_hash text DEFAULT '$2b$12$PcgVh63PAIBdXJsO.zSOUuNCbXS6b19nkO/8EWA3ZfhNIAS2VEs0.' NOT NULL,
    full_name character varying(150) NOT NULL,
    phone_number character varying(32),
    role character varying(20) NOT NULL,
    status character varying(20) DEFAULT 'active'::character varying NOT NULL,
    avatar_url text,
    last_login_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    updated_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    CONSTRAINT users_role_check CHECK (((role)::text = ANY ((ARRAY['ADMIN'::character varying, 'FACULTY'::character varying, 'STUDENT'::character varying])::text[]))),
    CONSTRAINT users_status_check CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'inactive'::character varying, 'suspended'::character varying])::text[])))
);


--
-- Name: view_active_timetable; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.view_active_timetable AS
 SELECT t.id AS timetable_id,
    c.name AS college_name,
    d.name AS department_name,
    co.code AS course_code,
    co.name AS course_name,
    u.full_name AS faculty_name,
    t.day_of_week,
        CASE t.day_of_week
            WHEN 1 THEN 'Monday'::text
            WHEN 2 THEN 'Tuesday'::text
            WHEN 3 THEN 'Wednesday'::text
            WHEN 4 THEN 'Thursday'::text
            WHEN 5 THEN 'Friday'::text
            WHEN 6 THEN 'Saturday'::text
            ELSE 'Sunday'::text
        END AS day_name,
    t.start_time,
    t.end_time,
    t.room_number,
    t.section,
    t.session_type,
    t.semester,
    t.academic_year
   FROM (((((public.timetable t
     JOIN public.colleges c ON ((t.college_id = c.id)))
     JOIN public.departments d ON ((t.department_id = d.id)))
     JOIN public.courses co ON ((t.course_id = co.id)))
     JOIN public.faculty f ON ((t.faculty_id = f.id)))
     JOIN public.users u ON ((f.user_id = u.id)));


--
-- Name: view_faculty; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.view_faculty AS
 SELECT f.id AS faculty_id,
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
   FROM (((public.faculty f
     JOIN public.users u ON ((f.user_id = u.id)))
     JOIN public.colleges c ON ((f.college_id = c.id)))
     JOIN public.departments d ON ((f.department_id = d.id)));


--
-- Name: view_student_attendance_summary; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.view_student_attendance_summary AS
 SELECT s.id AS student_id,
    s.roll_number,
    u.full_name AS student_name,
    co.code AS course_code,
    co.name AS course_name,
    count(a.id) AS total_classes,
    count(
        CASE
            WHEN ((a.status)::text = ANY ((ARRAY['PRESENT'::character varying, 'LATE'::character varying])::text[])) THEN 1
            ELSE NULL::integer
        END) AS attended_classes,
    round((((count(
        CASE
            WHEN ((a.status)::text = ANY ((ARRAY['PRESENT'::character varying, 'LATE'::character varying])::text[])) THEN 1
            ELSE NULL::integer
        END))::numeric / (NULLIF(count(a.id), 0))::numeric) * (100)::numeric), 2) AS attendance_percentage
   FROM (((public.students s
     JOIN public.users u ON ((s.user_id = u.id)))
     JOIN public.attendance a ON ((s.id = a.student_id)))
     JOIN public.courses co ON ((a.course_id = co.id)))
  GROUP BY s.id, s.roll_number, u.full_name, co.code, co.name;


--
-- Name: view_students; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.view_students AS
 SELECT s.id AS student_id,
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
   FROM (((public.students s
     JOIN public.users u ON ((s.user_id = u.id)))
     JOIN public.colleges c ON ((s.college_id = c.id)))
     JOIN public.departments d ON ((s.department_id = d.id)));


--
-- Data for Name: academic_calendar; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.academic_calendar (id, college_id, event_title, event_type, description, start_date, end_date, is_holiday, target_audience, created_at) VALUES ('632da92d-85bf-4cfe-bf5f-8600434a0f5e', '773013e5-0ce8-4db7-b5af-af50bae06939', 'Odd Semester 2025-26 Commencement', 'SEMESTER_START', 'Official reopening and commencement of academic classes for 3rd, 5th, and 7th semester students.', '2025-08-04', '2025-08-04', false, 'ALL', '2026-10-06 17:41:10.06162+00');
INSERT INTO public.academic_calendar (id, college_id, event_title, event_type, description, start_date, end_date, is_holiday, target_audience, created_at) VALUES ('625a6d2f-4670-4987-ba24-ca9b39a538f0', '773013e5-0ce8-4db7-b5af-af50bae06939', 'Independence Day Holiday', 'HOLIDAY', 'National Holiday celebration and flag hoisting in main quadrangle.', '2025-08-15', '2025-08-15', true, 'ALL', '2026-10-06 17:41:10.062797+00');
INSERT INTO public.academic_calendar (id, college_id, event_title, event_type, description, start_date, end_date, is_holiday, target_audience, created_at) VALUES ('ac1e9774-72a4-4c51-a06d-44a8db4a8673', '773013e5-0ce8-4db7-b5af-af50bae06939', 'Internal Assessment Test - 1 (CIE 1)', 'EXAM', 'First centralized internal test covering Units 1 & 2 for all departments.', '2025-09-22', '2025-09-26', false, 'STUDENTS', '2026-10-06 17:41:10.062869+00');
INSERT INTO public.academic_calendar (id, college_id, event_title, event_type, description, start_date, end_date, is_holiday, target_audience, created_at) VALUES ('e464f401-4a33-4739-80fa-d6fdbfb12f2d', '773013e5-0ce8-4db7-b5af-af50bae06939', 'AcadNexa Annual Hackathon 2025', 'WORKSHOP', '48-Hour Open Innovation Hackathon with industry mentorship and prizes.', '2025-10-10', '2025-10-12', false, 'STUDENTS', '2026-10-06 17:41:10.062892+00');
INSERT INTO public.academic_calendar (id, college_id, event_title, event_type, description, start_date, end_date, is_holiday, target_audience, created_at) VALUES ('30fce617-2240-4e12-a813-128a877d1378', '773013e5-0ce8-4db7-b5af-af50bae06939', 'Internal Assessment Test - 2 (CIE 2)', 'EXAM', 'Second internal continuous assessment test covering Units 3 & 4.', '2025-11-17', '2025-11-21', false, 'STUDENTS', '2026-10-06 17:41:10.062912+00');
INSERT INTO public.academic_calendar (id, college_id, event_title, event_type, description, start_date, end_date, is_holiday, target_audience, created_at) VALUES ('cefa5adc-373c-4679-9933-18d9acde3812', '773013e5-0ce8-4db7-b5af-af50bae06939', 'Semester End Practical Lab Examinations', 'EXAM', 'Autonomous practical lab viva and project evaluations.', '2025-12-08', '2025-12-15', false, 'STUDENTS', '2026-10-06 17:41:10.062932+00');
INSERT INTO public.academic_calendar (id, college_id, event_title, event_type, description, start_date, end_date, is_holiday, target_audience, created_at) VALUES ('0ec790e8-840c-47b3-a4f0-72bd72ea7377', '773013e5-0ce8-4db7-b5af-af50bae06939', 'Odd Semester End Theory Examinations', 'EXAM', 'University Final Semester Theory Examinations.', '2025-12-18', '2026-01-08', false, 'STUDENTS', '2026-10-06 17:41:10.063129+00');
INSERT INTO public.academic_calendar (id, college_id, event_title, event_type, description, start_date, end_date, is_holiday, target_audience, created_at) VALUES ('4d4da862-e40e-45d9-8e0f-bb1e53b71556', '773013e5-0ce8-4db7-b5af-af50bae06939', 'Winter Vacation & Inter-Semester Break', 'HOLIDAY', 'Winter holidays for students; Faculty development workshops.', '2026-01-09', '2026-01-25', true, 'STUDENTS', '2026-10-06 17:41:10.063155+00');


--
-- Data for Name: admins; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.admins (id, user_id, college_id, admin_level, office_location, created_at) VALUES ('d49df562-64e5-4c49-8329-6ea19bc6bab0', '11fa2ab2-d290-412f-a2aa-fccb7e2d6778', '773013e5-0ce8-4db7-b5af-af50bae06939', 'SUPER_ADMIN', 'Administrative Block, Room A-101', '2026-10-06 17:41:09.976113+00');
INSERT INTO public.admins (id, user_id, college_id, admin_level, office_location, created_at) VALUES ('0af44d3e-fd22-4f90-b0b8-2ab8d0b5697a', 'aa7bca0e-8e88-40e3-a1b2-ff6a80cb745d', '176ec9b8-0c53-4237-94ca-f83bf59cbfe4', 'DEAN', 'Chancellor Tower, Suite 402', '2026-10-06 17:41:09.976755+00');


--
-- Data for Name: announcements; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.announcements (id, college_id, department_id, author_id, title, content, category, target_role, priority, expires_at, created_at, updated_at) VALUES ('8e00d024-271e-4a04-9151-021165ca1745', '773013e5-0ce8-4db7-b5af-af50bae06939', NULL, '11fa2ab2-d290-412f-a2aa-fccb7e2d6778', '📢 Campus Closed for Diwali Holiday & Reopening Notice', 'All academic activities, libraries, and administrative offices will remain closed from Nov 1st to Nov 4th. Regular classes will resume on Nov 5th as per timetable.', 'GENERAL', 'ALL', 'HIGH', '2026-11-05 17:41:09.21365+00', '2026-10-06 17:41:10.06699+00', '2026-10-06 17:41:10.06699+00');
INSERT INTO public.announcements (id, college_id, department_id, author_id, title, content, category, target_role, priority, expires_at, created_at, updated_at) VALUES ('2e3ad1da-90fd-495a-80a5-6c4608addc2e', '773013e5-0ce8-4db7-b5af-af50bae06939', '202c1550-5012-475f-a4ac-06fbcb139c93', '859c23c1-83da-45a1-b3a6-d109ec1a5907', '📝 Internal Assessment Test - 1 Schedule & Seating Arrangement', 'The CIE-1 exam timetable for CSE Sem 5 has been published. Exams begin daily at 09:30 AM in Exam Hall 201. Carrying identity cards is mandatory.', 'EXAM', 'STUDENT', 'HIGH', '2026-10-20 17:41:09.21365+00', '2026-10-06 17:41:10.067628+00', '2026-10-06 17:41:10.067629+00');
INSERT INTO public.announcements (id, college_id, department_id, author_id, title, content, category, target_role, priority, expires_at, created_at, updated_at) VALUES ('06ea4e2c-9067-4eab-b269-f5d2cb645050', '773013e5-0ce8-4db7-b5af-af50bae06939', NULL, '11fa2ab2-d290-412f-a2aa-fccb7e2d6778', '🚀 Placement Drive: Google & Microsoft Cloud Engineering Roles', 'Eligible 7th & 5th semester students with CGPA >= 8.5 must register on the placement portal before Friday 5:00 PM for the upcoming coding test.', 'PLACEMENT', 'STUDENT', 'URGENT', '2026-10-13 17:41:09.21365+00', '2026-10-06 17:41:10.067651+00', '2026-10-06 17:41:10.067651+00');
INSERT INTO public.announcements (id, college_id, department_id, author_id, title, content, category, target_role, priority, expires_at, created_at, updated_at) VALUES ('6d554cf4-48f2-4091-a623-f7a40d4a8288', '773013e5-0ce8-4db7-b5af-af50bae06939', '202c1550-5012-475f-a4ac-06fbcb139c93', '0ce413d1-8815-4239-8919-32ad41121836', '💡 Guest Lecture on Generative AI by DeepMind Research Scientist', 'A special interactive guest lecture on Large Language Models will take place this Thursday at 2:30 PM in Seminar Hall 1.', 'ACADEMIC', 'ALL', 'NORMAL', '2026-10-11 17:41:09.21365+00', '2026-10-06 17:41:10.067665+00', '2026-10-06 17:41:10.067666+00');
INSERT INTO public.announcements (id, college_id, department_id, author_id, title, content, category, target_role, priority, expires_at, created_at, updated_at) VALUES ('0e1931a7-0bb1-4564-bf19-fd5510b1e19f', '773013e5-0ce8-4db7-b5af-af50bae06939', NULL, '11fa2ab2-d290-412f-a2aa-fccb7e2d6778', 'End Semester Examination Schedule Released', 'All students and faculty please note that the final timetable for the End Semester Examinations has been officially published.', 'EXAM', 'ALL', 'HIGH', NULL, '2026-10-12 18:00:46.620382+00', '2026-10-12 18:00:46.620386+00');
INSERT INTO public.announcements (id, college_id, department_id, author_id, title, content, category, target_role, priority, expires_at, created_at, updated_at) VALUES ('8069972a-785d-488f-b5f1-b546d3e7f704', '773013e5-0ce8-4db7-b5af-af50bae06939', NULL, '11fa2ab2-d290-412f-a2aa-fccb7e2d6778', 'Dussera', 'Holiday for ', 'GENERAL', 'ALL', 'NORMAL', NULL, '2026-10-13 08:31:57.513813+00', '2026-10-13 08:31:57.51382+00');


--
-- Data for Name: attendance; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.attendance (id, college_id, student_id, course_id, timetable_id, attendance_date, status, marked_by, verification_mode, remarks, created_at) VALUES ('da604c99-af6e-4218-8f18-82f858abaff3', '773013e5-0ce8-4db7-b5af-af50bae06939', 'a85d7016-d9f2-44ab-91c9-0a9a988d2ad6', '45ef449c-b929-4a74-aacd-4804f4527ce7', '747d7900-5bc7-4209-a61e-15416db62128', '2026-10-04', 'PRESENT', '0ce413d1-8815-4239-8919-32ad41121836', 'PORTAL', 'Regular attendance', '2026-10-06 17:41:10.076658+00');
INSERT INTO public.attendance (id, college_id, student_id, course_id, timetable_id, attendance_date, status, marked_by, verification_mode, remarks, created_at) VALUES ('b59b2f83-941d-4ca1-9841-52f4cad1eeb8', '773013e5-0ce8-4db7-b5af-af50bae06939', 'a85d7016-d9f2-44ab-91c9-0a9a988d2ad6', '06d78cfd-323b-4e3f-aecf-b7780838ebac', '58a6cdcb-f64b-4189-9d0e-87212a29c219', '2026-10-04', 'PRESENT', 'adf210a7-9fc5-41d7-ba37-ad6c1c361261', 'QR_CODE', 'Verified by QR scan', '2026-10-06 17:41:10.077266+00');
INSERT INTO public.attendance (id, college_id, student_id, course_id, timetable_id, attendance_date, status, marked_by, verification_mode, remarks, created_at) VALUES ('f3830262-e314-4df7-97bf-0998fe7d72f7', '773013e5-0ce8-4db7-b5af-af50bae06939', 'a85d7016-d9f2-44ab-91c9-0a9a988d2ad6', '91adea4c-2cd0-4dcc-8186-d79004067832', 'a56f8eff-c673-4e86-8254-706ec761c7fa', '2026-10-04', 'PRESENT', 'adf210a7-9fc5-41d7-ba37-ad6c1c361261', 'PORTAL', 'Active participation', '2026-10-06 17:41:10.077284+00');
INSERT INTO public.attendance (id, college_id, student_id, course_id, timetable_id, attendance_date, status, marked_by, verification_mode, remarks, created_at) VALUES ('539706e5-eb9f-4112-9b62-4200248c2a65', '773013e5-0ce8-4db7-b5af-af50bae06939', 'a85d7016-d9f2-44ab-91c9-0a9a988d2ad6', '45ef449c-b929-4a74-aacd-4804f4527ce7', '747d7900-5bc7-4209-a61e-15416db62128', '2026-10-05', 'PRESENT', '0ce413d1-8815-4239-8919-32ad41121836', 'PORTAL', 'Regular attendance', '2026-10-06 17:41:10.077293+00');
INSERT INTO public.attendance (id, college_id, student_id, course_id, timetable_id, attendance_date, status, marked_by, verification_mode, remarks, created_at) VALUES ('8e627b06-8be5-4bfc-8050-dbafc2a7a75e', '773013e5-0ce8-4db7-b5af-af50bae06939', 'a85d7016-d9f2-44ab-91c9-0a9a988d2ad6', '06d78cfd-323b-4e3f-aecf-b7780838ebac', '58a6cdcb-f64b-4189-9d0e-87212a29c219', '2026-10-05', 'PRESENT', 'adf210a7-9fc5-41d7-ba37-ad6c1c361261', 'PORTAL', 'Regular attendance', '2026-10-06 17:41:10.077385+00');
INSERT INTO public.attendance (id, college_id, student_id, course_id, timetable_id, attendance_date, status, marked_by, verification_mode, remarks, created_at) VALUES ('44e7402b-d907-4c07-b342-461ba17b325e', '773013e5-0ce8-4db7-b5af-af50bae06939', 'a85d7016-d9f2-44ab-91c9-0a9a988d2ad6', '45ef449c-b929-4a74-aacd-4804f4527ce7', '747d7900-5bc7-4209-a61e-15416db62128', '2026-10-06', 'PRESENT', '0ce413d1-8815-4239-8919-32ad41121836', 'PORTAL', 'Marked in class', '2026-10-06 17:41:10.077397+00');
INSERT INTO public.attendance (id, college_id, student_id, course_id, timetable_id, attendance_date, status, marked_by, verification_mode, remarks, created_at) VALUES ('8ba6cf6b-1e30-4ee7-b009-920f53f0052d', '773013e5-0ce8-4db7-b5af-af50bae06939', '66640a27-7c97-4eeb-aa97-61489348aaa7', '45ef449c-b929-4a74-aacd-4804f4527ce7', '747d7900-5bc7-4209-a61e-15416db62128', '2026-10-04', 'PRESENT', '0ce413d1-8815-4239-8919-32ad41121836', 'PORTAL', 'Regular attendance', '2026-10-06 17:41:10.077406+00');
INSERT INTO public.attendance (id, college_id, student_id, course_id, timetable_id, attendance_date, status, marked_by, verification_mode, remarks, created_at) VALUES ('9af62588-eef3-4cfb-a82b-46281edfb1e7', '773013e5-0ce8-4db7-b5af-af50bae06939', '66640a27-7c97-4eeb-aa97-61489348aaa7', '06d78cfd-323b-4e3f-aecf-b7780838ebac', '58a6cdcb-f64b-4189-9d0e-87212a29c219', '2026-10-04', 'PRESENT', 'adf210a7-9fc5-41d7-ba37-ad6c1c361261', 'QR_CODE', 'Regular attendance', '2026-10-06 17:41:10.077415+00');
INSERT INTO public.attendance (id, college_id, student_id, course_id, timetable_id, attendance_date, status, marked_by, verification_mode, remarks, created_at) VALUES ('6b4fde58-6499-4293-96d7-860d3d47ff61', '773013e5-0ce8-4db7-b5af-af50bae06939', '66640a27-7c97-4eeb-aa97-61489348aaa7', '91adea4c-2cd0-4dcc-8186-d79004067832', 'a56f8eff-c673-4e86-8254-706ec761c7fa', '2026-10-04', 'LATE', 'adf210a7-9fc5-41d7-ba37-ad6c1c361261', 'PORTAL', 'Arrived 10 mins late with permit', '2026-10-06 17:41:10.077424+00');
INSERT INTO public.attendance (id, college_id, student_id, course_id, timetable_id, attendance_date, status, marked_by, verification_mode, remarks, created_at) VALUES ('4e2a7e0d-4321-4d74-a3fc-b49ed7214094', '773013e5-0ce8-4db7-b5af-af50bae06939', '66640a27-7c97-4eeb-aa97-61489348aaa7', '45ef449c-b929-4a74-aacd-4804f4527ce7', '747d7900-5bc7-4209-a61e-15416db62128', '2026-10-05', 'PRESENT', '0ce413d1-8815-4239-8919-32ad41121836', 'PORTAL', 'Regular attendance', '2026-10-06 17:41:10.077433+00');
INSERT INTO public.attendance (id, college_id, student_id, course_id, timetable_id, attendance_date, status, marked_by, verification_mode, remarks, created_at) VALUES ('b2b0fca5-0a8a-4ec6-86bc-37817b33eecc', '773013e5-0ce8-4db7-b5af-af50bae06939', '66640a27-7c97-4eeb-aa97-61489348aaa7', '06d78cfd-323b-4e3f-aecf-b7780838ebac', '58a6cdcb-f64b-4189-9d0e-87212a29c219', '2026-10-05', 'PRESENT', 'adf210a7-9fc5-41d7-ba37-ad6c1c361261', 'PORTAL', 'Regular attendance', '2026-10-06 17:41:10.077441+00');
INSERT INTO public.attendance (id, college_id, student_id, course_id, timetable_id, attendance_date, status, marked_by, verification_mode, remarks, created_at) VALUES ('8fc6c665-83e7-4923-bc28-8e5659dc5117', '773013e5-0ce8-4db7-b5af-af50bae06939', '66640a27-7c97-4eeb-aa97-61489348aaa7', '45ef449c-b929-4a74-aacd-4804f4527ce7', '747d7900-5bc7-4209-a61e-15416db62128', '2026-10-06', 'PRESENT', '0ce413d1-8815-4239-8919-32ad41121836', 'PORTAL', 'Marked in class', '2026-10-06 17:41:10.07745+00');
INSERT INTO public.attendance (id, college_id, student_id, course_id, timetable_id, attendance_date, status, marked_by, verification_mode, remarks, created_at) VALUES ('b3e4747e-740b-4e97-8463-4b06d15f0e5b', '773013e5-0ce8-4db7-b5af-af50bae06939', '5d1023c6-824e-4884-abe0-5523c828a0fc', '45ef449c-b929-4a74-aacd-4804f4527ce7', '747d7900-5bc7-4209-a61e-15416db62128', '2026-10-04', 'ABSENT', '0ce413d1-8815-4239-8919-32ad41121836', 'PORTAL', 'Unexcused leave', '2026-10-06 17:41:10.077678+00');
INSERT INTO public.attendance (id, college_id, student_id, course_id, timetable_id, attendance_date, status, marked_by, verification_mode, remarks, created_at) VALUES ('4105b2f2-f147-4b25-8f45-7139daff3ddb', '773013e5-0ce8-4db7-b5af-af50bae06939', '5d1023c6-824e-4884-abe0-5523c828a0fc', '06d78cfd-323b-4e3f-aecf-b7780838ebac', '58a6cdcb-f64b-4189-9d0e-87212a29c219', '2026-10-04', 'ABSENT', 'adf210a7-9fc5-41d7-ba37-ad6c1c361261', 'PORTAL', 'Unexcused leave', '2026-10-06 17:41:10.077719+00');
INSERT INTO public.attendance (id, college_id, student_id, course_id, timetable_id, attendance_date, status, marked_by, verification_mode, remarks, created_at) VALUES ('6a5988c8-51f7-4546-919a-c02d1e808277', '773013e5-0ce8-4db7-b5af-af50bae06939', '5d1023c6-824e-4884-abe0-5523c828a0fc', '91adea4c-2cd0-4dcc-8186-d79004067832', 'a56f8eff-c673-4e86-8254-706ec761c7fa', '2026-10-04', 'ABSENT', 'adf210a7-9fc5-41d7-ba37-ad6c1c361261', 'PORTAL', 'Unexcused leave', '2026-10-06 17:41:10.077729+00');
INSERT INTO public.attendance (id, college_id, student_id, course_id, timetable_id, attendance_date, status, marked_by, verification_mode, remarks, created_at) VALUES ('c4500f14-d760-485b-96b8-0942347e109d', '773013e5-0ce8-4db7-b5af-af50bae06939', '5d1023c6-824e-4884-abe0-5523c828a0fc', '45ef449c-b929-4a74-aacd-4804f4527ce7', '747d7900-5bc7-4209-a61e-15416db62128', '2026-10-05', 'PRESENT', '0ce413d1-8815-4239-8919-32ad41121836', 'PORTAL', 'Back in class', '2026-10-06 17:41:10.077738+00');
INSERT INTO public.attendance (id, college_id, student_id, course_id, timetable_id, attendance_date, status, marked_by, verification_mode, remarks, created_at) VALUES ('0349c9ab-fff3-459d-bb13-346244355ac1', '773013e5-0ce8-4db7-b5af-af50bae06939', '5d1023c6-824e-4884-abe0-5523c828a0fc', '06d78cfd-323b-4e3f-aecf-b7780838ebac', '58a6cdcb-f64b-4189-9d0e-87212a29c219', '2026-10-05', 'PRESENT', 'adf210a7-9fc5-41d7-ba37-ad6c1c361261', 'PORTAL', 'Regular attendance', '2026-10-06 17:41:10.077747+00');
INSERT INTO public.attendance (id, college_id, student_id, course_id, timetable_id, attendance_date, status, marked_by, verification_mode, remarks, created_at) VALUES ('dbf5f83e-830f-466c-aa6b-cc4fd382f768', '773013e5-0ce8-4db7-b5af-af50bae06939', '5d1023c6-824e-4884-abe0-5523c828a0fc', '45ef449c-b929-4a74-aacd-4804f4527ce7', '747d7900-5bc7-4209-a61e-15416db62128', '2026-10-06', 'PRESENT', '0ce413d1-8815-4239-8919-32ad41121836', 'PORTAL', 'Marked in class', '2026-10-06 17:41:10.077756+00');
INSERT INTO public.attendance (id, college_id, student_id, course_id, timetable_id, attendance_date, status, marked_by, verification_mode, remarks, created_at) VALUES ('8e8bf3c8-577b-462f-a06b-fb1f8100143b', '773013e5-0ce8-4db7-b5af-af50bae06939', 'a85d7016-d9f2-44ab-91c9-0a9a988d2ad6', '45ef449c-b929-4a74-aacd-4804f4527ce7', '38884bae-2ae2-40b4-889a-a5a73671d040', '2026-10-13', 'ABSENT', '0ce413d1-8815-4239-8919-32ad41121836', 'PORTAL', NULL, '2026-10-13 08:36:49.174824+00');
INSERT INTO public.attendance (id, college_id, student_id, course_id, timetable_id, attendance_date, status, marked_by, verification_mode, remarks, created_at) VALUES ('2fcb14ee-8555-4914-912d-7d7e6928d708', '773013e5-0ce8-4db7-b5af-af50bae06939', '66640a27-7c97-4eeb-aa97-61489348aaa7', '45ef449c-b929-4a74-aacd-4804f4527ce7', '38884bae-2ae2-40b4-889a-a5a73671d040', '2026-10-13', 'ABSENT', '0ce413d1-8815-4239-8919-32ad41121836', 'PORTAL', NULL, '2026-10-13 08:36:49.207607+00');
INSERT INTO public.attendance (id, college_id, student_id, course_id, timetable_id, attendance_date, status, marked_by, verification_mode, remarks, created_at) VALUES ('fd519648-2092-4a80-9d63-d2223e83acc4', '773013e5-0ce8-4db7-b5af-af50bae06939', '5d1023c6-824e-4884-abe0-5523c828a0fc', '45ef449c-b929-4a74-aacd-4804f4527ce7', '38884bae-2ae2-40b4-889a-a5a73671d040', '2026-10-13', 'ABSENT', '0ce413d1-8815-4239-8919-32ad41121836', 'PORTAL', NULL, '2026-10-13 08:36:49.223933+00');


--
-- Data for Name: colleges; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.colleges (id, name, code, slug, domain, contact_email, contact_phone, address, subscription_tier, status, created_at, updated_at) VALUES ('773013e5-0ce8-4db7-b5af-af50bae06939', 'Apex Institute of Technology & Management', 'AITM', 'apex-tech', 'aitm.edu.in', 'contact@aitm.edu.in', '+91 80 2345 6789', 'Plot 42, Tech Knowledge Park, Whitefield, Bangalore, Karnataka - 560066', 'enterprise', 'active', '2026-10-06 17:41:09.956208+00', '2026-10-06 17:41:09.956208+00');
INSERT INTO public.colleges (id, name, code, slug, domain, contact_email, contact_phone, address, subscription_tier, status, created_at, updated_at) VALUES ('176ec9b8-0c53-4237-94ca-f83bf59cbfe4', 'National Horizon University', 'NHU', 'horizon-univ', 'horizon.edu.in', 'info@horizon.edu.in', '+91 44 2876 5432', 'Campus 12, GST Road, Chennai, Tamil Nadu - 600028', 'enterprise', 'active', '2026-10-06 17:41:09.957346+00', '2026-10-06 17:41:09.957346+00');


--
-- Data for Name: course_enrollments; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.course_enrollments (id, college_id, student_id, course_id, semester, academic_year, enrolled_at, status) VALUES ('e5868ae1-11db-4aab-99e9-e4ce7123d3da', '773013e5-0ce8-4db7-b5af-af50bae06939', 'a85d7016-d9f2-44ab-91c9-0a9a988d2ad6', '45ef449c-b929-4a74-aacd-4804f4527ce7', 5, '2025-2026', '2026-10-06 17:41:10.055286+00', 'ENROLLED');
INSERT INTO public.course_enrollments (id, college_id, student_id, course_id, semester, academic_year, enrolled_at, status) VALUES ('02198355-1f45-4bf2-b7b2-e47f79dbff92', '773013e5-0ce8-4db7-b5af-af50bae06939', 'a85d7016-d9f2-44ab-91c9-0a9a988d2ad6', '06d78cfd-323b-4e3f-aecf-b7780838ebac', 5, '2025-2026', '2026-10-06 17:41:10.055837+00', 'ENROLLED');
INSERT INTO public.course_enrollments (id, college_id, student_id, course_id, semester, academic_year, enrolled_at, status) VALUES ('bee45a6c-81b7-4e3d-905d-7aed1f095cb4', '773013e5-0ce8-4db7-b5af-af50bae06939', 'a85d7016-d9f2-44ab-91c9-0a9a988d2ad6', '91adea4c-2cd0-4dcc-8186-d79004067832', 5, '2025-2026', '2026-10-06 17:41:10.055862+00', 'ENROLLED');
INSERT INTO public.course_enrollments (id, college_id, student_id, course_id, semester, academic_year, enrolled_at, status) VALUES ('9c2c4840-588d-4bee-9728-734f7cc43420', '773013e5-0ce8-4db7-b5af-af50bae06939', 'a85d7016-d9f2-44ab-91c9-0a9a988d2ad6', 'c07118ec-d07b-4c30-9321-f916b89497ac', 5, '2025-2026', '2026-10-06 17:41:10.055871+00', 'ENROLLED');
INSERT INTO public.course_enrollments (id, college_id, student_id, course_id, semester, academic_year, enrolled_at, status) VALUES ('c600a287-a231-47a9-9523-84cf6e1fb316', '773013e5-0ce8-4db7-b5af-af50bae06939', '66640a27-7c97-4eeb-aa97-61489348aaa7', '45ef449c-b929-4a74-aacd-4804f4527ce7', 5, '2025-2026', '2026-10-06 17:41:10.055879+00', 'ENROLLED');
INSERT INTO public.course_enrollments (id, college_id, student_id, course_id, semester, academic_year, enrolled_at, status) VALUES ('94f4e706-364f-4766-846f-22667a48d39c', '773013e5-0ce8-4db7-b5af-af50bae06939', '66640a27-7c97-4eeb-aa97-61489348aaa7', '06d78cfd-323b-4e3f-aecf-b7780838ebac', 5, '2025-2026', '2026-10-06 17:41:10.055888+00', 'ENROLLED');
INSERT INTO public.course_enrollments (id, college_id, student_id, course_id, semester, academic_year, enrolled_at, status) VALUES ('0d271c90-ce60-4259-b6b3-f42655c8037c', '773013e5-0ce8-4db7-b5af-af50bae06939', '66640a27-7c97-4eeb-aa97-61489348aaa7', '91adea4c-2cd0-4dcc-8186-d79004067832', 5, '2025-2026', '2026-10-06 17:41:10.055896+00', 'ENROLLED');
INSERT INTO public.course_enrollments (id, college_id, student_id, course_id, semester, academic_year, enrolled_at, status) VALUES ('66493f91-6c23-4d9f-a8df-00385def4e1b', '773013e5-0ce8-4db7-b5af-af50bae06939', '66640a27-7c97-4eeb-aa97-61489348aaa7', 'c07118ec-d07b-4c30-9321-f916b89497ac', 5, '2025-2026', '2026-10-06 17:41:10.055904+00', 'ENROLLED');
INSERT INTO public.course_enrollments (id, college_id, student_id, course_id, semester, academic_year, enrolled_at, status) VALUES ('db5b4931-a77a-45fa-9dac-8ee9e217ff4e', '773013e5-0ce8-4db7-b5af-af50bae06939', '5d1023c6-824e-4884-abe0-5523c828a0fc', '45ef449c-b929-4a74-aacd-4804f4527ce7', 5, '2025-2026', '2026-10-06 17:41:10.055912+00', 'ENROLLED');
INSERT INTO public.course_enrollments (id, college_id, student_id, course_id, semester, academic_year, enrolled_at, status) VALUES ('931c3f40-a080-4288-ad3f-5e9406b47d18', '773013e5-0ce8-4db7-b5af-af50bae06939', '5d1023c6-824e-4884-abe0-5523c828a0fc', '06d78cfd-323b-4e3f-aecf-b7780838ebac', 5, '2025-2026', '2026-10-06 17:41:10.05592+00', 'ENROLLED');
INSERT INTO public.course_enrollments (id, college_id, student_id, course_id, semester, academic_year, enrolled_at, status) VALUES ('95f51119-68da-48f6-9247-48fabd95216a', '773013e5-0ce8-4db7-b5af-af50bae06939', '5d1023c6-824e-4884-abe0-5523c828a0fc', '91adea4c-2cd0-4dcc-8186-d79004067832', 5, '2025-2026', '2026-10-06 17:41:10.055976+00', 'ENROLLED');
INSERT INTO public.course_enrollments (id, college_id, student_id, course_id, semester, academic_year, enrolled_at, status) VALUES ('95aee474-06af-4ac9-881d-66c72a9f7e0f', '773013e5-0ce8-4db7-b5af-af50bae06939', 'f9866f5f-6c28-45d9-b46c-6c76fa588068', '0b5df1e9-f9db-4412-a65a-c8fb71d6c0db', 5, '2025-2026', '2026-10-06 17:41:10.055987+00', 'ENROLLED');
INSERT INTO public.course_enrollments (id, college_id, student_id, course_id, semester, academic_year, enrolled_at, status) VALUES ('edf8a72e-86e7-4f5b-a419-bfd68991b40e', '773013e5-0ce8-4db7-b5af-af50bae06939', '35e360fd-7166-488e-a193-b0a1a997f633', 'a372a9dd-c988-4de6-9672-4c5a882e4a7a', 5, '2025-2026', '2026-10-06 17:41:10.055996+00', 'ENROLLED');


--
-- Data for Name: course_materials; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.course_materials (id, college_id, course_id, uploaded_by, title, description, material_type, file_url, file_size_kb, unit_module, created_at, updated_at) VALUES ('ad7f668c-fe3d-49a9-bbc5-20a226347da1', '773013e5-0ce8-4db7-b5af-af50bae06939', '45ef449c-b929-4a74-aacd-4804f4527ce7', '0ce413d1-8815-4239-8919-32ad41121836', 'Module 1: Advanced Binary Search Trees & AVL', 'Complete lecture slides and C++ code implementation for AVL Tree rotations.', 'SLIDES', 'https://cdn.acadnexa.edu/courses/cs501/mod1_avl_trees.pdf', 3450, 1, '2026-10-06 17:41:10.05845+00', '2026-10-06 17:41:10.05845+00');
INSERT INTO public.course_materials (id, college_id, course_id, uploaded_by, title, description, material_type, file_url, file_size_kb, unit_module, created_at, updated_at) VALUES ('3b50a9eb-3bdc-421f-9ca0-ee17926feb78', '773013e5-0ce8-4db7-b5af-af50bae06939', '45ef449c-b929-4a74-aacd-4804f4527ce7', '0ce413d1-8815-4239-8919-32ad41121836', 'Lab Sheet 1: Graph Traversal BFS & DFS Practice', 'Problem set covering Dijkstra algorithm, Prim-Kruskal, and Topological sorting.', 'LAB_MANUAL', 'https://cdn.acadnexa.edu/courses/cs501/lab_manual_graphs.pdf', 1820, 2, '2026-10-06 17:41:10.05918+00', '2026-10-06 17:41:10.05918+00');
INSERT INTO public.course_materials (id, college_id, course_id, uploaded_by, title, description, material_type, file_url, file_size_kb, unit_module, created_at, updated_at) VALUES ('dbf4721e-ad47-4d9b-ae49-c27241864ba3', '773013e5-0ce8-4db7-b5af-af50bae06939', '06d78cfd-323b-4e3f-aecf-b7780838ebac', 'adf210a7-9fc5-41d7-ba37-ad6c1c361261', 'DBMS Complete Syllabus & Course Handout', 'Official course blueprint, textbook references, lecture plan, and evaluation scheme.', 'SYLLABUS', 'https://cdn.acadnexa.edu/courses/cs502/dbms_syllabus_2026.pdf', 520, 1, '2026-10-06 17:41:10.0592+00', '2026-10-06 17:41:10.0592+00');
INSERT INTO public.course_materials (id, college_id, course_id, uploaded_by, title, description, material_type, file_url, file_size_kb, unit_module, created_at, updated_at) VALUES ('2d0f78c8-30af-4576-a68e-046dcdc220be', '773013e5-0ce8-4db7-b5af-af50bae06939', '06d78cfd-323b-4e3f-aecf-b7780838ebac', 'adf210a7-9fc5-41d7-ba37-ad6c1c361261', 'Module 2: Relational Algebra & SQL Joins Guide', 'Deep dive into 3NF, BCNF Normalization theorems, SQL subqueries and indexing.', 'PDF', 'https://cdn.acadnexa.edu/courses/cs502/mod2_sql_normalization.pdf', 4120, 2, '2026-10-06 17:41:10.059208+00', '2026-10-06 17:41:10.059208+00');
INSERT INTO public.course_materials (id, college_id, course_id, uploaded_by, title, description, material_type, file_url, file_size_kb, unit_module, created_at, updated_at) VALUES ('b196228f-b09f-451c-8308-27fbec2f37dc', '773013e5-0ce8-4db7-b5af-af50bae06939', '91adea4c-2cd0-4dcc-8186-d79004067832', 'adf210a7-9fc5-41d7-ba37-ad6c1c361261', 'Module 3: Deadlock Detection & Banker Algorithm', 'Detailed OS lecture notes covering thread race conditions and Peterson algorithm.', 'PDF', 'https://cdn.acadnexa.edu/courses/cs503/mod3_os_deadlocks.pdf', 2980, 3, '2026-10-06 17:41:10.059289+00', '2026-10-06 17:41:10.059289+00');
INSERT INTO public.course_materials (id, college_id, course_id, uploaded_by, title, description, material_type, file_url, file_size_kb, unit_module, created_at, updated_at) VALUES ('55b27882-86a7-4513-ad42-78cf90a34f65', '773013e5-0ce8-4db7-b5af-af50bae06939', 'c07118ec-d07b-4c30-9321-f916b89497ac', '11dd8d45-cb48-4041-88d2-cf3d12a4de63', 'Assignment 1: A* Search & Minimax Alpha-Beta Pruning', 'Hands-on Python assignment for game playing agent and heuristic path finding.', 'ASSIGNMENT', 'https://cdn.acadnexa.edu/courses/cs504/assignment1_search.pdf', 940, 1, '2026-10-06 17:41:10.059299+00', '2026-10-06 17:41:10.059299+00');
INSERT INTO public.course_materials (id, college_id, course_id, uploaded_by, title, description, material_type, file_url, file_size_kb, unit_module, created_at, updated_at) VALUES ('0116c1d5-697c-40f0-8f07-4e8c71035874', '773013e5-0ce8-4db7-b5af-af50bae06939', '0b5df1e9-f9db-4412-a65a-c8fb71d6c0db', '9089f3d2-8807-4fbb-ac8e-7d1d0874f119', 'VLSI Lab Manual: Cadence Virtuoso Simulation', 'Step-by-step schematic capture and layout DRC/LVS check guidelines for CMOS inverter.', 'LAB_MANUAL', 'https://cdn.acadnexa.edu/courses/ec501/vlsi_lab_cadence_guide.pdf', 5400, 1, '2026-10-06 17:41:10.059306+00', '2026-10-06 17:41:10.059306+00');


--
-- Data for Name: courses; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.courses (id, college_id, department_id, code, name, description, credits, semester, course_type, status, created_at, updated_at) VALUES ('45ef449c-b929-4a74-aacd-4804f4527ce7', '773013e5-0ce8-4db7-b5af-af50bae06939', '202c1550-5012-475f-a4ac-06fbcb139c93', 'CS501', 'Data Structures & Algorithms', 'In-depth study of trees, graphs, dynamic programming, sorting and hashing algorithms.', 4, 5, 'CORE', 'active', '2026-10-06 17:41:10.053406+00', '2026-10-06 17:41:10.053406+00');
INSERT INTO public.courses (id, college_id, department_id, code, name, description, credits, semester, course_type, status, created_at, updated_at) VALUES ('06d78cfd-323b-4e3f-aecf-b7780838ebac', '773013e5-0ce8-4db7-b5af-af50bae06939', '202c1550-5012-475f-a4ac-06fbcb139c93', 'CS502', 'Database Management Systems', 'Relational models, SQL, indexing, transaction processing, concurrency and NoSQL databases.', 4, 5, 'CORE', 'active', '2026-10-06 17:41:10.053898+00', '2026-10-06 17:41:10.053898+00');
INSERT INTO public.courses (id, college_id, department_id, code, name, description, credits, semester, course_type, status, created_at, updated_at) VALUES ('91adea4c-2cd0-4dcc-8186-d79004067832', '773013e5-0ce8-4db7-b5af-af50bae06939', '202c1550-5012-475f-a4ac-06fbcb139c93', 'CS503', 'Operating Systems & Architecture', 'Process scheduling, virtual memory, concurrency synchronization, file systems and Linux internals.', 3, 5, 'CORE', 'active', '2026-10-06 17:41:10.053925+00', '2026-10-06 17:41:10.053925+00');
INSERT INTO public.courses (id, college_id, department_id, code, name, description, credits, semester, course_type, status, created_at, updated_at) VALUES ('c07118ec-d07b-4c30-9321-f916b89497ac', '773013e5-0ce8-4db7-b5af-af50bae06939', '202c1550-5012-475f-a4ac-06fbcb139c93', 'CS504', 'Artificial Intelligence & ML', 'Foundational concepts in heuristic search, expert systems, neural nets and supervised learning.', 3, 5, 'ELECTIVE', 'active', '2026-10-06 17:41:10.053933+00', '2026-10-06 17:41:10.053933+00');
INSERT INTO public.courses (id, college_id, department_id, code, name, description, credits, semester, course_type, status, created_at, updated_at) VALUES ('a372a9dd-c988-4de6-9672-4c5a882e4a7a', '773013e5-0ce8-4db7-b5af-af50bae06939', '31afff72-03c6-4eb1-9656-3e03aec11c9b', 'IS501', 'Computer Networks & Protocols', 'TCP/IP architecture, routing algorithms, socket programming, network security.', 4, 5, 'CORE', 'active', '2026-10-06 17:41:10.053939+00', '2026-10-06 17:41:10.05394+00');
INSERT INTO public.courses (id, college_id, department_id, code, name, description, credits, semester, course_type, status, created_at, updated_at) VALUES ('0b5df1e9-f9db-4412-a65a-c8fb71d6c0db', '773013e5-0ce8-4db7-b5af-af50bae06939', '33ff183d-9c47-4bb1-956e-61a6d9ff6293', 'EC501', 'Digital VLSI Design & Verilog', 'CMOS logic, layout rules, ASIC design flow, timing analysis, and Verilog HDL synthesis.', 4, 5, 'CORE', 'active', '2026-10-06 17:41:10.053946+00', '2026-10-06 17:41:10.053946+00');


--
-- Data for Name: departments; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.departments (id, college_id, name, code, head_of_department, created_at, updated_at) VALUES ('202c1550-5012-475f-a4ac-06fbcb139c93', '773013e5-0ce8-4db7-b5af-af50bae06939', 'Computer Science & Engineering', 'CSE', 'Dr. Ramesh Sundaram', '2026-10-06 17:41:09.95763+00', '2026-10-06 17:41:09.95763+00');
INSERT INTO public.departments (id, college_id, name, code, head_of_department, created_at, updated_at) VALUES ('33ff183d-9c47-4bb1-956e-61a6d9ff6293', '773013e5-0ce8-4db7-b5af-af50bae06939', 'Electronics & Communication Engineering', 'ECE', 'Dr. Radhika Menon', '2026-10-06 17:41:09.958162+00', '2026-10-06 17:41:09.958162+00');
INSERT INTO public.departments (id, college_id, name, code, head_of_department, created_at, updated_at) VALUES ('31afff72-03c6-4eb1-9656-3e03aec11c9b', '773013e5-0ce8-4db7-b5af-af50bae06939', 'Information Science & Engineering', 'ISE', 'Dr. Anand Deshmukh', '2026-10-06 17:41:09.958191+00', '2026-10-06 17:41:09.958191+00');
INSERT INTO public.departments (id, college_id, name, code, head_of_department, created_at, updated_at) VALUES ('ccccda4b-1947-44d3-be07-ab8e7eb1b044', '773013e5-0ce8-4db7-b5af-af50bae06939', 'Mechanical Engineering', 'MECH', 'Dr. K. S. Murthy', '2026-10-06 17:41:09.958256+00', '2026-10-06 17:41:09.958256+00');
INSERT INTO public.departments (id, college_id, name, code, head_of_department, created_at, updated_at) VALUES ('664b1a67-c470-4191-b80d-43b1deeb27e0', '176ec9b8-0c53-4237-94ca-f83bf59cbfe4', 'Computer Science & Engineering', 'CSE', 'Dr. Arvind Swaminathan', '2026-10-06 17:41:09.958263+00', '2026-10-06 17:41:09.958263+00');
INSERT INTO public.departments (id, college_id, name, code, head_of_department, created_at, updated_at) VALUES ('3d208272-bd0f-4382-bf0d-679bc089b5b8', '176ec9b8-0c53-4237-94ca-f83bf59cbfe4', 'Electronics Engineering', 'ECE', 'Dr. Preeti Verma', '2026-10-06 17:41:09.958268+00', '2026-10-06 17:41:09.958268+00');


--
-- Data for Name: faculty; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.faculty (id, user_id, college_id, department_id, employee_code, designation, qualification, specialization, cabin_room, hire_date, created_at, updated_at) VALUES ('fc6d28d1-f9ec-4030-9a22-88a3a969b322', '859c23c1-83da-45a1-b3a6-d109ec1a5907', '773013e5-0ce8-4db7-b5af-af50bae06939', '202c1550-5012-475f-a4ac-06fbcb139c93', 'FAC-CSE-001', 'Professor & Head', 'Ph.D. in Distributed Systems (IIT Bombay)', 'Distributed Systems, Cloud Computing', 'CSE Block - Room 301', '2015-06-15', '2026-10-06 17:41:10.005908+00', '2026-10-06 17:41:10.005909+00');
INSERT INTO public.faculty (id, user_id, college_id, department_id, employee_code, designation, qualification, specialization, cabin_room, hire_date, created_at, updated_at) VALUES ('d6736b33-7cfc-4a72-b6c0-c021ec98f125', '0ce413d1-8815-4239-8919-32ad41121836', '773013e5-0ce8-4db7-b5af-af50bae06939', '202c1550-5012-475f-a4ac-06fbcb139c93', 'FAC-CSE-002', 'Associate Professor', 'M.Tech, Ph.D (IISc Bangalore)', 'Data Structures & Algorithms, Machine Learning', 'CSE Block - Room 305', '2018-08-01', '2026-10-06 17:41:10.006819+00', '2026-10-06 17:41:10.006819+00');
INSERT INTO public.faculty (id, user_id, college_id, department_id, employee_code, designation, qualification, specialization, cabin_room, hire_date, created_at, updated_at) VALUES ('bbd12708-bb2a-4b1d-ba05-5296d046b9a2', 'adf210a7-9fc5-41d7-ba37-ad6c1c361261', '773013e5-0ce8-4db7-b5af-af50bae06939', '202c1550-5012-475f-a4ac-06fbcb139c93', 'FAC-CSE-003', 'Assistant Professor', 'M.Tech in Software Engineering (NITK)', 'Database Management & OS', 'CSE Block - Room 204', '2021-01-10', '2026-10-06 17:41:10.006898+00', '2026-10-06 17:41:10.006898+00');
INSERT INTO public.faculty (id, user_id, college_id, department_id, employee_code, designation, qualification, specialization, cabin_room, hire_date, created_at, updated_at) VALUES ('4bc6cda5-5f39-4f43-8cbe-52c304e15a13', '9089f3d2-8807-4fbb-ac8e-7d1d0874f119', '773013e5-0ce8-4db7-b5af-af50bae06939', '33ff183d-9c47-4bb1-956e-61a6d9ff6293', 'FAC-ECE-001', 'Professor & Head', 'Ph.D. in Microelectronics (IIT Madras)', 'VLSI Design, Embedded IoT Systems', 'ECE Block - Room 402', '2016-04-12', '2026-10-06 17:41:10.006912+00', '2026-10-06 17:41:10.006912+00');
INSERT INTO public.faculty (id, user_id, college_id, department_id, employee_code, designation, qualification, specialization, cabin_room, hire_date, created_at, updated_at) VALUES ('7f354f1a-85bb-4e4f-aea6-6e6fe3a96620', '11dd8d45-cb48-4041-88d2-cf3d12a4de63', '773013e5-0ce8-4db7-b5af-af50bae06939', '31afff72-03c6-4eb1-9656-3e03aec11c9b', 'FAC-ISE-001', 'Professor', 'Ph.D. in AI (NUS Singapore)', 'Artificial Intelligence, Computer Networks', 'ISE Block - Room 108', '2017-09-20', '2026-10-06 17:41:10.00692+00', '2026-10-06 17:41:10.00692+00');


--
-- Data for Name: grades; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.grades (id, college_id, student_id, course_id, faculty_id, assessment_type, assessment_name, marks_obtained, max_marks, grade_letter, grade_point, semester, academic_year, remarks, evaluated_at, created_at, updated_at) VALUES ('812cccb2-4d96-483a-9829-a8b2369d64b2', '773013e5-0ce8-4db7-b5af-af50bae06939', 'a85d7016-d9f2-44ab-91c9-0a9a988d2ad6', '45ef449c-b929-4a74-aacd-4804f4527ce7', 'd6736b33-7cfc-4a72-b6c0-c021ec98f125', 'INTERNAL_1', 'CIE Test 1 (Trees & Graphs)', 28.50, 30.00, 'O', 10.00, 5, '2025-2026', 'Outstanding logical implementation', '2026-10-06 17:41:10.084047+00', '2026-10-06 17:41:10.084048+00', '2026-10-06 17:41:10.084048+00');
INSERT INTO public.grades (id, college_id, student_id, course_id, faculty_id, assessment_type, assessment_name, marks_obtained, max_marks, grade_letter, grade_point, semester, academic_year, remarks, evaluated_at, created_at, updated_at) VALUES ('8039f6a9-93ab-4eb0-99b7-a0b0929e7726', '773013e5-0ce8-4db7-b5af-af50bae06939', 'a85d7016-d9f2-44ab-91c9-0a9a988d2ad6', '45ef449c-b929-4a74-aacd-4804f4527ce7', 'd6736b33-7cfc-4a72-b6c0-c021ec98f125', 'INTERNAL_2', 'CIE Test 2 (Dynamic Programming)', 29.00, 30.00, 'O', 10.00, 5, '2025-2026', 'Flawless DP memoization proof', '2026-10-06 17:41:10.084659+00', '2026-10-06 17:41:10.084659+00', '2026-10-06 17:41:10.084659+00');
INSERT INTO public.grades (id, college_id, student_id, course_id, faculty_id, assessment_type, assessment_name, marks_obtained, max_marks, grade_letter, grade_point, semester, academic_year, remarks, evaluated_at, created_at, updated_at) VALUES ('e5038b84-52ba-400d-85d1-a32251994830', '773013e5-0ce8-4db7-b5af-af50bae06939', 'a85d7016-d9f2-44ab-91c9-0a9a988d2ad6', '45ef449c-b929-4a74-aacd-4804f4527ce7', 'd6736b33-7cfc-4a72-b6c0-c021ec98f125', 'LAB_VIVA', 'End Semester Lab Viva & Practical', 19.50, 20.00, 'O', 10.00, 5, '2025-2026', 'Clean code & algorithm walkthrough', '2026-10-06 17:41:10.084765+00', '2026-10-06 17:41:10.084765+00', '2026-10-06 17:41:10.084765+00');
INSERT INTO public.grades (id, college_id, student_id, course_id, faculty_id, assessment_type, assessment_name, marks_obtained, max_marks, grade_letter, grade_point, semester, academic_year, remarks, evaluated_at, created_at, updated_at) VALUES ('4991f471-68a5-48fd-9148-c2d57ee904a5', '773013e5-0ce8-4db7-b5af-af50bae06939', 'a85d7016-d9f2-44ab-91c9-0a9a988d2ad6', '45ef449c-b929-4a74-aacd-4804f4527ce7', 'd6736b33-7cfc-4a72-b6c0-c021ec98f125', 'FINAL_EXAM', 'Semester End University Theory Exam', 94.00, 100.00, 'O', 10.00, 5, '2025-2026', 'Highest score in department', '2026-10-06 17:41:10.084778+00', '2026-10-06 17:41:10.084778+00', '2026-10-06 17:41:10.084778+00');
INSERT INTO public.grades (id, college_id, student_id, course_id, faculty_id, assessment_type, assessment_name, marks_obtained, max_marks, grade_letter, grade_point, semester, academic_year, remarks, evaluated_at, created_at, updated_at) VALUES ('1ce2ff2f-bf4d-42c5-bda5-b982030776fe', '773013e5-0ce8-4db7-b5af-af50bae06939', 'a85d7016-d9f2-44ab-91c9-0a9a988d2ad6', '06d78cfd-323b-4e3f-aecf-b7780838ebac', 'bbd12708-bb2a-4b1d-ba05-5296d046b9a2', 'INTERNAL_1', 'CIE Test 1 (ER & Relational Algebra)', 27.00, 30.00, 'A+', 9.00, 5, '2025-2026', 'Strong relational queries', '2026-10-06 17:41:10.084787+00', '2026-10-06 17:41:10.084787+00', '2026-10-06 17:41:10.084787+00');
INSERT INTO public.grades (id, college_id, student_id, course_id, faculty_id, assessment_type, assessment_name, marks_obtained, max_marks, grade_letter, grade_point, semester, academic_year, remarks, evaluated_at, created_at, updated_at) VALUES ('b47a0a1d-ded9-4c10-9ce5-fb115b09a3e7', '773013e5-0ce8-4db7-b5af-af50bae06939', 'a85d7016-d9f2-44ab-91c9-0a9a988d2ad6', '06d78cfd-323b-4e3f-aecf-b7780838ebac', 'bbd12708-bb2a-4b1d-ba05-5296d046b9a2', 'INTERNAL_2', 'CIE Test 2 (Normalization & SQL)', 28.00, 30.00, 'O', 10.00, 5, '2025-2026', 'Mastered BCNF & SQL indexing', '2026-10-06 17:41:10.084795+00', '2026-10-06 17:41:10.084795+00', '2026-10-06 17:41:10.084795+00');
INSERT INTO public.grades (id, college_id, student_id, course_id, faculty_id, assessment_type, assessment_name, marks_obtained, max_marks, grade_letter, grade_point, semester, academic_year, remarks, evaluated_at, created_at, updated_at) VALUES ('ef17142e-7947-400e-aad2-c7b593dedbb6', '773013e5-0ce8-4db7-b5af-af50bae06939', 'a85d7016-d9f2-44ab-91c9-0a9a988d2ad6', '06d78cfd-323b-4e3f-aecf-b7780838ebac', 'bbd12708-bb2a-4b1d-ba05-5296d046b9a2', 'FINAL_EXAM', 'Semester End University Theory Exam', 91.00, 100.00, 'O', 10.00, 5, '2025-2026', 'Excellent performance', '2026-10-06 17:41:10.084803+00', '2026-10-06 17:41:10.084803+00', '2026-10-06 17:41:10.084803+00');
INSERT INTO public.grades (id, college_id, student_id, course_id, faculty_id, assessment_type, assessment_name, marks_obtained, max_marks, grade_letter, grade_point, semester, academic_year, remarks, evaluated_at, created_at, updated_at) VALUES ('437a28a0-2d15-4337-99f3-fafd43be33bd', '773013e5-0ce8-4db7-b5af-af50bae06939', '66640a27-7c97-4eeb-aa97-61489348aaa7', '45ef449c-b929-4a74-aacd-4804f4527ce7', 'd6736b33-7cfc-4a72-b6c0-c021ec98f125', 'INTERNAL_1', 'CIE Test 1 (Trees & Graphs)', 27.00, 30.00, 'A+', 9.00, 5, '2025-2026', 'Very good graph analysis', '2026-10-06 17:41:10.084811+00', '2026-10-06 17:41:10.084811+00', '2026-10-06 17:41:10.084812+00');
INSERT INTO public.grades (id, college_id, student_id, course_id, faculty_id, assessment_type, assessment_name, marks_obtained, max_marks, grade_letter, grade_point, semester, academic_year, remarks, evaluated_at, created_at, updated_at) VALUES ('73653317-16a0-4456-89ea-b02ea8d1ffe6', '773013e5-0ce8-4db7-b5af-af50bae06939', '66640a27-7c97-4eeb-aa97-61489348aaa7', '45ef449c-b929-4a74-aacd-4804f4527ce7', 'd6736b33-7cfc-4a72-b6c0-c021ec98f125', 'INTERNAL_2', 'CIE Test 2 (Dynamic Programming)', 26.50, 30.00, 'A+', 9.00, 5, '2025-2026', 'Well structured solutions', '2026-10-06 17:41:10.08482+00', '2026-10-06 17:41:10.08482+00', '2026-10-06 17:41:10.08482+00');
INSERT INTO public.grades (id, college_id, student_id, course_id, faculty_id, assessment_type, assessment_name, marks_obtained, max_marks, grade_letter, grade_point, semester, academic_year, remarks, evaluated_at, created_at, updated_at) VALUES ('fe170e23-481e-45ca-9048-ccc4d375dd77', '773013e5-0ce8-4db7-b5af-af50bae06939', '66640a27-7c97-4eeb-aa97-61489348aaa7', '45ef449c-b929-4a74-aacd-4804f4527ce7', 'd6736b33-7cfc-4a72-b6c0-c021ec98f125', 'FINAL_EXAM', 'Semester End University Theory Exam', 88.00, 100.00, 'A+', 9.00, 5, '2025-2026', 'Consistently high grade', '2026-10-06 17:41:10.084828+00', '2026-10-06 17:41:10.084828+00', '2026-10-06 17:41:10.084828+00');
INSERT INTO public.grades (id, college_id, student_id, course_id, faculty_id, assessment_type, assessment_name, marks_obtained, max_marks, grade_letter, grade_point, semester, academic_year, remarks, evaluated_at, created_at, updated_at) VALUES ('bacafe35-a64c-4fe1-913c-d7194097809c', '773013e5-0ce8-4db7-b5af-af50bae06939', '5d1023c6-824e-4884-abe0-5523c828a0fc', '45ef449c-b929-4a74-aacd-4804f4527ce7', 'd6736b33-7cfc-4a72-b6c0-c021ec98f125', 'INTERNAL_1', 'CIE Test 1 (Trees & Graphs)', 21.00, 30.00, 'B+', 7.00, 5, '2025-2026', 'Need to practice tree traversals more', '2026-10-06 17:41:10.084836+00', '2026-10-06 17:41:10.084836+00', '2026-10-06 17:41:10.084837+00');
INSERT INTO public.grades (id, college_id, student_id, course_id, faculty_id, assessment_type, assessment_name, marks_obtained, max_marks, grade_letter, grade_point, semester, academic_year, remarks, evaluated_at, created_at, updated_at) VALUES ('415bc13d-85d7-471a-ac5c-f08923f6dc38', '773013e5-0ce8-4db7-b5af-af50bae06939', '5d1023c6-824e-4884-abe0-5523c828a0fc', '45ef449c-b929-4a74-aacd-4804f4527ce7', 'd6736b33-7cfc-4a72-b6c0-c021ec98f125', 'INTERNAL_2', 'CIE Test 2 (Dynamic Programming)', 23.50, 30.00, 'A', 8.00, 5, '2025-2026', 'Noticeable improvement in DP', '2026-10-06 17:41:10.084844+00', '2026-10-06 17:41:10.084844+00', '2026-10-06 17:41:10.084845+00');
INSERT INTO public.grades (id, college_id, student_id, course_id, faculty_id, assessment_type, assessment_name, marks_obtained, max_marks, grade_letter, grade_point, semester, academic_year, remarks, evaluated_at, created_at, updated_at) VALUES ('ae274894-5a3f-47e6-a38a-3732eafd8252', '773013e5-0ce8-4db7-b5af-af50bae06939', '5d1023c6-824e-4884-abe0-5523c828a0fc', '45ef449c-b929-4a74-aacd-4804f4527ce7', 'd6736b33-7cfc-4a72-b6c0-c021ec98f125', 'FINAL_EXAM', 'Semester End University Theory Exam', 79.00, 100.00, 'A', 8.00, 5, '2025-2026', 'Good effort', '2026-10-06 17:41:10.084902+00', '2026-10-06 17:41:10.084902+00', '2026-10-06 17:41:10.084902+00');


--
-- Data for Name: students; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.students (id, user_id, college_id, department_id, roll_number, registration_no, current_semester, current_year, section, batch_year, cgpa, admission_date, guardian_name, guardian_phone, created_at, updated_at) VALUES ('a85d7016-d9f2-44ab-91c9-0a9a988d2ad6', '89baf284-a7f5-4727-8dc2-30a3c4ab4a86', '773013e5-0ce8-4db7-b5af-af50bae06939', '202c1550-5012-475f-a4ac-06fbcb139c93', '1AT23CS001', 'REG2023CSE001', 5, 3, 'A', '2023-2027', 9.42, '2023-08-01', 'Rajesh Sharma', '+91 98110 01101', '2026-10-06 17:41:10.050248+00', '2026-10-06 17:41:10.050248+00');
INSERT INTO public.students (id, user_id, college_id, department_id, roll_number, registration_no, current_semester, current_year, section, batch_year, cgpa, admission_date, guardian_name, guardian_phone, created_at, updated_at) VALUES ('66640a27-7c97-4eeb-aa97-61489348aaa7', '604b0cd3-9466-468a-a79d-98d38c05ae0e', '773013e5-0ce8-4db7-b5af-af50bae06939', '202c1550-5012-475f-a4ac-06fbcb139c93', '1AT23CS002', 'REG2023CSE002', 5, 3, 'A', '2023-2027', 9.15, '2023-08-01', 'Suresh Iyer', '+91 98110 01102', '2026-10-06 17:41:10.051+00', '2026-10-06 17:41:10.051+00');
INSERT INTO public.students (id, user_id, college_id, department_id, roll_number, registration_no, current_semester, current_year, section, batch_year, cgpa, admission_date, guardian_name, guardian_phone, created_at, updated_at) VALUES ('5d1023c6-824e-4884-abe0-5523c828a0fc', '7d6e7ee3-8b64-4be0-a8ed-16f398e6c728', '773013e5-0ce8-4db7-b5af-af50bae06939', '202c1550-5012-475f-a4ac-06fbcb139c93', '1AT23CS003', 'REG2023CSE003', 5, 3, 'A', '2023-2027', 8.78, '2023-08-01', 'Mahesh Kulkarni', '+91 98110 01103', '2026-10-06 17:41:10.051052+00', '2026-10-06 17:41:10.051052+00');
INSERT INTO public.students (id, user_id, college_id, department_id, roll_number, registration_no, current_semester, current_year, section, batch_year, cgpa, admission_date, guardian_name, guardian_phone, created_at, updated_at) VALUES ('8eb9c3f2-f076-480d-bc0a-5e101024fc0e', 'e8b0d633-6e22-46f4-ac3e-afa0e55e0fde', '773013e5-0ce8-4db7-b5af-af50bae06939', '202c1550-5012-475f-a4ac-06fbcb139c93', '1AT23CS004', 'REG2023CSE004', 5, 3, 'B', '2023-2027', 8.92, '2023-08-01', 'Nitin Patel', '+91 98110 01104', '2026-10-06 17:41:10.051178+00', '2026-10-06 17:41:10.051178+00');
INSERT INTO public.students (id, user_id, college_id, department_id, roll_number, registration_no, current_semester, current_year, section, batch_year, cgpa, admission_date, guardian_name, guardian_phone, created_at, updated_at) VALUES ('e7392734-df6b-46bc-8e2a-ee7791d7e437', 'c3533427-51ef-461a-8bb9-bfb3da03c840', '773013e5-0ce8-4db7-b5af-af50bae06939', '202c1550-5012-475f-a4ac-06fbcb139c93', '1AT23CS005', 'REG2023CSE005', 5, 3, 'B', '2023-2027', 7.85, '2023-08-01', 'Harish Singh', '+91 98110 01105', '2026-10-06 17:41:10.051216+00', '2026-10-06 17:41:10.051217+00');
INSERT INTO public.students (id, user_id, college_id, department_id, roll_number, registration_no, current_semester, current_year, section, batch_year, cgpa, admission_date, guardian_name, guardian_phone, created_at, updated_at) VALUES ('f9866f5f-6c28-45d9-b46c-6c76fa588068', 'd03b2337-e192-48ee-aa59-54ef66c57132', '773013e5-0ce8-4db7-b5af-af50bae06939', '33ff183d-9c47-4bb1-956e-61a6d9ff6293', '1AT23EC001', 'REG2023ECE001', 5, 3, 'A', '2023-2027', 9.05, '2023-08-01', 'Gopal Nair', '+91 98110 01106', '2026-10-06 17:41:10.05125+00', '2026-10-06 17:41:10.05125+00');
INSERT INTO public.students (id, user_id, college_id, department_id, roll_number, registration_no, current_semester, current_year, section, batch_year, cgpa, admission_date, guardian_name, guardian_phone, created_at, updated_at) VALUES ('985c11ff-663b-4c3e-9236-51fbe4cf2c54', '40e06baf-6144-48ae-95b2-3a78c1dfb501', '773013e5-0ce8-4db7-b5af-af50bae06939', '33ff183d-9c47-4bb1-956e-61a6d9ff6293', '1AT23EC002', 'REG2023ECE002', 5, 3, 'A', '2023-2027', 8.35, '2023-08-01', 'M. Raja', '+91 98110 01107', '2026-10-06 17:41:10.051283+00', '2026-10-06 17:41:10.051283+00');
INSERT INTO public.students (id, user_id, college_id, department_id, roll_number, registration_no, current_semester, current_year, section, batch_year, cgpa, admission_date, guardian_name, guardian_phone, created_at, updated_at) VALUES ('35e360fd-7166-488e-a193-b0a1a997f633', '18ce1cfc-2b48-411f-a9ec-bcdffb083a7d', '773013e5-0ce8-4db7-b5af-af50bae06939', '31afff72-03c6-4eb1-9656-3e03aec11c9b', '1AT23IS001', 'REG2023ISE001', 5, 3, 'A', '2023-2027', 9.50, '2023-08-01', 'Vinod Joshi', '+91 98110 01108', '2026-10-06 17:41:10.051315+00', '2026-10-06 17:41:10.051315+00');


--
-- Data for Name: timetable; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.timetable (id, college_id, department_id, course_id, faculty_id, day_of_week, start_time, end_time, room_number, section, session_type, semester, academic_year, created_at, updated_at) VALUES ('747d7900-5bc7-4209-a61e-15416db62128', '773013e5-0ce8-4db7-b5af-af50bae06939', '202c1550-5012-475f-a4ac-06fbcb139c93', '45ef449c-b929-4a74-aacd-4804f4527ce7', 'd6736b33-7cfc-4a72-b6c0-c021ec98f125', 1, '09:00:00', '10:00:00', 'LH-301', 'A', 'THEORY', 5, '2025-2026', '2026-10-06 17:41:10.069774+00', '2026-10-06 17:41:10.069774+00');
INSERT INTO public.timetable (id, college_id, department_id, course_id, faculty_id, day_of_week, start_time, end_time, room_number, section, session_type, semester, academic_year, created_at, updated_at) VALUES ('58a6cdcb-f64b-4189-9d0e-87212a29c219', '773013e5-0ce8-4db7-b5af-af50bae06939', '202c1550-5012-475f-a4ac-06fbcb139c93', '06d78cfd-323b-4e3f-aecf-b7780838ebac', 'bbd12708-bb2a-4b1d-ba05-5296d046b9a2', 1, '10:00:00', '11:00:00', 'LH-301', 'A', 'THEORY', 5, '2025-2026', '2026-10-06 17:41:10.070364+00', '2026-10-06 17:41:10.070364+00');
INSERT INTO public.timetable (id, college_id, department_id, course_id, faculty_id, day_of_week, start_time, end_time, room_number, section, session_type, semester, academic_year, created_at, updated_at) VALUES ('a56f8eff-c673-4e86-8254-706ec761c7fa', '773013e5-0ce8-4db7-b5af-af50bae06939', '202c1550-5012-475f-a4ac-06fbcb139c93', '91adea4c-2cd0-4dcc-8186-d79004067832', 'bbd12708-bb2a-4b1d-ba05-5296d046b9a2', 1, '11:15:00', '12:15:00', 'LH-301', 'A', 'THEORY', 5, '2025-2026', '2026-10-06 17:41:10.071113+00', '2026-10-06 17:41:10.071113+00');
INSERT INTO public.timetable (id, college_id, department_id, course_id, faculty_id, day_of_week, start_time, end_time, room_number, section, session_type, semester, academic_year, created_at, updated_at) VALUES ('4b1143e3-0347-48a7-8490-7403444c9c0a', '773013e5-0ce8-4db7-b5af-af50bae06939', '202c1550-5012-475f-a4ac-06fbcb139c93', 'c07118ec-d07b-4c30-9321-f916b89497ac', '7f354f1a-85bb-4e4f-aea6-6e6fe3a96620', 1, '13:15:00', '14:15:00', 'LH-301', 'A', 'THEORY', 5, '2025-2026', '2026-10-06 17:41:10.071149+00', '2026-10-06 17:41:10.071149+00');
INSERT INTO public.timetable (id, college_id, department_id, course_id, faculty_id, day_of_week, start_time, end_time, room_number, section, session_type, semester, academic_year, created_at, updated_at) VALUES ('38884bae-2ae2-40b4-889a-a5a73671d040', '773013e5-0ce8-4db7-b5af-af50bae06939', '202c1550-5012-475f-a4ac-06fbcb139c93', '45ef449c-b929-4a74-aacd-4804f4527ce7', 'd6736b33-7cfc-4a72-b6c0-c021ec98f125', 1, '14:15:00', '16:15:00', 'CS-LAB-2', 'A', 'LAB', 5, '2025-2026', '2026-10-06 17:41:10.071179+00', '2026-10-06 17:41:10.071179+00');
INSERT INTO public.timetable (id, college_id, department_id, course_id, faculty_id, day_of_week, start_time, end_time, room_number, section, session_type, semester, academic_year, created_at, updated_at) VALUES ('a774fa54-8557-45ef-8c52-ec88a3317853', '773013e5-0ce8-4db7-b5af-af50bae06939', '202c1550-5012-475f-a4ac-06fbcb139c93', '06d78cfd-323b-4e3f-aecf-b7780838ebac', 'bbd12708-bb2a-4b1d-ba05-5296d046b9a2', 2, '09:00:00', '10:00:00', 'LH-301', 'A', 'THEORY', 5, '2025-2026', '2026-10-06 17:41:10.071231+00', '2026-10-06 17:41:10.071231+00');
INSERT INTO public.timetable (id, college_id, department_id, course_id, faculty_id, day_of_week, start_time, end_time, room_number, section, session_type, semester, academic_year, created_at, updated_at) VALUES ('5e22337c-8397-4dde-9a0f-21fe634e6649', '773013e5-0ce8-4db7-b5af-af50bae06939', '202c1550-5012-475f-a4ac-06fbcb139c93', '45ef449c-b929-4a74-aacd-4804f4527ce7', 'd6736b33-7cfc-4a72-b6c0-c021ec98f125', 2, '10:00:00', '11:00:00', 'LH-301', 'A', 'THEORY', 5, '2025-2026', '2026-10-06 17:41:10.071267+00', '2026-10-06 17:41:10.071267+00');
INSERT INTO public.timetable (id, college_id, department_id, course_id, faculty_id, day_of_week, start_time, end_time, room_number, section, session_type, semester, academic_year, created_at, updated_at) VALUES ('02395dd4-917c-47b4-a4a6-92abb856e391', '773013e5-0ce8-4db7-b5af-af50bae06939', '202c1550-5012-475f-a4ac-06fbcb139c93', 'c07118ec-d07b-4c30-9321-f916b89497ac', '7f354f1a-85bb-4e4f-aea6-6e6fe3a96620', 2, '11:15:00', '12:15:00', 'LH-301', 'A', 'THEORY', 5, '2025-2026', '2026-10-06 17:41:10.0713+00', '2026-10-06 17:41:10.0713+00');
INSERT INTO public.timetable (id, college_id, department_id, course_id, faculty_id, day_of_week, start_time, end_time, room_number, section, session_type, semester, academic_year, created_at, updated_at) VALUES ('5af7714e-b8cb-4871-83f7-2d0ea7b6d531', '773013e5-0ce8-4db7-b5af-af50bae06939', '202c1550-5012-475f-a4ac-06fbcb139c93', '91adea4c-2cd0-4dcc-8186-d79004067832', 'bbd12708-bb2a-4b1d-ba05-5296d046b9a2', 2, '14:15:00', '16:15:00', 'OS-LAB-1', 'A', 'LAB', 5, '2025-2026', '2026-10-06 17:41:10.071333+00', '2026-10-06 17:41:10.071333+00');
INSERT INTO public.timetable (id, college_id, department_id, course_id, faculty_id, day_of_week, start_time, end_time, room_number, section, session_type, semester, academic_year, created_at, updated_at) VALUES ('e4531996-5e03-41d5-88d9-cb5b3d74af5f', '773013e5-0ce8-4db7-b5af-af50bae06939', '202c1550-5012-475f-a4ac-06fbcb139c93', '91adea4c-2cd0-4dcc-8186-d79004067832', 'bbd12708-bb2a-4b1d-ba05-5296d046b9a2', 3, '09:00:00', '10:00:00', 'LH-301', 'A', 'THEORY', 5, '2025-2026', '2026-10-06 17:41:10.071365+00', '2026-10-06 17:41:10.071365+00');
INSERT INTO public.timetable (id, college_id, department_id, course_id, faculty_id, day_of_week, start_time, end_time, room_number, section, session_type, semester, academic_year, created_at, updated_at) VALUES ('ac0e6a82-ed17-419e-ae45-f7342e6e56e0', '773013e5-0ce8-4db7-b5af-af50bae06939', '202c1550-5012-475f-a4ac-06fbcb139c93', '45ef449c-b929-4a74-aacd-4804f4527ce7', 'd6736b33-7cfc-4a72-b6c0-c021ec98f125', 3, '10:00:00', '11:00:00', 'LH-301', 'A', 'THEORY', 5, '2025-2026', '2026-10-06 17:41:10.071398+00', '2026-10-06 17:41:10.071398+00');
INSERT INTO public.timetable (id, college_id, department_id, course_id, faculty_id, day_of_week, start_time, end_time, room_number, section, session_type, semester, academic_year, created_at, updated_at) VALUES ('5685c701-713e-44ba-b58e-ffaaf340e69f', '773013e5-0ce8-4db7-b5af-af50bae06939', '202c1550-5012-475f-a4ac-06fbcb139c93', '06d78cfd-323b-4e3f-aecf-b7780838ebac', 'bbd12708-bb2a-4b1d-ba05-5296d046b9a2', 3, '11:15:00', '12:15:00', 'LH-301', 'A', 'THEORY', 5, '2025-2026', '2026-10-06 17:41:10.071481+00', '2026-10-06 17:41:10.071481+00');
INSERT INTO public.timetable (id, college_id, department_id, course_id, faculty_id, day_of_week, start_time, end_time, room_number, section, session_type, semester, academic_year, created_at, updated_at) VALUES ('d675532b-0d15-42d5-911e-113b8ba28c4e', '773013e5-0ce8-4db7-b5af-af50bae06939', '202c1550-5012-475f-a4ac-06fbcb139c93', 'c07118ec-d07b-4c30-9321-f916b89497ac', '7f354f1a-85bb-4e4f-aea6-6e6fe3a96620', 4, '09:00:00', '10:00:00', 'LH-301', 'A', 'THEORY', 5, '2025-2026', '2026-10-06 17:41:10.071536+00', '2026-10-06 17:41:10.071536+00');
INSERT INTO public.timetable (id, college_id, department_id, course_id, faculty_id, day_of_week, start_time, end_time, room_number, section, session_type, semester, academic_year, created_at, updated_at) VALUES ('7cf4e62b-4ad0-4987-a131-c7d36e7cc2eb', '773013e5-0ce8-4db7-b5af-af50bae06939', '202c1550-5012-475f-a4ac-06fbcb139c93', '91adea4c-2cd0-4dcc-8186-d79004067832', 'bbd12708-bb2a-4b1d-ba05-5296d046b9a2', 4, '10:00:00', '11:00:00', 'LH-301', 'A', 'THEORY', 5, '2025-2026', '2026-10-06 17:41:10.071637+00', '2026-10-06 17:41:10.071637+00');
INSERT INTO public.timetable (id, college_id, department_id, course_id, faculty_id, day_of_week, start_time, end_time, room_number, section, session_type, semester, academic_year, created_at, updated_at) VALUES ('cb123473-acb6-43a3-a74a-f6e2f025dc92', '773013e5-0ce8-4db7-b5af-af50bae06939', '202c1550-5012-475f-a4ac-06fbcb139c93', '06d78cfd-323b-4e3f-aecf-b7780838ebac', 'bbd12708-bb2a-4b1d-ba05-5296d046b9a2', 4, '14:15:00', '16:15:00', 'DB-LAB-3', 'A', 'LAB', 5, '2025-2026', '2026-10-06 17:41:10.071675+00', '2026-10-06 17:41:10.071675+00');
INSERT INTO public.timetable (id, college_id, department_id, course_id, faculty_id, day_of_week, start_time, end_time, room_number, section, session_type, semester, academic_year, created_at, updated_at) VALUES ('d3b6db0d-e059-4a27-8c10-cc45715acaaf', '773013e5-0ce8-4db7-b5af-af50bae06939', '202c1550-5012-475f-a4ac-06fbcb139c93', '45ef449c-b929-4a74-aacd-4804f4527ce7', 'd6736b33-7cfc-4a72-b6c0-c021ec98f125', 5, '09:00:00', '10:00:00', 'LH-301', 'A', 'THEORY', 5, '2025-2026', '2026-10-06 17:41:10.071713+00', '2026-10-06 17:41:10.071713+00');
INSERT INTO public.timetable (id, college_id, department_id, course_id, faculty_id, day_of_week, start_time, end_time, room_number, section, session_type, semester, academic_year, created_at, updated_at) VALUES ('e1aa3c7f-2fe2-4c8d-af10-85d49b9adf4e', '773013e5-0ce8-4db7-b5af-af50bae06939', '202c1550-5012-475f-a4ac-06fbcb139c93', 'c07118ec-d07b-4c30-9321-f916b89497ac', '7f354f1a-85bb-4e4f-aea6-6e6fe3a96620', 5, '10:00:00', '11:00:00', 'LH-301', 'A', 'THEORY', 5, '2025-2026', '2026-10-06 17:41:10.071745+00', '2026-10-06 17:41:10.071745+00');
INSERT INTO public.timetable (id, college_id, department_id, course_id, faculty_id, day_of_week, start_time, end_time, room_number, section, session_type, semester, academic_year, created_at, updated_at) VALUES ('7d4a449e-ff0e-47c8-b3b6-ffd5bf7767fe', '773013e5-0ce8-4db7-b5af-af50bae06939', '202c1550-5012-475f-a4ac-06fbcb139c93', '06d78cfd-323b-4e3f-aecf-b7780838ebac', 'bbd12708-bb2a-4b1d-ba05-5296d046b9a2', 5, '11:15:00', '12:15:00', 'LH-301', 'A', 'THEORY', 5, '2025-2026', '2026-10-06 17:41:10.071776+00', '2026-10-06 17:41:10.071777+00');


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.users (id, college_id, department_id, email, password_hash, full_name, phone_number, role, status, avatar_url, last_login_at, created_at, updated_at) VALUES ('aa7bca0e-8e88-40e3-a1b2-ff6a80cb745d', '176ec9b8-0c53-4237-94ca-f83bf59cbfe4', '664b1a67-c470-4191-b80d-43b1deeb27e0', 'admin@horizon.edu.in', '$2b$12$PcgVh63PAIBdXJsO.zSOUuNCbXS6b19nkO/8EWA3ZfhNIAS2VEs0.', 'Dr. S. K. Narayanan', '+91 98450 22334', 'ADMIN', 'active', NULL, '2026-10-12 17:00:05.205497+00', '2026-10-06 17:41:09.975185+00', '2026-10-12 17:00:05.213821+00');
INSERT INTO public.users (id, college_id, department_id, email, password_hash, full_name, phone_number, role, status, avatar_url, last_login_at, created_at, updated_at) VALUES ('604b0cd3-9466-468a-a79d-98d38c05ae0e', '773013e5-0ce8-4db7-b5af-af50bae06939', '202c1550-5012-475f-a4ac-06fbcb139c93', 'ananya.iyer@aitm.edu.in', '$2b$12$PcgVh63PAIBdXJsO.zSOUuNCbXS6b19nkO/8EWA3ZfhNIAS2VEs0.', 'Ananya Iyer', '+91 97110 10002', 'STUDENT', 'active', NULL, '2026-10-12 17:00:26.628664+00', '2026-10-06 17:41:10.019649+00', '2026-10-12 17:00:26.631054+00');
INSERT INTO public.users (id, college_id, department_id, email, password_hash, full_name, phone_number, role, status, avatar_url, last_login_at, created_at, updated_at) VALUES ('859c23c1-83da-45a1-b3a6-d109ec1a5907', '773013e5-0ce8-4db7-b5af-af50bae06939', '202c1550-5012-475f-a4ac-06fbcb139c93', 'ramesh.cs@aitm.edu.in', '$2b$12$PcgVh63PAIBdXJsO.zSOUuNCbXS6b19nkO/8EWA3ZfhNIAS2VEs0.', 'Dr. Ramesh Sundaram', '+91 98450 33445', 'FACULTY', 'active', NULL, NULL, '2026-10-06 17:41:09.983043+00', '2026-10-12 16:59:08.325352+00');
INSERT INTO public.users (id, college_id, department_id, email, password_hash, full_name, phone_number, role, status, avatar_url, last_login_at, created_at, updated_at) VALUES ('adf210a7-9fc5-41d7-ba37-ad6c1c361261', '773013e5-0ce8-4db7-b5af-af50bae06939', '202c1550-5012-475f-a4ac-06fbcb139c93', 'amit.verma@aitm.edu.in', '$2b$12$PcgVh63PAIBdXJsO.zSOUuNCbXS6b19nkO/8EWA3ZfhNIAS2VEs0.', 'Dr. Amit Verma', '+91 98450 55667', 'FACULTY', 'active', NULL, NULL, '2026-10-06 17:41:09.992856+00', '2026-10-12 16:59:08.325401+00');
INSERT INTO public.users (id, college_id, department_id, email, password_hash, full_name, phone_number, role, status, avatar_url, last_login_at, created_at, updated_at) VALUES ('9089f3d2-8807-4fbb-ac8e-7d1d0874f119', '773013e5-0ce8-4db7-b5af-af50bae06939', '33ff183d-9c47-4bb1-956e-61a6d9ff6293', 'radhika.ece@aitm.edu.in', '$2b$12$PcgVh63PAIBdXJsO.zSOUuNCbXS6b19nkO/8EWA3ZfhNIAS2VEs0.', 'Dr. Radhika Menon', '+91 98450 66778', 'FACULTY', 'active', NULL, NULL, '2026-10-06 17:41:09.99879+00', '2026-10-12 16:59:08.325409+00');
INSERT INTO public.users (id, college_id, department_id, email, password_hash, full_name, phone_number, role, status, avatar_url, last_login_at, created_at, updated_at) VALUES ('11dd8d45-cb48-4041-88d2-cf3d12a4de63', '773013e5-0ce8-4db7-b5af-af50bae06939', '31afff72-03c6-4eb1-9656-3e03aec11c9b', 'anand.deshmukh@aitm.edu.in', '$2b$12$PcgVh63PAIBdXJsO.zSOUuNCbXS6b19nkO/8EWA3ZfhNIAS2VEs0.', 'Dr. Anand Deshmukh', '+91 98450 77889', 'FACULTY', 'active', NULL, NULL, '2026-10-06 17:41:10.003563+00', '2026-10-12 16:59:08.325414+00');
INSERT INTO public.users (id, college_id, department_id, email, password_hash, full_name, phone_number, role, status, avatar_url, last_login_at, created_at, updated_at) VALUES ('7d6e7ee3-8b64-4be0-a8ed-16f398e6c728', '773013e5-0ce8-4db7-b5af-af50bae06939', '202c1550-5012-475f-a4ac-06fbcb139c93', 'rohan.kulkarni@aitm.edu.in', '$2b$12$PcgVh63PAIBdXJsO.zSOUuNCbXS6b19nkO/8EWA3ZfhNIAS2VEs0.', 'Rohan Kulkarni', '+91 97110 10003', 'STUDENT', 'active', NULL, NULL, '2026-10-06 17:41:10.024301+00', '2026-10-12 16:59:08.325422+00');
INSERT INTO public.users (id, college_id, department_id, email, password_hash, full_name, phone_number, role, status, avatar_url, last_login_at, created_at, updated_at) VALUES ('e8b0d633-6e22-46f4-ac3e-afa0e55e0fde', '773013e5-0ce8-4db7-b5af-af50bae06939', '202c1550-5012-475f-a4ac-06fbcb139c93', 'sneha.patel@aitm.edu.in', '$2b$12$PcgVh63PAIBdXJsO.zSOUuNCbXS6b19nkO/8EWA3ZfhNIAS2VEs0.', 'Sneha Patel', '+91 97110 10004', 'STUDENT', 'active', NULL, NULL, '2026-10-06 17:41:10.029132+00', '2026-10-12 16:59:08.325427+00');
INSERT INTO public.users (id, college_id, department_id, email, password_hash, full_name, phone_number, role, status, avatar_url, last_login_at, created_at, updated_at) VALUES ('c3533427-51ef-461a-8bb9-bfb3da03c840', '773013e5-0ce8-4db7-b5af-af50bae06939', '202c1550-5012-475f-a4ac-06fbcb139c93', 'vikram.singh@aitm.edu.in', '$2b$12$PcgVh63PAIBdXJsO.zSOUuNCbXS6b19nkO/8EWA3ZfhNIAS2VEs0.', 'Vikram Aditya Singh', '+91 97110 10005', 'STUDENT', 'active', NULL, NULL, '2026-10-06 17:41:10.034633+00', '2026-10-12 16:59:08.325431+00');
INSERT INTO public.users (id, college_id, department_id, email, password_hash, full_name, phone_number, role, status, avatar_url, last_login_at, created_at, updated_at) VALUES ('d03b2337-e192-48ee-aa59-54ef66c57132', '773013e5-0ce8-4db7-b5af-af50bae06939', '33ff183d-9c47-4bb1-956e-61a6d9ff6293', 'diya.nair@aitm.edu.in', '$2b$12$PcgVh63PAIBdXJsO.zSOUuNCbXS6b19nkO/8EWA3ZfhNIAS2VEs0.', 'Diya Nair', '+91 97110 10006', 'STUDENT', 'active', NULL, NULL, '2026-10-06 17:41:10.039299+00', '2026-10-12 16:59:08.325435+00');
INSERT INTO public.users (id, college_id, department_id, email, password_hash, full_name, phone_number, role, status, avatar_url, last_login_at, created_at, updated_at) VALUES ('40e06baf-6144-48ae-95b2-3a78c1dfb501', '773013e5-0ce8-4db7-b5af-af50bae06939', '33ff183d-9c47-4bb1-956e-61a6d9ff6293', 'karthik.raja@aitm.edu.in', '$2b$12$PcgVh63PAIBdXJsO.zSOUuNCbXS6b19nkO/8EWA3ZfhNIAS2VEs0.', 'Karthik Raja', '+91 97110 10007', 'STUDENT', 'active', NULL, NULL, '2026-10-06 17:41:10.043857+00', '2026-10-12 16:59:08.32544+00');
INSERT INTO public.users (id, college_id, department_id, email, password_hash, full_name, phone_number, role, status, avatar_url, last_login_at, created_at, updated_at) VALUES ('18ce1cfc-2b48-411f-a9ec-bcdffb083a7d', '773013e5-0ce8-4db7-b5af-af50bae06939', '31afff72-03c6-4eb1-9656-3e03aec11c9b', 'meera.joshi@aitm.edu.in', '$2b$12$PcgVh63PAIBdXJsO.zSOUuNCbXS6b19nkO/8EWA3ZfhNIAS2VEs0.', 'Meera Joshi', '+91 97110 10008', 'STUDENT', 'active', NULL, NULL, '2026-10-06 17:41:10.048749+00', '2026-10-12 16:59:08.325444+00');
INSERT INTO public.users (id, college_id, department_id, email, password_hash, full_name, phone_number, role, status, avatar_url, last_login_at, created_at, updated_at) VALUES ('0ce413d1-8815-4239-8919-32ad41121836', '773013e5-0ce8-4db7-b5af-af50bae06939', '202c1550-5012-475f-a4ac-06fbcb139c93', 'priya.sharma@aitm.edu.in', '$2b$12$PcgVh63PAIBdXJsO.zSOUuNCbXS6b19nkO/8EWA3ZfhNIAS2VEs0.', 'Prof. Priya Sharma', '+91 98450 44556', 'FACULTY', 'active', NULL, '2026-10-13 13:39:32.514287+00', '2026-10-06 17:41:09.988069+00', '2026-10-13 13:39:32.514527+00');
INSERT INTO public.users (id, college_id, department_id, email, password_hash, full_name, phone_number, role, status, avatar_url, last_login_at, created_at, updated_at) VALUES ('11fa2ab2-d290-412f-a2aa-fccb7e2d6778', '773013e5-0ce8-4db7-b5af-af50bae06939', '202c1550-5012-475f-a4ac-06fbcb139c93', 'admin@aitm.edu.in', '$2b$12$PcgVh63PAIBdXJsO.zSOUuNCbXS6b19nkO/8EWA3ZfhNIAS2VEs0.', 'Prof. Vikramaditya Rao', '+91 98450 11223', 'ADMIN', 'active', NULL, '2026-10-13 14:08:46.416861+00', '2026-10-06 17:41:09.968909+00', '2026-10-13 14:08:46.426693+00');
INSERT INTO public.users (id, college_id, department_id, email, password_hash, full_name, phone_number, role, status, avatar_url, last_login_at, created_at, updated_at) VALUES ('89baf284-a7f5-4727-8dc2-30a3c4ab4a86', '773013e5-0ce8-4db7-b5af-af50bae06939', '202c1550-5012-475f-a4ac-06fbcb139c93', 'aarav.sharma@aitm.edu.in', '$2b$12$PcgVh63PAIBdXJsO.zSOUuNCbXS6b19nkO/8EWA3ZfhNIAS2VEs0.', 'Aarav Sharma', '+91 97110 10001', 'STUDENT', 'active', NULL, '2026-10-13 08:39:10.587321+00', '2026-10-06 17:41:10.014588+00', '2026-10-13 08:39:10.58923+00');


--
-- Name: academic_calendar academic_calendar_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.academic_calendar
    ADD CONSTRAINT academic_calendar_pkey PRIMARY KEY (id);


--
-- Name: admins admins_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admins
    ADD CONSTRAINT admins_pkey PRIMARY KEY (id);


--
-- Name: admins admins_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admins
    ADD CONSTRAINT admins_user_id_key UNIQUE (user_id);


--
-- Name: announcements announcements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcements
    ADD CONSTRAINT announcements_pkey PRIMARY KEY (id);


--
-- Name: attendance attendance_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance
    ADD CONSTRAINT attendance_pkey PRIMARY KEY (id);


--
-- Name: colleges colleges_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.colleges
    ADD CONSTRAINT colleges_code_key UNIQUE (code);


--
-- Name: colleges colleges_domain_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.colleges
    ADD CONSTRAINT colleges_domain_key UNIQUE (domain);


--
-- Name: colleges colleges_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.colleges
    ADD CONSTRAINT colleges_pkey PRIMARY KEY (id);


--
-- Name: colleges colleges_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.colleges
    ADD CONSTRAINT colleges_slug_key UNIQUE (slug);


--
-- Name: course_enrollments course_enrollments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.course_enrollments
    ADD CONSTRAINT course_enrollments_pkey PRIMARY KEY (id);


--
-- Name: course_materials course_materials_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.course_materials
    ADD CONSTRAINT course_materials_pkey PRIMARY KEY (id);


--
-- Name: courses courses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.courses
    ADD CONSTRAINT courses_pkey PRIMARY KEY (id);


--
-- Name: departments departments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT departments_pkey PRIMARY KEY (id);


--
-- Name: faculty faculty_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.faculty
    ADD CONSTRAINT faculty_pkey PRIMARY KEY (id);


--
-- Name: faculty faculty_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.faculty
    ADD CONSTRAINT faculty_user_id_key UNIQUE (user_id);


--
-- Name: grades grades_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grades
    ADD CONSTRAINT grades_pkey PRIMARY KEY (id);


--
-- Name: students students_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_pkey PRIMARY KEY (id);


--
-- Name: students students_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_user_id_key UNIQUE (user_id);


--
-- Name: timetable timetable_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.timetable
    ADD CONSTRAINT timetable_pkey PRIMARY KEY (id);


--
-- Name: courses uq_courses_college_code; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.courses
    ADD CONSTRAINT uq_courses_college_code UNIQUE (college_id, code);


--
-- Name: departments uq_departments_college_code; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT uq_departments_college_code UNIQUE (college_id, code);


--
-- Name: course_enrollments uq_enrollments_student_course_year; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.course_enrollments
    ADD CONSTRAINT uq_enrollments_student_course_year UNIQUE (student_id, course_id, academic_year);


--
-- Name: faculty uq_faculty_college_code; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.faculty
    ADD CONSTRAINT uq_faculty_college_code UNIQUE (college_id, employee_code);


--
-- Name: attendance uq_student_course_date_timetable; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance
    ADD CONSTRAINT uq_student_course_date_timetable UNIQUE (student_id, course_id, attendance_date, timetable_id);


--
-- Name: students uq_students_college_regno; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT uq_students_college_regno UNIQUE (college_id, registration_no);


--
-- Name: students uq_students_college_roll; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT uq_students_college_roll UNIQUE (college_id, roll_number);


--
-- Name: users uq_users_college_email; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT uq_users_college_email UNIQUE (college_id, email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: idx_admins_college; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_admins_college ON public.admins USING btree (college_id);


--
-- Name: idx_announcements_target; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_announcements_target ON public.announcements USING btree (college_id, target_role, created_at DESC);


--
-- Name: idx_attendance_student; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_attendance_student ON public.attendance USING btree (student_id, course_id, attendance_date);


--
-- Name: idx_calendar_dates; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_calendar_dates ON public.academic_calendar USING btree (college_id, start_date, end_date);


--
-- Name: idx_colleges_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_colleges_code ON public.colleges USING btree (code);


--
-- Name: idx_courses_college_dept; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_courses_college_dept ON public.courses USING btree (college_id, department_id, semester);


--
-- Name: idx_courses_dept; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_courses_dept ON public.courses USING btree (college_id, department_id, semester);


--
-- Name: idx_departments_college; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_departments_college ON public.departments USING btree (college_id);


--
-- Name: idx_enrollments_course; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_enrollments_course ON public.course_enrollments USING btree (course_id);


--
-- Name: idx_enrollments_student; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_enrollments_student ON public.course_enrollments USING btree (student_id);


--
-- Name: idx_faculty_college_dept; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_faculty_college_dept ON public.faculty USING btree (college_id, department_id);


--
-- Name: idx_faculty_dept; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_faculty_dept ON public.faculty USING btree (college_id, department_id);


--
-- Name: idx_grades_student; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_grades_student ON public.grades USING btree (student_id, course_id);


--
-- Name: idx_materials_course; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_materials_course ON public.course_materials USING btree (course_id);


--
-- Name: idx_students_college_dept; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_students_college_dept ON public.students USING btree (college_id, department_id, current_semester);


--
-- Name: idx_students_dept; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_students_dept ON public.students USING btree (college_id, department_id, current_semester);


--
-- Name: idx_timetable_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_timetable_lookup ON public.timetable USING btree (college_id, department_id, semester, day_of_week);


--
-- Name: idx_users_college_dept; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_college_dept ON public.users USING btree (college_id, department_id);


--
-- Name: idx_users_college_role; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_college_role ON public.users USING btree (college_id, role);


--
-- Name: announcements trg_announcements_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_announcements_updated_at BEFORE UPDATE ON public.announcements FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: colleges trg_colleges_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_colleges_updated_at BEFORE UPDATE ON public.colleges FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: course_materials trg_course_materials_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_course_materials_updated_at BEFORE UPDATE ON public.course_materials FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: courses trg_courses_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_courses_updated_at BEFORE UPDATE ON public.courses FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: departments trg_departments_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_departments_updated_at BEFORE UPDATE ON public.departments FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: faculty trg_faculty_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_faculty_updated_at BEFORE UPDATE ON public.faculty FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: grades trg_grades_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_grades_updated_at BEFORE UPDATE ON public.grades FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: students trg_students_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_students_updated_at BEFORE UPDATE ON public.students FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: timetable trg_timetable_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_timetable_updated_at BEFORE UPDATE ON public.timetable FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: users trg_users_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: academic_calendar academic_calendar_college_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.academic_calendar
    ADD CONSTRAINT academic_calendar_college_id_fkey FOREIGN KEY (college_id) REFERENCES public.colleges(id) ON DELETE CASCADE;


--
-- Name: admins admins_college_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admins
    ADD CONSTRAINT admins_college_id_fkey FOREIGN KEY (college_id) REFERENCES public.colleges(id) ON DELETE CASCADE;


--
-- Name: admins admins_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admins
    ADD CONSTRAINT admins_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: announcements announcements_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcements
    ADD CONSTRAINT announcements_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: announcements announcements_college_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcements
    ADD CONSTRAINT announcements_college_id_fkey FOREIGN KEY (college_id) REFERENCES public.colleges(id) ON DELETE CASCADE;


--
-- Name: announcements announcements_department_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcements
    ADD CONSTRAINT announcements_department_id_fkey FOREIGN KEY (department_id) REFERENCES public.departments(id) ON DELETE SET NULL;


--
-- Name: attendance attendance_college_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance
    ADD CONSTRAINT attendance_college_id_fkey FOREIGN KEY (college_id) REFERENCES public.colleges(id) ON DELETE CASCADE;


--
-- Name: attendance attendance_course_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance
    ADD CONSTRAINT attendance_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.courses(id) ON DELETE CASCADE;


--
-- Name: attendance attendance_marked_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance
    ADD CONSTRAINT attendance_marked_by_fkey FOREIGN KEY (marked_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: attendance attendance_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance
    ADD CONSTRAINT attendance_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(id) ON DELETE CASCADE;


--
-- Name: attendance attendance_timetable_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance
    ADD CONSTRAINT attendance_timetable_id_fkey FOREIGN KEY (timetable_id) REFERENCES public.timetable(id) ON DELETE SET NULL;


--
-- Name: course_enrollments course_enrollments_college_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.course_enrollments
    ADD CONSTRAINT course_enrollments_college_id_fkey FOREIGN KEY (college_id) REFERENCES public.colleges(id) ON DELETE CASCADE;


--
-- Name: course_enrollments course_enrollments_course_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.course_enrollments
    ADD CONSTRAINT course_enrollments_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.courses(id) ON DELETE CASCADE;


--
-- Name: course_enrollments course_enrollments_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.course_enrollments
    ADD CONSTRAINT course_enrollments_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(id) ON DELETE CASCADE;


--
-- Name: course_materials course_materials_college_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.course_materials
    ADD CONSTRAINT course_materials_college_id_fkey FOREIGN KEY (college_id) REFERENCES public.colleges(id) ON DELETE CASCADE;


--
-- Name: course_materials course_materials_course_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.course_materials
    ADD CONSTRAINT course_materials_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.courses(id) ON DELETE CASCADE;


--
-- Name: course_materials course_materials_uploaded_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.course_materials
    ADD CONSTRAINT course_materials_uploaded_by_fkey FOREIGN KEY (uploaded_by) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: courses courses_college_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.courses
    ADD CONSTRAINT courses_college_id_fkey FOREIGN KEY (college_id) REFERENCES public.colleges(id) ON DELETE CASCADE;


--
-- Name: courses courses_department_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.courses
    ADD CONSTRAINT courses_department_id_fkey FOREIGN KEY (department_id) REFERENCES public.departments(id) ON DELETE CASCADE;


--
-- Name: departments departments_college_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT departments_college_id_fkey FOREIGN KEY (college_id) REFERENCES public.colleges(id) ON DELETE CASCADE;


--
-- Name: faculty faculty_college_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.faculty
    ADD CONSTRAINT faculty_college_id_fkey FOREIGN KEY (college_id) REFERENCES public.colleges(id) ON DELETE CASCADE;


--
-- Name: faculty faculty_department_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.faculty
    ADD CONSTRAINT faculty_department_id_fkey FOREIGN KEY (department_id) REFERENCES public.departments(id) ON DELETE CASCADE;


--
-- Name: faculty faculty_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.faculty
    ADD CONSTRAINT faculty_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: grades grades_college_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grades
    ADD CONSTRAINT grades_college_id_fkey FOREIGN KEY (college_id) REFERENCES public.colleges(id) ON DELETE CASCADE;


--
-- Name: grades grades_course_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grades
    ADD CONSTRAINT grades_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.courses(id) ON DELETE CASCADE;


--
-- Name: grades grades_faculty_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grades
    ADD CONSTRAINT grades_faculty_id_fkey FOREIGN KEY (faculty_id) REFERENCES public.faculty(id) ON DELETE RESTRICT;


--
-- Name: grades grades_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grades
    ADD CONSTRAINT grades_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(id) ON DELETE CASCADE;


--
-- Name: students students_college_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_college_id_fkey FOREIGN KEY (college_id) REFERENCES public.colleges(id) ON DELETE CASCADE;


--
-- Name: students students_department_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_department_id_fkey FOREIGN KEY (department_id) REFERENCES public.departments(id) ON DELETE CASCADE;


--
-- Name: students students_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: timetable timetable_college_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.timetable
    ADD CONSTRAINT timetable_college_id_fkey FOREIGN KEY (college_id) REFERENCES public.colleges(id) ON DELETE CASCADE;


--
-- Name: timetable timetable_course_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.timetable
    ADD CONSTRAINT timetable_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.courses(id) ON DELETE CASCADE;


--
-- Name: timetable timetable_department_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.timetable
    ADD CONSTRAINT timetable_department_id_fkey FOREIGN KEY (department_id) REFERENCES public.departments(id) ON DELETE CASCADE;


--
-- Name: timetable timetable_faculty_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.timetable
    ADD CONSTRAINT timetable_faculty_id_fkey FOREIGN KEY (faculty_id) REFERENCES public.faculty(id) ON DELETE RESTRICT;


--
-- Name: users users_college_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_college_id_fkey FOREIGN KEY (college_id) REFERENCES public.colleges(id) ON DELETE CASCADE;


--
-- Name: users users_department_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_department_id_fkey FOREIGN KEY (department_id) REFERENCES public.departments(id) ON DELETE SET NULL;


--
-- PostgreSQL database dump complete
--

