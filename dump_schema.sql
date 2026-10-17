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

