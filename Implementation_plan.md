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
  * Every tenant corresponds to a unique `Tenant` / `College` entity (`tenant_id`).
* **Data Isolation Strategy:**
  * **Partitioned Relational Storage:** Every database table (Users, Smart ID Profiles, Attendance Logs, Timetables, Assessments, Alerts) enforces a mandatory indexed foreign key `tenant_id`.
  * **Database-Level Protection:** PostgreSQL Row-Level Security (RLS) policies or FastAPI scoped DB session middleware ensuring queries automatically filter by the authenticated session's `tenant_id`.
  * **Stateless Multi-Tenant JWTs:** Tokens encode `user_id`, `role`, and `tenant_id`. FastAPI dependency injection validates that incoming requests can never query or mutate data belonging to other tenants.
* **Hierarchical Role Model:**
  * **Super Admin (Platform Level):** Onboards colleges/tenants, manages platform health and subscriptions.
  * **College Admin (AG-01):** Manages campus-wide entities within their specific tenant (Smart ID assignments, master timetable, aggregate attendance, announcements).
  * **Faculty (AG-02):** Scoped strictly to their college's classes, assigned lab sessions, and student evaluations.
  * **Student (AG-03):** Scoped strictly to their personal records within their college.

### 2. Docker-First Development Environment (Strict Rule 2)
The development and production environments are strictly containerized using **Docker** and **Docker Compose** across three distinct containers:

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
┌──────────────┐  │                        │ PostgreSQL  │  │
│ Hardware/IoT │─►│───────────────────────►│ (Database)  │  │
│ Attendance   │  │                        └─────────────┘  │
└──────────────┘  │                         Container 3     │
                  └─────────────────────────────────────────┘
```

* **Container 1: `frontend` (Next.js)**
  * Next.js App Router with TypeScript and Vanilla/Tailored CSS.
  * Mounted volume for hot-reloading in dev (`/app`).
  * Communicates internally with the backend container and externally via port 3000.
* **Container 2: `backend` (FastAPI)**
  * Python 3.11+ with Uvicorn, Pydantic v2, and SQLAlchemy 2.0 (async).
  * Auto-reloading volume mount (`/app`), exposed on port 8000.
  * Handles multi-tenant resolution, RBAC, IoT hardware attendance endpoints, and business logic.
* **Container 3: `database` (PostgreSQL)**
  * PostgreSQL 16 Alpine container with a persistent named Docker volume (`postgres_data`).
  * Automated migration runner (Alembic) hooked into backend startup.
  * Healthcheck-gated dependency (`depends_on: db: condition: service_healthy`).

---

# PHASE 1 — ENVIRONMENT SETUP & MULTI-TENANT FOUNDATION
**Objective:** Establish containerized infrastructure, multi-tenant database schemas, and configuration.

### 1.1 Docker Compose & Service Orchestration
* Create root `docker-compose.yml` and `docker-compose.override.yml` for local development.
* Configure environment variables via `.env.example` (`POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `SECRET_KEY`, `TENANT_DOMAINS`).
* Set up Dockerfiles for `frontend` (Node 20 Alpine) and `backend` (Python 3.11 Slim) with optimized multi-stage builds.

### 1.2 Multi-Tenant Database Schema (PostgreSQL & SQLAlchemy)
All tables strictly include `tenant_id` foreign keys indexed for isolation:

1. **`tenants`** — `id (UUID)`, `name`, `slug`, `domain`, `is_active`, `created_at`
2. **`users` (ENT-01)** — `id (UUID)`, `tenant_id`, `email`, `hashed_password`, `full_name`, `role (ADMIN, FACULTY, STUDENT)`, `department`, `is_active`
3. **`smart_id_profiles` (ENT-02)** — `id (UUID)`, `tenant_id`, `user_id`, `card_uid` (Hardware RFID/NFC UID), `hardware_node_id`, `status (ACTIVE, SUSPENDED, LOST)`, `assigned_at`
4. **`attendance_logs` (ENT-03)** — `id (UUID)`, `tenant_id`, `user_id`, `session_id` (links to Timetable), `timestamp`, `source (IOT_SCAN, MANUAL_OVERRIDE)`, `status (PRESENT, ABSENT, LATE)`, `verified_by`
5. **`timetables` (ENT-04)** — `id (UUID)`, `tenant_id`, `course_code`, `course_name`, `session_type (THEORY, LAB)`, `faculty_id`, `room_number`, `day_of_week`, `start_time`, `end_time`
6. **`assessment_records` (ENT-05)** — `id (UUID)`, `tenant_id`, `student_id`, `course_code`, `assessment_name`, `score`, `max_score`, `evaluated_by`, `evaluated_at`
7. **`alerts` (ENT-06)** — `id (UUID)`, `tenant_id`, `author_id`, `title`, `message`, `target_role (ALL, FACULTY, STUDENT)`, `priority`, `created_at`

---

# PHASE 2 — BACKEND & MULTI-TENANT API DEVELOPMENT (FASTAPI)
**Objective:** Build high-performance, tenant-isolated REST APIs and hardware ingestion routes.

### Sprint 2.1: Multi-Tenant Middleware & RBAC Security
* **Tenant Context Middleware:** Extract and validate tenant from host header / JWT; inject tenant-scoped DB session into request context.
* **Authentication Engine:** `/api/v1/auth/login` issuing tenant-scoped JWTs with role verification.
* **Security Dependencies:** `get_current_user`, `require_role(["ADMIN", "FACULTY", "STUDENT"])`, `verify_tenant_match`.

### Sprint 2.2: IoT Attendance & Hardware Ingestion APIs (Ref: ENT-02, ENT-03)
* `POST /api/v1/hardware/scan` — High-throughput endpoint for campus hardware scanners / Smart ID readers to stream card scans with hardware API key and tenant validation.
* `GET /api/v1/admin/cards` & `POST /api/v1/admin/cards/assign` — Admin Smart ID profile provisioning (ADM-01).
* `GET /api/v1/student/cards/status` — Student Smart ID card active status verification (STD-04).

### Sprint 2.3: Admin Operations APIs (Ref: ADM-01 to ADM-04)
* `GET /api/v1/admin/attendance/aggregate` — Real-time campus-wide attendance rollups (ADM-02).
* `POST /api/v1/admin/alerts` & `GET /api/v1/alerts` — Broadcast department/campus alerts (ADM-03).
* `POST /api/v1/admin/timetable` & `PUT /api/v1/admin/timetable/{id}` — Master scheduling for theory and lab sessions (ADM-04).

### Sprint 2.4: Faculty Operations APIs (Ref: FAC-01 to FAC-05)
* `GET /api/v1/faculty/attendance/sessions` — Automated attendance logs for assigned sessions (FAC-01).
* `PUT /api/v1/faculty/attendance/override` — Manual attendance override for exceptions (FAC-02).
* `POST /api/v1/faculty/assessments` — Record/upload assessment scores and project evaluations (FAC-03).
* `GET /api/v1/faculty/timetable` — Personal teaching and lab supervision timetable (FAC-04).
* `GET /api/v1/alerts` — Department-wide alerts feed (FAC-05).

### Sprint 2.5: Student Access APIs (Ref: STD-01 to STD-05)
* `GET /api/v1/student/attendance` — Personal attendance logs & dynamic shortage calculation (STD-01).
* `GET /api/v1/student/timetable` — Combined personal theory & lab session timetable (STD-02).
* `GET /api/v1/student/assessments` — Academic scores, evaluations & computed semester progress (STD-03).
* `GET /api/v1/student/card` — Assigned Smart ID Card status (STD-04).
* `GET /api/v1/alerts` — Department notifications feed (STD-05).

---

# PHASE 3 — FRONTEND PORTAL DEVELOPMENT (NEXT.JS)
**Objective:** Create modern, responsive, role-differentiated interfaces with dynamic data visualization.

### 3.1 Design System & Shell Architecture
* **Theme & Styling:** Curated design system (dark/light themes, glassmorphism, responsive grid layout).
* **Multi-Tenant Context Provider:** Tenant branding and active role state management.
* **Navigation & Guards:** Dynamic sidebar and route guards enforcing tenant & role authorization.

### 3.2 The Admin Portal (`/admin`)
* **Live Campus Dashboard:** Real-time IoT attendance stats, active scans counter, and student/faculty summaries.
* **Smart ID Provisioning Hub:** Card-to-user pairing interface with status toggles (Active / Inactive / Lost).
* **Master Timetable Planner:** Interactive scheduling grid for theory and lab session allocation.
* **Notice Broadcast Center:** Rich-text alert composer targeting specific roles or entire campus.

### 3.3 The Faculty Portal (`/faculty`)
* **Teaching & Lab Timetable:** Weekly/daily interactive schedule view.
* **Session Attendance Manager:** Real-time log of automated scans during assigned class times with 1-click manual override controls.
* **Assessment & Gradebook:** Interface for entering project grades, midterm/final scores, and batch CSV imports.
* **Alerts Feed:** Department announcements and priority notices.

### 3.4 The Student Portal (`/student`)
* **Academic Command Center:** Personal attendance dial/progress bar with dynamic threshold alerts (<75% shortage warnings).
* **Personal Timetable:** Unified schedule for theory classes and laboratory batches.
* **Grade & Evaluation Tracker:** Visual breakdown of semester assessments and performance trends.
* **Smart ID Badge Widget:** Live digital representation of the physical card status and hardware sync.
* **Campus Alerts Stream:** Filterable notifications feed.

---

# PHASE 4 — TESTING, MULTI-TENANT ISOLATION & VALIDATION
**Objective:** Ensure zero cross-tenant data leakage, strict container reliability, and functional completeness.

| Test Category | Description | Target |
| :--- | :--- | :--- |
| **Multi-Tenant Isolation Test** | Verify Tenant A cannot read/mutate Tenant B data under any condition. | 100% Data Isolation |
| **RBAC Security Testing** | Verify Students/Faculty cannot call Admin or cross-role endpoints. | 403 Forbidden enforcement |
| **IoT Ingestion Benchmark** | Load-test the `/hardware/scan` endpoint for simulated concurrent card taps. | <50ms latency |
| **Docker Compose Smoke Test** | Fresh `docker compose up --build` brings all 3 containers up cleanly. | Zero startup errors |
| **SRS Requirement Traceability** | Automated end-to-end tests validating ADM-01..04, FAC-01..05, STD-01..05. | 100% PRD Coverage |

---

# PHASE 5 — DEPLOYMENT & PRODUCTION READINESS
**Objective:** Deploy the multi-tenant AcadNexa ecosystem with robust CI/CD and monitoring.

### 5.1 Containerized Production Deployment
* Multi-stage production `Dockerfile` configurations with minimal footprint.
* Production `docker-compose.prod.yml` or Kubernetes deployment manifests.
* Reverse proxy / Ingress configuration (Nginx / Traefik) handling tenant wildcards (`*.acadnexa.com`) and SSL termination.

### 5.2 CI/CD & Automated Verification
* GitHub Actions pipeline for linting, type-checking, multi-tenant isolation unit tests, and Docker image builds.
* Automated database migration checks (`alembic upgrade head`) on container startup.