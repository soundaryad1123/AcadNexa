# AcadNexa — API Specification Document

**Document:** API_Specification  
**System:** AcadNexa (IoT-Integrated Multi-Tenant Campus Management System)  
**Standard:** RESTful JSON API (FastAPI)  
**Base URL:** `https://{college-slug}.acadnexa.com/api/v1` or `http://localhost:8000/api/v1` (with `X-Tenant-ID` header)  
**Authentication:** JWT Bearer Token (`Authorization: Bearer <token>`) with RBAC & Scoped Multi-Tenant Isolation  

---

## 1. Authentication & System Foundation

| Route | Feature Fulfilled | Database Table(s) | Interaction Details |
| :--- | :--- | :--- | :--- |
| `POST /api/v1/auth/login` | User authentication across all roles | `users`, `colleges` | `SELECT` on `users` filtering by `college_id` and `email`; verifies password hash; `UPDATE users SET last_login_at = NOW()` |
| `GET /api/v1/auth/me` | Current authenticated profile & active session | `users`, `departments`, `colleges` | `SELECT` on `users` with `JOIN departments` and `JOIN colleges` by authenticated `user_id` and `college_id` |

---

## 2. IoT Hardware Ingestion (Card Reader & Gate Scanners)

| Route | Feature Fulfilled | Database Table(s) | Interaction Details |
| :--- | :--- | :--- | :--- |
| `POST /api/v1/hardware/scan` | **Hardware-Software Handshake (PRD Step 10.1):** Real-time automated attendance logging from physical RFID/NFC campus readers | `hardware_nodes`, `smart_id_profiles`, `users`, `timetables`, `attendance_logs` | 1. `SELECT` from `hardware_nodes` verifying `api_key_hash` & `college_id`; updates `last_heartbeat`<br>2. `SELECT` from `smart_id_profiles` by `card_uid` & `college_id` to resolve `user_id`<br>3. `SELECT` from `timetables` to resolve active session based on current time, day of week, and room<br>4. `INSERT` into `attendance_logs` (`source = 'IOT_SCAN'`, `status = 'PRESENT'`) |

---

## 3. Admin Portal (AG-01)

| Route | Feature Fulfilled | Database Table(s) | Interaction Details |
| :--- | :--- | :--- | :--- |
| `GET /api/v1/admin/cards` | **ADM-01:** View all registered Smart ID cards and their assigned users | `smart_id_profiles`, `users`, `departments` | `SELECT` on `smart_id_profiles` with `LEFT JOIN users` and `LEFT JOIN departments` filtered by `college_id` |
| `POST /api/v1/admin/cards/assign` | **ADM-01:** Register and assign a Smart ID Card (RFID/NFC) to a student or faculty | `smart_id_profiles`, `users` | `INSERT` / `UPSERT` into `smart_id_profiles` (`user_id`, `card_uid`, `card_type`, `assigned_by`, `status = 'active'`) scoped by `college_id` |
| `PATCH /api/v1/admin/cards/{card_id}/status` | **ADM-01:** Update card lifecycle status (Active, Suspended, Lost, Expired) | `smart_id_profiles` | `UPDATE` on `smart_id_profiles` setting `status` and `updated_at` where `id = :card_id` and `college_id = :college_id` |
| `GET /api/v1/admin/attendance/summary` | **ADM-02:** View real-time, campus-wide aggregated attendance metrics & trends | `attendance_logs`, `users`, `departments`, `timetables` | `SELECT` aggregation (`COUNT`, `GROUP BY department_id, date, status`) on `attendance_logs` scoped by `college_id` |
| `GET /api/v1/admin/attendance/logs` | **ADM-02:** Filter and search real-time campus attendance logs with pagination | `attendance_logs`, `users`, `timetables`, `hardware_nodes` | `SELECT` on `attendance_logs` with `JOIN users`, `JOIN timetables`, and `JOIN hardware_nodes` filtered by date range, department, and source |
| `POST /api/v1/admin/alerts` | **ADM-03:** Publish department-wide or campus-wide alerts and notifications | `alerts`, `users` | `INSERT` into `alerts` (`college_id`, `author_id`, `title`, `message`, `target_role`, `department_id`, `priority`, `expires_at`) |
| `GET /api/v1/admin/alerts` | **ADM-03:** View all published alerts and active notice broadcasts | `alerts`, `users`, `departments` | `SELECT` on `alerts` with `JOIN users (author)` and `LEFT JOIN departments` ordered by `created_at DESC` |
| `DELETE /api/v1/admin/alerts/{alert_id}` | **ADM-03:** Archive or delete an active alert broadcast | `alerts` | `DELETE` from `alerts` where `id = :alert_id` and `college_id = :college_id` |
| `GET /api/v1/admin/timetables` | **ADM-04:** View master institutional schedule across all rooms, courses, and faculty | `timetables`, `courses`, `users`, `departments` | `SELECT` on `timetables` with `JOIN courses` and `JOIN users (faculty)` filtered by `academic_year`, `department_id`, and `day_of_week` |
| `POST /api/v1/admin/timetables` | **ADM-04:** Create a new master schedule block for theory or laboratory sessions | `timetables`, `courses`, `users` | `INSERT` into `timetables` (`college_id`, `course_id`, `faculty_id`, `session_type`, `room_number`, `batch_name`, `day_of_week`, `start_time`, `end_time`, `academic_year`) |
| `PUT /api/v1/admin/timetables/{timetable_id}` | **ADM-04:** Update room allocation, timing, or instructor for a schedule block | `timetables` | `UPDATE` on `timetables` setting new time slots, room, faculty, or batch where `id = :timetable_id` and `college_id = :college_id` |
| `DELETE /api/v1/admin/timetables/{timetable_id}` | **ADM-04:** Remove a scheduled theory or lab class block | `timetables` | `DELETE` from `timetables` where `id = :timetable_id` and `college_id = :college_id` |
| `GET /api/v1/admin/hardware/nodes` | Hardware node registry & health diagnostics | `hardware_nodes` | `SELECT` on `hardware_nodes` filtered by `college_id` displaying live heartbeat status and room location |
| `POST /api/v1/admin/hardware/nodes` | Register a new IoT scanner or turnstile hardware node | `hardware_nodes` | `INSERT` into `hardware_nodes` (`college_id`, `node_code`, `name`, `room_number`, `mac_address`, `api_key_hash`, `status`) |
| `GET /api/v1/admin/users` | Manage campus user directory (Students & Faculty) | `users`, `departments` | `SELECT` on `users` with `LEFT JOIN departments` filtered by `role`, `department_id`, and `status` |
| `POST /api/v1/admin/users` | Onboard new student, faculty, or staff member | `users` | `INSERT` into `users` (`college_id`, `department_id`, `email`, `password_hash`, `full_name`, `role`, `identifier_number`, `status`) |

---

## 4. Faculty Portal (AG-02)

| Route | Feature Fulfilled | Database Table(s) | Interaction Details |
| :--- | :--- | :--- | :--- |
| `GET /api/v1/faculty/sessions/current` | **FAC-01:** Live view of current active session attendance scans | `timetables`, `attendance_logs`, `users`, `smart_id_profiles` | `SELECT` from `timetables` matching `faculty_id`, current day, and time window; `JOIN attendance_logs` and `users` to stream checked-in students |
| `GET /api/v1/faculty/sessions/{timetable_id}/attendance` | **FAC-01:** View automated attendance logs collected during a specific session | `attendance_logs`, `course_enrollments`, `users`, `timetables` | `SELECT` on `course_enrollments` for enrolled student roster; `LEFT JOIN attendance_logs` matching `timetable_id` and date |
| `POST /api/v1/faculty/attendance/override` | **FAC-02:** Manually mark or correct student attendance (manual exception override) | `attendance_logs`, `timetables`, `users` | `INSERT` or `UPDATE` on `attendance_logs` (`source = 'MANUAL_OVERRIDE'`, `status = :status`, `verified_by = :faculty_id`, `remarks = :remarks`) |
| `POST /api/v1/faculty/assessments` | **FAC-03:** Create an evaluation entry (Midterm, Lab Viva, Quiz, Assignment) | `assessment_records`, `courses`, `timetables` | `INSERT` into `assessment_records` (`college_id`, `student_id`, `course_id`, `timetable_id`, `assessment_type`, `assessment_name`, `score`, `max_score`, `evaluated_by`) |
| `GET /api/v1/faculty/courses/{course_id}/assessments` | **FAC-03:** View and manage assessment grade sheets for enrolled students | `assessment_records`, `users`, `courses` | `SELECT` on `assessment_records` with `JOIN users (students)` filtered by `course_id` and `evaluated_by = :faculty_id` |
| `PUT /api/v1/faculty/assessments/{record_id}` | **FAC-03:** Update/correct previously submitted marks or grades | `assessment_records` | `UPDATE` on `assessment_records` setting `score`, `remarks`, `evaluated_at` where `id = :record_id` and `evaluated_by = :faculty_id` |
| `GET /api/v1/faculty/timetable` | **FAC-04:** View faculty personal weekly teaching and lab supervision timetable | `timetables`, `courses`, `departments` | `SELECT` on `timetables` with `JOIN courses` filtered by `faculty_id = :faculty_id` and `academic_year`, ordered by `day_of_week, start_time` |
| `GET /api/v1/faculty/alerts` | **FAC-05:** View department and campus-wide notice board | `alerts`, `users`, `departments` | `SELECT` on `alerts` where `target_role IN ('ALL', 'FACULTY')` and `(department_id = :dept_id OR department_id IS NULL)` ordered by `created_at DESC` |

---

## 5. Student Portal (AG-03)

| Route | Feature Fulfilled | Database Table(s) | Interaction Details |
| :--- | :--- | :--- | :--- |
| `GET /api/v1/student/attendance` | **STD-01:** View personal attendance logs and subject-wise attendance history | `attendance_logs`, `timetables`, `courses` | `SELECT` on `attendance_logs` with `JOIN timetables` and `JOIN courses` filtered by `user_id = :student_id` |
| `GET /api/v1/student/attendance/shortage-check` | **STD-01:** Real-time dynamic calculation of attendance % and shortage warnings ($< 75\%$) | `attendance_logs`, `timetables`, `course_enrollments`, `courses` | `SELECT` enrolled courses from `course_enrollments`; compute $\left(\frac{\text{Present Count}}{\text{Total Sessions Held}}\right) \times 100$; flags warning if below institutional threshold |
| `GET /api/v1/student/timetable` | **STD-02:** View combined personalized theory class and lab batch schedule | `timetables`, `course_enrollments`, `courses`, `users` | `SELECT` on `timetables` with `JOIN course_enrollments` matching `student_id = :student_id` and `(timetables.batch_name = course_enrollments.batch_name OR timetables.batch_name = 'ALL')` |
| `GET /api/v1/student/assessments` | **STD-03:** View evaluation marks, exam scores, and semester performance summary | `assessment_records`, `courses`, `users` | `SELECT` on `assessment_records` with `JOIN courses` and `JOIN users (evaluator)` where `student_id = :student_id` |
| `GET /api/v1/student/card/status` | **STD-04:** Check active status and assignment metadata of physical Smart ID card | `smart_id_profiles` | `SELECT` on `smart_id_profiles` (`card_uid`, `card_type`, `status`, `issued_at`) where `user_id = :student_id` and `college_id = :college_id` |
| `GET /api/v1/student/alerts` | **STD-05:** View department broadcasts, academic updates, and campus notices | `alerts`, `users`, `departments` | `SELECT` on `alerts` where `target_role IN ('ALL', 'STUDENT')` and `(department_id = :dept_id OR department_id IS NULL)` ordered by `created_at DESC` |

---

## 6. End-to-End Requirement Traceability Matrix

| PRD Req ID | Agent | Feature Description | Assigned REST Route | Database Table(s) | HTTP Method |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **ADM-01** | Admin | Register & assign Smart ID Cards | `/api/v1/admin/cards/assign` | `smart_id_profiles`, `users` | `POST` |
| **ADM-01** | Admin | List & inspect registered cards | `/api/v1/admin/cards` | `smart_id_profiles`, `users` | `GET` |
| **ADM-01** | Admin | Update card status (Lost/Suspended) | `/api/v1/admin/cards/{card_id}/status` | `smart_id_profiles` | `PATCH` |
| **ADM-02** | Admin | View real-time campus attendance summary | `/api/v1/admin/attendance/summary` | `attendance_logs`, `users` | `GET` |
| **ADM-02** | Admin | Search & filter individual attendance logs | `/api/v1/admin/attendance/logs` | `attendance_logs`, `timetables` | `GET` |
| **ADM-03** | Admin | Publish announcements & alerts | `/api/v1/admin/alerts` | `alerts`, `users` | `POST` |
| **ADM-03** | Admin | View & manage published alerts | `/api/v1/admin/alerts` | `alerts`, `users` | `GET` |
| **ADM-04** | Admin | View master schedule across campus | `/api/v1/admin/timetables` | `timetables`, `courses`, `users` | `GET` |
| **ADM-04** | Admin | Schedule theory / lab class blocks | `/api/v1/admin/timetables` | `timetables`, `courses` | `POST` |
| **FAC-01** | Faculty | View live session attendance scans | `/api/v1/faculty/sessions/current` | `timetables`, `attendance_logs` | `GET` |
| **FAC-01** | Faculty | View session attendance logs | `/api/v1/faculty/sessions/{id}/attendance` | `attendance_logs`, `users` | `GET` |
| **FAC-02** | Faculty | Manually override student attendance | `/api/v1/faculty/attendance/override` | `attendance_logs` | `POST` |
| **FAC-03** | Faculty | Upload student assessment marks | `/api/v1/faculty/assessments` | `assessment_records` | `POST` |
| **FAC-03** | Faculty | View course grade sheet | `/api/v1/faculty/courses/{id}/assessments`| `assessment_records`, `users` | `GET` |
| **FAC-04** | Faculty | View personal teaching timetable | `/api/v1/faculty/timetable` | `timetables`, `courses` | `GET` |
| **FAC-05** | Faculty | View department alerts | `/api/v1/faculty/alerts` | `alerts` | `GET` |
| **STD-01** | Student | View personal attendance history | `/api/v1/student/attendance` | `attendance_logs`, `courses` | `GET` |
| **STD-01** | Student | Check attendance shortage alerts | `/api/v1/student/attendance/shortage-check`| `attendance_logs`, `timetables` | `GET` |
| **STD-02** | Student | View personal class/lab timetable | `/api/v1/student/timetable` | `timetables`, `course_enrollments`| `GET` |
| **STD-03** | Student | View evaluation marks & progress | `/api/v1/student/assessments` | `assessment_records`, `courses` | `GET` |
| **STD-04** | Student | Check assigned Smart ID card status | `/api/v1/student/card/status` | `smart_id_profiles` | `GET` |
| **STD-05** | Student | View campus and department alerts | `/api/v1/student/alerts` | `alerts` | `GET` |
| **HW-01** | IoT Node | Ingest real-time RFID/NFC card tap | `/api/v1/hardware/scan` | `hardware_nodes`, `smart_id_profiles`, `attendance_logs` | `POST` |
