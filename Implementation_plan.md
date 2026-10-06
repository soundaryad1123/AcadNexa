# AcadNexa

## Master Implementation & Execution Plan

**Document:** Implementation_Plan  
**Project:** AcadNexa  
**Reference:** Functional Requirements Specification (SRS / PRD)  
**Phase:** Execution & Architecture Blueprint  

---

## 🏛️ CORE ARCHITECTURAL CONSTRAINTS & PRINCIPLES

### 1. Multi-Tenant Architecture (Strict Rule 1)
* **Zero-Leakage Multi-Tenancy:** A single deployed instance securely serves multiple colleges/institutions in total isolation.
* **Tenant Identification & Resolution:**
  * Requests are resolved by subdomain (`<college-slug>.acadnexa.com`), custom domain, or `X-Tenant-ID` header.
  * Every tenant corresponds to a unique `College` entity (`college_id`).
* **Data Isolation Strategy:**
  * **Partitioned Relational Storage:** Every database table (Users, Departments, Courses, Enrollments, Attendance Logs, Timetables, Assessments, Alerts) enforces a mandatory indexed foreign key `college_id`.
  * **Database-Level Protection:** PostgreSQL Row-Level Security (RLS) policies and FastAPI scoped DB session middleware ensuring queries automatically filter by the authenticated session's `college_id`.
  * **Stateless Multi-Tenant JWTs:** Tokens encode `user_id`, `role`, and `college_id`. FastAPI dependency injection validates that incoming requests can never query or mutate data belonging to other tenants.
* **Hierarchical Role Model:**
  * **Super Admin (Platform Level):** Onboards colleges, manages platform health and subscriptions.
  * **College Admin (AG-01):** Manages campus-wide entities within their specific college (user accounts, master timetable, aggregate attendance, announcements).
  * **Faculty (AG-02):** Scoped strictly to their college's classes, assigned lab sessions, class attendance, and student evaluations.
  * **Student (AG-03):** Scoped strictly to their personal records, attendance, and grades within their college.

### 2. Docker-First Development Environment (Strict Rule 2)
The development and production environments are strictly containerized using **Docker** and **Docker Compose** across three distinct services:

```
                  ┌─────────────────────────────────────────┐
                  │          Docker Bridge Network          │
                  │                                         │
┌──────────────┐  │  ┌──────────────┐      ┌─────────────┐  │
│ Host Browser │─►│  │   Next.js    │─────►│   FastAPI   │  │
│  (Port 3000) │  │  │  (Frontend)  │      │  (Backend)  │  │
└──────────────┘  │  └──────────────┘      └──────┬──────┘  │
                  │   Container 1                 │         │
                  │                        Port 8000        │
                  │                               ▼         │
                  │                        ┌─────────────┐  │
                  │                        │ PostgreSQL  │  │
                  │                        │ (Database)  │  │
                  │                        └─────────────┘  │
                  │                         Container 3     │
                  └─────────────────────────────────────────┘
```

* **Container 1: `frontend` (Next.js)**
  * Next.js App Router with TypeScript and Vanilla/Tailored CSS.
  * Mounted volume for hot-reloading in dev (`/app`).
  * Communicates internally with the backend container and externally via port 3000.
* **Container 2: `backend` (FastAPI)**
  * Python 3.11+ with Uvicorn, Pydantic v2, and SQLAlchemy 2.0 (async).
  * Auto-reloading volume mount (`/app`), exposed on port 8000.
  * Handles multi-tenant resolution, RBAC, digital attendance logging, and business logic.
* **Container 3: `database` (PostgreSQL)**
  * PostgreSQL 16 Alpine container with a persistent named Docker volume (`postgres_data`).
  * Automated migration runner (Alembic) hooked into backend startup.
  * Healthcheck-gated dependency (`depends_on: db: condition: service_healthy`).

---

# PHASE 1 — ENVIRONMENT SETUP & MULTI-TENANT FOUNDATION
**Objective:** Establish containerized infrastructure, multi-tenant database schemas, and configuration.

### 1.1 Docker Compose & Service Orchestration
* Create root `docker-compose.yml` for local development.
* Configure environment variables via `.env.example` (`POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `SECRET_KEY`).
* Set up Dockerfiles for `frontend` (Node 20 Alpine) and `backend` (Python 3.11 Slim).

### 1.2 Multi-Tenant Database Schema (PostgreSQL & SQLAlchemy)
All tables strictly include `college_id` foreign keys indexed for isolation:

1. **`colleges`** — `id (UUID)`, `name`, `slug`, `domain`, `status`, `created_at`
2. **`departments`** — `id (UUID)`, `college_id`, `name`, `code`, `created_at`
3. **`users` (ENT-01)** — `id (UUID)`, `college_id`, `department_id`, `email`, `password_hash`, `full_name`, `role (ADMIN, FACULTY, STUDENT)`, `identifier_number`, `status`
4. **`courses`** — `id (UUID)`, `college_id`, `department_id`, `code`, `name`, `credits`, `semester`, `status`
5. **`course_enrollments` (ENT-02)** — `id (UUID)`, `college_id`, `student_id`, `course_id`, `batch_name`, `academic_year`
6. **`timetables` (ENT-04)** — `id (UUID)`, `college_id`, `course_id`, `faculty_id`, `session_type (THEORY, LAB)`, `room_number`, `day_of_week`, `start_time`, `end_time`
7. **`attendance_logs` (ENT-03)** — `id (UUID)`, `college_id`, `user_id`, `timetable_id`, `timestamp`, `source (PORTAL_ENTRY, MANUAL_OVERRIDE)`, `status (PRESENT, ABSENT, LATE)`, `verified_by`
8. **`assessment_records` (ENT-05)** — `id (UUID)`, `college_id`, `student_id`, `course_id`, `assessment_name`, `score`, `max_score`, `evaluated_by`, `evaluated_at`
9. **`alerts` (ENT-06)** — `id (UUID)`, `college_id`, `author_id`, `title`, `message`, `target_role (ALL, FACULTY, STUDENT)`, `priority`, `created_at`

---

# PHASE 2 — BACKEND & MULTI-TENANT API DEVELOPMENT (FASTAPI)
**Objective:** Build high-performance, tenant-isolated REST APIs.

### Sprint 2.1: Multi-Tenant Middleware & RBAC Security
* **Tenant Context Middleware:** Extract and validate tenant from host header / JWT; inject tenant-scoped DB session into request context.
* **Authentication Engine:** `/api/v1/auth/login` issuing tenant-scoped JWTs with role verification.
* **Security Dependencies:** `get_current_user`, `require_role(["ADMIN", "FACULTY", "STUDENT"])`, `verify_tenant_match`.

### Sprint 2.2: Admin Operations APIs (Ref: ADM-01 to ADM-04)
* `GET /api/v1/admin/users` & `POST /api/v1/admin/users` — User onboarding and role management.
* `GET /api/v1/admin/attendance/summary` & `GET /api/v1/admin/attendance/logs` — Real-time attendance aggregate monitoring (ADM-02).
* `POST /api/v1/admin/alerts` & `GET /api/v1/admin/alerts` — Institutional announcements & alert broadcasts (ADM-03).
* `GET /api/v1/admin/timetables` & `POST /api/v1/admin/timetables` — Master theory and lab session scheduling (ADM-04).

### Sprint 2.3: Faculty Operations APIs (Ref: FAC-01 to FAC-05)
* `GET /api/v1/faculty/sessions/current` & `POST /api/v1/faculty/sessions/{id}/attendance` — Session attendance tracking (FAC-01).
* `POST /api/v1/faculty/attendance/override` — Manual attendance adjustments and exception overrides (FAC-02).
* `POST /api/v1/faculty/assessments` & `GET /api/v1/faculty/courses/{id}/assessments` — Academic evaluation grade entry (FAC-03).
* `GET /api/v1/faculty/timetable` — Personal weekly teaching timetable (FAC-04).
* `GET /api/v1/faculty/alerts` — Department announcements feed (FAC-05).

### Sprint 2.4: Student Operations APIs (Ref: STD-01 to STD-05)
* `GET /api/v1/student/attendance` & `GET /api/v1/student/attendance/shortage-check` — Personal attendance logs & dynamic $< 75\%$ shortage alert calculation (STD-01).
* `GET /api/v1/student/timetable` — Combined personalized theory & lab session timetable (STD-02).
* `GET /api/v1/student/assessments` — Evaluation scores and semester progress tracking (STD-03).
* `GET /api/v1/student/profile` — Academic profile and enrollment status (STD-04).
* `GET /api/v1/student/alerts` — Campus announcements and departmental alerts feed (STD-05).

---

# PHASE 3 — FRONTEND DEVELOPMENT (NEXT.JS)
**Objective:** Create responsive, high-aesthetic web portals for Admin, Faculty, and Student personas.

### Sprint 3.1: Design System & Authentication
* Implement modern, role-adaptive theme with custom CSS design tokens.
* Multi-tenant login page with college slug resolution and JWT token management.

### Sprint 3.2: Admin Dashboard (AG-01)
* User & department management interface.
* Master timetable scheduler with visual grid and conflict detection.
* Attendance analytics dashboard with department filters.
* Broadcast alert composer with priority tags.

### Sprint 3.3: Faculty Portal (AG-02)
* Live session attendance sheet with one-click Present/Absent marking.
* Attendance exception override modal with reason logging.
* Assessment grading sheet with score validation.
* Weekly timetable schedule view.

### Sprint 3.4: Student Portal (AG-03)
* Personal dashboard with attendance gauge and dynamic shortage alert indicator.
* Interactive class & lab timetable.
* Semester grade report card.
* Department announcements feed.

---

# PHASE 4 — TESTING, POLISHING & DEPLOYMENT
**Objective:** End-to-end multi-tenant validation, performance tuning, and documentation.

1. Multi-tenant isolation testing (cross-tenant access prevention).
2. End-to-end API integration tests.
3. Production Docker Compose deployment verification.