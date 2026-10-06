"""
AcadNexa Database Seeder & Schema Initializer
Seeds multi-tenant PostgreSQL database with:
- 2 Colleges (Tenants)
- 2 College Admins (1 per tenant)
- 10 Faculty Members (5 per tenant across departments)
- 50 Students (25 per tenant across departments & semesters)
- Courses & Course Enrollments
- Master Timetables (Theory & Lab sessions)
- Attendance Logs (Portal Session Entries & Faculty Overrides)
- Assessment Records (Grades & evaluations)
- Campus/Department Alerts
"""

import os
import sys
import uuid
import random
import hashlib
from datetime import datetime, date, time, timedelta, timezone
from typing import List, Dict

# Ensure UTF-8 output on Windows consoles
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

from sqlalchemy import (
    create_engine, Column, String, Boolean, Integer, Numeric,
    DateTime, Time, Text, ForeignKey, UniqueConstraint, Index, CheckConstraint
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import declarative_base, sessionmaker, relationship

# -----------------------------------------------------------------------------
# Configuration & Connection Setup
# -----------------------------------------------------------------------------
DB_USER = os.getenv("POSTGRES_USER", "acadnexa_user")
DB_PASSWORD = os.getenv("POSTGRES_PASSWORD", "acadnexa_password")
DB_HOST = os.getenv("POSTGRES_HOST", "localhost")
DB_PORT = os.getenv("POSTGRES_PORT", "5432")
DB_NAME = os.getenv("POSTGRES_DB", "acadnexa_db")

DATABASE_URL = f"postgresql+psycopg2://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"

print(f"Connecting to database: postgresql://{DB_USER}:***@{DB_HOST}:{DB_PORT}/{DB_NAME}")
engine = create_engine(DATABASE_URL, echo=False)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# -----------------------------------------------------------------------------
# SQLAlchemy Models Definition
# -----------------------------------------------------------------------------

class Tenant(Base):
    __tablename__ = "tenants"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(255), nullable=False)
    slug = Column(String(64), nullable=False, unique=True)
    domain = Column(String(255), nullable=True, unique=True)
    contact_email = Column(String(255), nullable=False)
    is_active = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))

    users = relationship("User", back_populates="tenant", cascade="all, delete-orphan")
    courses = relationship("Course", back_populates="tenant", cascade="all, delete-orphan")


class User(Base):
    __tablename__ = "users"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    tenant_id = Column(UUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False)
    email = Column(String(255), nullable=False)
    hashed_password = Column(String(255), nullable=False)
    full_name = Column(String(255), nullable=False)
    role = Column(String(32), nullable=False)  # 'ADMIN', 'FACULTY', 'STUDENT'
    department = Column(String(128), nullable=False)
    identifier_number = Column(String(64), nullable=True)
    is_active = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))

    __table_args__ = (
        UniqueConstraint("tenant_id", "email", name="uq_users_tenant_email"),
        UniqueConstraint("tenant_id", "identifier_number", name="uq_users_tenant_identifier"),
        Index("idx_users_tenant_role", "tenant_id", "role"),
        Index("idx_users_tenant_dept", "tenant_id", "department"),
    )

    tenant = relationship("Tenant", back_populates="users")


class Course(Base):
    __tablename__ = "courses"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    tenant_id = Column(UUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False)
    code = Column(String(32), nullable=False)
    name = Column(String(255), nullable=False)
    department = Column(String(128), nullable=False)
    credits = Column(Integer, nullable=False, default=3)
    semester = Column(Integer, nullable=False)
    is_active = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))

    __table_args__ = (
        UniqueConstraint("tenant_id", "code", name="uq_courses_tenant_code"),
        Index("idx_courses_tenant_dept", "tenant_id", "department", "semester"),
    )

    tenant = relationship("Tenant", back_populates="courses")


class CourseEnrollment(Base):
    __tablename__ = "course_enrollments"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    tenant_id = Column(UUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False)
    student_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    course_id = Column(UUID(as_uuid=True), ForeignKey("courses.id", ondelete="CASCADE"), nullable=False)
    batch_name = Column(String(32), nullable=True, default="ALL")
    academic_year = Column(String(32), nullable=False, default="2026-2027")
    enrolled_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))

    __table_args__ = (
        UniqueConstraint("tenant_id", "student_id", "course_id", "academic_year", name="uq_enrollment_unique"),
        Index("idx_enrollments_student", "tenant_id", "student_id"),
        Index("idx_enrollments_course", "tenant_id", "course_id", "batch_name"),
    )


class Timetable(Base):
    __tablename__ = "timetables"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    tenant_id = Column(UUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False)
    course_id = Column(UUID(as_uuid=True), ForeignKey("courses.id", ondelete="CASCADE"), nullable=False)
    faculty_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="RESTRICT"), nullable=False)
    session_type = Column(String(32), nullable=False)  # THEORY, LAB, SEMINAR
    room_number = Column(String(64), nullable=False)
    batch_name = Column(String(32), nullable=False, default="ALL")
    day_of_week = Column(Integer, nullable=False)  # 1 (Mon) - 7 (Sun)
    start_time = Column(Time, nullable=False)
    end_time = Column(Time, nullable=False)
    academic_year = Column(String(32), nullable=False, default="2026-2027")
    created_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))

    __table_args__ = (
        CheckConstraint("day_of_week BETWEEN 1 AND 7", name="chk_day_of_week"),
        Index("idx_timetables_faculty", "tenant_id", "faculty_id", "day_of_week"),
        Index("idx_timetables_course", "tenant_id", "course_id", "batch_name"),
        Index("idx_timetables_room", "tenant_id", "room_number", "day_of_week", "start_time"),
    )


class AttendanceLog(Base):
    __tablename__ = "attendance_logs"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    tenant_id = Column(UUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    timetable_id = Column(UUID(as_uuid=True), ForeignKey("timetables.id", ondelete="SET NULL"), nullable=True)
    timestamp = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))
    source = Column(String(32), nullable=False)  # PORTAL_ENTRY, MANUAL_OVERRIDE
    status = Column(String(32), nullable=False, default="PRESENT")  # PRESENT, ABSENT, LATE, EXCUSED
    verified_by = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    remarks = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))

    __table_args__ = (
        Index("idx_attendance_tenant_user", "tenant_id", "user_id", "timestamp"),
        Index("idx_attendance_timetable", "tenant_id", "timetable_id", "timestamp"),
        Index("idx_attendance_date", "tenant_id", "timestamp"),
    )


class AssessmentRecord(Base):
    __tablename__ = "assessment_records"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    tenant_id = Column(UUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False)
    student_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    course_id = Column(UUID(as_uuid=True), ForeignKey("courses.id", ondelete="CASCADE"), nullable=False)
    timetable_id = Column(UUID(as_uuid=True), ForeignKey("timetables.id", ondelete="SET NULL"), nullable=True)
    assessment_type = Column(String(32), nullable=False)  # MIDTERM, FINAL, LAB_VIVA, ASSIGNMENT
    assessment_name = Column(String(128), nullable=False)
    score = Column(Numeric(5, 2), nullable=False)
    max_score = Column(Numeric(5, 2), nullable=False)
    evaluated_by = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="RESTRICT"), nullable=False)
    evaluated_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))
    created_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))

    __table_args__ = (
        CheckConstraint("score >= 0", name="chk_score_positive"),
        CheckConstraint("max_score > 0", name="chk_max_score_positive"),
        Index("idx_assessments_student", "tenant_id", "student_id", "course_id"),
        Index("idx_assessments_course", "tenant_id", "course_id", "assessment_type"),
        Index("idx_assessments_evaluator", "tenant_id", "evaluated_by"),
    )


class Alert(Base):
    __tablename__ = "alerts"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    tenant_id = Column(UUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False)
    author_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="RESTRICT"), nullable=False)
    title = Column(String(255), nullable=False)
    message = Column(Text, nullable=False)
    target_role = Column(String(32), nullable=False, default="ALL")  # ALL, FACULTY, STUDENT
    department = Column(String(128), nullable=True, default="ALL")
    priority = Column(String(32), nullable=False, default="NORMAL")  # LOW, NORMAL, HIGH, URGENT
    expires_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))

    __table_args__ = (
        Index("idx_alerts_tenant_target", "tenant_id", "target_role", "department", "created_at"),
    )


# -----------------------------------------------------------------------------
# Seeder Script
# -----------------------------------------------------------------------------

def hash_pw(password: str) -> str:
    return hashlib.sha256(password.encode("utf-8")).hexdigest()

def seed_database():
    print("=" * 70)
    print("🚀 INITIALIZING ACADNEXA DATABASE SCHEMA & MULTI-TENANT SEEDING")
    print("=" * 70)

    # 1. Recreate tables cleanly
    print("📦 Creating database tables...")
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    print("✅ All tables created successfully.")

    session = SessionLocal()

    try:
        # -------------------------------------------------------------------------
        # 1. Seed 2 Tenants (Colleges)
        # -------------------------------------------------------------------------
        print("\n🏛️ Seeding 2 Colleges (Tenants)...")
        tenants_data = [
            {
                "name": "Apex Institute of Technology",
                "slug": "apex",
                "domain": "apex.acadnexa.com",
                "contact_email": "admin@apex.edu"
            },
            {
                "name": "Nexus University of Science & Engineering",
                "slug": "nexus",
                "domain": "nexus.acadnexa.com",
                "contact_email": "dean@nexus.edu"
            }
        ]

        tenants: List[Tenant] = []
        for t_info in tenants_data:
            tenant = Tenant(
                name=t_info["name"],
                slug=t_info["slug"],
                domain=t_info["domain"],
                contact_email=t_info["contact_email"],
                is_active=True
            )
            session.add(tenant)
            tenants.append(tenant)

        session.flush()
        for t in tenants:
            print(f"  • Created Tenant: {t.name} (Slug: {t.slug}, ID: {t.id})")

        # -------------------------------------------------------------------------
        # 2. Seed 2 Admins (1 per Tenant)
        # -------------------------------------------------------------------------
        print("\n👑 Seeding 2 College Admins...")
        admins: List[User] = []
        for tenant in tenants:
            admin = User(
                tenant_id=tenant.id,
                email=f"admin@{tenant.slug}.edu",
                hashed_password=hash_pw("Admin@123"),
                full_name=f"{tenant.name.split()[0]} Campus Administrator",
                role="ADMIN",
                department="Administration",
                identifier_number=f"ADM-{tenant.slug.upper()}-001",
                is_active=True
            )
            session.add(admin)
            admins.append(admin)
        session.flush()

        for a in admins:
            print(f"  • Admin: {a.full_name} | Email: {a.email} | Tenant: {a.tenant_id}")

        # -------------------------------------------------------------------------
        # 3. Seed 10 Faculty Members (5 per Tenant)
        # -------------------------------------------------------------------------
        print("\n👨‍🏫 Seeding 10 Faculty Members (5 per college)...")
        departments = [
            "Computer Science & Engineering",
            "Electronics & Communication",
            "Data Science & AI",
            "Information Technology",
            "Mechanical Engineering"
        ]

        faculty_names = [
            ("Dr. Alan Turing", "alan.turing"),
            ("Dr. Grace Hopper", "grace.hopper"),
            ("Prof. Claude Shannon", "claude.shannon"),
            ("Dr. Barbara Liskov", "barbara.liskov"),
            ("Prof. Donald Knuth", "donald.knuth"),
            ("Dr. Margaret Hamilton", "margaret.hamilton"),
            ("Prof. Edsger Dijkstra", "edsger.dijkstra"),
            ("Dr. Adele Goldberg", "adele.goldberg"),
            ("Prof. Tim Berners-Lee", "tim.berners"),
            ("Dr. Radia Perlman", "radia.perlman"),
        ]

        all_faculty: List[User] = []
        idx = 0
        for tenant in tenants:
            for dept_idx, dept in enumerate(departments):
                f_name, f_email_prefix = faculty_names[idx]
                idx += 1
                faculty = User(
                    tenant_id=tenant.id,
                    email=f"{f_email_prefix}@{tenant.slug}.edu",
                    hashed_password=hash_pw("Faculty@123"),
                    full_name=f_name,
                    role="FACULTY",
                    department=dept,
                    identifier_number=f"FAC-{tenant.slug.upper()}-{100 + dept_idx}",
                    is_active=True
                )
                session.add(faculty)
                all_faculty.append(faculty)

        session.flush()
        print(f"  • Created {len(all_faculty)} faculty members across {len(departments)} departments.")

        # -------------------------------------------------------------------------
        # 4. Seed Courses per Tenant
        # -------------------------------------------------------------------------
        print("\n📚 Seeding Courses...")
        course_catalog = [
            ("CS301", "Distributed Systems & Cloud Computing", "Computer Science & Engineering", 4, 5),
            ("CS302", "Advanced Database Management", "Computer Science & Engineering", 3, 5),
            ("EC201", "Digital Signal Processing & Protocols", "Electronics & Communication", 4, 4),
            ("DS401", "Applied Machine Learning & Deep Neural Nets", "Data Science & AI", 4, 7),
            ("IT202", "Web Systems & Microservice Architecture", "Information Technology", 3, 3),
            ("ME305", "Robotics & Automated Control", "Mechanical Engineering", 4, 6),
        ]

        all_courses: List[Course] = []
        for tenant in tenants:
            for code, name, dept, credits, sem in course_catalog:
                course = Course(
                    tenant_id=tenant.id,
                    code=code,
                    name=name,
                    department=dept,
                    credits=credits,
                    semester=sem,
                    is_active=True
                )
                session.add(course)
                all_courses.append(course)
        session.flush()
        print(f"  • Seeded {len(all_courses)} course offerings across colleges.")

        # -------------------------------------------------------------------------
        # 5. Seed 50 Students (25 per Tenant)
        # -------------------------------------------------------------------------
        print("\n🎓 Seeding 50 Students (25 per college)...")
        first_names = [
            "Aarav", "Ananya", "Rohan", "Sneha", "Vikram", "Priya", "Rahul", "Kavya",
            "Aditya", "Isha", "Arjun", "Neha", "Siddharth", "Tanvi", "Karan", "Meera",
            "Varun", "Riya", "Nikhil", "Pooja", "Dev", "Anushka", "Manish", "Divya", "Akash"
        ]
        last_names = ["Sharma", "Verma", "Patel", "Reddy", "Gupta", "Nair", "Rao", "Iyer", "Mehta", "Singh"]

        all_students: List[User] = []
        for tenant_idx, tenant in enumerate(tenants):
            for s_idx in range(25):
                fn = first_names[s_idx % len(first_names)]
                ln = last_names[(s_idx + tenant_idx * 3) % len(last_names)]
                full_name = f"{fn} {ln}"
                email_handle = f"{fn.lower()}.{ln.lower()}{s_idx+1}@{tenant.slug}.edu"
                dept = departments[s_idx % len(departments)]
                roll_no = f"{tenant.slug.upper()}-2024-{dept[:2].upper()}-{1001 + s_idx}"

                student = User(
                    tenant_id=tenant.id,
                    email=email_handle,
                    hashed_password=hash_pw("Student@123"),
                    full_name=full_name,
                    role="STUDENT",
                    department=dept,
                    identifier_number=roll_no,
                    is_active=True
                )
                session.add(student)
                all_students.append(student)

        session.flush()
        print(f"  • Seeded {len(all_students)} student profiles across 2 colleges.")

        # -------------------------------------------------------------------------
        # 6. Seed Master Timetables (Theory & Lab sessions)
        # -------------------------------------------------------------------------
        print("\n🗓️ Scheduling Master Timetables...")
        all_timetables: List[Timetable] = []

        times = [
            (time(9, 0), time(10, 30)),
            (time(10, 45), time(12, 15)),
            (time(13, 15), time(14, 45)),
            (time(15, 0), time(16, 30))
        ]

        for tenant in tenants:
            tenant_courses = [c for c in all_courses if c.tenant_id == tenant.id]
            tenant_faculty = [f for f in all_faculty if f.tenant_id == tenant.id]

            for i, course in enumerate(tenant_courses):
                assigned_fac = tenant_faculty[i % len(tenant_faculty)]
                
                # Theory Session (Batch ALL)
                start_t, end_t = times[i % len(times)]
                tt_theory = Timetable(
                    tenant_id=tenant.id,
                    course_id=course.id,
                    faculty_id=assigned_fac.id,
                    session_type="THEORY",
                    room_number=f"LH-{100 + (i % 5)}",
                    batch_name="ALL",
                    day_of_week=(i % 5) + 1,  # Mon - Fri
                    start_time=start_t,
                    end_time=end_t,
                    academic_year="2026-2027"
                )
                session.add(tt_theory)
                all_timetables.append(tt_theory)

                # Lab Session (Batch B1)
                tt_lab = Timetable(
                    tenant_id=tenant.id,
                    course_id=course.id,
                    faculty_id=assigned_fac.id,
                    session_type="LAB",
                    room_number=f"LAB-{300 + (i % 3)}",
                    batch_name="B1",
                    day_of_week=((i + 2) % 5) + 1,
                    start_time=time(14, 0),
                    end_time=time(16, 0),
                    academic_year="2026-2027"
                )
                session.add(tt_lab)
                all_timetables.append(tt_lab)

        session.flush()
        print(f"  • Generated {len(all_timetables)} timetable schedule blocks.")

        # -------------------------------------------------------------------------
        # 7. Seed Course Enrollments
        # -------------------------------------------------------------------------
        print("\n📝 Enrolling Students in Courses...")
        enrollments_count = 0
        for tenant in tenants:
            t_students = [s for s in all_students if s.tenant_id == tenant.id]
            t_courses = [c for c in all_courses if c.tenant_id == tenant.id]

            for student in t_students:
                matching_courses = [c for c in t_courses if c.department == student.department]
                other_courses = [c for c in t_courses if c.department != student.department]
                chosen_courses = matching_courses + other_courses[:2]

                for c in chosen_courses:
                    enrollment = CourseEnrollment(
                        tenant_id=tenant.id,
                        student_id=student.id,
                        course_id=c.id,
                        batch_name="B1" if random.random() > 0.5 else "B2",
                        academic_year="2026-2027"
                    )
                    session.add(enrollment)
                    enrollments_count += 1

        session.flush()
        print(f"  • Created {enrollments_count} student course enrollments.")

        # -------------------------------------------------------------------------
        # 8. Seed Digital Attendance Logs (Faculty Entries + Overrides)
        # -------------------------------------------------------------------------
        print("\n⏱️ Logging Session Attendance Records...")
        attendance_records_count = 0
        now = datetime.now(timezone.utc)

        for tenant in tenants:
            t_students = [s for s in all_students if s.tenant_id == tenant.id]
            t_timetables = [tt for tt in all_timetables if tt.tenant_id == tenant.id]

            for day_offset in range(14, 0, -1):
                log_date = (now - timedelta(days=day_offset)).date()
                day_num = log_date.isoweekday()  # 1=Mon, 7=Sun
                if day_num > 5:
                    continue  # Skip weekends

                active_sessions = [tt for tt in t_timetables if tt.day_of_week == day_num]

                for session_slot in active_sessions:
                    sample_students = random.sample(t_students, min(len(t_students), 15))

                    for student in sample_students:
                        is_present = random.random() > 0.15  # 85% attendance rate
                        is_late = is_present and (random.random() < 0.10)
                        is_manual = random.random() < 0.05

                        status_val = "PRESENT" if is_present else "ABSENT"
                        if is_late:
                            status_val = "LATE"

                        log_dt = datetime.combine(
                            log_date,
                            session_slot.start_time
                        ).replace(tzinfo=timezone.utc) + timedelta(minutes=random.randint(0, 10))

                        att = AttendanceLog(
                            tenant_id=tenant.id,
                            user_id=student.id,
                            timetable_id=session_slot.id,
                            timestamp=log_dt,
                            source="MANUAL_OVERRIDE" if is_manual else "PORTAL_ENTRY",
                            status=status_val,
                            verified_by=session_slot.faculty_id,
                            remarks="Updated by Faculty" if is_manual else "Class Session Roll Call"
                        )
                        session.add(att)
                        attendance_records_count += 1

        session.flush()
        print(f"  • Recorded {attendance_records_count} attendance log entries.")

        # -------------------------------------------------------------------------
        # 9. Seed Assessment Records (Evaluations, Midterms, Lab Viva)
        # -------------------------------------------------------------------------
        print("\n📊 Recording Assessment Scores & Evaluations...")
        assessment_types = [
            ("MIDTERM", "Midterm Examination", 100.0),
            ("LAB_VIVA", "Laboratory Practical Viva", 25.0),
            ("ASSIGNMENT", "Hands-on Project Evaluation", 50.0),
        ]

        assessments_count = 0
        for tenant in tenants:
            t_students = [s for s in all_students if s.tenant_id == tenant.id]
            t_courses = [c for c in all_courses if c.tenant_id == tenant.id]
            t_faculty = [f for f in all_faculty if f.tenant_id == tenant.id]

            for course in t_courses:
                evaluator = random.choice(t_faculty)
                for a_type, a_name, max_sc in assessment_types:
                    for student in random.sample(t_students, 12):
                        scored = round(random.uniform(0.60 * max_sc, 0.98 * max_sc), 1)
                        record = AssessmentRecord(
                            tenant_id=tenant.id,
                            student_id=student.id,
                            course_id=course.id,
                            assessment_type=a_type,
                            assessment_name=f"{course.code} - {a_name}",
                            score=scored,
                            max_score=max_sc,
                            evaluated_by=evaluator.id,
                            evaluated_at=now - timedelta(days=random.randint(1, 20))
                        )
                        session.add(record)
                        assessments_count += 1

        session.flush()
        print(f"  • Recorded {assessments_count} academic evaluation records.")

        # -------------------------------------------------------------------------
        # 10. Seed Alerts (Institutional & Department Announcements)
        # -------------------------------------------------------------------------
        print("\n📢 Publishing Campus Alerts & Notifications...")
        alert_templates = [
            ("Digital Attendance Verification Policy", "Faculty members are requested to complete digital session attendance within 15 minutes of class commencement.", "FACULTY", "ALL", "HIGH"),
            ("Mid-Term Grade Submission Window Open", "Faculty members are requested to upload laboratory and theory evaluations into the gradebook by Friday.", "FACULTY", "ALL", "NORMAL"),
            ("Semester Timetable Finalized", "The revised semester timetable for theory and lab batches is now active.", "ALL", "ALL", "LOW"),
            ("Shortage Warning: Attendance Threshold Policy", "Students maintaining attendance below 75% will be flagged automatically for academic review.", "STUDENT", "Computer Science & Engineering", "URGENT")
        ]

        alerts_created = 0
        for tenant in tenants:
            t_admin = [a for a in admins if a.tenant_id == tenant.id][0]
            for title, msg, role, dept, prio in alert_templates:
                alert = Alert(
                    tenant_id=tenant.id,
                    author_id=t_admin.id,
                    title=f"[{tenant.slug.upper()}] {title}",
                    message=msg,
                    target_role=role,
                    department=dept,
                    priority=prio,
                    expires_at=now + timedelta(days=30)
                )
                session.add(alert)
                alerts_created += 1

        session.commit()
        print(f"  • Published {alerts_created} system and department alerts.")

        # -------------------------------------------------------------------------
        # Verification Summary
        # -------------------------------------------------------------------------
        print("\n" + "=" * 70)
        print("🎉 DATABASE SEEDING COMPLETED SUCCESSFULLY!")
        print("=" * 70)
        print(f"• Total Colleges / Tenants:     {session.query(Tenant).count()}")
        print(f"• Total Admins:                 {session.query(User).filter_by(role='ADMIN').count()}")
        print(f"• Total Faculty Members:        {session.query(User).filter_by(role='FACULTY').count()}")
        print(f"• Total Students:               {session.query(User).filter_by(role='STUDENT').count()}")
        print(f"• Total Courses:                {session.query(Course).count()}")
        print(f"• Total Timetable Slots:        {session.query(Timetable).count()}")
        print(f"• Total Course Enrollments:     {session.query(CourseEnrollment).count()}")
        print(f"• Total Attendance Logs:        {session.query(AttendanceLog).count()}")
        print(f"• Total Assessment Records:     {session.query(AssessmentRecord).count()}")
        print(f"• Total Alerts:                 {session.query(Alert).count()}")
        print("=" * 70)

    except Exception as e:
        session.rollback()
        print(f"\n❌ Error during database seeding: {e}")
        raise
    finally:
        session.close()

if __name__ == "__main__":
    seed_database()
