# AcadNexa — API Specification Document

**Document:** API_Specification  
**System:** AcadNexa (Multi-Tenant Campus Management System)  
**Standard:** RESTful JSON API (FastAPI)  
**Base URL:** `https://{college-slug}.acadnexa.com/api/v1` or `http://localhost:8000/api/v1` (with `X-Tenant-ID` header)  
**Authentication:** JWT Bearer Token (`Authorization: Bearer <token>`) with RBAC & Scoped Multi-Tenant Isolation  

---

## 1. Authentication & System Foundation

| Route | Method | Feature (PRD) | DB Table(s) | DB Action |
| :--- | :--- | :--- | :--- | :--- |
| `/api/v1/auth/login` | `POST` | User authentication across all roles | `users`, `colleges` | `SELECT` on `users` filtering by `college_id` and `email`; verifies password hash; `UPDATE users SET last_login_at = NOW()` |
| `/api/v1/auth/me` | `GET` | Current authenticated profile & active session | `users`, `departments`, `colleges` | `SELECT` on `users` with `JOIN departments` and `JOIN colleges` by authenticated `user_id` and `college_id` |

---

## 2. Admin Portal (AG-01)

| Route | Method | Feature (PRD) | DB Table(s) | DB Action |
| :--- | :--- | :--- | :--- | :--- |
| `/api/v1/admin/users` | `GET` | **ADM-01:** Manage campus user directory (Students & Faculty) | `users`, `departments` | `SELECT` on `users` with `LEFT JOIN departments` filtered by `role`, `department_id`, and `status` |
| `/api/v1/admin/users` | `POST` | **ADM-01:** Onboard new student, faculty, or staff member | `users` | `INSERT` into `users` (`college_id`, `department_id`, `email`, `password_hash`, `full_name`, `role`, `identifier_number`, `status`) |
| `/api/v1/admin/users/{user_id}` | `PUT` | **ADM-01:** Update user details or departmental assignment | `users` | `UPDATE` on `users` setting profile attributes where `id = :user_id` and `college_id = :college_id` |
| `/api/v1/admin/attendance/summary` | `GET` | **ADM-02:** View real-time aggregated campus attendance metrics | `attendance_logs`, `users`, `departments`, `timetables` | `SELECT` aggregation (`COUNT`, `GROUP BY department_id, date, status`) on `attendance_logs` scoped by `college_id` |
| `/api/v1/admin/attendance/logs` | `GET` | **ADM-02:** Filter and search real-time campus attendance logs | `attendance_logs`, `users`, `timetables` | `SELECT` on `attendance_logs` with `JOIN users` and `JOIN timetables` filtered by date range and department |
| `/api/v1/admin/alerts` | `POST` | **ADM-03:** Publish department-wide or campus-wide alerts | `alerts`, `users` | `INSERT` into `alerts` (`college_id`, `author_id`, `title`, `message`, `target_role`, `department_id`, `priority`, `expires_at`) |
| `/api/v1/admin/alerts` | `GET` | **ADM-03:** View all published alerts and active broadcasts | `alerts`, `users`, `departments` | `SELECT` on `alerts` with `JOIN users (author)` and `LEFT JOIN departments` ordered by `created_at DESC` |
| `/api/v1/admin/alerts/{alert_id}` | `DELETE` | **ADM-03:** Archive or delete an active alert broadcast | `alerts` | `DELETE` from `alerts` where `id = :alert_id` and `college_id = :college_id` |
| `/api/v1/admin/timetables` | `GET` | **ADM-04:** View master institutional schedule | `timetables`, `courses`, `users`, `departments` | `SELECT` on `timetables` with `JOIN courses` and `JOIN users (faculty)` filtered by `academic_year` and `department_id` |
| `/api/v1/admin/timetables` | `POST` | **ADM-04:** Create a new master schedule block for classes/labs | `timetables`, `courses`, `users` | `INSERT` into `timetables` (`college_id`, `course_id`, `faculty_id`, `session_type`, `room_number`, `batch_name`, `day_of_week`, `start_time`, `end_time`, `academic_year`) |
| `/api/v1/admin/timetables/{id}` | `PUT` | **ADM-04:** Update room allocation, timing, or instructor | `timetables` | `UPDATE` on `timetables` setting new time slots, room, faculty, or batch where `id = :id` |
| `/api/v1/admin/timetables/{id}` | `DELETE` | **ADM-04:** Remove a scheduled theory or lab class block | `timetables` | `DELETE` from `timetables` where `id = :id` and `college_id = :college_id` |

---

## 3. Faculty Portal (AG-02)

| Route | Method | Feature (PRD) | DB Table(s) | DB Action |
| :--- | :--- | :--- | :--- | :--- |
| `/api/v1/faculty/sessions/{id}/roster` | `GET` | **FAC-01:** View enrolled student roster for scheduled session | `course_enrollments`, `users`, `timetables` | `SELECT` students enrolled in session course/batch for attendance sheet |
| `/api/v1/faculty/sessions/{id}/attendance` | `POST` | **FAC-01:** Record digital class attendance for a session | `attendance_logs`, `timetables` | `INSERT` attendance records (`source = 'PORTAL_ENTRY'`, `status = :status`, `verified_by = :faculty_id`) |
| `/api/v1/faculty/sessions/{id}/attendance` | `GET` | **FAC-01:** View recorded attendance logs for a specific session | `attendance_logs`, `users` | `SELECT` attendance logs with student details for given session and date |
| `/api/v1/faculty/attendance/override` | `POST` | **FAC-02:** Manually update/correct student attendance | `attendance_logs`, `timetables` | `UPDATE` / `INSERT` on `attendance_logs` (`source = 'MANUAL_OVERRIDE'`, `verified_by = :faculty_id`, `remarks = :remarks`) |
| `/api/v1/faculty/assessments` | `POST` | **FAC-03:** Create an evaluation entry (Midterm, Viva, Quiz, Project) | `assessment_records`, `courses` | `INSERT` into `assessment_records` (`college_id`, `student_id`, `course_id`, `timetable_id`, `assessment_type`, `assessment_name`, `score`, `max_score`, `evaluated_by`) |
| `/api/v1/faculty/courses/{id}/assessments` | `GET` | **FAC-03:** View grade sheets for enrolled course students | `assessment_records`, `users` | `SELECT` on `assessment_records` with `JOIN users (students)` filtered by `course_id` and `evaluated_by` |
| `/api/v1/faculty/assessments/{record_id}` | `PUT` | **FAC-03:** Update / correct entered marks | `assessment_records` | `UPDATE` on `assessment_records` setting `score`, `evaluated_at` where `id = :record_id` |
| `/api/v1/faculty/timetable` | `GET` | **FAC-04:** View faculty personal weekly teaching timetable | `timetables`, `courses`, `departments` | `SELECT` on `timetables` with `JOIN courses` filtered by `faculty_id = :faculty_id` ordered by `day_of_week, start_time` |
| `/api/v1/faculty/alerts` | `GET` | **FAC-05:** View department and campus announcements | `alerts`, `users`, `departments` | `SELECT` on `alerts` where `target_role IN ('ALL', 'FACULTY')` ordered by `created_at DESC` |

---

## 4. Student Portal (AG-03)

| Route | Method | Feature (PRD) | DB Table(s) | DB Action |
| :--- | :--- | :--- | :--- | :--- |
| `/api/v1/student/attendance` | `GET` | **STD-01:** View personal attendance logs and subject history | `attendance_logs`, `timetables`, `courses` | `SELECT` on `attendance_logs` with `JOIN timetables` and `JOIN courses` filtered by `user_id = :student_id` |
| `/api/v1/student/attendance/shortage-check` | `GET` | **STD-01:** Dynamic calculation of attendance % & shortage alerts ($< 75\%$) | `attendance_logs`, `timetables`, `course_enrollments` | `SELECT` enrolled courses; compute $\left(\frac{\text{Present Count}}{\text{Total Sessions}}\right) \times 100$; flags shortage alert |
| `/api/v1/student/timetable` | `GET` | **STD-02:** View combined personalized class & lab timetable | `timetables`, `course_enrollments`, `courses` | `SELECT` on `timetables` with `JOIN course_enrollments` matching `student_id = :student_id` |
| `/api/v1/student/assessments` | `GET` | **STD-03:** View evaluation marks, exam scores, and progress | `assessment_records`, `courses`, `users` | `SELECT` on `assessment_records` with `JOIN courses` where `student_id = :student_id` |
| `/api/v1/student/profile` | `GET` | **STD-04:** View academic profile and enrolled course details | `users`, `departments`, `course_enrollments` | `SELECT` user details, department name, and enrolled courses for authenticated student |
| `/api/v1/student/alerts` | `GET` | **STD-05:** View department and campus announcements feed | `alerts`, `users`, `departments` | `SELECT` on `alerts` where `target_role IN ('ALL', 'STUDENT')` ordered by `created_at DESC` |

---

## 5. End-to-End Requirement Traceability Matrix

| PRD Req ID | Agent | Feature Description | Assigned REST Route | Database Table(s) | HTTP Method |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **ADM-01** | Admin | Onboard & manage users / enrollments | `/api/v1/admin/users` | `users`, `departments` | `GET`, `POST` |
| **ADM-02** | Admin | View real-time campus attendance summary | `/api/v1/admin/attendance/summary` | `attendance_logs`, `users` | `GET` |
| **ADM-02** | Admin | Search & filter individual attendance logs | `/api/v1/admin/attendance/logs` | `attendance_logs`, `timetables` | `GET` |
| **ADM-03** | Admin | Publish announcements & alerts | `/api/v1/admin/alerts` | `alerts`, `users` | `POST` |
| **ADM-03** | Admin | View & manage published alerts | `/api/v1/admin/alerts` | `alerts`, `users` | `GET` |
| **ADM-04** | Admin | View master schedule across campus | `/api/v1/admin/timetables` | `timetables`, `courses`, `users` | `GET` |
| **ADM-04** | Admin | Schedule theory / lab class blocks | `/api/v1/admin/timetables` | `timetables`, `courses` | `POST` |
| **FAC-01** | Faculty | View session roster & record class attendance | `/api/v1/faculty/sessions/{id}/attendance` | `attendance_logs`, `timetables` | `POST`, `GET` |
| **FAC-02** | Faculty | Manually override student attendance | `/api/v1/faculty/attendance/override` | `attendance_logs` | `POST` |
| **FAC-03** | Faculty | Upload student assessment marks | `/api/v1/faculty/assessments` | `assessment_records` | `POST` |
| **FAC-03** | Faculty | View course grade sheet | `/api/v1/faculty/courses/{id}/assessments`| `assessment_records`, `users` | `GET` |
| **FAC-04** | Faculty | View personal teaching timetable | `/api/v1/faculty/timetable` | `timetables`, `courses` | `GET` |
| **FAC-05** | Faculty | View department alerts | `/api/v1/faculty/alerts` | `alerts` | `GET` |
| **STD-01** | Student | View personal attendance history | `/api/v1/student/attendance` | `attendance_logs`, `courses` | `GET` |
| **STD-01** | Student | Check attendance shortage alerts | `/api/v1/student/attendance/shortage-check`| `attendance_logs`, `timetables` | `GET` |
| **STD-02** | Student | View personal class/lab timetable | `/api/v1/student/timetable` | `timetables`, `course_enrollments`| `GET` |
| **STD-03** | Student | View evaluation marks & progress | `/api/v1/student/assessments` | `assessment_records`, `courses` | `GET` |
| **STD-04** | Student | View academic profile & course enrollments | `/api/v1/student/profile` | `users`, `departments` | `GET` |
| **STD-05** | Student | View campus and department alerts | `/api/v1/student/alerts` | `alerts` | `GET` |
