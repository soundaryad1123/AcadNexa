# AcadNexa

## Master Implementation & Execution Plan

**Document:** Implementation_Plan
**Project:** AcadNexa
**Reference:** Functional Requirements Specification (SRS)
**Phase:** Execution & Development

---

# PHASE 1 — SYSTEM ARCHITECTURE & ENVIRONMENT SETUP
**Objective:** Establish the foundation, technology stack, and database schemas based on the defined entities.

### 1.1 Technology Stack Definition
*   **Database:** PostgreSQL (Ideal for relational entities like Student, Faculty, Grades) or MongoDB (If flexible document structures are preferred for Course Materials).
*   **Backend:** Node.js with Express.js (or Python/Django, Java/Spring Boot).
*   **Frontend:** React.js or Next.js (for fast, component-based role dashboards).
*   **Authentication:** JSON Web Tokens (JWT) for stateless, role-based session management.

### 1.2 Database Schema Design (Ref: SRS Step 7)
Create the exact tables/collections mapping to the Master Entity List:
1.  `Users` (Base table with Role Enum: ADMIN, FACULTY, STUDENT)
2.  `Students` (ENT-01) - Links to Users
3.  `Faculty` (ENT-02) - Links to Users
4.  `Attendance` (ENT-03, ENT-04) - Includes type (Student/Faculty), date, status, course_id.
5.  `Timetable` (ENT-05) - Master schedule linking faculty, students, time, and courses.
6.  `Grades` (ENT-06) - Links student_id, course_id, assessment_name, score.
7.  `Course_Materials` (ENT-07) - Links faculty_id, course_id, file_url.
8.  `Announcements` (ENT-08) - Global feed posts.
9.  `Academic_Calendar` (ENT-09) - Events, holidays, exam dates.

---

# PHASE 2 — BACKEND & API DEVELOPMENT (SPRINTS)
**Objective:** Build the RESTful API routes mapped exactly to the Actions defined in SRS Step 4.

### Sprint 2.1: Authentication & Role-Based Access Control (RBAC)
*   **Deliverable:** Login endpoint issuing JWTs.
*   **Security:** Middleware to enforce role boundaries (e.g., `verifyAdmin`, `verifyFaculty`, `verifyStudent`).

### Sprint 2.2: Administrative APIs (Ref: ADM-01 to ADM-03)
*   `GET /api/attendance/students/aggregate` (College-wide average)
*   `GET /api/attendance/faculty` (Faculty attendance records)
*   `POST /api/announcements` (Create global notices)

### Sprint 2.3: Faculty Operations APIs (Ref: FAC-01 to FAC-06)
*   `POST /api/attendance/students` (Record daily attendance)
*   `GET /api/timetable/faculty/:id` (View teaching schedule)
*   `GET /api/attendance/students/course/:id` (View assigned class metrics)
*   `POST /api/grades` (Upload scores)
*   `POST /api/materials` (Upload digital resources)

### Sprint 2.4: Student Access APIs (Ref: STD-01 to STD-06)
*   `GET /api/attendance/student/:id` (Personal attendance)
*   `GET /api/timetable/student/:id` (Personal class schedule)
*   `GET /api/grades/student/:id` (Personal progress reports)
*   `GET /api/materials/course/:id` (Download materials)
*   `GET /api/calendar` (Upcoming exams & holidays)
*   `GET /api/announcements` (View global feed)

---

# PHASE 3 — FRONTEND UI/UX DEVELOPMENT
**Objective:** Build isolated interfaces for the three primary agents defined in SRS Step 2.

### 3.1 Common UI Components
*   Login Screen (Role routing based on credentials).
*   Global Announcement Feed Component.
*   Navigation Sidebar (Renders links dynamically based on user role).

### 3.2 The Admin Portal
*   **Dashboard:** High-level metrics (Total Students, Aggregate Attendance Chart).
*   **Notice Board Manager:** WYSIWYG editor to draft and publish announcements.
*   **Faculty Monitor:** Data table displaying faculty attendance logs.

### 3.3 The Faculty Portal
*   **My Schedule:** Daily timetable view showing assigned classes.
*   **Classroom Manager:** 
    *   Toggle interface for marking student attendance.
    *   Form to input/upload CSV of student grades.
    *   File upload dropzone for course materials.
*   **Metrics View:** Graphical view of attendance averages for their specific classes.

### 3.4 The Student Portal
*   **My Hub:** Summary cards showing upcoming exams, recent grades, and today's timetable.
*   **Academics Tab:** Detailed view of personal attendance records and subject-wise grades.
*   **Resource Center:** Downloadable list of course materials grouped by subject.
*   **Calendar View:** Visual monthly calendar highlighting holidays and exam dates.

---

# PHASE 4 — TESTING & VALIDATION
**Objective:** Ensure all requirements are met without scope creep or security flaws.

| Test Category | Description | Target |
| :--- | :--- | :--- |
| **Unit Testing** | Test individual API endpoints for correct responses. | Core logic, calculations |
| **Integration Testing** | Verify database writes/reads match frontend requests. | DB constraints |
| **Security/RBAC Testing** | Ensure a Student *cannot* access `POST /api/grades`. | Middleware security |
| **Traceability Check** | Verify every ID (ADM-01 to STD-06) works in the UI. | SRS Alignment |

---

# PHASE 5 — DEPLOYMENT & HANDOVER
**Objective:** Push EduNexa to a live production environment.

### 5.1 Infrastructure Setup
*   **Cloud Hosting:** AWS (EC2/RDS), Vercel (Frontend), or Render/Heroku (Backend).
*   **Storage:** AWS S3 or Cloudinary for storing `Course Materials` and attachments.
*   **Domain & SSL:** Configure custom domain with HTTPS for secure data transmission.

### 5.2 CI/CD Pipeline
*   Set up GitHub Actions to automatically test and deploy code when merged into the `main` branch.

### 5.3 System Handover
*   Generate API Documentation (using Swagger/Postman).
*   Provide Admin credentials for initial system access.
*   Sign-off against the original SRS document.