1. # ACAD NEXA

## System Requirement Specification (SRS) Sheet

**Document:** Project_Requirements
**Project:** AcadNexa
**Document Type:** Functional Requirements Specification
**Status:** Requirements Definition

---

# STEP 1 — PROJECT IDENTIFICATION

### 1.1 Project Name
**AcadNexa**

### 1.2 Project Type
**IoT-Integrated Campus Management & Academic System**

### 1.3 System Purpose
AcadNexa is a modern, role-based academic ecosystem that bridges software management with hardware integration. It is designed to automate physical campus workflows—such as automated attendance tracking via Smart ID Cards—while centralizing academic records, lab schedules, and department communications.

---

# STEP 2 — SYSTEM AGENTS

An **Agent** is a designated role authorized to perform specific operations within the system.

| Agent ID | Agent   | Description                                                                 |
| -------- | ------- | --------------------------------------------------------------------------- |
| AG-01    | Admin   | Manages institutional data, hardware nodes, and department-level workflows. |
| AG-02    | Faculty | Manages academic deliverables, lab sessions, and manual overrides.          |
| AG-03    | Student | Accesses personal academic progress, lab schedules, and campus resources.   |

---

# STEP 3 — REQUIREMENT IDENTIFICATION

## 3.1 Admin Requirements

| ID     | Requirement                                                                                   |
| ------ | --------------------------------------------------------------------------------------------- |
| ADM-01 | Admin shall be able to register and assign Smart ID Cards to specific students and faculty.   |
| ADM-02 | Admin shall be able to view real-time, aggregated campus attendance logs.                     |
| ADM-03 | Admin shall be able to publish department-wide alerts and academic notifications.             |
| ADM-04 | Admin shall be able to manage the master schedule for theory classes and laboratory sessions. |

## 3.2 Faculty Requirements

| ID     | Requirement                                                                                         |
| ------ | --------------------------------------------------------------------------------------------------- |
| FAC-01 | Faculty shall be able to view automated attendance logs generated during their assigned sessions.   |
| FAC-02 | Faculty shall be able to manually override or update attendance records for exceptions.             |
| FAC-03 | Faculty shall be able to upload assessment scores and project evaluations for enrolled students.    |
| FAC-04 | Faculty shall be able to access their personal teaching and lab supervision timetable.              |
| FAC-05 | Faculty shall be able to view department-wide alerts and notifications.                             |

## 3.3 Student Requirements

| ID     | Requirement                                                                                    |
| ------ | ---------------------------------------------------------------------------------------------- |
| STD-01 | Student shall be able to view their real-time personal attendance records and shortage alerts. |
| STD-02 | Student shall be able to view their combined theory and lab session timetable.                 |
| STD-03 | Student shall be able to access their assessment scores and semester progress.                 |
| STD-04 | Student shall be able to check the active status of their assigned Smart ID Card.              |
| STD-05 | Student shall be able to view department-wide alerts and notifications.                        |

---

# STEP 4 — AGENT → ACTION → ENTITY → RELATION

This matrix breaks down narrative requirements into programmatic interactions for database modeling and API routing.

| Req. ID | Agent   | Action        | Entity             | Relation                          |
| ------- | ------- | ------------- | ------------------ | --------------------------------- |
| ADM-01  | Admin   | Create/Update | Smart ID Profile   | Campus-wide Users                 |
| ADM-02  | Admin   | View          | Attendance Log     | Campus-wide Aggregation           |
| ADM-03  | Admin   | Create/Post   | Alert              | Department-wide                   |
| ADM-04  | Admin   | Create/Update | Timetable          | Master Institutional Schedule     |
| FAC-01  | Faculty | View          | Attendance Log     | Assigned Sessions                 |
| FAC-02  | Faculty | Update        | Attendance Log     | Assigned Sessions (Overrides)     |
| FAC-03  | Faculty | Create/Update | Assessment Record  | Enrolled Students                 |
| FAC-04  | Faculty | View          | Timetable          | Personal Teaching Schedule        |
| FAC-05  | Faculty | View          | Alert              | Department-wide                   |
| STD-01  | Student | View          | Attendance Log     | Personal Records                  |
| STD-02  | Student | View          | Timetable          | Personal Schedule                 |
| STD-03  | Student | View          | Assessment Record  | Personal Academic Progress        |
| STD-04  | Student | View          | Smart ID Profile   | Personal Hardware Assignment      |
| STD-05  | Student | View          | Alert              | Department-wide                   |

---

# STEP 5 — MASTER AGENT LIST

1. Admin
2. Faculty
3. Student

---

# STEP 6 — MASTER ACTION LIST

| Action        | Application in AcadNexa                          |
| ------------- | ------------------------------------------------ |
| View          | Read/Fetch existing database records             |
| Create        | Insert new database records                      |
| Update        | Mutate/Modify existing records                   |
| Create/Update | Upsert operations (Add or Edit)                  |
| Create/Post   | Publish broadcasts to the system                 |

---

# STEP 7 — MASTER ENTITY LIST

Normalizing the requirements yields the following core database entities:

| Entity ID | Entity             | Description                                          |
| --------- | ------------------ | ---------------------------------------------------- |
| ENT-01    | User               | Base entity for all students, faculty, and admins    |
| ENT-02    | Smart ID Profile   | Links a physical hardware tag/card to a specific User|
| ENT-03    | Attendance Log     | Immutable records generated by manual or auto-scans  |
| ENT-04    | Timetable          | Master scheduling block for theory and lab sessions  |
| ENT-05    | Assessment Record  | Academic scores, project grades, and evaluations     |
| ENT-06    | Alert              | Department-level communications and notifications    |

---

# STEP 8 — ENTITIES VS. CALCULATED AGGREGATIONS

*   **Attendance Shortage Alerts:** Computed dynamically by comparing a student's `Attendance Log` against the required thresholds in the `Timetable`. Not a standalone database entity.
*   **Semester Progress:** Computed dynamically by aggregating `Assessment Records` for a specific student.

---

# STEP 9 — ROLE-BASED REQUIREMENT MATRIX

| Module / Resource    | Admin                      | Faculty                             | Student                       |
| -------------------- | -------------------------- | ----------------------------------- | ----------------------------- |
| Smart ID Profile     | Register & assign cards    | —                                   | View active status            |
| Attendance Log       | View campus aggregate      | View & manually override class logs | View personal records         |
| Timetable            | Manage master schedule     | View personal schedule              | View personal schedule        |
| Assessment Records   | —                          | Assign/Upload scores                | View personal scores          |
| Alerts               | Publish department notices | View feed                           | View feed                     |

---

# STEP 10 — REQUIREMENT NORMALIZATION & SCOPING

1.  **Hardware-Software Handshake:** `Attendance Log` is designed to accept POST requests both from the frontend client (manual override by Faculty) and from external hardware endpoints (automated ID scanners).
2.  **Unified Scheduling:** `Timetable` handles both theory classes and laboratory sessions to prevent redundant scheduling tables.
3.  **Strict Scope Limits:** Modules like Library Management, Transport Tracking, and Online Fee Collection are expressly **out of scope** for this phase.

---

# STEP 11 — REQUIREMENT COMPLETENESS CHECK

| Verification Gate                         | Status |
| ----------------------------------------- | ------ |
| Business requirements defined & scoped    | ✅     |
| Requirements mapped to valid Agents       | ✅     |
| Requirements translated to CRUD Actions   | ✅     |
| Core Entities cleanly identified          | ✅     |
| Calculated aggregations separated         | ✅     |
| Presentation concepts decoupled from data | ✅     |
| Architectural Database Design ready       | ⏳ Next |
| REST/GraphQL API Design ready             | ⏳ Next |
| UI/UX Wireframes ready                    | ⏳ Next |

---

# STEP 12 — FINAL REQUIREMENT MODEL

```text
                                AcadNexa
                                    │
            ┌───────────────────────┼───────────────────────┐
            │                       │                       │
          ADMIN                  FACULTY                 STUDENT
            │                       │                       │
      ┌─────┼─────┐           ┌─────┼─────┐           ┌─────┼─────┐
      │     │     │           │     │     │           │     │     │
 Smart ID   │ Timetable  Attendance │ Assessment Attendance │ Assessment
  Profile   │                Log    │   Record       Log    │   Record
            │                       │                       │
      Attendance Log            Timetable               Timetable
            │                       │                       │
          Alert                   Alert                 Smart ID Profile
                                                            │
                                                          Alert